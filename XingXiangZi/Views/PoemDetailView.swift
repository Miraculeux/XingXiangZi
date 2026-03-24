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
    @State private var showingCiPaiDetail = false

    /// Extract cipai name from poem title (part before · or full title)
    private var matchedCiPai: CiPai? {
        let cipaiName: String
        if let dotIndex = poem.title.firstIndex(of: "·") {
            cipaiName = String(poem.title[poem.title.startIndex..<dotIndex])
        } else if let dotIndex = poem.title.firstIndex(of: "．") {
            cipaiName = String(poem.title[poem.title.startIndex..<dotIndex])
        } else {
            cipaiName = poem.title
        }
        return DatabaseManager.shared.findCiPai(byName: cipaiName)
    }

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

                // CiPai link
                if let cipai = matchedCiPai {
                    Button {
                        showingCiPaiDetail = true
                    } label: {
                        Label("词牌：\(cipai.name)", systemImage: "text.book.closed")
                            .font(.subheadline)
                    }
                }

                // Action icons
                HStack(spacing: 24) {
                    //Button {
                    //    onEdit?()
                    //} label: {
                    //    Image(systemName: "square.and.pencil")
                    //        .font(.title2)
                    //}
                    //.buttonStyle(.plain)

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
                    speaker: speaker,
                    onPlayFromParagraph: { paragraphIndex in
                        startSpeakingFromParagraph(paragraphIndex)
                    }
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
        .onAppear {
            if autoPlay {
                startSpeaking()
            } else {
                speaker.stop()
            }
        }
        .sheet(isPresented: $showingCiPaiDetail) {
            if let cipai = matchedCiPai {
                NavigationStack {
                    CiPaiDetailView(cipai: cipai)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") {
                                    showingCiPaiDetail = false
                                }
                            }
                        }
                }
            }
        }
    }

    private func startSpeaking() {
        let prefix = "\(poem.title)。\(poem.author)。"
        let text = prefix + poem.content
        let poemId = poem.id
        speaker.speak(text, language: selectedLanguage, contentOffset: prefix.count, title: poem.title, author: "【\(poem.dynasty)】\(poem.author)") {
            switch self.playbackMode {
            case .single:
                break
            case .repeatOne:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard self.poem.id == poemId else { return }
                    self.startSpeaking()
                }
            case .next:
                if let next = self.nextPoem {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard self.poem.id == poemId else { return }
                        self.onNavigate?(next, true)
                    }
                }
            }
        }
    }

    private func startSpeakingFromParagraph(_ paragraphIndex: Int) {
        let paragraphs = poem.content.components(separatedBy: "\n")
        guard paragraphIndex < paragraphs.count else { return }
        let textFromParagraph = paragraphs[paragraphIndex...].joined(separator: "\n")
        let skippedChars = poem.content.count - textFromParagraph.count
        let poemId = poem.id
        speaker.speak(textFromParagraph, language: selectedLanguage, contentOffset: 0, title: poem.title, author: "【\(poem.dynasty)】\(poem.author)", contentSkipOffset: skippedChars) {
            switch self.playbackMode {
            case .single:
                break
            case .repeatOne:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard self.poem.id == poemId else { return }
                    self.startSpeaking()
                }
            case .next:
                if let next = self.nextPoem {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard self.poem.id == poemId else { return }
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
    var onPlayFromParagraph: ((Int) -> Void)?

    private var paragraphs: [String] {
        content.components(separatedBy: "\n")
    }

    /// Map the speaker's spoken range (in full text) to a range in `content`.
    private var highlightRange: Range<String.Index>? {
        guard let spokenRange = speaker.spokenRange,
              let contentStart = speaker.contentStartIndex,
              let fullText = speaker.currentText else { return nil }
        let contentEnd = fullText.endIndex
        let overlapLower = max(spokenRange.lowerBound, contentStart)
        let overlapUpper = min(spokenRange.upperBound, contentEnd)
        guard overlapLower < overlapUpper else { return nil }
        let localLower = fullText.distance(from: contentStart, to: overlapLower)
        let localUpper = fullText.distance(from: contentStart, to: overlapUpper)
        guard localLower >= 0, localUpper >= localLower else { return nil }
        // Offset into the full content string (accounting for skipped paragraphs)
        let skipOffset = speaker.contentSkipOffset
        let contentLocalLower = localLower + skipOffset
        let contentLocalUpper = localUpper + skipOffset
        let lo = content.index(content.startIndex, offsetBy: contentLocalLower, limitedBy: content.endIndex) ?? content.endIndex
        let hi = content.index(content.startIndex, offsetBy: contentLocalUpper, limitedBy: content.endIndex) ?? content.endIndex
        guard lo <= hi, hi <= content.endIndex else { return nil }
        return lo..<hi
    }

    var body: some View {
        let paras = paragraphs
        VStack(alignment: .center, spacing: 16) {
            ForEach(Array(paras.enumerated()), id: \.offset) { index, paragraph in
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        onPlayFromParagraph?(index)
                    } label: {
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    highlightedText(for: paragraph, paragraphIndex: index)
                        .font(.title3)
                        .lineSpacing(10)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func highlightedText(for paragraph: String, paragraphIndex: Int) -> Text {
        guard let range = highlightRange else {
            return Text(paragraph)
        }
        // Calculate the start/end of this paragraph within full content
        var charOffset = 0
        for i in 0..<paragraphIndex {
            charOffset += paragraphs[i].count + 1 // +1 for \n
        }
        let paraStart = content.index(content.startIndex, offsetBy: charOffset)
        let paraEnd = content.index(paraStart, offsetBy: paragraph.count, limitedBy: content.endIndex) ?? content.endIndex

        // Check if highlight overlaps this paragraph
        guard range.lowerBound < paraEnd, range.upperBound > paraStart else {
            return Text(paragraph)
        }

        let hlStart = max(range.lowerBound, paraStart)
        let hlEnd = min(range.upperBound, paraEnd)

        let localStart = content.distance(from: paraStart, to: hlStart)
        let localEnd = content.distance(from: paraStart, to: hlEnd)

        let pStart = paragraph.startIndex
        let lo = paragraph.index(pStart, offsetBy: localStart, limitedBy: paragraph.endIndex) ?? paragraph.endIndex
        let hi = paragraph.index(pStart, offsetBy: localEnd, limitedBy: paragraph.endIndex) ?? paragraph.endIndex

        guard lo < hi else { return Text(paragraph) }

        let before = paragraph[pStart..<lo]
        let spoken = paragraph[lo..<hi]
        let after = paragraph[hi..<paragraph.endIndex]
        return Text(before) + Text(spoken).foregroundColor(.accentColor).bold() + Text(after)
    }
}

@MainActor
final class PoemSpeaker: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var highlightTimer: Timer?

    @Published var isSpeaking = false
    @Published var spokenRange: Range<String.Index>?
    private var onFinish: (() -> Void)?
    private var speakGeneration: Int = 0
    private(set) var currentText: String?
    private(set) var contentStartIndex: String.Index?
    private var contentOffset: Int = 0
    /// Number of characters in the full content that were skipped (for paragraph playback)
    @Published private(set) var contentSkipOffset: Int = 0
    private var isPaused = false

    // Now Playing
    private var poemTitle = ""
    private var poemAuthor = ""

    // Playback timing
    private var renderBuffers: [AVAudioPCMBuffer] = []
    private var playbackStartTime: Date?
    private var pauseElapsed: TimeInterval = 0
    private var totalDuration: TimeInterval = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        startEngine()
        configureRemoteCommands()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // Verify background audio is properly configured
        if let modes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String] {
            print("[TTS] UIBackgroundModes: \(modes)")
        } else {
            print("[TTS] WARNING: UIBackgroundModes NOT found in Info.plist!")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session & Engine

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
        } catch {
            print("[TTS] session error: \(error)")
        }
    }

    private func startEngine() {
        // Attach player node once; connect with a default format
        // Will reconnect with correct format when audio is ready
        if !audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.attach(playerNode)
        }
        let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: defaultFormat)
        do {
            try audioEngine.start()
            print("[TTS] engine started")
        } catch {
            print("[TTS] engine start error: \(error)")
        }
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print("[TTS] interruption began")
        case .ended:
            print("[TTS] interruption ended")
            let opts = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume) {
                DispatchQueue.main.async {
                    self.setupAudioSession()
                    if !self.audioEngine.isRunning {
                        do {
                            try self.audioEngine.start()
                        } catch {
                            print("[TTS] engine restart error: \(error)")
                            return
                        }
                    }
                    if self.isSpeaking || self.isPaused {
                        self.playerNode.play()
                        self.isPaused = false
                        self.isSpeaking = true
                        self.playbackStartTime = Date().addingTimeInterval(-self.pauseElapsed)
                        self.startHighlightTimer()
                        self.updateNowPlaying(rate: 1.0)
                    }
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Remote Commands

    private func configureRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            guard let self, self.isPaused else { return .commandFailed }
            self.resumePlayback()
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self, !self.isPaused else { return .commandFailed }
            self.pausePlayback()
            return .success
        }

        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPaused { self.resumePlayback() }
            else { self.pausePlayback() }
            return .success
        }

        cc.stopCommand.isEnabled = true
        cc.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }

        cc.nextTrackCommand.isEnabled = false
        cc.previousTrackCommand.isEnabled = false
    }

    // MARK: - Now Playing

    private var currentElapsed: TimeInterval {
        if isPaused { return pauseElapsed }
        guard let start = playbackStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    private func updateNowPlaying(rate: Double) {
        guard !poemTitle.isEmpty else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = poemTitle
        info[MPMediaItemPropertyArtist] = poemAuthor
        info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: totalDuration)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentElapsed)
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: rate)
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value: 1.0)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Speak / Stop

    func speak(_ text: String, language: SpeechLanguage, contentOffset: Int = 0, title: String = "", author: String = "", contentSkipOffset: Int = 0, onFinish: (() -> Void)? = nil) {
        stop()
        self.onFinish = onFinish
        self.currentText = text
        self.contentOffset = contentOffset
        self.contentStartIndex = text.index(text.startIndex, offsetBy: contentOffset, limitedBy: text.endIndex)
        self.contentSkipOffset = contentSkipOffset
        self.poemTitle = title
        self.poemAuthor = author
        self.isPaused = false

        setupAudioSession()
        if !audioEngine.isRunning {
            startEngine()
        }

        renderBuffers = []
        speakGeneration += 1
        let generation = speakGeneration
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8

        isSpeaking = true

        // write() renders speech to PCM buffers on a background thread
        synthesizer.write(utterance) { [weak self] buffer in
            guard let self,
                  self.speakGeneration == generation,
                  let pcm = buffer as? AVAudioPCMBuffer,
                  pcm.frameLength > 0 else { return }
            self.renderBuffers.append(pcm)
        }
    }

    func stop() {
        speakGeneration += 1
        synthesizer.stopSpeaking(at: .immediate)
        playerNode.stop()
        stopHighlightTimer()
        renderBuffers = []
        isPaused = false
        onFinish = nil
        currentText = nil
        contentStartIndex = nil
        contentSkipOffset = 0
        isSpeaking = false
        spokenRange = nil
        playbackStartTime = nil
        pauseElapsed = 0
        totalDuration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func pausePlayback() {
        guard !isPaused else { return }
        pauseElapsed = currentElapsed
        playerNode.pause()
        isPaused = true
        isSpeaking = false
        stopHighlightTimer()
        updateNowPlaying(rate: 0.0)
    }

    private func resumePlayback() {
        guard isPaused else { return }
        playerNode.play()
        playbackStartTime = Date().addingTimeInterval(-pauseElapsed)
        isPaused = false
        isSpeaking = true
        startHighlightTimer()
        updateNowPlaying(rate: 1.0)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.playViaEngine()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Only reset state if no new speak session has started
        let gen = self.speakGeneration
        DispatchQueue.main.async {
            guard self.speakGeneration == gen else { return }
            self.isSpeaking = false
            self.spokenRange = nil
        }
    }

    // MARK: - AVAudioEngine Playback

    private func playViaEngine() {
        guard currentText != nil else {
            renderBuffers = []
            return
        }
        guard let firstBuf = renderBuffers.first else {
            print("[TTS] no buffers to play")
            isSpeaking = false
            return
        }

        let format = firstBuf.format
        var totalFrames: AVAudioFrameCount = 0
        for buf in renderBuffers { totalFrames += buf.frameLength }
        totalDuration = Double(totalFrames) / format.sampleRate

        guard totalDuration > 0 else {
            print("[TTS] zero duration")
            isSpeaking = false
            return
        }

        print("[TTS] playing \(renderBuffers.count) buffers, \(totalFrames) frames, \(totalDuration)s")

        // Reconnect with the correct format from the synthesizer
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        if !audioEngine.isRunning {
            do { try audioEngine.start() }
            catch {
                print("[TTS] engine start error: \(error)")
                isSpeaking = false
                return
            }
        }

        // Schedule all buffers; completion on the last one
        let generation = speakGeneration
        for (i, buf) in renderBuffers.enumerated() {
            if i == renderBuffers.count - 1 {
                playerNode.scheduleBuffer(buf, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self, self.speakGeneration == generation else { return }
                        self.playbackDidFinish()
                    }
                }
            } else {
                playerNode.scheduleBuffer(buf)
            }
        }
        renderBuffers = []

        playerNode.play()
        playbackStartTime = Date()
        pauseElapsed = 0

        updateNowPlaying(rate: 1.0)
        startHighlightTimer()
    }

    private func playbackDidFinish() {
        stopHighlightTimer()
        isSpeaking = false
        spokenRange = nil
        playbackStartTime = nil
        totalDuration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let cb = onFinish
        onFinish = nil
        cb?()
    }

    // MARK: - Text Highlight

    private func startHighlightTimer() {
        stopHighlightTimer()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateHighlight()
            }
        }
    }

    private func stopHighlightTimer() {
        highlightTimer?.invalidate()
        highlightTimer = nil
    }

    private func updateHighlight() {
        guard totalDuration > 0,
              let text = currentText, !text.isEmpty else { return }
        let progress = min(currentElapsed / totalDuration, 1.0)
        let charIndex = min(Int(progress * Double(text.count)), text.count - 1)
        guard charIndex >= 0 else { return }
        let lo = text.index(text.startIndex, offsetBy: charIndex)
        let hi = text.index(lo, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
        guard lo < hi else { return }
        spokenRange = lo..<hi
    }
}
