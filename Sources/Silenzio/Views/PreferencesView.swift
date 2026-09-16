import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var hotkeys: HotkeyManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: PreferencesTab = .shortcuts

    private enum PreferencesTab: String, CaseIterable, Identifiable {
        case general
        case shortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .shortcuts: return "Shortcuts"
            }
        }

        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "keyboard"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            settingsList
            footer
        }
        .frame(width: 420)
        .background(SilenzioTheme.preferencesBackground)
        .onAppear {
            hotkeys.refreshAccessibilityStatus(prompt: false)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(PreferencesTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(selectedTab == tab ? SilenzioTheme.primaryLabel : SilenzioTheme.secondaryLabel)
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(selectedTab == tab ? SilenzioTheme.primaryLabel : SilenzioTheme.secondaryLabel)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selectedTab == tab ? Color.primary.opacity(0.10) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(Color.primary.opacity(0.02))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SilenzioTheme.separator)
                .frame(height: 1)
        }
    }

    private var settingsList: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .shortcuts:
                shortcutRow
                divider
                muteModeRow
                divider
                launchRow
                divider
                statusDisplayRow
            case .general:
                launchRow
                divider
                statusDisplayRow
                divider
                accessibilityRow
            }
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

    private var accessibilityRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Access")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SilenzioTheme.primaryLabel)
                Text(hotkeys.isAccessibilityTrusted ? "Granted — push-to-talk release works globally" : "Recommended for push-to-talk key release")
                    .font(.system(size: 11))
                    .foregroundStyle(SilenzioTheme.secondaryLabel)
            }
            Spacer()
            if hotkeys.isAccessibilityTrusted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SilenzioTheme.liveGreen)
            } else {
                Button("Enable…") {
                    hotkeys.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
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
