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

// Global menu bar status item for Coffein
var coffeinStatusItem: NSStatusItem?

/// Updates the menu bar icon & tooltip based on Coffein state
func updateCoffeinStatusItem(isAwake: Bool) {
    guard let button = coffeinStatusItem?.button else { return }

    if isAwake {
        // Active glyph only: 􁉘
        let glyph = "􁉘"
        let font = NSFont.systemFont(ofSize: 15)
        let attributed = NSAttributedString(string: glyph, attributes: [
            .font: font
        ])

        button.image = nil
        button.title = ""
        button.attributedTitle = attributed
        button.toolTip = "Coffein: Active – your Mac won't sleep"
    } else {
        // Clear the glyph when off (leaves a tiny gap, but status item stays stable)
        button.image = nil
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = "Coffein"
    }
}

extension NSApplication {
    /// Called from the status item to bring Coffein to the front
    @objc func bringCoffeinToFront(_ sender: Any?) {
        // Activate the app and bring the main window to the front
        self.activate(ignoringOtherApps: true)
        if let window = self.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct ContentView: View {
    enum TimerEndAction: String, CaseIterable, Identifiable {
        case deactivate
        case shutdown

        var id: String { rawValue }

        var label: String {
            switch self {
            case .deactivate: return "Deactivate Coffein"
            case .shutdown:   return "Shut Down"
            }
        }
    }
    @State private var isAwake = false
    @State private var isPressing = false
    @State private var hoverClose = false
    @State private var hoverMin = false
    @State private var hoverZoom = false

    @State private var selectedDuration: TimeInterval? = nil
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 0
    @State private var offTimer: Timer? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var remainingSeconds: Int? = nil
    @State private var isTimerExpanded: Bool = false
    @State private var timerEndAction: TimerEndAction = .deactivate

    var body: some View {
        ZStack {
            // Main card
            VStack(spacing: 18) {

                // Window controls inside the card
                HStack(spacing: 8) {

                    // Close
                    Circle()
                        .fill(hoverClose ? Color.red.opacity(1.0) : Color.red.opacity(0.75))
                        .frame(width: 12, height: 12)
                        .onHover { hoverClose = $0 }
                        .animation(.easeInOut(duration: 0.15), value: hoverClose)
                        .onTapGesture {
                            if isAwake {
                                // When Coffein is active, just minimize the window
                                NSApp.keyWindow?.miniaturize(nil)
                            } else {
                                // When Coffein is idle, close the app completely
                                NSApp.terminate(nil)
                            }
                        }

                    // Minimize
                    Circle()
                        .fill(hoverMin ? Color.yellow.opacity(1.0) : Color.yellow.opacity(0.75))
                        .frame(width: 12, height: 12)
                        .onHover { hoverMin = $0 }
                        .animation(.easeInOut(duration: 0.15), value: hoverMin)
                        .onTapGesture { NSApp.keyWindow?.miniaturize(nil) }

                    // Zoom
                    Circle()
                        .fill(hoverZoom ? Color.green.opacity(1.0) : Color.green.opacity(0.75))
                        .frame(width: 12, height: 12)
                        .onHover { hoverZoom = $0 }
                        .animation(.easeInOut(duration: 0.15), value: hoverZoom)
                        .onTapGesture { NSApp.keyWindow?.zoom(nil) }

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
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Tiny status pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isAwake ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isAwake ? "Active" : "Idle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }

                // Power button
                Button {
                    isAwake.toggle()
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

                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isAwake
                                        ? [Color.green.opacity(0.55), Color.green.opacity(0.35)]
                                        : [Color.gray.opacity(0.45), Color.gray.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 84, height: 84)
                            .shadow(color: isAwake ? Color.green.opacity(0.7) : Color.black.opacity(0.6),
                                    radius: isAwake ? 18 : 10,
                                    x: 0, y: isAwake ? 10 : 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )

                        // Icon
                        Image(systemName: isAwake ? "power.circle.fill" : "power")
                            .font(.system(size: 34, weight: .regular))
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
                    Text(isAwake ? "Your Mac won't sleep while this is on" : "Your Mac can sleep normally")
                        .font(.system(size: 14, weight: .medium))
                    Text("Powered by the built-in `caffeinate` command to keep your Mac from dozing off.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

                // Auto-off timer (collapsible)
                VStack(spacing: 6) {
                    // Header row (collapsible toggle)
                    Button {
                        isTimerExpanded.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Auto turn off")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(selectedDuration == nil ? "Off" : timerSummaryText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
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
                                            Circle()
                                                .fill(selectedDuration == nil ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
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
                                        Circle()
                                            .fill((selectedDuration == 30 * 60) ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
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
                                        Circle()
                                            .fill((selectedDuration == 60 * 60) ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
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
                                        Circle()
                                            .fill((selectedDuration == 2 * 60 * 60) ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
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
                                        Circle()
                                            .fill((selectedDuration == 3 * 60 * 60) ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 4)

                            // Custom time below presets
                            HStack(spacing: 10) {
                                Text("Custom")
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                HStack(spacing: 18) {
                                    // Hours column
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Hours")
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Picker("Hours", selection: $customHours) {
                                            ForEach(0...24, id: \.self) { h in
                                                Text("\(h)")
                                                    .tag(h)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 50)
                                    }

                                    // Minutes column
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Minutes")
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Picker("Minutes", selection: $customMinutes) {
                                            ForEach(0...59, id: \.self) { m in
                                                Text("\(m)")
                                                    .tag(m)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 60)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isCustomSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                            )
                            .onChange(of: customHours) { _ in
                                applyCustomMinutes()
                            }
                            .onChange(of: customMinutes) { _ in
                                applyCustomMinutes()
                            }

                            // Action when timer ends – separate card under Custom
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("When timer ends")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Picker("When timer ends", selection: $timerEndAction) {
                                        Text("Deactivate Coffein").tag(TimerEndAction.deactivate)
                                        Text("Shut Down").tag(TimerEndAction.shutdown)
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
                                    .fill(Color.white.opacity(0.06))
                            )
                            .font(.system(size: 11))

                            // Timer summary text at the bottom
                            Text(timerSummaryText)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 6)

                // Footer tag
                Text("v1.0 · Made by arj4ng")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)


            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .frame(width: 360)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 18)
        }
        .onAppear {
            // Detect initial state (in case caffeinate is already running)
            isAwake = isCaffeinateRunning()

            // Always create the status item once; visibility is controlled by updateCoffeinStatusItem
            if coffeinStatusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

                if let button = item.button {
                    button.image = nil
                    button.title = ""
                    button.toolTip = "Coffein"
                    button.target = NSApp
                    button.action = #selector(NSApplication.bringCoffeinToFront(_:))
                }

                coffeinStatusItem = item
            }

            // Sync current state to the status item (will hide it if not awake)
            updateCoffeinStatusItem(isAwake: isAwake)

            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.hasShadow = false

                    // Ensure content fills the full frame and the window is non-resizable
                    var style = window.styleMask
                    style.insert(.titled)
                    style.insert(.fullSizeContentView)
                    style.insert(.closable)
                    style.insert(.miniaturizable)
                    style.remove(.resizable)
                    window.styleMask = style
                    window.isMovableByWindowBackground = true

                    if let contentView = window.contentView {
                        // Make sure layout is up-to-date before measuring
                        contentView.layoutSubtreeIfNeeded()
                        let size = contentView.fittingSize
                        window.setContentSize(size)
                        window.minSize = size
                    }

                    // Hide native traffic lights
                    window.standardWindowButton(.closeButton)?.isHidden = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                }
            }
        }
        .onChange(of: isAwake) { newValue in
            // Status item is created once on appear; here we just update visibility & glyph
            updateCoffeinStatusItem(isAwake: newValue)
        }
    }

    // MARK: - Timer helpers (UI)

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

    // MARK: - Timer helpers (logic)

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
                    // Current behavior: just turn Coffein off
                    isAwake = false
                    stopCaffeinate()
                case .shutdown:
                    // Stop caffeinate first, then shut down the Mac
                    stopCaffeinate()
                    _ = shell("osascript -e 'tell application \"System Events\" to shut down'")
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

    func applyCustomMinutes() {
        let totalMinutes = customHours * 60 + customMinutes
        guard totalMinutes > 0 else { return }
        selectedDuration = TimeInterval(totalMinutes * 60)
        scheduleOffTimerIfNeeded()
    }

    // MARK: - Shell helpers

    func runCaffeinate() {
        _ = shell("nohup caffeinate -di >/dev/null 2>&1 &")
    }

    func stopCaffeinate() {
        _ = shell("killall caffeinate")
    }

    func isCaffeinateRunning() -> Bool {
        let result = shell("pgrep caffeinate")
        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    @discardableResult
    func shell(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/bash"

        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
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
