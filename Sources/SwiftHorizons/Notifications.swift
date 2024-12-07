//
//  Notifications.swift
//  Regulus
//
//  Created by Antoine on 3/2/18.
//  Copyright © 2018 Yuma Antoine Decaux. All rights reserved.
//

import Foundation

let loadingNotification = Notification.Name(rawValue: "loading")
let remainingNotification = Notification.Name(rawValue: "remaining")
let completedNotification = Notification.Name(rawValue: "completed")
let downloadCompleteNotification = Notification.Name(rawValue: "downloadComplete")
let bodyLoadNotification = Notification.Name(rawValue: "bodyLoad")

//Errors
let noConnectionNotification = Notification.Name(rawValue: "noConnection")
let downloadFailedNotification = Notification.Name(rawValue: "downloadFailedAsteroid")
let resetToEarthNotification = Notification.Name(rawValue: "resetToEarth")

