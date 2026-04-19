import SwiftUI

#if os(iOS)
private let cardBackground = Color(.systemGray6)
#else
private let cardBackground = Color(nsColor: .controlBackgroundColor)
#endif

struct CiPaiDetailView: View {
    let cipai: CiPai

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Name and aliases
                VStack(alignment: .center, spacing: 8) {
                    Text(cipai.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    if let nameTc = cipai.nameTc, nameTc != cipai.name {
                        Text(nameTc)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    if let aliases = cipai.aliases, !aliases.isEmpty {
                        Text("又名：\(aliases)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if cipai.sectionCount != nil || cipai.charCount != nil {
                        HStack(spacing: 16) {
                            if let sections = cipai.sectionCount {
                                Label("\(sections)阕", systemImage: "text.alignleft")
                            }
                            if let chars = cipai.charCount {
                                Label("\(chars)字", systemImage: "character")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Introduction
                if let intro = cipai.intro, !intro.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("简介", systemImage: "info.circle")
                            .font(.headline)
                        Text(intro)
                            .font(.body)
                            .lineSpacing(6)
                    }
                }

                // Pattern
                if let pattern = cipai.pattern, !pattern.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("格律", systemImage: "music.note.list")
                            .font(.headline)
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                            .lineSpacing(6)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardBackground)
                            .cornerRadius(8)
                    }
                }

                // Example
                if let example = cipai.example, !example.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("例词", systemImage: "text.book.closed")
                            .font(.headline)
                        Text(example)
                            .font(.body)
                            .lineSpacing(6)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardBackground)
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .navigationTitle(cipai.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
