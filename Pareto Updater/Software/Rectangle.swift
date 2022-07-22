//
//  Rectangle.swift
//  Pareto Updater
//
//  Created by Janez Troha on 26/04/2022.
//

import Alamofire
import Foundation
import os.log
import OSLog
import Regex

class AppRectangle: SparkleApp {
    static let sharedInstance = AppMacy(
        name: "Rectangle",
        bundle: "com.knollsoft.Rectangle",
        url: "https://rectangleapp.com/downloads/updates.xml"
    )
}
