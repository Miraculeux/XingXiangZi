import SwiftUI

struct SidebarView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Binding var selectedPoem: Poem?
    @Binding var searchText: String

    private var displayGroups: [DynastyGroup] {
        if searchText.isEmpty {
            return dbManager.dynastyGroups
        }
        let results = dbManager.search(query: searchText)
        return buildGroups(from: results)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索诗词…", text: $searchText)
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

            // Tree view
            if displayGroups.isEmpty {
                Spacer()
                Text("暂无诗词")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(selection: $selectedPoem) {
                    ForEach(displayGroups) { dynastyGroup in
                        Section {
                            DisclosureGroup(dynastyGroup.dynasty) {
                                ForEach(dynastyGroup.authors) { authorGroup in
                                    DisclosureGroup(authorGroup.author) {
                                        ForEach(authorGroup.poems) { poem in
                                            Text(poem.title)
                                                .tag(poem)
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        dbManager.deletePoem(id: poem.id)
                                                        if selectedPoem == poem {
                                                            selectedPoem = nil
                                                        }
                                                    } label: {
                                                        Label("删除", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func buildGroups(from poems: [Poem]) -> [DynastyGroup] {
        var dynastyDict: [String: [String: [Poem]]] = [:]
        for poem in poems {
            dynastyDict[poem.dynasty, default: [:]][poem.author, default: []].append(poem)
        }
        return dynastyDict.keys.sorted {
            DatabaseManager.dynastySortKey($0) < DatabaseManager.dynastySortKey($1)
        }.map { dynasty in
            let authorDict = dynastyDict[dynasty]!
            let authors = authorDict.keys.sorted().map { author in
                AuthorGroup(author: author, poems: authorDict[author]!.sorted { $0.title < $1.title })
            }
            return DynastyGroup(dynasty: dynasty, authors: authors)
        }
    }
}
