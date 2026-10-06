import AppKit
import UniformTypeIdentifiers
import ControllerCore

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ControllerProfile] = []
    @Published var draft = ControllerProfile()
    @Published var message: String?
    @Published var error: String?
    private let directory: URL
    private var selectedURL: URL { directory.appendingPathComponent("selected.txt") }
    var isDirty: Bool { profiles.first(where: { $0.id == draft.id }) != draft }

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DualShock/Profiles", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                do { profiles.append(try ProfileFile.decode(Data(contentsOf: file))) }
                catch { self.error = "无法读取 \(file.lastPathComponent)：\(error.localizedDescription)。原文件已保留。" }
            }
            profiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            let selected = try? String(contentsOf: selectedURL, encoding: .utf8)
            if let existing = profiles.first(where: { $0.id.uuidString == selected }) ?? profiles.first {
                draft = existing
            } else if !files.contains(where: { $0.pathExtension == "json" }) {
                save()
            }
        } catch { self.error = error.localizedDescription }
    }

    @discardableResult
    func save() -> Bool {
        do {
            let data = try ProfileFile.encode(draft)
            try data.write(to: file(for: draft.id), options: .atomic)
            if let index = profiles.firstIndex(where: { $0.id == draft.id }) { profiles[index] = draft }
            else { profiles.append(draft) }
            try draft.id.uuidString.write(to: selectedURL, atomically: true, encoding: .utf8)
            message = "配置已保存"
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func select(_ id: UUID) {
        guard id != draft.id else { return }
        if isDirty && !save() { return }
        if let profile = profiles.first(where: { $0.id == id }) {
            draft = profile
            do { try id.uuidString.write(to: selectedURL, atomically: true, encoding: .utf8) }
            catch { self.error = error.localizedDescription }
        }
    }

    func duplicate() {
        if isDirty && !save() { return }
        draft.id = UUID()
        draft.name = String((draft.name + " 副本").prefix(80))
        save()
    }

    func delete() {
        guard profiles.count > 1 else { return }
        do {
            try FileManager.default.removeItem(at: file(for: draft.id))
            profiles.removeAll { $0.id == draft.id }
            draft = profiles[0]
            try draft.id.uuidString.write(to: selectedURL, atomically: true, encoding: .utf8)
            message = "配置已删除"
        } catch { self.error = error.localizedDescription }
    }

    func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 1_048_576 else { throw ProfileError.invalidProfile }
            var imported = try ProfileFile.decode(data)
            if isDirty && !save() { return }
            imported.id = UUID()
            draft = imported
            save()
        } catch { self.error = error.localizedDescription }
    }

    func exportProfile() {
        do {
            let data = try ProfileFile.encode(draft)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "DualShock-profile.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            message = "配置已导出"
        } catch { self.error = error.localizedDescription }
    }

    private func file(for id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".json") }
}
