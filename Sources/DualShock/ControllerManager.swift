import AppKit
import GameController
import ControllerCore

struct ConnectedPad: Identifiable {
    let id: ObjectIdentifier
    let controller: GCController
    var name: String { controller.vendorName ?? "游戏手柄" }
    var kind: String { controller.productCategory }
    var battery: String {
        guard let battery = controller.battery, battery.batteryLevel >= 0 else { return "电量未知" }
        return "\(Int(battery.batteryLevel * 100))%" + (battery.batteryState == .charging ? " · 充电中" : "")
    }
}

struct InputState {
    var buttons: [PadButton: Double] = [:]
    var lx: Double = 0
    var ly: Double = 0
    var rx: Double = 0
    var ry: Double = 0
}

@MainActor
final class ControllerManager: ObservableObject {
    @Published var devices: [ConnectedPad] = []
    @Published var selectedID: ObjectIdentifier? { didSet { input = InputState(); sample() } }
    @Published var input = InputState()
    @Published var scanning = false
    @Published var demo = false { didSet { input = InputState() } }
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var tick = 0
    var selected: ConnectedPad? { devices.first { $0.id == selectedID } }

    init() {
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func refresh() {
        devices = GCController.controllers().map { ConnectedPad(id: ObjectIdentifier($0), controller: $0) }
        if !devices.contains(where: { $0.id == selectedID }) { selectedID = devices.first?.id }
    }

    func discover() {
        guard !scanning else { return }
        scanning = true
        GCController.startWirelessControllerDiscovery { [weak self] in
            Task { @MainActor in self?.stopDiscovery() }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            self?.stopDiscovery()
        }
    }

    func stopDiscovery() {
        guard scanning else { return }
        scanning = false
        GCController.stopWirelessControllerDiscovery()
        refresh()
    }

    func openBluetooth() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") { NSWorkspace.shared.open(url) }
    }

    func applyLight(_ profile: ControllerProfile) {
        guard !demo, let light = selected?.controller.light else { return }
        light.color = GCColor(red: Float(profile.lightRed), green: Float(profile.lightGreen), blue: Float(profile.lightBlue))
    }

    private func sample() {
        tick += 1
        if demo {
            let t = Double(tick) / 30
            var state = InputState()
            state.lx = sin(t) * 0.7
            state.ly = cos(t) * 0.7
            state.rx = sin(t * 0.6) * 0.4
            state.ry = cos(t * 0.6) * 0.4
            state.buttons[.a] = sin(t * 2) > 0.7 ? 1 : 0
            state.buttons[.leftTrigger] = (sin(t) + 1) / 2
            state.buttons[.rightTrigger] = (cos(t) + 1) / 2
            input = state
            return
        }
        guard let pad = selected?.controller.extendedGamepad else {
            input = InputState()
            return
        }
        let elements: [(PadButton, GCControllerButtonInput?)] = [
            (.a, pad.buttonA), (.b, pad.buttonB), (.x, pad.buttonX), (.y, pad.buttonY),
            (.leftShoulder, pad.leftShoulder), (.rightShoulder, pad.rightShoulder),
            (.leftTrigger, pad.leftTrigger), (.rightTrigger, pad.rightTrigger),
            (.up, pad.dpad.up), (.down, pad.dpad.down), (.left, pad.dpad.left), (.right, pad.dpad.right),
            (.leftStick, pad.leftThumbstickButton), (.rightStick, pad.rightThumbstickButton),
            (.menu, pad.buttonMenu), (.options, pad.buttonOptions)
        ]
        var state = InputState()
        for (key, button) in elements { state.buttons[key] = Double(button?.value ?? 0) }
        state.lx = Double(pad.leftThumbstick.xAxis.value)
        state.ly = Double(pad.leftThumbstick.yAxis.value)
        state.rx = Double(pad.rightThumbstick.xAxis.value)
        state.ry = Double(pad.rightThumbstick.yAxis.value)
        input = state
        if tick % 150 == 0 { refresh() }
    }
}
