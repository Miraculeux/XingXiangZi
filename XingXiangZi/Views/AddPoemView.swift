import SwiftUI

struct AddPoemView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var dynasty = ""
    @State private var content = ""

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !author.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dynasty.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    TextField("作者", text: $author)
                    TextField("朝代", text: $dynasty)
                }

                Section("诗词内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("添加诗词")
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
                        let poem = Poem(
                            title: title.trimmingCharacters(in: .whitespaces),
                            author: author.trimmingCharacters(in: .whitespaces),
                            dynasty: dynasty.trimmingCharacters(in: .whitespaces),
                            content: content.trimmingCharacters(in: .whitespaces)
                        )
                        dbManager.addPoem(poem)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
