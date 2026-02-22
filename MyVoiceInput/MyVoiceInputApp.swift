import SwiftUI

@main
struct MyVoiceInputApp: App {
    @State private var appState = AppState.shared
    @State private var wiringCoordinator = AppWiringCoordinator()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MyVoiceInput", systemImage: iconName) {
            Group {
                Button("Onboarding Wizard...") {
                    appDelegate.showOnboarding()
                    NSApp.activate(ignoringOtherApps: true)
                }

                Button("Settings...") {
                    appDelegate.showSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                if let feedback = appState.transientFeedbackMessage {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .environment(appState)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.showSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    private var iconName: String {
        switch appState.recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "mic.circle.fill"
        case .transcribing, .inserting:
            return "waveform"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var onboardingWindowController: NSWindowController?
    var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
        if !onboardingComplete {
            showOnboarding()
        }
    }

    func showOnboarding() {
        if onboardingWindowController == nil {
            let onboardingView = OnboardingView()
                .environment(AppState.shared)

            let hostingController = NSHostingController(rootView: onboardingView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.center()
            window.contentViewController = hostingController
            window.title = "Onboarding Wizard"
            window.identifier = NSUserInterfaceItemIdentifier("onboarding")
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true

            let controller = NSWindowController(window: window)
            onboardingWindowController = controller
        }

        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settingsWindowController == nil {
            let settingsView = SettingsView()
                .environment(AppState.shared)

            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            window.center()
            window.contentViewController = hostingController
            window.title = "Settings"
            window.identifier = NSUserInterfaceItemIdentifier("settings")

            let controller = NSWindowController(window: window)
            settingsWindowController = controller
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
