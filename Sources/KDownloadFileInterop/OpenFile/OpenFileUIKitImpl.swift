//
//  OpenFileUIKitImpl.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 22/06/2025.
//

#if canImport(UIKit)
import UIKit
import QuickLook
import ObjectiveC.runtime

class FileOpenerUIKitImpl: NSObject {
    static func open(filePath: String) {
        DispatchQueue.main.async {
            let dataSourceKey = UnsafeRawPointer(bitPattern: "io.github.kdownload_file_interop.FileOpener.dataSourceKey".hashValue)!

            guard
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = scene.windows.first?.rootViewController
            else {
                print("No root view controller")
                return
            }

            let url = URL(fileURLWithPath: filePath)
            let preview = QLPreviewController()
            let dataSource = PreviewDataSource(url: url)

            preview.dataSource = dataSource

            objc_setAssociatedObject(
                preview,
                dataSourceKey,
                dataSource,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            rootVC.present(preview, animated: true)
        }
    }

    private class PreviewDataSource: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

#endif
