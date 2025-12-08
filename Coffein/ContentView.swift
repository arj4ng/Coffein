//
//  ContentView.swift
//  Coffein
//
//  Created by arj4ng on 06.12.25.
//
/*
  ╔════════════════════════════════════════════════════════╗
  ║  █████╗ ██████╗      ██╗ ██╗  ██╗ ███╗   ██╗  ██████╗  ║
  ║ ██╔══██╗██╔══██╗     ██║ ██║  ██║ ████╗  ██║ ██╔════╝  ║
  ║ ███████║██████╔╝     ██║ ███████║ ██╔██╗ ██║ ██║  ███╗ ║
  ║ ██╔══██║██╔══██╗██   ██║ ╚════██║ ██║╚██╗██║ ██║   ██║ ║
  ║ ██║  ██║██║  ██║╚█████╔╝      ██║ ██║ ╚████║ ╚██████╔╝ ║
  ║ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚════╝       ╚═╝ ╚═╝  ╚═══╝  ╚═════╝  ║
  ╚════════════════════════════════════════════════════════╝
*/

// MARK: ╔════[ Coffein v1.0 ]════╗
// MARK: ║    ContentView.swift   ║
// MARK: ╚════════════════════════╝


import SwiftUI
import AppKit
import IOKit.pwr_mgt

private let cardCornerRadius: CGFloat = 24

/// Shared glass background used by both main card and settings
@ViewBuilder
private func coffeinGlassBackground(colorScheme: ColorScheme) -> some View {
    ZStack {
        if colorScheme == .light {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.9))
        }
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}


extension Notification.Name {
    static let coffeinForceStop        = Notification.Name("coffeinForceStop")
    static let coffeinQuickTimerPreset = Notification.Name("coffeinQuickTimerPreset")
}

// Global menu bar status item for Coffein
var coffeinStatusItem: NSStatusItem?

// Global flag so the app delegate knows if Coffein is actively preventing sleep
var coffeinIsAwakeFlag: Bool = false

// Helper object to handle status item menu actions
class CoffeinStatusMenuHandler: NSObject {
    @objc func openMain(_ sender: Any?) {
        NSApp.bringCoffeinToFront(sender)
    }

    @objc func quickTimerOff(_ sender: Any?) {
        NotificationCenter.default.post(name: .coffeinQuickTimerPreset, object: 0 as TimeInterval)
    }

    @objc func quickTimer30(_ sender: Any?) {
        NotificationCenter.default.post(name: .coffeinQuickTimerPreset, object: 30 * 60 as TimeInterval)
    }

    @objc func quickTimer60(_ sender: Any?) {
        NotificationCenter.default.post(name: .coffeinQuickTimerPreset, object: 60 * 60 as TimeInterval)
    }

    @objc func quickTimer120(_ sender: Any?) {
        NotificationCenter.default.post(name: .coffeinQuickTimerPreset, object: 2 * 60 * 60 as TimeInterval)
    }

    @objc func quickTimer180(_ sender: Any?) {
        NotificationCenter.default.post(name: .coffeinQuickTimerPreset, object: 3 * 60 * 60 as TimeInterval)
    }

    @objc func openAbout(_ sender: Any?) {
        // Forward to the app delegate's custom About panel
        NSApp.sendAction(#selector(CoffeinAppDelegate.showAboutPanel(_:)), to: nil, from: sender)
    }

    @objc func quitApp(_ sender: Any?) {
        NSApp.terminate(sender)
    }
}

// Single shared handler for all status item menu actions
let coffeinStatusMenuHandler = CoffeinStatusMenuHandler()

/// Updates the menu bar icon & tooltip based on Coffein state
/// - Parameters:
///   - isAwake: Whether Coffein is currently preventing sleep
///   - tooltip: Optional custom tooltip text. If nil, a default message is used.
func updateCoffeinStatusItem(isAwake: Bool, tooltip: String? = nil) {
    guard let button = coffeinStatusItem?.button else { return }

    let defaultText = isAwake ? "Coffein: Active – your Mac won't sleep" : "Coffein – idle (Mac can sleep normally)"
    let tip = tooltip ?? defaultText

    // Always show an icon; switch glyph based on state
    let symbol = isAwake ? "􀋦" : "􀋩"  // enabled / disabled icons
    let font = NSFont.systemFont(ofSize: 15)
    let attributed = NSAttributedString(string: symbol, attributes: [ .font: font ])

    button.image = nil
    button.title = ""
    button.attributedTitle = attributed
    button.toolTip = tip

    // Keep the first menu item (state line) in sync with the tooltip text
    if let menu = coffeinStatusItem?.menu, let first = menu.items.first {
        first.title = tip
    }
}

// Shared number formatters for hours and minutes (used in custom timer UI)
fileprivate let hoursFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.minimum = 0
    f.maximum = 24
    f.allowsFloats = false
    return f
}()

