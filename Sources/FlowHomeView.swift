import SwiftUI

// MARK: - Home View

struct FlowHomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var records: [TranscriptRecord] = []

    private var holdShortcutLabel: String {
        let binding = appState.holdShortcut
        if binding.isDisabled { return "your shortcut" }
        return binding.displayName
    }

    // Stats computed from transcript history
    private var totalWords: Int {
        records.reduce(0) { total, record in
            total + record.displayTranscript
                .split(separator: " ")
                .count
        }
    }

    private var weekStreak: Int {
        guard !records.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        // Walk backwards week by week
        while true {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            let hasEntry = records.contains { record in
                record.timestamp >= weekStart && record.timestamp < weekEnd
            }
            if hasEntry {
                streak += 1
                guard let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkDate) else { break }
                checkDate = prevWeek
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Greeting
                greetingSection
                    .padding(.top, 8)

                // Hero + Stats row
                HStack(alignment: .top, spacing: 16) {
                    heroBanner
                    statsPanel
                }

                // Transcript history feed
                transcriptFeed
            }
            .padding(28)
        }
        .background(FlowColors.surface)
        .onAppear { reload() }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack(spacing: 6) {
            Text("Get back into the flow with")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FlowColors.textPrimary)
            FlowShortcutBadge(text: holdShortcutLabel)
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hold down \(holdShortcutLabel) to dictate")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Flow works in all your apps. Try it in **email**, **messages**, **docs** or anywhere else.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.12, blue: 0.10),
                    Color(red: 0.30, green: 0.22, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Stats Panel

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            statRow(value: "\(totalWords)", label: "total words")
            statRow(value: "\(weekStreak)", label: "week streak")
            statRow(value: "\(records.count)", label: "transcripts")
        }
        .padding(20)
        .frame(width: 170)
        .background(FlowColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(FlowColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func statRow(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FlowColors.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(FlowColors.textSecondary)
        }
    }

    // MARK: - Transcript Feed

    private var transcriptFeed: some View {
        VStack(alignment: .leading, spacing: 0) {
            let grouped = groupedByDate()

            if grouped.isEmpty {
                VStack(spacing: 10) {
                    Text("No transcripts yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FlowColors.textSecondary)
                    Text("Start dictating and your history will appear here.")
                        .font(.system(size: 12))
                        .foregroundStyle(FlowColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(grouped.keys.sorted().reversed()), id: \.self) { dateKey in
                    let dayRecords = grouped[dateKey] ?? []

                    // Date header
                    Text(dateHeader(dateKey))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FlowColors.textSecondary)
                        .tracking(0.5)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // Day's records in a grouped card
                    FlowGroupedCard {
                        ForEach(Array(dayRecords.enumerated()), id: \.element.id) { index, record in
                            transcriptRow(record)
                            if index < dayRecords.count - 1 {
                                FlowCardDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func transcriptRow(_ record: TranscriptRecord) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(timeString(record.timestamp))
                .font(FlowFonts.mono(11))
                .foregroundStyle(FlowColors.textTertiary)
                .frame(width: 70, alignment: .leading)

            Text(record.displayTranscript)
                .font(FlowFonts.body(13))
                .foregroundStyle(FlowColors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.displayTranscript, forType: .string)
            }
        }
    }

    // MARK: - Helpers

    private func reload() {
        records = appState.transcriptHistoryStore.loadAll()
    }

    private func groupedByDate() -> [String: [TranscriptRecord]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var dict: [String: [TranscriptRecord]] = [:]
        for record in records {
            let key = formatter.string(from: record.timestamp)
            dict[key, default: []].append(record)
        }
        return dict
    }

    private func dateHeader(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return dateKey }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "TODAY" }
        if calendar.isDateInYesterday(date) { return "YESTERDAY" }
        let display = DateFormatter()
        display.dateFormat = "MMMM d, yyyy"
        return display.string(from: date).uppercased()
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }
}
