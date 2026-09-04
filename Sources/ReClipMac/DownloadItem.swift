import Combine
import Foundation

enum DownloadMode: String, CaseIterable, Identifiable, Sendable {
    case video
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: "MP4"
        case .audio: "MP3"
        }
    }
}

enum DownloadStatus: String, Equatable, Sendable {
    case inspecting
    case ready
    case queued
    case downloading
    case completed
    case failed
    case cancelled

    var title: String {
        switch self {
        case .inspecting: L10n.text("status.inspecting")
        case .ready: L10n.text("status.ready")
        case .queued: L10n.text("status.queued")
        case .downloading: L10n.text("status.downloading")
        case .completed: L10n.text("status.completed")
        case .failed: L10n.text("status.failed")
        case .cancelled: L10n.text("status.cancelled")
        }
    }

    var canStart: Bool {
        self == .ready || self == .failed || self == .cancelled
    }
}

struct MediaFormat: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let height: Int
}

@MainActor
final class DownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let sourceURL: URL

    @Published var title = L10n.text("media.inspecting_title")
    @Published var uploader = ""
    @Published var duration: TimeInterval?
    @Published var thumbnailURL: URL?
    @Published var formats: [MediaFormat] = []
    @Published var selectedFormatID: String?
    @Published var mode: DownloadMode
    @Published var status: DownloadStatus = .inspecting
    @Published var progress = 0.0
    @Published var speed = ""
    @Published var eta = ""
    @Published var errorMessage: String?
    @Published var destinationURL: URL?
    @Published var outputURL: URL?

    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?
    var wasCancelled = false
    var createdFileURLs = Set<URL>()

    init(sourceURL: URL, mode: DownloadMode) {
        self.sourceURL = sourceURL
        self.mode = mode
    }

    var durationText: String {
        guard let duration else { return "" }
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var selectedFormatLabel: String {
        guard let selectedFormatID,
              let format = formats.first(where: { $0.id == selectedFormatID }) else {
            return L10n.text("format.best")
        }
        return format.label
    }
}
