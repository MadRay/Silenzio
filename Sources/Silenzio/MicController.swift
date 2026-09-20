import AppKit
import AVFoundation
import Combine
import CoreAudio
import Foundation

struct InputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
}

@MainActor
final class MicController: ObservableObject {
    @Published private(set) var isMuted = false {
        didSet {
            if oldValue != isMuted {
                restartMeter()
            }
        }
    }
    @Published private(set) var deviceName = "No Input Device"
    @Published private(set) var deviceID: AudioDeviceID = kAudioObjectUnknown
    @Published private(set) var availableDevices: [InputDevice] = []
    @Published private(set) var inputLevel: Float = 0
    @Published private(set) var decibelLevel: Float = -160
    @Published private(set) var usesVolumeFallback = false
    @Published private(set) var lastError: String?
    @Published private(set) var hasMicrophoneAccess = false

    private var savedVolume: Float?
    private var audioEngine: AVAudioEngine?
    private var isRefreshing = false
    private var didStartListeners = false

    init() {
        refreshDevices()
        bindDefaultInputDevice()
        startHardwareListeners()
        requestMicrophoneAccessAndStartMeter()
    }

    deinit {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
    }

    // MARK: - Public API

    func toggleMute() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        guard deviceID != kAudioObjectUnknown else {
            lastError = "No default input device"
            return
        }

