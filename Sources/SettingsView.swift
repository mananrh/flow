import SwiftUI
import AVFoundation
import ServiceManagement

// MARK: - Shared Helpers

private let iso8601DayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

struct ProviderSettingsFields: View {
    @EnvironmentObject var appState: AppState
    @Binding var apiBaseURLInput: String
    @Binding var transcriptionAPIURLInput: String
    @Binding var transcriptionAPIKeyInput: String
    @FocusState private var isEditingAPIBaseURL: Bool
    @FocusState private var isEditingTranscriptionModel: Bool
    @FocusState private var isEditingRealtimeStreamingModel: Bool
    @FocusState private var isEditingPostProcessingModel: Bool
    @FocusState private var isEditingPostProcessingFallbackModel: Bool
    @FocusState private var isEditingContextModel: Bool
    @FocusState private var transcriptionAPIURLFocused: Bool
    @FocusState private var transcriptionAPIKeyFocused: Bool
    @State private var transcriptionModelDraft: String = ""
    @State private var realtimeStreamingModelDraft: String = ""
    @State private var postProcessingModelDraft: String = ""
    @State private var postProcessingFallbackModelDraft: String = ""
    @State private var contextModelDraft: String = ""

    let showsModelDescription: Bool

    private func commitAPIBaseURL() {
        let trimmed = apiBaseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBaseURL = trimmed.isEmpty ? AppState.defaultAPIBaseURL : trimmed
        apiBaseURLInput = resolvedBaseURL
        appState.apiBaseURL = resolvedBaseURL
    }

    private func commitTranscriptionModel() {
        let trimmed = transcriptionModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriptionModelDraft = trimmed
        guard appState.transcriptionModel != trimmed else { return }
        appState.transcriptionModel = trimmed
    }

    private func commitRealtimeStreamingModel() {
        let trimmed = realtimeStreamingModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        realtimeStreamingModelDraft = trimmed
        guard appState.realtimeStreamingModel != trimmed else { return }
        appState.realtimeStreamingModel = trimmed
    }

    private func commitPostProcessingModel() {
        let trimmed = postProcessingModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        postProcessingModelDraft = trimmed
        guard appState.postProcessingModel != trimmed else { return }
        appState.postProcessingModel = trimmed
    }

    private func commitPostProcessingFallbackModel() {
        let trimmed = postProcessingFallbackModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        postProcessingFallbackModelDraft = trimmed
        guard appState.postProcessingFallbackModel != trimmed else { return }
        appState.postProcessingFallbackModel = trimmed
    }

    private func commitContextModel() {
        let trimmed = contextModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        contextModelDraft = trimmed
        guard appState.contextModel != trimmed else { return }
        appState.contextModel = trimmed
    }

    private func commitTranscriptionAPIURL() {
        let trimmed = transcriptionAPIURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriptionAPIURLInput = trimmed
        guard appState.transcriptionAPIURL != trimmed else { return }
        appState.transcriptionAPIURL = trimmed
    }

    private func commitTranscriptionAPIKey() {
        let trimmed = transcriptionAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriptionAPIKeyInput = trimmed
        guard appState.transcriptionAPIKey != trimmed else { return }
        appState.transcriptionAPIKey = trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Base URL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlowColors.textPrimary)

            Text("Change this to use a different OpenAI-compatible API provider.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(AppState.defaultAPIBaseURL, text: $apiBaseURLInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($isEditingAPIBaseURL)
                    .onSubmit {
                        commitAPIBaseURL()
                    }
                    .onChange(of: isEditingAPIBaseURL) { isEditing in
                        if !isEditing {
                            commitAPIBaseURL()
                        }
                    }

                Button("Reset to Default") {
                    apiBaseURLInput = AppState.defaultAPIBaseURL
                    appState.apiBaseURL = AppState.defaultAPIBaseURL
                }
                .font(.caption)
            }

