import Foundation

struct CiPai: Identifiable, Hashable {
    let id: Int64
    var name: String
    var nameTc: String?
    var aliases: String?
    var intro: String?
    var pattern: String?
    var sectionCount: Int?
    var charCount: Int?
    var example: String?

    init(id: Int64 = 0, name: String, nameTc: String? = nil, aliases: String? = nil, intro: String? = nil, pattern: String? = nil, sectionCount: Int? = nil, charCount: Int? = nil, example: String? = nil) {
        self.id = id
        self.name = name
        self.nameTc = nameTc
        self.aliases = aliases
        self.intro = intro
        self.pattern = pattern
        self.sectionCount = sectionCount
        self.charCount = charCount
        self.example = example
    }
}
