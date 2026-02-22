# MyVoiceInput v1 — macOS Streaming Voice Input App

## TL;DR

> **Quick Summary**: Build a macOS menu bar app that captures voice via configurable hotkey, sends audio to a local ASR HTTP API with streaming response, and inserts transcribed text into the focused app in real-time using chunked paste.
> 
> **Deliverables**:
> - macOS 14+ native app with menu bar presence (no Dock icon)
> - Press-and-hold global hotkey for recording
> - Floating pill recording indicator near cursor
> - Real-time streaming text insertion via chunked paste
> - Settings window for hotkey, microphone, and API configuration
> - Onboarding wizard for permissions
> - Auto-start with system option
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Project Setup → Audio Service → Transcription Service → Text Insertion → Integration

---

## Context

### Original Request
Build a streaming voice input app (macOS native), named MyVoiceInput, that calls locally deployed ASR model to do realtime voice to text. The app runs in background, and when user holds a specific key (or modifier + key), the app starts to collect audio input from microphone. When the user releases the key(s), it calls the HTTP API of ASR model, getting streaming output and inserts text into the current app's focused field streamingly as well. The hotkey(s) can be configured, and the model url_endpoint, model name can also be configured. For the input device (microphone), we should also let the user select. When hotkey is held, play a subtle sound and show recording indicator. The app should be able to auto-start with system restart. This app should guide the user on how to grant permissions.

### Interview Summary
**Key Decisions**:
- macOS 14+ (Sonoma) target for cleanest architecture
- Direct distribution (no sandbox) for simpler permissions
- Press-and-hold hotkey (not toggle)
- Real-time streaming insertion via chunked paste (~1-3 words at a time)
- Universal text insertion (Accessibility + paste fallback)
- Auto-detect language (no language selector)
- Separate Settings window (Cmd+,)
- MP3 audio format for API upload
- Full onboarding wizard for permissions
- TDD approach with automated tests
- Visual + audio feedback on errors

**Research Findings**:
- Reference implementations: VoiceInk, Pindrop, OpenWhisper
- KeyboardShortcuts library wraps Carbon hotkey APIs
- AVAudioEngine canonical for real-time audio capture
- Text insertion via clipboard swap + Cmd+V simulation
- Floating NSPanel with level: .floating for indicator

### Metis Review
**Identified Gaps** (addressed):
- Build system: Must use Xcode project (not SPM-only) for Info.plist, assets, LSUIElement
- API format: Need to validate ASR SSE format before implementing parser
- Scope creep risks: Locked down 7 areas (see guardrails)
- Edge cases: Added handling for hotkey conflicts, clipboard restoration, app focus

---

## Work Objectives

### Core Objective
Create a polished macOS menu bar voice input application that provides seamless press-and-hold dictation with real-time streaming transcription insertion.

### Concrete Deliverables
- `MyVoiceInput.xcodeproj` — Xcode project with SwiftUI app
- Menu bar app with microphone icon (no Dock presence)
- Global hotkey configuration via KeyboardShortcuts
- Audio recording with AVAudioEngine + MP3 encoding
- HTTP client for ASR API with SSE streaming
- Chunked paste text insertion
- Floating pill recording indicator
- Settings window with all configuration options
- Onboarding wizard for permissions
- Auto-start toggle via SMAppService

### Definition of Done
- [ ] App launches as menu bar only (no Dock icon) — verified by `LSUIElement` in Info.plist
- [ ] Pressing configured hotkey starts recording with sound and indicator
- [ ] Releasing hotkey sends audio to ASR API
- [ ] Transcribed text appears in focused text field in real-time
- [ ] All permissions requested via onboarding wizard
- [ ] All unit tests pass: `swift test` or Xcode test runner
- [ ] QA scenarios pass with evidence in `.sisyphus/evidence/`

### Must Have
- Press-and-hold hotkey detection (not just press/release)
- Real-time streaming text insertion (not wait-for-completion)
- Clipboard preservation (restore original after paste)
- Microphone device selection
- Visual recording indicator
- Audio feedback (start/stop/error sounds)
- Permission onboarding flow
- Error handling with user feedback

### Must NOT Have (Guardrails)
- **NO local Whisper/model bundling** — HTTP API only
- **NO multiple ASR providers** — single configurable endpoint
- **NO RTL language support** — standard LTR text only
- **NO iOS/watchOS companion apps** — macOS only
- **NO custom themes** — follow system appearance only
- **NO language selection UI** — auto-detect only
- **NO toggle hotkey mode** — press-and-hold only
- **NO App Store distribution** — no sandbox constraints
- **NO over-abstraction** — no unnecessary protocols for single implementations
- **NO excessive comments** — code should be self-documenting

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (greenfield project)
- **Automated tests**: TDD (test-driven)
- **Framework**: XCTest (bundled with Xcode)
- **If TDD**: Each service task follows RED (failing test) → GREEN (minimal impl) → REFACTOR

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **UI Components**: Use Playwright skill — Navigate, interact, assert, screenshot (via accessibility)
- **CLI/Build**: Use Bash — Run commands, validate output, check exit codes
- **Services/Logic**: Use XCTest — Unit tests with assertions
- **Integration**: Use Bash + tmux — Launch app, simulate hotkeys, verify behavior

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — start immediately, MAX PARALLEL):
├── Task 1: Create Xcode project with SwiftUI lifecycle [quick]
├── Task 2: Configure Info.plist and entitlements [quick]
├── Task 3: Add KeyboardShortcuts SPM dependency [quick]
├── Task 4: Define core data models and protocols [quick]
├── Task 5: Create app state management (AppState) [unspecified-high]
└── Task 6: Validate ASR API format (discovery task) [quick]

Wave 2 (Core Services — after Wave 1):
├── Task 7: Implement AudioCaptureService (AVAudioEngine) [deep]
├── Task 8: Implement MP3 encoder service [unspecified-high]
├── Task 9: Implement TranscriptionService (HTTP + SSE) [deep]
├── Task 10: Implement HotkeyManager (press-and-hold) [unspecified-high]
├── Task 11: Implement TextInsertionService (paste + accessibility) [deep]
└── Task 12: Implement PermissionManager [unspecified-high]

Wave 3 (UI Components — after Wave 2):
├── Task 13: Create MenuBarExtra and status icon [visual-engineering]
├── Task 14: Create floating recording indicator [visual-engineering]
├── Task 15: Create Settings window UI [visual-engineering]
├── Task 16: Create onboarding wizard UI [visual-engineering]
├── Task 17: Implement audio feedback (sounds) [quick]
└── Task 18: Wire up AppState to UI [unspecified-high]

Wave 4 (Integration & Polish — after Wave 3):
├── Task 19: Integrate all services in recording flow [deep]
├── Task 20: Implement auto-start (SMAppService) [quick]
├── Task 21: Add error handling and user feedback [unspecified-high]
├── Task 22: End-to-end integration tests [deep]
└── Task 23: Build and package .app bundle [quick]

Wave FINAL (Verification — after ALL tasks):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Real QA with Playwright [unspecified-high]
└── Task F4: Scope fidelity check [deep]

Critical Path: Task 1 → Task 7 → Task 9 → Task 11 → Task 19 → Task 22 → F1-F4
Parallel Speedup: ~65% faster than sequential
Max Concurrent: 6 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|------------|--------|
| 1-6 | — | 7-12 |
| 7 | 1, 4, 5 | 8, 19 |
| 8 | 7 | 19 |
| 9 | 1, 4, 5, 6 | 19 |
| 10 | 1, 3, 4, 5 | 18, 19 |
| 11 | 1, 4, 5, 12 | 19 |
| 12 | 1, 2, 4, 5 | 11, 16 |
| 13-18 | 5, respective services | 19 |
| 19 | 7, 8, 9, 10, 11, 13, 14, 17, 18 | 22 |
| 20 | 1, 2 | 22 |
| 21 | 19 | 22 |
| 22 | 19, 20, 21 | F1-F4 |
| 23 | 22 | F1-F4 |
| F1-F4 | 22, 23 | — |

### Agent Dispatch Summary

