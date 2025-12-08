//
//  SettingsView.swift
//  Coffein
//
//  Created by Arjang Khademi on 07.12.25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    /// Provided by ContentView so the settings overlay can dismiss itself
    let onClose: () -> Void
    
    @State private var selectedMode: CoffeinSleepMode
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _selectedMode = State(initialValue: CoffeinSleepManager.shared.mode)
    }
    
    var body: some View {
        ZStack {
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
            
            VStack(alignment: .leading, spacing: 18) {
                
                // MARK: Header
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        
                        Text("Fine-tune how Coffein behaves.")
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
                
                // MARK: General section label
                Text("General")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                // MARK: General section card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start Coffein at login")
                                .font(.system(size: 13, weight: .medium))

                            Text("Coming soon")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text("You'll be able to keep Coffein ready in your menu bar right after logging into macOS.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
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

                // MARK: Power section card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Behavior")
                                .font(.system(size: 13, weight: .medium))
                                .layoutPriority(1) // prefer truncating other views before this

                        }

                        Spacer(minLength: 8)

                        Picker("", selection: $selectedMode) {
                            ForEach(CoffeinSleepMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()              // keep the menu tight
                        .frame(maxWidth: 150)     // don't push too far into the text
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
                
                Spacer(minLength: 0)
            }
            .padding(20)
            .onChange(of: selectedMode) { _, newMode in
                CoffeinSleepManager.shared.configure(mode: newMode)
            }
        }
    }
}
