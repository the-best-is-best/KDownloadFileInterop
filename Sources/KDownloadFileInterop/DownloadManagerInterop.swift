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
    private var showLiveActivities: [Int: Bool] = [:]
    private var lastProgressUpdates: [Int: Date] = [:]

    @objc
    public func downloadFile(
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
            showLiveActivities[id] = showLiveActivity
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
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let id = downloadTask.taskIdentifier
        guard let fileName = fileNames[id],
              let showLive = showLiveActivities[id] else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let now = Date()

        if now.timeIntervalSince(lastProgressUpdates[id] ?? .distantPast) > 0.2 {
            lastProgressUpdates[id] = now

            if showLive, #available(iOS 16.1, *) {
                Task {
                    let percent = Int(progress * 100)
                    await ActivityStorage.shared.update(
                        fileName: fileName,
                        progress: progress,
                        status: "Downloading… \(percent)%"
                    )
                }
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let id = downloadTask.taskIdentifier

        guard let fileName = fileNames[id],
              let folderName = folderNames[id],
              let showLive = showLiveActivities[id] else {
            complete(id: id, with: .failure(NSError(domain: "Missing metadata", code: -99)))
            return
        }

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            complete(id: id, with: .failure(NSError(domain: "FileManager", code: -1)))
            return
        }

        let destinationURL: URL
        if let folderName, !folderName.isEmpty {
            let folderURL = documentsURL.appendingPathComponent(folderName, isDirectory: true)
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            destinationURL = folderURL.appendingPathComponent(fileName)
        } else {
            destinationURL = documentsURL.appendingPathComponent(fileName)
        }

        try? fileManager.removeItem(at: destinationURL)

        do {
            try fileManager.moveItem(at: location, to: destinationURL)

            if showLive, #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(fileName: fileName, progress: 1.0, status: "Done ✅")
                    await ActivityStorage.shared.end(fileName: fileName)
                }
            }

            complete(id: id, with: .success(destinationURL.path))
        } catch {
            if showLive, #available(iOS 16.1, *) {
                Task {
                    await ActivityStorage.shared.update(fileName: fileName, progress: 1.0, status: "Failed ❌")
                    await ActivityStorage.shared.end(fileName: fileName)
                }
            }
            complete(id: id, with: .failure(error))
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }
        let id = task.taskIdentifier

        if let fileName = fileNames[id],
           let showLive = showLiveActivities[id],
           showLive,
           #available(iOS 16.1, *) {
            Task {
                await ActivityStorage.shared.update(fileName: fileName, progress: 1.0, status: "Failed ❌")
                await ActivityStorage.shared.end(fileName: fileName)
            }
        }

        complete(id: id, with: .failure(error))
    }

    // MARK: - Safe Completion

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
        showLiveActivities.removeValue(forKey: id)
        lastProgressUpdates.removeValue(forKey: id)
    }
}
