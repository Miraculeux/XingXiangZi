import SwiftUI

struct EditPoemView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let poem: Poem

    @State private var title: String
    @State private var author: String
    @State private var dynasty: String
    @State private var content: String

    init(dbManager: DatabaseManager, poem: Poem) {
        self.dbManager = dbManager
        self.poem = poem
        _title = State(initialValue: poem.title)
        _author = State(initialValue: poem.author)
        _dynasty = State(initialValue: poem.dynasty)
        _content = State(initialValue: poem.content)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !author.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dynasty.isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    TextField("作者", text: $author)
                    Picker("朝代", selection: $dynasty) {
                        ForEach(DatabaseManager.dynastyList, id: \.self) { d in
                            Text(d).tag(d)
                        }
                    }
                }

                Section("诗词内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("编辑诗词")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updated = Poem(
                            id: poem.id,
                            title: title.trimmingCharacters(in: .whitespaces),
                            author: author.trimmingCharacters(in: .whitespaces),
                            dynasty: dynasty.trimmingCharacters(in: .whitespaces),
                            content: content.trimmingCharacters(in: .whitespaces)
                        )
                        dbManager.updatePoem(updated)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
