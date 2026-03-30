//
//  Watchkit_Watch_WidgetsBundle.swift
//  Watchkit Watch Widgets
//
//  Created by Rizhan Ruslan on 31/03/2026.
//

import WidgetKit
import SwiftUI

@main
struct Watchkit_Watch_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        WaktuNextPrayerWidget()
        WaktuCurrentPrayerWidget()
        WaktuPrayerTimelineWidget()
    }
}
