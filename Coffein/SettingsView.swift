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
            
            VStack(alignment: .leading, spacing: 14) {
                SettingsHeaderView(colorScheme: colorScheme, onClose: onClose)
                
                Text("General")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                
                SettingsGeneralSection(colorScheme: colorScheme, launchAtLogin: $coffeinManager.launchAtLogin)
                
                Text("Appearance")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                SettingsAppearanceSection(themeModeBinding: themeModeBinding)
                
                Text("Power")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                SettingsPowerSection(selectedMode: $coffeinManager.sleepMode)
                
                Spacer(minLength: 0)
            }
            .padding(20)
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                
                Text("Fine-tune how Coffein behaves")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .padding(6)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Toggle("Start Coffein at login", isOn: $launchAtLogin)
                        .font(.system(size: 13, weight: .medium))

                    Text("Keep Coffein ready in your menu bar right after logging into macOS.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "moon.stars.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("Theme")
                    .font(.system(size: 13, weight: .medium))

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
            }

            Text("Choose how Coffein looks")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Behavior")
                        .font(.system(size: 13, weight: .medium))
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
            }

            Text(selectedMode.modeDescription)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
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
