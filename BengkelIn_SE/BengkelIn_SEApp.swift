//
//  BengkelIn_SEApp.swift
//  BengkelIn_SE
//
//  Created by Rei Soemanto on 01/05/26.
//

import SwiftUI
import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://ipxwpxozreksmuiztwcy.supabase.co")!,
  supabaseKey: "sb_publishable_KGesQO8JPeZ4H_c7QASQew_1kzIyqvr"
)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct BengkelIn_SEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
