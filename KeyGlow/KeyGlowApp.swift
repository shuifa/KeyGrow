//
//  KeyGlowApp.swift
//  KeyGlow
//

import SwiftUI

@main
struct KeyGlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}
