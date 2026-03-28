import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Siri 语音控制")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("HomePod / Siri", systemImage: "homepod.fill")
                            .font(.body)
                        Group {
                            Text("• \"Hey Siri, 用行香子播放水调歌头\"")
                            Text("• \"Hey Siri, 用行香子朗读诗词\"")
                            Text("• 播放时可用 HomePod 顶部点按暂停/继续")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
