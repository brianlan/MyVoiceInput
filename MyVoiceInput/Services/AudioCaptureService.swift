import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio

enum AudioCaptureServiceError: Error, Equatable {
    case unsupportedCaptureFormat
    case invalidInputDeviceID(String)
    case inputAudioUnitUnavailable
    case unableToSelectInputDevice(OSStatus)
}

protocol AudioEngineInputNodeProtocol: AnyObject {
    func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat
    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock)
    func removeTap(onBus bus: AVAudioNodeBus)
}

protocol AudioEngineProtocol: AnyObject {
    var isRunning: Bool { get }
    var inputNode: AudioEngineInputNodeProtocol { get }
    func setInputDevice(_ deviceID: AudioDeviceID) throws
    func prepare()
    func start() throws
    func stop()
}

final class AudioCaptureService: AudioCaptureServiceProtocol, @unchecked Sendable {
    private enum CapturePCM {
        static let commonFormat: AVAudioCommonFormat = .pcmFormatFloat32
        static let bytesPerSample = MemoryLayout<Float32>.size
        static let tapBufferSize: AVAudioFrameCount = 1_024
    }

    private let lock = NSLock()
    private let engine: AudioEngineProtocol
    private let inputDevicesProvider: @Sendable () -> [AudioDevice]
    private let deviceIDResolver: @Sendable (String) -> AudioDeviceID?

    private var bufferedPCMData = Data()
    private var selectedInputDeviceID: String?
    private var pendingWarningMessage: String?
    private var capturing = false

    var isCapturing: Bool {
        withLockedValue { capturing }
    }

    init(
        engine: AudioEngineProtocol = AVAudioEngineAdapter(),
        inputDevicesProvider: @Sendable @escaping () -> [AudioDevice] = { CoreAudioDeviceDiscovery.inputDevices() },
        deviceIDResolver: @Sendable @escaping (String) -> AudioDeviceID? = { uid in CoreAudioDeviceDiscovery.resolveDeviceID(for: uid) }
    ) {
        self.engine = engine
        self.inputDevicesProvider = inputDevicesProvider
        self.deviceIDResolver = deviceIDResolver
    }

    func availableInputDevices() -> [AudioDevice] {
        inputDevicesProvider()
    }

    func selectInputDevice(id: String?) {
        lock.lock()
        selectedInputDeviceID = id
        lock.unlock()
    }

    func consumePendingWarning() -> String? {
        withLockedMutation {
            defer { pendingWarningMessage = nil }
            return pendingWarningMessage
        }
    }

    func startCapture() async throws {
        if isCapturing {
            return
        }

        withLockedMutation {
            pendingWarningMessage = nil
        }

        let selectedID: String? = withLockedValue { selectedInputDeviceID }
        if let selectedID {
            if let resolvedDeviceID = deviceIDResolver(selectedID) {
                do {
                    try engine.setInputDevice(resolvedDeviceID)
                } catch {
                    withLockedMutation {
                        pendingWarningMessage = "Selected microphone is unavailable. Using system default input."
                    }
                }
            } else {
                withLockedMutation {
                    pendingWarningMessage = "Selected microphone is unavailable. Using system default input."
                }
            }
        }

        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        guard let captureFormat = AVAudioFormat(
            commonFormat: CapturePCM.commonFormat,
            sampleRate: inputFormat.sampleRate,
            channels: inputFormat.channelCount,
            interleaved: false
        ) else {
            throw AudioCaptureServiceError.unsupportedCaptureFormat
        }

        withLockedMutation {
            bufferedPCMData.removeAll(keepingCapacity: true)
            capturing = true
        }

        engine.inputNode.installTap(onBus: 0, bufferSize: CapturePCM.tapBufferSize, format: captureFormat) { [weak self] buffer, _ in
            self?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            withLockedMutation {
                bufferedPCMData.removeAll(keepingCapacity: true)
                capturing = false
            }
            throw error
        }
    }

    func stopCapture() async -> Data? {
        let wasCapturing = withLockedMutation { () -> Bool in
            guard capturing else { return false }
            capturing = false
            return true
        }

        guard wasCapturing else {
            return nil
        }

        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }

        return withLockedMutation {
            defer { bufferedPCMData.removeAll(keepingCapacity: true) }
            return bufferedPCMData.isEmpty ? nil : bufferedPCMData
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else {
            return
        }

        var chunk = Data(count: frameCount * channelCount * CapturePCM.bytesPerSample)
        chunk.withUnsafeMutableBytes { rawBuffer in
            let output = rawBuffer.bindMemory(to: Float32.self)
            var outputIndex = 0
            for frame in 0..<frameCount {
                for channel in 0..<channelCount {
                    output[outputIndex] = channelData[channel][frame]
                    outputIndex += 1
                }
            }
        }

        withLockedMutation {
            bufferedPCMData.append(chunk)
        }
    }

    private func withLockedValue<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func withLockedMutation<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class AVAudioInputNodeAdapter: AudioEngineInputNodeProtocol {
    private let inputNode: AVAudioInputNode

    init(inputNode: AVAudioInputNode) {
        self.inputNode = inputNode
    }

    func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        inputNode.inputFormat(forBus: bus)
    }

    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock) {
        inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: format, block: block)
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        inputNode.removeTap(onBus: bus)
    }
}

private final class AVAudioEngineAdapter: AudioEngineProtocol {
    private let engine: AVAudioEngine
    private lazy var inputNodeAdapter = AVAudioInputNodeAdapter(inputNode: engine.inputNode)

    init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
    }

    var isRunning: Bool {
        engine.isRunning
    }

    var inputNode: AudioEngineInputNodeProtocol {
        inputNodeAdapter
    }

    func setInputDevice(_ deviceID: AudioDeviceID) throws {
        guard let audioUnit = engine.inputNode.audioUnit else {
            throw AudioCaptureServiceError.inputAudioUnitUnavailable
        }

        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioCaptureServiceError.unableToSelectInputDevice(status)
        }
    }

    func prepare() {
        engine.prepare()
    }

    func start() throws {
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}

private enum CoreAudioDeviceDiscovery {
    static func inputDevices() -> [AudioDevice] {
        allDeviceIDs().compactMap { deviceID in
            guard hasInputStream(deviceID),
                  let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)
            else {
                return nil
            }

            let name = stringProperty(deviceID, selector: kAudioObjectPropertyName) ?? uid
            return AudioDevice(name: name, id: uid)
        }
    }

    static func resolveDeviceID(for uid: String) -> AudioDeviceID? {
        for deviceID in allDeviceIDs() {
            guard hasInputStream(deviceID) else { continue }
            if stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID) == uid {
                return deviceID
            }
        }
        return nil
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.stride
        var deviceIDs = Array(repeating: AudioDeviceID(), count: count)
        var mutableDataSize = dataSize
        let dataStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &mutableDataSize,
            &deviceIDs
        )

        guard dataStatus == noErr else {
            return []
        }
        return deviceIDs
    }

    private static func hasInputStream(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    private static func stringProperty(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var value: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.stride)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr else {
            return nil
        }

        return value as String
    }
}
