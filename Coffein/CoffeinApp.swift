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
                // Allow quit / shutdown / logout
                return .terminateNow
            } else {
                // Block termination
                return .terminateCancel
            }
        }

        // If not active, quit normally.
        return .terminateNow
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

}

@main
struct CoffeinApp: App {
    @NSApplicationDelegateAdaptor(CoffeinAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)          // hides toolbar
        .windowToolbarStyle(.unifiedCompact)   // prevents automatic chrome
        .windowResizability(.contentSize)
        .commands {
            // Replace the default “About” item with your custom About window
            CommandGroup(replacing: .appInfo) {
                Button("About Coffein") {
                    appDelegate.showAboutPanel(nil)
                }
            }

            // Replace the default Quit menu.
            // This still goes through applicationShouldTerminate(_:) in your delegate.
            CommandGroup(replacing: .appTermination) {
                Button("Quit Coffein") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }

            // Optional: remove “New Window”, “New Document” etc. since your app has none.
            CommandGroup(replacing: .newItem) { }
        }
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
                    Text("Created by Arjang Khademi (arj4ng)")
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
