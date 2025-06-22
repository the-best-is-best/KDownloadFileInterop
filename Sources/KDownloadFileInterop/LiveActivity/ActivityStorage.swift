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
        private var activity: Activity<DownloadAttributes>?

        var isActive: Bool {
            activity != nil
        }

        func start(fileName: String) async {
            guard activity == nil else { return }

            let attributes = DownloadAttributes(fileName: fileName)
            let state = DownloadAttributes.ContentState(progress: 0.0, status: "Starting…")

            do {
                activity = try Activity<DownloadAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            } catch {
                print("Failed to start Live Activity: \(error)")
            }
        }

        func update(progress: Double, status: String) async {
            guard let activity else { return }
            let newState = DownloadAttributes.ContentState(progress: progress, status: status)
            await activity.update(using: newState)
        }

        func end() async {
            guard let activity else { return }
            await activity.end(dismissalPolicy: .immediate)
            self.activity = nil
        }

}
#endif
