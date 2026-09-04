import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var rawURLs = ""
    @State private var selectedMode: DownloadMode = .video
    @FocusState private var isURLInputFocused: Bool

    var body: some View {
        ZStack {
            ReClipPalette.canvas.ignoresSafeArea()
            RadialGradient(
                colors: [ReClipPalette.accent.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 680
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                inputCard
                                    .frame(minWidth: 520, maxWidth: .infinity)
                                utilityPanel
                                    .frame(width: 300)
                            }

                            VStack(spacing: 16) {
                                inputCard
                                utilityPanel
                            }
                        }

                        if let inputError = manager.inputError {
                            errorBanner(inputError)
                        }

                        taskSection
                    }
                    .frame(maxWidth: 1120)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                }
            }
        }
        .onAppear { isURLInputFocused = true }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ReClipPalette.accent)
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text("ReClip")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                Text(L10n.text("app.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(L10n.text("app.legal_notice"), systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 13)
        .background(ReClipPalette.chrome)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ReClipPalette.border)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("01")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(ReClipPalette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(ReClipPalette.accent.opacity(0.12), in: Capsule())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("input.title"))
                        .font(.title3.weight(.semibold))
                    Text(L10n.text("input.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker(L10n.text("output_format"), selection: $selectedMode) {
                    ForEach(DownloadMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 128)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $rawURLs)
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)
                    .focused($isURLInputFocused)
                    .frame(minHeight: 118, maxHeight: 160)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(L10n.text("input.accessibility"))

                if rawURLs.isEmpty {
                    Text("https://example.com/video")
                        .font(.body.monospaced())
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 13)
                        .padding(.top, 15)
                        .allowsHitTesting(false)
                }
            }
            .background(ReClipPalette.field, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isURLInputFocused ? ReClipPalette.accent : ReClipPalette.border, lineWidth: isURLInputFocused ? 2 : 1)
                    .allowsHitTesting(false)
            }

            HStack(spacing: 12) {
                Label(L10n.text("input.separators"), systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("⌘↩")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)

                Button {
                    inspectInput()
                } label: {
                    Label(L10n.text("input.inspect"), systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ReClipPalette.accent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canInspect)
            }
        }
        .padding(20)
        .background(ReClipPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReClipPalette.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var utilityPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: manager.toolStatus.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(manager.toolStatus.isReady ? ReClipPalette.success : ReClipPalette.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text(manager.toolStatus.isReady ? "environment.ready" : "environment.needs_attention"))
                        .font(.callout.weight(.semibold))
                    Text(manager.toolStatus.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    manager.refreshToolStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(L10n.text("environment.recheck"))
                .accessibilityLabel(L10n.text("environment.recheck"))
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.text("destination.title"), systemImage: "folder.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ReClipPalette.accent)

                Text(manager.destinationURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack {
                    Button {
                        NSWorkspace.shared.open(manager.destinationURL)
                    } label: {
                        Label(L10n.text("action.open"), systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.text("destination.change")) {
                        chooseDestination()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()

            Label(L10n.text("destination.local_only"), systemImage: "desktopcomputer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(ReClipPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReClipPalette.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("queue.title"))
                        .font(.title3.weight(.semibold))
                    Text(manager.items.isEmpty
                         ? L10n.text("queue.empty_hint")
                         : L10n.format("queue.task_count", manager.items.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if manager.isQueueRunning {
                    Label(L10n.text("queue.running"), systemImage: "arrow.down.to.line.compact")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ReClipPalette.accent)
                }

                Button {
                    manager.startAllReadyItems()
                } label: {
                    Label(L10n.text("queue.download_all"), systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(ReClipPalette.accent)
                .disabled(manager.readyItemCount == 0 || !manager.toolStatus.isReady)
            }

            if manager.items.isEmpty {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ReClipPalette.accent.opacity(0.12))
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.title2)
                            .foregroundStyle(ReClipPalette.accent)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("queue.empty_title"))
                            .font(.headline)
                        Text(L10n.text("queue.empty_body"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReClipPalette.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ReClipPalette.border, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(manager.items) { item in
                        DownloadRow(item: item)
                            .environmentObject(manager)
                    }
                }
            }
        }
    }

    private var canInspect: Bool {
        !rawURLs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && manager.toolStatus.isReady
    }

    private func inspectInput() {
        let input = rawURLs
        manager.inspectURLs(from: input, mode: selectedMode)
        rawURLs = ""
        isURLInputFocused = true
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = manager.destinationURL
        panel.message = L10n.text("destination.panel_message")

        if panel.runModal() == .OK, let url = panel.url {
            manager.setDestination(url)
        }
    }
}

private enum ReClipPalette {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let chrome = Color(nsColor: .underPageBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let field = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let accent = Color(red: 0.92, green: 0.38, blue: 0.13)
    static let success = Color(nsColor: .systemGreen)
}

private struct DownloadRow: View {
    @EnvironmentObject private var manager: DownloadManager
    @ObservedObject var item: DownloadItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Label(item.status.title, systemImage: statusIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12), in: Capsule())

                    Button {
                        manager.remove(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(L10n.text("task.delete_help"))
                    .accessibilityLabel(L10n.text("task.delete_accessibility"))
                }

                let metadata = [item.sourceURL.host ?? "", item.uploader, item.durationText]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if item.status == .downloading || item.status == .queued {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: item.progress)
                            .tint(ReClipPalette.accent)
                        HStack {
                            Text(item.status == .queued
                                 ? L10n.text("task.waiting_previous")
                                 : "\(Int(item.progress * 100))%")
                            Spacer()
                            if !item.speed.isEmpty { Text(item.speed) }
                            if !item.eta.isEmpty { Text(L10n.format("task.remaining", item.eta)) }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = item.errorMessage, item.status == .failed {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                controls
            }
        }
        .padding(14)
        .background(ReClipPalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(ReClipPalette.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderThumbnail
                }
            }
            .frame(width: 112, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderThumbnail
                .frame(width: 112, height: 72)
        }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(ReClipPalette.accent.opacity(0.12))
            .overlay {
                Image(systemName: item.mode == .audio ? "waveform" : "play.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(ReClipPalette.accent)
            }
    }

    @ViewBuilder
    private var controls: some View {
        switch item.status {
        case .ready:
            HStack(spacing: 8) {
                Picker(L10n.text("output_format"), selection: $item.mode) {
                    ForEach(DownloadMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 110)

                if item.mode == .video, !item.formats.isEmpty {
                    Menu(item.selectedFormatLabel) {
                        ForEach(item.formats) { format in
                            Button(format.label) {
                                item.selectedFormatID = format.id
                            }
                        }
                    }
                }

                Button(L10n.text("action.download")) {
                    manager.startDownload(item)
                }
                .buttonStyle(.borderedProminent)
                .tint(ReClipPalette.accent)
            }

        case .queued, .downloading:
            Button(L10n.text("action.cancel")) {
                manager.cancel(item)
            }
            .buttonStyle(.bordered)

        case .completed:
            Button(L10n.text("action.show_in_finder")) {
                manager.reveal(item)
            }
            .buttonStyle(.borderedProminent)
            .tint(ReClipPalette.success)

        case .failed, .cancelled:
            HStack(spacing: 8) {
                Button(L10n.text("action.retry")) {
                    manager.retry(item)
                }
                .buttonStyle(.borderedProminent)
                .tint(ReClipPalette.accent)

                Button(L10n.text("action.open_folder")) {
                    manager.reveal(item)
                }
                .buttonStyle(.bordered)
            }

        case .inspecting:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.text("media.reading"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed: ReClipPalette.success
        case .failed: .red
        case .cancelled: .secondary
        case .downloading: ReClipPalette.accent
        case .queued, .ready, .inspecting: .secondary
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .inspecting: "magnifyingglass"
        case .ready: "checkmark"
        case .queued: "clock"
        case .downloading: "arrow.down"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }
}
