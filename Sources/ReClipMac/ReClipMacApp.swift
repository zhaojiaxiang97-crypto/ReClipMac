import AppKit
import SwiftUI

@main
struct ReClipMacApp: App {
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .frame(minWidth: 780, minHeight: 640)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .task {
                    manager.refreshToolStatus()
                }
        }
        .defaultSize(width: 1080, height: 760)
    }
}
