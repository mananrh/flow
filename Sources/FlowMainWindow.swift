import SwiftUI

// MARK: - Main App Window

struct FlowMainWindow: View {
    @EnvironmentObject var appState: AppState

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 170)

            // Content panel
            ZStack {
                FlowColors.surface
                    .ignoresSafeArea()

                Group {
                    switch appState.selectedMainTab {
                    case .home:
                        FlowHomeView()
                    case .dictionary:
                        FlowDictionaryView()
                    }
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 14,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
        }
        .background(FlowColors.cream)
        .frame(minWidth: 780, minHeight: 540)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // App logo
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FlowColors.textPrimary)
                Text("Flow")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FlowColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Navigation
            ForEach(MainTab.allCases) { tab in
                FlowSidebarRow(
                    icon: tab.icon,
                    title: tab.title,
                    isSelected: appState.selectedMainTab == tab,
                    action: { appState.selectedMainTab = tab }
                )
            }

            Spacer()

            // Bottom actions
            FlowSidebarRow(
                icon: "gearshape",
                title: "Settings",
                isSelected: false,
                action: {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
            )

            // Version
            Text("Flow v\(appVersion)")
                .font(FlowFonts.mono(10))
                .foregroundStyle(FlowColors.textTertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .padding(.top, 4)
        }
        .padding(.horizontal, 6)
    }
}
