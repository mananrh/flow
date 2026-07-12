import SwiftUI
import AppKit

// MARK: - State

final class RecordingOverlayState: ObservableObject {
    @Published var phase: OverlayPhase = .recording
    @Published var audioLevel: Float = 0.0
    @Published var recordingTriggerMode: RecordingTriggerMode = .hold
    @Published var isCommandMode = false
    @Published var showsTranscribingSpinner = false
    @Published var updateVersion: String = ""
}

enum OverlayPhase {
    case initializing
    case recording
    case transcribing
    case feedback
    case updateAvailable
}

// MARK: - Panel Helpers

private func makeOverlayPanel(width: CGFloat, height: CGFloat) -> NSPanel {
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.level = .screenSaver
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces]
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    return panel
}

private func makeNotchContent<V: View>(
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat,
    rootView: V
) -> NSView {
    let shaped = rootView
        .frame(width: width, height: height)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.14),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius))
        .overlay(
            UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 6)

    let hosting = NSHostingView(rootView: shaped)
    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
    hosting.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
    // Match the NSHostingView's layer mask to SwiftUI's clip shape so visual
    // effect sublayers don't bleed at the corners.
    hosting.wantsLayer = true
    hosting.layer?.mask = bottomRoundedMask(size: CGSize(width: width, height: height), radius: cornerRadius)
    return hosting
}

/// Creates a Core Animation mask that rounds only the bottom two corners.
private func bottomRoundedMask(size: CGSize, radius: CGFloat) -> CALayer {
    let path = CGMutablePath()
    let r = min(radius, min(size.width, size.height) / 2)
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: size.width, y: 0))
    path.addLine(to: CGPoint(x: size.width, y: size.height - r))
    path.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - r, y: size.height), radius: r)
    path.addLine(to: CGPoint(x: r, y: size.height))
    path.addArc(tangent1End: CGPoint(x: 0, y: size.height), tangent2End: CGPoint(x: 0, y: size.height - r), radius: r)
    path.closeSubpath()

    let mask = CAShapeLayer()
    mask.path = path
    mask.frame = CGRect(origin: .zero, size: size)
    return mask
}

// MARK: - Manager

final class RecordingOverlayManager {
    private var overlayWindow: NSPanel?
    private let overlayState = RecordingOverlayState()
    private var lockedOverlayWidth: CGFloat?

    var onStopButtonPressed: (() -> Void)?
    var onUpdateOverlayPressed: (() -> Void)?