fileprivate let minutesFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.minimum = 0
    f.maximum = 59
    f.allowsFloats = false
    return f
}()

// MARK: - Global Sleep Assertion Handling (IOKit, no caffeinate)

enum CoffeinSleepMode: String, CaseIterable {
    /// Match classic `caffeinate -di`: prevent idle sleep and keep the display on.
    case systemAndDisplay

    /// Prepared for later: prevent system idle sleep but allow normal display sleep.
    case systemOnly

    /// Prepared for later: keep the display on, without explicitly blocking idle sleep.
    case displayOnly

    var displayName: String {
        switch self {
        case .systemAndDisplay:
            return "System + Display"
        case .systemOnly:
            return "System only"
        case .displayOnly:
            return "Display only"
        }
    }

    var modeDescription: String {
        switch self {
        case .systemAndDisplay:
            return "Prevents both your Mac and its display from sleeping while Coffein is active"
        case .systemOnly:
            return "Prevents your Mac from going to sleep, but allows the display to turn off normally"
        case .displayOnly:
            return "Keeps the display on while Coffein is active; system sleep follows macOS settings"
        }
    }
}

final class CoffeinSleepManager {
    static let shared = CoffeinSleepManager()

    private var idleAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    private(set) var isActive: Bool = false

    /// Default behavior: match classic `caffeinate -di`
    private(set) var mode: CoffeinSleepMode = .systemAndDisplay

    private init() {}

    /// Prepared hook for future settings: change how Coffein keeps the Mac awake.
    func configure(mode: CoffeinSleepMode) {
        let wasActive = isActive
        if wasActive {
            deactivateInternal()
        }
        self.mode = mode
        if wasActive {
            activate()
        }
    }

    func activate() {
        guard !isActive else {
            print("[Coffein] Sleep assertions already active (mode: \(mode.rawValue))")
            return
        }

        let reason = "Coffein – prevent sleep (\(mode.rawValue))" as CFString

        var createdIdle = false
        var createdDisplay = false

        switch mode {
        case .systemAndDisplay:
            // Match `caffeinate -di`: keep display on AND block idle sleep explicitly.
            let resDisplay = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
            if resDisplay == kIOReturnSuccess {
                createdDisplay = true
            } else {
                displayAssertionID = 0
                print("[Coffein] Failed to create NoDisplaySleep assertion, code: \(resDisplay)")
            }

            let resIdle = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &idleAssertionID
            )
            if resIdle == kIOReturnSuccess {
                createdIdle = true
            } else {
                idleAssertionID = 0
                print("[Coffein] Failed to create NoIdleSleep assertion, code: \(resIdle)")
            }

        case .systemOnly:
            // Prevent system idle sleep, allow display to follow user settings.
            let resIdle = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &idleAssertionID
            )
            if resIdle == kIOReturnSuccess {
                createdIdle = true
            } else {
                idleAssertionID = 0
                print("[Coffein] Failed to create NoIdleSleep assertion, code: \(resIdle)")
            }

