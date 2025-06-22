//
//  isDownloadableFile.swift
//  KDownloadFileInterop
//
//  Created by Michelle Raouf on 22/06/2025.
//

#if canImport(UIKit)
import UIKit

@objc public class DownloaderInterop: NSObject {
    
    @objc public static func isDownloadableFile(url: URL, headers: [String: String]?) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            let code = httpResponse.statusCode
            if code != 200 && code != 206 { return false }
            
            if let disposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
               disposition.contains("attachment") {
                return true
            }
            
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               contentType.starts(with: "application/") ||
               contentType.starts(with: "image/") ||
               contentType.starts(with: "video/") ||
               contentType.starts(with: "audio/") {
                return true
            }
            
            if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
               Int(contentLength) ?? 0 > 0 {
                return true
            }
        } catch {
            return false
        }
        
        return false
    }
}
#endif
