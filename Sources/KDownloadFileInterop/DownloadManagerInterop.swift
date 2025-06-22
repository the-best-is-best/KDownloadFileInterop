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
    private var lastProgressUpdate: Date = .distantPast

    // MARK: - Main Entry

    @objc public func downloadFile(
        _ urlString: String,
        fileName: String,
        folderName: String?,
        customHeaders: [String: String]?,
        showLiveActivity: Bool
    ) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        let isDownloadable = await DownloaderInterop.isDownloadableFile(url: url, headers: customHeaders)
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
            sessionConfig.timeoutIntervalForRequest = 30
            sessionConfig.timeoutIntervalForResource = .infinity

            let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)

            if showLiveActivity, #available(iOS 16.1, *) {
                Task {
                    if await ActivityStorage.shared.isActive == false {
                        await ActivityStorage.shared.start(fileName: fileName)
                    }
                    await ActivityStorage.shared.update(progress: 0.0, status: "Starting…")
                }
            }

            task.resume()
        }
    }

    // MARK: - Completion Helper (safe continuation)

    private func complete(with result: Result<String, Error>) {
        if let continuation {
            switch result {
            case .success(let path):
                continuation.resume(returning: path)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
            self.continuation = nil
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

        if now.timeIntervalSince(lastProgressUpdate) > 0.2 {
            lastProgressUpdate = now

            if #available(iOS 16.1, *) {
                Task {
                    let percent = Int(progress * 100)
                    await ActivityStorage.shared.update(progress: progress, status: "Downloading… \(percent)%")
                }
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let fileManager = FileManager.default

        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            complete(with: .failure(NSError(domain: "FileManager", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not find documents directory"
            ])))
            return
        }

        let destinationURL: URL
        if let folderName = currentFolderName, !folderName.isEmpty {
            let folderURL = documentsURL.appendingPathComponent(folderName, isDirectory: true)
            if !fileManager.fileExists(atPath: folderURL.path) {
                do {
                    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
                } catch {
                    complete(with: .failure(error))
                    return
                }
            }
            destinationURL = folderURL.appendingPathComponent(currentFileName)
        } else {
            destinationURL = documentsURL.appendingPathComponent(currentFileName)
        }

        try? fileManager.removeItem(at: destinationURL)

        do {
            try fileManager.moveItem(at: location, to: destinationURL)

            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: 1.0, status: "Done ✅")
                    await ActivityStorage.shared.end()
                }
            }

            complete(with: .success(destinationURL.path))
        } catch {
            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: 1.0, status: "Failed ❌")
                    await ActivityStorage.shared.end()
                }
            }

            complete(with: .failure(error))
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            if #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(progress: 1.0, status: "Failed ❌")
                    await ActivityStorage.shared.end()
                }
            }
            complete(with: .failure(error))
        }
    }
}
