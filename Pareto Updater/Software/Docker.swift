//
//  Docker.swift
//  Pareto Updater
//
//  Created by Janez Troha on 11/05/2022.
//

import Foundation
import Alamofire
import os.log
import OSLog
import Regex
import Version

class AppDocker: AppUpdater {
    static let sharedInstance = AppDocker()
    
    override var appName: String { "Docker" }
    override var appMarketingName: String { "Docker" }
    override var appBundle: String { "com.docker.docker" }
    
    override var UUID: String {
        "ee11fe36-a372-5cba-a1b4-151748fc2fa7"
    }
    
    override var latestURL: URL {
    #if (arch(arm64))
            return URL(string: "https://desktop.docker.com/mac/main/arm64/Docker.dmg")!
    #else
            return URL(string: "https://desktop.docker.com/mac/main/amd64/Docker.dmg")!
    #endif
    }
    
    override func getLatestVersion(completion: @escaping (String) -> Void) {
        let url = viaEdgeCache("https://raw.githubusercontent.com/docker/docker.github.io/master/desktop/mac/release-notes/index.md")
        let versionRegex = Regex("## Docker Desktop ([\\d.]+)")
        os_log("Requesting %{public}s", url)
        AF.request(url).responseString(queue: Constants.httpQueue, completionHandler: { response in
            if response.data != nil {
                let result = versionRegex.firstMatch(in: response.value ?? "")
                completion(result?.groups.first?.value ?? "0.0.0")
            } else {
                os_log("%{public}s failed: %{public}s", self.appBundle, response.error.debugDescription)
                completion("0.0.0")
            }
            
        })
    }
}
