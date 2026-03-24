import SwiftUI

struct ContentView: View {
    @StateObject private var dbManager = DatabaseManager.shared
    @State private var selectedPoem: Poem?
    @State private var showingAddPoem = false
    @State private var showingEditPoem = false
    @State private var showingCiPaiList = false
    @State private var searchText = ""

    @State private var autoPlay = false
    @State private var navigatingViaAutoPlay = false
    @State private var playbackMode: PlaybackMode = .single
    @State private var selectedLanguage: SpeechLanguage = .cantonese
    @State private var sidebarGrouping: SidebarGrouping = .dynasty
    @StateObject private var speaker = PoemSpeaker()

    var body: some View {
        NavigationSplitView {
            SidebarView(
                dbManager: dbManager,
                selectedPoem: $selectedPoem,
                searchText: $searchText,
                grouping: $sidebarGrouping
            )
            .toolbar {
                //ToolbarItem(placement: .primaryAction) {
                //    Button {
                //        showingAddPoem = true
                //    } label: {
                //        Image(systemName: "plus")
                //    }
                //}
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Section("词牌") {
                            Button {
                                showingCiPaiList = true
                            } label: {
                                Label("词牌大全", systemImage: "text.book.closed")
                            }
                        }
                        Section("词库") {
                            ForEach(Library.allLibraries) { lib in
                                Button {
                                    if dbManager.currentLibrary != lib {
                                        selectedPoem = nil
                                        dbManager.switchLibrary(lib)
                                    }
                                } label: {
                                    if dbManager.currentLibrary == lib {
                                        Label(lib.name, systemImage: "checkmark")
                                    } else {
                                        Text(lib.name)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
            .navigationTitle(dbManager.currentLibrary.name)
        } detail: {
            if let poem = selectedPoem {
                PoemDetailView(poem: poem, poems: dbManager.poems, autoPlay: autoPlay, playbackMode: $playbackMode, selectedLanguage: $selectedLanguage, speaker: speaker, onEdit: {
                    showingEditPoem = true
                }, onNavigate: { newPoem, shouldAutoPlay in
                    navigatingViaAutoPlay = shouldAutoPlay
                    autoPlay = shouldAutoPlay
                    selectedPoem = newPoem
                })
                .id(poem.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("选择一首诗词")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: selectedPoem) {
            if navigatingViaAutoPlay {
                navigatingViaAutoPlay = false
            } else {
                autoPlay = false
            }
        }
        .sheet(isPresented: $showingAddPoem) {
            AddPoemView(dbManager: dbManager)
        }
        .sheet(isPresented: $showingEditPoem, onDismiss: {
            // Refresh selectedPoem from updated data
            if let current = selectedPoem,
               let updated = dbManager.poems.first(where: { $0.id == current.id }) {
                selectedPoem = updated
            }
        }) {
            if let poem = selectedPoem {
                EditPoemView(dbManager: dbManager, poem: poem)
            }
        }
        .sheet(isPresented: $showingCiPaiList) {
            NavigationStack {
                CiPaiListView(dbManager: dbManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") {
                                showingCiPaiList = false
                            }
                        }
                    }
            }
        }
    }
}
