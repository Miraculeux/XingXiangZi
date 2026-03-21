import AVFoundation
import SwiftUI

struct PoemDetailView: View {
    let poem: Poem
    let poems: [Poem]
    var onEdit: (() -> Void)?
    var onNavigate: ((Poem) -> Void)?

    @StateObject private var speaker = PoemSpeaker()
    @State private var selectedLanguage: SpeechLanguage = .cantonese

    private var currentIndex: Int? {
        poems.firstIndex(of: poem)
    }

    private var previousPoem: Poem? {
        guard let idx = currentIndex, idx > 0 else { return nil }
        return poems[idx - 1]
    }

    private var nextPoem: Poem? {
        guard let idx = currentIndex, idx < poems.count - 1 else { return nil }
        return poems[idx + 1]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text(poem.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Author and dynasty
                HStack(spacing: 4) {
                    Text("【\(poem.dynasty)】")
                        .foregroundColor(.secondary)
                    Text(poem.author)
                        .foregroundColor(.secondary)
                }
                .font(.title3)

                // Action icons
                HStack(spacing: 24) {
                    Button {
                        onEdit?()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)

                    Picker("", selection: $selectedLanguage) {
                        ForEach(SpeechLanguage.allCases) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()

                    Button {
                        if speaker.isSpeaking {
                            speaker.stop()
                        } else {
                            let text = "\(poem.title)。\(poem.author)。\(poem.content)"
                            speaker.speak(text, language: selectedLanguage)
                        }
                    } label: {
                        Image(systemName: speaker.isSpeaking ? "stop.circle" : "play.circle")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.horizontal, 40)

                // Content
                Text(poem.content)
                    .font(.title3)
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 40)
            .padding(.horizontal)
        }
        .navigationTitle(poem.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    if let prev = previousPoem {
                        speaker.stop()
                        onNavigate?(prev)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(previousPoem == nil)

                Button {
                    if let next = nextPoem {
                        speaker.stop()
                        onNavigate?(next)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(nextPoem == nil)
            }
        }
        .onDisappear {
            speaker.stop()
        }
    }
}

enum SpeechLanguage: String, CaseIterable, Identifiable {
    case cantonese = "zh-HK"
    case mandarin = "zh-CN"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cantonese: return "粤语"
        case .mandarin: return "普通话"
        }
    }
}

final class PoemSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private nonisolated(unsafe) let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: SpeechLanguage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