| Wave | Tasks | Categories |
|------|-------|------------|
| 1 | 6 | T1-T4,T6 → `quick`, T5 → `unspecified-high` |
| 2 | 6 | T7,T9,T11 → `deep`, T8,T10,T12 → `unspecified-high` |
| 3 | 6 | T13-T16 → `visual-engineering`, T17 → `quick`, T18 → `unspecified-high` |
| 4 | 5 | T19,T22 → `deep`, T20,T23 → `quick`, T21 → `unspecified-high` |
| FINAL | 4 | F1 → `oracle`, F2-F3 → `unspecified-high`, F4 → `deep` |

---

## TODOs

### Wave 1: Foundation (Start Immediately)

- [x] 1. Create Xcode Project with SwiftUI Lifecycle

  **What to do**:
  - Create new Xcode project: `MyVoiceInput` with SwiftUI App lifecycle
  - Set deployment target to macOS 14.0
  - Configure as menu bar app (LSUIElement will be set in Task 2)
  - Create basic `MyVoiceInputApp.swift` with empty `MenuBarExtra`
  - Add `.gitignore` for Xcode artifacts

  **Must NOT do**:
  - Do NOT add any functionality yet — just project skeleton
  - Do NOT use SPM-only structure — must be full Xcode project

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple project creation, no complex logic

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2-6)
  - **Blocks**: Tasks 7-12 (all services depend on project)
  - **Blocked By**: None

  **References**:
  - Pattern: SwiftUI MenuBarExtra from Apple docs
  - External: https://developer.apple.com/documentation/swiftui/menubarextra

  **Acceptance Criteria**:
  - [ ] `MyVoiceInput.xcodeproj` exists
  - [ ] `xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput build` succeeds
  - [ ] App entry point is `@main struct MyVoiceInputApp: App`

  **QA Scenarios**:
  ```
  Scenario: Project builds successfully
    Tool: Bash
    Preconditions: Xcode 15+ installed
    Steps:
      1. Run: xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput -configuration Debug build
      2. Check exit code is 0
    Expected Result: Build succeeds with exit code 0
    Failure Indicators: Non-zero exit code, "error:" in output
    Evidence: .sisyphus/evidence/task-1-build-success.txt

  Scenario: App entry point exists
    Tool: Bash (grep)
    Preconditions: Project created
    Steps:
      1. Run: grep -r "@main" MyVoiceInput/*.swift
      2. Verify output contains "struct MyVoiceInputApp: App"
    Expected Result: @main struct found in app file
    Evidence: .sisyphus/evidence/task-1-entry-point.txt
  ```

  **Commit**: YES
  - Message: `chore(project): initialize Xcode project with SwiftUI lifecycle`
  - Files: `MyVoiceInput.xcodeproj/`, `MyVoiceInput/`, `.gitignore`
  - Pre-commit: `xcodebuild build`

---

- [x] 2. Configure Info.plist and Entitlements

  **What to do**:
  - Set `LSUIElement` to `true` (menu bar only, no Dock icon)
  - Add `NSMicrophoneUsageDescription` with user-friendly message
  - Create entitlements file if needed for non-sandboxed app
  - Set bundle identifier: `com.myvoiceinput.app`
  - Set app name and version

  **Must NOT do**:
  - Do NOT enable App Sandbox
  - Do NOT add unnecessary entitlements

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple plist configuration

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3-6)
  - **Blocks**: Task 12 (PermissionManager), Task 20 (auto-start)
  - **Blocked By**: Task 1 (project must exist)

  **References**:
  - Apple docs: LSUIElement, NSMicrophoneUsageDescription
  - Pattern: VoiceInk Info.plist structure

  **Acceptance Criteria**:
  - [ ] Info.plist contains `LSUIElement = true`
  - [ ] Info.plist contains `NSMicrophoneUsageDescription`
  - [ ] App launches without Dock icon

  **QA Scenarios**:
  ```
  Scenario: LSUIElement configured correctly
    Tool: Bash
    Preconditions: Info.plist exists
    Steps:
      1. Run: /usr/libexec/PlistBuddy -c "Print :LSUIElement" MyVoiceInput/Info.plist
      2. Verify output is "true"
    Expected Result: Output is exactly "true"
    Failure Indicators: "false", key not found error
    Evidence: .sisyphus/evidence/task-2-lsuielement.txt

  Scenario: Microphone usage description present
    Tool: Bash
    Preconditions: Info.plist exists
    Steps:
      1. Run: /usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" MyVoiceInput/Info.plist
      2. Verify non-empty string returned
    Expected Result: Returns description string
    Evidence: .sisyphus/evidence/task-2-mic-description.txt
  ```

  **Commit**: Groups with Task 1

---

- [x] 3. Add KeyboardShortcuts SPM Dependency

  **What to do**:
  - Add `sindresorhus/KeyboardShortcuts` package via SPM
  - Version: latest stable (currently ~2.0)
  - Verify package resolves and builds
  - Add import statement test in a placeholder file

  **Must NOT do**:
  - Do NOT implement hotkey logic yet — just add dependency

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple dependency addition

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 10 (HotkeyManager)
  - **Blocked By**: Task 1

  **References**:
  - Package: https://github.com/sindresorhus/KeyboardShortcuts
  - Docs: SwiftUI Recorder, onKeyUp/onKeyDown

  **Acceptance Criteria**:
  - [ ] Package.resolved contains KeyboardShortcuts
  - [ ] `import KeyboardShortcuts` compiles without error

  **QA Scenarios**:
  ```
  Scenario: KeyboardShortcuts package added
    Tool: Bash
    Preconditions: Project exists
    Steps:
      1. Run: xcodebuild -resolvePackageDependencies -project MyVoiceInput.xcodeproj
      2. Check for KeyboardShortcuts in resolved packages
      3. Run: grep -r "KeyboardShortcuts" MyVoiceInput.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    Expected Result: Package found in dependencies
    Evidence: .sisyphus/evidence/task-3-package-resolved.txt
  ```

  **Commit**: Groups with Tasks 4-6

---

- [x] 4. Define Core Data Models and Protocols

  **What to do**:
  - Create `Models/` directory
  - Define `RecordingState` enum: `.idle`, `.recording`, `.transcribing`, `.inserting`, `.error(Error)`
  - Define `AppSettings` struct: hotkey config, API endpoint, model name, selected mic ID, auto-start
  - Define `TranscriptionChunk` struct for streaming response parsing
  - Define service protocols (but NOT implementations):
    - `AudioCaptureServiceProtocol`
    - `TranscriptionServiceProtocol`
    - `TextInsertionServiceProtocol`
    - `PermissionServiceProtocol`

  **Must NOT do**:
  - Do NOT implement any service logic — protocols only
  - Do NOT over-abstract — keep protocols minimal

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Data model definitions, straightforward

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: Tasks 5, 7-12 (all services depend on models)
  - **Blocked By**: Task 1

  **References**:
  - Pattern: VoiceScribe protocol-based architecture
  - Swift best practices for enums with associated values

  **Acceptance Criteria**:
  - [ ] `Models/RecordingState.swift` exists with enum
  - [ ] `Models/AppSettings.swift` exists with struct
  - [ ] `Models/TranscriptionChunk.swift` exists
  - [ ] `Protocols/` directory with service protocols
  - [ ] All files compile

  **QA Scenarios**:
  ```
  Scenario: Models compile correctly
    Tool: Bash
    Preconditions: Model files created
    Steps:
      1. Run: xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput build
      2. Verify no errors related to model files
    Expected Result: Build succeeds
    Evidence: .sisyphus/evidence/task-4-models-compile.txt

  Scenario: RecordingState has all required cases
    Tool: Bash (grep)
    Steps:
      1. grep for "case idle", "case recording", "case transcribing", "case error" in RecordingState.swift
    Expected Result: All cases found
    Evidence: .sisyphus/evidence/task-4-recording-state.txt
  ```

  **Commit**: Groups with Tasks 3, 5-6

---

