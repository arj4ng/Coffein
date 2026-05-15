<p align="center">
  <img src="Coffein/Assets.xcassets/AppIcon.appiconset/1024x1024.png" alt="Coffein icon" width="110" />
</p>

<h1 align="center">Coffein</h1>
<p align="center">Native macOS utility to keep your Mac awake with timer controls and menu bar-first UX.</p>

## Overview

Coffein is a SwiftUI + AppKit desktop utility that manages macOS sleep assertions through a clean UI and quick menu bar actions.  
It is designed as a lightweight, native alternative to terminal-based sleep-prevention workflows.

## Core Features

- One-click awake/idle toggle
- Sleep assertion modes:
  - System + Display
  - System only
  - Display only
- Timer presets and custom timer
- Configurable timer end behavior
- Battery safety threshold (block activation / auto-deactivate)
- Launch at login support
- Live status updates in menu bar tooltip

## Architecture

### UI

- `Coffein/ContentView.swift`: main window, toggle flow, timer UI, settings overlay
- `Coffein/SettingsView.swift`: power mode, theme, launch-at-login, battery safety
- `Coffein/AboutView 2.swift`: About panel content

### App Shell and Menu Bar

- `Coffein/CoffeinApp.swift`
  - SwiftUI app entry
  - AppKit delegate bridge
  - custom app menu and status item lifecycle
  - menu reassertion logic for window-state transitions

### Domain and System Integration

- `Coffein/Coffein/CoffeinManager.swift`
  - central app state
  - timer lifecycle and end-action handling
  - battery monitoring and activation gating
  - launch-at-login wiring

- `CoffeinSleepManager` (inside `CoffeinManager.swift`)
  - wraps `IOKit` sleep assertions
  - creates/releases system and display sleep prevention assertions

## Tech Stack

- Swift 5
- SwiftUI
- AppKit
- Combine
- IOKit (`IOPMAssertion*`)
- ServiceManagement (`SMAppService`)

## Run Locally

1. Open `Coffein.xcodeproj`.
2. Select scheme `Coffein`.
3. Build and run on macOS.

## Roadmap

- Add targeted tests for timer and battery logic
- Add screenshots/demo clip
- Refine helper target integration

## License

MIT. See [LICENSE](LICENSE).