    private var screenHasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }

    private var notchWidth: CGFloat {
        guard let screen = NSScreen.main, screenHasNotch else { return 0 }
        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else { return 0 }
        return screen.frame.width - leftArea.width - rightArea.width
    }

    private var notchOverlap: CGFloat {
        guard let screen = NSScreen.main else { return 0 }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }

    private var overlayAcceptsMouseEvents: Bool {
        (overlayState.phase == .recording && overlayState.recordingTriggerMode == .toggle)
            || overlayState.phase == .updateAvailable
    }

    func showInitializing(mode: RecordingTriggerMode = .hold, isCommandMode: Bool = false) {
        DispatchQueue.main.async {
            self.lockedOverlayWidth = nil
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.isCommandMode = isCommandMode
            self.overlayState.phase = .initializing
            self.overlayState.showsTranscribingSpinner = false
            self.overlayState.audioLevel = 0
            self.showOverlayPanel(animatedResize: false)
        }
    }

    func showRecording(mode: RecordingTriggerMode = .hold, isCommandMode: Bool = false) {
        DispatchQueue.main.async {
            self.lockedOverlayWidth = nil
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.isCommandMode = isCommandMode
            self.overlayState.phase = .recording
            self.overlayState.showsTranscribingSpinner = false
            self.overlayState.audioLevel = 0
            self.showOverlayPanel(animatedResize: true)
        }
    }

    func transitionToRecording(mode: RecordingTriggerMode = .hold, isCommandMode: Bool = false) {
        DispatchQueue.main.async {
            self.lockedOverlayWidth = nil
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.isCommandMode = isCommandMode
            self.overlayState.phase = .recording
            self.overlayState.showsTranscribingSpinner = false
            self.updateOverlayLayout(animated: true)
        }
    }

    func setRecordingTriggerMode(_ mode: RecordingTriggerMode, animated: Bool) {
        DispatchQueue.main.async {
            self.overlayState.recordingTriggerMode = mode
            self.updateOverlayLayout(animated: animated)
        }
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.overlayState.audioLevel = level
        }
    }

    func prepareForTranscribing() {
        DispatchQueue.main.async {
            self.setTranscribingPhase(showsTranscribingSpinner: false)
        }
    }

    func showTranscribing() {
        DispatchQueue.main.async {
            self.setTranscribingPhase(showsTranscribingSpinner: true)
        }
    }

    func showFailureIndicator() {
        DispatchQueue.main.async {
            self.showFeedbackPanel()
        }
    }

    func showUpdateAvailable(version: String) {
        DispatchQueue.main.async {
            self.lockedOverlayWidth = nil
            self.overlayState.isCommandMode = false
            self.overlayState.showsTranscribingSpinner = false
            self.overlayState.updateVersion = version
            self.overlayState.phase = .updateAvailable
            self.showOverlayPanel(animatedResize: true)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.dismissAll()
        }
    }

    private func showOverlayPanel(animatedResize: Bool) {
        let frame = overlayFrame

        if let panel = overlayWindow {
            panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
            panel.contentView = makeOverlayContent(frame: frame)
            resize(panel: panel, to: frame, animated: animatedResize)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }

        let panel = makeOverlayPanel(width: frame.width, height: frame.height)
        panel.hasShadow = false
        panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
        panel.contentView = makeOverlayContent(frame: frame)

        guard let screen = NSScreen.main else { return }

        let hiddenFrame = NSRect(x: frame.origin.x, y: screen.frame.maxY, width: frame.width, height: frame.height)
        panel.setFrame(hiddenFrame, display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
            panel.animator().setFrame(frame, display: true)
        }

        overlayWindow = panel
    }

    private func updateOverlayLayout(animated: Bool) {
        guard let panel = overlayWindow else { return }
        let frame = overlayFrame
        panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
        panel.contentView = makeOverlayContent(frame: frame)
        resize(panel: panel, to: frame, animated: animated)
    }

    private func setTranscribingPhase(showsTranscribingSpinner: Bool) {
        lockedOverlayWidth = overlayWindow?.frame.width ?? overlayWidth
        overlayState.phase = .transcribing
        overlayState.showsTranscribingSpinner = showsTranscribingSpinner
        showOverlayPanel(animatedResize: true)
    }

    private func makeOverlayContent(frame: NSRect) -> NSView {
        makeNotchContent(
            width: frame.width,
            height: frame.height,
            cornerRadius: screenHasNotch ? 20 : 14,
            rootView: RecordingOverlayView(
                state: overlayState,
                onStopButtonPressed: { [weak self] in
                    self?.onStopButtonPressed?()
                },
                onUpdateOverlayPressed: { [weak self] in
                    self?.onUpdateOverlayPressed?()
                }
            )
            .padding(.top, screenHasNotch ? notchOverlap : 0)
        )
    }

    private func resize(panel: NSPanel, to frame: NSRect, animated: Bool) {
        guard animated else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private var overlayFrame: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let width = overlayWidth
        let overlap = screenHasNotch ? notchOverlap : 0
        let height: CGFloat = 42 + overlap
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private var overlayWidth: CGFloat {
        if let lockedOverlayWidth, overlayState.phase == .transcribing {
            return lockedOverlayWidth
        }

        if overlayState.phase == .feedback {
            let feedbackWidth: CGFloat = 100
            guard screenHasNotch else { return feedbackWidth }
            return max(notchWidth, feedbackWidth)
        }

        if overlayState.phase == .updateAvailable {
            let updateWidth: CGFloat = 200
            guard screenHasNotch else { return updateWidth }
            return max(notchWidth, updateWidth)
        }

        let commandModeWidth: CGFloat = 200
        let toggleWidth: CGFloat = 168
        let defaultWidth: CGFloat = 100
        let baseWidth: CGFloat

        if overlayState.isCommandMode {
            baseWidth = commandModeWidth
        } else if overlayState.phase == .recording && overlayState.recordingTriggerMode == .toggle {
            baseWidth = toggleWidth
        } else {
            baseWidth = defaultWidth
        }

        guard screenHasNotch else { return baseWidth }
        return max(notchWidth, baseWidth)
    }

    private func showFeedbackPanel() {
        lockedOverlayWidth = nil
        overlayState.phase = .feedback
        showOverlayPanel(animatedResize: true)
    }

    private func dismissAll() {
        lockedOverlayWidth = nil
        overlayState.isCommandMode = false
        overlayState.showsTranscribingSpinner = false
        overlayState.updateVersion = ""
        if let panel = overlayWindow {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                panel.alphaValue = 1
                self.overlayWindow = nil
            })
        }
    }
}