            if showsModelDescription {
                Text("If you use another provider, enter that provider's model IDs here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Post-Processing Model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    TextField(AppState.defaultPostProcessingModel, text: $postProcessingModelDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isEditingPostProcessingModel)
                        .onSubmit {
                            commitPostProcessingModel()
                        }
                        .onChange(of: isEditingPostProcessingModel) { isEditing in
                            if !isEditing {
                                commitPostProcessingModel()
                            }
                        }
                    Button("Reset to Default") {
                        postProcessingModelDraft = AppState.defaultPostProcessingModel
                        appState.postProcessingModel = AppState.defaultPostProcessingModel
                    }
                    .font(.caption)
                }
                Text("Used for transcript cleanup and Edit Mode transforms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Post-Processing Fallback Model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    TextField(AppState.defaultPostProcessingFallbackModel, text: $postProcessingFallbackModelDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isEditingPostProcessingFallbackModel)
                        .onSubmit {
                            commitPostProcessingFallbackModel()
                        }
                        .onChange(of: isEditingPostProcessingFallbackModel) { isEditing in
                            if !isEditing {
                                commitPostProcessingFallbackModel()
                            }
                        }
                    Button("Reset to Default") {
                        postProcessingFallbackModelDraft = AppState.defaultPostProcessingFallbackModel
                        appState.postProcessingFallbackModel = AppState.defaultPostProcessingFallbackModel
                    }
                    .font(.caption)
                }
                Text("Used as the explicit retry model for transcript cleanup and Edit Mode transforms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Context Model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    TextField(AppState.defaultContextModel, text: $contextModelDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isEditingContextModel)
                        .onSubmit {
                            commitContextModel()
                        }
                        .onChange(of: isEditingContextModel) { isEditing in
                            if !isEditing {
                                commitContextModel()
                            }
                        }
                    Button("Reset to Default") {
                        contextModelDraft = AppState.defaultContextModel
                        appState.contextModel = AppState.defaultContextModel
                    }
                    .font(.caption)
                }
                Text("Used for context inference, with a text-only retry when screenshot analysis fails.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Transcription Model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    TextField(AppState.defaultTranscriptionModel, text: $transcriptionModelDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isEditingTranscriptionModel)
                        .onSubmit {
                            commitTranscriptionModel()
                        }
                        .onChange(of: isEditingTranscriptionModel) { isEditing in
                            if !isEditing {
                                commitTranscriptionModel()
                            }
                        }
                    Button("Reset to Default") {
                        transcriptionModelDraft = AppState.defaultTranscriptionModel
                        appState.transcriptionModel = AppState.defaultTranscriptionModel
                    }
                    .font(.caption)
                }
                Text("Used for speech-to-text transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Transcription Language")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                Picker("", selection: $appState.transcriptionLanguage) {
                    ForEach(AppState.transcriptionLanguageOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .accessibilityLabel("Transcription Language")
                .labelsHidden()
                Text("Hint to the transcription model. Auto-detect works for most users. Pick a specific language if you see wrong-script characters (for example Chinese) appear in your output.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Transcription API URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    TextField("Uses API Base URL when empty", text: $transcriptionAPIURLInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($transcriptionAPIURLFocused)
                        .onSubmit {
                            commitTranscriptionAPIURL()
                        }
                        .onChange(of: transcriptionAPIURLFocused) { isFocused in
                            if !isFocused {
                                commitTranscriptionAPIURL()
                            }
                        }
                    if !transcriptionAPIURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear") {
                            transcriptionAPIURLInput = ""
                            appState.transcriptionAPIURL = ""
                        }
                        .font(.caption)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Transcription API Key")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    SecureField("Uses API Key when empty", text: $transcriptionAPIKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($transcriptionAPIKeyFocused)
                        .onSubmit {
                            commitTranscriptionAPIKey()
                        }
                        .onChange(of: transcriptionAPIKeyFocused) { isFocused in
                            if !isFocused {
                                commitTranscriptionAPIKey()
                            }
                        }
                    if !transcriptionAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear") {
                            transcriptionAPIKeyInput = ""
                            appState.transcriptionAPIKey = ""
                        }
                        .font(.caption)
                    }
                }
            }

            Divider()

            Toggle(
                "Stream audio while recording (realtime)",
                isOn: $appState.realtimeStreamingEnabled
            )
            Text("Streams audio through the provider's OpenAI-compatible /v1/realtime WebSocket so transcription runs while you speak.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Realtime Transcription Model")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowColors.textPrimary)
                HStack(spacing: 8) {
                    TextField("Required by some providers, e.g. gpt-4o-transcribe", text: $realtimeStreamingModelDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isEditingRealtimeStreamingModel)
                        .onSubmit {
                            commitRealtimeStreamingModel()
                        }
                        .onChange(of: isEditingRealtimeStreamingModel) { isEditing in
                            if !isEditing {
                                commitRealtimeStreamingModel()
                            }
                        }
                    if !realtimeStreamingModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Reset") {
                            realtimeStreamingModelDraft = ""
                            appState.realtimeStreamingModel = ""
                        }
                        .font(.caption)
                    }
                }
                Text("Used only for realtime streaming. Leave empty for providers that supply a server default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            transcriptionModelDraft = appState.transcriptionModel
            realtimeStreamingModelDraft = appState.realtimeStreamingModel
            postProcessingModelDraft = appState.postProcessingModel
            postProcessingFallbackModelDraft = appState.postProcessingFallbackModel
            contextModelDraft = appState.contextModel
        }
        .onChange(of: appState.transcriptionModel) { value in
            if !isEditingTranscriptionModel {
                transcriptionModelDraft = value
            }
        }
        .onChange(of: appState.realtimeStreamingModel) { value in
            if !isEditingRealtimeStreamingModel {
                realtimeStreamingModelDraft = value
            }
        }
        .onChange(of: appState.postProcessingModel) { value in
            if !isEditingPostProcessingModel {
                postProcessingModelDraft = value
            }
        }
        .onChange(of: appState.postProcessingFallbackModel) { value in
            if !isEditingPostProcessingFallbackModel {
                postProcessingFallbackModelDraft = value
            }
        }
        .onChange(of: appState.contextModel) { value in
            if !isEditingContextModel {
                contextModelDraft = value
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                FlowSidebarSectionHeader(title: "SETTINGS")

                ForEach(SettingsTab.allCases) { tab in
                    FlowSidebarRow(
                        icon: tab.icon,
                        title: tab.title,
                        isSelected: appState.selectedSettingsTab == tab,
                        action: { appState.selectedSettingsTab = tab }
                    )
                }

                Spacer()

                // Version footer
                Text("Flow v\(appVersion)")
                    .font(FlowFonts.mono(10))
                    .foregroundStyle(FlowColors.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 6)
            .frame(width: 190)
            .background(FlowColors.cream)

            // Content
            ZStack {
                FlowColors.surface
                    .ignoresSafeArea()

                Group {
                    switch appState.selectedSettingsTab {
                    case .general, .none:
                        GeneralSettingsTab()
                    case .system:
                        SystemSettingsTab()
                    case .permissions:
                        PermissionsSettingsTab()
                    case .apiModels:
                        APIModelsSettingsTab()
                    case .prompts:
                        PromptsSettingsView()
                    case .macros:
                        VoiceMacrosSettingsView()
                    case .runLog:
                        RunLogView().environment(\.colorScheme, .dark)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.colorScheme, .light)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showShortcutConfig = false
    @State private var showMicPicker = false
    @State private var showLanguagePicker = false

    private var holdShortcutLabel: String {
        let binding = appState.holdShortcut
        if binding.isDisabled { return "Not set" }
        return "Hold \(binding.displayName) and speak"
    }

    private var microphoneName: String {
        if appState.selectedMicrophoneID == "default" || appState.selectedMicrophoneID.isEmpty {
            return "Built-in mic (recommended)"
        }
        return appState.availableMicrophones.first(where: { $0.uid == appState.selectedMicrophoneID })?.name ?? "Unknown"
    }

    private var languageName: String {
        let lang = appState.transcriptionLanguage
        if lang.isEmpty { return "Auto-detect" }
        return AppState.transcriptionLanguageOptions.first(where: { $0.code == lang })?.name ?? lang
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("General")
                    .font(FlowFonts.pageTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    // Shortcuts row
                    FlowSettingsRow("Shortcuts", description: holdShortcutLabel) {
                        FlowPillButton(title: "Change") {
                            showShortcutConfig = true
                        }
                    }

                    FlowCardDivider()

                    // Microphone row
                    FlowSettingsRow("Microphone", description: microphoneName) {
                        FlowPillButton(title: "Change") {
                            showMicPicker = true
                        }
                    }

                    FlowCardDivider()

                    // Languages row
                    FlowSettingsRow("Languages", description: languageName) {
                        FlowPillButton(title: "Change") {
                            showLanguagePicker = true
                        }
                    }
                }
            }
            .padding(28)
        }
        .onAppear {
            appState.refreshAvailableMicrophones()
        }
        .sheet(isPresented: $showShortcutConfig) {
            ShortcutConfigSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showMicPicker) {
            MicPickerSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
                .environmentObject(appState)
        }
    }
}

// MARK: - System Settings Tab

struct SystemSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("show_menu_bar_icon") private var showMenuBarIcon = true
    @State private var showMutedHint = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("System")
                    .font(FlowFonts.pageTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                // App settings
                Text("App settings")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    FlowSettingsRow("Launch app at login") {
                        Toggle("", isOn: $appState.launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    FlowCardDivider()
                    FlowSettingsRow("Show Flow bar at all times") {
                        Toggle("", isOn: $showMenuBarIcon)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                // Sound
                Text("Sound")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    FlowSettingsRow("Dictation and notification sounds") {
                        Toggle("", isOn: $appState.alertSoundsEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    FlowCardDivider()
                    FlowSettingsRow("Mute music while dictating") {
                        Toggle("", isOn: $appState.dictationAudioInterruptionEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                // Edit Mode
                Text("Edit Mode")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    FlowSettingsRow("Enable Edit Mode", description: "Transform selected text with a spoken instruction.") {
                        Toggle("", isOn: Binding(
                            get: { appState.isCommandModeEnabled },
                            set: { _ = appState.setCommandModeEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    if appState.isCommandModeEnabled {
                        FlowCardDivider()
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Invocation Style", selection: Binding(
                                get: { appState.commandModeStyle },
                                set: { _ = appState.setCommandModeStyle($0) }
                            )) {
                                ForEach(CommandModeStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)

                            if appState.commandModeStyle == .manual {
                                Picker("Extra Modifier", selection: Binding(
                                    get: { appState.commandModeManualModifier },
                                    set: { _ = appState.setCommandModeManualModifier($0) }
                                )) {
                                    ForEach(CommandModeManualModifier.allCases) { modifier in
                                        Text(modifier.title).tag(modifier)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }

                // Clipboard
                Text("Clipboard")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    FlowSettingsRow("Preserve clipboard after paste", description: "Restores clipboard contents after pasting transcript.") {
                        Toggle("", isOn: $appState.preserveClipboard)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    FlowCardDivider()
                    FlowSettingsRow("Say \"press enter\" to submit", description: "Removes the words and presses Return after pasting.") {
                        Toggle("", isOn: $appState.isPressEnterVoiceCommandEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
            .padding(28)
        }
    }
}

// MARK: - Permissions Settings Tab

struct PermissionsSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var micPermissionGranted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Permissions")
                    .font(FlowFonts.pageTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                Text("Required permissions")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    permissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Required for recording your speech.",
                        granted: micPermissionGranted,
                        action: {
                            appState.requestMicrophoneAccess { granted in
                                micPermissionGranted = granted
                            }
                        }
                    )

                    FlowCardDivider()

                    permissionRow(
                        icon: "hand.raised.fill",
                        title: "Accessibility",
                        description: "Required to paste text and detect cursor position.",
                        granted: appState.hasAccessibility,
                        action: { appState.openAccessibilitySettings() }
                    )

                    FlowCardDivider()

                    // Screen Recording permission removed - context is now optional
                }
            }
            .padding(28)
        }
        .onAppear {
            micPermissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(granted ? FlowColors.success : FlowColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textPrimary)
                Text(description)
                    .font(FlowFonts.caption())
                    .foregroundStyle(FlowColors.textSecondary)
            }

            Spacer()

            if granted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FlowColors.success)
                        .font(.system(size: 14))
                    Text("Granted")
                        .font(FlowFonts.caption())
                        .foregroundStyle(FlowColors.success)
                }
            } else {
                FlowPillButton(title: "Grant Access", action: action)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

// MARK: - API & Models Settings Tab

struct APIModelsSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyInput: String = ""
    @State private var apiBaseURLInput: String = ""
    @State private var transcriptionAPIURLInput: String = ""
    @State private var transcriptionAPIKeyInput: String = ""
    @State private var isValidatingKey = false
    @State private var keyValidationError: String?
    @State private var keyValidationSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("API & Models")
                    .font(FlowFonts.pageTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                // API Key
                Text("API Configuration")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Key")
                            .font(FlowFonts.body(13))
                            .foregroundStyle(FlowColors.textPrimary)

                        HStack(spacing: 8) {
                            SecureField("Enter your API key", text: $apiKeyInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .disabled(isValidatingKey)
                                .onChange(of: apiKeyInput) { _ in
                                    keyValidationError = nil
                                    keyValidationSuccess = false
                                }

                            FlowPillButton(title: isValidatingKey ? "Validating..." : "Save") {
                                validateAndSaveKey()
                            }
                        }

                        if let error = keyValidationError {
                            Label(error, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(FlowFonts.caption())
                        } else if keyValidationSuccess {
                            Label("API key saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(FlowColors.success)
                                .font(FlowFonts.caption())
                        }
                    }
                    .padding(18)
                }

                // Provider settings (advanced)
                Text("Provider & Models")
                    .font(FlowFonts.sectionTitle())
                    .foregroundStyle(FlowColors.textPrimary)

                FlowGroupedCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ProviderSettingsFields(
                            apiBaseURLInput: $apiBaseURLInput,
                            transcriptionAPIURLInput: $transcriptionAPIURLInput,
                            transcriptionAPIKeyInput: $transcriptionAPIKeyInput,
                            showsModelDescription: true
                        )
                    }
                    .padding(18)
                }
            }
            .padding(28)
        }
        .onAppear {
            apiKeyInput = appState.apiKey
            apiBaseURLInput = appState.apiBaseURL
            transcriptionAPIURLInput = appState.transcriptionAPIURL
            transcriptionAPIKeyInput = appState.transcriptionAPIKey
        }
    }

    private func validateAndSaveKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = apiBaseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidatingKey = true
        keyValidationError = nil
        keyValidationSuccess = false

        Task {
            let valid = await TranscriptionService.validateAPIKey(
                key,
                baseURL: baseURL.isEmpty ? AppState.defaultAPIBaseURL : baseURL
            )
            await MainActor.run {
                isValidatingKey = false
                if valid {
                    appState.apiKey = key
                    keyValidationSuccess = true
                } else {
                    keyValidationError = "Validation failed. Check your API key and provider settings."
                }
            }
        }
    }
}

// MARK: - Sheet: Shortcut Config

struct ShortcutConfigSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var holdValidation: String?
    @State private var toggleValidation: String?
    @State private var isCapturingHold = false
    @State private var isCapturingToggle = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dictation Shortcuts")
                    .font(.title2.weight(.semibold))
                Text("Configure your hold-to-talk and tap-to-toggle shortcuts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DictationShortcutEditor { isCapturing in
                        if isCapturing {
                            appState.suspendHotkeyMonitoringForShortcutCapture()
                        } else {
                            appState.resumeHotkeyMonitoringAfterShortcutCapture()
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Shortcut Start Delay")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(appState.shortcutStartDelayMilliseconds) ms")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $appState.shortcutStartDelay, in: 0...0.5, step: 0.025)
                        Text("Delay before recording starts. Stopping is always immediate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 520, height: 460)
    }
}

// MARK: - Sheet: Mic Picker

struct MicPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Select Microphone")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    MicrophoneOptionRow(
                        name: "System Default",
                        isSelected: appState.selectedMicrophoneID == "default" || appState.selectedMicrophoneID.isEmpty,
                        action: { appState.selectedMicrophoneID = "default" }
                    )
                    ForEach(appState.availableMicrophones) { device in
                        MicrophoneOptionRow(
                            name: device.name,
                            isSelected: appState.selectedMicrophoneID == device.uid,
                            action: { appState.selectedMicrophoneID = device.uid }
                        )
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 340)
        .onAppear { appState.refreshAvailableMicrophones() }
    }
}

// MARK: - Sheet: Language Picker

struct LanguagePickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private static let outputLanguageOptions = [
        "",
        "English",
        "Chinese (Simplified)",
        "Chinese (Traditional)",
        "Spanish",
        "French",
        "Japanese",
        "Korean",
        "German",
        "Portuguese",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Languages")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription Language")
                            .font(.headline)
                        Picker("", selection: $appState.transcriptionLanguage) {
                            ForEach(AppState.transcriptionLanguageOptions, id: \.code) { option in
                                Text(option.name).tag(option.code)
                            }
                        }
                        .labelsHidden()
                        Text("Hint to the transcription model. Auto-detect works for most users.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Language")
                            .font(.headline)
                        Picker("", selection: $appState.outputLanguage) {
                            Text("Same as spoken").tag("")
                            ForEach(Self.outputLanguageOptions.dropFirst(), id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                        .labelsHidden()
                        Text("When set, Flow translates your speech into the selected language.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 420, height: 380)
    }
}

// MARK: - Microphone Option Row

struct MicrophoneOptionRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? FlowColors.accent : FlowColors.textTertiary)
                Text(name)
                    .foregroundStyle(FlowColors.textPrimary)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? FlowColors.accent.opacity(0.08) : FlowColors.cardBg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? FlowColors.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Prompts Settings

struct PromptsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var customSystemPromptInput: String = ""
    @State private var customContextPromptInput: String = ""
    @State private var showDefaultSystemPrompt = false
    @State private var showDefaultContextPrompt = false

    // System prompt test state
    @State private var systemTestInput: String = "Um, so I was like, thinking we should uh, refactor the authentication module, you know?"
    @State private var systemTestRunning = false
    @State private var systemTestOutput: String? = nil
    @State private var systemTestError: String? = nil
    @State private var systemTestPrompt: String? = nil

    // Context prompt test state
    @State private var contextTestRunning = false
    @State private var contextTestOutput: String? = nil
    @State private var contextTestError: String? = nil
    @State private var contextTestPrompt: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsCard("System Prompt", icon: "text.bubble.fill") {
                    systemPromptSection
                }
                SettingsCard("Context Prompt", icon: "eye.fill") {
                    contextPromptSection
                }
            }
            .padding(24)
        }
        .onAppear {
            customSystemPromptInput = appState.customSystemPrompt.isEmpty
                ? PostProcessingService.defaultSystemPrompt
                : appState.customSystemPrompt
            customContextPromptInput = appState.customContextPrompt.isEmpty
                ? AppContextService.defaultContextPrompt
                : appState.customContextPrompt
        }
    }

    // MARK: System Prompt

    private var systemPromptSection: some View {
        let isCustom = !appState.customSystemPrompt.isEmpty
        let hasNewerDefault = isCustom
            && !appState.customSystemPromptLastModified.isEmpty
            && appState.customSystemPromptLastModified < PostProcessingService.defaultSystemPromptDate

        return VStack(alignment: .leading, spacing: 10) {
            Text("Controls how raw transcriptions are cleaned up.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if hasNewerDefault {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                    Text("A newer default prompt is available.")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button("View Default") {
                        showDefaultSystemPrompt.toggle()
                    }
                    .font(.caption)
                    Button("Switch to Default") {
                        customSystemPromptInput = PostProcessingService.defaultSystemPrompt
                        appState.customSystemPrompt = ""
                        appState.customSystemPromptLastModified = ""
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }

            if showDefaultSystemPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Default System Prompt")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button("Hide") {
                            showDefaultSystemPrompt = false
                        }
                        .font(.caption)
                    }
                    Text(PostProcessingService.defaultSystemPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(FlowColors.cardBg)
                .cornerRadius(6)
            }

            TextEditor(text: $customSystemPromptInput)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(FlowColors.surface)
                .frame(minHeight: 120, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(FlowColors.border, lineWidth: 1)
                )
                .onChange(of: customSystemPromptInput) { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let defaultTrimmed = PostProcessingService.defaultSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == defaultTrimmed || trimmed.isEmpty {
                        if !appState.customSystemPrompt.isEmpty {
                            appState.customSystemPrompt = ""
                            appState.customSystemPromptLastModified = ""
                        }
                    } else {
                        appState.customSystemPrompt = trimmed
                        let today = iso8601DayFormatter.string(from: Date())
                        if appState.customSystemPromptLastModified != today {
                            appState.customSystemPromptLastModified = today
                        }
                    }
                }

            HStack {
                if isCustom {
                    Label("Using custom prompt", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Label("Using default", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCustom {
                    Button("Reset to Default") {
                        customSystemPromptInput = PostProcessingService.defaultSystemPrompt
                        appState.customSystemPrompt = ""
                        appState.customSystemPromptLastModified = ""
                    }
                    .font(.caption)
                }
            }

            Divider()

            // Test section
            VStack(alignment: .leading, spacing: 8) {
                Text("Test System Prompt")
                    .font(.caption.weight(.semibold))
                Text("Enter sample text to see how the current prompt cleans it up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $systemTestInput)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60, maxHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Button {
                    runSystemPromptTest()
                } label: {
                    HStack(spacing: 6) {
                        if systemTestRunning {
                            ProgressView()
                                .controlSize(.small)
                            Text("Running...")
                        } else {
                            Image(systemName: "play.fill")
                            Text("Test System Prompt")
                        }
                    }
                }
                .disabled(systemTestRunning || appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || systemTestInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("API key required to test", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let error = systemTestError {
                    Label(error, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let output = systemTestOutput {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Result:")
                            .font(.caption.weight(.semibold))
                        Text(output.isEmpty ? "(empty — no output)" : output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(6)
                    }
                }

                if let prompt = systemTestPrompt {
                    DisclosureGroup("Full prompt sent") {
                        Text(prompt)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func runSystemPromptTest() {
        systemTestRunning = true
        systemTestOutput = nil
        systemTestError = nil
        systemTestPrompt = nil

        let service = PostProcessingService(
            apiKey: appState.apiKey,
            baseURL: appState.apiBaseURL,
            preferredModel: appState.postProcessingModel,
            preferredFallbackModel: appState.postProcessingFallbackModel
        )
        let input = systemTestInput
        let customPrompt = appState.customSystemPrompt
        let vocabulary = appState.customVocabulary

        let context = AppContext(
            appName: "\(AppName.displayName) Settings",
            bundleIdentifier: "com.mananrathod.flow",
            windowTitle: "System Prompt Test",
            selectedText: nil,
            currentActivity: "User is testing the system prompt in \(AppName.displayName) settings.",
            contextSystemPrompt: nil,
            contextPrompt: nil,
            screenshotDataURL: nil,
            screenshotMimeType: nil,
            screenshotError: nil
        )

        Task {
            do {
                let result = try await service.postProcess(
                    transcript: input,
                    context: context,
                    customVocabulary: vocabulary,
                    customSystemPrompt: customPrompt
                )
                await MainActor.run {
                    systemTestOutput = result.transcript
                    systemTestPrompt = result.prompt
                    systemTestRunning = false
                }
            } catch {
                await MainActor.run {
                    systemTestError = error.localizedDescription
                    systemTestRunning = false
                }
            }
        }
    }

    // MARK: Context Prompt

    private var contextPromptSection: some View {
        let isCustom = !appState.customContextPrompt.isEmpty
        let hasNewerDefault = isCustom
            && !appState.customContextPromptLastModified.isEmpty
            && appState.customContextPromptLastModified < AppContextService.defaultContextPromptDate

        return VStack(alignment: .leading, spacing: 10) {
            // Beta toggle with permission check
            HStack {
                Toggle("Enable Context", isOn: Binding(
                    get: { appState.contextPromptEnabled },
                    set: { newValue in
                        if newValue {
                            // Only ask for permission once - on first toggle attempt
                            if !appState.contextPromptPermissionAsked {
                                appState.contextPromptPermissionAsked = true
                                appState.requestScreenCapturePermission()
                            }
                            // Enable if permission already granted
                            if appState.hasScreenRecordingPermission {
                                appState.contextPromptEnabled = true
                            }
                        } else {
                            appState.contextPromptEnabled = false
                        }
                    }
                ))
                .toggleStyle(.switch)
                Text("Beta")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FlowColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
            }

            Text("Controls how \(AppName.displayName) infers your current activity from app metadata and screenshots.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !appState.contextPromptEnabled {
                Text("Context is currently disabled. Enable it to use app-aware transcription.")
                    .font(.caption)
                    .foregroundStyle(FlowColors.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FlowColors.cardBg)
                    .cornerRadius(6)
            }

            if hasNewerDefault {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                    Text("A newer default prompt is available.")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button("View Default") {
                        showDefaultContextPrompt.toggle()
                    }
                    .font(.caption)
                    Button("Switch to Default") {
                        customContextPromptInput = AppContextService.defaultContextPrompt
                        appState.customContextPrompt = ""
                        appState.customContextPromptLastModified = ""
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }

            if showDefaultContextPrompt {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Default Context Prompt")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button("Hide") {
                            showDefaultContextPrompt = false
                        }
                        .font(.caption)
                    }
                    Text(AppContextService.defaultContextPrompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(FlowColors.cardBg)
                .cornerRadius(6)
            }

            TextEditor(text: $customContextPromptInput)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(FlowColors.surface)
                .frame(minHeight: 120, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(FlowColors.border, lineWidth: 1)
                )
                .onChange(of: customContextPromptInput) { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    let defaultTrimmed = AppContextService.defaultContextPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == defaultTrimmed || trimmed.isEmpty {
                        if !appState.customContextPrompt.isEmpty {
                            appState.customContextPrompt = ""
                            appState.customContextPromptLastModified = ""
                        }
                    } else {
                        appState.customContextPrompt = trimmed
                        let today = iso8601DayFormatter.string(from: Date())
                        if appState.customContextPromptLastModified != today {
                            appState.customContextPromptLastModified = today
                        }
                    }
                }

            HStack {
                if isCustom {
                    Label("Using custom prompt", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Label("Using default", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCustom {
                    Button("Reset to Default") {
                        customContextPromptInput = AppContextService.defaultContextPrompt
                        appState.customContextPrompt = ""
                        appState.customContextPromptLastModified = ""
                    }
                    .font(.caption)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Screenshot Resolution")
                    .font(.caption.weight(.semibold))

                Text("Controls the maximum image dimension sent for context inference.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $appState.contextScreenshotMaxDimension) {
                    ForEach(AppState.contextScreenshotDimensionOptions, id: \.self) { dimension in
                        Text("\(dimension) px").tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Screenshot Resolution")

                HStack {
                    if appState.contextScreenshotMaxDimension == AppState.defaultContextScreenshotMaxDimension {
                        Label("Using default", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Using custom value", systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if appState.contextScreenshotMaxDimension != AppState.defaultContextScreenshotMaxDimension {
                        Button("Reset to Default") {
                            appState.contextScreenshotMaxDimension = AppState.defaultContextScreenshotMaxDimension
                        }
                        .font(.caption)
                    }
                }
            }

            Divider()

            // Test section
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Context Prompt")
                    .font(.caption.weight(.semibold))
                Text("Captures a screenshot and metadata from the frontmost app, then runs the context prompt to infer activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    runContextPromptTest()
                } label: {
                    HStack(spacing: 6) {
                        if contextTestRunning {
                            ProgressView()
                                .controlSize(.small)
                            Text("Running...")
                        } else {
                            Image(systemName: "play.fill")
                            Text("Test Context Prompt")
                        }
                    }
                }
                .disabled(contextTestRunning || appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if appState.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("API key required to test", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let error = contextTestError {
                    Label(error, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let output = contextTestOutput {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Result:")
                            .font(.caption.weight(.semibold))
                        Text(output.isEmpty ? "(empty — no output)" : output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .cornerRadius(6)
                    }
                }

                if let prompt = contextTestPrompt {
                    DisclosureGroup("Full prompt sent") {
                        Text(prompt)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func runContextPromptTest() {
        contextTestRunning = true
        contextTestOutput = nil
        contextTestError = nil
        contextTestPrompt = nil

        let service = appState.makeAppContextService()

        Task {
            let context = await service.collectContext()
            await MainActor.run {
                if let prompt = context.contextPrompt {
                    contextTestOutput = context.contextSummary
                    contextTestPrompt = prompt
                } else {
                    contextTestError = "Context inference returned no result. This may be a permissions issue or the API could not be reached."
                    contextTestOutput = context.contextSummary
                }
                contextTestRunning = false
            }
        }
    }

}

// MARK: - Run Log

struct RunLogView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run Log")
                        .font(.headline)
                    Text("Stored locally. Only the \(appState.maxPipelineHistoryCount) most recent runs are kept.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Clear History") {
                    appState.clearPipelineHistory()
                }
                .disabled(appState.pipelineHistory.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if appState.pipelineHistory.isEmpty {
                VStack {
                    Spacer()
                    Text("No runs yet. Use dictation to populate history.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.pipelineHistory) { item in
                            RunLogEntryView(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

// MARK: - Run Log Entry

struct RunLogEntryView: View {
    private let actionIconSize: CGFloat = 28
    let item: PipelineHistoryItem
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    @State private var isRetrying = false
    @State private var showContextPrompt = false
    @State private var showPostProcessingPrompt = false
    @State private var copiedTranscript = false
    @State private var copiedTranscriptResetWorkItem: DispatchWorkItem?

    private var isError: Bool {
        item.postProcessingStatus.hasPrefix("Error:")
    }

    private var copyableTranscript: String {
        if !item.postProcessedTranscript.isEmpty {
            return item.postProcessedTranscript
        }
        return item.rawTranscript
    }

    @ViewBuilder
    private func actionIconButton(
        systemName: String,
        color: Color = .secondary,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: actionIconSize, height: actionIconSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: actionIconSize, height: actionIconSize)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        if isError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.timestamp.formatted(date: .numeric, time: .standard))
                                .font(.subheadline.weight(.semibold))
                            Text(item.postProcessedTranscript.isEmpty ? "(no transcript)" : item.postProcessedTranscript)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    if isError && item.audioFileName != nil {
                        Button {
                            appState.retryTranscription(item: item)
                        } label: {
                            if isRetrying {
                                ProgressView()
                                    .controlSize(.mini)
                                    .frame(width: actionIconSize, height: actionIconSize)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .frame(width: actionIconSize, height: actionIconSize)
                                    .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isRetrying)
                        .help("Retry transcription")
                    } else {
                        Color.clear
                            .frame(width: actionIconSize, height: actionIconSize)
                    }

                    actionIconButton(systemName: "square.and.arrow.up", help: "Export run log") {
                        TestCaseExporter.exportWithSavePanel(
                            item: item,
                            audioDirURL: AppState.audioStorageDirectory()
                        )
                    }

                    actionIconButton(
                        systemName: copiedTranscript ? "checkmark" : "doc.on.doc",
                        color: copiedTranscript ? .green : .secondary,
                        help: copiedTranscript ? "Copied transcript" : "Copy transcript",
                        disabled: copyableTranscript.isEmpty
                    ) {
                        copyTranscriptToPasteboard()
                    }

                    actionIconButton(systemName: "trash", help: "Delete this run") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.deleteHistoryEntry(id: item.id)
                        }
                    }
                }
            }
            .padding(12)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // Audio player
                    if let audioFileName = item.audioFileName {
                        let audioURL = AppState.audioStorageDirectory().appendingPathComponent(audioFileName)
                        AudioPlayerView(audioURL: audioURL)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("No audio recorded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Custom vocabulary
                    if !item.customVocabulary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Vocabulary")
                                .font(.caption.weight(.semibold))
                            FlowLayout(spacing: 4) {
                                ForEach(parseVocabulary(item.customVocabulary), id: \.self) { word in
                                    Text(word)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Pipeline steps
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pipeline")
                            .font(.caption.weight(.semibold))

                        // Step 1: Context Capture
                        PipelineStepView(
                            number: 1,
                            title: "Capture Context",
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let dataURL = item.contextScreenshotDataURL,
                                       let image = imageFromDataURL(dataURL) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 120)
                                            .cornerRadius(4)
                                    }

                                    if let prompt = item.contextPrompt, !prompt.isEmpty {
                                        Button {
                                            showContextPrompt.toggle()
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(showContextPrompt ? "Hide Prompt" : "Show Prompt")
                                                    .font(.caption)
                                                Image(systemName: showContextPrompt ? "chevron.up" : "chevron.down")
                                                    .font(.caption2)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)

                                        if showContextPrompt {
                                            Text(prompt)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(FlowColors.cardBg)
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !item.contextSummary.isEmpty {
                                        Text(item.contextSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    } else {
                                        Text("No context captured")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )

                        // Step 2: Transcribe Audio
                        PipelineStepView(
                            number: 2,
                            title: "Transcribe Audio",
                            content: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sent audio to the configured transcription model")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    if !item.rawTranscript.isEmpty {
                                        Text(item.rawTranscript)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(FlowColors.cardBg)
                                            .cornerRadius(4)
                                    } else {
                                        Text("(empty transcript)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        )

                        // Step 3: Post-Process
                        PipelineStepView(
                            number: 3,
                            title: "Post-Process",
                            content: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.postProcessingStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)

                                    if let prompt = item.postProcessingPrompt, !prompt.isEmpty {
                                        Button {
                                            showPostProcessingPrompt.toggle()
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(showPostProcessingPrompt ? "Hide Prompt" : "Show Prompt")
                                                    .font(.caption)
                                                Image(systemName: showPostProcessingPrompt ? "chevron.up" : "chevron.down")
                                                    .font(.caption2)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Color.accentColor)

                                        if showPostProcessingPrompt {
                                            Text(prompt)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(FlowColors.cardBg)
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !item.postProcessedTranscript.isEmpty {
                                        Text(item.postProcessedTranscript)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(FlowColors.cardBg)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        )
                    }

                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isError ? Color.red.opacity(0.4) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onReceive(appState.$retryingItemIDs) { ids in
            isRetrying = ids.contains(item.id)
        }
    }

    private func parseVocabulary(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func copyTranscriptToPasteboard() {
        guard !copyableTranscript.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copyableTranscript, forType: .string)
        copiedTranscript = true

        copiedTranscriptResetWorkItem?.cancel()
        let resetWorkItem = DispatchWorkItem {
            copiedTranscript = false
            copiedTranscriptResetWorkItem = nil
        }
        copiedTranscriptResetWorkItem = resetWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: resetWorkItem)
    }
}

// MARK: - Pipeline Step View

struct PipelineStepView<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(FlowColors.cardBg.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Audio Player

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVAudioPlayer?
    @State private var delegate = AudioPlayerDelegate()
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 0
    @State private var elapsed: TimeInterval = 0
    @State private var progressTimer: Timer?

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, geo.size.width * progress), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 28)

            Text("\(formatDuration(elapsed)) / \(formatDuration(duration))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .onAppear {
            loadDuration()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func loadDuration() {
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
        if let p = try? AVAudioPlayer(contentsOf: audioURL) {
            duration = p.duration
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
            do {
                let p = try AVAudioPlayer(contentsOf: audioURL)
                delegate.onFinish = {
                    self.stopPlayback()
                }
                p.delegate = delegate
                p.play()
                player = p
                isPlaying = true
                elapsed = 0
                startProgressTimer()
            } catch {}
        }
    }

    private func stopPlayback() {
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        player = nil
        isPlaying = false
        elapsed = 0
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let p = player, p.isPlaying {
                elapsed = p.currentTime
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let pos = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Voice Macros Settings

struct VoiceMacrosSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddMacro = false
    @State private var editingMacro: VoiceMacro?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsCard("Voice Macros", icon: "music.mic") {
                    macrosSection
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingAddMacro, onDismiss: { editingMacro = nil }) {
            VoiceMacroEditorView(isPresented: $showingAddMacro, macro: $editingMacro)
        }
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bypass post-processing and immediately paste your predefined text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { showingAddMacro = true }) {
                    Text("Add Macro")
                }
            }

            if appState.voiceMacros.isEmpty {
                VStack {
                    Image(systemName: "music.mic")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)
                    Text("No Voice Macros Yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Click 'Add Macro' to define your first voice macro.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(appState.voiceMacros.enumerated()), id: \.element.id) { index, macro in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(macro.command)
                                    .font(.headline)
                                Spacer()
                                Button("Edit") {
                                    editingMacro = macro
                                    showingAddMacro = true
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                
                                Button("Delete") {
                                    appState.voiceMacros.removeAll { $0.id == macro.id }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                            Text(macro.payload)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .background(FlowColors.cardBg.opacity(0.8))
                    }
                }
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }
        }
    }
}

struct VoiceMacroEditorView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    @Binding var macro: VoiceMacro?

    @State private var command: String = ""
    @State private var payload: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(macro == nil ? "Add Macro" : "Edit Macro")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Command (What you say)")
                    .font(.caption.weight(.semibold))
                TextField("e.g. debugging prompt", text: $command)
                    .textFieldStyle(.roundedBorder)

                Text("Text (What gets pasted)")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 8)
                TextEditor(text: $payload)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(FlowColors.surface)
                    .frame(height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(FlowColors.border, lineWidth: 1))
            }

            HStack {
                Button("Cancel") {
                    isPresented = false
                    macro = nil
                }
                Spacer()
                Button("Save") {
                    let newMacro = VoiceMacro(
                        id: macro?.id ?? UUID(),
                        command: command.trimmingCharacters(in: .whitespacesAndNewlines),
                        payload: payload
                    )
                    
                    if let existingIndex = appState.voiceMacros.firstIndex(where: { $0.id == newMacro.id }) {
                        appState.voiceMacros[existingIndex] = newMacro
                    } else {
                        appState.voiceMacros.append(newMacro)
                    }
                    isPresented = false
                    macro = nil
                }
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || payload.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            if let m = macro {
                command = m.command
                payload = m.payload
            }
        }
    }
}

// MARK: - Legacy Components

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(_ title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FlowColors.cardBg.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
    }
}
