import SwiftUI

struct AlphabetCiPaiSection: Identifiable {
    let id = UUID()
    let letter: String
    var cipaiItems: [CiPai]
}

struct CiPaiListView: View {
    @ObservedObject var dbManager: DatabaseManager
    @State private var searchText = ""

    private var displaySections: [AlphabetCiPaiSection] {
        let list = searchText.isEmpty ? dbManager.cipaiList : dbManager.searchCiPai(query: searchText)
        var dict: [String: [CiPai]] = [:]
        for cipai in list {
            let letter = DatabaseManager.pinyinFirstLetter(of: cipai.name)
            dict[letter, default: []].append(cipai)
        }
        return dict.keys.sorted().map { letter in
            AlphabetCiPaiSection(letter: letter, cipaiItems: dict[letter]!)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索词牌…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if displaySections.isEmpty {
                Spacer()
                Text("暂无词牌")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(displaySections) { section in
                        Section(header: Text(section.letter)) {
                            ForEach(section.cipaiItems) { cipai in
                                NavigationLink(destination: CiPaiDetailView(cipai: cipai)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cipai.name)
                                            .font(.body)
                                        if let aliases = cipai.aliases, !aliases.isEmpty {
                                            Text(aliases)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("词牌")
    }
}
