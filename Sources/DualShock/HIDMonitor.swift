import AppKit
import IOKit.hid
import UniformTypeIdentifiers
import ControllerCore

struct HIDDeviceSnapshot: Identifiable, Codable {
    let id: String
    let name: String
    let vendorID: Int
    let productID: Int
    let transport: String
    var readings: [HIDReading]
    var receivedValues = 0
    var lastInput: Date?
}

/// This monitor is owned by the app; callbacks are scheduled exclusively on the main run loop.
/// It never seizes a device or sends output/feature reports.
@MainActor
final class HIDMonitor: ObservableObject {
    @Published private(set) var devices: [HIDDeviceSnapshot] = []
    @Published private(set) var status = "尚未开始检测"
    @Published private(set) var running = false
    @Published var message: String?
    private var manager: IOHIDManager?
    private var pending: [String: HIDDeviceSnapshot] = [:]
    private var timer: Timer?

    func start() {
        guard manager == nil else { return }
        pending = [:]
        devices = []
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        // Generic Desktop Joystick and Game Pad only: do not match keyboards or mice.
        let matches: [[String: Int]] = [4, 5].map {
            [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: $0]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard let context, result == kIOReturnSuccess else { return }
            MainActor.assumeIsolated {
                Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue().add(device)
            }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.pending.removeValue(forKey: monitor.identifier(device))
                monitor.publish()
            }
        }, context)
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard let context, result == kIOReturnSuccess else { return }
            MainActor.assumeIsolated {
                Unmanaged<HIDMonitor>.fromOpaque(context).takeUnretainedValue().receive(value)
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            stop()
            status = String(format: "HID 打开失败（0x%08X）。请检查系统输入监控权限后重试。", UInt32(bitPattern: result))
            return
        }
        running = true
        status = "检测中 · 仅读取手柄输入"
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.publish() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let manager {
            IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
            IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        running = false
        pending = [:]
        devices = []
        status = "检测已停止"
    }

    func retry() { stop(); start() }

    func export() {
        struct Report: Encodable {
            let appVersion = "0.2.0"
            let date = Date()
            let system = ProcessInfo.processInfo.operatingSystemVersionString
            let status: String
            let devices: [HIDDeviceSnapshot]
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "DualShock-HID-diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let report = Report(status: status, devices: devices)
            try encoder.encode(report).write(to: url, options: .atomic)
            message = "诊断报告已导出"
        } catch { message = "导出失败：\(error.localizedDescription)" }
    }

    private func identifier(_ device: IOHIDDevice) -> String {
        var id: UInt64 = 0
        if IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == kIOReturnSuccess {
            return String(id)
        }
        return String(describing: Unmanaged.passUnretained(device).toOpaque())
    }

    private func add(_ device: IOHIDDevice) {
        let id = identifier(device)
        guard pending[id] == nil else { return }
        func property(_ key: String) -> AnyObject? { IOHIDDeviceGetProperty(device, key as CFString) }
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []
        var readings: [HIDReading] = []
        for element in elements {
            let type = IOHIDElementGetType(element)
            guard type == kIOHIDElementTypeInput_Misc || type == kIOHIDElementTypeInput_Button || type == kIOHIDElementTypeInput_Axis else { continue }
            guard IOHIDElementGetReportSize(element) <= 32 else { continue }
            readings.append(HIDReading(
                id: IOHIDElementGetCookie(element), usagePage: IOHIDElementGetUsagePage(element),
                usage: IOHIDElementGetUsage(element), reportID: IOHIDElementGetReportID(element),
                logicalMin: IOHIDElementGetLogicalMin(element), logicalMax: IOHIDElementGetLogicalMax(element)))
        }
        pending[id] = HIDDeviceSnapshot(
            id: id, name: property(kIOHIDProductKey) as? String ?? "未命名 HID 手柄",
            vendorID: (property(kIOHIDVendorIDKey) as? NSNumber)?.intValue ?? 0,
            productID: (property(kIOHIDProductIDKey) as? NSNumber)?.intValue ?? 0,
            transport: property(kIOHIDTransportKey) as? String ?? "未知",
            readings: readings.sorted { $0.id < $1.id })
        publish()
    }

    private func receive(_ value: IOHIDValue) {
        guard IOHIDValueGetLength(value) <= 4 else { return }
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let id = identifier(device)
        guard var snapshot = pending[id],
              let index = snapshot.readings.firstIndex(where: { $0.id == IOHIDElementGetCookie(element) }) else { return }
        snapshot.readings[index].value = IOHIDValueGetIntegerValue(value)
        snapshot.receivedValues += 1
        snapshot.lastInput = Date()
        pending[id] = snapshot
    }

    private func publish() {
        devices = pending.values.sorted { ($0.name, $0.id) < ($1.name, $1.id) }
    }
}
