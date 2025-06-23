//
//  ActivityStorage.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 21/06/2025.
//

//
//  ActivityStorage.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 21/06/2025.
//

#if canImport(ActivityKit)
@preconcurrency import ActivityKit

@available(iOS 16.1, *)
actor ActivityStorage {
    static let shared = ActivityStorage()
    
    // Use fileName as a unique key for each activity
    private var activities: [String: Activity<DownloadAttributes>] = [:]
    
    // Start new Live Activity for a file
    func start(fileName: String) async {
        // If an activity already exists for this file, do nothing
        guard activities[fileName] == nil else { return }

        let attributes = DownloadAttributes(fileName: fileName)
        let state = DownloadAttributes.ContentState(progress: 0.0, status: "Starting…")

        do {
            let activity = try Activity<DownloadAttributes>.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            activities[fileName] = activity
        } catch {
            print("Failed to start Live Activity for \(fileName): \(error)")
        }
    }

    // Update Live Activity by fileName
    func update(fileName: String, progress: Double, status: String) async {
        guard let activity = activities[fileName] else { return }

        let newState = DownloadAttributes.ContentState(progress: progress, status: status)
        await activity.update(using: newState)
    }

    // End and remove Live Activity by fileName
    func end(fileName: String) async {
        guard let activity = activities[fileName] else { return }

        await activity.end(dismissalPolicy: .immediate)
        activities.removeValue(forKey: fileName)
    }

    // Optional: End all activities
    func endAll() async {
        for (_, activity) in activities {
            await activity.end(dismissalPolicy: .immediate)
        }
        activities.removeAll()
    }
}
#endif
