//
//  getUserAgent.swift
//  KDownloadFileInterop
//
//  Created by Michelle Raouf on 22/06/2025.
//
#if canImport(UIKit)

import UIKit

@MainActor
func getUserAgent() -> String {
    let infoDictionary = Bundle.main.infoDictionary
    let appName = infoDictionary?["CFBundleName"] as? String ?? "App"
    let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"

    let cfNetworkVersion = ProcessInfo.processInfo.environment["CFNETWORK_VERSION"] ?? "Unknown"
    let osVersionString = ProcessInfo.processInfo.operatingSystemVersionString
    let darwinVersion = osVersionString.components(separatedBy: "Darwin/").dropFirst().first ?? "Unknown"

    let modelName = UIDevice.current.model
    let platform = UIDevice.current.systemName
    let osVersion = osVersionString

    return "\(appName)/\(version).\(build) " +
           "(\(platform); \(modelName); \(osVersion)) " +
           "CFNetwork/\(cfNetworkVersion) " +
           "Darwin/\(darwinVersion)"
}
#endif
