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
    
    private var activity: Activity<DownloadAttributes>? = nil

    func start(fileName: String) async {
        let attributes = DownloadAttributes(fileName: fileName)
        let initialState = DownloadAttributes.ContentState(progress: 0.0, status: "Starting")
        do {
            activity = try Activity.request(attributes: attributes, contentState: initialState)
        } catch {
            print("❌ Failed to start activity: \(error)")
        }
    }

    func update(progress: Double, status: String) async {
        let newState = DownloadAttributes.ContentState(progress: progress, status: status)
        await activity?.update(using: newState)
    }

    func end() async {
        await activity?.end(dismissalPolicy: .immediate)
        activity = nil
    }
}
#endif
