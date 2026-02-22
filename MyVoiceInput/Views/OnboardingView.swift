import SwiftUI
import KeyboardShortcuts

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    enum Step: Int, CaseIterable {
        case welcome
        case microphone
        case accessibility
        case hotkey
        case done
    }
    
    @State private var currentStep: Step = .welcome
    @State private var micStatus: Bool = false
    @State private var a11yStatus: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Step.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            
            VStack {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .microphone:
                    microphoneView
                case .accessibility:
                    accessibilityView
                case .hotkey:
                    hotkeyView
                case .done:
                    doneView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.push(from: .trailing))
            
            HStack {
                if currentStep != .welcome && currentStep != .done {
                    Button("Back") {
                        withAnimation {
                            currentStep = Step(rawValue: currentStep.rawValue - 1) ?? .welcome
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                Spacer()
                
                if currentStep == .done {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Next") {
                        withAnimation {
                            currentStep = Step(rawValue: currentStep.rawValue + 1) ?? .done
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canProceed)
                }
            }
            .padding(30)
        }
        .frame(width: 500, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(timer) { _ in
            checkPermissions()
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.bounce, value: currentStep)
            
            Text("Welcome to MyVoiceInput")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("Your AI-powered voice assistant for macOS.\nLet's get you set up in just a few steps.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var microphoneView: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(micStatus ? .green : .orange)
            
            VStack(spacing: 8) {
                Text("Microphone Access")
                    .font(.title2.bold())
                
                Text("We need access to your microphone to capture your voice.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            if micStatus {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Access Granted")
                }
                .foregroundStyle(.green)
                .font(.headline)
                .padding()
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Button("Request Access") {
                    requestMicPermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
    }
    
    private var accessibilityView: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 48))
                .foregroundStyle(a11yStatus ? .green : .orange)
            
            VStack(spacing: 8) {
                Text("Accessibility Access")
                    .font(.title2.bold())
                
                Text("We need accessibility permissions to type text into other applications.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            if a11yStatus {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Access Granted")
                }
                .foregroundStyle(.green)
                .font(.headline)
                .padding()
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 12) {
                    Button("Open System Settings") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Text("Enable MyVoiceInput in:\nPrivacy & Security → Accessibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
    
    private var hotkeyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("Set Your Hotkey")
                    .font(.title2.bold())
                
                Text("Choose a key combination to start listening.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            
            VStack {
                Text("Hold to Talk")
                    .font(.headline)
                
                KeyboardShortcuts.Recorder(for: .holdToTalk)
                    .controlSize(.large)
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    
    private var doneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.bounce)
            
            Text("You're All Set!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("MyVoiceInput runs in your menu bar.\nPress your hotkey to start dictating.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .welcome: return true
        case .microphone: return micStatus
        case .accessibility: return a11yStatus
        case .hotkey: return true
        case .done: return true
        }
    }
    
    private func checkPermissions() {
        let pm = PermissionManager()
        micStatus = pm.hasMicrophonePermission()
        a11yStatus = pm.hasAccessibilityPermission()
    }
    
    private func requestMicPermission() {
        Task {
            let pm = PermissionManager()
            _ = await pm.requestMicrophonePermission()
            checkPermissions()
        }
    }
    
    private func openAccessibilitySettings() {
        let pm = PermissionManager()
        pm.openAccessibilitySettings()
    }
    
    private func completeOnboarding() {
        appState.isOnboardingComplete = true
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
            window.close()
        } else {
             NSApp.keyWindow?.close()
        }
    }
}
