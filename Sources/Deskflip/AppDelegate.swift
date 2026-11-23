import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var naturalScrollingItem: NSMenuItem!
    private var openAtLoginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // VoiceOver and keyboard users cannot right-click, so offer the menu as an action.
            button.setAccessibilityCustomActions([
                NSAccessibilityCustomAction(name: "Show Menu", target: self, selector: #selector(showMenuForAccessibility)),
            ])
        }

        menu = makeMenu()

        // Menu bar apps are rarely the active app, so ask for delivery even while suspended.
        // Otherwise changes made in System Settings would only arrive much later.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(scrollDirectionDidChange(_:)),
            name: ScrollDirection.didChangeNotification,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        refresh()
    }

    // MARK: - Status item

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            showMenu()
        } else {
            toggleNaturalScrolling()
        }
    }

    private func showMenu() {
        // Attach the menu only while it is open, so a left-click keeps toggling.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    @objc private func showMenuForAccessibility() -> Bool {
        showMenu()
        return true
    }

    @objc private func scrollDirectionDidChange(_ notification: Notification) {
        refresh()
    }

    private func toggleNaturalScrolling() {
        let natural = !ScrollDirection.isNatural
        if !ScrollDirection.setNatural(natural) {
            showAlert(
                title: "Couldn't change natural scrolling",
                message: "Deskflip could not save the setting. You can still change it in System Settings."
            )
        }
        refresh()
    }

    private func refresh() {
        let natural = ScrollDirection.isNatural
        if let button = statusItem.button {
            button.image = StatusIcon.image(natural: natural)
            var toolTip = natural
                ? "Natural scrolling: On (click to turn off)"
                : "Natural scrolling: Off (click to turn on)"
            if !ScrollDirection.appliesImmediately {
                toolTip += "\nChanges apply after you log out and back in."
            }
            button.toolTip = toolTip
        }
        naturalScrollingItem.state = natural ? .on : .off
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        naturalScrollingItem = NSMenuItem(
            title: "Natural scrolling",
            action: #selector(naturalScrollingItemClicked(_:)),
            keyEquivalent: ""
        )
        naturalScrollingItem.target = self
        menu.addItem(naturalScrollingItem)

        openAtLoginItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(openAtLoginItemClicked(_:)),
            keyEquivalent: ""
        )
        openAtLoginItem.target = self
        menu.addItem(openAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Deskflip",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        openAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    @objc private func naturalScrollingItemClicked(_ sender: NSMenuItem) {
        toggleNaturalScrolling()
    }

    @objc private func openAtLoginItemClicked(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showAlert(title: "Couldn't change Open at Login", message: error.localizedDescription)
            return
        }

        if service.status == .requiresApproval {
            let openSettings = showAlert(
                title: "Allow Deskflip to open at login",
                message: "Turn on Deskflip in System Settings under General, Login Items.",
                buttons: ["Open System Settings", "Cancel"]
            )
            if openSettings == .alertFirstButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    // MARK: - Alerts

    @discardableResult
    private func showAlert(title: String, message: String, buttons: [String] = []) -> NSApplication.ModalResponse {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        for button in buttons {
            alert.addButton(withTitle: button)
        }
        return alert.runModal()
    }
}
