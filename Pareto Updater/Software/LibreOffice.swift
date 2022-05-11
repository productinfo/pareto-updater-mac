//
//  LibreOffice.swift
//  Pareto Updater
//
//  Created by Janez Troha on 11/05/2022.
//

import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Regex
import Version

class AppLibreOffice: AppUpdater {
    static let sharedInstance = AppLibreOffice()

    override var appName: String { "LibreOffice" }
    override var appMarketingName: String { "LibreOffice" }
    override var appBundle: String { "org.libreoffice.script" }

    override var UUID: String {
        "5726931a-264a-5758-b7dd-d09285ac4b7f"
    }

    override var latestURL: URL {
        #if arch(arm64)
            return URL(string: "https://www.libreoffice.org/donate/dl/mac-aarch64/\(latestVersionCached)/en-US/LibreOffice_\(latestVersionCached)_MacOS_aarch64.dmg")!
        #else
            return URL(string: "https://www.libreoffice.org/donate/dl/mac-x86_64/\(latestVersionCached)/en-US/LibreOffice_\(latestVersionCached)_MacOS_x86-64.dmg")!
        #endif
    }

    override var currentVersion: Version {
        if applicationPath == nil {
            return Version(0, 0, 0)
        }
        let v = appVersion(path: applicationPath ?? "1.2.3.4")!.split(separator: ".")
        return Version(Int(v[0]) ?? 0, Int(v[1]) ?? 0, Int(v[2]) ?? 0)
    }

    func getLatestVersions(completion: @escaping ([String]) -> Void) {
        let url = viaEdgeCache("https://www.libreoffice.org/download/download/")
        os_log("Requesting %{public}s", url)
        let versionRegex = Regex("<span class=\"dl_version_number\">?([\\.\\d]+)</span>")
        AF.request(url).responseString(queue: Constants.httpQueue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<span class=\"dl_version_number\">1.2.4</span>"
                let versions = versionRegex.allMatches(in: html).map { $0.groups.first?.value ?? "1.2.4" }
                completion(versions)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion(["0.0.0"])
            }
        })
    }

    public var latestVersions: [Version] {
        var tempVersions = [Version(0, 0, 0)]
        let lock = DispatchSemaphore(value: 0)
        getLatestVersions { versions in
            tempVersions = versions.map { Version($0) ?? Version(0, 0, 0) }
            lock.signal()
        }
        lock.wait()
        return tempVersions
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        completion(latestVersions.first?.description ?? "0.0.0")
    }
}
