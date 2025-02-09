//
//  Slack.swift
//  Pareto Updater
//
//  Created by Janez Troha on 27/04/2022.
//

import Alamofire
import Foundation
import os.log
import Regex

class AppSlack: AppUpdater {
    static let sharedInstance = AppSlack(appBundle: "com.tinyspeck.slackmacgap")

    override var appName: String { "Slack" }
    override var appMarketingName: String { "Slack" }
    override var description: String { "Slack is a new way to communicate with your team. It's faster, better organized, and more secure than email." }
    override var latestURL: URL {
        URL(string: "https://downloads.slack-edge.com/releases/macos/\(latestVersion)/prod/universal/Slack-\(latestVersion)-macOS.dmg")!
    }

    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://slack.com/release-notes/mac")
        let versionRegex = Regex("<h2>Slack ?([\\.\\d]+)</h2>")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: Constants.httpQueue, completionHandler: { response in
            if response.error == nil {
                let html = response.value ?? "<h2>Slack 1.23.0</h2>"
                let version = versionRegex.firstMatch(in: html)?.groups.first?.value ?? "1.23.0"
                os_log("%{public}s version=%{public}s", self.appBundle, version)
                completion(version)
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }

        })
    }
}