        case .displayOnly:
            // Keep the display on; system idle behavior left to macOS.
            let resDisplay = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
            if resDisplay == kIOReturnSuccess {
                createdDisplay = true
            } else {
                displayAssertionID = 0
                print("[Coffein] Failed to create NoDisplaySleep assertion, code: \(resDisplay)")
            }
        }

        isActive = createdIdle || createdDisplay
        if isActive {
            print("[Coffein] Sleep assertions ON (mode: \(mode.rawValue))")
        } else {
            print("[Coffein] Failed to create any sleep assertion (mode: \(mode.rawValue))")
        }
    }

    func deactivate() {
        guard isActive else {
            print("[Coffein] Sleep assertions already OFF")
            return
        }

        deactivateInternal()
        isActive = false
        print("[Coffein] Sleep assertions OFF")
    }

    private func deactivateInternal() {
        if idleAssertionID != 0 {
            let res = IOPMAssertionRelease(idleAssertionID)
            if res != kIOReturnSuccess {
                print("[Coffein] Failed to release NoIdleSleep assertion, code: \(res)")
            }
            idleAssertionID = 0
        }

        if displayAssertionID != 0 {
            let res = IOPMAssertionRelease(displayAssertionID)
            if res != kIOReturnSuccess {
                print("[Coffein] Failed to release NoDisplaySleep assertion, code: \(res)")
            }
            displayAssertionID = 0
        }
    }
}

func runCaffeinate() {
    CoffeinSleepManager.shared.activate()
}

func stopCaffeinate() {
    CoffeinSleepManager.shared.deactivate()
}

func isCaffeinateRunning() -> Bool {
    return CoffeinSleepManager.shared.isActive
}


extension NSApplication {
    /// Called from the status item to bring Coffein to the front
    @objc func bringCoffeinToFront(_ sender: Any?) {
        // Activate the app and bring the main window to the front without forcing key on a borderless window
        self.activate(ignoringOtherApps: true)
        if let window = self.windows.first {
            window.orderFront(nil)
        }
    }
}