// MARK: - Accent Color Theme

private enum FlowAccent {
    static let primary = Color(red: 0.38, green: 0.52, blue: 1.0)
    static let secondary = Color(red: 0.56, green: 0.36, blue: 1.0)
    static let recording = Color(red: 1.0, green: 0.30, blue: 0.36)
    static let processing = Color(red: 0.30, green: 0.85, blue: 0.72)

    static var activeGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Waveform Views

struct WaveformBar: View {
    let amplitude: CGFloat
    let index: Int
    let isRecording: Bool

    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 22

    var body: some View {
        Capsule()
            .fill(barGradient)
            .frame(width: 3.5, height: minHeight + (maxHeight - minHeight) * amplitude)
    }

    private var barGradient: some ShapeStyle {
        LinearGradient(
            colors: isRecording
                ? [FlowAccent.primary.opacity(0.7 + Double(amplitude) * 0.3),
                   FlowAccent.secondary.opacity(0.6 + Double(amplitude) * 0.4)]
                : [Color.white.opacity(0.5), Color.white.opacity(0.3)],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

struct WaveformView: View {
    let audioLevel: Float
    var showsActivityPulse = false

    private static let barCount = 9
    private static let multipliers: [CGFloat] = [0.35, 0.55, 0.75, 0.9, 1.0, 0.9, 0.75, 0.55, 0.35]
    private static let centerIndex = CGFloat((barCount - 1) / 2)

    var body: some View {
        Group {
            if showsActivityPulse {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    waveformBars(pulseTime: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                waveformBars(pulseTime: nil)
            }
        }
        .frame(height: 22)
    }

    private func waveformBars(pulseTime: TimeInterval?) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                WaveformBar(
                    amplitude: barAmplitude(for: index, pulseTime: pulseTime),
                    index: index,
                    isRecording: showsActivityPulse
                )
                    .animation(
                        .spring(
                            response: barResponse(for: index),
                            dampingFraction: 0.82
                        )
                        .delay(barDelay(for: index)),
                        value: audioLevel
                    )
            }
        }
    }

    private func barAmplitude(for index: Int, pulseTime: TimeInterval?) -> CGFloat {
        let level = CGFloat(max(audioLevel, 0))
        let baseAmplitude = min(level * Self.multipliers[index], 1.0)

        guard let pulseTime else { return baseAmplitude }

        let travelingWave = CGFloat(0.5 + 0.5 * sin((pulseTime * 6.2) - Double(index) * 0.78))
        let shimmer = CGFloat(0.5 + 0.5 * sin((pulseTime * 3.1) + Double(index) * 0.5))
        let pulse = travelingWave * 0.22 + shimmer * 0.06

        let saturationRelief = baseAmplitude * (0.74 + pulse)
        let quietPulse = (1.0 - baseAmplitude) * (0.04 + pulse * 0.28)
        return min(saturationRelief + quietPulse, 1.0)
    }

    private func barResponse(for index: Int) -> Double {
        let distance = abs(CGFloat(index) - Self.centerIndex)
        let normalizedDistance = distance / Self.centerIndex
        return 0.18 + Double(normalizedDistance) * 0.06
    }

    private func barDelay(for index: Int) -> Double {
        let distance = abs(CGFloat(index) - Self.centerIndex)
        return Double(distance) * 0.01
    }
}

struct ProcessingWaveformView: View {
    private static let barCount = 9
    private static let multipliers: [CGFloat] = [0.42, 0.58, 0.76, 0.9, 1.0, 0.9, 0.76, 0.58, 0.42]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            HStack(spacing: 3) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    let wave = 0.5 + 0.5 * sin((time * 5.6) - Double(index) * 0.5)
                    let shimmer = 0.5 + 0.5 * sin((time * 2.8) + Double(index) * 0.75)
                    let amplitude = min(
                        0.16 + CGFloat(wave) * Self.multipliers[index] * 0.52 + CGFloat(shimmer) * 0.08,
                        1.0
                    )

