import Foundation
import SwiftUI
import ServiceManagement
import IOKit.pwr_mgt
import IOKit.ps // NEW: Import IOKit.ps for battery monitoring
import Combine

enum CoffeinSleepMode: String, CaseIterable {
    /// Match classic `caffeinate -di`: prevent idle sleep and keep the display on.
    case systemAndDisplay

    /// Prevent system idle sleep but allow normal display sleep.
    case systemOnly

    /// Keep the display on, without explicitly blocking idle sleep.
    case displayOnly

    var displayName: String {
        switch self {
        case .systemAndDisplay:
            return "System + Display"
        case .systemOnly:
            return "System only"
        case CoffeinSleepMode.displayOnly:
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

class CoffeinManager: ObservableObject {
    // MARK: - Core State
    @Published var isAwake: Bool = true {
        didSet {
            print("[CoffeinManager] isAwake changed to: \(isAwake)")
            appStorageIsAwake = isAwake
            
            if isAwake {
                sleepManager.start(mode: sleepMode)
            } else {
                sleepManager.stop()
            }
        }
    }
    
    // MARK: - App Storage
    @AppStorage("isAwake") private var appStorageIsAwake: Bool = true
    private var _sleepModeRaw: String

    // MARK: - Battery Safety Feature
    @Published var batteryDeactivationThreshold: Int {
        didSet {
            UserDefaults.standard.set(batteryDeactivationThreshold, forKey: "batteryDeactivationThreshold")
            print("[CoffeinManager] batteryDeactivationThreshold set to: \(batteryDeactivationThreshold)%")
        }
    }

    // MARK: - Timer Properties
    @Published var timer: Timer?
    @Published var timeRemaining: TimeInterval = 0
    @Published var initialDuration: TimeInterval = 0
    
    // MARK: - Sleep Management
    internal var sleepManager = CoffeinSleepManager()
    @Published var sleepMode: CoffeinSleepMode
    
    // NEW: For battery monitoring
    private var batteryMonitorTimer: AnyCancellable?

    init() {
        _sleepModeRaw = UserDefaults.standard.string(forKey: "sleepMode") ?? CoffeinSleepMode.systemAndDisplay.rawValue
        self.sleepMode = CoffeinSleepMode(rawValue: _sleepModeRaw) ?? .systemAndDisplay
        
        // Initialize new batteryDeactivationThreshold
        self.batteryDeactivationThreshold = UserDefaults.standard.integer(forKey: "batteryDeactivationThreshold")
        if self.batteryDeactivationThreshold == 0 { // Default if not set, 0 is not a valid threshold
            self.batteryDeactivationThreshold = 20 // Default to 20%
        }
        
        // Read initial state for isAwake directly from UserDefaults to avoid premature property wrapper access
        let initialIsAwakeState = UserDefaults.standard.bool(forKey: "isAwake")
        self.isAwake = initialIsAwakeState // This will trigger the didSet
        
        print("[CoffeinManager] Initialized. isAwake: \(isAwake), sleepMode: \(sleepMode), batteryDeactivationThreshold: \(batteryDeactivationThreshold)%")
        
        if self.isAwake {
            sleepManager.start(mode: self.sleepMode)
        }
        
        // NEW: Start battery monitoring
        startBatteryMonitoring()
    }

    deinit {
        // NEW: Invalidate battery monitoring timer
        batteryMonitorTimer?.cancel()
    }

    // MARK: - NEW: Battery Monitoring Logic
    private func getBatteryLevel() -> Int? {
        guard let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            print("[CoffeinManager] Error: Could not get power source info.")
            return nil
        }

        guard let powerSourceList = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFDictionary] else {
            print("[CoffeinManager] Error: Could not get power source list.")
            return nil
        }

        for powerSource in powerSourceList {
            // Convert the CFDictionary to a Swift Dictionary
            guard let powerSourceDict = powerSource as? [String: Any] else {
                continue
            }

            // Check if it's a battery using the string literal
            if let isBattery = powerSourceDict["Is Battery"] as? Bool, isBattery {
                // Get current and max capacity using string literals
                if let currentCapacity = powerSourceDict["Current Capacity"] as? Int,
                   let maxCapacity = powerSourceDict["Max Capacity"] as? Int,
                   maxCapacity > 0 {
                    
                    let batteryLevel = (Double(currentCapacity) / Double(maxCapacity)) * 100
                    return Int(batteryLevel)
                }
            }
        }

        print("[CoffeinManager] No battery found or could not retrieve capacity information.")
        return nil
    }

    private func checkBatteryLevel() {
        if let currentBatteryPercentage = getBatteryLevel() {
            print("[CoffeinManager] Current battery level: \(currentBatteryPercentage)%")
            if isAwake && currentBatteryPercentage <= batteryDeactivationThreshold {
                print("[CoffeinManager] Battery level (\(currentBatteryPercentage)%) is at or below threshold (\(batteryDeactivationThreshold)%). Deactivating Coffein.")
                isAwake = false
                stopTimer()
                // Optionally, could show a notification to the user here
            }
        }
    }

    private func startBatteryMonitoring() {
        // Check battery level every 60 seconds
        batteryMonitorTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkBatteryLevel()
            }
        print("[CoffeinManager] Started battery monitoring.")
        // Perform an initial check immediately
        checkBatteryLevel()
    }

