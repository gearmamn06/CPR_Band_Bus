//
//  AppDelegate.swift
//  BusExample
//
//  Created by ParkHyunsoo on 2018. 4. 19..
//  Copyright © 2018년 ParkHyunsoo. All rights reserved.
//

import UIKit
import Bus

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var bus: Bus!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // If you want your Bluetooth connection to the band to stay in your app's background, enter true as the keepAlive value.
        self.bus = Bus(keepAlive: true)
        
        return true
    }


    func applicationWillTerminate(_ application: UIApplication) {
        
        // Initialize all connections with bands
        self.bus?.disconnectBy(macs: nil)
    }


}