        if muted {
            mute()
        } else {
            unmute()
        }
        refreshMuteState()
    }

    func selectDevice(_ id: AudioDeviceID) {
        guard id != kAudioObjectUnknown else { return }
        var newID = id
        var address = Self.makeAddress(
            selector: kAudioHardwarePropertyDefaultInputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &newID
        )
        if status != noErr {
            lastError = "Failed to set default input device (\(status))"
            return
        }
        bindDefaultInputDevice()
    }

    func refreshDevices() {
        availableDevices = Self.enumerateInputDevices()
    }

    // MARK: - Mute / Unmute

    private func mute() {
        if setHardwareMute(true) {
            usesVolumeFallback = false
            return
        }

        if let current = getVolumeScalar() {
            savedVolume = current
            if setVolumeScalar(0) {
                usesVolumeFallback = true
                return
            }
        }

        lastError = "Device does not support mute or volume control"
    }

    private func unmute() {
        if usesVolumeFallback {
            let restore = savedVolume ?? 0.75
            if setVolumeScalar(restore) {
                usesVolumeFallback = false
                savedVolume = nil
                return
            }
        }

        if setHardwareMute(false) {
            usesVolumeFallback = false
            return
        }

        if let restore = savedVolume, setVolumeScalar(restore) {
            usesVolumeFallback = false
            savedVolume = nil
            return
        }

        lastError = "Failed to unmute input device"
    }

    private func setHardwareMute(_ muted: Bool) -> Bool {
        guard hasMuteControl() else { return false }
        var value: UInt32 = muted ? 1 : 0
        var address = Self.muteAddress
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
        return status == noErr
    }

    private func getHardwareMute() -> Bool? {
        guard hasMuteControl() else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = Self.muteAddress
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else { return nil }
        return value != 0
    }

    private func hasMuteControl() -> Bool {
        var address = Self.muteAddress
        return AudioObjectHasProperty(deviceID, &address)
    }

    private func getVolumeScalar() -> Float? {
        guard hasVolumeControl() else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.volumeAddress
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr else { return nil }
        return value
    }

    private func setVolumeScalar(_ value: Float) -> Bool {
        guard hasVolumeControl() else { return false }
        var scalar = Float32(max(0, min(1, value)))
        var address = Self.volumeAddress
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &scalar
        )
        return status == noErr
    }

    private func hasVolumeControl() -> Bool {
        var address = Self.volumeAddress
        return AudioObjectHasProperty(deviceID, &address)
    }

    // MARK: - Device binding

    private func bindDefaultInputDevice() {
        let id = Self.defaultInputDeviceID()
        deviceID = id
        deviceName = id == kAudioObjectUnknown ? "No Input Device" : (Self.deviceName(for: id) ?? "Input Device")
        refreshMuteState()
        if didStartListeners {
            rebindDeviceListeners()
        }
        restartMeter()
    }

    private func refreshMuteState() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if let hardwareMuted = getHardwareMute() {
            isMuted = hardwareMuted
            if !hardwareMuted {
                usesVolumeFallback = false
            }
            return
        }

        if let volume = getVolumeScalar() {
            let mutedByVolume = volume < 0.001
            isMuted = mutedByVolume
            if mutedByVolume {
                usesVolumeFallback = true
                if savedVolume == nil {
                    savedVolume = 0.75
                }
            }
            return
        }

        isMuted = false
    }

    // MARK: - Hardware listeners

    private func startHardwareListeners() {
        didStartListeners = true
        let systemID = AudioObjectID(kAudioObjectSystemObject)

        addListener(
            objectID: systemID,
            address: Self.makeAddress(
                selector: kAudioHardwarePropertyDefaultInputDevice,
                scope: kAudioObjectPropertyScopeGlobal
            )
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
                self?.bindDefaultInputDevice()
            }
        }

        addListener(
            objectID: systemID,
            address: Self.makeAddress(
                selector: kAudioHardwarePropertyDevices,
                scope: kAudioObjectPropertyScopeGlobal
            )
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }

        rebindDeviceListeners()
    }

    private func rebindDeviceListeners() {
        guard deviceID != kAudioObjectUnknown else { return }

        addListener(objectID: deviceID, address: Self.muteAddress) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshMuteState()
            }
        }
        addListener(objectID: deviceID, address: Self.volumeAddress) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshMuteState()
            }
        }
    }

    private func addListener(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = address
        let status = AudioObjectAddPropertyListenerBlock(objectID, &address, nil, block)
        if status != noErr {
            print("Silenzio: failed to add property listener (\(status))")
        }
    }

    // MARK: - Level meter

    private func requestMicrophoneAccessAndStartMeter() {
        refreshMicrophoneAccess()
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startMeter()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.refreshMicrophoneAccess()
                    if granted {
                        self?.startMeter()
                    }
                }
            }
        default:
            break
        }
    }

    func refreshMicrophoneAccess() {
        hasMicrophoneAccess = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func openMicrophoneSettings() {
        refreshMicrophoneAccess()
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.refreshMicrophoneAccess()
                    if granted {
                        self?.restartMeter()
                    } else {
                        self?.openSystemMicrophonePrivacyPane()
                    }
                }
            }
            return
        }
        openSystemMicrophonePrivacyPane()
    }

    private func openSystemMicrophonePrivacyPane() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Microphone"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func restartMeter() {
        stopMeter()
        startMeter()
    }

    private func stopMeter() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputLevel = 0
        decibelLevel = -160
    }

    private func startMeter() {
        guard !isMuted else {
            inputLevel = 0
            decibelLevel = -160
            return
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(frameLength))
            let db = 20 * log10(max(rms, 1e-7))
            let normalized = max(0, min(1, (db + 50) / 50))

            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isMuted else {
                    self.inputLevel = 0
                    self.decibelLevel = -160
                    return
                }
                self.inputLevel = normalized
                self.decibelLevel = db
            }
        }

        do {
            try engine.start()
            audioEngine = engine
        } catch {
            lastError = "Audio meter failed: \(error.localizedDescription)"
            input.removeTap(onBus: 0)
        }
    }

    // MARK: - CoreAudio helpers

    private static var muteAddress: AudioObjectPropertyAddress {
        makeAddress(selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        makeAddress(selector: kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput)
    }

    private static func makeAddress(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }

    private static func defaultInputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = makeAddress(
            selector: kAudioHardwarePropertyDefaultInputDevice,
            scope: kAudioObjectPropertyScopeGlobal
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : kAudioObjectUnknown
    }

    private static func deviceName(for deviceID: AudioDeviceID) -> String? {
        var address = makeAddress(
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal
        )
        var cfName: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &cfName) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        return cfName as String
    }

    private static func enumerateInputDevices() -> [InputDevice] {
        var address = makeAddress(
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { id in
            guard hasInputStreams(deviceID: id), let name = deviceName(for: id) else { return nil }
            return InputDevice(id: id, name: name)
        }
    }

    private static func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var address = makeAddress(
            selector: kAudioDevicePropertyStreams,
            scope: kAudioDevicePropertyScopeInput
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }
}