    // MARK: - Core Logic
    func toggleAwake() {
        print("[CoffeinManager] toggleAwake() called")
        isAwake.toggle()
    }
    
    func sleepModeChanged() {
        print("[CoffeinManager] sleepModeChanged() called. New mode: \(sleepMode.rawValue)")
        _sleepModeRaw = sleepMode.rawValue
        UserDefaults.standard.set(_sleepModeRaw, forKey: "sleepMode")
        if isAwake {
            print("[CoffeinManager] isAwake is true, restarting sleep assertions with new mode.")
            sleepManager.stop()
            sleepManager.start(mode: sleepMode)
        }
    }

    // MARK: - Timer Logic
    func startTimer(duration: TimeInterval) {
        print("[CoffeinManager] startTimer(duration: \(duration)) called")
        if !isAwake {
            isAwake = true
        }

        initialDuration = duration
        timeRemaining = duration
        
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                print("[CoffeinManager] Timer finished.")
                self.isAwake = false
                self.stopTimer()
                self.macSleep()
            }
        }
    }

    func stopTimer() {
        print("[CoffeinManager] stopTimer() called")
        timer?.invalidate()
        timer = nil
        timeRemaining = 0
        initialDuration = 0
    }
    
    func pauseTimer() {
        print("[CoffeinManager] pauseTimer() called")
        timer?.invalidate()
        timer = nil
    }
    
    func resumeTimer() {
        print("[CoffeinManager] resumeTimer() called")
        guard timeRemaining > 0 else {
            print("[CoffeinManager] No time remaining, not resuming.")
            return
        }
        startTimer(duration: timeRemaining)
    }

    // MARK: - System Actions
    func macSleep() {
        print("[CoffeinManager] macSleep() called")
        sleepManager.sleep()
    }

    // MARK: - Settings
    @Published var launchAtLogin: Bool = false {
        didSet {
            print("[CoffeinManager] launchAtLogin changed to: \(launchAtLogin)")
            setLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        print("[CoffeinManager] setLaunchAtLogin(enabled: \(enabled)) called")
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService().register()
                    print("[CoffeinManager] SMAppService registered.")
                } else {
                    try SMAppService().unregister()
                    print("[CoffeinManager] SMAppService unregistered.")
                }
            } catch {
                print("[CoffeinManager] Failed to update login item status: \(error)")
            }
        } else {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                print("[CoffeinManager] Error: Could not get bundle identifier.")
                return
            }
            if !SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("[CoffeinManager] SMLoginItemSetEnabled failed.")
            } else {
                print("[CoffeinManager] SMLoginItemSetEnabled succeeded.")
            }
        }
    }
    
    func checkLaunchAtLogin() {
        print("[CoffeinManager] checkLaunchAtLogin() called")
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService().status == .enabled
        } else {
            launchAtLogin = false
        }
        print("[CoffeinManager] launchAtLogin is: \(launchAtLogin)")
    }
}

class CoffeinSleepManager {
    private var idleAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    func start(mode: CoffeinSleepMode) {
        print("[CoffeinSleepManager] start(mode: \(mode.rawValue)) called")
        stop()
        
        let reason = "Coffein is active" as CFString

        if mode == .systemAndDisplay || mode == .systemOnly {
            print("[CoffeinSleepManager] Creating idle sleep assertion.")
            let result = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &idleAssertionID)
            if result != kIOReturnSuccess {
                print("[CoffeinSleepManager] Failed to create idle sleep assertion. Error: \(result)")
                idleAssertionID = 0
            }
        }

        if mode == .systemAndDisplay || mode == .displayOnly {
            print("[CoffeinSleepManager] Creating display sleep assertion.")
            let result = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &displayAssertionID)
            if result != kIOReturnSuccess {
                print("[CoffeinSleepManager] Failed to create display sleep assertion. Error: \(result)")
                displayAssertionID = 0
            }
        }
    }

    func stop() {
        print("[CoffeinSleepManager] stop() called")
        if idleAssertionID != 0 {
            print("[CoffeinSleepManager] Releasing idle sleep assertion.")
            IOPMAssertionRelease(idleAssertionID)
            idleAssertionID = 0
        }
        if displayAssertionID != 0 {
            print("[CoffeinSleepManager] Releasing display sleep assertion.")
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    func sleep() {
        print("[CoffeinSleepManager] sleep() called")
        let port: io_connect_t = IOPMFindPowerManagement(mach_port_t())
        if port != IO_OBJECT_NULL {
            IOPMSleepSystem(port)
            IOServiceClose(port)
        } else {
            print("[CoffeinSleepManager] Failed to find power management port.")
        }
    }
}