- [x] 5. Create App State Management (AppState)

  **What to do**:
  - Create `AppState.swift` as `@Observable` class (macOS 14+)
  - Properties: `recordingState`, `settings`, `isOnboardingComplete`, `permissionStatus`
  - Methods: `startRecording()`, `stopRecording()`, `updateSettings(_:)`
  - Use `@AppStorage` for persisted settings
  - Initialize with default settings

  **Must NOT do**:
  - Do NOT implement actual recording logic — just state transitions
  - Do NOT add UI bindings yet

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Central state management, moderate complexity

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: Tasks 7-18 (most components depend on AppState)
  - **Blocked By**: Tasks 1, 4

  **References**:
  - Pattern: VoiceInk WhisperState, OpenWhisper AppState
  - Apple docs: @Observable macro (macOS 14+)

  **Acceptance Criteria**:
  - [ ] `AppState.swift` exists with @Observable
  - [ ] All RecordingState transitions are defined
  - [ ] Settings persist via @AppStorage
  - [ ] Unit tests for state transitions pass

  **QA Scenarios**:
  ```
  Scenario: AppState state transitions work
    Tool: Bash (XCTest)
    Preconditions: AppState and tests created
    Steps:
      1. Create test: AppState starts in .idle
      2. Call startRecording(), assert state is .recording
      3. Call stopRecording(), assert state is .transcribing
      4. Run: xcodebuild test -project MyVoiceInput.xcodeproj -scheme MyVoiceInput
    Expected Result: State transition tests pass
    Evidence: .sisyphus/evidence/task-5-state-tests.txt
  ```

  **Commit**: Groups with Tasks 3-4, 6

---

- [x] 6. Validate ASR API Format (Discovery Task)

  **What to do**:
  - Test the ASR API endpoint with curl to understand response format
  - Document: Is it SSE (`text/event-stream`) or NDJSON?
  - Document: What fields are in each chunk? (`text`, `delta`, `segment`?)
  - Create `Docs/api-format.md` documenting the format
  - If API unavailable, create mock server specification

  **Must NOT do**:
  - Do NOT implement parser yet — just document format

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: API investigation, documentation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 9 (TranscriptionService needs format)
  - **Blocked By**: None

  **References**:
  - API endpoint: `http://127.0.0.1:8010/v1/audio/transcriptions`
  - Example: `curl -X POST ... -F "stream=True"`

  **Acceptance Criteria**:
  - [ ] `Docs/api-format.md` exists with format documentation
  - [ ] Response content-type documented
  - [ ] Chunk structure documented with example

  **QA Scenarios**:
  ```
  Scenario: API format documented
    Tool: Bash
    Steps:
      1. Check Docs/api-format.md exists
      2. Grep for "Content-Type" or "text/event-stream" or "application/json"
      3. Grep for example chunk structure
    Expected Result: Documentation file with format details
    Failure Indicators: Empty file, missing chunk example
    Evidence: .sisyphus/evidence/task-6-api-format.txt

  Scenario: API test (if available)
    Tool: Bash (curl)
    Preconditions: ASR server running on localhost:8010
    Steps:
      1. curl -X POST http://127.0.0.1:8010/v1/audio/transcriptions -F "file=@test.mp3" -F "stream=True" -v 2>&1 | head -50
      2. Capture Content-Type header and first response lines
    Expected Result: Response format captured
    Evidence: .sisyphus/evidence/task-6-api-test.txt
  ```

  **Commit**: Groups with Tasks 3-5

### Wave 2: Core Services (After Wave 1)

- [x] 7. Implement AudioCaptureService (AVAudioEngine)

  **What to do**:
  - Create `Services/AudioCaptureService.swift` implementing `AudioCaptureServiceProtocol`
  - Use `AVAudioEngine` with input tap for real-time PCM capture
  - Get available audio input devices via `AVCaptureDevice.DiscoverySession`
  - Allow selecting specific microphone by device ID
  - Provide methods: `startCapture()`, `stopCapture() -> Data`, `getAvailableDevices() -> [AudioDevice]`
  - Buffer audio in memory during recording
  - Handle microphone disconnection gracefully
  - Write TDD tests first: mock AVAudioEngine, test start/stop, test buffer accumulation

  **Must NOT do**:
  - Do NOT encode to MP3 here — pass raw PCM to encoder (Task 8)
  - Do NOT write to disk — keep in memory
  - Do NOT handle permissions — that's PermissionManager (Task 12)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: AVAudioEngine is complex with real-time audio constraints, requires careful buffer handling

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9-12)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 8 (MP3 encoder needs audio data), Task 19 (integration)
  - **Blocked By**: Tasks 1, 4, 5

  **References**:
  - Pattern: `watzon/pindrop` AudioRecorder — AVAudioEngine setup with input tap
  - Pattern: `Beingpax/VoiceInk` RecordingManager — buffer handling
  - Apple docs: https://developer.apple.com/documentation/avfaudio/avaudioengine
  - Apple docs: https://developer.apple.com/documentation/avfaudio/avaudioinputnode

  **Acceptance Criteria**:
  - [ ] `Services/AudioCaptureService.swift` exists implementing protocol
  - [ ] Unit tests for start/stop/buffer pass
  - [ ] Device enumeration returns at least built-in microphone
  - [ ] Audio capture produces non-empty PCM data

  **QA Scenarios**:
  ```
  Scenario: Audio capture produces data
    Tool: Bash (XCTest)
    Preconditions: Tests written, microphone permission granted
    Steps:
      1. Run unit test that: creates AudioCaptureService, calls startCapture(), waits 1 second, calls stopCapture()
      2. Assert returned Data is non-empty (> 1000 bytes)
    Expected Result: Test passes, data.count > 1000
    Failure Indicators: Empty data, test timeout, AVAudioEngine error
    Evidence: .sisyphus/evidence/task-7-audio-capture.txt

  Scenario: Device enumeration works
    Tool: Bash (XCTest)
    Steps:
      1. Run unit test that calls getAvailableDevices()
      2. Assert array is non-empty
      3. Assert each device has id and name
    Expected Result: At least one device returned
    Evidence: .sisyphus/evidence/task-7-devices.txt

  Scenario: Graceful handling when no microphone
    Tool: Bash (XCTest)
    Steps:
      1. Mock AVAudioEngine to simulate no input available
      2. Call startCapture()
      3. Assert throws appropriate error
    Expected Result: Throws AudioCaptureError.noInputAvailable
    Evidence: .sisyphus/evidence/task-7-no-mic-error.txt
  ```

  **Commit**: YES
  - Message: `feat(audio): implement AVAudioEngine capture service`
  - Files: `Services/AudioCaptureService.swift`, `Tests/AudioCaptureServiceTests.swift`
  - Pre-commit: `xcodebuild test`

---

- [x] 8. Implement MP3 Encoder Service

  **What to do**:
  - Create `Services/MP3EncoderService.swift`
  - Use `AVAudioConverter` to convert PCM to compressed format OR
  - Use LAME encoder via SPM package (e.g., `nicktrienenern/SwiftLAME`) for true MP3
  - Provide method: `encode(pcmData: Data, sampleRate: Int) -> Data` returning MP3 bytes
  - Handle sample rate conversion if needed (API may expect specific rate)
  - Write TDD tests: encode known PCM, verify MP3 header bytes (0xFF 0xFB or ID3)

  **Must NOT do**:
  - Do NOT block main thread — encoding can be CPU intensive
  - Do NOT over-engineer — single encoding path is fine

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Audio encoding has gotchas but well-documented paths exist

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9-12)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 19 (integration needs encoded audio)
  - **Blocked By**: Task 7 (needs PCM data format understanding)

  **References**:
  - Package: `nicktrienenern/SwiftLAME` for LAME encoder
  - Alternative: AAC via `AVAudioConverter` (if API accepts AAC)
  - Apple docs: AVAudioConverter for format conversion

  **Acceptance Criteria**:
  - [ ] `Services/MP3EncoderService.swift` exists
  - [ ] Encoding produces valid MP3 data (correct header bytes)
  - [ ] Unit tests pass for encoding

  **QA Scenarios**:
  ```
  Scenario: MP3 encoding produces valid output
    Tool: Bash (XCTest)
    Steps:
      1. Create test with known PCM data (sine wave)
      2. Call encode(pcmData:sampleRate:)
      3. Assert output starts with MP3 sync bytes (0xFF 0xFB) or ID3 header
      4. Assert output length is smaller than input (compression occurred)
    Expected Result: Valid MP3 header, compressed size
    Evidence: .sisyphus/evidence/task-8-mp3-encode.txt

  Scenario: Encoding handles empty input gracefully
    Tool: Bash (XCTest)
    Steps:
      1. Call encode with empty Data
      2. Assert throws EncodingError.emptyInput or returns empty
    Expected Result: Graceful handling, no crash
    Evidence: .sisyphus/evidence/task-8-empty-input.txt
  ```

  **Commit**: Groups with Task 7
  - Message: `feat(audio): implement audio capture and MP3 encoding`

