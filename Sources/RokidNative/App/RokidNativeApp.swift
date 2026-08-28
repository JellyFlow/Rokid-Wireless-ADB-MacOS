import AppKit
import SwiftUI

@main
struct RokidNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup("Rokid 无线投屏助手", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1100, minHeight: 760)
                .preferredColorScheme(colorScheme)
                .environment(\.locale, store.appLanguage.locale)
        }
        .defaultSize(width: 1280, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(store.localized("设置…")) { store.selection = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(store.localized("设备")) {
                Button(store.localized("刷新设备")) { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                Button(store.localized("扫码连接投屏")) { store.openQR() }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button(store.localized("Rokid 使用说明")) { store.selection = .help }
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.preferredAppearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
