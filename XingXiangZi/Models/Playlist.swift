import Foundation

struct Playlist: Identifiable, Hashable {
    let id: Int64
    var name: String
    var createdAt: String

    init(id: Int64 = 0, name: String, createdAt: String = "") {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct PlaylistEntry: Identifiable {
    let id: Int64
    let playlistId: Int64
    let poemId: Int64
    let libraryId: String
    let sortOrder: Int
}
