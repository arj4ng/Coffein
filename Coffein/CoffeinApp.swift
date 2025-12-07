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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Debug: see when this is actually called
        print("[Coffein] applicationShouldTerminate called. coffeinIsAwakeFlag =", coffeinIsAwakeFlag)

        // If Coffein is actively preventing sleep, ask the user before quitting.
        if coffeinIsAwakeFlag {
            let alert = NSAlert()
            alert.messageText = "Coffein is active"
            alert.informativeText = "Coffein is currently keeping your Mac awake. Do you really want to quit and allow your Mac to sleep again?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit Anyway")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // User chose to quit anyway: always stop caffeinate before exiting
                print("[Coffein] User chose Quit Anyway – stopping caffeinate before quit")
                stopCaffeinate()
                coffeinIsAwakeFlag = false
                return .terminateNow
            } else {
                // User cancelled quit
                return .terminateCancel
            }
        }

        // If not marked as awake, still make sure nothing is left running
        print("[Coffein] Not marked as awake on quit – calling stopCaffeinate() just in case")
        stopCaffeinate()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Last-resort safety: if anything slipped through, stop caffeinate now
        print("[Coffein] applicationWillTerminate – final stopCaffeinate() call")
        stopCaffeinate()
    }

    @objc func showAboutPanel(_ sender: Any?) {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: AboutView())

        // Start with a tiny rect; we'll resize to the SwiftUI view's fitting size.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Coffein"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentViewController = hostingController

        // Ask the SwiftUI view for its ideal (fitting) size, then resize the window to hug it.
        let fittingSize = hostingController.view.fittingSize

        // Add a little extra breathing room so it doesn't feel cramped at the edges.
        let targetWidth = max(320, fittingSize.width)
        let targetHeight = max(260, fittingSize.height)

        window.setContentSize(NSSize(width: targetWidth, height: targetHeight))
        window.center()

        aboutWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
            action: #selector(showAboutPanel(_:)),
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

        // Install as the app's main menu, replacing the default SwiftUI menus
        NSApp.mainMenu = mainMenu

        // Start Coffein in active state and launch caffeinate once the app has finished launching.
        coffeinIsAwakeFlag = true
        runCaffeinate()
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
                    ? Color.white.opacity(0.04)
                    : Color.black.opacity(0.03)
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 16) {
                // App icon + name
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
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

                    Text("Coffein wraps the built‑in “caffeinate” command in a clean, focused UI so you can stop your Mac from falling asleep during long renders, uploads, gaming sessions or late‑night coding.")
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
    }
}