---

- [x] 9. Implement TranscriptionService (HTTP + SSE Streaming)

  **What to do**:
  - Create `Services/TranscriptionService.swift` implementing `TranscriptionServiceProtocol`
  - Build multipart/form-data request with: `file` (MP3 data), `model` (from settings), `stream=True`
  - Use `URLSession.bytes(for:)` for streaming response
  - Parse SSE or NDJSON based on Task 6 findings (see `Docs/api-format.md`)
  - Yield `TranscriptionChunk` via AsyncStream as chunks arrive
  - Handle: connection errors, timeout, malformed responses
  - Write TDD tests with mock URLSession

  **Must NOT do**:
  - Do NOT assume format — read Task 6 documentation first
  - Do NOT retry automatically — let caller decide

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Streaming HTTP with SSE parsing is nuanced, needs careful error handling

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7, 8, 10-12)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 19 (integration)
  - **Blocked By**: Tasks 1, 4, 5, 6 (needs API format from Task 6)

  **References**:
  - Task 6 output: `Docs/api-format.md` for response format
  - Pattern: Swift `URLSession.bytes(for:)` + `AsyncSequence`
  - SSE parsing: split on `data:` lines, handle `[DONE]` sentinel
  - Apple docs: https://developer.apple.com/documentation/foundation/urlsession/3767352-bytes

  **Acceptance Criteria**:
  - [ ] `Services/TranscriptionService.swift` exists implementing protocol
  - [ ] Multipart request correctly formatted
  - [ ] SSE/NDJSON parsing works (based on actual format)
  - [ ] AsyncStream yields chunks progressively
  - [ ] Unit tests with mock responses pass

  **QA Scenarios**:
  ```
  Scenario: Streaming transcription returns chunks
    Tool: Bash (XCTest)
    Steps:
      1. Create mock URLSession returning SSE stream: "data: {\"text\":\"Hello\"}\n\ndata: {\"text\":\" world\"}\n\n"
      2. Call transcribe(audioData:) and collect AsyncStream
      3. Assert received 2 chunks with text "Hello" and " world"
    Expected Result: Two TranscriptionChunk objects yielded
    Evidence: .sisyphus/evidence/task-9-stream-chunks.txt

  Scenario: Connection error handled
    Tool: Bash (XCTest)
    Steps:
      1. Mock URLSession to throw URLError.notConnectedToInternet
      2. Call transcribe(audioData:)
      3. Assert throws TranscriptionError.connectionFailed
    Expected Result: Appropriate error thrown, no crash
    Evidence: .sisyphus/evidence/task-9-connection-error.txt

  Scenario: Multipart request format correct
    Tool: Bash (XCTest)
    Steps:
      1. Inspect request built by service
      2. Assert Content-Type is multipart/form-data with boundary
      3. Assert body contains file part and model part
    Expected Result: Valid multipart structure
    Evidence: .sisyphus/evidence/task-9-multipart.txt
  ```

  **Commit**: YES
  - Message: `feat(transcription): implement streaming ASR client`
  - Files: `Services/TranscriptionService.swift`, `Tests/TranscriptionServiceTests.swift`
  - Pre-commit: `xcodebuild test`

---

- [x] 10. Implement HotkeyManager (Press-and-Hold)

  **What to do**:
  - Create `Services/HotkeyManager.swift`
  - Use `KeyboardShortcuts` library for global hotkey registration
  - Implement press-and-hold detection using `onKeyDown` and `onKeyUp` callbacks
  - Provide callbacks: `onRecordingStart: () -> Void`, `onRecordingStop: () -> Void`
  - Store configured shortcut in UserDefaults via KeyboardShortcuts.Name
  - Handle edge cases: key stuck, window focus changes, multiple rapid presses
  - Write tests for callback invocation

  **Must NOT do**:
  - Do NOT use toggle mode — must be press-and-hold only
  - Do NOT handle recording logic — just detect key events

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: KeyboardShortcuts library handles complexity, moderate integration work

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7-9, 11-12)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 18 (AppState wiring), Task 19 (integration)
  - **Blocked By**: Tasks 1, 3, 4, 5

  **References**:
  - Library: https://github.com/sindresorhus/KeyboardShortcuts
  - Pattern: `Beingpax/VoiceInk` HotkeyManager — onKeyDown/onKeyUp callbacks
  - Pattern: `richardwu/openwhisper` — KeyboardShortcuts.Name extension

  **Acceptance Criteria**:
  - [ ] `Services/HotkeyManager.swift` exists
  - [ ] Shortcut can be set/changed at runtime
  - [ ] `onKeyDown` triggers `onRecordingStart`
  - [ ] `onKeyUp` triggers `onRecordingStop`
  - [ ] Unit tests for callback sequencing pass

  **QA Scenarios**:
  ```
  Scenario: Press-and-hold fires correct callbacks
    Tool: Bash (XCTest)
    Steps:
      1. Create HotkeyManager with mock callbacks
      2. Simulate keyDown event
      3. Assert onRecordingStart called
      4. Simulate keyUp event
      5. Assert onRecordingStop called
    Expected Result: Callbacks fire in sequence: start, stop
    Evidence: .sisyphus/evidence/task-10-hotkey-callbacks.txt

  Scenario: Rapid key presses don't cause duplicate starts
    Tool: Bash (XCTest)
    Steps:
      1. Simulate: keyDown, keyDown, keyDown (without keyUp)
      2. Assert onRecordingStart called only once
    Expected Result: Single start callback despite multiple keyDowns
    Evidence: .sisyphus/evidence/task-10-no-duplicate.txt

  Scenario: Shortcut persists after restart
    Tool: Bash (XCTest)
    Steps:
      1. Set shortcut to Cmd+Shift+R
      2. Create new HotkeyManager instance
      3. Assert shortcut is still Cmd+Shift+R
    Expected Result: Shortcut loaded from UserDefaults
    Evidence: .sisyphus/evidence/task-10-persistence.txt
  ```

  **Commit**: YES
  - Message: `feat(hotkey): implement press-and-hold hotkey manager`
  - Files: `Services/HotkeyManager.swift`, `Tests/HotkeyManagerTests.swift`
  - Pre-commit: `xcodebuild test`

---

- [x] 11. Implement TextInsertionService (Clipboard + Accessibility)

  **What to do**:
  - Create `Services/TextInsertionService.swift` implementing `TextInsertionServiceProtocol`
  - Primary method: clipboard swap + Cmd+V simulation
    1. Save current clipboard contents
    2. Set clipboard to text chunk
    3. Simulate Cmd+V using CGEvent
    4. Restore original clipboard (with small delay)
  - Provide method: `insertText(_ text: String)` for single chunk
  - Provide method: `insertTextStream(_ chunks: AsyncStream<String>)` for streaming
  - Add small delay between chunks (~50ms) for smooth insertion
  - Handle Accessibility permission check before simulating keypress
  - Write TDD tests mocking NSPasteboard and CGEvent

  **Must NOT do**:
  - Do NOT implement direct AX text insertion — clipboard swap is more reliable
  - Do NOT insert entire text at once — must be chunked for real-time effect

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: CGEvent, Accessibility APIs, clipboard management are tricky

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7-10, 12)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 19 (integration)
  - **Blocked By**: Tasks 1, 4, 5, 12 (needs permission check)

  **References**:
  - Pattern: `Beingpax/VoiceInk` CursorPaster — clipboard save/restore, CGEvent
  - Pattern: `watzon/pindrop` — NSPasteboard handling
  - Apple docs: CGEvent for keyboard simulation
  - Apple docs: AXIsProcessTrusted for permission check

  **Acceptance Criteria**:
  - [ ] `Services/TextInsertionService.swift` exists implementing protocol
  - [ ] Clipboard is restored after insertion
  - [ ] Unit tests for clipboard save/restore pass
  - [ ] Stream insertion works with multiple chunks

  **QA Scenarios**:
  ```
  Scenario: Clipboard is preserved
    Tool: Bash (XCTest)
    Steps:
      1. Set clipboard to "original content"
      2. Call insertText("new text")
      3. Wait 200ms for restore
      4. Assert clipboard equals "original content"
    Expected Result: Original clipboard restored
    Evidence: .sisyphus/evidence/task-11-clipboard-restore.txt

  Scenario: Text insertion works (integration)
    Tool: interactive_bash (tmux) + TextEdit
    Preconditions: Accessibility permission granted
    Steps:
      1. Open TextEdit with empty document
      2. Focus TextEdit
      3. Call insertText("Hello World")
      4. Read TextEdit content
    Expected Result: TextEdit contains "Hello World"
    Evidence: .sisyphus/evidence/task-11-insertion-works.png

  Scenario: Streaming insertion has timing
    Tool: Bash (XCTest)
    Steps:
      1. Create mock stream with 3 chunks
      2. Call insertTextStream
      3. Measure time between insertions
    Expected Result: ~50ms delay between chunks
    Evidence: .sisyphus/evidence/task-11-stream-timing.txt
  ```

  **Commit**: Groups with Task 12
  - Message: `feat(services): implement text insertion and permissions`

