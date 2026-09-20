import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hotkeys: HotkeyManager
    @ObservedObject var mic: MicController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            shortcutsLabel
            if !mic.hasMicrophoneAccess {
                microphonePermissionCard
            }
            settingsList
            footer
        }
        .frame(width: 420)
        .background(SilenzioTheme.preferencesBackground)
        .onAppear {
            mic.refreshMicrophoneAccess()
            hotkeys.refreshAccessibilityStatus(prompt: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            mic.refreshMicrophoneAccess()
        }
    }

    private var header: some View {
        Text("Preferences")
            .font(.system(size: 14, weight: .semibold))
            .tracking(-0.14)
            .foregroundStyle(SilenzioTheme.primaryLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.primary.opacity(0.02))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SilenzioTheme.separator)
                    .frame(height: 1)
            }
    }

    private var shortcutsLabel: some View {
        Text("SHORTCUTS")
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.55)
            .foregroundStyle(SilenzioTheme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 2)
    }

    private var microphonePermissionCard: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(hex: 0xFF9F0A).opacity(0.18))
                    .frame(width: 26, height: 26)
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF9F0A))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Microphone Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SilenzioTheme.primaryLabel)
                Text("Allow Silenzio to monitor and mute your input.")
                    .font(.system(size: 11))
                    .foregroundStyle(SilenzioTheme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Open Settings") {
                mic.openMicrophoneSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SilenzioTheme.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: 0xFF9F0A).opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: 0xFF9F0A).opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var settingsList: some View {
        VStack(spacing: 0) {
            shortcutRow
            divider
            muteModeRow
            divider
            launchRow
            divider
            statusDisplayRow
        }
        .background(SilenzioTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(SilenzioTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private var shortcutRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Global Mute / Unmute")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SilenzioTheme.primaryLabel)
                Text("Works system-wide")
                    .font(.system(size: 11))
                    .foregroundStyle(SilenzioTheme.secondaryLabel)
            }
            Spacer(minLength: 8)
            ShortcutRecorderView(shortcut: $hotkeys.shortcut)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
    }

    private var muteModeRow: some View {
        HStack {
            Text("Mute Mode")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SilenzioTheme.primaryLabel)
            Spacer()
            SegmentedPill(
                options: MuteMode.allCases,
                selection: Binding(
                    get: { settings.muteMode },
                    set: { settings.muteMode = $0 }
                ),
                title: { $0.title }
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private var launchRow: some View {
        HStack {
            Text("Launch at Login")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SilenzioTheme.primaryLabel)
            Spacer()
            Toggle("", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.launchAtLogin = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(SilenzioTheme.liveGreen)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private var statusDisplayRow: some View {
        HStack {
            Text("Status Bar Display")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SilenzioTheme.primaryLabel)
            Spacer()
            SegmentedPill(
                options: StatusBarDisplay.allCases,
                selection: Binding(
                    get: { settings.statusBarDisplay },
                    set: { settings.statusBarDisplay = $0 }
                ),
                title: { $0.title }
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private var divider: some View {
        Rectangle()
            .fill(SilenzioTheme.separator)
            .frame(height: 1)
            .padding(.leading, 14)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
            .background(SilenzioTheme.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SilenzioTheme.separator)
                .frame(height: 1)
        }
    }
}
