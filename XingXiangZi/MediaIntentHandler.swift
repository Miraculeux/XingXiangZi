import Foundation
import Intents

final class MediaIntentHandler: NSObject, INPlayMediaIntentHandling {

    // MARK: - Resolve media items

    func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
        guard let searchTerm = intent.mediaSearch?.mediaName ?? intent.mediaSearch?.artistName,
              !searchTerm.isEmpty else {
            // No specific request — will play random
            return [.notRequired()]
        }

        let poems = await MainActor.run { DatabaseManager.shared.poems }
        let matches = poems.filter {
            fuzzyContains($0.title, searchTerm) || fuzzyContains($0.author, searchTerm)
        }

        if matches.isEmpty {
            return [.unsupported()]
        }

        let mediaItems = matches.prefix(5).map { poem -> INMediaItem in
            INMediaItem(
                identifier: String(poem.id),
                title: "\(poem.author)《\(poem.title)》",
                type: .podcastEpisode,
                artwork: nil
            )
        }

        if mediaItems.count == 1 {
            return [.success(with: mediaItems[0])]
        }
        return [.disambiguation(with: mediaItems)]
    }

    // MARK: - Handle playback

    func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
        let poems = await MainActor.run { DatabaseManager.shared.poems }

        // Find the requested poem
        let poem: Poem?
        if let identifier = intent.mediaItems?.first?.identifier,
           let id = Int64(identifier) {
            poem = poems.first { $0.id == id }
        } else if let search = intent.mediaSearch?.mediaName ?? intent.mediaSearch?.artistName,
                  !search.isEmpty {
            poem = poems.first { fuzzyContains($0.title, search) || fuzzyContains($0.author, search) }
        } else {
            poem = poems.randomElement()
        }

        guard let poem else {
            return INPlayMediaIntentResponse(code: .failureNoUnplayedContent, userActivity: nil)
        }

        await MainActor.run {
            let prefix = "\(poem.title)。\(poem.author)。"
            let text = prefix + poem.content
            PoemSpeaker.shared.speak(
                text,
                language: .cantonese,
                contentOffset: prefix.count,
                title: poem.title,
                author: "【\(poem.dynasty)】\(poem.author)"
            )
        }

        return INPlayMediaIntentResponse(code: .success, userActivity: nil)
    }
}
