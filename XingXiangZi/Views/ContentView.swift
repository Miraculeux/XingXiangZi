import SwiftUI

struct ContentView: View {
    @StateObject private var dbManager = DatabaseManager.shared
    @State private var selectedPoem: Poem?
    @State private var showingAddPoem = false
    @State private var showingEditPoem = false
    @State private var searchText = ""

    @State private var autoPlay = false
    @State private var playbackMode: PlaybackMode = .single
    @State private var selectedLanguage: SpeechLanguage = .cantonese

    var body: some View {
        NavigationSplitView {
            SidebarView(
                dbManager: dbManager,
                selectedPoem: $selectedPoem,
                searchText: $searchText
            )
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPoem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationTitle("行香子")
        } detail: {
            if let poem = selectedPoem {
                PoemDetailView(poem: poem, poems: dbManager.poems, autoPlay: autoPlay, playbackMode: $playbackMode, selectedLanguage: $selectedLanguage, onEdit: {
                    showingEditPoem = true
                }, onNavigate: { newPoem, shouldAutoPlay in
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
    }
}
