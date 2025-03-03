//
//  ToDoList_v1App.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/17.
//

import SwiftUI
import SwiftData

@main
struct ToDoList_v1App: App {
    // 暫時註解掉 Cloud 版的 ModelContainer 初始化
    /*
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    */

    var body: some Scene {
        WindowGroup {
            //ContentView()
            ContentView()
        }
        // 也暫時移除綁定 ModelContainer
        // .modelContainer(sharedModelContainer)
    }
}
