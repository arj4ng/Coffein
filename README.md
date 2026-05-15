# Coffein

Native macOS utility to keep your Mac awake on demand with a focused menu bar workflow, timers, and battery-aware safety controls.

![Coffein App Icon](Coffein/Assets.xcassets/AppIcon.appiconset/1024x1024.png)

## Why This Project

I built Coffein as a lightweight alternative to terminal-first sleep prevention workflows, with emphasis on:

- Native macOS behavior (`SwiftUI` + `AppKit`)
- Fast menu bar access
- Clear and reversible power management
- Safety controls for battery-powered usage

## Features

- One-click awake/idle toggle
- Sleep assertion modes:
  - System + Display
  - System only
  - Display only
- Quick timer presets from UI and menu bar
- Custom timer with selectable end action
- Battery safety threshold that can block activation and auto-deactivate
- Launch at login support
- Custom status item tooltip and live timer state in menu bar

## Architecture

### UI Layer

- `Coffein/ContentView.swift`
  - Main window UI
  - Toggle interactions
  - Timer controls
  - Settings overlay

- `Coffein/SettingsView.swift`
  - Appearance, power behavior, battery threshold, login launch

- `Coffein/AboutView 2.swift`
  - About panel content used by the AppKit delegate

### App Shell + Menu Bar Integration

- `Coffein/CoffeinApp.swift`
  - SwiftUI app entry point
  - `NSApplicationDelegate` bridge
  - Custom AppKit app menu creation
  - Status bar item and menu lifecycle
  - Reassertion logic for menu consistency across window state transitions

### Core Logic

- `Coffein/Coffein/CoffeinManager.swift`
  - Source of truth for app state
  - Timer state and transitions
  - Battery threshold logic
  - Sleep mode switching
  - Launch-at-login management

- `CoffeinSleepManager` (inside `CoffeinManager.swift`)
  - Wraps `IOKit` power assertions:
    - `kIOPMAssertPreventUserIdleSystemSleep`
    - `kIOPMAssertPreventUserIdleDisplaySleep`
  - Handles releasing assertions and optional system sleep action

## Technical Highlights

- Uses native macOS power assertions instead of shelling out to `caffeinate`
- Blends declarative SwiftUI state with AppKit menu bar control where needed
- Includes battery-aware fail-safe behavior for laptop usage
- Handles timer end actions and resume behavior consistently

## Build

1. Open `Coffein.xcodeproj` in Xcode.
2. Select the `Coffein` scheme.
3. Build and run on macOS.

## Roadmap

- Add automated tests for timer and battery logic
- Add screenshot gallery and short demo GIF
- Polish helper target integration and project organization

## Screenshots

Screenshots will be added soon.

## License

MIT License. See [LICENSE](LICENSE).

