//
//  isDownloadableFile.swift
//  KDownloadFileInterop
//
//  Created by Michelle Raouf on 22/06/2025.
//
#if canImport(UIKit)
import UIKit

func isDownloadableFile(url: URL) async -> Bool {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("bytes=0-0", forHTTPHeaderField: "Range")

    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        // Check status code (206 = Partial Content) OR 200 OK
        guard httpResponse.statusCode == 206 || httpResponse.statusCode == 200 else {
            return false
        }

        // Check Content-Disposition
        if let disposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
           disposition.contains("attachment") {
            return true
        }

        // Check Content-Type
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.starts(with: "application/") ||
           contentType.starts(with: "image/") ||
           contentType.starts(with: "video/") ||
           contentType.starts(with: "audio/") {
            return true
        }

        // Fallback if Content-Length exists
        if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           Int(contentLength) ?? 0 > 0 {
            return true
        }

    } catch {
        return false
    }

    return false
}
#endif
