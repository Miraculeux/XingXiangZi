import AVFoundation
import SwiftUI

struct PoemDetailView: View {
    let poem: Poem
    var onEdit: (() -> Void)?

    @State private var isSpeaking = false
    @StateObject private var speaker = PoemSpeaker()

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

                    Button {
                        if speaker.isSpeaking {
                            speaker.stop()
                        } else {
                            let text = "\(poem.title)。\(poem.author)。\(poem.content)"
                            speaker.speak(text)
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
        .onDisappear {
            speaker.stop()
        }
    }
}

final class PoemSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
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
