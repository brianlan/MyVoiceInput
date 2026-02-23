import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    @State private var apiEndpoint: String = ""
    @State private var modelName: String = ""
    @State private var transcriptionLanguage: String = ""
    @State private var selectedMicrophoneID: String = ""
    @State private var autoStartEnabled: Bool = false
    @State private var inputDevices: [AudioDevice] = []
    
    @State private var endpointError: String? = nil
    @State private var modelNameError: String? = nil
    
    var body: some View {
        TabView {
            GeneralSettingsView(autoStartEnabled: $autoStartEnabled)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AudioSettingsView(selectedMicrophoneID: $selectedMicrophoneID, inputDevices: inputDevices)
                .tabItem {
                    Label("Audio", systemImage: "mic")
                }
            
            APISettingsView(
                endpoint: $apiEndpoint,
                modelName: $modelName,
                transcriptionLanguage: $transcriptionLanguage,
                endpointError: endpointError,
                modelNameError: modelNameError
            )
                .tabItem {
                    Label("API", systemImage: "network")
                }
            
            HotkeySettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 450, height: 250)
        .onAppear {
            loadSettings()
            loadInputDevices()
        }
        .onChange(of: apiEndpoint) { _, _ in saveSettings() }
        .onChange(of: modelName) { _, _ in saveSettings() }
        .onChange(of: transcriptionLanguage) { _, _ in saveSettings() }
        .onChange(of: selectedMicrophoneID) { _, _ in saveSettings() }
        .onChange(of: autoStartEnabled) { _, _ in saveSettings() }
    }
    
    private func loadSettings() {
        let settings = appState.settings
        self.apiEndpoint = settings.apiEndpoint
        self.modelName = settings.modelName
        self.transcriptionLanguage = settings.transcriptionLanguage ?? ""
        // Validate saved microphone ID exists in available devices
        let savedID = settings.selectedMicrophoneID
        if let savedID, !savedID.isEmpty {
            let service = AudioCaptureService()
            let devices = service.availableInputDevices()
            let deviceExists = devices.contains { $0.id == savedID }
            self.selectedMicrophoneID = deviceExists ? savedID : ""
        } else {
            self.selectedMicrophoneID = ""
        }
        self.autoStartEnabled = appState.autoStartIsEnabled
    }
    
    private func loadInputDevices() {
        let service = AudioCaptureService()
        self.inputDevices = service.availableInputDevices()
        // If saved ID is not in devices, clear selection
        if !selectedMicrophoneID.isEmpty && !inputDevices.contains(where: { $0.id == selectedMicrophoneID }) {
            selectedMicrophoneID = ""
        }
    }
    
    private func saveSettings() {
        var isValid = true
        
        if let url = URL(string: apiEndpoint), url.scheme != nil, url.host != nil {
            endpointError = nil
        } else {
            endpointError = "Invalid URL"
            isValid = false
        }
        
        // Model name can be empty (optional)
        modelNameError = nil
        
        if isValid {
            let newSettings = AppSettings(
                hotkeyKeyCode: appState.settings.hotkeyKeyCode,
                hotkeyModifiers: appState.settings.hotkeyModifiers,
                apiEndpoint: apiEndpoint,
                modelName: modelName,
                transcriptionLanguage: transcriptionLanguage.isEmpty ? nil : transcriptionLanguage,
                selectedMicrophoneID: selectedMicrophoneID.isEmpty ? nil : selectedMicrophoneID,
                autoStartEnabled: autoStartEnabled
            )
            appState.updateSettings(newSettings)
        }
    }
}

struct GeneralSettingsView: View {
    @Binding var autoStartEnabled: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $autoStartEnabled)
                    .help("Automatically start MyVoiceInput when you log in")
            }
        }
        .formStyle(.grouped)
    }
}

struct AudioSettingsView: View {
    @Binding var selectedMicrophoneID: String
    let inputDevices: [AudioDevice]
    
    var body: some View {
        Form {
            Section {
                Picker("Microphone:", selection: $selectedMicrophoneID) {
                    Text("System Default").tag("")
                    ForEach(inputDevices, id: \.id) { device in
                        Text(device.name).tag(device.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct APISettingsView: View {
    @Binding var endpoint: String
    @Binding var modelName: String
    @Binding var transcriptionLanguage: String
    var endpointError: String?
    var modelNameError: String?
    
    var body: some View {
        Form {
            Section {
                TextField("API Endpoint:", text: $endpoint)
                    .textFieldStyle(.roundedBorder)
                    .help("The URL of the transcription API")
                if let error = endpointError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                TextField("Model Name:", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .help("The model to use for transcription (e.g., 'whisper-1')")
                if let error = modelNameError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Picker("Language:", selection: $transcriptionLanguage) {
                    Text("Auto Detect").tag("")
                    Text("English").tag("en")
                    Text("Chinese").tag("zh")
                }
                .help("Force transcription language when auto-detection is inaccurate")
            }
        }
        .formStyle(.grouped)
    }
}

struct HotkeySettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle Recording:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .holdToTalk)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
