//
//  DownloadManagerInterop.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 21/06/2025.
//


import Foundation

@objc public class DownloadManagerInterop: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<String, Error>?
    private var currentFileName: String = ""
    private var currentFolderName: String?
    private var lastProgressUpdate: Date = Date.distantPast

    @objc public func downloadFile(
        _ urlString: String,
        fileName: String,
        folderName: String?,
        customHeaders: [String: String]?
    ) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        let isDownloadable = await isDownloadableFile(url: url)
        guard isDownloadable else {
            throw NSError(domain: "Not a downloadable file", code: -2, userInfo: nil)
        }
        
        self.currentFileName = fileName
        self.currentFolderName = folderName

        let userAgent = await getUserAgent()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            var headers = customHeaders ?? [:]
            headers["User-Agent"] = userAgent

            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.httpAdditionalHeaders = headers

            let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)

            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.start(fileName: fileName)
                    await ActivityStorage.shared.update(progress: 0.0, status: "Starting…")
                }
            }

            task.resume()
        }
    }


    // MARK: - URLSessionDownloadDelegate

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let now = Date()

        // تحديث progress كل 0.2 ثانية فقط لتخفيف الحمل على الواجهة
        if now.timeIntervalSince(lastProgressUpdate) > 0.2 {
            lastProgressUpdate = now
            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: progress, status: "Downloading…")
                }
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let fm = FileManager.default

        guard let documentsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            continuation?.resume(throwing: NSError(domain: "FileManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find documents directory"]))
            continuation = nil
            return
        }

        let destinationUrl: URL
        if let folderName = currentFolderName, !folderName.isEmpty {
            let folderUrl = documentsUrl.appendingPathComponent(folderName, isDirectory: true)
            if !fm.fileExists(atPath: folderUrl.path) {
                do {
                    try fm.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    continuation?.resume(throwing: error)
                    continuation = nil
                    return
                }
            }
            destinationUrl = folderUrl.appendingPathComponent(currentFileName)
        } else {
            destinationUrl = documentsUrl.appendingPathComponent(currentFileName)
        }

        try? fm.removeItem(at: destinationUrl)

        do {
            try fm.moveItem(at: location, to: destinationUrl)

            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: 1.0, status: "Done ✅")
                    await ActivityStorage.shared.end()
                }
            }

            continuation?.resume(returning: destinationUrl.path)
        } catch {
            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: 1.0, status: "Failed ❌")
                    await ActivityStorage.shared.end()
                }
            }
            continuation?.resume(throwing: error)
        }

        continuation = nil
    }

    // Handle download errors (network failure, cancel, etc)
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: 1.0, status: "Failed ❌")
                    await ActivityStorage.shared.end()
                }
            }
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}



