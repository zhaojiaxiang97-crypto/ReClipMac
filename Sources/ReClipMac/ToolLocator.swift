import Foundation

struct ToolStatus: Equatable, Sendable {
    let ytDLPPath: String?
    let ffmpegPath: String?

    var isReady: Bool {
        ytDLPPath != nil && ffmpegPath != nil
    }

    var message: String {
        if isReady {
            return L10n.text("tool.ready")
        }

        var missing: [String] = []
        if ytDLPPath == nil { missing.append("yt-dlp") }
        if ffmpegPath == nil { missing.append("ffmpeg") }
        return L10n.format(
            "tool.missing",
            missing.joined(separator: L10n.text("list.separator")),
            missing.joined(separator: " ")
        )
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
