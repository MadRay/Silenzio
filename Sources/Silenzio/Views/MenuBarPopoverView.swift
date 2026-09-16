import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var mic: MicController
    @ObservedObject var hotkeys: HotkeyManager
    @ObservedObject var settings: SettingsStore
    var openPreferences: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusSection
            toggleSection
            deviceSection
            bottomBar
        }
        .padding(16)
        .frame(width: 320)
        .background(SilenzioTheme.popoverBackground)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                if mic.isMuted {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(SilenzioTheme.muteRed)
                            .frame(width: 6, height: 6)
                        Text("MUTED")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.11)
                            .foregroundStyle(SilenzioTheme.muteBadgeText)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(SilenzioTheme.muteRedSoft)
                    .overlay(
                        Capsule().stroke(SilenzioTheme.muteRedBorder, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                } else {
                    Circle()
                        .fill(SilenzioTheme.liveGreen)
                        .frame(width: 9, height: 9)
                        .shadow(color: SilenzioTheme.liveGreen.opacity(0.8), radius: 4)
                }

                Text(mic.isMuted ? "Microphone Muted" : "Microphone Live")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundStyle(SilenzioTheme.primaryLabel)

                Spacer(minLength: 0)

                Text(levelText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(mic.isMuted ? SilenzioTheme.tertiaryLabel : SilenzioTheme.secondaryLabel)
            }
            .frame(height: 20)

            AudioMeterView(isMuted: mic.isMuted, level: mic.inputLevel)
        }
    }

    private var levelText: String {
        if mic.isMuted { return "-∞ dB" }
        let db = mic.decibelLevel
        if db <= -100 { return "-∞ dB" }
        return String(format: "%.0f dB", db)
    }

    // MARK: - Toggle

    private var toggleSection: some View {
        VStack(spacing: 8) {
            Button(action: { mic.toggleMute() }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(mic.isMuted ? SilenzioTheme.muteRed : SilenzioTheme.liveGreen)
                            .frame(width: 40, height: 40)
                            .shadow(
                                color: (mic.isMuted ? SilenzioTheme.muteRed : SilenzioTheme.liveGreen).opacity(0.4),
                                radius: 8
                            )
                        Image(systemName: mic.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(mic.isMuted ? Color.white : SilenzioTheme.liveGreenIcon)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(mic.isMuted ? "Click to Unmute" : "Click to Mute")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.15)
                            .foregroundStyle(SilenzioTheme.primaryLabel)
                        Text(mic.isMuted ? "Input is muted" : "Input is live")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(mic.isMuted ? SilenzioTheme.muteRedText : SilenzioTheme.liveGreenText)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64)
                .background(mic.isMuted ? SilenzioTheme.muteRedSoft : SilenzioTheme.liveGreenSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(mic.isMuted ? SilenzioTheme.muteRedBorder : SilenzioTheme.liveGreenBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            if mic.isMuted {
                HStack(spacing: 6) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(SilenzioTheme.secondaryLabel)
                    Text(mic.usesVolumeFallback ? "Input muted via volume fallback" : "Input muted at hardware level")
                        .font(.system(size: 12))
                        .foregroundStyle(SilenzioTheme.secondaryLabel)
                }
            } else {
                HStack(spacing: 5) {
                    Text("Click or press")
                        .font(.system(size: 12))
                        .foregroundStyle(SilenzioTheme.secondaryLabel)
                    ShortcutChip(text: hotkeys.shortcutDisplay)
                    Text("to mute")
                        .font(.system(size: 12))
                        .foregroundStyle(SilenzioTheme.secondaryLabel)
                }
            }
        }
    }

    // MARK: - Device

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("INPUT DEVICE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.55)
                .foregroundStyle(SilenzioTheme.secondaryLabel)

            Menu {
                ForEach(mic.availableDevices) { device in
                    Button {
                        mic.selectDevice(device.id)
                    } label: {
                        HStack {
                            Text(device.name)
                            if device.id == mic.deviceID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(mic.isMuted ? SilenzioTheme.tertiaryLabel : SilenzioTheme.liveGreen)
                        .frame(width: 6, height: 6)
                    Text(mic.deviceName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SilenzioTheme.primaryLabel)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SilenzioTheme.secondaryLabel)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38)
                .background(SilenzioTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(SilenzioTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Button(action: openPreferences) {
                HStack(spacing: 6) {
                    Text("Preferences")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SilenzioTheme.primaryLabel.opacity(0.8))
                    Text("⌘,")
                        .font(.system(size: 12))
                        .foregroundStyle(SilenzioTheme.tertiaryLabel)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Text("Quit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SilenzioTheme.primaryLabel.opacity(0.8))
                    Text("⌘Q")
                        .font(.system(size: 12))
                        .foregroundStyle(SilenzioTheme.tertiaryLabel)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SilenzioTheme.separator)
                .frame(height: 1)
        }
    }
}
