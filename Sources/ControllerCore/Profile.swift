import Foundation

public enum PadButton: String, Codable, CaseIterable, Identifiable {
    case a, b, x, y, leftShoulder, rightShoulder, leftTrigger, rightTrigger
    case up, down, left, right, leftStick, rightStick, menu, options, home
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .a: return "A / ×"
        case .b: return "B / ○"
        case .x: return "X / □"
        case .y: return "Y / △"
        case .leftShoulder: return "LB / L1"
        case .rightShoulder: return "RB / R1"
        case .leftTrigger: return "LT / L2"
        case .rightTrigger: return "RT / R2"
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .leftStick: return "LS / L3"
        case .rightStick: return "RS / R3"
        case .menu: return "START / Menu"
        case .options: return "SELECT / Options"
        case .home: return "HOME"
        }
    }
}

public struct StickSettings: Codable, Equatable {
    public var deadzone: Double = 0.12
    public var sensitivity: Double = 1
    public var invertY = false
    public init() {}

    public func process(x: Double, y: Double) -> (x: Double, y: Double) {
        guard x.isFinite, y.isFinite else { return (0, 0) }
        let magnitude = hypot(x, y)
        let threshold = min(0.95, max(0, deadzone.isFinite ? deadzone : 0.12))
        guard magnitude > threshold else { return (0, 0) }
        let gain = min(2, max(0.2, sensitivity.isFinite ? sensitivity : 1))
        let output = min(1, (min(magnitude, 1) - threshold) / (1 - threshold) * gain)
        return (x / magnitude * output, y / magnitude * output * (invertY ? -1 : 1))
    }
}

public struct ControllerProfile: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var leftStick = StickSettings()
    public var rightStick = StickSettings()
    public var mapping: [String: PadButton] = [:]
    public var lightRed: Double = 0.32
    public var lightGreen: Double = 0.42
    public var lightBlue: Double = 1
    public init(name: String = "默认配置") { self.name = name }

    public func mapped(_ button: PadButton) -> PadButton { mapping[button.rawValue] ?? button }

    public func validated() throws -> ControllerProfile {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              [leftStick.deadzone, rightStick.deadzone].allSatisfy({ $0.isFinite && (0...0.95).contains($0) }),
              [leftStick.sensitivity, rightStick.sensitivity].allSatisfy({ $0.isFinite && (0.2...2).contains($0) }),
              [lightRed, lightGreen, lightBlue].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              mapping.keys.allSatisfy({ PadButton(rawValue: $0) != nil }) else {
            throw ProfileError.invalidProfile
        }
        return self
    }
}

public enum ProfileError: LocalizedError {
    case invalidProfile
    public var errorDescription: String? { "配置格式不正确：请检查名称、摇杆参数及灯光颜色。" }
}

public enum ProfileFile {
    public static func encode(_ profile: ControllerProfile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profile.validated())
    }
    public static func decode(_ data: Data) throws -> ControllerProfile {
        try JSONDecoder().decode(ControllerProfile.self, from: data).validated()
    }
}
