import SwiftUI
import UIKit

/// A UIKit-based left-edge swipe recognizer that works alongside List/ScrollView gestures
private struct EdgeSwipeModifier: ViewModifier {
    var onSwipe: () -> Void

    func body(content: Content) -> some View {
        content.overlay(
            EdgeSwipeView(onSwipe: onSwipe)
                .frame(width: 30)
                .frame(maxHeight: .infinity)
                .allowsHitTesting(true),
            alignment: .leading
        )
    }
}

private struct EdgeSwipeView: UIViewRepresentable {
    var onSwipe: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let gesture = UIScreenEdgePanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        gesture.edges = .left
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSwipe = onSwipe
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipe: onSwipe)
    }

    class Coordinator: NSObject {
        var onSwipe: () -> Void

        init(onSwipe: @escaping () -> Void) {
            self.onSwipe = onSwipe
        }

        @objc func handleSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
            if gesture.state == .ended {
                let translation = gesture.translation(in: gesture.view)
                if translation.x > 80 {
                    onSwipe()
                }
            }
        }
    }
}

extension View {
    func edgeSwipeBack(action: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeModifier(onSwipe: action))
    }
}

struct PlaylistListView: View {
    @ObservedObject var dbManager: DatabaseManager
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var editingPlaylist: Playlist?
    @State private var editPlaylistName = ""

    var body: some View {
        List {
            if dbManager.playlists.isEmpty {
                Text("暂无播放列表")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dbManager.playlists) { playlist in
                    NavigationLink(value: playlist) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.name)
                                .font(.body)
                            Text("\(dbManager.poemsInPlaylist(playlist.id).count) 首")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button {
                            editPlaylistName = playlist.name
                            editingPlaylist = playlist
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            dbManager.deletePlaylist(id: playlist.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        dbManager.deletePlaylist(id: dbManager.playlists[index].id)
                    }
                }
            }
        }
        .navigationTitle("播放列表")
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(dbManager: dbManager, playlist: playlist)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewPlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("新建播放列表", isPresented: $showingNewPlaylist) {
            TextField("名称", text: $newPlaylistName)
            Button("取消", role: .cancel) {
                newPlaylistName = ""
            }
            Button("创建") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    _ = dbManager.createPlaylist(name: name)
                }
                newPlaylistName = ""
            }
        } message: {
            Text("请输入播放列表名称")
        }
        .alert("重命名播放列表", isPresented: Binding(
            get: { editingPlaylist != nil },
            set: { if !$0 { editingPlaylist = nil } }
        )) {
            TextField("名称", text: $editPlaylistName)
            Button("取消", role: .cancel) {
                editingPlaylist = nil
                editPlaylistName = ""
            }
            Button("保存") {
                let name = editPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, let playlist = editingPlaylist {
                    dbManager.renamePlaylist(id: playlist.id, newName: name)
                }
                editingPlaylist = nil
                editPlaylistName = ""
            }
        } message: {
            Text("请输入新的名称")
        }
    }
}

struct PlaylistDetailView: View {
    @ObservedObject var dbManager: DatabaseManager
    let playlist: Playlist
    var onDismiss: (() -> Void)?
    @State private var poems: [Poem] = []
    @State private var selectedPoem: Poem?
    @State private var autoPlay = false
    @State private var navigatingViaAutoPlay = false
    @State private var playbackMode: PlaybackMode = .single
    @State private var selectedLanguage: SpeechLanguage = .cantonese
    @State private var showingDeleteConfirm = false
    @StateObject private var speaker = PoemSpeaker()

    var body: some View {
        Group {
        if let poem = selectedPoem {
            PoemDetailView(poem: poem, poems: poems, autoPlay: autoPlay, playbackMode: $playbackMode, selectedLanguage: $selectedLanguage, speaker: speaker, onEdit: nil, onNavigate: { newPoem, shouldAutoPlay in
                navigatingViaAutoPlay = shouldAutoPlay
                autoPlay = shouldAutoPlay
                selectedPoem = newPoem
            }, showNavigationButtons: false)
            .id(poem.id)
            .edgeSwipeBack {
                speaker.stop()
                selectedPoem = nil
            }
            .onChange(of: selectedPoem) {
                if navigatingViaAutoPlay {
                    navigatingViaAutoPlay = false
                } else {
                    autoPlay = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        speaker.stop()
                        selectedPoem = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(playlist.name)
                        }
                    }
                }
            }
        } else {
            List {
                if poems.isEmpty {
                    Text("播放列表为空")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(poems) { poem in
                        Button {
                            selectedPoem = poem
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(poem.title)
                                    .font(.body)
                                HStack(spacing: 4) {
                                    Text("【\(poem.dynasty)】")
                                    Text(poem.author)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                        .contextMenu {
                            Button(role: .destructive) {
                                let libraryId = findLibraryId(for: poem)
                                dbManager.removePoemFromPlaylist(playlistId: playlist.id, poemId: poem.id, libraryId: libraryId)
                                poems = dbManager.poemsInPlaylist(playlist.id)
                            } label: {
                                Label("从列表移除", systemImage: "minus.circle")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let poem = poems[index]
                            let libraryId = findLibraryId(for: poem)
                            dbManager.removePoemFromPlaylist(playlistId: playlist.id, poemId: poem.id, libraryId: libraryId)
                        }
                        poems = dbManager.poemsInPlaylist(playlist.id)
                    }
                }
            }
            .navigationTitle(playlist.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        speaker.stop()
                        onDismiss?()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            if let first = poems.first {
                                autoPlay = true
                                playbackMode = .next
                                selectedPoem = first
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(poems.isEmpty)

                        Button {
                            if let first = poems.first {
                                autoPlay = true
                                playbackMode = .loopAll
                                selectedPoem = first
                            }
                        } label: {
                            Image(systemName: "repeat")
                                .foregroundColor(.orange)
                        }
                        .disabled(poems.isEmpty)

                        Rectangle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 1, height: 18)

                        Button {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .alert("确认删除", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    speaker.stop()
                    dbManager.deletePlaylist(id: playlist.id)
                    onDismiss?()
                }
            } message: {
                Text("确定要删除播放列表「\(playlist.name)」吗？")
            }
            .onAppear {
                poems = dbManager.poemsInPlaylist(playlist.id)
            }
            .edgeSwipeBack {
                speaker.stop()
                onDismiss?()
            }
        }
        }
        .onDisappear {
            speaker.stop()
        }
    }

    /// Determine which library a poem belongs to by checking playlist_entries
    private func findLibraryId(for poem: Poem) -> String {
        let entries = dbManager.playlistsContainingPoem(poemId: poem.id, libraryId: dbManager.currentLibrary.id)
        if entries.contains(playlist.id) {
            return dbManager.currentLibrary.id
        }
        // Fallback: check all libraries
        for lib in Library.allLibraries {
            let entries = dbManager.playlistsContainingPoem(poemId: poem.id, libraryId: lib.id)
            if entries.contains(playlist.id) {
                return lib.id
            }
        }
        return dbManager.currentLibrary.id
    }
}
