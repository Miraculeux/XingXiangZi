import Foundation

struct Library: Identifiable, Hashable {
    let id: String          // unique key, also used as table name
    let name: String        // display name
    let sqlResource: String? // bundle SQL file name (without extension), nil = uses seed.sqlite3
    let isEditable: Bool    // only "My" allows add/edit/delete

    static let allLibraries: [Library] = [
        Library(id: "poems", name: "My", sqlResource: nil, isEditable: true),
        Library(id: "song300", name: "宋词三百首", sqlResource: "seed2", isEditable: false),
    ]

    static let defaultLibrary = allLibraries[0]
}
