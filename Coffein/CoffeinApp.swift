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
        // Use the delegate method to show the panel
        (NSApp.delegate as? CoffeinAppDelegate)?.showAboutPanel(sender)
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
    private var mainMenuRef: NSMenu? // Re-introducing mainMenuRef
    private var coffeinStatusItem: NSStatusItem?
    private var windowNotificationObservers: [NSObjectProtocol] = []

    deinit {
        for observer in windowNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func reassertMainMenu() {
        guard let menu = mainMenuRef else { return }
        if NSApp.mainMenu !== menu {
            NSApp.mainMenu = menu
        }
    }

    private func scheduleMainMenuReassertion() {
        reassertMainMenu()
        DispatchQueue.main.async { [weak self] in
            self?.reassertMainMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.reassertMainMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.reassertMainMenu()
        }
    }

    private func installMainMenuReassertObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification
        ]

        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleMainMenuReassertion()
            }
            windowNotificationObservers.append(observer)
        }
    }

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
        scheduleMainMenuReassertion()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Manually create the main menu in AppKit.
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

        // Store a reference to our custom menu.
        self.mainMenuRef = mainMenu

        // Install it as the app's main menu.
        NSApp.mainMenu = self.mainMenuRef
        installMainMenuReassertObservers()
        scheduleMainMenuReassertion()

        // Create and configure the status bar item (menu bar icon).
        self.coffeinStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.coffeinStatusMenuHandler.configure(with: self.coffeinManager)
        let storedIsAwake = UserDefaults.standard.bool(forKey: "isAwake")

        if let button = self.coffeinStatusItem?.button {
            button.image = nil
            button.title = ""
            button.toolTip = "Coffein"
        }

        let menu = NSMenu()
        let initialTip = storedIsAwake ? "Coffein: Active – your Mac won't sleep" : "Coffein – idle (Mac can sleep normally)"
        let stateItem = NSMenuItem(title: initialTip, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(NSMenuItem.separator())
        let openItem = NSMenuItem(title: "Open Coffein", action: #selector(self.coffeinStatusMenuHandler.openMain(_:)), keyEquivalent: "")
        openItem.target = self.coffeinStatusMenuHandler
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
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
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        scheduleMainMenuReassertion()
        // Explicitly update the status item to ensure its state is current after the app becomes active.
        self.coffeinStatusMenuHandler.updateStatusItem(
            isAwake: self.coffeinManager.isAwake // Rely on internal statusTooltip calculation
        )
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("[Coffein] applicationShouldTerminate - coffeinManager.isAwake: \(coffeinManager.isAwake)")
        if coffeinManager.isAwake {
            let alert = NSAlert()
            alert.messageText = "Coffein is active."
            alert.informativeText = "Do you want to quit the app? Your Mac will be allowed to sleep. Or you can cancel to keep Coffein running in the background."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                return .terminateNow
            } else {
                return .terminateCancel
            }
        } else {
            // Coffein is idle, terminate immediately without prompt
            return .terminateNow
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coffeinManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
        .commands {
            // Empty commands block to prevent SwiftUI from generating any menus.
            // AppKit will handle the main menu entirely.
        }
    }
}
