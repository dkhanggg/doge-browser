//
//  DOGE_browserApp.swift
//  DOGE browser
//
//  Created by Khang Hoang on 2/24/25.
//

import SwiftUI

@main
struct DOGE_browserApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
