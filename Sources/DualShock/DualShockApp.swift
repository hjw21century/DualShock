import SwiftUI

@main
struct DualShockApp: App {
    @StateObject private var controllers = ControllerManager()
    @StateObject private var profiles = ProfileStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controllers)
                .environmentObject(profiles)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 720)
        }
        .defaultSize(width: 1180, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("复制当前配置") { profiles.duplicate() }.keyboardShortcut("n")
                Button("保存配置") { profiles.save() }.keyboardShortcut("s")
                Divider()
                Button("导入配置…") { profiles.importProfile() }
                Button("导出配置…") { profiles.exportProfile() }
            }
        }
    }
}
