import Foundation
import ServiceManagement
import SwiftUI

enum MuteMode: String, CaseIterable, Identifiable {
    case toggle
    case pushToTalk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggle: return "Toggle"
        case .pushToTalk: return "Push-to-Talk"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @AppStorage("muteMode") var muteModeRaw: String = MuteMode.toggle.rawValue
    @AppStorage("launchAtLogin") private var launchAtLoginStored: Bool = false

    var muteMode: MuteMode {
        get { MuteMode(rawValue: muteModeRaw) ?? .toggle }
        set { muteModeRaw = newValue.rawValue }
    }

    var launchAtLogin: Bool {
        get { launchAtLoginStored }
        set {
            launchAtLoginStored = newValue
            updateLaunchAtLogin(enabled: newValue)
        }
    }

    init() {
        syncLaunchAtLoginFromSystem()
    }

    private func syncLaunchAtLoginFromSystem() {
        launchAtLoginStored = SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Silenzio: launch-at-login update failed: \(error.localizedDescription)")
            syncLaunchAtLoginFromSystem()
        }
    }
}
