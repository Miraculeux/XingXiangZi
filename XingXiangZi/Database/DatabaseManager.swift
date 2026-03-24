import Foundation
import SQLite3

final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?

    @Published var poems: [Poem] = []
    @Published var dynastyGroups: [DynastyGroup] = []
    @Published var authorTopGroups: [AuthorTopGroup] = []
    @Published var alphabetAuthorSections: [AlphabetAuthorSection] = []
    @Published var cipaiList: [CiPai] = []
    @Published var currentLibrary: Library = Library.defaultLibrary

    /// Current library's table name
    private var table: String { currentLibrary.id }

    private init() {
        seedIfNeeded()
        openDatabase()
        createTable()
        seedLibrariesIfNeeded()
        createCiPaiTable()
        seedCiPaiIfNeeded()
        loadPoems()
        loadCiPaiList()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private static let seedVersionKey = "DatabaseSeedVersion"
    private static let currentSeedVersion = 2

    /// Import seed poems into the database if not already done.
    private func seedIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: DatabaseManager.seedVersionKey) >= DatabaseManager.currentSeedVersion {
            return
        }

        let destURL = DatabaseManager.databaseURL()

        if !FileManager.default.fileExists(atPath: destURL.path) {
            // No database yet — just copy the bundled one
            if let bundledURL = Bundle.main.url(forResource: "seed", withExtension: "sqlite3") {
                try? FileManager.default.copyItem(at: bundledURL, to: destURL)
            }
        } else {
            // Database exists (may have user data) — merge seed poems into it
            importSeedPoems(into: destURL)
        }

        defaults.set(DatabaseManager.currentSeedVersion, forKey: DatabaseManager.seedVersionKey)
    }

    /// Import poems from the bundled seed database into the existing user database.
    private func importSeedPoems(into destURL: URL) {
        guard let bundledURL = Bundle.main.url(forResource: "seed", withExtension: "sqlite3") else { return }

        var destDb: OpaquePointer?
        guard sqlite3_open(destURL.path, &destDb) == SQLITE_OK else { return }
        defer { sqlite3_close(destDb) }

        // Ensure table exists
        let createSQL = "CREATE TABLE IF NOT EXISTS poems (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, author TEXT NOT NULL, dynasty TEXT NOT NULL, content TEXT NOT NULL);"
        sqlite3_exec(destDb, createSQL, nil, nil, nil)

        // Attach the seed database
        var errMsg: UnsafeMutablePointer<CChar>?
        let attachSQL = "ATTACH DATABASE '\(bundledURL.path)' AS seed;"
        guard sqlite3_exec(destDb, attachSQL, nil, nil, &errMsg) == SQLITE_OK else {
            if let errMsg { sqlite3_free(errMsg) }
            return
        }

        // Insert seed poems that don't already exist (by title + author)
        let insertSQL = """
            INSERT INTO poems (title, author, dynasty, content)
            SELECT s.title, s.author, s.dynasty, s.content
            FROM seed.poems s
            WHERE NOT EXISTS (
                SELECT 1 FROM poems p WHERE p.title = s.title AND p.author = s.author
            );
            """
        sqlite3_exec(destDb, insertSQL, nil, nil, nil)
        sqlite3_exec(destDb, "DETACH DATABASE seed;", nil, nil, nil)
    }

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

    // MARK: - Library Seeding

    private static let librarySeedVersionKey = "LibrarySeedVersion"
    private static let currentLibrarySeedVersion = 1

    private func seedLibrariesIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: DatabaseManager.librarySeedVersionKey) >= DatabaseManager.currentLibrarySeedVersion {
            return
        }

        for lib in Library.allLibraries {
            guard let resource = lib.sqlResource else { continue }
            seedLibraryFromSQL(library: lib, resource: resource)
        }

        defaults.set(DatabaseManager.currentLibrarySeedVersion, forKey: DatabaseManager.librarySeedVersionKey)
    }

    private func seedLibraryFromSQL(library: Library, resource: String) {
        guard let sqlURL = Bundle.main.url(forResource: resource, withExtension: "sql"),
              let sqlContent = try? String(contentsOf: sqlURL, encoding: .utf8) else { return }

        // Ensure the table exists with the standard poem schema
        let createSQL = """
            CREATE TABLE IF NOT EXISTS \(library.id) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                dynasty TEXT NOT NULL,
                content TEXT NOT NULL
            );
            """
        sqlite3_exec(db, createSQL, nil, nil, nil)

        // Check if already populated
        var countStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(library.id);", -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW && sqlite3_column_int(countStmt, 0) > 0 {
                sqlite3_finalize(countStmt)
                return
            }
        }
        sqlite3_finalize(countStmt)

        // Execute INSERT statements, rewriting table name to library.id
        let statements = sqlContent.components(separatedBy: ";\n").filter { $0.contains("INSERT") }
        for statement in statements {
            let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, trimmed + ";", nil, nil, &errMsg) != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
                print("Failed to seed library \(library.name): \(msg)")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Library Switching

    func switchLibrary(_ library: Library) {
        currentLibrary = library
        loadPoems()
    }

    // MARK: - CRUD

    func addPoem(_ poem: Poem) {
        guard currentLibrary.isEditable else { return }
        let sql = "INSERT INTO \(table) (title, author, dynasty, content) VALUES (?, ?, ?, ?);"
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
        guard currentLibrary.isEditable else { return }
        let sql = "DELETE FROM \(table) WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
        loadPoems()
    }

    func updatePoem(_ poem: Poem) {
        guard currentLibrary.isEditable else { return }
        let sql = "UPDATE \(table) SET title = ?, author = ?, dynasty = ?, content = ? WHERE id = ?;"
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
        poems = fetchPoems(sql: "SELECT id, title, author, dynasty, content FROM \(table) ORDER BY dynasty, author, title;")
        buildGroups()
    }

    func search(query: String) -> [Poem] {
        guard !query.isEmpty else { return poems }
        let sql = """
            SELECT id, title, author, dynasty, content FROM \(table)
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

    static let dynastyList: [(Int, [String])] = [
        (0,  ["先秦"]),
        (1,  ["秦"]),
        (2,  ["汉", "漢"]),
        (3,  ["西汉", "西漢"]),
        (4,  ["东汉", "東漢"]),
        (5,  ["三国", "三國"]),
        (6,  ["魏"]),
        (7,  ["蜀"]),
        (8,  ["吴", "吳"]),
        (9,  ["晋", "晉"]),
        (10, ["西晋", "西晉"]),
        (11, ["东晋", "東晉"]),
        (12, ["南北朝"]),
        (13, ["南朝"]),
        (14, ["北朝"]),
        (15, ["隋"]),
        (16, ["唐"]),
        (17, ["五代"]),
        (18, ["五代十国", "五代十國"]),
        (19, ["北宋"]),
        (20, ["南宋"]),
        (21, ["辽", "遼"]),
        (22, ["金"]),
        (23, ["元"]),
        (24, ["明"]),
        (25, ["清"]),
        (26, ["近代"]),
        (27, ["近现代", "近現代"]),
        (28, ["现代", "現代"]),
        (29, ["当代", "當代"])
    ]

    /// Traditional Chinese dynasty names for use in pickers, in chronological order.
    /// For each group, the last name is the traditional form.
    static let dynastyNames: [String] = dynastyList.map { $0.1.last! }

    /// Maps any dynasty name (simplified or traditional) to its traditional form.
    static let dynastyToTraditional: [String: String] = {
        var dict: [String: String] = [:]
        for (_, names) in dynastyList {
            let traditional = names.last!
            for name in names {
                dict[name] = traditional
            }
        }
        return dict
    }()

    private static let dynastyOrder: [String: Int] = {
        var dict: [String: Int] = [:]
        for (order, names) in dynastyList {
            for name in names {
                dict[name] = order
            }
        }
        return dict
    }()

    static func dynastySortKey(_ dynasty: String) -> (Int, String) {
        if let order = dynastyOrder[dynasty] {
            return (order, dynasty)
        }
        return (Int.max, dynasty)
    }

    private func buildGroups() {
        var dynastyDict: [String: [String: [Poem]]] = [:]
        for poem in poems {
            dynastyDict[poem.dynasty, default: [:]][poem.author, default: []].append(poem)
        }
        dynastyGroups = dynastyDict.keys.sorted {
            DatabaseManager.dynastySortKey($0) < DatabaseManager.dynastySortKey($1)
        }.map { dynasty in
            let authorDict = dynastyDict[dynasty]!
            let authors = authorDict.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { author in
                AuthorGroup(author: author, poems: authorDict[author]!.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
            }
            return DynastyGroup(dynasty: dynasty, authors: authors)
        }

        var authorDict: [String: [Poem]] = [:]
        for poem in poems {
            authorDict[poem.author, default: []].append(poem)
        }
        authorTopGroups = authorDict.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { author in
            AuthorTopGroup(author: author, poems: authorDict[author]!.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        }
        alphabetAuthorSections = DatabaseManager.buildAlphabetSections(from: authorTopGroups)
    }

    static func pinyinFirstLetter(of text: String) -> String {
        guard let first = text.first else { return "#" }
        let str = NSMutableString(string: String(first))
        CFStringTransform(str, nil, kCFStringTransformToLatin, false)
        CFStringTransform(str, nil, kCFStringTransformStripDiacritics, false)
        let letter = (str as String).prefix(1).uppercased()
        return letter.first?.isLetter == true ? letter : "#"
    }

    static func buildAlphabetSections(from groups: [AuthorTopGroup]) -> [AlphabetAuthorSection] {
        var dict: [String: [AuthorTopGroup]] = [:]
        for group in groups {
            let letter = pinyinFirstLetter(of: group.author)
            dict[letter, default: []].append(group)
        }
        return dict.keys.sorted().map { letter in
            AlphabetAuthorSection(letter: letter, authors: dict[letter]!)
        }
    }

    // MARK: - CiPai

    private static let cipaiSeedVersionKey = "CiPaiSeedVersion"
    private static let currentCiPaiSeedVersion = 2

    private func createCiPaiTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS cipai (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                name_tc TEXT,
                aliases TEXT,
                intro TEXT,
                pattern TEXT,
                section_count INTEGER,
                char_count INTEGER,
                example TEXT
            );
            """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
            print("Failed to create cipai table: \(msg)")
            sqlite3_free(errMsg)
        }
    }

    private func seedCiPaiIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: DatabaseManager.cipaiSeedVersionKey) >= DatabaseManager.currentCiPaiSeedVersion {
            return
        }

        // Drop and recreate to handle schema changes (cipai data is read-only seed data)
        sqlite3_exec(db, "DROP TABLE IF EXISTS cipai;", nil, nil, nil)
        createCiPaiTable()

        guard let sqlURL = Bundle.main.url(forResource: "seed_cipai", withExtension: "sql"),
              let sqlContent = try? String(contentsOf: sqlURL, encoding: .utf8) else { return }

        // Execute the SQL statements (skip CREATE TABLE since we already have it)
        let statements = sqlContent.components(separatedBy: ";\n").filter { $0.contains("INSERT") }
        for statement in statements {
            let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, trimmed + ";", nil, nil, &errMsg) != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
                print("Failed to seed cipai: \(msg)")
                sqlite3_free(errMsg)
            }
        }

        defaults.set(DatabaseManager.currentCiPaiSeedVersion, forKey: DatabaseManager.cipaiSeedVersionKey)
    }

    func loadCiPaiList() {
        cipaiList = fetchCiPai(sql: "SELECT id, name, name_tc, aliases, intro, pattern, section_count, char_count, example FROM cipai ORDER BY name;")
    }

    func searchCiPai(query: String) -> [CiPai] {
        guard !query.isEmpty else { return cipaiList }
        let sql = """
            SELECT id, name, name_tc, aliases, intro, pattern, section_count, char_count, example FROM cipai
            WHERE name LIKE ? OR name_tc LIKE ? OR aliases LIKE ? OR intro LIKE ?
            ORDER BY name;
            """
        let wildcard = "%\(query)%"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (wildcard as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (wildcard as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (wildcard as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (wildcard as NSString).utf8String, -1, nil)

        var results: [CiPai] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readCiPai(from: stmt))
        }
        return results
    }

    func findCiPai(byName name: String) -> CiPai? {
        let sql = """
            SELECT id, name, name_tc, aliases, intro, pattern, section_count, char_count, example FROM cipai
            WHERE name = ? OR name_tc = ? OR (',' || aliases || ',') LIKE ('%,' || ? || ',%')
            LIMIT 1;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return readCiPai(from: stmt)
        }
        return nil
    }

    private func fetchCiPai(sql: String) -> [CiPai] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [CiPai] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(readCiPai(from: stmt))
        }
        return results
    }

    private func readCiPai(from stmt: OpaquePointer?) -> CiPai {
        let id = sqlite3_column_int64(stmt, 0)
        let name = String(cString: sqlite3_column_text(stmt, 1))
        let nameTc = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
        let aliases = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let intro = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let pattern = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let sectionCount = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 6)) : nil
        let charCount = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 7)) : nil
        let example = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        return CiPai(id: id, name: name, nameTc: nameTc, aliases: aliases, intro: intro, pattern: pattern, sectionCount: sectionCount, charCount: charCount, example: example)
    }
}
