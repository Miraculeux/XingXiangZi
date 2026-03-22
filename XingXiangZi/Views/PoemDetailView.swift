import AVFoundation
import MediaPlayer
import SwiftUI

struct PoemDetailView: View {
    let poem: Poem
    let poems: [Poem]
    var autoPlay: Bool = false
    @Binding var playbackMode: PlaybackMode
    @Binding var selectedLanguage: SpeechLanguage
    var onEdit: (() -> Void)?
    var onNavigate: ((Poem, Bool) -> Void)?

    @StateObject private var speaker = PoemSpeaker()

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

                    Picker("", selection: $playbackMode) {
                        ForEach(PlaybackMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .labelStyle(.iconOnly)

                    Button {
                        if speaker.isSpeaking {
                            speaker.stop()
                        } else {
                            startSpeaking()
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
                        onNavigate?(prev, false)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(previousPoem == nil)

                Button {
                    if let next = nextPoem {
                        speaker.stop()
                        onNavigate?(next, false)
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
        .onAppear {
            if autoPlay {
                startSpeaking()
            }
        }
    }

    private func startSpeaking() {
        let text = "\(poem.title)。\(poem.author)。\(poem.content)"
        speaker.speak(text, language: selectedLanguage) {
            switch self.playbackMode {
            case .single:
                break
            case .repeatOne:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.startSpeaking()
                }
            case .next:
                if let next = self.nextPoem {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.onNavigate?(next, true)
                    }
                }
            }
        }
    }
}

enum PlaybackMode: String, CaseIterable, Identifiable {
    case single
    case repeatOne
    case next

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: return "播完停止"
        case .repeatOne: return "單首循環"
        case .next: return "播完下一首"
        }
    }

    var icon: String {
        switch self {
        case .single: return "play.fill"
        case .repeatOne: return "repeat.1"
        case .next: return "forward.fill"
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
    private var onFinish: (() -> Void)?
    private var currentText: String?
    private var currentLanguage: SpeechLanguage?

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommands()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            if let self, let text = self.currentText, let lang = self.currentLanguage, !self.isSpeaking {
                self.speak(text, language: lang, onFinish: self.onFinish)
            }
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
    }

    private func updateNowPlaying(title: String) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPNowPlayingInfoPropertyPlaybackRate] = isSpeaking ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                setupAudioSession()
                if let text = currentText, let lang = currentLanguage {
                    speak(text, language: lang, onFinish: onFinish)
                }
            }
        }
    }

    func speak(_ text: String, language: SpeechLanguage, onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self.currentText = text
        self.currentLanguage = language
        setupAudioSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        synthesizer.speak(utterance)
        isSpeaking = true
        updateNowPlaying(title: String(text.prefix(20)))
    }

    func stop() {
        onFinish = nil
        currentText = nil
        currentLanguage = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.updateNowPlaying(title: "")
            self.onFinish?()
            self.onFinish = nil
        }
    }
}
