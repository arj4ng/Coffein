//
//  SettingsView.swift
//  Coffein
//
//  Created by Arjang Khademi on 07.12.25.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var coffeinManager: CoffeinManager
    
    @AppStorage("coffein_theme_mode") private var themeModeRaw: String = CoffeinThemeMode.system.rawValue

    private var themeModeBinding: Binding<CoffeinThemeMode> {
        Binding(
            get: { CoffeinThemeMode(rawValue: themeModeRaw) ?? .system },
            set: { themeModeRaw = $0.rawValue }
        )
    }
    
    /// Provided by ContentView so the settings overlay can dismiss itself
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            SettingsBackground(colorScheme: colorScheme)
            
            VStack(alignment: .leading, spacing: 16) { // Adjusted VStack spacing
                SettingsHeaderView(colorScheme: colorScheme, onClose: onClose)
                
                Text("General")
                    .font(.headline) // Changed to headline style
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 16) // Adjusted padding
                
                SettingsGeneralSection(colorScheme: colorScheme, launchAtLogin: $coffeinManager.launchAtLogin)
                
                Text("Appearance")
                    .font(.headline) // Changed to headline style
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 16) // Adjusted padding
                
                SettingsAppearanceSection(themeModeBinding: themeModeBinding)
                
                Text("Power")
                    .font(.headline) // Changed to headline style
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 16) // Adjusted padding
                
                SettingsPowerSection(selectedMode: $coffeinManager.sleepMode)

                Text("Battery Safety")
                    .font(.headline)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
                
                SettingsBatterySafetySection(batteryDeactivationThreshold: $coffeinManager.batteryDeactivationThreshold)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20) // Adjusted horizontal padding
            .padding(.vertical, 16) // Adjusted vertical padding
            .onAppear {
                coffeinManager.checkLaunchAtLogin()
            }
        }
    }
}

private struct SettingsBackground: View {
    let colorScheme: ColorScheme

    var body: some View {
        // Glass / card background – liquid style
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colorScheme == .dark
                    ? [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.02)
                    ]
                    : [
                        Color.white.opacity(0.75),
                        Color.white.opacity(0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                // Outer border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark
                            ? [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.08)
                            ]
                            : [
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                // Inner highlight at the top for extra glass feel
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.35 : 0.55),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 2
                    )
                    .blur(radius: 8)
                    .opacity(0.8)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.25), radius: 28, x: 0, y: 18)
    }
}

private struct SettingsHeaderView: View {
    let colorScheme: ColorScheme
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) { // Adjusted HStack spacing
            VStack(alignment: .leading, spacing: 4) { // Adjusted VStack spacing
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold)) // Adjusted font size and weight
                
                Text("Fine-tune how Coffein behaves")
                    .font(.subheadline) // Changed to subheadline style
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold)) // Slightly increased font size
                    .padding(8) // Adjusted padding
                    .background(
                        Circle().fill(
                            colorScheme == .dark
                            ? Color.white.opacity(0.16)
                            : Color.black.opacity(0.08)
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SettingsGeneralSection: View {
    let colorScheme: ColorScheme
    @Binding var launchAtLogin: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Adjusted VStack spacing
            HStack(alignment: .top, spacing: 12) { // Adjusted HStack spacing
                Image(systemName: "clock.arrow.circlepath")
                    .font(.body.weight(.semibold)) // Changed to body style, semibold
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) { // Adjusted VStack spacing
                    Toggle("Start Coffein at login", isOn: $launchAtLogin)
                        .font(.body) // Changed to body style

                    Text("Keep Coffein ready in your menu bar right after logging into macOS.")
                        .font(.subheadline) // Changed to subheadline style
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16) // Adjusted padding
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03)
                )
        )
    }
}

private struct SettingsAppearanceSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var themeModeBinding: CoffeinThemeMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Adjusted VStack spacing
            HStack(alignment: .center, spacing: 12) { // Adjusted HStack spacing
                Image(systemName: "moon.stars.circle.fill")
                    .font(.body.weight(.semibold)) // Changed to body style, semibold
                    .foregroundColor(.secondary)

                Text("Theme")
                    .font(.body) // Changed to body style

                Spacer(minLength: 8)

                Picker("", selection: $themeModeBinding) {
                    ForEach(CoffeinThemeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .frame(maxWidth: 120)
                .font(.callout) // Applied font to picker text
            }

            Text("Choose how Coffein looks")
                .font(.subheadline) // Changed to subheadline style
                .foregroundColor(.secondary)
        }
        .padding(16) // Adjusted padding
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03)
                )
        )
    }
}

private struct SettingsPowerSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedMode: CoffeinSleepMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Adjusted VStack spacing
            HStack(alignment: .center, spacing: 12) { // Adjusted HStack spacing
                Image(systemName: "bolt.fill")
                    .font(.body.weight(.semibold)) // Changed to body style, semibold
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) { // Adjusted VStack spacing
                    Text("Behavior")
                        .font(.body) // Changed to body style
                        .layoutPriority(1)
                }

                Spacer(minLength: 8)

                Picker("", selection: $selectedMode) {
                    ForEach(CoffeinSleepMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .frame(maxWidth: 150)
                .font(.callout) // Applied font to picker text
            }

            Text(selectedMode.modeDescription)
                .font(.subheadline) // Changed to subheadline style
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16) // Adjusted padding
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03)
                )
        )
    }
}

// NEW: Private struct for Battery Safety Section
private struct SettingsBatterySafetySection: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var batteryDeactivationThreshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "battery.100") // A relevant SF Symbol for battery
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack { // Added HStack for Text and Percentage
                        Text("Deactivate Coffein when battery is below:")
                            .font(.body)
                        Spacer()
                        Text("\(batteryDeactivationThreshold)%")
                            .font(.body.monospacedDigit())
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(batteryDeactivationThreshold) },
                            set: { batteryDeactivationThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    ) {
                        Text("Threshold")
                    } minimumValueLabel: {
                        Text("0%")
                    } maximumValueLabel: {
                        Text("100%")
                    }
                    .controlSize(.small)
                    
                    Text("Coffein will automatically deactivate and stop any active timers if your battery level drops below this percentage.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.03)
                )
        )
    }
}
