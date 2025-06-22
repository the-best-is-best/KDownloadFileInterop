//
//  KDownloadFileLiveActivityHandler.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 21/06/2025.
//

#if canImport(ActivityKit)
@preconcurrency import ActivityKit

@available(iOS 16.1, *)
actor DownloadActivityStorage {
    private var currentActivity: Activity<DownloadAttributes>?

    func set(_ activity: Activity<DownloadAttributes>?) {
        self.currentActivity = activity
    }

    func get() -> Activity<DownloadAttributes>? {
        return currentActivity
    }
}

@available(iOS 16.1, *)
enum DownloadActivityHandler {
    static let storage = DownloadActivityStorage()

    static func start(fileName: String) async {
        let attributes = DownloadAttributes(fileName: fileName)
        let initialState = DownloadAttributes.ContentState(progress: 0.0, status: "Starting...")
        do {
            let activity = try Activity<DownloadAttributes>.request(attributes: attributes, contentState: initialState)
            await storage.set(activity)
        } catch {
            print("❌ Failed to start activity: \(error)")
        }
    }

    static func update(progress: Double, status: String) async {
        let newState = DownloadAttributes.ContentState(progress: progress, status: status)
        if let activity = await storage.get() {
            await activity.update(using: newState)
        }
    }

    static func end() async {
        if let activity = await storage.get() {
            await activity.end(dismissalPolicy: .immediate)
            await storage.set(nil)
        }
    }
}
#endif
