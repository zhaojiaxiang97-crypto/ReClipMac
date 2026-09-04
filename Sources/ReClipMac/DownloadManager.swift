import AppKit
import Combine
import Foundation

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var toolStatus = ToolStatus(ytDLPPath: nil, ffmpegPath: nil)
    @Published private(set) var items: [DownloadItem] = []
    @Published var destinationURL: URL
    @Published var inputError: String?
    @Published private(set) var isQueueRunning = false

    var readyItemCount: Int {
        items.filter { $0.status == .ready }.count
    }

    private let toolLocator = ToolLocator()
    private var activeItem: DownloadItem?
    private var pendingItems: [DownloadItem] = []
    private var partialLines: [UUID: String] = [:]
    private var lastMessages: [UUID: String] = [:]
    private var pendingDeletion = Set<UUID>()

    init() {
        let defaults = UserDefaults.standard
        if let savedPath = defaults.string(forKey: "downloadDirectory") {
            destinationURL = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            destinationURL = downloads.appendingPathComponent("ReClip", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
    }

    func refreshToolStatus() {
        toolStatus = toolLocator.locate()
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
    }

    func setDestination(_ url: URL) {
        destinationURL = url
        UserDefaults.standard.set(url.path, forKey: "downloadDirectory")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func inspectURLs(from rawInput: String, mode: DownloadMode) {
        inputError = nil
        guard toolStatus.isReady else {
            inputError = toolStatus.message
            return
        }

        let urls = uniqueURLs(from: rawInput)
        guard !urls.isEmpty else {
            inputError = "请输入一个或多个有效的 http/https 链接。"
            return
        }

        let knownURLs = Set(items.map { $0.sourceURL.absoluteString })
        for url in urls where !knownURLs.contains(url.absoluteString) {
            let item = DownloadItem(sourceURL: url, mode: mode)
            items.append(item)
            Task { [weak self, weak item] in
                guard let self, let item else { return }
                await self.inspect(item)
            }
        }
    }

    func startAllReadyItems() {
        for item in items where item.status == .ready {
            startDownload(item)
        }
    }

    func startDownload(_ item: DownloadItem) {
        guard toolStatus.isReady else {
            item.status = .failed
            item.errorMessage = toolStatus.message
            return
        }
        guard item.status.canStart else { return }

        item.errorMessage = nil
        item.progress = 0
        item.speed = ""
        item.eta = ""
        item.wasCancelled = false
        item.createdFileURLs.removeAll()

        if activeItem != nil {
            guard !pendingItems.contains(where: { $0.id == item.id }) else { return }
            item.status = .queued
            pendingItems.append(item)
            isQueueRunning = true
            return
        }

        launch(item)
    }

    func cancel(_ item: DownloadItem) {
        if item.status == .queued {
            pendingItems.removeAll { $0.id == item.id }
            item.status = .cancelled
            return
        }

        guard item.status == .downloading else { return }
        item.wasCancelled = true
        item.process?.terminate()
    }

    func remove(_ item: DownloadItem) {
        pendingItems.removeAll { $0.id == item.id }
        items.removeAll { $0.id == item.id }

        if activeItem?.id == item.id {
            pendingDeletion.insert(item.id)
            item.wasCancelled = true
            item.process?.terminate()
        } else {
            trashFiles(for: item)
            if activeItem == nil && pendingItems.isEmpty {
                isQueueRunning = false
            }
        }
    }

    func retry(_ item: DownloadItem) {
        guard item.status == .failed || item.status == .cancelled else { return }
        item.status = .ready
        item.errorMessage = nil
        startDownload(item)
    }

    func reveal(_ item: DownloadItem) {
        if let outputURL = item.outputURL {
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        } else {
            NSWorkspace.shared.open(item.destinationURL ?? destinationURL)
        }
    }

    private func inspect(_ item: DownloadItem) async {
        guard let ytDLPPath = toolStatus.ytDLPPath else {
            item.status = .failed
            item.errorMessage = toolStatus.message
            return
        }

        item.status = .inspecting
        let urlString = item.sourceURL.absoluteString

        do {
            let output = try await CommandRunner.output(
                executable: ytDLPPath,
                arguments: ["--no-playlist", "--no-warnings", "--socket-timeout", "30", "-J", urlString]
            )
            let info = try JSONDecoder().decode(YTDLPInfo.self, from: Data(output.utf8))
            let formats = bestFormats(from: info.formats ?? [])

            item.title = info.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? info.title! : "未命名媒体"
            item.uploader = info.uploader ?? ""
            item.duration = info.duration
            item.thumbnailURL = info.thumbnail.flatMap(URL.init(string:))
            item.formats = formats
            item.selectedFormatID = formats.first?.id
            item.status = .ready
        } catch {
            item.status = .failed
            item.errorMessage = friendlyError(error.localizedDescription)
        }
    }

    private func launch(_ item: DownloadItem) {
        guard let ytDLPPath = toolStatus.ytDLPPath,
              let ffmpegPath = toolStatus.ffmpegPath else {
            item.status = .failed
            item.errorMessage = toolStatus.message
            return
        }

        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        } catch {
            item.status = .failed
            item.errorMessage = "无法创建下载目录：\(error.localizedDescription)"
            return
        }

        let outputTemplate = destinationURL
            .appendingPathComponent("%(title).200B [%(id)s].%(ext)s")
            .path
        var arguments = [
            "--no-playlist",
            "--no-warnings",
            "--newline",
            "--no-quiet",
            "--ffmpeg-location", ffmpegPath,
            "--progress-template", "download:download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "after_move:filepath",
            "-o", outputTemplate
        ]

        switch item.mode {
        case .audio:
            arguments += ["-x", "--audio-format", "mp3"]
        case .video:
            if let formatID = item.selectedFormatID {
                arguments += ["-f", "\(formatID)+bestaudio/best"]
            } else {
                arguments += ["-f", "bestvideo+bestaudio/best"]
            }
            arguments += ["--merge-output-format", "mp4"]
        }
        arguments.append(item.sourceURL.absoluteString)

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: ytDLPPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        item.status = .downloading
        item.destinationURL = destinationURL
        item.process = process
        item.outputPipe = outputPipe
        item.errorPipe = errorPipe
        activeItem = item
        isQueueRunning = true

        observe(outputPipe, item: item)
        observe(errorPipe, item: item)
        process.terminationHandler = { [weak self, weak item] completedProcess in
            let exitStatus = completedProcess.terminationStatus
            DispatchQueue.main.async {
                guard let self, let item else { return }
                self.finishDownload(item, exitStatus: exitStatus)
            }
        }

        do {
            try process.run()
        } catch {
            finishDownload(item, exitStatus: 1, launchError: error.localizedDescription)
        }
    }

    private func observe(_ pipe: Pipe, item: DownloadItem) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self, weak item] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                guard let self, let item else { return }
                self.consumeOutput(text, for: item)
            }
        }
    }

    private func consumeOutput(_ text: String, for item: DownloadItem) {
        let combined = (partialLines[item.id] ?? "") + text
        var lines = combined.components(separatedBy: .newlines)
        if !combined.hasSuffix("\n") {
            partialLines[item.id] = lines.popLast() ?? ""
        } else {
            partialLines[item.id] = ""
        }

        for line in lines {
            consumeLine(line, for: item)
        }
    }

    private func consumeLine(_ line: String, for item: DownloadItem) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("download:") {
            let values = trimmed.dropFirst("download:".count).split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            if let first = values.first {
                let percentText = first.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                if let percent = Double(percentText) {
                    item.progress = min(max(percent / 100, 0), 1)
                }
            }
            if values.count > 1 { item.speed = String(values[1]).trimmingCharacters(in: .whitespaces) }
            if values.count > 2 { item.eta = String(values[2]).trimmingCharacters(in: .whitespaces) }
            return
        }

        let destinationPrefix = "[download] Destination:"
        if trimmed.hasPrefix(destinationPrefix) {
            let path = trimmed.dropFirst(destinationPrefix.count).trimmingCharacters(in: .whitespaces)
            if path.hasPrefix("/") {
                item.createdFileURLs.insert(URL(fileURLWithPath: path))
            }
            return
        }

        if trimmed.hasPrefix("/") {
            item.outputURL = URL(fileURLWithPath: trimmed)
            item.createdFileURLs.insert(URL(fileURLWithPath: trimmed))
            return
        }

        if trimmed.contains("ERROR:") || trimmed.contains("WARNING:") {
            lastMessages[item.id] = trimmed
        }
    }

    private func finishDownload(_ item: DownloadItem, exitStatus: Int32, launchError: String? = nil) {
        item.outputPipe?.fileHandleForReading.readabilityHandler = nil
        item.errorPipe?.fileHandleForReading.readabilityHandler = nil
        item.process = nil
        item.outputPipe = nil
        item.errorPipe = nil
        partialLines[item.id] = nil

        if pendingDeletion.remove(item.id) != nil {
            trashFiles(for: item)
        }

        if item.wasCancelled {
            item.status = .cancelled
        } else if exitStatus == 0 && launchError == nil {
            item.progress = 1
            item.status = .completed
        } else {
            item.status = .failed
            let message = launchError ?? lastMessages[item.id] ?? "下载失败，请检查链接和网络后重试。"
            item.errorMessage = friendlyError(message)
        }

        lastMessages[item.id] = nil
        if activeItem?.id == item.id {
            activeItem = nil
        }
        startNextDownload()
    }

    private func trashFiles(for item: DownloadItem) {
        let rootURL = (item.destinationURL ?? destinationURL).standardizedFileURL
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        var urls = item.createdFileURLs
        if let outputURL = item.outputURL {
            urls.insert(outputURL)
        }

        for url in urls {
            let candidates = [
                url,
                URL(fileURLWithPath: url.path + ".part"),
                URL(fileURLWithPath: url.path + ".ytdl")
            ]

            for candidate in candidates {
                let standardized = candidate.standardizedFileURL
                guard standardized.path.hasPrefix(rootPath) else { continue }

                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue else {
                    continue
                }

                do {
                    try FileManager.default.trashItem(at: standardized, resultingItemURL: nil)
                } catch {
                    inputError = "无法将文件移到废纸篓：\(error.localizedDescription)"
                }
            }
        }
        item.createdFileURLs.removeAll()
    }

    private func startNextDownload() {
        guard activeItem == nil else { return }

        while !pendingItems.isEmpty {
            let next = pendingItems.removeFirst()
            guard next.status == .queued else { continue }
            launch(next)
            return
        }
        isQueueRunning = false
    }

    private func uniqueURLs(from rawInput: String) -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []

        for value in rawInput.split(whereSeparator: { $0.isWhitespace || $0 == "," }) {
            let candidate = String(value)
            guard let url = URL(string: candidate),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  seen.insert(url.absoluteString).inserted else {
                continue
            }
            urls.append(url)
        }
        return urls
    }

    private func bestFormats(from sourceFormats: [YTDLPFormat]) -> [MediaFormat] {
        var bestByHeight: [Int: YTDLPFormat] = [:]

        for format in sourceFormats {
            guard let height = format.height,
                  let formatID = format.formatID,
                  format.vcodec != "none" else {
                continue
            }
            if let current = bestByHeight[height], (current.tbr ?? 0) >= (format.tbr ?? 0) {
                continue
            }
            bestByHeight[height] = YTDLPFormat(
                formatID: formatID,
                height: height,
                vcodec: format.vcodec,
                tbr: format.tbr
            )
        }

        return bestByHeight.values.compactMap { format in
            guard let formatID = format.formatID, let height = format.height else { return nil }
            return MediaFormat(id: formatID, label: "\(height)p", height: height)
        }
        .sorted { $0.height > $1.height }
    }

    private func friendlyError(_ rawMessage: String) -> String {
        let message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = message.lowercased()

        if lowercased.contains("unsupported url") { return "该链接暂不受支持。" }
        if lowercased.contains("private video") || lowercased.contains("video unavailable") {
            return "媒体不可访问、已删除或为私密内容。"
        }
        if lowercased.contains("http error 403") { return "平台拒绝了访问请求。" }
        if lowercased.contains("http error 404") { return "未找到对应媒体。" }
        if lowercased.contains("timed out") { return "请求超时，请检查网络后重试。" }
        if lowercased.contains("drm") { return "该媒体受 DRM 保护，无法下载。" }
        return message.isEmpty ? "下载失败，请稍后重试。" : message
    }
}

private struct YTDLPInfo: Decodable {
    let title: String?
    let thumbnail: String?
    let duration: TimeInterval?
    let uploader: String?
    let formats: [YTDLPFormat]?
}

private struct YTDLPFormat: Decodable {
    let formatID: String?
    let height: Int?
    let vcodec: String?
    let tbr: Double?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case height
        case vcodec
        case tbr
    }
}

private struct CommandFailure: LocalizedError, Sendable {
    let message: String

    var errorDescription: String? { message }
}

private enum CommandRunner {
    static func output(executable: String, arguments: [String]) async throws -> String {
        let task = Task.detached(priority: .userInitiated) {
            try outputSynchronously(executable: executable, arguments: arguments)
        }
        return try await task.value
    }

    private static func outputSynchronously(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw CommandFailure(message: error.localizedDescription)
        }

        process.waitUntilExit()
        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let error = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw CommandFailure(message: error.isEmpty ? "yt-dlp 解析失败。" : error)
        }
        return output
    }
}
