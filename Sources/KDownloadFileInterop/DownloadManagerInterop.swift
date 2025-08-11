//
//  DownloadManagerInterop.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 21/06/2025.
//

import Foundation

@objc public class DownloadManagerInterop: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    
    public static let shared = DownloadManagerInterop()
    
    private override init() {
        super.init()
    }
    
    private var continuations: [Int: CheckedContinuation<String, Error>] = [:]
    private var fileNames: [Int: String] = [:]
    private var folderNames: [Int: String?] = [:]
    private var configurations: [Int: DownloadConfiguration] = [:]
    private var lastProgressUpdates: [Int: Date] = [:]
    
    struct DownloadConfiguration {
        let saveToDownloads: Bool
        let saveInCacheFiles: Bool
        let noDuplicateFile: Bool
        let showLiveActivity: Bool
    }
    
    @objc
    public func downloadFile(
        _ urlString: String,
        fileName: String,
        folderName: String?,
        customHeaders: [String: String]?,
        saveToDownloads: Bool,
        saveInCacheFiles: Bool,
        noDuplicateFile: Bool,
        showLiveActivity: Bool
    ) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }
        
        // Validate configuration
        if saveToDownloads && saveInCacheFiles {
            throw NSError(domain: "Cannot save to both Downloads and cache", code: -3, userInfo: nil)
        }
        
        // Check if file is downloadable
        let isDownloadable = await DownloaderInterop.isDownloadableFile(url: url, headers: customHeaders)
        guard isDownloadable else {
            throw NSError(domain: "Not a downloadable file", code: -2, userInfo: nil)
        }
        
        let userAgent = await getUserAgent()
        
        return try await withCheckedThrowingContinuation { continuation in
            var headers = customHeaders ?? [:]
            headers["User-Agent"] = userAgent
            
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.httpAdditionalHeaders = headers
            sessionConfig.timeoutIntervalForRequest = 30
            sessionConfig.timeoutIntervalForResource = .infinity
            
            let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            let id = task.taskIdentifier
            
            // Store info for this task
            continuations[id] = continuation
            fileNames[id] = fileName
            folderNames[id] = folderName
            configurations[id] = DownloadConfiguration(
                saveToDownloads: saveToDownloads,
                saveInCacheFiles: saveInCacheFiles,
                noDuplicateFile: noDuplicateFile,
                showLiveActivity: showLiveActivity
            )
            lastProgressUpdates[id] = .distantPast
            
            if showLiveActivity, #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.start(fileName: fileName)
                    await ActivityStorage.shared.update(fileName: fileName, progress: 0.0, status: "Starting…")
                }
            }
            
            task.resume()
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let id = downloadTask.taskIdentifier
        
        guard let fileName = fileNames[id],
              let folderName = folderNames[id],
              let config = configurations[id] else {
            complete(id: id, with: .failure(NSError(domain: "Missing metadata", code: -99)))
            return
        }
        
        let fileManager = FileManager.default
        let baseDirectoryURL: URL
        
        // Determine destination directory based on configuration
        if config.saveToDownloads {
            // Save to Documents/Downloads (visible to user)
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                complete(id: id, with: .failure(NSError(domain: "Could not access Documents directory", code: -4)))
                return
            }
            let downloadsFolderURL = documentsURL.appendingPathComponent("Downloads", isDirectory: true)
            do {
                try fileManager.createDirectory(at: downloadsFolderURL, withIntermediateDirectories: true)
            } catch {
                complete(id: id, with: .failure(error))
                return
            }
            baseDirectoryURL = downloadsFolderURL
        } else if config.saveInCacheFiles {
            // Save to Cache directory (may be cleared by system)
            guard let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                complete(id: id, with: .failure(NSError(domain: "Could not access Cache directory", code: -5)))
                return
            }
            baseDirectoryURL = cacheURL
        } else {
            // Save to Application Support (persistent but hidden)
            guard let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                complete(id: id, with: .failure(NSError(domain: "Could not access Application Support directory", code: -6)))
                return
            }
            // Create Application Support directory if it doesn't exist
            do {
                try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
            } catch {
                complete(id: id, with: .failure(error))
                return
            }
            baseDirectoryURL = supportURL
        }
        
        // Create destination URL with folder structure
        var destinationURL: URL
        if let folderName, !folderName.isEmpty {
            let folderURL = baseDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            } catch {
                complete(id: id, with: .failure(error))
                return
            }
            destinationURL = folderURL.appendingPathComponent(fileName)
        } else {
            destinationURL = baseDirectoryURL.appendingPathComponent(fileName)
        }
        
        // Handle file naming based on noDuplicateFile setting
        if config.noDuplicateFile {
            // Delete existing file if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                do {
                    try fileManager.removeItem(at: destinationURL)
                } catch {
                    complete(id: id, with: .failure(error))
                    return
                }
            }
        } else {
            // Find unique filename if needed
            var counter = 1
            var uniqueDestinationURL = destinationURL
            let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
            let fileExtension = (fileName as NSString).pathExtension
            
            while fileManager.fileExists(atPath: uniqueDestinationURL.path) {
                let newFileName = "\(fileNameWithoutExtension) (\(counter)).\(fileExtension)"
                uniqueDestinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newFileName)
                counter += 1
            }
            destinationURL = uniqueDestinationURL
        }
        
        do {
            // Ensure the downloaded file exists at the temporary location
            guard fileManager.fileExists(atPath: location.path) else {
                throw NSError(domain: "Downloaded file not found at temporary location", code: -7)
            }
            
            // Move the file to its final destination
            try fileManager.moveItem(at: location, to: destinationURL)
            
            // Set "do not backup" attribute for cache files
            if config.saveInCacheFiles {
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try destinationURL.setResourceValues(resourceValues)
            }
            
            if config.showLiveActivity, #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(fileName: fileName, progress: 1.0, status: "Done ✅")
                    await ActivityStorage.shared.end(fileName: fileName)
                }
            }
            
            complete(id: id, with: .success(destinationURL.path))
        } catch {
            if config.showLiveActivity, #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(fileName: fileName, progress: 1.0, status: "Failed ❌")
                    await ActivityStorage.shared.end(fileName: fileName)
                }
            }
            complete(id: id, with: .failure(error))
        }
    }
    
    // ... (keep existing progress update and error handling methods)
    
    private func complete(id: Int, with result: Result<String, Error>) {
        if let continuation = continuations[id] {
            switch result {
            case .success(let path):
                continuation.resume(returning: path)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
        
        // Cleanup
        continuations.removeValue(forKey: id)
        fileNames.removeValue(forKey: id)
        folderNames.removeValue(forKey: id)
        configurations.removeValue(forKey: id)
        lastProgressUpdates.removeValue(forKey: id)
    }
}
