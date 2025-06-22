//
//  OpenFileInterop.swift
//  KDownloadFileLiveActivityInterop
//
//  Created by Michelle Raouf on 22/06/2025.
//

// OpenFileInterop.swift

import Foundation


@objc public class FileOpener: NSObject {
    @objc public static func openFile(filePath: String) {
        FileOpenerUIKitImpl.open(filePath: filePath)
    }

 
}
