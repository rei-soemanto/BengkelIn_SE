//
//  BengkelInApp.swift
//  BengkelIn
//
//  Created by Rei Soemanto on 23/04/26.
//

import SwiftUI
import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://ipxwpxozreksmuiztwcy.supabase.co")!,
  supabaseKey: "sb_publishable_KGesQO8JPeZ4H_c7QASQew_1kzIyqvr",
  options: SupabaseClientOptions(
    auth: SupabaseClientOptions.AuthOptions(
      emitLocalSessionAsInitialSession: true
    )
  )
)

import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct BengkelInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
