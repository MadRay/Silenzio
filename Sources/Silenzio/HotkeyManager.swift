import AppKit
import ApplicationServices
import Carbon
import SwiftUI

/// Persisted global shortcut (Carbon key code + modifiers).
struct HotkeyShortcut: Equatable, Codable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = HotkeyShortcut(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey)
    )

    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " ")
    }

    var keyLabel: String {
        Self.keyName(for: keyCode)
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "Esc"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default:
            return "Key\(keyCode)"
        }
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8,
             kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15,
             kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20:
            return true
        default:
            return false
        }
    }

    static func from(nsEvent event: NSEvent) -> HotkeyShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }

        let modifierOnly: Set<UInt16> = [56, 60, 59, 62, 58, 61, 55, 54, 63]
        guard !modifierOnly.contains(event.keyCode) else { return nil }

        // Require a modifier, except for function keys (F1–F20) which are valid alone.
        if carbon == 0 && !isFunctionKey(event.keyCode) {
            return nil
        }

        return HotkeyShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
    }
}

@MainActor
final class HotkeyManager: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published var shortcut: HotkeyShortcut {
        didSet {
            persistShortcut()
            shortcutDisplay = shortcut.displayString
            registerHotKey()
        }
    }
    @Published private(set) var shortcutDisplay: String

    private weak var mic: MicController?
    private weak var settings: SettingsStore?
    private var isPushToTalkHeld = false
    private var permissionTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private static let hotKeyID = EventHotKeyID(signature: OSType(0x534C4E5A), id: 1) // 'SLNZ'
    private static let storageKey = "silenzio.hotkey"

    init() {
        let loaded: HotkeyShortcut
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(HotkeyShortcut.self, from: data) {
            loaded = decoded
        } else {
            loaded = .default
        }
        shortcut = loaded
        shortcutDisplay = loaded.displayString

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityStatus(prompt: false)
            }
        }
    }

    func configure(mic: MicController, settings: SettingsStore) {
        self.mic = mic
        self.settings = settings
        installCarbonHandler()
        registerHotKey()
        refreshAccessibilityStatus(prompt: true)
    }

    func refreshAccessibilityStatus(prompt: Bool) {
        if prompt && !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
        } else {
            isAccessibilityTrusted = AXIsProcessTrusted()
        }

        if !isAccessibilityTrusted {
            startPermissionPolling()
        } else {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshAccessibilityStatus(prompt: true)
    }

    func resetToDefault() {
        shortcut = .default
    }

    /// Call when the user switches mute mode in Preferences.
    func muteModeDidChange(_ mode: MuteMode) {
        isPushToTalkHeld = false
        if mode == .pushToTalk {
            mic?.setMuted(true)
        }
    }

    // MARK: - Carbon registration

    private func installCarbonHandler() {
        guard eventHandler == nil else { return }

        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            )
        ]

        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard hotKeyID.signature == HotkeyManager.hotKeyID.signature else {
                return noErr
            }

            let kind = GetEventKind(event)
            Task { @MainActor in
                if kind == UInt32(kEventHotKeyPressed) {
                    manager.handleKeyDown()
                } else if kind == UInt32(kEventHotKeyReleased) {
                    manager.handleKeyUp()
                }
            }
            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            2,
            &eventTypes,
            userData,
            &eventHandler
        )
    }

    private func registerHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            print("Silenzio: RegisterEventHotKey failed (\(status))")
        }
    }

    // MARK: - Actions

    private func handleKeyDown() {
        guard let mic, let settings else { return }
        switch settings.muteMode {
        case .toggle:
            mic.toggleMute()
        case .pushToTalk:
            guard !isPushToTalkHeld else { return }
            isPushToTalkHeld = true
            mic.setMuted(false)
        }
    }

    private func handleKeyUp() {
        guard let mic, let settings else { return }
        guard settings.muteMode == .pushToTalk else { return }
        guard isPushToTalkHeld else { return }
        isPushToTalkHeld = false
        mic.setMuted(true)
    }

    private func persistShortcut() {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = AXIsProcessTrusted()
                self.isAccessibilityTrusted = trusted
                if trusted {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
    }
}

// MARK: - Shortcut recorder UI

struct ShortcutRecorderView: View {
    @Binding var shortcut: HotkeyShortcut
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                Text("Press shortcut…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SilenzioTheme.secondaryLabel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(SilenzioTheme.chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .background(
                        ShortcutCatcher { captured in
                            shortcut = captured
                            isRecording = false
                        } onCancel: {
                            isRecording = false
                        }
                    )
            } else {
                HStack(spacing: 5) {
                    chip(label(forModifier: optionKey, symbol: "⌥ Option", present: shortcut.carbonModifiers & UInt32(optionKey) != 0))
                    chip(label(forModifier: shiftKey, symbol: "⇧ Shift", present: shortcut.carbonModifiers & UInt32(shiftKey) != 0))
                    chip(label(forModifier: controlKey, symbol: "⌃ Control", present: shortcut.carbonModifiers & UInt32(controlKey) != 0))
                    chip(label(forModifier: cmdKey, symbol: "⌘ Command", present: shortcut.carbonModifiers & UInt32(cmdKey) != 0))
                    chip(shortcut.keyLabel)
                }
                .onTapGesture { isRecording = true }

                Button("Change") { isRecording = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func chip(_ text: String?) -> some View {
        Group {
            if let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SilenzioTheme.primaryLabel)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private func label(forModifier modifier: Int, symbol: String, present: Bool) -> String? {
        present ? symbol : nil
    }
}

/// Invisible view that becomes first responder and captures the next key combination.
private struct ShortcutCatcher: NSViewRepresentable {
    var onCapture: (HotkeyShortcut) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
    }

    final class RecorderNSView: NSView {
        var onCapture: ((HotkeyShortcut) -> Void)?
        var onCancel: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == UInt16(kVK_Escape) {
                onCancel?()
                return
            }
            if let shortcut = HotkeyShortcut.from(nsEvent: event) {
                onCapture?(shortcut)
            }
        }
    }
}
