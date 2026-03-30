//
//  WatchkitApp.swift
//  Watchkit Watch App
//
//  Created by Rizhan Ruslan on 31/03/2026.
//

import SwiftUI

@main
struct Watchkit_Watch_AppApp: App {
    @StateObject private var store = WatchPrayerStore()
    #if canImport(WatchConnectivity)
    @StateObject private var syncManager = WatchConnectivitySyncManager()
    #endif

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .task {
                    #if canImport(WatchConnectivity)
                    syncManager.onSnapshotApplied = {
                        store.reload()
                    }
                    syncManager.activate()
                    syncManager.requestSyncIfPossible()
                    #endif
                    store.reload()
                }
        }
    }
}
