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

struct ContentView: View {
    @State private var isAwake = false
    @State private var isPressing = false
    
    var body: some View {
        ZStack {
            // Subtle background for the whole window
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main card
            VStack(spacing: 22) {
                
                // Header row
                HStack {
                    Image(systemName: isAwake ? "sun.max.fill" : "moon.zzz.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 22, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coffein")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Control system sleep")
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
                    if isAwake { runCaffeinate() } else { stopCaffeinate() }
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
                            .frame(width: 120, height: 120)
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
                            .shadow(color: isAwake ? Color.green.opacity(0.7) : Color.black.opacity(0.6),
                                    radius: isAwake ? 18 : 10,
                                    x: 0, y: isAwake ? 10 : 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                        
                        // Icon
                        Image(systemName: isAwake ? "power.circle.fill" : "power")
                            .font(.system(size: 46, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(isPressing ? 0.96 : 1.0)
                }
                .buttonStyle(.plain)
                .pressEvents(onPress: { isPressing = true }, onRelease: { isPressing = false })
                
                // Description
                VStack(spacing: 4) {
                    Text(isAwake ? "Sleep prevention enabled" : "Mac will follow normal sleep settings")
                        .font(.system(size: 14, weight: .medium))
                    Text("Uses the built-in caffeinate command. You can close this window at any time.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            }
            .padding(24)
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
            .padding()
        }
        .onAppear {
            // Optional: sync UI with current caffeinate state on launch
            isAwake = isCaffeinateRunning()
        }
    }
    
    // MARK: - Shell helpers (unchanged)
    
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
