import SwiftUI

// MARK: - Flow Design System
// Shared color tokens, typography, and reusable card components
// matching the warm, premium Wispr Flow aesthetic.

enum FlowColors {
    // Backgrounds
    static let cream = Color(red: 0.98, green: 0.97, blue: 0.95)       // #FAF7F2 — primary window bg
    static let surface = Color.white                                      // content panel bg
    static let cardBg = Color(red: 0.96, green: 0.945, blue: 0.925)     // #F5F1EC — grouped card bg
    static let border = Color(red: 0.91, green: 0.89, blue: 0.87)       // #E8E4DE — subtle borders

    // Accent
    static let accent = Color(red: 0.91, green: 0.64, blue: 0.30)       // #E8A24C — active highlights

    // Controls
    static let pill = Color(red: 0.92, green: 0.90, blue: 0.87)         // #EBE6DF — button fills
    static let pillHover = Color(red: 0.88, green: 0.86, blue: 0.83)    // darker on hover

    // Text
    static let textPrimary = Color(red: 0.10, green: 0.10, blue: 0.10)  // #1A1A1A
    static let textSecondary = Color(red: 0.48, green: 0.46, blue: 0.44) // #7A7570
    static let textTertiary = Color(red: 0.68, green: 0.66, blue: 0.63) // #ADA89F

    // Semantic
    static let success = Color(red: 0.30, green: 0.69, blue: 0.31)      // green checkmarks
    static let warning = Color.orange
    static let danger = Color.red
}

enum FlowFonts {
    /// Serif-style page headings (e.g., "General", "System")
    static func pageTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// Section subheadings (e.g., "App settings", "Sound")
    static func sectionTitle(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Sidebar navigation items
    static func sidebarItem(isSelected: Bool) -> Font {
        .system(size: 13, weight: isSelected ? .semibold : .regular)
    }

    /// Small uppercase section labels (e.g., "SETTINGS")
    static func sectionLabel() -> Font {
        .system(size: 11, weight: .semibold)
    }

    /// Body text
    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size)
    }

    /// Caption / description text
    static func caption() -> Font {
        .system(size: 11)
    }

    /// Monospaced (for version numbers, API keys)
    static func mono(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Reusable Components

/// A grouped card container matching the reference's cream-colored rounded card style.
/// Used in Settings to group related rows.
struct FlowGroupedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(FlowColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FlowColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}

/// A single row inside a FlowGroupedCard. Shows a title, optional description,
/// and a trailing control (toggle, button, etc.).
struct FlowSettingsRow<Trailing: View>: View {
    let title: String
    let description: String?
    let trailing: Trailing

    init(_ title: String, description: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.description = description
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FlowFonts.body(13))
                    .foregroundStyle(FlowColors.textPrimary)
                if let description {
                    Text(description)
                        .font(FlowFonts.caption())
                        .foregroundStyle(FlowColors.textSecondary)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

/// A "Change" pill button matching the reference's warm beige style.
struct FlowPillButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FlowColors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isHovering ? FlowColors.pillHover : FlowColors.pill)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

/// A divider used inside grouped cards (thinner than system divider).
struct FlowCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(FlowColors.border.opacity(0.4))
            .frame(height: 0.5)
            .padding(.horizontal, 18)
    }
}

/// Sidebar section header (e.g., "SETTINGS")
struct FlowSidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FlowFonts.sectionLabel())
            .foregroundStyle(FlowColors.textSecondary)
            .tracking(0.8)
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }
}

/// Sidebar navigation row with hover and active state.
struct FlowSidebarRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? FlowColors.textPrimary : FlowColors.textSecondary)
                    .frame(width: 18)
                Text(title)
                    .font(FlowFonts.sidebarItem(isSelected: isSelected))
                    .foregroundStyle(isSelected ? FlowColors.textPrimary : FlowColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? FlowColors.accent.opacity(0.12)
                          : isHovering ? FlowColors.textPrimary.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

/// Shortcut key badge (orange pill with key name like "^ Ctrl").
struct FlowShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(FlowColors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(FlowColors.accent.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(FlowColors.accent.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

/// Polyfill for UnevenRoundedRectangle (available macOS 14+).
/// On macOS 13, falls back to a regular RoundedRectangle.
struct UnevenRoundedRectangle: InsettableShape {
    var topLeadingRadius: CGFloat
    var bottomLeadingRadius: CGFloat
    var bottomTrailingRadius: CGFloat
    var topTrailingRadius: CGFloat
    var insetAmount: CGFloat = 0

    init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0) {
        self.topLeadingRadius = topLeadingRadius
        self.bottomLeadingRadius = bottomLeadingRadius
        self.bottomTrailingRadius = bottomTrailingRadius
        self.topTrailingRadius = topTrailingRadius
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let tl = min(topLeadingRadius, min(insetRect.width, insetRect.height) / 2)
        let tr = min(topTrailingRadius, min(insetRect.width, insetRect.height) / 2)
        let bl = min(bottomLeadingRadius, min(insetRect.width, insetRect.height) / 2)
        let br = min(bottomTrailingRadius, min(insetRect.width, insetRect.height) / 2)

        path.move(to: CGPoint(x: insetRect.minX + tl, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX - tr, y: insetRect.minY))
        path.addArc(tangent1End: CGPoint(x: insetRect.maxX, y: insetRect.minY), tangent2End: CGPoint(x: insetRect.maxX, y: insetRect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: insetRect.maxX, y: insetRect.maxY), tangent2End: CGPoint(x: insetRect.maxX - br, y: insetRect.maxY), radius: br)
        path.addLine(to: CGPoint(x: insetRect.minX + bl, y: insetRect.maxY))
        path.addArc(tangent1End: CGPoint(x: insetRect.minX, y: insetRect.maxY), tangent2End: CGPoint(x: insetRect.minX, y: insetRect.maxY - bl), radius: bl)
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: insetRect.minX, y: insetRect.minY), tangent2End: CGPoint(x: insetRect.minX + tl, y: insetRect.minY), radius: tl)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var rectangle = self
        rectangle.insetAmount += amount
        return rectangle
    }
}

/// Animated dots for transcribing state.
struct SimpleTranscribingDots: View {
    @State private var activeDot = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(FlowColors.accent.opacity(activeDot == index ? 1.0 : 0.4))
                    .frame(width: 14, height: 14)
                    .scaleEffect(activeDot == index ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}

/// A pill-shaped badge with the accent color for shortcuts.
struct FlowAccentPill: View {
    let icon: String?
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(FlowColors.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(FlowColors.accent.opacity(0.15))
        )
    }
}

/// Custom text field style matching the Flow design system.
struct FlowTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(FlowColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FlowColors.border, lineWidth: 1)
            )
    }
}

/// Custom secure field with Flow styling.
struct FlowSecureField: View {
    @Binding var text: String
    var isDisabled: Bool = false
    var font: Font = .body

    var body: some View {
        SecureField("Paste your API key", text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .disabled(isDisabled)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(FlowColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FlowColors.border, lineWidth: 1)
            )
    }
}
