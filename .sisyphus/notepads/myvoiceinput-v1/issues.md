
## Environment Blockers (Feb 21, 2026)

- Xcode is not installed in `/Applications` in this environment; `xcodebuild` fails with `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`.
- SourceKit/LSP diagnostics on `MyVoiceInput/MyVoiceInputApp.swift` reports `@main attribute cannot be used in a module that contains top-level code` (likely due to missing Xcode project build context); treat LSP output as unreliable until Xcode build tooling is available.
- SourceKit/LSP also fails to resolve cross-file symbols in this repo (e.g. `RecordingState`, `AppSettings` referenced from `MyVoiceInput/AppState.swift`), even when the `.xcodeproj` includes all sources. Treat as an environment/tooling limitation.

## Additional Project Corruption Pattern (Feb 22, 2026)

- `project.pbxproj` had dangling `PBXSourcesBuildPhase` entries for `A1000071` and `A1000073` without matching `PBXBuildFile` object definitions; this can silently break target source inclusion and should be checked alongside object-ID collisions.

## @AppStorage + @Observable Conflict (Feb 22, 2026)

- **Problem**: Combining `@Observable` macro with `@AppStorage` property wrappers on the same class causes compilation errors like:
  - "property wrapper cannot be applied to a computed property"
  - "init accessor cannot refer to property '_endpointStorage'; init accessors can refer only to stored properties"
- **Root cause**: The `@Observable` macro generates `ObservationTracked` macros that conflict with `@AppStorage`'s custom `init(accessor:)` requirements. Both macros try to control property initialization in incompatible ways.
- **Workaround applied**: Added `@ObservationIgnored` to all `@AppStorage` properties in `AppState.swift`. This tells the `@Observable` macro to exclude these properties from observation tracking, while still allowing `@AppStorage` to handle persistence via UserDefaults.
- **Result**: The class remains `@Observable` (for observed properties like `recordingState`, `settings`, `isOnboardingComplete`, `permissionStatus`), while settings persistence still works via `@AppStorage` on ignored properties.

## httpBody vs httpBodyStream (Feb 22, 2026)

- **Problem**: `testTranscribeBuildsMultipartFormRequest()` failed because it tried to read the request body via `request.httpBody`, but URLSession with streaming (or certain configurations) provides the body via `request.httpBodyStream` instead.
- **Root cause**: When using `URLSession` with an ephemeral configuration and custom `URLProtocol`, the request body may be presented as a stream rather than as pre-loaded `Data`. The production code sets `request.httpBody = body`, but the URLProtocol receives it via `httpBodyStream`.
- **Fix applied**: Updated the test to first check `request.httpBody`, and if nil, read all bytes from `request.httpBodyStream` into `Data`.
- **Verification**: Test now passes with `xcodebuild test`.

## testTranscribeBuildsMultipartFormRequest() Refactor (Feb 22, 2026)

- **Issue**: The inline body extraction logic was duplicated in the test function.
- **Fix applied**: Refactored into a private helper function `extractRequestBody(from:)` that handles both `httpBody` and `httpBodyStream`, with proper stream reading and error handling via `XCTFail`.
- **Note**: URLProtocol-based tests commonly see body data via `httpBodyStream` because the URL loading system streams large request bodies rather than pre-loading them into memory.

## Project Structure
- `OnboardingView.swift` could not be added to the Xcode project without modifying `.pbxproj`, which is risky.
- Code for `OnboardingView` was moved to `MyVoiceInputApp.swift` to pass the build. It should be moved to its own file and added to the project target manually.

- **Notification-based Launch Failure**: The notification-based approach (`NotificationCenter.default.post(name: .showOnboarding)`) failed to reliably open the onboarding window on first launch. This is likely because the `MenuBarExtra` content, which contained the `.onReceive` modifier, had not yet been fully initialized or subscribed to the notification when the `AppDelegate` posted it (even with a 1-second delay). Direct window management in `AppDelegate` was required.

## Onboarding Auto-Show Regression (Feb 22, 2026)

- **Problem**: Onboarding window still appeared even after running `defaults write com.myvoiceinput.app onboardingComplete -bool true`.
- **Root cause**: `AppDelegate.applicationDidFinishLaunching` checked `AppState.shared.isOnboardingComplete` which is unreliable at launch because the `@Observable` state may not be synchronized with UserDefaults at that point.
- **Fix applied**: Changed the check in `AppDelegate.applicationDidFinishLaunching` to read directly from `UserDefaults.standard.bool(forKey: "onboardingComplete")` instead of via `AppState.shared.isOnboardingComplete`.
- **Verification**: Tests pass with `xcodebuild test`.

## SMAppService Auto-Start (Task 20)

- **No additional blockers identified**: SMAppService.mainApp is available on macOS 13+ (the app targets macOS 14.0), and no special entitlements are required for the main app to register itself as a login item.
- **Status Reporting**: SMAppService.status can return `.notRegistered`, `.enabled`, or `.notFound`; UI sync reads this on each settings load to reflect actual state.
- **Error Visibility**: If `register()` or `unregister()` fails, errors are logged but user gets no UI feedback (toggle will reflect actual state on next load).
