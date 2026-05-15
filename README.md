<p align="center">
  <img src="Coffein/Assets.xcassets/AppIcon.appiconset/1024x1024.png" alt="Coffein icon" width="110" />
</p>

<h1 align="center">Coffein</h1>
<p align="center">A small native macOS app to keep your Mac awake when you need it, with quick timer controls and a menu bar workflow.</p>

## Overview

I built Coffein because I wanted something simpler than jumping to Terminal whenever I needed to prevent sleep.
It gives you a clean native interface, fast menu bar access, and practical safety controls for laptop use.

Under the hood, it uses macOS power assertions through `IOKit` and combines `SwiftUI` with `AppKit` where the menu bar and window lifecycle need tighter control.

## What It Does

- One-click awake/idle toggle
- Sleep assertion modes (`System + Display`, `System only`, `Display only`)
- Timer presets and custom timer
- Configurable timer end behavior
- Battery safety threshold (can block activation and auto-deactivate)
- Launch at login support
- Live menu bar tooltip updates

## Project Structure

### UI

- `Coffein/ContentView.swift`  
  Main window, awake toggle flow, timer controls, settings overlay.
- `Coffein/SettingsView.swift`  
  Theme, sleep mode, launch-at-login, battery safety threshold.
- `Coffein/AboutView 2.swift`  
  About panel content.

### App Shell and Menu Bar Integration

- `Coffein/CoffeinApp.swift`
  - SwiftUI app entry point
  - `NSApplicationDelegate` bridge
  - custom app menu + status item setup
  - menu reassertion logic for minimize/restore transitions

### Core Logic

- `Coffein/Coffein/CoffeinManager.swift`
  - central app state
  - timer lifecycle and end-action handling
  - battery monitoring and activation gating
  - launch-at-login wiring

- `CoffeinSleepManager` (inside `CoffeinManager.swift`)
  - wraps `IOKit` sleep assertions
  - creates/releases system and display sleep prevention assertions

## Stack

- Swift 5
- SwiftUI
- AppKit
- Combine
- IOKit (`IOPMAssertion*`)
- ServiceManagement (`SMAppService`)

## Running Locally

1. Open `Coffein.xcodeproj`.
2. Select scheme `Coffein`.
3. Build and run on macOS.

## Notes

- Screenshots/demo clip will be added.
- Next technical step is adding tests around timer and battery behavior.

## License

MIT. See [LICENSE](LICENSE).
