//
//  ContentView.swift
//  Watchkit Watch App
//
//  Created by Rizhan Ruslan on 31/03/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WatchRootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchPrayerStore())
}