                    WaveformBar(amplitude: amplitude, index: index, isRecording: false)
                        .opacity(0.35 + CGFloat(wave) * 0.6)
                }
            }
            .frame(height: 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InitializingDotsView: View {
    @State private var activeDot = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        activeDot == index
                            ? AnyShapeStyle(FlowAccent.activeGradient)
                            : AnyShapeStyle(Color.white.opacity(0.2))
                    )
                    .frame(width: 5, height: 5)
                    .scaleEffect(activeDot == index ? 1.3 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: activeDot)
            }
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
                DispatchQueue.main.async {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Glow Ring (ambient recording indicator)

struct GlowRingView: View {
    let audioLevel: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(time * 3.0)
            let level = CGFloat(max(audioLevel, 0))
            let glowIntensity = 0.15 + level * 0.5 + CGFloat(pulse) * 0.1

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FlowAccent.primary.opacity(glowIntensity),
                            FlowAccent.secondary.opacity(glowIntensity * 0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 18
                    )
                )
                .frame(width: 36, height: 36)
                .blur(radius: 4 + level * 3)
        }
    }
}

// MARK: - Main Overlay View

struct RecordingOverlayView: View {
    @ObservedObject var state: RecordingOverlayState
    let onStopButtonPressed: () -> Void
    let onUpdateOverlayPressed: () -> Void

    private let leadingAccessoryWidth: CGFloat = 28
    private let trailingAccessoryWidth: CGFloat = 36

    private var showsLiveRecordingContent: Bool {
        state.phase == .recording || (state.phase == .transcribing && !state.showsTranscribingSpinner)
    }

    private var showsStopButton: Bool {
        showsLiveRecordingContent && state.recordingTriggerMode == .toggle
    }

    var body: some View {
        Group {
            if state.phase == .feedback {
                FailureIndicatorView()
            } else if state.phase == .updateAvailable {
                UpdateAvailableOverlayView(onPress: onUpdateOverlayPressed)
            } else {
                ZStack {
                    // Ambient glow behind waveform during recording
                    if state.phase == .recording {
                        GlowRingView(audioLevel: state.audioLevel)
                            .transition(.opacity)
                    }

                    Group {
                        if state.phase == .initializing {
                            InitializingDotsView()
                                .transition(.opacity)
                        } else if showsLiveRecordingContent {
                            WaveformView(
                                audioLevel: state.audioLevel,
                                showsActivityPulse: state.phase == .recording
                            )
                                .transition(.opacity)
                        } else {
                            ProcessingWaveformView()
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }

                    HStack {
                        Group {
                            if state.isCommandMode {
                                CommandModeIndicator()
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }
                        }
                        .frame(width: leadingAccessoryWidth, alignment: .center)
                        .frame(maxHeight: .infinity, alignment: .center)

                        Spacer(minLength: 0)

                        Group {
                            if showsStopButton {
                                Button(action: onStopButtonPressed) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(
                                            Circle()
                                                .fill(FlowAccent.recording.opacity(0.9))
                                                .shadow(color: FlowAccent.recording.opacity(0.4), radius: 6, x: 0, y: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .frame(width: trailingAccessoryWidth, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: state.phase)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: state.recordingTriggerMode)
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: state.isCommandMode)
    }
}

// MARK: - Accessory Views

struct CommandModeIndicator: View {
    var body: some View {
        Image(systemName: "pencil")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FlowAccent.primary)
            .frame(width: 18, height: 18, alignment: .center)
    }
}

struct FailureIndicatorView: View {
    @State private var appeared = false

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(
                Circle()
                    .fill(FlowAccent.recording.opacity(0.9))
                    .shadow(color: FlowAccent.recording.opacity(0.3), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: appeared)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { appeared = true }
    }
}

struct UpdateAvailableOverlayView: View {
    let onPress: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onPress) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FlowAccent.primary)

                Text("Update Available")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
