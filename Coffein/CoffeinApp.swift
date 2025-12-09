//
//  CoffeinApp.swift
//  Coffein
//
//  Created by Arjang Khademi on 06.12.25.
//

import SwiftUI
import AppKit
import Combine


// MARK: - Notification Names

extension Notification.Name {
    static let coffeinForceStop        = Notification.Name("coffeinForceStop")
    static let coffeinQuickTimerPreset = Notification.Name("coffeinQuickTimerPreset")
    static let coffeinUpdateStatusItem = Notification.Name("coffeinUpdateStatusItem") // New notification for status item updates
}


// MARK: - CoffeinStatusMenuHandler

class CoffeinStatusMenuHandler: NSObject, ObservableObject {
    @Published var statusItem: NSStatusItem?
    var coffeinManager: CoffeinManager!
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
    }

    func configure(with manager: CoffeinManager) {
        self.coffeinManager = manager

        NotificationCenter.default.publisher(for: .coffeinUpdateStatusItem)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let isAwake = notification.userInfo?["isAwake"] as? Bool {
                    self.updateStatusItem(isAwake: isAwake, tooltip: self.statusTooltip)
                }
            }
            .store(in: &cancellables)

        // Set up observers for coffeinManager properties
        coffeinManager.$isAwake
            .sink { [weak self] isAwake in
                self?.updateStatusItem(isAwake: isAwake, tooltip: self?.statusTooltip)
            }
            .store(in: &cancellables)

        coffeinManager.$timeRemaining
            .sink { [weak self] _ in
                self?.updateStatusItem(isAwake: self?.coffeinManager.isAwake ?? false, tooltip: self?.statusTooltip)
            }
            .store(in: &cancellables)

        coffeinManager.$initialDuration
            .sink { [weak self] _ in
                self?.updateStatusItem(isAwake: self?.coffeinManager.isAwake ?? false, tooltip: self?.statusTooltip)
            }
            .store(in: &cancellables)
    }

    func setupStatusItem(item: NSStatusItem, initialIsAwake: Bool) {
        self.statusItem = item
        updateStatusItem(isAwake: initialIsAwake, tooltip: nil)
    }


    func updateStatusItem(isAwake: Bool, tooltip: String? = nil) {
        guard let button = statusItem?.button else { return }

        let defaultText = isAwake ? "Coffein: Active – your Mac won't sleep" : "Coffein – idle (Mac can sleep normally)"
        let tip = tooltip ?? defaultText

        let symbol = isAwake ? "􀋦" : "􀋩"
        let font = NSFont.systemFont(ofSize: 15)
        let attributed = NSAttributedString(string: symbol, attributes: [ .font: font ])

        button.image = nil
        button.title = ""
        button.attributedTitle = attributed
        button.toolTip = tip

        if let menu = statusItem?.menu, let first = menu.items.first {
            first.title = tip
        }
    }

    // MARK: - Menu Actions

    @objc func openMain(_ sender: Any?) {
        NSApp.bringCoffeinToFront(sender)
    }

    @objc func quickTimerOff(_ sender: Any?) {
        coffeinManager.stopTimer()
    }

    @objc func quickTimer30(_ sender: Any?) {
        coffeinManager.startTimer(duration: 30 * 60)
    }

    @objc func quickTimer60(_ sender: Any?) {
        coffeinManager.startTimer(duration: 60 * 60)
    }

    @objc func quickTimer120(_ sender: Any?) {
        coffeinManager.startTimer(duration: 2 * 60 * 60)
    }

    @objc func quickTimer180(_ sender: Any?) {
        coffeinManager.startTimer(duration: 3 * 60 * 60)
    }

    @objc func openAbout(_ sender: Any?) {
        NSApp.sendAction(#selector(CoffeinAppDelegate.showAboutPanel(_:)), to: nil, from: sender)
    }

    @objc func quitApp(_ sender: Any?) {
        NSApp.terminate(sender)
    }


    // MARK: - Tooltip generation

    private var statusTooltip: String {
        if !coffeinManager.isAwake {
            return "Coffein – idle (Mac can sleep normally)"
        }

        if coffeinManager.timeRemaining > 0 {
            let secs = Int(coffeinManager.timeRemaining)
            let hours = secs / 3600
            let minutes = (secs % 3600) / 60

            if hours > 0 {
                return String(format: "Coffein: Active – Sleep in %dh %02dm", hours, minutes)
            } else {
                return String(format: "Coffein: Active – Sleep in %d min", minutes)
            }
        }

        if coffeinManager.initialDuration > 0 {
            let duration = coffeinManager.initialDuration
            let minutes = Int(duration / 60)

            if minutes < 1 {
                return "Coffein: Active – Timer: <1 minute"
            } else if minutes < 60 {
                return "Coffein: Active – Timer: \(minutes) minute\(minutes > 1 ? "s" : "")"
            } else if minutes % 60 == 0 {
                let hours = minutes / 60
                return "Coffein: Active – Timer: \(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                return "Coffein: Active – Timer: \(hours)h \(mins)m"
            }
        }

        return "Coffein: Active – your Mac won't sleep"
    }
}