enum CoffeinThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "Automatic"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Maps the theme mode to an optional ColorScheme. `.system` => nil (use system).
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct ContentView: View {
    enum TimerEndAction: String, CaseIterable, Identifiable {
        case deactivate
        case sleep

        var id: String { rawValue }

        var label: String {
            switch self {
            case .deactivate: return "Deactivate Coffein"
            case .sleep:      return "Sleep"
            }
        }
    }
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAwake = false
    @State private var isPressing = false
    @State private var hoverClose = false
    @State private var hoverMin = false
    @State private var hoverZoom = false

    @State private var isShowingSettings = false
    @State private var selectedDuration: TimeInterval? = nil
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 0
    @State private var offTimer: Timer? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var remainingSeconds: Int? = nil
    @State private var isTimerExpanded: Bool = false

    // Persist small preferences between launches
    @AppStorage("coffein_timerEndActionRaw") private var timerEndActionRaw: String = TimerEndAction.deactivate.rawValue
    @AppStorage("coffein_selectedMinutes")   private var storedSelectedMinutes: Int = 0
    @AppStorage("coffein_customHours")       private var storedCustomHours: Int = 0
    @AppStorage("coffein_customMinutes")     private var storedCustomMinutes: Int = 0
    @AppStorage("coffein_isTimerExpanded")   private var storedIsTimerExpanded: Bool = false
    
    // Persist core state across launches
    @AppStorage("coffein_isAwake") private var storedIsAwake: Bool = true
    @AppStorage("coffein_selectedDurationSeconds") private var storedSelectedDurationSeconds: Int = 0

    @AppStorage("coffein_theme_mode") private var themeModeRaw: String = CoffeinThemeMode.system.rawValue

    /// The color scheme Coffein should use, based on the selected theme mode.
    private var effectiveColorScheme: ColorScheme? {
        CoffeinThemeMode(rawValue: themeModeRaw)?.preferredColorScheme
            ?? CoffeinThemeMode.system.preferredColorScheme
    }

    // Convenience wrapper so UI works with the enum instead of raw strings
    private var timerEndAction: TimerEndAction {
        get { TimerEndAction(rawValue: timerEndActionRaw) ?? .deactivate }
        set { timerEndActionRaw = newValue.rawValue }
    }

    var body: some View {
        ZStack {
            mainCard
        }
        .background(Color.clear)
        // Apply the selected theme (system / light / dark) to the whole window.
        .preferredColorScheme(effectiveColorScheme)
        // Extend content into the top/titlebar region so there is no unused
        // "ghost" area above the card where the default window chrome would be.
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // Restore persisted awake state and selected duration
            isAwake = storedIsAwake
            coffeinIsAwakeFlag = isAwake

            if storedSelectedDurationSeconds > 0 {
                selectedDuration = TimeInterval(storedSelectedDurationSeconds)
            } else {
                selectedDuration = nil
            }
            
            // Apply awake state to power assertions
            if isAwake {
                runCaffeinate()
            } else {
                stopCaffeinate()
            }

            // Sync current state to the status item (will hide it if not awake)
            updateCoffeinStatusItem(isAwake: isAwake, tooltip: statusTooltip)
            
            if selectedDuration != nil {
                scheduleOffTimerIfNeeded()
            }

            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true

                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.hasShadow = false

                    // Let SwiftUI / AppKit manage resizability and style;
                    // we only make the window movable by background and hide
                    // the native traffic lights so our custom ones are used.
                    window.isMovableByWindowBackground = true

                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                }
            }

            // Restore simple preferences from storage
            customHours = storedCustomHours
            customMinutes = storedCustomMinutes
            isTimerExpanded = storedIsTimerExpanded

        }
        .onChange(of: isAwake) {
            storedIsAwake = isAwake
            // Keep global flag and status item in sync
            coffeinIsAwakeFlag = isAwake
            updateCoffeinStatusItem(isAwake: isAwake, tooltip: statusTooltip)
        }
        .onChange(of: selectedDuration) {
            if let duration = selectedDuration {
                storedSelectedMinutes = Int(duration / 60)
                storedSelectedDurationSeconds = Int(duration)
            } else {
                storedSelectedMinutes = 0
                storedSelectedDurationSeconds = 0
            }
            updateCoffeinStatusItem(isAwake: isAwake, tooltip: statusTooltip)
        }
        .onChange(of: isTimerExpanded) {
            // Persist expansion state only; let SwiftUI manage content size.
            storedIsTimerExpanded = isTimerExpanded
        }
        .onChange(of: isShowingSettings) {
            // No manual window resize here; keep behavior simple and stable.
        }
        .onChange(of: remainingSeconds, initial: false) {
            updateCoffeinStatusItem(isAwake: isAwake, tooltip: statusTooltip)
        }
        .onReceive(NotificationCenter.default.publisher(for: .coffeinQuickTimerPreset)) { note in
            guard let seconds = note.object as? TimeInterval else { return }

            // Clear existing timers
            offTimer?.invalidate()
            offTimer = nil
            countdownTimer?.invalidate()
            countdownTimer = nil
            remainingSeconds = nil

            if seconds <= 0 {
                // Timer Off via menu
                selectedDuration = nil
            } else {
                selectedDuration = seconds
                if !isAwake {
                    isAwake = true
                    runCaffeinate()
                }
                scheduleOffTimerIfNeeded()
            }
        }
    }

    // Extracted main card to make body simpler for the compiler
    @ViewBuilder
    private var mainCard: some View {
        ZStack {
            // Base rounded glass card
            VStack(spacing: 18) {
                // Window controls inside the card
                HStack(spacing: 8) {
                    // Close
                    Circle()
                        .fill(hoverClose ? Color.red.opacity(1.0) : Color.red.opacity(0.75))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color.black.opacity(0.75))
                                .opacity(hoverClose ? 1.0 : 0.0)
                        )
                        .onHover { hoverClose = $0 }
                        .animation(.easeInOut(duration: 0.15), value: hoverClose)
                        .onTapGesture {
                            guard let window = mainWindow() else { return }

                            if isAwake {
                                // Active: just minimize
                                window.miniaturize(nil)
                            } else {
                                // Idle: ask before quitting; if cancelled, just hide the window
                                let alert = NSAlert()
                                alert.messageText = "Quit Coffein?"
                                alert.informativeText = "Coffein is idle. Do you want to quit the app? You can also cancel to simply hide the window and keep the menu bar item."
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "Quit")
                                alert.addButton(withTitle: "Cancel")

                                let response = alert.runModal()
                                if response == .alertFirstButtonReturn {
                                    NSApp.terminate(nil)
                                } else {
                                    // Cancel: hide the window (order out) to keep process/state alive
                                    window.orderOut(nil)
                                }
                            }
                        }

                    // Minimize
                    Circle()
                        .fill(hoverMin ? Color.yellow.opacity(1.0) : Color.yellow.opacity(0.75))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Image(systemName: "minus")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(Color.black.opacity(0.75))
                                .opacity(hoverMin ? 1.0 : 0.0)
                        )
                        .onHover { hoverMin = $0 }
                        .animation(.easeInOut(duration: 0.15), value: hoverMin)
                        .onTapGesture {
                            mainWindow()?.miniaturize(nil)
                        }

                    // Zoom / Center
                    Circle()
                        .fill(hoverZoom ? Color.green.opacity(1.0) : Color.green.opacity(0.75))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(Color.black.opacity(0.75))
                                .opacity(hoverZoom ? 1.0 : 0.0)
                        )
                        .onHover { hoverZoom = $0 }
                        .animation(.easeInOut(duration: 0.15), value: hoverZoom)
                        .onTapGesture {
                            centerMainWindow()
                        }

                    Spacer()
                }
                .padding(.bottom, 2)
                .opacity(0.92)

                // Header row
                HStack {
                    Image(systemName: isAwake ? "sun.max.fill" : "moon.zzz.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 22, weight: .medium))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coffein Shot")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Stop your Mac from sleeping")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .secondary : .primary.opacity(0.7))
                    }

                    Spacer()

                    // Tiny status pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isAwake ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isAwake ? "Active" : "Idle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .primary : .primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark
                                  ? Color.white.opacity(0.08)
                                  : Color.black.opacity(0.06))
                    )
                }

                // Power button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2)) {
                        isAwake.toggle()
                    }
                    if isAwake {
                        runCaffeinate()
                    } else {
                        stopCaffeinate()
                    }
                    scheduleOffTimerIfNeeded()
                } label: {
                    ZStack {
                        // Soft pulsing ring when active
                        Circle()
                            .stroke(
                                RadialGradient(
                                    colors: isAwake
                                        ? [Color.green.opacity(0.6), Color.green.opacity(0.0)]
                                        : [Color.gray.opacity(0.4), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 84, height: 84)
                            .opacity(isAwake ? 1 : 0.5)
                            .scaleEffect(isAwake ? 1.05 : 1.0)
                            .animation(
                                isAwake
                                ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                                : .default,
                                value: isAwake
                            )

                        // Main button fill: static when idle, liquid gradient when active
                        Group {
                            if isAwake {
                                LiquidGradientCircle(timerIntensity: timerIntensity)
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.45), Color.gray.opacity(0.25)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .frame(width: 84, height: 84)
                        .shadow(color: isAwake ? Color.green.opacity(0.7) : Color.black.opacity(0.6),
                                radius: isAwake ? 18 : 10,
                                x: 0, y: isAwake ? 10 : 6)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )

                        // Icon
                        Image(systemName: isAwake ? "bolt.circle.fill" : "bolt.circle")
                            .font(.system(size: 54, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(isPressing ? 0.96 : 1.0)
                }
                .buttonStyle(.plain)
                .pressEvents(onPress: { isPressing = true },
                             onRelease: { isPressing = false })

                // Countdown display (only when a timer is active)
                if let text = countdownDisplayText {
                    HStack {
                        Spacer()
                        Text(text)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                        Spacer()
                    }
                    .padding(.top, 4)
                }

                // Description
                VStack(spacing: 4) {
                    Text(isAwake ? "Your Mac won't sleep while activated" : "Your Mac can sleep normally")
                        .font(.system(size: 16, weight: .medium))
                    Text("Powered by native macOS power assertions to keep your Mac from dozing off.")
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? .secondary : .primary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

                // Auto-off timer (collapsible)
                autoOffSection

                // Footer tag
                Text("v1.0 · Made by arj4ng")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .secondary : .primary.opacity(0.65))
                    .padding(.top, 6)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .frame(width: 360)
            .background(
                coffeinGlassBackground(colorScheme: colorScheme)
            )
            // Small corner settings button on the card itself
            .overlay(alignment: .topTrailing) {
                Button {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        isShowingSettings = true
                    }
                } label: {
                    Text("􀣌")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                colorScheme == .dark
                                ? Color.white.opacity(0.10)
                                : Color.black.opacity(0.08)
                            )
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
                .padding(.top, 12)
            }
            // Clip the entire card (content + background + overlay) to rounded corners,
            // then apply the shadow so it follows the rounded shape instead of a rectangle.
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))

            if isShowingSettings {
                SettingsView(onClose: {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        isShowingSettings = false
                    }
                })
                .frame(width: 360)
                .background(
                    coffeinGlassBackground(colorScheme: colorScheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            }
        }
    }

    // Extracted auto-off section to keep mainCard smaller
    @ViewBuilder
    private var autoOffSection: some View {
        VStack(spacing: 6) {
            // Header row (collapsible toggle)
            Button {
                isTimerExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text("􀐱 Auto turn off")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text(selectedDuration == nil ? "Off" : timerSummaryText)
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? .secondary : .primary.opacity(0.7))
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                        Image(systemName: isTimerExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)

            if isTimerExpanded {
                VStack(spacing: 8) {
                    timerPresetsRow
                    customTimerCard
                    timerEndActionCard
                }
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var timerPresetsRow: some View {
        HStack(spacing: 10) {
            // Timer off circle button
            Button {
                selectedDuration = nil
                offTimer?.invalidate()
                offTimer = nil
                countdownTimer?.invalidate()
                countdownTimer = nil
                remainingSeconds = nil
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(
                            selectedDuration == nil
                            ? (colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
                            : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        )
                    )
            }
            .buttonStyle(.plain)

            // 30 min preset
            Button {
                selectedDuration = 30 * 60
                scheduleOffTimerIfNeeded()
            } label: {
                VStack(spacing: 2) {
                    Text("30")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Min")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        (selectedDuration == 30 * 60)
                        ? (colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
                        : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    )
                )
            }
            .buttonStyle(.plain)

            // 1 h preset
            Button {
                selectedDuration = 60 * 60
                scheduleOffTimerIfNeeded()
            } label: {
                VStack(spacing: 2) {
                    Text("1")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Hr")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        (selectedDuration == 60 * 60)
                        ? (colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
                        : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    )
                )
            }
            .buttonStyle(.plain)

            // 2 h preset
            Button {
                selectedDuration = 2 * 60 * 60
                scheduleOffTimerIfNeeded()
            } label: {
                VStack(spacing: 2) {
                    Text("2")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Hr")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        (selectedDuration == 2 * 60 * 60)
                        ? (colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
                        : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    )
                )
            }
            .buttonStyle(.plain)

            // 3 h preset
            Button {
                selectedDuration = 3 * 60 * 60
                scheduleOffTimerIfNeeded()
            } label: {
                VStack(spacing: 2) {
                    Text("3")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Hr")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(
                        (selectedDuration == 3 * 60 * 60)
                        ? (colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
                        : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var customTimerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Custom")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                HStack(spacing: 12) {
                    // Hours field + stepper
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hours")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .secondary : .primary.opacity(0.7))

                        Stepper(value: $customHours, in: 0...24) {
                            TextField("0", value: $customHours, formatter: hoursFormatter)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .frame(width: 32)
                        }
                    }

                    // Minutes field + stepper
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Minutes")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .secondary : .primary.opacity(0.7))

                        Stepper(value: $customMinutes, in: 0...59) {
                            TextField("0", value: $customMinutes, formatter: minutesFormatter)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .frame(width: 32)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isCustomSelected
                    ? (colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10))
                    : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            // Re-apply the current custom duration as the active duration
            applyCustomFromPicker()
        }
        .onChange(of: customHours) {
            applyCustomFromPicker()
        }
        .onChange(of: customMinutes) {
            applyCustomFromPicker()
        }
    }

    @ViewBuilder
    private var timerEndActionCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("When timer ends")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .primary : .primary)
                Spacer()
                Picker(
                    "When timer ends",
                    selection: Binding<TimerEndAction>(
                        get: { timerEndAction },
                        set: { newValue in
                            // write directly to the AppStorage-backed raw value
                            timerEndActionRaw = newValue.rawValue
                        }
                    )
                ) {
                    Text("Deactivate Coffein").tag(TimerEndAction.deactivate)
                    Text("Sleep").tag(TimerEndAction.sleep)
                }
                .labelsHidden()
                .pickerStyle(.menu)  // dropdown style
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
        )
        .font(.system(size: 11))
    }

    // MARK: - Window helper

    /// Returns the main Coffein window (key window if available, otherwise first app window).
    private func mainWindow() -> NSWindow? {
        NSApp.keyWindow ?? NSApp.windows.first
    }

    /// Centers the main window on its current screen.
    private func centerMainWindow() {
        guard let window = mainWindow() else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        var newFrame = window.frame
        newFrame.origin.x = screenFrame.midX - newFrame.size.width / 2
        newFrame.origin.y = screenFrame.midY - newFrame.size.height / 2

        window.setFrame(newFrame, display: true, animate: true)
    }




    // MARK: - Timer helpers (UI)

    /// Tooltip for the menu bar icon, reflecting current state and timer
    private var statusTooltip: String {
        if !isAwake {
            return "Coffein – idle (Mac can sleep normally)"
        }

        // If we have a live countdown, show remaining time
        if let secs = remainingSeconds, secs > 0 {
            let hours = secs / 3600
            let minutes = (secs % 3600) / 60

            if hours > 0 {
                return String(format: "Coffein: Active – Sleep in %dh %02dm", hours, minutes)
            } else {
                return String(format: "Coffein: Active – Sleep in %d min", minutes)
            }
        }

        // If we only know the selected duration, use the summary text
        if let _ = selectedDuration {
            return "Coffein: Active – \(timerSummaryText)"
        }

        // Fallback
        return "Coffein: Active – your Mac won't sleep"
    }

    private var countdownDisplayText: String? {
        guard isAwake, let seconds = remainingSeconds, seconds > 0 else { return nil }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    private var isCustomSelected: Bool {
        guard let selectedDuration else { return false }
        let presets: [TimeInterval] = [30 * 60, 60 * 60, 2 * 60 * 60, 3 * 60 * 60]
        return !presets.contains(selectedDuration)
    }

    private var timerSummaryText: String {
        guard let selectedDuration else { return "Timer off" }
        let minutes = Int(selectedDuration / 60)
        if minutes < 60 {
            return "Timer: \(minutes) minutes"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return "Timer: \(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "Timer: \(hours)h \(mins)m"
        }
    }

    /// 0 = no timer or just started, 1 = timer almost finished
    private var timerIntensity: Double {
        guard let selectedDuration,
              let remainingSeconds,
              remainingSeconds > 0 else {
            return 0
        }

        let total = Int(selectedDuration)
        guard total > 0 else { return 0 }

        let ratio = max(0.0, min(1.0, Double(remainingSeconds) / Double(total)))
        // Invert: 0 at start, 1 near the end
        return 1.0 - ratio
    }

    // MARK: - Timer helpers (logic)

    // Helper to apply the custom duration (hours + minutes) and schedule the timer
    func applyCustomFromPicker() {
        // Clamp values to their allowed ranges in case of manual text entry
        customHours = max(0, min(24, customHours))
        customMinutes = max(0, min(59, customMinutes))

        // Persist custom values
        storedCustomHours = customHours
        storedCustomMinutes = customMinutes

        let totalMinutes = (customHours * 60) + customMinutes

        if totalMinutes > 0 {
            selectedDuration = TimeInterval(totalMinutes * 60)
        } else {
            selectedDuration = nil
        }

        scheduleOffTimerIfNeeded()
    }

    func scheduleOffTimerIfNeeded() {
        offTimer?.invalidate()
        offTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingSeconds = nil

        guard isAwake, let duration = selectedDuration else { return }

        remainingSeconds = Int(duration)

        offTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                switch timerEndAction {
                case .deactivate:
                    // Turn Coffein off and reset the timer to Off
                    isAwake = false
                    stopCaffeinate()
                    selectedDuration = nil

                case .sleep:
                    // Turn Coffein off, clear timer, then attempt system sleep
                    isAwake = false
                    stopCaffeinate()
                    selectedDuration = nil
                    macSleep()
                }

                remainingSeconds = nil
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if let current = remainingSeconds, current > 0 {
                    remainingSeconds = current - 1
                } else {
                    remainingSeconds = nil
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                }
            }
        }
    }



    // MARK: - System actions

    func macSleep() {
        print("COFFEIN: Requesting system sleep via IOPMSleepSystem")

        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        if port == 0 {
            print("IOPMFindPowerManagement failed")
            return
        }

        let result = IOPMSleepSystem(port)
        if result != kIOReturnSuccess {
            print("IOPMSleepSystem failed with code: \(result)")
        }

        IOServiceClose(port)
    }
}


// MARK: - Liquid Gradient Fill for Toggle

private struct LiquidGradientCircle: View {
    /// 0 = no timer / just started, 1 = timer nearly done
    let timerIntensity: Double

    @State private var spin1: Double = 0
    @State private var spin2: Double = 0
    @State private var spin3: Double = 0
    @State private var didStartSpins: Bool = false

    var body: some View {
        // timerIntensity: 0 = just started, 1 = almost finished
        // We want the "fill level" to DECREASE over time visually,
        // so fillLevel is the fraction of time remaining (1 → 0).
        let clampedIntensity = max(0.0, min(1.0, timerIntensity))
        let fillLevel = 1.0 - clampedIntensity   // 1 at start, 0 near end

        // Base hue for a calm green
        let baseHue: Double = 0.33   // green-ish
        let saturation: Double = 0.92

        let color1 = Color(hue: baseHue, saturation: saturation, brightness: 0.88)
        let color2 = Color(hue: baseHue, saturation: saturation, brightness: 0.74)
        let color3 = Color(hue: baseHue, saturation: saturation, brightness: 0.62)

        // A darker "empty container" behind the liquid
        let container = Color(hue: baseHue, saturation: 0.40, brightness: 0.18)

        return ZStack {
            // Container background (what's left when the liquid is drained)
            Circle()
                .fill(container)

            if fillLevel > 0.001 {
                ZStack {
                    // Three overlapping rotating blobs like the CSS waves,
                    // slightly smaller so they stay comfortably inside the circle
                    Circle()
                        .fill(color1.opacity(0.8))
                        .frame(width: 120, height: 120)
                        .offset(x: -14, y: 16)
                        .rotationEffect(.degrees(spin1))

                    Circle()
                        .fill(color2.opacity(0.6))
                        .frame(width: 130, height: 130)
                        .offset(x: 10, y: 20)
                        .rotationEffect(.degrees(spin2))

                    Circle()
                        .fill(color3.opacity(0.5))
                        .frame(width: 140, height: 140)
                        .offset(x: -6, y: 24)
                        .rotationEffect(.degrees(spin3))
                }
                // Blend blobs together so they feel like one liquid mass
                .compositingGroup()
                .blur(radius: 2.0)
                // Slightly shrink the whole stack,
                .scaleEffect(0.9, anchor: .bottom)
                // then drain vertically from bottom as time passes (never thinner than 15%)
                .scaleEffect(x: 1.0, y: max(0.15, fillLevel), anchor: .bottom)
                // Lift the liquid a bit so low levels are easier to see
                .offset(y: -8)
            }
        }
        // Constrain to the button's size and clip to a circle to hide overflow
        .frame(width: 84, height: 84, alignment: .center)
        .clipShape(Circle())
        .opacity(0.95)
        // Smoothly react as the timer counts down
        .animation(.easeInOut(duration: 0.35), value: timerIntensity)
        .onAppear {
            // Ensure we only start the repeat-forever spin animations once
            guard !didStartSpins else { return }
            didStartSpins = true

            // Slow but distinct rotations for each layer (like different wave durations)
            spin1 = 0
            spin2 = 0
            spin3 = 0

            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                spin1 = 360
            }
            withAnimation(.linear(duration: 7.0).repeatForever(autoreverses: false)) {
                spin2 = 360
            }
            withAnimation(.linear(duration: 11.0).repeatForever(autoreverses: false)) {
                spin3 = 360
            }
        }
    }
}


// Small helper to detect button press state
private struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

private extension View {
    func pressEvents(onPress: @escaping () -> Void,
                     onRelease: @escaping () -> Void) -> some View {
        self.modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

