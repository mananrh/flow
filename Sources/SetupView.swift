import SwiftUI
import AVFoundation
import Combine
import Foundation
import ServiceManagement

private struct SetupProviderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiBaseURLInput: String
    @Binding var transcriptionAPIURLInput: String
    @Binding var transcriptionAPIKeyInput: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Advanced Provider Settings")
                    .font(.title2.weight(.semibold))
                Text("Use these fields when pointing \(AppName.displayName) at another OpenAI-compatible provider or when you need custom model IDs.")
                    .font(.subheadline)
                    .foregroundStyle(FlowColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            ScrollView {
                ProviderSettingsFields(
                    apiBaseURLInput: $apiBaseURLInput,
                    transcriptionAPIURLInput: $transcriptionAPIURLInput,
                    transcriptionAPIKeyInput: $transcriptionAPIKeyInput,
                    showsModelDescription: true
                )
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 520)
    }
}

struct SetupView: View {
    var onComplete: () -> Void
    @EnvironmentObject var appState: AppState
    private enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case apiKey
        case micPermission
        case accessibility
        case screenRecording
        case holdShortcut
        case toggleShortcut
        case commandMode
        case vocabulary
        case launchAtLogin
        case testTranscription
        case ready
    }

    @State private var currentStep = SetupStep.welcome
    @State private var micPermissionGranted = false
    @State private var accessibilityGranted = false
    @State private var apiKeyInput: String = ""
    @State private var apiBaseURLInput: String = ""
    @State private var transcriptionAPIURLInput: String = ""
    @State private var transcriptionAPIKeyInput: String = ""
    @State private var isValidatingKey = false
    @State private var keyValidationError: String?
    @State private var showingProviderSettingsSheet = false
    @State private var accessibilityTimer: Timer?
    @State private var screenRecordingTimer: Timer?
    @State private var customVocabularyInput: String = ""

    // Test transcription state
    private enum TestPhase: Equatable {
        case idle, recording, transcribing, done
    }
    @State private var testPhase: TestPhase = .idle
    @State private var testAudioRecorder: AudioRecorder? = nil
    @State private var testAudioLevel: Float = 0.0
    @State private var testTranscript: String = ""
    @State private var testError: String? = nil
    @State private var testAudioLevelCancellable: AnyCancellable? = nil
    @State private var testMicPulsing = false
    @State private var holdShortcutValidationMessage: String?
    @State private var toggleShortcutValidationMessage: String?
    @State private var isCapturingHoldShortcut = false
    @State private var isCapturingToggleShortcut = false
    @StateObject private var testHotkeyHarness = SetupTestHotkeyHarness()

    private let totalSteps: [SetupStep] = SetupStep.allCases
    private var isCapturingShortcut: Bool {
        isCapturingHoldShortcut || isCapturingToggleShortcut
    }

    var body: some View {
        VStack(spacing: 0) {
            currentStepView
                .foregroundStyle(FlowColors.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.vertical, 32)

            Divider()

            ZStack {
                stepIndicator

                HStack(alignment: .center) {
                    Group {
                        if currentStep != .welcome {
                            Button("Back") {
                                keyValidationError = nil
                                withAnimation {
                                    currentStep = previousStep(currentStep)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(FlowColors.textSecondary)
                            .disabled(isValidatingKey)
                        }
                    }

                    Spacer()

                    Group {
                        if currentStep != .ready {
                            if currentStep == .apiKey {
                                Button(isValidatingKey ? "Validating..." : "Continue") {
                                    validateAndContinue()
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(FlowColors.accent)
                                .keyboardShortcut(.defaultAction)
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidatingKey)
                            } else if currentStep == .vocabulary {
                                Button("Continue") {
                                    saveCustomVocabularyAndContinue()
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(FlowColors.accent)
                                .keyboardShortcut(.defaultAction)
                            } else if currentStep == .testTranscription {
                                HStack(spacing: 10) {
                                    Button("Skip") {
                                        stopTestHotkeyMonitoring()
                                        withAnimation {
                                            currentStep = nextStep(currentStep)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(FlowColors.textSecondary)

                                    Button("Continue") {
                                        stopTestHotkeyMonitoring()
                                        withAnimation {
                                            currentStep = nextStep(currentStep)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(FlowColors.accent)
                                    .keyboardShortcut(.defaultAction)
                                    .disabled(testPhase != .done || testTranscript.isEmpty || testError != nil)
                                }
                            } else {
                                Button("Continue") {
                                    withAnimation {
                                        currentStep = nextStep(currentStep)
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(FlowColors.accent)
                                .keyboardShortcut(.defaultAction)
                                .disabled(!canContinueFromCurrentStep)
                            }
                        } else {
                            Button("Get Started") {
                                onComplete()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(FlowColors.accent)
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                }
            }
            .padding(20)
            .background(FlowColors.cream)
        }
        .frame(width: 520, height: 680)
        .background(FlowColors.cream)
        .onAppear {
            apiKeyInput = appState.apiKey
            apiBaseURLInput = appState.apiBaseURL
            transcriptionAPIURLInput = appState.transcriptionAPIURL
            transcriptionAPIKeyInput = appState.transcriptionAPIKey
            customVocabularyInput = appState.customVocabulary
            checkMicPermission()
            checkAccessibility()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            screenRecordingTimer?.invalidate()
            appState.resumeHotkeyMonitoringAfterShortcutCapture()
        }
        .sheet(isPresented: $showingProviderSettingsSheet) {
            SetupProviderSettingsSheet(
                apiBaseURLInput: $apiBaseURLInput,
                transcriptionAPIURLInput: $transcriptionAPIURLInput,
                transcriptionAPIKeyInput: $transcriptionAPIKeyInput
            )
                .environmentObject(appState)
        }
        .onChange(of: isCapturingShortcut) { isCapturing in
            if isCapturing {
                appState.suspendHotkeyMonitoringForShortcutCapture()
            } else {
                appState.resumeHotkeyMonitoringAfterShortcutCapture()
            }
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .apiKey:
            apiKeyStep
        case .micPermission:
            micPermissionStep
        case .accessibility:
            accessibilityStep
        case .screenRecording:
            screenRecordingStep
        case .holdShortcut:
            holdShortcutStep
        case .toggleShortcut:
            toggleShortcutStep
        case .commandMode:
            commandModeStep
        case .vocabulary:
            vocabularyStep
        case .launchAtLogin:
            launchAtLoginStep
        case .testTranscription:
            testTranscriptionStep
        case .ready:
            readyStep
        }
    }

    // MARK: - Steps

    var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)

            VStack(spacing: 6) {
                Text("Welcome to \(AppName.displayName)")
                    .font(FlowFonts.pageTitle(30))
                    .foregroundStyle(FlowColors.textPrimary)

                Text("Dictate text anywhere on your Mac.\nHold to talk or tap to toggle dictation.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FlowColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var apiKeyStep: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(FlowColors.accent)

                Text("API Key")
                    .font(FlowFonts.pageTitle(22))
                    .foregroundStyle(FlowColors.textPrimary)

                Text("Enter an API key for your OpenAI-compatible provider. If you are not using Groq, expand the advanced provider settings and enter that provider's base URL and model IDs before continuing.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FlowColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Using Groq?")
                            .font(.subheadline.weight(.semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            instructionRow(number: "1", text: "Go to [console.groq.com/keys](https://console.groq.com/keys)")
                            instructionRow(number: "2", text: "Create a free account (if you don't have one)")
                            instructionRow(number: "3", text: "Click **Create API Key** and copy it")
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.06))
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.headline)
                            .foregroundStyle(FlowColors.textPrimary)
                        FlowSecureField(text: $apiKeyInput, isDisabled: isValidatingKey)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: apiKeyInput) { _ in
                                keyValidationError = nil
                            }

                        if let error = keyValidationError {
                            Label(error, systemImage: "xmark.circle.fill")
                                .foregroundStyle(FlowColors.danger)
                                .font(.caption)
                        }
                    }

                    Button {
                        showingProviderSettingsSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(FlowColors.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Advanced Provider Settings")
                                    .foregroundStyle(FlowColors.textPrimary)
                                Text("Base URL and model IDs")
                                    .font(.caption)
                                    .foregroundStyle(FlowColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FlowColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(FlowColors.surface.opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 440)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var micPermissionStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Microphone Access")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("\(AppName.displayName) needs access to your microphone to record audio for transcription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "mic.fill")
                    .frame(width: 24)
                    .foregroundStyle(FlowColors.accent)
                Text("Microphone")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textPrimary)
                Spacer()
                if micPermissionGranted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FlowColors.success)
                        Text("Granted")
                            .font(FlowFonts.caption())
                            .foregroundStyle(FlowColors.success)
                    }
                } else {
                    FlowPillButton(title: "Grant Access") {
                        requestMicPermission()
                    }
                }
            }
            .padding(12)
            .background(FlowColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        }
    }

    var accessibilityStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Accessibility Access")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("\(AppName.displayName) needs Accessibility access to paste transcribed text into your apps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "hand.raised.fill")
                    .frame(width: 24)
                    .foregroundStyle(FlowColors.accent)
                Text("Accessibility")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textPrimary)
                Spacer()
                if accessibilityGranted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FlowColors.success)
                        Text("Granted")
                            .font(FlowFonts.caption())
                            .foregroundStyle(FlowColors.success)
                    }
                } else {
                    FlowPillButton(title: "Open Settings") {
                        requestAccessibility()
                    }
                }
            }
            .padding(12)
            .background(FlowColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        }
        .onAppear {
            startAccessibilityPolling()
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
        }
    }

    var screenRecordingStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Screen Recording")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("\(AppName.displayName) intelligently adapts the transcription to the current app you're working in (ex. spelling names in an email correctly).")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("It needs this permission to see which app you're working in and any in-progress work. Nothing is stored on \(AppName.displayName)'s servers (\(AppName.displayName) doesn't have servers).")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "camera.viewfinder")
                    .frame(width: 24)
                    .foregroundStyle(FlowColors.accent)
                Text("Screen Recording")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textPrimary)
                Spacer()
                if appState.hasScreenRecordingPermission {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FlowColors.success)
                        Text("Granted")
                            .font(FlowFonts.caption())
                            .foregroundStyle(FlowColors.success)
                    }
                } else {
                    FlowPillButton(title: "Grant Access") {
                        appState.requestScreenCapturePermission()
                    }
                }
            }
            .padding(12)
            .background(FlowColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        }
        .onAppear {
            startScreenRecordingPolling()
        }
        .onDisappear {
            screenRecordingTimer?.invalidate()
        }
    }

    var holdShortcutStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Hold to Talk Shortcut")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("Choose the shortcut you want to hold while speaking.\nRelease it to stop unless you latch into tap mode later, or disable hold-to-talk entirely.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutRoleSection(
                role: .hold,
                selection: appState.holdShortcut,
                validationMessage: holdShortcutValidationMessage,
                isCapturing: $isCapturingHoldShortcut,
                onSelect: { binding in
                    holdShortcutValidationMessage = appState.setShortcut(binding, for: .hold)
                }
            )
                .padding(.top, 10)

            if appState.holdShortcut.usesFnKey {
                Text("Tip: If Fn opens Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

        }
    }

    var toggleShortcutStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "switch.2")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Tap to Toggle Shortcut")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("Choose the shortcut you want to tap once to start dictating and tap again to stop.\nIf this shortcut becomes active while you are holding the hold shortcut, \(AppName.displayName) latches into tap mode. You can also disable tap-to-toggle entirely.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutRoleSection(
                role: .toggle,
                selection: appState.toggleShortcut,
                validationMessage: toggleShortcutValidationMessage,
                isCapturing: $isCapturingToggleShortcut,
                onSelect: { binding in
                    toggleShortcutValidationMessage = appState.setShortcut(binding, for: .toggle)
                }
            )
                .padding(.top, 10)

            if appState.toggleShortcut.usesFnKey {
                Text("Tip: If Fn opens Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

        }
    }

    var vocabularyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Custom Vocabulary")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("Add words and phrases that should be preserved in post-processing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Vocabulary")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                TextEditor(text: $customVocabularyInput)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
                    .padding(10)
                    .background(FlowColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FlowColors.border, lineWidth: 1)
                    )

                Text("Separate entries with commas, new lines, or semicolons.")
                    .font(FlowFonts.caption())
                    .foregroundStyle(FlowColors.textSecondary)
            }

        }
    }

    var commandModeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "pencil")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Edit Mode")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("Transform selected text with a spoken instruction instead of dictating over it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowGroupedCard {
                FlowSettingsRow("Enable Edit Mode") {
                    Toggle("", isOn: Binding(
                        get: { appState.isCommandModeEnabled },
                        set: { newValue in
                            _ = appState.setCommandModeEnabled(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                FlowCardDivider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Invocation Style")
                        .font(FlowFonts.body(13))
                        .foregroundStyle(FlowColors.textPrimary)

                    HStack(spacing: 0) {
                        ForEach(CommandModeStyle.allCases) { style in
                            Button {
                                _ = appState.setCommandModeStyle(style)
                            } label: {
                                Text(style.title)
                                    .font(FlowFonts.body(12))
                                    .foregroundStyle(appState.commandModeStyle == style ? FlowColors.textPrimary : FlowColors.textSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(appState.commandModeStyle == style ? FlowColors.surface : Color.clear)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!appState.isCommandModeEnabled)
                            .opacity(appState.isCommandModeEnabled ? 1 : 0.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(FlowColors.pill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FlowColors.border, lineWidth: 1)
                    )

                    Group {
                        switch appState.commandModeStyle {
                        case .automatic:
                            Text("Automatic mode uses your normal dictation shortcut. If text is selected, \(AppName.displayName) transforms that selection instead of dictating new text.")
                                .font(FlowFonts.caption())
                                .foregroundStyle(FlowColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        case .manual:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Manual mode only triggers when you hold an extra modifier together with your normal dictation shortcut.")
                                    .font(FlowFonts.caption())
                                    .foregroundStyle(FlowColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 8) {
                                    Text("Extra Modifier")
                                        .font(FlowFonts.body(12))
                                        .foregroundStyle(FlowColors.textSecondary)

                                    Picker("", selection: Binding(
                                        get: { appState.commandModeManualModifier },
                                        set: { newValue in
                                            _ = appState.setCommandModeManualModifier(newValue)
                                        }
                                    )) {
                                        ForEach(CommandModeManualModifier.allCases) { modifier in
                                            Text(modifier.title).tag(modifier)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .disabled(!appState.isCommandModeEnabled || appState.commandModeStyle != .manual)
                                }
                            }
                        }
                    }
                    .opacity(appState.isCommandModeEnabled ? 1 : 0.5)

                    if let validationMessage = appState.commandModeManualModifierValidationMessage {
                        Label(validationMessage, systemImage: "xmark.circle.fill")
                            .font(FlowFonts.caption())
                            .foregroundStyle(FlowColors.danger)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
    }

    var launchAtLoginStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.accent)

            Text("Launch at Login")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("Start \(AppName.displayName) automatically when you log in so it's always ready.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowGroupedCard {
                FlowSettingsRow("Launch \(AppName.displayName) at login") {
                    Toggle("", isOn: $appState.launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    var testTranscriptionStep: some View {
        VStack(spacing: 24) {
            // Microphone picker
            VStack(spacing: 8) {
                Text("Test Your Microphone")
                    .font(FlowFonts.pageTitle(22))
                    .foregroundStyle(FlowColors.textPrimary)

                Picker("Microphone:", selection: $appState.selectedMicrophoneID) {
                    Text("System Default").tag("default")
                    ForEach(appState.availableMicrophones) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .frame(maxWidth: 340)

                Text("You can change this later in the menu bar or settings.")
                    .font(FlowFonts.caption())
                    .foregroundStyle(FlowColors.textTertiary)
            }
            .padding(.top, 8)

            Spacer()

            Group {
                switch testPhase {
                case .idle:
                    idleStateView

                case .recording:
                    recordingStateView

                case .transcribing:
                    transcribingStateView

                case .done:
                    doneStateView
                }
            }
            .transition(.opacity)
            .id(testPhase)

            Spacer()
        }
        .onAppear {
            appState.refreshAvailableMicrophones()
            testMicPulsing = true
            startTestHotkeyMonitoring()
        }
        .onDisappear {
            stopTestHotkeyMonitoring()
        }
    }

    private var idleStateView: some View {
        VStack(spacing: 24) {
            // Large mic button with accent
            ZStack {
                Circle()
                    .fill(FlowColors.accent.opacity(0.2))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(FlowColors.accent.opacity(0.35))
                    .frame(width: 90, height: 90)

                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(FlowColors.textPrimary)
                    .scaleEffect(testMicPulsing ? 1.1 : 1.0)
            }
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: testMicPulsing)

            VStack(spacing: 12) {
                Text("Let's Try It Out!")
                    .font(FlowFonts.pageTitle(24))
                    .foregroundStyle(FlowColors.textPrimary)

                // Shortcut prompt with accent badge
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 14))

                    Text(testShortcutPrompt)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(FlowColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FlowColors.accent.opacity(0.15))
                )

                Text("Say anything — a sentence or two is perfect.")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var recordingStateView: some View {
        VStack(spacing: 24) {
            // Animated recording indicator
            ZStack {
                // Outer pulsing ring
                Circle()
                    .fill(FlowColors.accent.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .scaleEffect(testMicPulsing ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: testMicPulsing)

                // Middle ring
                Circle()
                    .fill(FlowColors.accent.opacity(0.25))
                    .frame(width: 110, height: 110)

                // Inner recording circle with waveform
                Circle()
                    .fill(FlowColors.accent)
                    .frame(width: 80, height: 80)
                    .overlay(
                        WaveformView(audioLevel: testAudioLevel)
                            .foregroundColor(.white)
                    )
            }

            VStack(spacing: 8) {
                Text("Listening...")
                    .font(FlowFonts.sectionTitle(18))
                    .foregroundStyle(FlowColors.textPrimary)

                Text("Speak naturally into your microphone")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textSecondary)
            }
        }
    }

    private var transcribingStateView: some View {
        VStack(spacing: 24) {
            // Animated dots
            SimpleTranscribingDots()

            VStack(spacing: 8) {
                Text("Transcribing...")
                    .font(FlowFonts.sectionTitle(18))
                    .foregroundStyle(FlowColors.textPrimary)

                Text("Processing your speech into text")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textSecondary)
            }
        }
    }

    private var doneStateView: some View {
        VStack(spacing: 20) {
            if let error = testError {
                // Error state
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(FlowColors.danger)

                Text("Something went wrong")
                    .font(FlowFonts.sectionTitle(18))
                    .foregroundStyle(FlowColors.textPrimary)

                Text(error)
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text(retryShortcutPrompt)
                    .font(FlowFonts.caption())
                    .foregroundStyle(FlowColors.textTertiary)

            } else if testTranscript.isEmpty {
                // No speech detected
                Image(systemName: "waveform.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(FlowColors.textTertiary)

                Text("No speech detected")
                    .font(FlowFonts.sectionTitle(18))
                    .foregroundStyle(FlowColors.textPrimary)

                Text("Try speaking louder or check your microphone")
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text(retryShortcutPrompt)
                    .font(FlowFonts.caption())
                    .foregroundStyle(FlowColors.textTertiary)

            } else {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(FlowColors.success)

                Text("Perfect — \(AppName.displayName) is ready to go.")
                    .font(FlowFonts.sectionTitle(18))
                    .foregroundStyle(FlowColors.textPrimary)

                // Transcript card
                Text(testTranscript)
                    .font(FlowFonts.body(14))
                    .foregroundStyle(FlowColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FlowColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(FlowColors.border, lineWidth: 1)
                            )
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                Text(retryShortcutPrompt)
                    .font(FlowFonts.caption())
                    .foregroundStyle(FlowColors.textTertiary)
            }
        }
        .padding(.horizontal, 20)
    }

    var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(FlowColors.success)

            Text("You're All Set!")
                .font(FlowFonts.pageTitle(22))
                .foregroundStyle(FlowColors.textPrimary)

            Text("\(AppName.displayName) lives in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(FlowColors.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                if appState.hasEnabledHoldShortcut {
                    HowToRow(icon: "keyboard", text: "Hold \(appState.holdShortcut.displayName) to record")
                }
                if appState.hasEnabledToggleShortcut {
                    HowToRow(icon: "switch.2", text: "Tap \(appState.toggleShortcut.displayName) to start and stop")
                }
                if appState.hasEnabledHoldShortcut && appState.hasEnabledToggleShortcut {
                    HowToRow(icon: "arrow.triangle.branch", text: "While holding, press the toggle shortcut to latch on")
                }
                if appState.isCommandModeEnabled {
                    switch appState.commandModeStyle {
                    case .automatic:
                        HowToRow(icon: "wand.and.stars", text: "With text selected, your normal shortcut transforms the selection")
                    case .manual:
                        HowToRow(
                            icon: "wand.and.stars",
                            text: "Hold \(appState.commandModeManualModifier.title) with your normal shortcut to transform selected text"
                        )
                    }
                }
                HowToRow(icon: "doc.on.clipboard", text: "Text is typed at your cursor & copied")
            }
            .padding(.top, 10)

        }
    }

    var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(totalSteps, id: \.rawValue) { step in
                Circle()
                    .fill(step == currentStep ? FlowColors.accent : FlowColors.border)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var canContinueFromCurrentStep: Bool {
        switch currentStep {
        case .micPermission:
            return micPermissionGranted
        case .accessibility:
            return accessibilityGranted
        case .screenRecording:
            return appState.hasScreenRecordingPermission
        case .testTranscription:
            return testPhase == .done && !testTranscript.isEmpty && testError == nil
        default:
            return true
        }
    }

    private var testShortcutPrompt: String {
        switch (appState.hasEnabledHoldShortcut, appState.hasEnabledToggleShortcut) {
        case (true, true):
            return "Hold \(appState.holdShortcut.displayName) or tap \(appState.toggleShortcut.displayName)"
        case (true, false):
            return "Hold \(appState.holdShortcut.displayName)"
        case (false, true):
            return "Tap \(appState.toggleShortcut.displayName)"
        case (false, false):
            return "Use Start Dictating from the menu bar"
        }
    }

    private var retryShortcutPrompt: String {
        "\(testShortcutPrompt) to try again"
    }

    // MARK: - Helpers

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number + ".")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(FlowColors.textSecondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.subheadline)
                .tint(.blue)
        }
    }

    // MARK: - Actions

    func validateAndContinue() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = apiBaseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBaseURL = baseURL.isEmpty ? AppState.defaultAPIBaseURL : baseURL
        appState.apiBaseURL = resolvedBaseURL
        isValidatingKey = true
        keyValidationError = nil

        Task {
            let valid = await TranscriptionService.validateAPIKey(key, baseURL: resolvedBaseURL)
            await MainActor.run {
                isValidatingKey = false
                if valid {
                    appState.apiKey = key
                    withAnimation {
                        currentStep = nextStep(currentStep)
                    }
                } else {
                    keyValidationError = "Validation failed. Please check your API key and provider settings, then try again."
                }
            }
        }
    }

    func saveCustomVocabularyAndContinue() {
        appState.customVocabulary = customVocabularyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation {
            currentStep = nextStep(currentStep)
        }
    }

    private func nextStep(_ step: SetupStep) -> SetupStep {
        var nextRaw = step.rawValue + 1
        // Skip screen recording step (no longer required)
        while nextRaw <= SetupStep.ready.rawValue {
            if let nextStep = SetupStep(rawValue: nextRaw), nextStep != .screenRecording {
                return nextStep
            }
            nextRaw += 1
        }
        return .ready
    }

    private func previousStep(_ step: SetupStep) -> SetupStep {
        var prevRaw = step.rawValue - 1
        // Skip screen recording step
        while prevRaw >= 0 {
            if let prevStep = SetupStep(rawValue: prevRaw), prevStep != .screenRecording {
                return prevStep
            }
            prevRaw -= 1
        }
        return .welcome
    }

    func checkMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micPermissionGranted = true
        default:
            break
        }
    }

    func requestMicPermission() {
        appState.requestMicrophoneAccess { granted in
            micPermissionGranted = granted
        }
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                checkAccessibility()
            }
        }
    }

    func requestAccessibility() {
        appState.openAccessibilitySettings()
    }

    func startScreenRecordingPolling() {
        screenRecordingTimer?.invalidate()
        screenRecordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                appState.hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
            }
        }
    }

    // MARK: - Test Transcription

    private func startTestHotkeyMonitoring() {
        testHotkeyHarness.onAction = { action in
            switch action {
            case .start:
                guard testPhase == .idle || testPhase == .done else { return }
                if testPhase == .done {
                    resetTest()
                }
                do {
                    let recorder = AudioRecorder()
                    recorder.onRecordingFailure = { [weak recorder] error in
                        guard let recorder else { return }
                        Task { @MainActor in
                            testAudioLevelCancellable?.cancel()
                            testAudioLevelCancellable = nil
                            testAudioLevel = 0.0
                            testHotkeyHarness.isTranscribing = false
                            testAudioRecorder = nil
                            testError = error.localizedDescription
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                testPhase = .done
                            }
                            recorder.cleanup()
                        }
                    }
                    try recorder.startRecording(deviceUID: appState.selectedMicrophoneID)
                    testAudioRecorder = recorder
                    testError = nil
                    testAudioLevelCancellable = recorder.$audioLevel
                        .receive(on: DispatchQueue.main)
                        .sink { level in
                            testAudioLevel = level
                        }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .recording
                    }
                } catch {
                    testHotkeyHarness.resetSession()
                    testError = error.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .done
                    }
                }

            case .stop:
                guard testPhase == .recording, let recorder = testAudioRecorder else { return }
                testAudioLevelCancellable?.cancel()
                testAudioLevelCancellable = nil
                testAudioLevel = 0.0
                testHotkeyHarness.isTranscribing = true

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    testPhase = .transcribing
                }
                recorder.stopRecording { url in
                    guard let url else {
                        Task { @MainActor in
                            testHotkeyHarness.isTranscribing = false
                            testAudioRecorder = nil
                            if testError == nil {
                                testError = "No audio file was created."
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                testPhase = .done
                            }
                            recorder.cleanup()
                        }
                        return
                    }

                    Task {
                        do {
                            let service = try appState.makeTranscriptionService()
                            let transcript = try await service.transcribe(fileURL: url)
                            await MainActor.run {
                                testHotkeyHarness.isTranscribing = false
                                testAudioRecorder = nil
                                testTranscript = transcript
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    testPhase = .done
                                }
                            }
                        } catch {
                            await MainActor.run {
                                testHotkeyHarness.isTranscribing = false
                                testAudioRecorder = nil
                                testError = error.localizedDescription
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    testPhase = .done
                                }
                            }
                        }
                        await MainActor.run {
                            recorder.cleanup()
                        }
                    }
                }

            case .switchedToToggle:
                break
            }
        }

        do {
            try testHotkeyHarness.start(configuration: ShortcutConfiguration(
                hold: appState.holdShortcut,
                toggle: appState.toggleShortcut
            ), startDelay: appState.shortcutStartDelay)
        } catch {
            testError = error.localizedDescription
            testPhase = .done
        }
    }

    private func stopTestHotkeyMonitoring() {
        testHotkeyHarness.stop()
        testAudioLevelCancellable?.cancel()
        testAudioLevelCancellable = nil
        if let recorder = testAudioRecorder, recorder.isRecording {
            recorder.cancelRecording()
        }
        testAudioRecorder = nil
    }

    private func resetTest() {
        testPhase = .idle
        testTranscript = ""
        testError = nil
        testAudioLevel = 0.0
        testMicPulsing = true
        testHotkeyHarness.isTranscribing = false
        testHotkeyHarness.resetSession()
        if let recorder = testAudioRecorder {
            if recorder.isRecording {
                recorder.cancelRecording()
            }
            testAudioRecorder = nil
        }
    }

}