// MARK: - CoffeinAppDelegate

class CoffeinAppDelegate: NSObject, NSApplicationDelegate {
    var coffeinManager: CoffeinManager!
    var coffeinStatusMenuHandler: CoffeinStatusMenuHandler!

    private var aboutWindow: NSWindow?
    private var mainMenuRef: NSMenu?
    private var coffeinStatusItem: NSStatusItem?

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

        self.coffeinStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // The CoffeinManager now handles its own state restoration via @AppStorage
        // and its init method. We only need to read the initial state for the menu bar.
        let storedIsAwake = UserDefaults.standard.bool(forKey: "isAwake")

        if let button = self.coffeinStatusItem?.button {
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
        let openItem = NSMenuItem(title: "Open Coffein", action: #selector(self.coffeinStatusMenuHandler.openMain(_:)), keyEquivalent: "")
        openItem.target = self.coffeinStatusMenuHandler
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quick timer presets from the menu
        let offItem = NSMenuItem(title: "Timer Off", action: #selector(self.coffeinStatusMenuHandler.quickTimerOff(_:)), keyEquivalent: "")
        offItem.target = self.coffeinStatusMenuHandler
        menu.addItem(offItem)

        let t30 = NSMenuItem(title: "30 min", action: #selector(self.coffeinStatusMenuHandler.quickTimer30(_:)), keyEquivalent: "")
        t30.target = self.coffeinStatusMenuHandler
        menu.addItem(t30)

        let t60 = NSMenuItem(title: "1 hour", action: #selector(self.coffeinStatusMenuHandler.quickTimer60(_:)), keyEquivalent: "")
        t60.target = self.coffeinStatusMenuHandler
        menu.addItem(t60)

        let t120 = NSMenuItem(title: "2 hours", action: #selector(self.coffeinStatusMenuHandler.quickTimer120(_:)), keyEquivalent: "")
        t120.target = self.coffeinStatusMenuHandler
        menu.addItem(t120)

        let t180 = NSMenuItem(title: "3 hours", action: #selector(self.coffeinStatusMenuHandler.quickTimer180(_:)), keyEquivalent: "")
        t180.target = self.coffeinStatusMenuHandler
        menu.addItem(t180)

        menu.addItem(NSMenuItem.separator())

        // About + Quit
        let statusMenuAboutItem = NSMenuItem(title: "About Coffein", action: #selector(self.coffeinStatusMenuHandler.openAbout(_:)), keyEquivalent: "")
        statusMenuAboutItem.target = self.coffeinStatusMenuHandler
        menu.addItem(statusMenuAboutItem)

        let statusMenuQuitItem = NSMenuItem(title: "Quit Coffein", action: #selector(self.coffeinStatusMenuHandler.quitApp(_:)), keyEquivalent: "q")
        statusMenuQuitItem.target = self.coffeinStatusMenuHandler
        menu.addItem(statusMenuQuitItem)

        self.coffeinStatusItem?.menu = menu
        if let statusItem = self.coffeinStatusItem {
            self.coffeinStatusMenuHandler.setupStatusItem(item: statusItem, initialIsAwake: storedIsAwake)
        } else {
            print("[Coffein] ERROR: NSStatusItem could not be created or is nil.")
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

    func applicationWillTerminate(_ notification: Notification) {
        print("[Coffein] applicationWillTerminate – releasing power assertions.")
        coffeinManager.sleepManager.stop()
    }
}



// MARK: - CoffeinApp

@main
struct CoffeinApp: App {
    let coffeinManager = CoffeinManager()
    let coffeinStatusMenuHandler = CoffeinStatusMenuHandler()
    @NSApplicationDelegateAdaptor(CoffeinAppDelegate.self) var appDelegate

    init() {
        appDelegate.coffeinManager = coffeinManager
        appDelegate.coffeinStatusMenuHandler = coffeinStatusMenuHandler
        // NOTE: If configure is needed, call it from applicationDidFinishLaunching in the delegate.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coffeinManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
    }
}


// MARK: - AboutView

fileprivate struct AboutView: View {
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
