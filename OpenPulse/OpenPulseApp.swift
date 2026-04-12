//
//  OpenPulseApp.swift
//  OpenPulse
//
//  Created by James on 12/4/2026.
//

import SwiftUI

@main
struct OpenPulseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(minWidth: 600, minHeight: 400)
            #endif
        }
    }
}
