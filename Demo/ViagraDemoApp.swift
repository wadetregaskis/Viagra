//
//  ViagraDemoApp.swift
//  ViagraDemo
//
//  Created by Wade Tregaskis on 18/5/2024.
//

import SwiftUI

@main
struct ShrinkSlowlyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.windowResizability(.contentMinSize)
    }
}
