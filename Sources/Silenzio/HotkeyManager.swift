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
        case kVK_ANSI_A...kVK_ANSI_Z:
            let scalar = UnicodeScalar(Int(keyCode) - kVK_ANSI_A + 65)!
            return String(Character(scalar))
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
        case kVK_ANSI_M: return "M"
        default:
            return "Key\(keyCode)"
        }
    }

    static func from(nsEvent event: NSEvent) -> HotkeyShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        guard carbon != 0 else { return nil }
        // Ignore pure modifier presses.
        let keyCode = UInt32(event.keyCode)
        let modifierOnly: Set<UInt16> = [56, 60, 59, 62, 58, 61, 55, 54, 63]
        guard !modifierOnly.contains(event.keyCode) else { return nil }
        return HotkeyShortcut(keyCode: keyCode, carbonModifiers: carbon)
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
    private var pushToTalkWasMuted: Bool?
    private var permissionTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var monitorLocal: Any?
    private var monitorGlobal: Any?

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

    deinit {
        // Best-effort teardown; Carbon refs are process-lifetime for this agent.
        if let monitorLocal { NSEvent.removeMonitor(monitorLocal) }
        if let monitorGlobal { NSEvent.removeMonitor(monitorGlobal) }
    }

    func configure(mic: MicController, settings: SettingsStore) {
        self.mic = mic
        self.settings = settings
        installCarbonHandler()
        registerHotKey()
        installKeyUpMonitor()
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

        // Re-bind key-up monitor once trusted (needed for push-to-talk release).
        installKeyUpMonitor()
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

    // MARK: - Carbon registration

    private func installCarbonHandler() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
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
            if hotKeyID.signature == HotkeyManager.hotKeyID.signature {
                Task { @MainActor in
                    manager.handleKeyDown()
                }
            }
            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
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

    private func installKeyUpMonitor() {
        if let monitorLocal {
            NSEvent.removeMonitor(monitorLocal)
            self.monitorLocal = nil
        }
        if let monitorGlobal {
            NSEvent.removeMonitor(monitorGlobal)
            self.monitorGlobal = nil
        }

        let handle: (NSEvent) -> Void = { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                guard self.settings?.muteMode == .pushToTalk else { return }
                if UInt32(event.keyCode) == self.shortcut.keyCode {
                    self.handleKeyUp()
                }
            }
        }

        monitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            handle(event)
            return event
        }

        if AXIsProcessTrusted() {
            monitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { event in
                handle(event)
            }
        }
    }

    // MARK: - Actions

    private func handleKeyDown() {
        guard let mic, let settings else { return }
        switch settings.muteMode {
        case .toggle:
            mic.toggleMute()
        case .pushToTalk:
            pushToTalkWasMuted = mic.isMuted
            mic.setMuted(false)
        }
    }

    private func handleKeyUp() {
        guard let mic, let settings else { return }
        guard settings.muteMode == .pushToTalk else { return }
        let restoreMuted = pushToTalkWasMuted ?? true
        pushToTalkWasMuted = nil
        mic.setMuted(restoreMuted)
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
                    self.installKeyUpMonitor()
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
                    chip(shortcut.displayString.split(separator: " ").last.map(String.init) ?? "?")
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
