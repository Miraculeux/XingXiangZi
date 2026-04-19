import SwiftUI

#if os(iOS)
private let searchBarBackground = Color(.systemGray6)
#else
private let searchBarBackground = Color(nsColor: .controlBackgroundColor)
#endif

enum SidebarGrouping: String, CaseIterable, Identifiable {
    case dynasty
    case author

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dynasty: return "朝代"
        case .author: return "作者"
        }
    }
}

struct SidebarView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Binding var selectedPoem: Poem?
    @Binding var searchText: String
    @Binding var grouping: SidebarGrouping

    @State private var expandedDynasties: Set<String> = []
    @State private var expandedAuthors: Set<String> = []

    private var displayDynastyGroups: [DynastyGroup] {
        if searchText.isEmpty {
            return dbManager.dynastyGroups
        }
        return buildDynastyGroups(from: dbManager.search(query: searchText))
    }

    private var displayAlphabetSections: [AlphabetAuthorSection] {
        if searchText.isEmpty {
            return dbManager.alphabetAuthorSections
        }
        let groups = buildAuthorGroups(from: dbManager.search(query: searchText))
        return DatabaseManager.buildAlphabetSections(from: groups)
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
            .background(searchBarBackground)
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Grouping picker
            #if os(macOS)
            Picker("分组", selection: $grouping) {
                ForEach(SidebarGrouping.allCases) { g in
                    Text(g.label).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize()
            #else
            Picker("分组", selection: $grouping) {
                ForEach(SidebarGrouping.allCases) { g in
                    Text(g.label).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            #endif

            // Tree view
            switch grouping {
            case .dynasty:
                dynastyListView
            case .author:
                authorListView
            }
        }
    }

    @ViewBuilder
    private var dynastyListView: some View {
        if displayDynastyGroups.isEmpty {
            Spacer()
            Text("暂无诗词")
                .foregroundColor(.secondary)
            Spacer()
        } else {
            List(selection: $selectedPoem) {
                ForEach(displayDynastyGroups) { dynastyGroup in
                    Section {
                        DisclosureGroup(isExpanded: dynastyBinding(dynastyGroup.dynasty)) {
                            ForEach(dynastyGroup.authors) { authorGroup in
                                DisclosureGroup(isExpanded: authorBinding(dynastyGroup.dynasty, authorGroup.author)) {
                                    ForEach(authorGroup.poems) { poem in
                                        poemRow(poem)
                                    }
                                } label: {
                                    Text(authorGroup.author)
                                        #if os(macOS)
                                        .font(.system(size: 15))
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            let key = "\(dynastyGroup.dynasty)|\(authorGroup.author)"
                                            if expandedAuthors.contains(key) {
                                                expandedAuthors.remove(key)
                                            } else {
                                                expandedAuthors.insert(key)
                                            }
                                        }
                                        #endif
                                }
                            }
                        } label: {
                            Text(dynastyGroup.dynasty)
                                #if os(macOS)
                                .font(.system(size: 16, weight: .medium))
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    if expandedDynasties.contains(dynastyGroup.dynasty) {
                                        expandedDynasties.remove(dynastyGroup.dynasty)
                                    } else {
                                        expandedDynasties.insert(dynastyGroup.dynasty)
                                    }
                                }
                                #endif
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var authorListView: some View {
        if displayAlphabetSections.isEmpty {
            Spacer()
            Text("暂无诗词")
                .foregroundColor(.secondary)
            Spacer()
        } else {
            List(selection: $selectedPoem) {
                ForEach(displayAlphabetSections) { section in
                    Section(header: Text(section.letter)) {
                        ForEach(section.authors) { authorGroup in
                            DisclosureGroup(isExpanded: authorBinding("_alpha", authorGroup.author)) {
                                ForEach(authorGroup.poems) { poem in
                                    poemRow(poem)
                                }
                            } label: {
                                Text(authorGroup.author)
                                    #if os(macOS)
                                    .font(.system(size: 15))
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        let key = "_alpha|\(authorGroup.author)"
                                        if expandedAuthors.contains(key) {
                                            expandedAuthors.remove(key)
                                        } else {
                                            expandedAuthors.insert(key)
                                        }
                                    }
                                    #endif
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func poemRow(_ poem: Poem) -> some View {
        Text(poem.title)
            #if os(macOS)
            .font(.system(size: 14))
            #endif
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

    private func dynastyBinding(_ dynasty: String) -> Binding<Bool> {
        Binding(
            get: { expandedDynasties.contains(dynasty) },
            set: { isExpanded in
                if isExpanded { expandedDynasties.insert(dynasty) }
                else { expandedDynasties.remove(dynasty) }
            }
        )
    }

    private func authorBinding(_ prefix: String, _ author: String) -> Binding<Bool> {
        let key = "\(prefix)|\(author)"
        return Binding(
            get: { expandedAuthors.contains(key) },
            set: { isExpanded in
                if isExpanded { expandedAuthors.insert(key) }
                else { expandedAuthors.remove(key) }
            }
        )
    }

    private func buildDynastyGroups(from poems: [Poem]) -> [DynastyGroup] {
        var dynastyDict: [String: [String: [Poem]]] = [:]
        for poem in poems {
            dynastyDict[poem.dynasty, default: [:]][poem.author, default: []].append(poem)
        }
        return dynastyDict.keys.sorted {
            DatabaseManager.dynastySortKey($0) < DatabaseManager.dynastySortKey($1)
        }.map { dynasty in
            let authorDict = dynastyDict[dynasty]!
            let authors = authorDict.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { author in
                AuthorGroup(author: author, poems: authorDict[author]!.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
            }
            return DynastyGroup(dynasty: dynasty, authors: authors)
        }
    }

    private func buildAuthorGroups(from poems: [Poem]) -> [AuthorTopGroup] {
        var authorDict: [String: [Poem]] = [:]
        for poem in poems {
            authorDict[poem.author, default: []].append(poem)
        }
        return authorDict.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { author in
            AuthorTopGroup(author: author, poems: authorDict[author]!.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        }
    }
}
