import SwiftUI

struct MenuSidebarView: View {
    @ObservedObject var dbManager: DatabaseManager
    @Binding var selectedPoem: Poem?
    @Binding var showingCiPaiList: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 词牌 section
                Section("词牌") {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingCiPaiList = true
                        }
                    } label: {
                        Label("词牌", systemImage: "text.book.closed")
                    }
                }

                // Library section
                Section("词库") {
                    ForEach(Library.allLibraries) { lib in
                        Button {
                            if dbManager.currentLibrary != lib {
                                selectedPoem = nil
                                dbManager.switchLibrary(lib)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Label(lib.name, systemImage: "books.vertical")
                                Spacer()
                                if dbManager.currentLibrary == lib {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("菜单")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}
