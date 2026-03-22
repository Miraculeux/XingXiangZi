import AVFoundation
import MediaPlayer
import SwiftUI

struct PoemDetailView: View {
    let poem: Poem
    let poems: [Poem]
    var autoPlay: Bool = false
    @Binding var playbackMode: PlaybackMode
    @Binding var selectedLanguage: SpeechLanguage
    @ObservedObject var speaker: PoemSpeaker
    var onEdit: (() -> Void)?
    var onNavigate: ((Poem, Bool) -> Void)?

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
                HighlightedPoemText(
                    content: poem.content,
                    speaker: speaker
                )
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
        let prefix = "\(poem.title)。\(poem.author)。"
        let text = prefix + poem.content
        speaker.speak(text, language: selectedLanguage, contentOffset: prefix.count, title: poem.title, author: "【\(poem.dynasty)】\(poem.author)") {
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

private struct HighlightedPoemText: View {
    let content: String
    @ObservedObject var speaker: PoemSpeaker

    /// Map the speaker's spoken range (in full text) to a range in `content`.
    private var highlightRange: Range<String.Index>? {
        guard let spokenRange = speaker.spokenRange,
              let contentStart = speaker.contentStartIndex,
              let fullText = speaker.currentText else { return nil }
        // Only highlight if the spoken range overlaps the content portion
        let contentEnd = fullText.endIndex
        let overlapLower = max(spokenRange.lowerBound, contentStart)
        let overlapUpper = min(spokenRange.upperBound, contentEnd)
        guard overlapLower < overlapUpper else { return nil }
        // Convert to content-local offsets
        let localLower = fullText.distance(from: contentStart, to: overlapLower)
        let localUpper = fullText.distance(from: contentStart, to: overlapUpper)
        guard localLower >= 0, localUpper >= localLower else { return nil }
        let lo = content.index(content.startIndex, offsetBy: localLower, limitedBy: content.endIndex) ?? content.endIndex
        let hi = content.index(content.startIndex, offsetBy: localUpper, limitedBy: content.endIndex) ?? content.endIndex
        guard lo <= hi, hi <= content.endIndex else { return nil }
        return lo..<hi
    }

    var body: some View {
        if let range = highlightRange {
            let before = content[content.startIndex..<range.lowerBound]
            let spoken = content[range]
            let after = content[range.upperBound..<content.endIndex]
            (Text(before)
                + Text(spoken).foregroundColor(.accentColor).bold()
                + Text(after))
                .font(.title3)
                .lineSpacing(10)
                .multilineTextAlignment(.center)
        } else {
            Text(content)
                .font(.title3)
                .lineSpacing(10)
                .multilineTextAlignment(.center)
        }
    }
}

final class PoemSpeaker: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var highlightTimer: Timer?

    @Published var isSpeaking = false
    @Published var spokenRange: Range<String.Index>?
    private var onFinish: (() -> Void)?
    private(set) var currentText: String?
    private(set) var contentStartIndex: String.Index?
    private var contentOffset: Int = 0

    // Now Playing
    private var poemTitle = ""
    private var poemAuthor = ""

    // Rendering state
    private var renderBuffers: [AVAudioPCMBuffer] = []
    private static let tempFileURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("xingxiangzi_tts.caf")

    override init() {
        super.init()
        synthesizer.delegate = self
        activateSession()
        configureRemoteCommands()
    }

    // MARK: - Audio Session

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true, options: [])
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - Remote Commands

    private func configureRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return .commandFailed }
            player.play()
            self.isSpeaking = true
            self.startHighlightTimer()
            self.updateNowPlaying()
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.audioPlayer?.pause()
            self.isSpeaking = false
            self.stopHighlightTimer()
            self.updateNowPlaying()
            return .success
        }

        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return .commandFailed }
            if player.isPlaying {
                player.pause()
                self.isSpeaking = false
                self.stopHighlightTimer()
            } else {
                player.play()
                self.isSpeaking = true
                self.startHighlightTimer()
            }
            self.updateNowPlaying()
            return .success
        }

        cc.stopCommand.isEnabled = true
        cc.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }

        // Disable unused commands so iOS doesn't show them
        cc.nextTrackCommand.isEnabled = false
        cc.previousTrackCommand.isEnabled = false
    }

    // MARK: - Now Playing

    private func setupNowPlaying(duration: TimeInterval, elapsed: TimeInterval, rate: Double) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = poemTitle
        info[MPMediaItemPropertyArtist] = poemAuthor
        info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: elapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: rate)
        info[MPMediaItemPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue)
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = rate > 0 ? .playing : .paused
    }

    private func updateNowPlaying() {
        guard !poemTitle.isEmpty else { return }
        if let player = audioPlayer {
            setupNowPlaying(
                duration: player.duration,
                elapsed: player.currentTime,
                rate: player.isPlaying ? 1.0 : 0.0
            )
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }

    // MARK: - Speak / Stop

    func speak(_ text: String, language: SpeechLanguage, contentOffset: Int = 0, title: String = "", author: String = "", onFinish: (() -> Void)? = nil) {
        stop()
        self.onFinish = onFinish
        self.currentText = text
        self.contentOffset = contentOffset
        self.contentStartIndex = text.index(text.startIndex, offsetBy: contentOffset, limitedBy: text.endIndex)
        self.poemTitle = title
        self.poemAuthor = author
        self.isSpeaking = true

        activateSession()

        // Pre-render speech to audio buffers, then play as audio file
        renderBuffers = []
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8

        synthesizer.write(utterance) { [weak self] buffer in
            guard let self = self else { return }
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer,
                  pcmBuffer.frameLength > 0 else { return }
            self.renderBuffers.append(pcmBuffer)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.playRenderedAudio()
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        stopHighlightTimer()
        renderBuffers = []
        onFinish = nil
        currentText = nil
        contentStartIndex = nil
        isSpeaking = false
        spokenRange = nil
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = nil
        center.playbackState = .stopped
    }

    // MARK: - Render & Play

    private func playRenderedAudio() {
        guard let firstBuffer = renderBuffers.first else {
            isSpeaking = false
            return
        }

        let url = PoemSpeaker.tempFileURL
        do {
            let audioFile = try AVAudioFile(forWriting: url, settings: firstBuffer.format.settings)
            for buffer in renderBuffers {
                try audioFile.write(from: buffer)
            }
            renderBuffers = []

            // Force a clean audio session after AVSpeechSynthesizer.write()
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true, options: [])

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            audioPlayer = player

            // Set Now Playing info BEFORE play() so iOS registers the app
            setupNowPlaying(duration: player.duration, elapsed: 0, rate: 1.0)

            player.play()
            startHighlightTimer()
        } catch {
            print("Failed to play rendered speech: \(error)")
            isSpeaking = false
        }
    }

    // MARK: - Text Highlight

    private func startHighlightTimer() {
        stopHighlightTimer()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.updateHighlight()
        }
    }

    private func stopHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = nil
    }

    private func updateHighlight() {
        guard let player = audioPlayer, player.duration > 0,
              let text = currentText, !text.isEmpty else { return }
        let progress = player.currentTime / player.duration
        let charIndex = min(Int(progress * Double(text.count)), text.count - 1)
        guard charIndex >= 0 else { return }
        let lo = text.index(text.startIndex, offsetBy: charIndex)
        let hi = text.index(lo, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
        spokenRange = lo..<hi
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.audioPlayer = nil
            self.stopHighlightTimer()
            self.isSpeaking = false
            self.spokenRange = nil
            self.updateNowPlaying()
            self.onFinish?()
            self.onFinish = nil
        }
    }
}