---

- [x] 12. Implement PermissionManager

  **What to do**:
  - Create `Services/PermissionManager.swift` implementing `PermissionServiceProtocol`
  - Check/request Microphone permission: `AVCaptureDevice.requestAccess(for: .audio)`
  - Check Accessibility permission: `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions`
  - Provide properties: `microphoneStatus`, `accessibilityStatus` as enum (granted/denied/notDetermined)
  - Provide method: `requestMicrophoneAccess() async -> Bool`
  - Provide method: `openAccessibilitySettings()` — opens System Settings
  - Observe permission changes if possible
  - Write TDD tests with mocked system APIs

  **Must NOT do**:
  - Do NOT request permissions automatically — let UI/onboarding trigger
  - Do NOT bundle multiple permissions in one request

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Permission APIs are well-documented, moderate complexity

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7-11)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 11 (TextInsertion needs to check), Task 16 (onboarding UI)
  - **Blocked By**: Tasks 1, 2, 4, 5

  **References**:
  - Apple docs: AVCaptureDevice.requestAccess
  - Apple docs: AXIsProcessTrustedWithOptions with kAXTrustedCheckOptionPrompt
  - Deep link: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

  **Acceptance Criteria**:
  - [ ] `Services/PermissionManager.swift` exists implementing protocol
  - [ ] Microphone status correctly detected
  - [ ] Accessibility status correctly detected
  - [ ] `openAccessibilitySettings()` opens correct System Settings pane
  - [ ] Unit tests pass

  **QA Scenarios**:
  ```
  Scenario: Microphone permission detection
    Tool: Bash (XCTest)
    Steps:
      1. Get microphoneStatus
      2. Assert it returns one of: .granted, .denied, .notDetermined
    Expected Result: Valid status returned
    Evidence: .sisyphus/evidence/task-12-mic-status.txt

  Scenario: Accessibility settings opens correctly
    Tool: interactive_bash (tmux)
    Steps:
      1. Call openAccessibilitySettings()
      2. Verify System Settings app opens to Privacy & Security > Accessibility
    Expected Result: Correct Settings pane opens
    Evidence: .sisyphus/evidence/task-12-accessibility-pane.png

  Scenario: Permission request returns result
    Tool: Bash (XCTest)
    Preconditions: Microphone permission not yet determined (or use mock)
    Steps:
      1. Call requestMicrophoneAccess()
      2. Assert returns true or false (not throws)
    Expected Result: Boolean result returned
    Evidence: .sisyphus/evidence/task-12-request-result.txt
  ```

  **Commit**: Groups with Task 11

---

### Wave 3: UI Components (After Wave 2)

- [x] 13. Create MenuBarExtra and Status Icon

  **What to do**:
  - Update `MyVoiceInputApp.swift` with proper `MenuBarExtra` implementation
  - Create microphone icon (SF Symbol: `mic.fill` or custom asset)
  - Show icon states: idle (normal), recording (red/pulsing), error (warning)
  - Menu items: Status indicator, Settings (Cmd+,), Quit
  - Wire menu items to AppState actions
  - Add keyboard shortcut hints in menu

  **Must NOT do**:
  - Do NOT show Dock icon — LSUIElement must remain true
  - Do NOT put settings inline in menu — separate Settings window

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: UI design with menu bar polish, icon states

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 14-18)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 19 (integration)
  - **Blocked By**: Task 5 (needs AppState)

  **References**:
  - Pattern: `richardwu/openwhisper` MenuBarExtra with icon states
  - Apple docs: https://developer.apple.com/documentation/swiftui/menubarextra
  - SF Symbols: mic.fill, mic.slash.fill, exclamationmark.triangle

  **Acceptance Criteria**:
  - [ ] Menu bar icon appears when app launches
  - [ ] Icon changes state: idle → recording → idle
  - [ ] Menu shows Settings and Quit options
  - [ ] Cmd+, opens Settings window

  **QA Scenarios**:
  ```
  Scenario: Menu bar icon appears
    Tool: Bash + screencapture
    Steps:
      1. Launch app: open ./build/Debug/MyVoiceInput.app
      2. Wait 2 seconds
      3. Capture menu bar area: screencapture -R0,0,400,30 menubar.png
      4. Verify mic icon visible (visual inspection or image diff)
    Expected Result: Microphone icon visible in menu bar
    Evidence: .sisyphus/evidence/task-13-menubar-icon.png

  Scenario: Menu items present
    Tool: Bash (AppleScript or UI automation)
    Steps:
      1. Click menu bar icon
      2. List menu items
      3. Assert "Settings" and "Quit" exist
    Expected Result: Both menu items present
    Evidence: .sisyphus/evidence/task-13-menu-items.txt

  Scenario: No Dock icon
    Tool: Bash
    Steps:
      1. Launch app
      2. Run: osascript -e 'tell application "System Events" to name of every process whose visible is true'
      3. Assert MyVoiceInput not in visible Dock apps
    Expected Result: App not in Dock
    Evidence: .sisyphus/evidence/task-13-no-dock.txt
  ```

  **Commit**: Groups with Tasks 14-16
  - Message: `feat(ui): implement menu bar, indicator, settings, onboarding`

---

- [x] 14. Create Floating Recording Indicator

  **What to do**:
  - Create `Views/RecordingIndicatorWindow.swift` using `NSPanel`
  - Style: floating pill shape near cursor with "Recording..." text
  - Use `.floating` window level, no title bar, non-activating
  - Show microphone icon + animated waveform or pulsing dot
  - Position near cursor but not directly under it
  - Show/hide based on `AppState.recordingState`
  - Ensure it follows cursor or stays in fixed position (user chose near cursor)

  **Must NOT do**:
  - Do NOT make the window activating — should not steal focus
  - Do NOT make it resizable or closable by user
  - Do NOT over-animate — subtle pulse only

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: Custom NSPanel with animations and positioning

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13, 15-18)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 19 (integration)
  - **Blocked By**: Task 5 (needs AppState)

  **References**:
  - Pattern: `Beingpax/VoiceInk` floating indicator
  - NSPanel with styleMask: .nonactivatingPanel, .borderless
  - Animation: SwiftUI pulse or simple opacity animation

  **Acceptance Criteria**:
  - [ ] `Views/RecordingIndicatorWindow.swift` exists
  - [ ] Window appears when recording starts
  - [ ] Window disappears when recording stops
  - [ ] Window does not steal focus
  - [ ] Window has pill shape with recording UI

  **QA Scenarios**:
  ```
  Scenario: Indicator appears during recording
    Tool: interactive_bash (tmux) + screenshot
    Steps:
      1. Launch app
      2. Trigger hotkey (simulate key down)
      3. Capture screen: screencapture indicator.png
      4. Verify floating pill visible
    Expected Result: Recording indicator visible on screen
    Evidence: .sisyphus/evidence/task-14-indicator-visible.png

  Scenario: Indicator does not steal focus
    Tool: interactive_bash (tmux)
    Steps:
      1. Focus TextEdit
      2. Trigger recording via hotkey
      3. Check focused app: osascript -e 'tell application "System Events" to name of first process whose frontmost is true'
    Expected Result: TextEdit still frontmost (not MyVoiceInput)
    Evidence: .sisyphus/evidence/task-14-no-focus-steal.txt

  Scenario: Indicator disappears after recording
    Tool: interactive_bash (tmux)
    Steps:
      1. Trigger hotkey down, then up
      2. Wait 500ms
      3. Capture screen
      4. Verify no recording indicator visible
    Expected Result: Indicator not visible after recording ends
    Evidence: .sisyphus/evidence/task-14-indicator-hidden.png
  ```

  **Commit**: Groups with Tasks 13, 15-16

