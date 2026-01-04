//
//  ToDoList_v1App.swift
//  ToDoList_v1
//
//  Created by swimchichen on 2025/2/17.
//

import SwiftUI
import SwiftData
import GoogleSignIn
import UserNotifications
import WidgetKit

@main
struct ToDoList_v1App: App {
    @StateObject private var alarmStateManager = AlarmStateManager()
    
    init() {
        setupLanguagePreferences()
        cleanupLegacyUserDefaults()
        updateWidgetData()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmStateManager)
                .onOpenURL(perform: handleURL)
        }
    }
    
    private func handleURL(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }
    
    
    
    private func updateWidgetData() {
        Task {
            do {
                let allTasks = try await APIDataManager.shared.getAllTodoItems()
                WidgetDataManager.shared.saveTodayTasksForWidget(allTasks)
            } catch {
                // Silent failure for widget data update
            }
        }
    }
    

    private func setupLanguagePreferences() {
        let preferredLanguages = Locale.preferredLanguages
        if !preferredLanguages.isEmpty {
            UserDefaults.standard.set(preferredLanguages, forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }

        if Locale.current.languageCode == "zh" {
            UserDefaults.standard.set(["zh-Hant-TW"], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set(["en-US"], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    private func cleanupLegacyUserDefaults() {
        let keysToRemove = ["recentlyDeletedItemIDs"]
        for key in keysToRemove {
            if UserDefaults.standard.object(forKey: key) != nil {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.synchronize()
    }
}
