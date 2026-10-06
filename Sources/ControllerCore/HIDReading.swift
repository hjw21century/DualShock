import Foundation

/// Descriptor-based diagnostics, deliberately independent of any vendor's button layout.
public struct HIDReading: Identifiable, Codable, Equatable {
    public let id: UInt32
    public let usagePage: UInt32
    public let usage: UInt32
    public let reportID: UInt32
    public let logicalMin: Int
    public let logicalMax: Int
    public var value: Int?

    public init(id: UInt32, usagePage: UInt32, usage: UInt32, reportID: UInt32,
                logicalMin: Int, logicalMax: Int, value: Int? = nil) {
        self.id = id
        self.usagePage = usagePage
        self.usage = usage
        self.reportID = reportID
        self.logicalMin = logicalMin
        self.logicalMax = logicalMax
        self.value = value
    }

    public var label: String {
        if usagePage == 9 { return "Button \(usage)" }
        if usagePage == 1 {
            let names: [UInt32: String] = [0x30: "X", 0x31: "Y", 0x32: "Z", 0x33: "Rx", 0x34: "Ry", 0x35: "Rz", 0x36: "Slider", 0x39: "Hat / 方向帽"]
            if let name = names[usage] { return name }
        }
        return String(format: "Usage %04X:%04X", usagePage, usage)
    }

    /// Only axes have a continuous normalized value. Null/out-of-range values stay unknown.
    public var normalizedAxis: Double? {
        guard usagePage == 1, (0x30...0x36).contains(usage), let value,
              logicalMax > logicalMin, (logicalMin...logicalMax).contains(value) else { return nil }
        return (Double(value) - Double(logicalMin)) / (Double(logicalMax) - Double(logicalMin)) * 2 - 1
    }
}
