import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var settingsWindow: NSWindow?
    var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host the app; don't create a menu bar item or start timers.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "newspaper", accessibilityDescription: "NewsDigest")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: DigestView())
        popover?.behavior = .transient
        popover?.animates = true

        // Setup menu
        setupMenu()

        // Initialize scheduler with background service
        SchedulerService.shared.apply(StorageService.shared.loadSettings())

        #if DEBUG
        // Developer aid for README screenshots: launch with `-screenshotMode popover|history|settings`.
        if let mode = UserDefaults.standard.string(forKey: "screenshotMode") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                switch mode {
                case "popover": self?.showPopover()
                case "history": self?.showHistory()
                case "settings":
                    self?.showSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.settingsWindow?.makeFirstResponder(nil) }
                default: break
                }
            }
        }
        #endif
    }

    @objc func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                showPopover()
            }
        }
    }

    func showPopover() {
        if let button = statusItem?.button, let popover = popover {
            // Update digest before showing
            DigestViewModel.shared.loadLatestDigest()

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Activate app to bring popover to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open Digest", action: #selector(togglePopover), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Generate New Digest", action: #selector(generateDigest), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "View History", action: #selector(showHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        // Assign menu to status item
        statusItem?.menu = menu
    }

    @objc func generateDigest() {
        // Show the popover straight away so the loading state is visible.
        showPopover()
        Task { await DigestViewModel.shared.generateDigest() }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsWindow()
            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "NewsDigest Settings"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable]
            settingsWindow?.setContentSize(NSSize(width: 680, height: 520))
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.center()
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showHistory() {
        if historyWindow == nil {
            let historyView = DigestHistoryView()
            let hostingController = NSHostingController(rootView: historyView)

            historyWindow = NSWindow(contentViewController: hostingController)
            historyWindow?.title = "Digest History"
            historyWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            historyWindow?.setContentSize(NSSize(width: 800, height: 600))
            historyWindow?.isReleasedWhenClosed = false
            historyWindow?.center()
        }

        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    // Handle right-click menu
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

