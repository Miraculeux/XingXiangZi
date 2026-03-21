import Foundation

struct Poem: Identifiable, Hashable {
    let id: Int64
    var title: String
    var author: String
    var dynasty: String
    var content: String

    init(id: Int64 = 0, title: String, author: String, dynasty: String, content: String) {
        self.id = id
        self.title = title
        self.author = author
        self.dynasty = dynasty
        self.content = content
    }
}

/// Grouped structure for tree view: Dynasty -> Author -> [Poem]
struct DynastyGroup: Identifiable {
    let id = UUID()
    let dynasty: String
    var authors: [AuthorGroup]
}

struct AuthorGroup: Identifiable {
    let id = UUID()
    let author: String
    var poems: [Poem]
}
