//
//  TeamWorks_ArizonaApp.swift
//  TeamWorks Arizona
//
//  Created by Jason Cantor on 1/21/26.
//

import SwiftUI
import UIKit

@main
struct TeamWorks_ArizonaApp: App {
    init() {
        // Keep Apple TV awake while the app is running.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
