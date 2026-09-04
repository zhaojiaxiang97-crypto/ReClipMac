import Foundation

struct ToolStatus: Equatable, Sendable {
    let ytDLPPath: String?
    let ffmpegPath: String?

    var isReady: Bool {
        ytDLPPath != nil && ffmpegPath != nil
    }

    var message: String {
        if isReady {
            return "yt-dlp 和 ffmpeg 已就绪"
        }

        var missing: [String] = []
        if ytDLPPath == nil { missing.append("yt-dlp") }
        if ffmpegPath == nil { missing.append("ffmpeg") }
        return "缺少 \(missing.joined(separator: "、"))。请运行：brew install \(missing.joined(separator: " "))"
    }
}

struct ToolLocator {
    func locate() -> ToolStatus {
        ToolStatus(
            ytDLPPath: executable(named: "yt-dlp"),
            ffmpegPath: executable(named: "ffmpeg")
        )
    }

    private func executable(named name: String) -> String? {
        let pathDirectories = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"] + pathDirectories

        for directory in candidates {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}
