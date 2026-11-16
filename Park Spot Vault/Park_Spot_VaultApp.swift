//
//  Park_Spot_VaultApp.swift
//  Park Spot Vault
//
//  Created by Артём Коротков on 18.07.2026.
//

import SwiftUI

@main
struct Park_Spot_VaultApp: App {
    @UIApplicationDelegateAdaptor(VaultAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            VaultLaunchView()
        }
    }
}
