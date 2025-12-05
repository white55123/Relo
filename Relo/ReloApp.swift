//
//  ReloApp.swift
//  Relo
//
//  Created by reol on 2025/12/3.
//

import SwiftUI
import CoreData

@main
struct ReloApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
