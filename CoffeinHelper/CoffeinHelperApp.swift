//
//  CoffeinHelperApp.swift
//  CoffeinHelper
//

import SwiftUI
import AppKit

@main
struct CoffeinHelperApp: App {
    @NSApplicationDelegateAdaptor(HelperDelegate.self) var delegate

    var body: some Scene {
        // No UI at all – pure agent
        Settings {
            EmptyView()
        }
    }
}

final class HelperDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) Kill any stray caffeinate from previous crashes / force quits
        killStrayCaffeinate()

        // 2) Launch main Coffein app if it’s not already running
        launchMainAppIfNeeded()

        // 3) Helper can exit – job done
        NSApp.terminate(nil)
    }

    private func killStrayCaffeinate() {
        let proc = Process()
        proc.launchPath = "/usr/bin/killall"
        proc.arguments = ["-q", "caffeinate"]

        do {
            try proc.run()
        } catch {
            print("[Helper] killall caffeinate failed:", error)
        }
    }

    private func launchMainAppIfNeeded() {
        let mainBundleID = "com.arj4ng.Coffein"   // <--- your main app’s bundle id

        let alreadyRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == mainBundleID
        }

        guard !alreadyRunning else {
            return
        }

        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: mainBundleID,
            options: [.default],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
    }
}
