import AppKit
import SwiftUI

@main
struct SilenzioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var mic = MicController()
    @StateObject private var settings = SettingsStore()
    @StateObject private var hotkeys = HotkeyManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(mic: mic, hotkeys: hotkeys, settings: settings)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(settings: settings, hotkeys: hotkeys)
        }
        .defaultSize(width: 420, height: 370)

        // Explicit window fallback — more reliable than Settings for agent apps.
        Window("Silenzio Preferences", id: PreferencesPresenter.windowID) {
            PreferencesView(settings: settings, hotkeys: hotkeys)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 370)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let symbol = mic.isMuted ? "mic.slash.fill" : "mic.fill"
        let showBadge = settings.statusBarDisplay == .iconAndBadge

        if showBadge {
            Label {
                Text(mic.isMuted ? "Muted" : "Live")
            } icon: {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(mic.isMuted ? SilenzioTheme.muteRed : Color.primary)
            }
        } else {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(mic.isMuted ? SilenzioTheme.muteRed : Color.primary)
        }
    }
}

/// Reads `openSettings` / `openWindow` from the MenuBarExtra scene environment
/// (these are no-ops when captured on the `App` type itself).
private struct MenuBarRootView: View {
    @ObservedObject var mic: MicController
    @ObservedObject var hotkeys: HotkeyManager
    @ObservedObject var settings: SettingsStore

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarPopoverView(
            mic: mic,
            hotkeys: hotkeys,
            settings: settings,
            openPreferences: {
                PreferencesPresenter.open(openWindow: openWindow)
            }
        )
        .onAppear {
            hotkeys.configure(mic: mic, settings: settings)
        }
    }
}

enum PreferencesPresenter {
    static let windowID = "preferences"

    @MainActor
    static func open(openWindow: OpenWindowAction) {
        NSApp.activate(ignoringOtherApps: true)

        // Named Window is the reliable path for LSUIElement / accessory apps.
        // Settings + openSettings are often no-ops when the app has no Dock icon.
        openWindow(id: windowID)

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID || $0.title.contains("Preferences") }) {
                window.collectionBehavior.insert(.moveToActiveSpace)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
