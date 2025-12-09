//
//  CoffeinApp.swift
//  Coffein
//
//  Created by Arjang Khademi on 06.12.25.
//

import SwiftUI
import AppKit

class CoffeinAppDelegate: NSObject, NSApplicationDelegate {
    private var aboutWindow: NSWindow?
    private var mainMenuRef: NSMenu?

    func application(_ application: NSApplication,
                     shouldSaveApplicationState coder: NSCoder) -> Bool {
        return false
    }

    func application(_ application: NSApplication,
                     shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return false
    }

    func applicationShouldRestoreWindows(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc func showAboutPanel(_ sender: Any?) {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: AboutView())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Coffein"
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentViewController = hostingController

        let fittingSize = hostingController.view.fittingSize
        let targetWidth = max(340, fittingSize.width + 24)
        let targetHeight = max(320, fittingSize.height + 24)

        window.setContentSize(NSSize(width: targetWidth, height: targetHeight))
        window.center()

        aboutWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        // Reassert the custom menu after SwiftUI finishes any scene/menu rebuild during restore.
        if let menu = self.mainMenuRef {
            NSApp.mainMenu = menu
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()

        // Top-level Coffein app menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Coffein")
        appMenuItem.submenu = appMenu

        let appName = ProcessInfo.processInfo.processName

        // About item – opens custom About panel
        let aboutItem = NSMenuItem(
            title: "About \(appName)",
            action: #selector(CoffeinAppDelegate.showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        appMenu.addItem(NSMenuItem.separator())

        // Quit item – still goes through applicationShouldTerminate(_:) first
        let quitItem = NSMenuItem(
            title: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        // The CoffeinManager now handles its own state restoration via @AppStorage
        // and its init method. We only need to read the initial state for the menu bar.
        let storedIsAwake = UserDefaults.standard.bool(forKey: "isAwake")

        // Ensure status item is created once per process and reflects restored state
        if coffeinStatusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

            if let button = item.button {
                button.image = nil
                button.title = ""
                button.toolTip = "Coffein"
            }

            let menu = NSMenu()

            // First line: current state/tooltip (disabled)
            let initialTip = storedIsAwake ? "Coffein: Active – your Mac won't sleep" : "Coffein – idle (Mac can sleep normally)"
            let stateItem = NSMenuItem(title: initialTip, action: nil, keyEquivalent: "")
            stateItem.isEnabled = false
            menu.addItem(stateItem)
            menu.addItem(NSMenuItem.separator())

            // Open main UI
            let openItem = NSMenuItem(title: "Open Coffein", action: #selector(CoffeinStatusMenuHandler.openMain(_:)), keyEquivalent: "")
            openItem.target = coffeinStatusMenuHandler
            menu.addItem(openItem)

            menu.addItem(NSMenuItem.separator())

            // Quick timer presets from the menu
            let offItem = NSMenuItem(title: "Timer Off", action: #selector(CoffeinStatusMenuHandler.quickTimerOff(_:)), keyEquivalent: "")
            offItem.target = coffeinStatusMenuHandler
            menu.addItem(offItem)

            let t30 = NSMenuItem(title: "30 min", action: #selector(CoffeinStatusMenuHandler.quickTimer30(_:)), keyEquivalent: "")
            t30.target = coffeinStatusMenuHandler
            menu.addItem(t30)

            let t60 = NSMenuItem(title: "1 hour", action: #selector(CoffeinStatusMenuHandler.quickTimer60(_:)), keyEquivalent: "")
            t60.target = coffeinStatusMenuHandler
            menu.addItem(t60)

            let t120 = NSMenuItem(title: "2 hours", action: #selector(CoffeinStatusMenuHandler.quickTimer120(_:)), keyEquivalent: "")
            t120.target = coffeinStatusMenuHandler
            menu.addItem(t120)

            let t180 = NSMenuItem(title: "3 hours", action: #selector(CoffeinStatusMenuHandler.quickTimer180(_:)), keyEquivalent: "")
            t180.target = coffeinStatusMenuHandler
            menu.addItem(t180)

            menu.addItem(NSMenuItem.separator())

            // About + Quit
            let aboutItem = NSMenuItem(title: "About Coffein", action: #selector(CoffeinStatusMenuHandler.openAbout(_:)), keyEquivalent: "")
            aboutItem.target = coffeinStatusMenuHandler
            menu.addItem(aboutItem)

            let quitItem = NSMenuItem(title: "Quit Coffein", action: #selector(CoffeinStatusMenuHandler.quitApp(_:)), keyEquivalent: "q")
            quitItem.target = coffeinStatusMenuHandler
            menu.addItem(quitItem)

            item.menu = menu
            coffeinStatusItem = item

            // Ensure icon/tooltip reflect restored state
            updateCoffeinStatusItem(isAwake: storedIsAwake)
        }

        self.mainMenuRef = mainMenu

        // Install as the app's main menu, replacing the default SwiftUI menus
        NSApp.mainMenu = self.mainMenuRef

        print("[Coffein] applicationDidFinishLaunching – installed custom main menu")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Reassert the custom menu after SwiftUI finishes any scene/menu rebuild during restore.
        if let menu = self.mainMenuRef {
            NSApp.mainMenu = menu
        }
    }

}

@main
struct CoffeinApp: App {
    @NSApplicationDelegateAdaptor(CoffeinAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
    }
}

private struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var appName: String {
        ProcessInfo.processInfo.processName
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "Version \(version)" : "Version \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            // Subtle background to match the main app’s style
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.00)
                    : Color.black.opacity(0.00)
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 16) {
                // App icon + name
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 100)
                        .cornerRadius(12)
                        .shadow(radius: 8, y: 4)
                }

                VStack(spacing: 4) {
                    Text(appName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    Text(versionString)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(
                            colorScheme == .dark
                            ? .secondary
                            : .primary.opacity(0.7)
                        )
                }

                VStack(spacing: 6) {
                    Text("Keep your Mac wide awake")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Text("Coffein uses macOS power assertions under the hood, in a clean, focused UI, so you can stop your Mac from falling asleep during long renders, uploads, gaming sessions or late‑night coding—without relying on the old “caffeinate” command.")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(
                            colorScheme == .dark
                            ? .secondary
                            : .primary.opacity(0.75)
                        )
                        .padding(.horizontal, 6)
                }
                .padding(.top, 4)

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.top, 2)

                VStack(spacing: 2) {
                    Text("Made by arj4ng")
                        .font(.system(size: 12, weight: .medium))

                    Text("A new macOS app developer building tiny tools for real‑world workflows.")
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(
                            colorScheme == .dark
                            ? .secondary
                            : .primary.opacity(0.7)
                        )
                        .padding(.horizontal, 10)
                }
                .padding(.bottom, 2)

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: 320)
        }
        .padding(8)
        .frame(minWidth: 320, minHeight: 260)
    }
}

