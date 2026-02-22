# MyVoiceInput

A macOS 14+ menu bar app that records audio while a hotkey is held, sends MP3 audio to a local ASR HTTP endpoint with streaming SSE output, and inserts the transcription into the focused app in real-time.

## Features

- **Press-and-Hold Recording** - Hold a configurable global hotkey to record audio
- **Streaming Transcription** - Real-time text insertion as speech is transcribed
- **Menu Bar Only** - Runs as a menu bar app with no Dock icon
- **Floating Indicator** - Visual recording indicator appears near cursor during recording
- **Audio Feedback** - Subtle sounds play on recording start/stop/error
- **Settings** - Configure hotkey, microphone, and API endpoint
- **Onboarding** - Guided permission setup for microphone and accessibility
- **Auto-Start** - Optional launch at system startup

## Requirements

- macOS 14.0 (Sonoma) or later
- A local ASR HTTP API endpoint (e.g., running a Whisper model server)

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/MyVoiceInput.git
   cd MyVoiceInput
   ```

2. Open in Xcode:
   ```bash
   open MyVoiceInput.xcodeproj
   ```

3. Build and run (Cmd+R) in Xcode

## Configuration

### API Endpoint

By default, the app expects an ASR API at `http://127.0.0.1:8010/v1/audio/transcriptions`. Configure a different endpoint in Settings.

The API should accept:
- POST request with `multipart/form-data`
- `file`: Audio file (MP3)
- `model`: Model name
- `stream`: Set to `true` for streaming response

The app expects SSE (Server-Sent Events) streaming response with JSON chunks containing transcribed text.

### Hotkey

Default hotkey is **Option + R** (Alt+R). Change this in Settings (Cmd+,).

### Microphone

Select your preferred input device in Settings. The app will use this device for all recordings.

## Permissions

On first launch, the app will guide you through granting required permissions:

1. **Microphone** - Required for audio recording
2. **Accessibility** - Required for inserting text into other apps

## Usage

1. Launch the app - it appears in the menu bar (no Dock icon)
2. Hold the configured hotkey to start recording
3. Speak your message
4. Release the hotkey to stop recording and transcribe
5. Transcription appears in the previously focused app

## Project Structure

```
MyVoiceInput/
├── AppState.swift              # Central app state management
├── MyVoiceInputApp.swift      # App entry point & menu bar
├── Models/                    # Data models
│   ├── RecordingState.swift
│   ├── AppSettings.swift
│   └── ...
├── Services/                  # Core services
│   ├── AudioCaptureService.swift
│   ├── TranscriptionService.swift
│   ├── TextInsertionService.swift
│   └── ...
├── Views/                     # SwiftUI views
│   ├── SettingsView.swift
│   ├── OnboardingView.swift
│   └── ...
└── Protocols/                  # Service protocols

MyVoiceInputTests/             # Unit tests
```

## Development

### Building

```bash
# Debug build
xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput -configuration Debug build

# Release build
xcodebuild -project MyVoiceInput.xcodeproj -scheme MyVoiceInput -configuration Release build
```

### Running Tests

```bash
xcodebuild test -project MyVoiceInput.xcodeproj -scheme MyVoiceInput
```

## License

MIT License
