import Foundation
import Observation

@MainActor
final class RecordingFlowCoordinator {
    private enum Constants {
        static let defaultSampleRate = 44_100
        static let minimumPCMBytes = 4_096
    }

    private enum Phase {
        case idle
        case starting
        case recording
        case processing
    }

    private let appState: AppState
    private let hotkeyManager: any HotkeyManaging
    private let audioCaptureService: AudioCaptureServiceProtocol
    private let mp3EncoderService: MP3EncoderService
    private let transcriptionService: TranscriptionServiceProtocol
    private let textInsertionService: TextInsertionServiceProtocol
    private let permissionService: PermissionServiceProtocol
    private let errorHandlingService: ErrorHandlingService
    private let audioFeedbackService: AudioFeedbackPlaying
    private let recordingIndicatorController: RecordingIndicatorControlling
    private let sampleRate: Int
    private let minimumPCMBytes: Int

    private var phase: Phase = .idle
    private var activeTask: Task<Void, Never>?
    private var previousSettings: AppSettings

    init(
        appState: AppState = .shared,
        hotkeyManager: any HotkeyManaging,
        audioCaptureService: AudioCaptureServiceProtocol,
        mp3EncoderService: MP3EncoderService,
        transcriptionService: TranscriptionServiceProtocol,
        textInsertionService: TextInsertionServiceProtocol,
        permissionService: PermissionServiceProtocol = DefaultPermissionService(),
        errorHandlingService: ErrorHandlingService? = nil,
        audioFeedbackService: AudioFeedbackPlaying,
        recordingIndicatorController: RecordingIndicatorControlling,
        sampleRate: Int = Constants.defaultSampleRate,
        minimumPCMBytes: Int = Constants.minimumPCMBytes
    ) {
        self.appState = appState
        self.hotkeyManager = hotkeyManager
        self.audioCaptureService = audioCaptureService
        self.mp3EncoderService = mp3EncoderService
        self.transcriptionService = transcriptionService
        self.textInsertionService = textInsertionService
        self.permissionService = permissionService
        self.errorHandlingService = errorHandlingService ?? ErrorHandlingService()
        self.audioFeedbackService = audioFeedbackService
        self.recordingIndicatorController = recordingIndicatorController
        self.sampleRate = sampleRate
        self.minimumPCMBytes = minimumPCMBytes
        previousSettings = appState.settings

        bindHotkeyHandlers()
        applySettingsDiff(old: nil, new: previousSettings)
        observeSettings()
    }

    deinit {
        activeTask?.cancel()
    }

    func handleHotkeyDown() {
        guard phase == .idle else {
            return
        }

        guard permissionService.hasMicrophonePermission() else {
            handleAppError(.microphonePermissionMissing)
            return
        }

        guard permissionService.hasAccessibilityPermission() else {
            handleAppError(.accessibilityPermissionMissing)
            return
        }

        phase = .starting
        appState.recordingState = .recording
        recordingIndicatorController.show()
        audioFeedbackService.playStartSound()

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.audioCaptureService.startCapture()
                self.recordingDidStart()
            } catch is CancellationError {
                await self.cleanupAfterCancellation()
            } catch {
                self.handleFlowError(error)
            }
        }
    }

    func handleHotkeyUp() {
        guard phase == .starting || phase == .recording else {
            return
        }

        phase = .processing
        appState.recordingState = .transcribing
        audioFeedbackService.playStopSound()
        recordingIndicatorController.hide()

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }

            do {
                let pcmData = await self.audioCaptureService.stopCapture()
                try Task.checkCancellation()

                guard self.isUsableRecording(pcmData) else {
                    self.finishAsIdle()
                    return
                }

                let encodedAudio = try await self.mp3EncoderService.encode(
                    pcmData: pcmData!,
                    sampleRate: self.sampleRate
                )

                let settings = self.appState.settings
                let stream = try await self.transcriptionService.transcribe(
                    audioData: encodedAudio,
                    endpoint: settings.apiEndpoint,
                    model: settings.modelName
                )

                try await self.insertStreamedText(stream)
                self.finishAsIdle()
            } catch is CancellationError {
                await self.cleanupAfterCancellation()
            } catch {
                self.handleFlowError(error)
            }
        }
    }

    func cancelCurrentFlow() {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            await self?.cleanupAfterCancellation()
        }
    }

    private func bindHotkeyHandlers() {
        hotkeyManager.onRecordingStart = { [weak self] in
            Task { @MainActor in
                self?.handleHotkeyDown()
            }
        }

        hotkeyManager.onRecordingStop = { [weak self] in
            Task { @MainActor in
                self?.handleHotkeyUp()
            }
        }
    }

    private func recordingDidStart() {
        guard phase == .starting else {
            return
        }
        phase = .recording
        activeTask = nil
    }

    private func finishAsIdle() {
        phase = .idle
        activeTask = nil
        appState.recordingState = .idle
        recordingIndicatorController.hide()
    }

    private func handleFlowError(_ error: Error) {
        let appError = errorHandlingService.handle(error: error, endpoint: appState.settings.apiEndpoint)
        applyAppError(appError)
    }

    private func handleAppError(_ appError: AppError) {
        errorHandlingService.handle(appError: appError)
        applyAppError(appError)
    }

    private func applyAppError(_ appError: AppError) {
        phase = .idle
        activeTask = nil
        appState.recordingState = .error(appError.userMessage)
        appState.showTransientFeedback(appError.userMessage)
        recordingIndicatorController.hide()
        audioFeedbackService.playErrorSound()
    }

    private func cleanupAfterCancellation() async {
        _ = await audioCaptureService.stopCapture()
        phase = .idle
        activeTask = nil
        appState.recordingState = .idle
        recordingIndicatorController.hide()
    }

    private func insertStreamedText(_ stream: AsyncStream<String>) async throws {
        for await chunk in stream {
            try Task.checkCancellation()

            guard !chunk.isEmpty else {
                continue
            }

            appState.recordingState = .inserting
            try await textInsertionService.insertText(chunk)
        }
    }

    private func isUsableRecording(_ pcmData: Data?) -> Bool {
        guard let pcmData else {
            return false
        }
        return pcmData.count >= minimumPCMBytes
    }

    private func observeSettings() {
        withObservationTracking {
            _ = appState.settings
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }

                let current = self.appState.settings
                let old = self.previousSettings
                self.previousSettings = current

                self.applySettingsDiff(old: old, new: current)
                self.observeSettings()
            }
        }
    }

    private func applySettingsDiff(old: AppSettings?, new: AppSettings) {
        if old?.selectedMicrophoneID != new.selectedMicrophoneID {
            audioCaptureService.selectInputDevice(id: new.selectedMicrophoneID)
        }
    }
}

private struct DefaultPermissionService: PermissionServiceProtocol {
    func requestMicrophonePermission() async -> Bool { true }
    func hasMicrophonePermission() -> Bool { true }
    func requestAccessibilityPermission() async -> Bool { true }
    func hasAccessibilityPermission() -> Bool { true }
}