---

- [x] 15. Create Settings Window UI

  **What to do**:
  - Create `Views/SettingsView.swift` as SwiftUI view
  - Open in separate window via Settings scene (Cmd+, shortcut)
  - Sections:
    - **Hotkey**: KeyboardShortcuts.Recorder for configuring shortcut
    - **Microphone**: Picker with available devices from AudioCaptureService
    - **API**: Text fields for endpoint URL and model name
    - **General**: Toggle for auto-start with system
  - Bind all controls to AppSettings via AppState
  - Validate inputs (URL format, non-empty model)
  - Save settings automatically (UserDefaults via @AppStorage)

  **Must NOT do**:
  - Do NOT add theme/appearance options — follow system only
  - Do NOT add language selection — auto-detect only
  - Do NOT add multiple ASR provider options

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: Form-based SwiftUI with bindings and validation

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-14, 16-18)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18 (wiring), Task 19 (integration)
  - **Blocked By**: Tasks 5, 7 (needs device list), 10 (needs shortcut recorder)

  **References**:
  - Pattern: `richardwu/openwhisper` SettingsView with KeyboardShortcuts.Recorder
  - SwiftUI Settings scene: https://developer.apple.com/documentation/swiftui/settings
  - KeyboardShortcuts.Recorder usage

  **Acceptance Criteria**:
  - [ ] `Views/SettingsView.swift` exists
  - [ ] Cmd+, opens Settings window
  - [ ] Hotkey can be configured via Recorder
  - [ ] Microphone picker shows available devices
  - [ ] API endpoint and model fields save correctly
  - [ ] Auto-start toggle works

  **QA Scenarios**:
  ```
  Scenario: Settings window opens with Cmd+,
    Tool: interactive_bash (tmux)
    Steps:
      1. Launch app
      2. Send Cmd+, keystroke
      3. Check for Settings window: osascript -e 'tell application "System Events" to name of every window of process "MyVoiceInput"'
    Expected Result: Settings window appears
    Evidence: .sisyphus/evidence/task-15-settings-open.txt

  Scenario: Hotkey recorder works
    Tool: Playwright or manual
    Steps:
      1. Open Settings
      2. Click hotkey recorder
      3. Press Cmd+Shift+R
      4. Verify shortcut displayed
    Expected Result: Recorder shows "⌘⇧R"
    Evidence: .sisyphus/evidence/task-15-hotkey-set.png

  Scenario: Microphone picker shows devices
    Tool: Bash (XCTest)
    Steps:
      1. Render SettingsView in test
      2. Assert microphone picker has options
      3. Assert at least "Built-in Microphone" present
    Expected Result: Device list populated
    Evidence: .sisyphus/evidence/task-15-mic-picker.txt

  Scenario: API settings persist
    Tool: Bash (XCTest)
    Steps:
      1. Set endpoint to "http://custom:8000/v1/transcribe"
      2. Set model to "whisper-large"
      3. Quit and relaunch
      4. Assert values restored
    Expected Result: Settings persist across app restarts
    Evidence: .sisyphus/evidence/task-15-persistence.txt
  ```

  **Commit**: Groups with Tasks 13-14, 16

---

- [x] 16. Create Onboarding Wizard UI

  **What to do**:
  - Create `Views/OnboardingView.swift` as multi-step wizard
  - Steps:
    1. Welcome screen with app overview
    2. Microphone permission request (with button to trigger)
    3. Accessibility permission (with button to open Settings + instructions)
    4. Hotkey configuration (embed KeyboardShortcuts.Recorder)
    5. Done/completion screen
  - Track completion in AppState (`isOnboardingComplete`)
  - Show on first launch only
  - Allow revisiting from Settings or menu
  - Each step shows permission status (granted ✓ / denied ✗ / pending)

  **Must NOT do**:
  - Do NOT auto-request permissions — let user click explicitly
  - Do NOT skip steps — all steps required for first launch
  - Do NOT make wizard dismissable until permissions granted

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []
  - Reason: Multi-step wizard with permission flow and embedded recorder

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-15, 17-18)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18 (wiring), Task 19 (integration)
  - **Blocked By**: Tasks 5, 10 (hotkey recorder), 12 (permission checks)

  **References**:
  - Pattern: Various macOS apps with permission onboarding
  - SwiftUI TabView or custom navigation for steps
  - PermissionManager for status checks

  **Acceptance Criteria**:
  - [ ] `Views/OnboardingView.swift` exists
  - [ ] Wizard shows on first launch
  - [ ] Wizard does NOT show on subsequent launches
  - [ ] Permission status updates in real-time
  - [ ] Hotkey can be set in wizard
  - [ ] Completion sets `isOnboardingComplete = true`

  **QA Scenarios**:
  ```
  Scenario: Onboarding shows on first launch
    Tool: Bash
    Steps:
      1. Delete UserDefaults for app: defaults delete com.myvoiceinput.app
      2. Launch app
      3. Assert onboarding window appears
    Expected Result: Onboarding wizard visible
    Evidence: .sisyphus/evidence/task-16-first-launch.png

  Scenario: Onboarding hidden on subsequent launch
    Tool: Bash
    Steps:
      1. Complete onboarding (or set isOnboardingComplete in defaults)
      2. Relaunch app
      3. Assert no onboarding window
    Expected Result: App goes directly to menu bar mode
    Evidence: .sisyphus/evidence/task-16-no-onboarding.txt

  Scenario: Permission status updates
    Tool: interactive_bash (tmux)
    Steps:
      1. Open onboarding
      2. Grant microphone permission
      3. Assert mic step shows ✓
    Expected Result: Real-time status update
    Evidence: .sisyphus/evidence/task-16-permission-status.png

  Scenario: Cannot skip onboarding until permissions granted
    Tool: interactive_bash (tmux)
    Steps:
      1. Open onboarding with permissions denied
      2. Try to click "Done" or navigate away
      3. Assert blocked or button disabled
    Expected Result: User must complete permission steps
    Evidence: .sisyphus/evidence/task-16-no-skip.png
  ```

  **Commit**: Groups with Tasks 13-15

---

- [x] 17. Implement Audio Feedback (Sounds)

  **What to do**:
  - Create `Services/AudioFeedbackService.swift`
  - Include sound files in app bundle:
    - `start-recording.mp3` (subtle click or beep, <500ms)
    - `stop-recording.mp3` (different click/beep, <500ms)
    - `error.mp3` (warning tone, <500ms)
  - Use `AVAudioPlayer` or `NSSound` for playback
  - Provide methods: `playStartSound()`, `playStopSound()`, `playErrorSound()`
  - Add volume control or mute option in settings (optional stretch)

  **Must NOT do**:
  - Do NOT use system sounds (may not exist)
  - Do NOT make sounds jarring or loud
  - Do NOT play sounds when app is muted (respect system volume)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple audio playback with bundled files

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-16, 18)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 19 (integration)
  - **Blocked By**: Task 1 (needs project for resources)

  **References**:
  - NSSound for simple playback: `NSSound(named:)?.play()`
  - Free sounds: freesound.org, mixkit.co (ensure license allows bundling)

  **Acceptance Criteria**:
  - [ ] `Services/AudioFeedbackService.swift` exists
  - [ ] 3 sound files in app bundle
  - [ ] Sounds play without error
  - [ ] Sounds are subtle and appropriate

  **QA Scenarios**:
  ```
  Scenario: Start sound plays
    Tool: Bash (XCTest)
    Steps:
      1. Call playStartSound()
      2. Assert no error thrown
      3. (Sound plays — manual verification or duration check)
    Expected Result: Sound plays successfully
    Evidence: .sisyphus/evidence/task-17-start-sound.txt

  Scenario: Sound files bundled correctly
    Tool: Bash
    Steps:
      1. Build app
      2. Check bundle: ls ./build/Debug/MyVoiceInput.app/Contents/Resources/*.mp3
      3. Assert 3 sound files present
    Expected Result: start-recording.mp3, stop-recording.mp3, error.mp3 present
    Evidence: .sisyphus/evidence/task-17-bundle-sounds.txt

  Scenario: Error sound plays on error state
    Tool: Bash (XCTest)
    Steps:
      1. Trigger error state in AppState
      2. Assert playErrorSound called
    Expected Result: Error sound triggered
    Evidence: .sisyphus/evidence/task-17-error-sound.txt
  ```

  **Commit**: Groups with Task 18
  - Message: `feat(integration): wire up app state and audio feedback`

