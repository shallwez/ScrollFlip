import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let settings = ScrollSettings.shared
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popover.contentSize = NSSize(width: 330, height: 380)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: SettingsView().environmentObject(settings)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "滚动翻转")
            button.action = #selector(togglePopover)
            button.target = self
        }

        if settings.hasAccessibilityPermission {
            settings.startMonitoring()
        } else {
            // Ask on first launch; the menu popover also keeps a manual route to
            // System Settings in case the user dismisses the system prompt.
            settings.requestPermission()
        }
        settings.configureLaunchAtLogin()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.settings.maintenanceTick()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        settings.stopMonitoring()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            settings.refreshPermissionState()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

}
