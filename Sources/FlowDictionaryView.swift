import SwiftUI

// MARK: - Dictionary View (Custom Vocabulary)

struct FlowDictionaryView: View {
    @EnvironmentObject var appState: AppState
    @State private var newWordInput: String = ""
    @State private var isAddingWord = false
    @State private var vocabularyEntries: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Dictionary")
                    .font(FlowFonts.pageTitle())
                    .foregroundStyle(FlowColors.textPrimary)
                Spacer()
                FlowPillButton(title: "Add new") {
                    isAddingWord = true
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Hero explainer card
                    heroCard

                    // Add word inline field
                    if isAddingWord {
                        addWordField
                    }

                    // Word list
                    if vocabularyEntries.isEmpty && !isAddingWord {
                        emptyState
                    } else {
                        wordList
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .background(FlowColors.surface)
        .onAppear { parseVocabulary() }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Flow spells the way ")
            + Text("you")
                .italic()
            + Text(" do.")

            Text("Add personal terms, company jargon, client names, or industry-specific lingo so Flow always gets them right.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))

            // Tag chips showing current entries
            if !vocabularyEntries.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(vocabularyEntries.prefix(8), id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
        .font(.system(size: 22, weight: .semibold))
        .foregroundColor(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.15, blue: 0.10),
                    Color(red: 0.35, green: 0.25, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Add Word Field

    private var addWordField: some View {
        HStack(spacing: 10) {
            TextField("Type a word or phrase…", text: $newWordInput)
                .textFieldStyle(.plain)
                .font(FlowFonts.body(13))
                .padding(10)
                .background(FlowColors.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FlowColors.border, lineWidth: 0.5)
                )
                .onSubmit { addWord() }

            FlowPillButton(title: "Add") {
                addWord()
            }

            Button {
                isAddingWord = false
                newWordInput = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FlowColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Word List

    private var wordList: some View {
        FlowGroupedCard {
            ForEach(Array(vocabularyEntries.enumerated()), id: \.offset) { index, entry in
                HStack {
                    Text(entry)
                        .font(FlowFonts.body(13))
                        .foregroundStyle(FlowColors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Delete") {
                        deleteWord(at: index)
                    }
                }

                if index < vocabularyEntries.count - 1 {
                    FlowCardDivider()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(FlowColors.textTertiary)
            Text("No words added yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FlowColors.textSecondary)
            Text("Add words and phrases that Flow should always spell correctly.")
                .font(.system(size: 12))
                .foregroundStyle(FlowColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func parseVocabulary() {
        let raw = appState.customVocabulary
        vocabularyEntries = raw
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func addWord() {
        let trimmed = newWordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        vocabularyEntries.append(trimmed)
        saveVocabulary()
        newWordInput = ""
    }

    private func deleteWord(at index: Int) {
        guard index >= 0 && index < vocabularyEntries.count else { return }
        vocabularyEntries.remove(at: index)
        saveVocabulary()
    }

    private func saveVocabulary() {
        appState.customVocabulary = vocabularyEntries.joined(separator: ", ")
    }
}
