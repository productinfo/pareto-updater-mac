//
//  AppUpdater.swift
//  Pareto Updater
//
//  Created by Janez Troha on 14/04/2022.
//

import Alamofire
import AppKit
import Defaults
import Foundation
import os.log
import Path
import Regex
import SwiftUI

enum AppUpdaterStatus {
    case Idle
    case GatheringInfo
    case DownloadingUpdate
    case InstallingUpdate
    case Updated
    case Failed
    case Unsupported
}

struct AppStoreResponse: Codable {
    let resultCount: Int
    let results: [AppStoreResult]
}

struct AppStoreResult: Codable {
    let version, wrapperType: String
    let artistID: Int
    let artistName: String

    enum CodingKeys: String, CodingKey {
        case version, wrapperType
        case artistID = "artistId"
        case artistName
    }
}

public class AppUpdater: Hashable, Identifiable, ObservableObject {
    public static func == (lhs: AppUpdater, rhs: AppUpdater) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var id = UUID()

    var appName: String { "" } // Updater for Pareto
    var appMarketingName: String { "" } // Pareto Updater
    var appBundle: String { "" } // like co.niteo.paretoupdater

    @Published var status: AppUpdaterStatus = .Idle
    @Published var updatable: Bool = false
    @Published var fractionCompleted: Double = 0.0

    var workItem: DispatchWorkItem?

    func getLatestVersion(completion _: @escaping (String) -> Void) {
        fatalError("getLatestVersion() is not implemented")
    }

    var help: String {
        if textVersion == "0.0.0" {
            return "Installing: \(latestVersion)"
        }
        return "\(textVersion) Latest: \(latestVersion)"
    }

    var latestURLExtension: String {
        latestURL.pathExtension
    }

    var hasUpdate: Bool {
        if let version = currentVersion {
            return latestVersion.versionCompare(version) == .orderedDescending
        }
        return false
    }

    public var usedRecently: Bool {
        if !Defaults[.checkForUpdatesRecentOnly] {
            return true
        }

        if isInstalled {
            let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            let attributes = NSMetadataItem(url: URL(fileURLWithPath: applicationPath))
            guard let lastUse = attributes?.value(forAttribute: "kMDItemLastUsedDate") as? Date else { return false }
            return lastUse >= weekAgo
        }
        return true
    }

    public var fromAppStore: Bool {
        if isInstalled {
            let attributes = NSMetadataItem(url: URL(fileURLWithPath: applicationPath))
            guard let hasReceipt = attributes?.value(forAttribute: "kMDItemAppStoreHasReceipt") as? Bool else { return false }
            return hasReceipt
        }
        return false
    }

    func downloadLatest(completion: @escaping (URL, URL) -> Void) {
        let cachedPath = Constants.cacheFolder.appendingPathComponent("\(appBundle)-\(latestVersion).\(latestURLExtension)")
        if FileManager.default.fileExists(atPath: cachedPath.path), Constants.useCacheFolder {
            os_log("Update from cache at %{public}", cachedPath.debugDescription)
            completion(latestURL, cachedPath)
            return
        }
        // os_log("Update downloadLatest: \(cachedPath.debugDescription) from \(latestURL.debugDescription)")
        print("Starting download of \(latestURL.description)")
        AF.download(latestURL).responseData { [self] response in
            do {
                if FileManager.default.fileExists(atPath: cachedPath.path) {
                    try FileManager.default.removeItem(at: cachedPath)
                }
                try FileManager.default.moveItem(atPath: response.fileURL!.path, toPath: cachedPath.path)
                os_log("Update downloadLatest: %{public} from %{public}", cachedPath.debugDescription, self.latestURL.debugDescription)
                completion(latestURL, cachedPath)
                return
            } catch {
                completion(latestURL, response.fileURL!)
                return
            }
        }.downloadProgress { [self] progress in
            self.fractionCompleted = progress.fractionCompleted
            print("\(self.fractionCompleted.description)")
        }
    }

    var latestURL: URL {
        fatalError("latestURL() is not implemented")
    }

    func install(sourceFile: URL, appFile: URL) -> AppUpdaterStatus {
        DispatchQueue.main.async { [self] in
            status = .InstallingUpdate
        }

        var needsStart = false
        let processes = NSRunningApplication.runningApplications(withBundleIdentifier: appBundle)
        for process in processes {
            process.forceTerminate()
            needsStart = true
        }

        return extract(sourceFile: sourceFile, appFile: appFile, needsStart: needsStart)
    }