---

- [x] 18. Wire Up AppState to UI

  **What to do**:
  - Connect HotkeyManager callbacks to AppState
  - Connect recording state changes to:
    - Menu bar icon state updates
    - Recording indicator show/hide
    - Audio feedback sounds
  - Connect settings changes to services (microphone selection, API config)
  - Implement proper observation using @Observable pattern
  - Handle state transitions: idle → recording → transcribing → inserting → idle
  - Handle error states with user feedback

  **Must NOT do**:
  - Do NOT implement recording flow yet — just wire state to UI
  - Do NOT add business logic — just bindings

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: State management wiring across multiple components

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: End of Wave 3 (after 13-17)
  - **Blocks**: Task 19 (integration)
  - **Blocked By**: Tasks 5, 10, 13, 14, 17

  **References**:
  - Pattern: VoiceInk state binding patterns
  - SwiftUI @Observable + .onChange modifiers

  **Acceptance Criteria**:
  - [ ] Hotkey triggers state transition to .recording
  - [ ] Recording state shows indicator + menu icon change
  - [ ] State changes trigger appropriate sounds
  - [ ] Settings changes propagate to services

  **QA Scenarios**:
  ```
  Scenario: Hotkey triggers state change
    Tool: Bash (XCTest)
    Steps:
      1. Simulate hotkey down
      2. Assert AppState.recordingState == .recording
      3. Simulate hotkey up
      4. Assert state transitions to .transcribing
    Expected Result: State machine responds to hotkey
    Evidence: .sisyphus/evidence/task-18-state-hotkey.txt

  Scenario: UI responds to state changes
    Tool: interactive_bash (tmux)
    Steps:
      1. Set AppState.recordingState = .recording programmatically
      2. Assert recording indicator visible
      3. Assert menu bar icon changed
    Expected Result: UI reflects state
    Evidence: .sisyphus/evidence/task-18-ui-state.png

  Scenario: Settings update services
    Tool: Bash (XCTest)
    Steps:
      1. Change microphone selection in settings
      2. Assert AudioCaptureService uses new device
    Expected Result: Service reconfigured
    Evidence: .sisyphus/evidence/task-18-settings-propagate.txt
  ```

  **Commit**: Groups with Task 17

---

### Wave 4: Integration & Polish (After Wave 3)

- [x] 19. Integrate All Services in Recording Flow

  **What to do**:
  - Create `Services/RecordingFlowCoordinator.swift` to orchestrate the full flow:
    1. Hotkey down → Play start sound → Show indicator → Start audio capture
    2. Hotkey up → Stop audio capture → Hide indicator → Play stop sound
    3. Encode PCM to MP3
    4. Send to TranscriptionService
    5. For each chunk from stream → Insert text via TextInsertionService
    6. On completion → State back to idle
    7. On error → Show error, play error sound, state to error
  - Handle cancellation (if user presses escape or hotkey again)
  - Handle edge cases: very short recordings (<500ms), API timeout
  - Coordinate async operations properly
  - Ensure clipboard is restored even on errors

  **Must NOT do**:
  - Do NOT block the main thread
  - Do NOT lose audio if API call fails (consider retry option for future)
  - Do NOT leave indicator visible on error

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Complex async coordination with error handling and state management

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Start of Wave 4
  - **Blocks**: Tasks 21, 22
  - **Blocked By**: Tasks 7, 8, 9, 10, 11, 13, 14, 17, 18 (all services and UI)

  **References**:
  - Pattern: VoiceInk WhisperState recording flow
  - Swift async/await for coordination
  - All service implementations from Wave 2

  **Acceptance Criteria**:
  - [ ] `Services/RecordingFlowCoordinator.swift` exists
  - [ ] Full flow works: hotkey → record → transcribe → insert
  - [ ] Sounds play at correct times
  - [ ] Indicator shows/hides correctly
  - [ ] Errors handled gracefully
  - [ ] Clipboard restored after insertion

  **QA Scenarios**:
  ```
  Scenario: Full happy path flow
    Tool: interactive_bash (tmux) + TextEdit
    Preconditions: All permissions granted, ASR API running
    Steps:
      1. Open TextEdit with empty document
      2. Focus TextEdit
      3. Hold hotkey for 2 seconds, speak "Hello world"
      4. Release hotkey
      5. Wait for transcription (up to 10s)
      6. Assert TextEdit contains transcribed text
    Expected Result: Spoken words appear in TextEdit
    Evidence: .sisyphus/evidence/task-19-full-flow.png

  Scenario: Short recording handled
    Tool: interactive_bash (tmux)
    Steps:
      1. Press and release hotkey quickly (<500ms)
      2. Assert app handles gracefully (either transcribes or shows "too short" message)
    Expected Result: No crash, graceful handling
    Evidence: .sisyphus/evidence/task-19-short-recording.txt

  Scenario: API timeout handled
    Tool: Bash (XCTest with mock)
    Steps:
      1. Mock TranscriptionService to timeout after 5s
      2. Trigger recording flow
      3. Assert error state reached
      4. Assert error sound played
      5. Assert indicator hidden
    Expected Result: Error state, UI cleaned up
    Evidence: .sisyphus/evidence/task-19-timeout.txt

  Scenario: Clipboard preserved through flow
    Tool: interactive_bash (tmux)
    Steps:
      1. Copy "original content" to clipboard
      2. Run full recording flow
      3. Paste (Cmd+V) in TextEdit
      4. Assert "original content" pasted (not transcribed text)
    Expected Result: Clipboard restored to original
    Evidence: .sisyphus/evidence/task-19-clipboard.txt
  ```

  **Commit**: Groups with Tasks 20-21
  - Message: `feat(flow): integrate recording flow with error handling`

---

- [x] 20. Implement Auto-Start (SMAppService)

  **What to do**:
  - Create `Services/AutoStartService.swift`
  - Use `SMAppService.mainApp` for login item registration (macOS 13+)
  - Provide methods: `isEnabled: Bool`, `enable()`, `disable()`
  - Wire to Settings toggle
  - Handle errors (e.g., user disabled in System Settings)

  **Must NOT do**:
  - Do NOT use deprecated `LSSharedFileListInsertItemURL`
  - Do NOT use LaunchAgents — SMAppService is the modern approach

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Simple API, well-documented

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 19, 21)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 22 (integration test)
  - **Blocked By**: Tasks 1, 2

  **References**:
  - Apple docs: https://developer.apple.com/documentation/servicemanagement/smappservice
  - Pattern: Simple toggle with error handling

  **Acceptance Criteria**:
  - [ ] `Services/AutoStartService.swift` exists
  - [ ] Toggle in Settings enables/disables login item
  - [ ] Status reflects actual state in System Settings

  **QA Scenarios**:
  ```
  Scenario: Enable auto-start
    Tool: Bash
    Steps:
      1. Call enable()
      2. Check status: sfltool dumpbtm | grep MyVoiceInput
      3. Assert app listed as login item
    Expected Result: App appears in login items
    Evidence: .sisyphus/evidence/task-20-enable.txt

  Scenario: Disable auto-start
    Tool: Bash
    Steps:
      1. Enable first
      2. Call disable()
      3. Assert isEnabled == false
    Expected Result: Login item removed
    Evidence: .sisyphus/evidence/task-20-disable.txt

  Scenario: Settings toggle syncs
    Tool: interactive_bash (tmux)
    Steps:
      1. Open Settings
      2. Toggle auto-start ON
      3. Assert AutoStartService.isEnabled == true
      4. Toggle OFF
      5. Assert isEnabled == false
    Expected Result: UI and service in sync
    Evidence: .sisyphus/evidence/task-20-settings-sync.txt
  ```

  **Commit**: Groups with Tasks 19, 21

---

