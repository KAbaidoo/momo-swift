//
//  MoMoDemoAppApp.swift
//  MoMoDemoApp
//
//  Created by kobby on 24/08/2026.
//

import SwiftUI

@main
struct MoMoDemoApp: App {
    @StateObject private var container = AppDependencyContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
        }
    }
}
