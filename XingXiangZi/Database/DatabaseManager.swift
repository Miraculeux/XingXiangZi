import Foundation
import SQLite3

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    @Published var poems: [Poem] = []
    @Published var dynastyGroups: [DynastyGroup] = []

    private init() {
        openDatabase()
        createTable()
        loadPoems()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fileURL = DatabaseManager.databaseURL()
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private static func databaseURL() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("xingxiangzi.sqlite")
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS poems (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                dynasty TEXT NOT NULL,
                content TEXT NOT NULL
            );
            """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
            print("Failed to create table: \(msg)")
            sqlite3_free(errMsg)
        }
    }

    // MARK: - CRUD

    func addPoem(_ poem: Poem) {
        let sql = "INSERT INTO poems (title, author, dynasty, content) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("Failed to prepare insert: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (poem.title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (poem.author as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (poem.dynasty as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (poem.content as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) != SQLITE_DONE {
            print("Failed to insert poem: \(String(cString: sqlite3_errmsg(db)))")
        }
        loadPoems()
    }

    func deletePoem(id: Int64) {
        let sql = "DELETE FROM poems WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
        loadPoems()
    }

    func updatePoem(_ poem: Poem) {
        let sql = "UPDATE poems SET title = ?, author = ?, dynasty = ?, content = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (poem.title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (poem.author as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (poem.dynasty as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (poem.content as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(stmt, 5, poem.id)

        sqlite3_step(stmt)
        loadPoems()
    }

    // MARK: - Query

    func loadPoems() {
        poems = fetchPoems(sql: "SELECT id, title, author, dynasty, content FROM poems ORDER BY dynasty, author, title;")
        buildGroups()
    }

    func search(query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        let sql = """
            SELECT id, title, author, dynasty, content FROM poems
            WHERE title LIKE ? OR author LIKE ? OR dynasty LIKE ?
            ORDER BY dynasty, author, title;
            """
        let wildcard = "%\(query)%"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (wildcard as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (wildcard as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (wildcard as NSString).utf8String, -1, nil)

        var results: [Poem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readPoem(from: stmt))
        }
        return results
    }

    // MARK: - Helpers

    private func fetchPoems(sql: String) -> [Poem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [Poem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readPoem(from: stmt))
        }
        return results
    }

    private func readPoem(from stmt: OpaquePointer?) -> Poem {
        let id = sqlite3_column_int64(stmt, 0)
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let author = String(cString: sqlite3_column_text(stmt, 2))
        let dynasty = String(cString: sqlite3_column_text(stmt, 3))
        let content = String(cString: sqlite3_column_text(stmt, 4))
        return Poem(id: id, title: title, author: author, dynasty: dynasty, content: content)
    }

    private func buildGroups() {
        var dynastyDict: [String: [String: [Poem]]] = [:]
        for poem in poems {
            dynastyDict[poem.dynasty, default: [:]][poem.author, default: []].append(poem)
        }
        dynastyGroups = dynastyDict.keys.sorted().map { dynasty in
            let authorDict = dynastyDict[dynasty]!
            let authors = authorDict.keys.sorted().map { author in
                AuthorGroup(author: author, poems: authorDict[author]!)
            }
            return DynastyGroup(dynasty: dynasty, authors: authors)
        }
    }
}
