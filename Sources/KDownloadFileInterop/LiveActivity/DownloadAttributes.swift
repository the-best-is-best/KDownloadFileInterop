//
//  DownloadAttributes.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 21/06/2025.
//

#if canImport(ActivityKit)
@preconcurrency import ActivityKit

@available(iOS 16.1, *)
public struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var status: String

        public init(progress: Double, status: String) {
            self.progress = progress
            self.status = status
        }
    }

    public var fileName: String

    public init(fileName: String) {
        self.fileName = fileName
    }
}
#endif