    func extract(sourceFile _: URL, appFile: URL, needsStart: Bool) -> AppUpdaterStatus {
        switch appFile.pathExtension {
        case "dmg":
            let mountPoint = URL(string: "/Volumes/" + appBundle)!
            os_log("Mount %{public}s is %{public}s%", appFile.debugDescription, mountPoint.debugDescription)
            if DMGMounter.attach(diskImage: appFile, at: mountPoint) {
                do {
                    let app = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains(".app") }.first

                    let downloadedAppBundle = Bundle(url: app!)!
                    if let installedAppBundle = Bundle(path: applicationPath) {
                        os_log("Delete installedAppBundle: \(installedAppBundle.description)")
                        try installedAppBundle.path.delete()

                        os_log("Update installedAppBundle: \(installedAppBundle.description) with \(downloadedAppBundle.description)")
                        try downloadedAppBundle.path.copy(to: installedAppBundle.path, overwrite: true)
                        if needsStart {
                            installedAppBundle.launch()
                        }
                    } else {
                        os_log("Install AppBundle \(downloadedAppBundle.description)")
                        try downloadedAppBundle.path.copy(to: Path(applicationPath)!, overwrite: true)
                    }
                    _ = DMGMounter.detach(mountPoint: mountPoint)

                    if let bundle = Bundle(path: applicationPath), needsStart {
                        bundle.launch()
                    }

                    return AppUpdaterStatus.Updated
                } catch {
                    _ = DMGMounter.detach(mountPoint: mountPoint)
                    os_log("Failed to check for app bundle %{public}s", error.localizedDescription)
                    return AppUpdaterStatus.Failed
                }
            }
        case "zip", "tar":
            do {
                let app = FileManager.default.unzip(appFile)
                let downloadedAppBundle = Bundle(url: app)!
                if let installedAppBundle = Bundle(path: applicationPath) {
                    os_log("Delete installedAppBundle: \(installedAppBundle.description)")
                    try installedAppBundle.path.delete()

                    os_log("Update installedAppBundle: \(installedAppBundle.description) with \(downloadedAppBundle.description)")
                    try downloadedAppBundle.path.copy(to: installedAppBundle.path, overwrite: true)
                    if needsStart {
                        installedAppBundle.launch()
                    }
                } else {
                    os_log("Install AppBundle \(downloadedAppBundle.description)")
                    try downloadedAppBundle.path.copy(to: Path(applicationPath)!, overwrite: true)
                }

                try downloadedAppBundle.path.delete()
                if let bundle = Bundle(path: applicationPath), needsStart {
                    bundle.launch()
                }
                return AppUpdaterStatus.Updated
            } catch {
                os_log("Failed to check for app bundle %{public}s", error.localizedDescription)
                return AppUpdaterStatus.Failed
            }
        default:
            return AppUpdaterStatus.Unsupported
        }

        return AppUpdaterStatus.Failed
    }

    func updateApp(completion: @escaping (AppUpdaterStatus) -> Void) {
        DispatchQueue.main.async { [self] in
            status = .DownloadingUpdate
            fractionCompleted = 0.0
        }
        downloadLatest { [self] sourceFile, appFile in
            workItem?.cancel()
            workItem = DispatchWorkItem { [self] in

                let state = self.install(sourceFile: sourceFile, appFile: appFile)
                DispatchQueue.main.async { [self] in
                    status = state
                    fractionCompleted = 0.0
                    completion(state)
                }
            }

            workItem?.notify(queue: .main) { [self] in
                status = .Idle
                updatable = false
                fractionCompleted = 0.0
                completion(status)
            }
            DispatchQueue.global(qos: .userInteractive).async(execute: workItem!)
        }
    }

    var textVersion: String {
        if isInstalled {
            if let version = Bundle.appVersion(path: applicationPath) {
                return version.lowercased()
            }
            return "0.0.0"
        }
        return "0.0.0"
    }

    var currentVersion: String? {
        if !isInstalled {
            return nil
        }

        return textVersion.versionNormalize
    }

    var applicationPath: String {
        return "/Applications/\(appName).app"
    }

    public var isInstalled: Bool {
        FileManager.default.fileExists(atPath: applicationPath)
    }

    public var icon: NSImage? {
        if !isInstalled {
            return nil
        }
        return Bundle(path: applicationPath)?.icon
    }

    public var latestVersion: String {
        if let found = try? Constants.versionStorage.existsObject(forKey: appBundle), found {
            return try! Constants.versionStorage.object(forKey: appBundle)
        } else {
            let lock = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInteractive).async { [self] in
                getLatestVersion { [self] version in
                    try! Constants.versionStorage.setObject(version, forKey: self.appBundle)
                    lock.signal()
                }
            }
            lock.wait()
            return try! Constants.versionStorage.object(forKey: appBundle)
        }
    }
}