struct GitHubRepoInfo: Decodable {
    let stargazersCount: Int

    private enum CodingKeys: String, CodingKey {
        case stargazersCount = "stargazers_count"
    }
}

struct GitHubStarRecord: Decodable, Identifiable {
    let user: GitHubStarUser

    var id: Int {
        user.id
    }
}

struct GitHubStarUser: Decodable {
    let id: Int
    let login: String
    let avatarUrl: URL
    let htmlUrl: URL

    /// Avatar URL resized to 44px (2x for 22pt display) for efficient loading
    var avatarThumbnailUrl: URL {
        // GitHub avatar URLs already have query params, so append with &
        let separator = avatarUrl.absoluteString.contains("?") ? "&" : "?"
        return URL(string: avatarUrl.absoluteString + "\(separator)s=44") ?? avatarUrl
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

@MainActor
class GitHubMetadataCache: ObservableObject {
    static let shared = GitHubMetadataCache()

    @Published var starCount: Int?
    @Published var recentStargazers: [GitHubStarRecord] = []
    @Published var isLoading = true

    private var lastFetchDate: Date?
    private let cacheDuration: TimeInterval = 5 * 60 // 5 minutes
    private let repoAPIURL = URL(string: "https://api.github.com/repos/mananrathod/flow")!

    private init() {}

    func fetchIfNeeded() async {
        if let lastFetch = lastFetchDate, Date().timeIntervalSince(lastFetch) < cacheDuration {
            return
        }

        isLoading = true

        do {
            let repoResult = try await URLSession.shared.data(from: repoAPIURL)
            guard let repoHTTP = repoResult.1 as? HTTPURLResponse,
                  (200..<300).contains(repoHTTP.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let count = try JSONDecoder().decode(GitHubRepoInfo.self, from: repoResult.0).stargazersCount

            var recent: [GitHubStarRecord] = []
            if count > 0 {
                let perPage = 100
                let lastPage = max(1, Int(ceil(Double(count) / Double(perPage))))
                let stargazersURL = URL(string: "https://api.github.com/repos/mananrathod/flow/stargazers?per_page=\(perPage)&page=\(lastPage)")!
                var request = URLRequest(url: stargazersURL)
                request.setValue("application/vnd.github.v3.star+json", forHTTPHeaderField: "Accept")
                let starredResult = try await URLSession.shared.data(for: request)
                if let starredHTTP = starredResult.1 as? HTTPURLResponse,
                   (200..<300).contains(starredHTTP.statusCode) {
                    let all = try JSONDecoder().decode([GitHubStarRecord].self, from: starredResult.0)
                    recent = Array(all.suffix(15).reversed())
                }
            }

            starCount = count
            recentStargazers = recent
            isLoading = false
            lastFetchDate = Date()
        } catch {
            isLoading = false
        }
    }
}

private struct InlineTranscribingDots: View {
    @State private var activeDot = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(activeDot == index ? 1.0 : 0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(activeDot == index ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}

struct HowToRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(FlowColors.accent)
            Text(text)
                .foregroundStyle(FlowColors.textSecondary)
        }
    }
}
