//
//  GoogleChrome.swift
//  Pareto Security
//
//  Created by Janez Troha on 11/11/2021.
//
import Alamofire
import AppKit
import Combine
import Foundation
import os.log
import OSLog
import Path
import Regex

class AppMTeams: PkgApp {
    static let sharedInstance = AppMTeams(pkgName: "Teams_osx_app.pkg", appPkgName: "Microsoft Teams.app")

    override var appName: String { "Microsoft Teams" }
    override var appMarketingName: String { "Microsoft Teams" }
    override var appBundle: String { "com.microsoft.teams" }

    override var latestURL: URL {
        return URL(string: "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=osx&download=true")!
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=osx&download=true"
        let versionRegex = Regex("x/?([\\.\\d]+)/T") // x/1.5.00.22362/T
        os_log("Requesting %{public}s", url)

        AF.request(url, method: .head).responseString(queue: Constants.httpQueue, completionHandler: { response in
            if let url = response.response?.url, response.error == nil {
                let cdn = versionRegex.firstMatch(in: url.description)?.groups.first?.value ?? "1.5.00.22362"
                let nibbles = cdn.components(separatedBy: ".")
                let version = "\(nibbles[0]).00.\(nibbles[1])\(nibbles[nibbles.endIndex - 1])"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
