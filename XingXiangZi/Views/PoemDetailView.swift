import SwiftUI

struct PoemDetailView: View {
    let poem: Poem

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
    }
}
