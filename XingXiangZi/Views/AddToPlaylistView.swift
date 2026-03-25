import SwiftUI

struct AddToPlaylistView: View {
    @ObservedObject var dbManager: DatabaseManager
    let poem: Poem
    let libraryId: String
    @Environment(\.dismiss) private var dismiss
    @State private var newPlaylistName = ""
    @State private var showingNewPlaylist = false
    @State private var containingPlaylistIds: Set<Int64> = []

    private func refreshContaining() {
        containingPlaylistIds = Set(dbManager.playlistsContainingPoem(poemId: poem.id, libraryId: libraryId))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingNewPlaylist = true
                    } label: {
                        Label("新建播放列表", systemImage: "plus")
                    }
                }

                Section("播放列表") {
                    if dbManager.playlists.isEmpty {
                        Text("暂无播放列表")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(dbManager.playlists) { playlist in
                            let isInPlaylist = containingPlaylistIds.contains(playlist.id)
                            Button {
                                if isInPlaylist {
                                    dbManager.removePoemFromPlaylist(playlistId: playlist.id, poemId: poem.id, libraryId: libraryId)
                                } else {
                                    dbManager.addPoemToPlaylist(playlistId: playlist.id, poemId: poem.id, libraryId: libraryId)
                                }
                                refreshContaining()
                            } label: {
                                HStack {
                                    Text(playlist.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if isInPlaylist {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加到播放列表")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshContaining()
            }
            .alert("新建播放列表", isPresented: $showingNewPlaylist) {
                TextField("名称", text: $newPlaylistName)
                Button("取消", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("创建") {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        if let playlist = dbManager.createPlaylist(name: name) {
                            dbManager.addPoemToPlaylist(playlistId: playlist.id, poemId: poem.id, libraryId: libraryId)
                            refreshContaining()
                        }
                    }
                    newPlaylistName = ""
                }
            } message: {
                Text("请输入播放列表名称")
            }
        }
    }
}
