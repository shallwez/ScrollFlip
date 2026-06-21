import AppKit
import ApplicationServices
import Combine
import ServiceManagement

final class ScrollSettings: ObservableObject {
    static let shared = ScrollSettings()
    private static let syntheticEventMarker: Int64 = 0x5346_4C50

    private enum Keys {
        static let reverseVertical = "reverseVertical"
        static let speed = "scrollSpeed"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var reverseVertical: Bool {
        didSet { defaults.set(reverseVertical, forKey: Keys.reverseVertical) }
    }

    @Published var speed: Double {
        didSet { defaults.set(speed, forKey: Keys.speed) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isUpdatingLaunchAtLogin else { return }
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLoginPreference()
        }
    }

    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var isMonitoring = false

    private let defaults = UserDefaults.standard
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var slowScrollAccumulator = 0.0
    private var isUpdatingLaunchAtLogin = false

    private init() {
        defaults.register(defaults: [
            Keys.reverseVertical: true,
            Keys.speed: 1.0
        ])
        reverseVertical = defaults.bool(forKey: Keys.reverseVertical)
        speed = defaults.double(forKey: Keys.speed)
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) == nil
            ? true
            : defaults.bool(forKey: Keys.launchAtLogin)
        refreshPermissionState()
    }

    func configureLaunchAtLogin() {
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        applyLaunchAtLoginPreference()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        if hasAccessibilityPermission {
            startMonitoring()
        }
    }

    func refreshPermissionState() {
        let trusted = AXIsProcessTrusted()
        if hasAccessibilityPermission != trusted {
            hasAccessibilityPermission = trusted
        }
        if trusted && eventTap == nil {
            startMonitoring()
        }
    }

    func maintenanceTick() {
        if !hasAccessibilityPermission || eventTap == nil {
            refreshPermissionState()
        } else if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func startMonitoring() {
        guard eventTap == nil else { return }
        refreshPermissionOnly()
        guard hasAccessibilityPermission else { return }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                ScrollSettings.shared.reenableEventTap()
                return Unmanaged.passUnretained(event)
            }
            return ScrollSettings.shared.process(event: event)
        }

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        )

        guard let tap else {
            isMonitoring = false
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isMonitoring = true
    }

    func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        isMonitoring = false
    }

    fileprivate func reenableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    fileprivate func process(event: CGEvent) -> Unmanaged<CGEvent>? {
        // Events posted by this app pass through the tap again. The marker keeps
        // them from being processed recursively.
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0

        // If no transformation is requested, preserve the original event exactly.
        guard reverseVertical || speed != 1.0 else {
            return Unmanaged.passUnretained(event)
        }

        let verticalField: CGEventField = isContinuous
            ? .scrollWheelEventPointDeltaAxis1
            : .scrollWheelEventDeltaAxis1
        let horizontalField: CGEventField = isContinuous
            ? .scrollWheelEventPointDeltaAxis2
            : .scrollWheelEventDeltaAxis2
        let rawVertical = Double(event.getIntegerValueField(verticalField))
        let rawHorizontal = event.getIntegerValueField(horizontalField)
        guard rawVertical != 0 else { return Unmanaged.passUnretained(event) }
        let direction = reverseVertical ? -1.0 : 1.0
        var transformed = rawVertical * speed * direction

        if !isContinuous && speed < 1.0 {
            slowScrollAccumulator += transformed
            transformed = slowScrollAccumulator.rounded(.towardZero)
            slowScrollAccumulator -= transformed
        } else {
            slowScrollAccumulator = 0
        }

        let vertical = Int32(clamping: Int64(transformed.rounded()))
        let horizontal = Int32(clamping: rawHorizontal)
        guard vertical != 0 || horizontal != 0 else { return nil }

        let units: CGScrollEventUnit = isContinuous ? .pixel : .line
        guard let replacement = CGEvent(
            scrollWheelEvent2Source: nil,
            units: units,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else { return Unmanaged.passUnretained(event) }

        replacement.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
        replacement.post(tap: .cghidEventTap)
        return nil
    }

    private func refreshPermissionOnly() {
        let trusted = AXIsProcessTrusted()
        if hasAccessibilityPermission != trusted {
            hasAccessibilityPermission = trusted
        }
    }

    private func applyLaunchAtLoginPreference() {
        do {
            if launchAtLogin {
                let status = SMAppService.mainApp.status
                if status != .enabled && status != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled ||
                        SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            isUpdatingLaunchAtLogin = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            isUpdatingLaunchAtLogin = false
        }
    }

}
