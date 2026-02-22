import Foundation
import Observation
import SwiftUI
#if canImport(KeyboardShortcuts)
import KeyboardShortcuts
#endif

enum PermissionStatus: Sendable {
    enum Access: Sendable {
        case unknown
        case granted
        case denied
    }

    case status(microphone: Access, accessibility: Access)

    static let unknown: PermissionStatus = .status(microphone: .unknown, accessibility: .unknown)
}

@Observable
final class AppState {
    static let shared = AppState()
    
    private let autoStartService = AutoStartService()
    
    var recordingState: RecordingState = .idle
    var permissionStatus: PermissionStatus = .unknown
    var transientFeedbackMessage: String?

    @ObservationIgnored
    private var transientFeedbackTask: Task<Void, Never>?

    @ObservationIgnored
    @AppStorage("endpoint") private var endpointStorage: String = AppSettings.default.apiEndpoint
    @ObservationIgnored
    @AppStorage("modelName") private var modelNameStorage: String = AppSettings.default.modelName
    @ObservationIgnored
    @AppStorage("selectedMicrophoneID") private var selectedMicrophoneIDStorage: String = ""
    @ObservationIgnored
    @AppStorage("autoStartEnabled") private var autoStartEnabledStorage: Bool = AppSettings.default.autoStartEnabled
    @ObservationIgnored
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCodeStorage: Int = Int(AppSettings.default.hotkeyKeyCode)
    @ObservationIgnored
    @AppStorage("hotkeyModifiers") private var hotkeyModifiersStorage: Int = Int(AppSettings.default.hotkeyModifiers)
    @ObservationIgnored
    @AppStorage("onboardingComplete") private var onboardingCompleteStorage: Bool = false

    var isOnboardingComplete: Bool {
        get { onboardingCompleteStorage }
        set { onboardingCompleteStorage = newValue }
    }

    var settings: AppSettings {
        get {
            AppSettings(
                hotkeyKeyCode: UInt16(clamping: hotkeyKeyCodeStorage),
                hotkeyModifiers: UInt(clamping: hotkeyModifiersStorage),
                apiEndpoint: endpointStorage,
                modelName: modelNameStorage,
                selectedMicrophoneID: selectedMicrophoneIDStorage.isEmpty ? nil : selectedMicrophoneIDStorage,
                autoStartEnabled: autoStartEnabledStorage
            )
        }
        set {
            updateSettings(newValue)
        }
    }
    
    var autoStartIsEnabled: Bool {
        autoStartService.isEnabled
    }

    func startRecording() {
        recordingState = .recording
    }

    func stopRecording() {
        recordingState = .transcribing
    }

    @MainActor
    func showTransientFeedback(_ message: String, durationNanoseconds: UInt64 = 3_000_000_000) {
        transientFeedbackTask?.cancel()
        transientFeedbackMessage = message

        transientFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: durationNanoseconds)
            guard let self else { return }
            if transientFeedbackMessage == message {
                transientFeedbackMessage = nil
            }
        }
    }

    func updateSettings(_ newSettings: AppSettings) {
        let previousSettings = self.settings
        
        endpointStorage = newSettings.apiEndpoint
        modelNameStorage = newSettings.modelName
        selectedMicrophoneIDStorage = newSettings.selectedMicrophoneID ?? ""
        hotkeyKeyCodeStorage = Int(newSettings.hotkeyKeyCode)
        hotkeyModifiersStorage = Int(newSettings.hotkeyModifiers)
        
        if previousSettings.autoStartEnabled != newSettings.autoStartEnabled {
            if newSettings.autoStartEnabled {
                _ = autoStartService.enable()
            } else {
                _ = autoStartService.disable()
            }
        }
        
        autoStartEnabledStorage = newSettings.autoStartEnabled
    }
}

protocol HotkeyManaging: AnyObject {
    var onRecordingStart: (() -> Void)? { get set }
    var onRecordingStop: (() -> Void)? { get set }
}

final class NoopHotkeyManager: HotkeyManaging {
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?
}

#if canImport(KeyboardShortcuts)
extension HotkeyManager: HotkeyManaging {}
#endif

@MainActor
protocol RecordingIndicatorControlling: AnyObject {
    func show()
    func hide()
}

@MainActor
protocol AudioFeedbackPlaying: AnyObject {
    func playStartSound()
    func playStopSound()
    func playErrorSound()
}

extension RecordingIndicatorWindowController: RecordingIndicatorControlling {}
extension AudioFeedbackService: AudioFeedbackPlaying {}

@MainActor
final class AppWiringCoordinator {
    private(set) var recordingFlowCoordinator: RecordingFlowCoordinator

    init(
        appState: AppState = .shared,
        hotkeyManager: any HotkeyManaging = AppWiringCoordinator.makeDefaultHotkeyManager(),
        audioCaptureService: AudioCaptureServiceProtocol = AudioCaptureService(),
        mp3EncoderService: MP3EncoderService = MP3EncoderService(),
        transcriptionService: TranscriptionServiceProtocol = TranscriptionService(),
        textInsertionService: TextInsertionServiceProtocol = TextInsertionService(),
        permissionService: PermissionServiceProtocol = PermissionManager(),
        errorHandlingService: ErrorHandlingService? = nil,
        audioFeedbackService: AudioFeedbackPlaying = AudioFeedbackService.shared,
        recordingIndicatorController: RecordingIndicatorControlling? = nil
    ) {
        self.recordingFlowCoordinator = RecordingFlowCoordinator(
            appState: appState,
            hotkeyManager: hotkeyManager,
            audioCaptureService: audioCaptureService,
            mp3EncoderService: mp3EncoderService,
            transcriptionService: transcriptionService,
            textInsertionService: textInsertionService,
            permissionService: permissionService,
            errorHandlingService: errorHandlingService ?? ErrorHandlingService(),
            audioFeedbackService: audioFeedbackService,
            recordingIndicatorController: recordingIndicatorController ?? RecordingIndicatorWindowController()
        )
    }

    nonisolated private static func makeDefaultHotkeyManager() -> any HotkeyManaging {
#if canImport(KeyboardShortcuts)
        return HotkeyManager()
#else
        return NoopHotkeyManager()
#endif
    }
}
