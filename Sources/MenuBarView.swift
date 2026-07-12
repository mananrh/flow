import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var updateManager = UpdateManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Home — opens the main window
            Button("Home") {
                NotificationCenter.default.post(name: .showHome, object: nil)
            }
            .padding(.vertical, 2)

            Divider()

            // Check for updates
            Button {
                Task { await updateManager.checkForUpdates(userInitiated: true) }
            } label: {
                if updateManager.isChecking {
                    Text("Checking for updates…")
                } else {
                    Text("Check for updates…")
                }
            }
            .disabled(updateManager.isChecking)
            .padding(.vertical, 2)

            Divider()

            // Paste last transcript
            Button("Paste last transcript") {
                guard !appState.lastTranscript.isEmpty else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(appState.lastTranscript, forType: .string)
            }
            .keyboardShortcut("v", modifiers: [.control, .command])
            .disabled(appState.lastTranscript.isEmpty)
            .padding(.vertical, 2)

            Divider()

            // Shortcuts — opens settings to General tab
            Button("Shortcuts") {
                appState.selectedSettingsTab = .general
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .padding(.vertical, 2)

            // Microphone submenu
            Menu("Microphone") {
                Button {
                    appState.selectedMicrophoneID = "default"
                } label: {
                    if appState.selectedMicrophoneID == "default" || appState.selectedMicrophoneID.isEmpty {
                        Text("✓ System Default")
                    } else {
                        Text("  System Default")
                    }
                }
                ForEach(appState.availableMicrophones) { device in
                    Button {
                        appState.selectedMicrophoneID = device.uid
                    } label: {
                        if appState.selectedMicrophoneID == device.uid {
                            Text("✓ \(device.name)")
                        } else {
                            Text("  \(device.name)")
                        }
                    }
                }
            }

            // Languages submenu
            Menu("Languages") {
                ForEach(AppState.transcriptionLanguageOptions, id: \.code) { option in
                    Button {
                        appState.transcriptionLanguage = option.code
                    } label: {
                        if appState.transcriptionLanguage == option.code {
                            Text("✓ \(option.name)")
                        } else {
                            Text("  \(option.name)")
                        }
                    }
                }
            }

            Divider()

            // Settings
            Button("Settings") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .padding(.vertical, 2)

            Divider()

            // Quit
            Button("Quit \(AppName.displayName)") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.vertical, 2)
        }
        .padding(4)
    }
}