- [x] 21. Add Error Handling and User Feedback

  **What to do**:
  - Create `Services/ErrorHandlingService.swift`
  - Define error types: `AppError` enum with cases for common failures
  - Show user-friendly alerts for critical errors (NSAlert or SwiftUI alert)
  - Show transient notifications for recoverable errors (menu bar flash or notification)
  - Log errors for debugging (OSLog)
  - Handle specific errors:
    - No microphone permission → prompt to Settings
    - No accessibility permission → prompt to Settings
    - API connection failed → show endpoint in error
    - API response error → show error message from API
    - Encoding failed → generic error with retry option

  **Must NOT do**:
  - Do NOT show technical error messages to users
  - Do NOT swallow errors silently — always provide feedback
  - Do NOT block app on non-critical errors

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Error UX design plus technical error handling

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 19, 20)
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 22 (integration test)
  - **Blocked By**: Task 19 (needs flow to integrate)

  **References**:
  - Pattern: User-friendly error messages
  - OSLog for structured logging
  - NSAlert or SwiftUI .alert modifier

  **Acceptance Criteria**:
  - [ ] `Services/ErrorHandlingService.swift` exists
  - [ ] `AppError` enum with all error cases
  - [ ] User-friendly messages for each error type
  - [ ] Errors logged to OSLog
  - [ ] Alerts shown for critical errors

  **QA Scenarios**:
  ```
  Scenario: API connection error shows alert
    Tool: Bash (XCTest with mock)
    Steps:
      1. Configure API endpoint to invalid URL
      2. Trigger recording flow
      3. Assert alert shown with "Cannot connect to transcription service"
    Expected Result: User-friendly error alert
    Evidence: .sisyphus/evidence/task-21-api-error.txt

  Scenario: Missing permission error prompts settings
    Tool: interactive_bash (tmux)
    Steps:
      1. Revoke microphone permission
      2. Trigger recording
      3. Assert alert with "Open Settings" button
      4. Click button, assert Settings opens
    Expected Result: User guided to fix permission
    Evidence: .sisyphus/evidence/task-21-permission-error.png

  Scenario: Errors logged
    Tool: Bash
    Steps:
      1. Trigger an error condition
      2. Check logs: log show --predicate 'subsystem == "com.myvoiceinput.app"' --last 1m
      3. Assert error logged with context
    Expected Result: Error in OSLog with details
    Evidence: .sisyphus/evidence/task-21-logging.txt
  ```

  **Commit**: Groups with Tasks 19, 20

---

- [x] 22. End-to-End Integration Tests

  **What to do**:
  - Create `Tests/IntegrationTests/` directory
  - Write integration tests that exercise full flows:
    - Complete recording flow with mock ASR
    - Permission flow simulation
    - Settings persistence across restarts
    - Auto-start enable/disable
  - Use mock services where needed (especially ASR API)
  - Set up test fixtures for audio data
  - Ensure tests can run headless in CI

  **Must NOT do**:
  - Do NOT require real ASR API for tests
  - Do NOT require UI interaction — use programmatic triggers
  - Do NOT make tests flaky with timing issues

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: Integration testing requires careful mocking and flow understanding

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: After Tasks 19-21
  - **Blocks**: Task 23, Final Wave
  - **Blocked By**: Tasks 19, 20, 21

  **References**:
  - XCTest for integration tests
  - Mock patterns from unit tests
  - Test fixtures for audio samples

  **Acceptance Criteria**:
  - [ ] `Tests/IntegrationTests/` exists with test files
  - [ ] Recording flow test passes
  - [ ] Settings persistence test passes
  - [ ] All tests pass: `xcodebuild test`

  **QA Scenarios**:
  ```
  Scenario: All integration tests pass
    Tool: Bash
    Steps:
      1. Run: xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput test
      2. Assert exit code 0
      3. Assert all tests pass (no failures)
    Expected Result: All tests green
    Evidence: .sisyphus/evidence/task-22-tests-pass.txt

  Scenario: Recording flow integration test
    Tool: Bash (read test output)
    Steps:
      1. Run specific test: RecordingFlowIntegrationTests
      2. Assert mock audio captured
      3. Assert mock transcription returned
      4. Assert text insertion called
    Expected Result: Full flow exercised with mocks
    Evidence: .sisyphus/evidence/task-22-flow-test.txt
  ```

  **Commit**: Groups with Task 23
  - Message: `feat(release): add integration tests and build app bundle`

---

- [x] 23. Build and Package .app Bundle

  **What to do**:
  - Create release build configuration
  - Set up code signing (if certificate available) or ad-hoc signing
  - Create `Makefile` or script for building release:
    - `xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput -configuration Release build`
  - Create DMG or ZIP for distribution (optional)
  - Document installation instructions in README
  - Verify app launches correctly from build output

  **Must NOT do**:
  - Do NOT notarize (not needed for direct distribution with user trust)
  - Do NOT create installer package — simple .app copy is sufficient

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - Reason: Standard Xcode build process

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: End of Wave 4
  - **Blocks**: Final Wave
  - **Blocked By**: Task 22 (all tests must pass first)

  **References**:
  - xcodebuild documentation
  - Ad-hoc code signing: codesign --sign -

  **Acceptance Criteria**:
  - [ ] Release build succeeds
  - [ ] .app bundle produced at expected path
  - [ ] App launches from Finder
  - [ ] README has installation instructions

  **QA Scenarios**:
  ```
  Scenario: Release build succeeds
    Tool: Bash
    Steps:
      1. Run: xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput -configuration Release build
      2. Assert exit code 0
      3. Assert .app exists: ls ./build/Release/MyVoiceInput.app
    Expected Result: App bundle created
    Evidence: .sisyphus/evidence/task-23-release-build.txt

  Scenario: App launches from Finder
    Tool: Bash
    Steps:
      1. Open app: open ./build/Release/MyVoiceInput.app
      2. Wait 3 seconds
      3. Check process running: pgrep -x MyVoiceInput
    Expected Result: Process running
    Evidence: .sisyphus/evidence/task-23-app-launches.txt

  Scenario: App shows in menu bar
    Tool: Bash + screencapture
    Steps:
      1. Launch release app
      2. Capture menu bar
      3. Verify icon visible
    Expected Result: Menu bar icon present
    Evidence: .sisyphus/evidence/task-23-menubar.png
  ```

  **Commit**: Groups with Task 22

---

## Final Verification Wave (MANDATORY)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `swiftc` type check + SwiftLint (if configured) + `swift test`. Review all Swift files for: `as! Any`, force unwraps without guard, empty catches, print statements in prod code, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill if applicable)
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration. Test edge cases: no microphone, API offline, rapid hotkey presses, clipboard with rich content.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual implementation. Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| After Task(s) | Commit Message | Pre-commit Check |
|---------------|----------------|------------------|
| 1-2 | `chore(project): initialize Xcode project with SwiftUI lifecycle` | Build succeeds |
| 3-6 | `feat(core): add dependencies and data models` | Build succeeds |
| 7-8 | `feat(audio): implement audio capture and MP3 encoding` | Tests pass |
| 9 | `feat(transcription): implement streaming ASR client` | Tests pass |
| 10 | `feat(hotkey): implement press-and-hold hotkey manager` | Tests pass |
| 11-12 | `feat(services): implement text insertion and permissions` | Tests pass |
| 13-16 | `feat(ui): implement menu bar, indicator, settings, onboarding` | Build succeeds |
| 17-18 | `feat(integration): wire up app state and audio feedback` | Tests pass |
| 19-21 | `feat(flow): integrate recording flow with error handling` | Tests pass |
| 22-23 | `feat(release): add integration tests and build app bundle` | All tests pass |

---

## Success Criteria

### Verification Commands
```bash
# Build succeeds
xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput -configuration Debug build

# Tests pass
xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput test

# App launches as menu bar only
open ./build/Debug/MyVoiceInput.app && sleep 2 && pgrep -x MyVoiceInput

# Verify no Dock icon (LSUIElement)
/usr/libexec/PlistBuddy -c "Print :LSUIElement" MyVoiceInput/Info.plist  # Expected: true
```

### Final Checklist
- [ ] All "Must Have" features present and functional
- [ ] All "Must NOT Have" patterns absent from codebase
- [ ] All unit tests pass
- [ ] All QA scenarios pass with evidence
- [ ] App builds without warnings
- [ ] App runs as menu bar only (no Dock icon)
- [ ] Permissions requested appropriately
- [ ] Recording indicator appears/disappears correctly
- [ ] Text insertion works in TextEdit, Notes, browser text fields
