import Foundation
import os

/// Reads and changes the macOS "Natural scrolling" setting.
///
/// The Trackpad and Mouse panes in System Settings share one global default,
/// `com.apple.swipescrolldirection`. Writing that default only takes effect after
/// the next login, so the change is also pushed to the running session through a
/// private function in PreferencePanesSupport.framework.
@MainActor
enum ScrollDirection {
    /// Posted by System Settings and by Deskflip when the setting changes.
    static let didChangeNotification = Notification.Name("SwipeScrollDirectionDidChangeNotification")

    private static let defaultsKey = "com.apple.swipescrolldirection"
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport"
    private static let logger = Logger(subsystem: "io.github.ardakyncu.deskflip", category: "ScrollDirection")

    private typealias SetSwipeScrollDirection = @convention(c) (Bool) -> Void

    /// The private setter, loaded once at runtime. `nil` if the framework or symbol is missing.
    private static let setSwipeScrollDirection: SetSwipeScrollDirection? = {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            logger.error("Could not load PreferencePanesSupport, changes will apply after the next login")
            return nil
        }
        guard let symbol = dlsym(handle, "setSwipeScrollDirection") else {
            logger.error("setSwipeScrollDirection is missing, changes will apply after the next login")
            return nil
        }
        return unsafeBitCast(symbol, to: SetSwipeScrollDirection.self)
    }()

    /// Whether natural scrolling is on. A missing value means the macOS default, which is on.
    static var isNatural: Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        // Accepts booleans, numbers and "YES"/"NO" strings.
        var isValid: DarwinBoolean = false
        let value = CFPreferencesGetAppBooleanValue(defaultsKey as CFString, kCFPreferencesAnyApplication, &isValid)
        return isValid.boolValue ? value : true
    }

    /// Whether a change takes effect right away instead of after the next login.
    static var appliesImmediately: Bool {
        setSwipeScrollDirection != nil
    }

    /// Saves the setting, applies it to the running session and tells other apps about it.
    /// Returns `false` if the setting could not be saved.
    @discardableResult
    static func setNatural(_ natural: Bool) -> Bool {
        guard writeDefault(natural) else { return false }
        setSwipeScrollDirection?(natural)
        DistributedNotificationCenter.default().postNotificationName(
            didChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return true
    }

    /// Writes the global default through `/usr/bin/defaults`. `UserDefaults` is unreliable
    /// for the global domain, and replacing the persistent domain would wipe other settings.
    private static func writeDefault(_ natural: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "-g", defaultsKey, "-bool", natural ? "YES" : "NO"]
        do {
            try process.run()
        } catch {
            logger.error("Could not run defaults: \(error.localizedDescription, privacy: .public)")
            return false
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            logger.error("defaults exited with status \(process.terminationStatus)")
            return false
        }
        return true
    }
}
