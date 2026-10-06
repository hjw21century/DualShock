import SwiftUI
import ControllerCore

private let accent = Color(red: 0.57, green: 0.52, blue: 1)
private let panelColor = Color(red: 0.10, green: 0.11, blue: 0.15)

enum Page: String, CaseIterable, Identifiable {
    case overview = "设备概览", inputs = "输入测试", mapping = "按键映射", sticks = "摇杆设置", profiles = "配置管理"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "gamecontroller"
        case .inputs: return "waveform.path.ecg"
        case .mapping: return "arrow.triangle.branch"
        case .sticks: return "slider.horizontal.3"
        case .profiles: return "square.stack.3d.up"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var controllers: ControllerManager
    @EnvironmentObject private var profiles: ProfileStore
    @State private var page: Page = .overview
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if controllers.demo {
                            Label("演示模式 · 当前数据为模拟输入，不会控制真实设备", systemImage: "play.rectangle")
                                .font(.callout).foregroundStyle(.orange).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        switch page {
                        case .overview: overview
                        case .inputs: inputs
                        case .mapping: mapping
                        case .sticks: sticks
                        case .profiles: profileManagement
                        }
                    }.padding(28)
                }
                footer
            }
        }
        .background(Color(red: 0.065, green: 0.073, blue: 0.10))
        .tint(accent)
        .alert("操作未完成", isPresented: Binding(get: { profiles.error != nil }, set: { if !$0 { profiles.error = nil } })) {
            Button("好") { profiles.error = nil }
        } message: { Text(profiles.error ?? "") }
        .confirmationDialog("删除“\(profiles.draft.name)”？", isPresented: $confirmingDelete) {
            Button("删除配置", role: .destructive) { profiles.delete() }
        } message: { Text("此操作会删除本地配置文件。") }
        .onChange(of: profiles.draft) { _, _ in profiles.message = nil }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill").font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("DualShock").font(.system(size: 19, weight: .bold))
                    Text("CONTROLLER STUDIO").font(.system(size: 8, weight: .medium)).tracking(2).foregroundStyle(.secondary)
                }
            }.padding(.top, 35)
            VStack(alignment: .leading, spacing: 6) {
                Text("工作空间").font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
                ForEach(Page.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).frame(width: 20)
                            Text(item.rawValue)
                            Spacer()
                            if page == item { Circle().fill(accent).frame(width: 5, height: 5) }
                        }.padding(12).foregroundStyle(page == item ? .white : .secondary)
                            .background(page == item ? accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("已连接设备").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(controllers.devices.count)").font(.caption.monospacedDigit()).foregroundStyle(accent)
                }
                if controllers.devices.isEmpty {
                    Text("暂无设备\n通过 USB 或蓝牙连接手柄")
                        .font(.caption).foregroundStyle(.secondary).lineSpacing(6)
                }
                ForEach(controllers.devices) { device in
                    Button {
                        controllers.demo = false
                        controllers.selectedID = device.id
                    } label: {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text(device.name).lineLimit(2)
                            Spacer(minLength: 0)
                            if controllers.selectedID == device.id { Circle().fill(.green).frame(width: 6, height: 6) }
                        }.font(.caption).padding(10)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            Toggle("演示模式", isOn: $controllers.demo).toggleStyle(.switch).controlSize(.small)
            Text("macOS 14+  ·  v0.1.0").font(.caption2).foregroundStyle(.tertiary)
        }.padding(.horizontal, 20).padding(.bottom, 20).frame(width: 220)
            .background(Color(red: 0.08, green: 0.085, blue: 0.12))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(page.rawValue).font(.system(size: 24, weight: .semibold))
                Text("让每一次操作，都恰到好处。").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !profiles.profiles.isEmpty {
                Picker("配置", selection: Binding(get: { profiles.draft.id }, set: { profiles.select($0) })) {
                    ForEach(profiles.profiles) { Text($0.name).tag($0.id) }
                }.frame(width: 210)
            }
            Button { profiles.save() } label: { Label("保存配置", systemImage: "checkmark") }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }.padding(.horizontal, 28).padding(.vertical, 25)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(controllers.demo ? .orange : controllers.selected == nil ? .gray : .green).frame(width: 6, height: 6)
            Text(controllers.demo ? "模拟设备" : controllers.selected == nil ? "等待连接手柄" : "设备已连接")
            Spacer()
            Text(profiles.isDirty ? "有未保存的更改" : profiles.message ?? "配置已保存至本机")
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 28).padding(.vertical, 12)
            .background(.black.opacity(0.15))
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                metric("设备状态", value: controllers.demo ? "演示中" : controllers.selected == nil ? "未连接" : "已连接", icon: "dot.radiowaves.left.and.right")
                metric("剩余电量", value: controllers.demo ? "模拟数据" : controllers.selected?.battery ?? "—", icon: "battery.75percent")
                metric("当前配置", value: profiles.draft.name, icon: "slider.horizontal.3")
            }
            card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(controllers.demo ? "演示手柄" : controllers.selected?.name ?? "准备好连接了吗？").font(.title2.bold())
                        Text(controllers.selected?.kind ?? "连接你的手柄，开始探索每一个按键。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(controllers.demo ? "DEMO" : "GAME CONTROLLER").font(.caption2.bold()).tracking(2).foregroundStyle(accent)
                }
                ControllerDiagram(input: controllers.input).frame(height: 260)
                HStack {
                    Label("实时输入可视化", systemImage: "waveform.path").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("输入测试") { page = .inputs }.buttonStyle(.bordered)
                }
            }
            if controllers.selected == nil && !controllers.demo { connectionHelp }
            if let selected = controllers.selected, selected.controller.extendedGamepad == nil {
                Label("此设备不提供扩展手柄输入，暂无法显示完整测试数据。", systemImage: "info.circle").foregroundStyle(.orange)
            }
            card {
                Label("灯光颜色", systemImage: "lightbulb.led.fill").font(.headline)
                HStack(spacing: 12) {
                    ForEach(0..<6) { index in
                        let colors: [(Double, Double, Double)] = [(0.32, 0.42, 1), (0.65, 0.3, 1), (1, 0.25, 0.42), (1, 0.65, 0.15), (0.2, 0.85, 0.55), (0.2, 0.75, 1)]
                        let rgb = colors[index]
                        Button {
                            profiles.draft.lightRed = rgb.0
                            profiles.draft.lightGreen = rgb.1
                            profiles.draft.lightBlue = rgb.2
                        } label: {
                            Circle().fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2)).frame(width: 26, height: 26)
                                .overlay(Circle().stroke(.white, lineWidth: profiles.draft.lightRed == rgb.0 && profiles.draft.lightGreen == rgb.1 ? 2 : 0).padding(-4))
                        }.buttonStyle(.plain).accessibilityLabel("灯光预设 \(index + 1)")
                    }
                    Spacer()
                    Button("应用到手柄") { controllers.applyLight(profiles.draft) }
                        .disabled(controllers.demo || controllers.selected?.controller.light == nil)
                }
                Text(controllers.selected?.controller.light == nil ? "当前设备未提供灯光控制，可先保存颜色预设。" : "点击应用可设置当前手柄灯光；其他应用可能覆盖该颜色。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var connectionHelp: some View {
        card {
            Label("连接你的第一只手柄", systemImage: "cable.connector").font(.headline)
            Text("USB：用数据线将手柄连接至 Mac。\n蓝牙：将手柄置于配对模式，在系统蓝牙设置中完成配对后返回。")
                .foregroundStyle(.secondary).lineSpacing(6)
            HStack {
                Button("打开蓝牙设置") { controllers.openBluetooth() }.buttonStyle(.borderedProminent)
                Button(controllers.scanning ? "正在搜索…" : "搜索手柄") { controllers.discover() }.disabled(controllers.scanning)
                if controllers.scanning { ProgressView().controlSize(.small) }
            }
        }
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("按下按键或移动摇杆，查看设备报告的原始输入。").foregroundStyle(.secondary)
            if controllers.selected == nil && !controllers.demo { connectionHelp }
            card { ControllerDiagram(input: controllers.input).frame(height: 240) }
            HStack(spacing: 18) {
                stickMonitor("左摇杆 · 原始", x: controllers.input.lx, y: controllers.input.ly, deadzone: 0)
                stickMonitor("右摇杆 · 原始", x: controllers.input.rx, y: controllers.input.ry, deadzone: 0)
            }
            card {
                Text("按键与扳机").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 12) {
                    ForEach(PadButton.allCases) { button in
                        let value = controllers.input.buttons[button] ?? 0
                        VStack(spacing: 8) {
                            Text(button.label).font(.system(.body, design: .monospaced).bold())
                            ProgressView(value: value)
                            Text(value, format: .number.precision(.fractionLength(2))).font(.caption.monospacedDigit())
                        }.padding(14).frame(maxWidth: .infinity)
                            .background(value > 0.05 ? accent.opacity(0.25) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var mapping: some View {
        VStack(alignment: .leading, spacing: 20) {
            scopeNote
            card {
                HStack {
                    Text("按键映射预设").font(.headline)
                    Spacer()
                    Button("恢复默认映射") { profiles.draft.mapping = [:] }
                }
                ForEach(PadButton.allCases) { button in
                    HStack {
                        Text(button.label).frame(width: 90, alignment: .leading)
                        Circle().fill((controllers.input.buttons[button] ?? 0) > 0.1 ? accent : .gray.opacity(0.3)).frame(width: 7, height: 7)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        Picker("输出", selection: Binding(get: { profiles.draft.mapped(button) }, set: { profiles.draft.mapping[button.rawValue] = $0 })) {
                            ForEach(PadButton.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 170)
                    }.padding(.vertical, 5)
                    if button != PadButton.allCases.last { Divider().opacity(0.4) }
                }
            }
            card {
                Text("映射输出预览").font(.headline)
                let pressed = PadButton.allCases.filter { (controllers.input.buttons[$0] ?? 0) > 0.1 }
                Text(pressed.isEmpty ? "等待按键输入…" : pressed.map { "\($0.label) → \(profiles.draft.mapped($0).label)" }.joined(separator: "    "))
                    .foregroundStyle(pressed.isEmpty ? .secondary : accent)
            }
        }
    }

    private var sticks: some View {
        VStack(alignment: .leading, spacing: 22) {
            scopeNote
            HStack(alignment: .top, spacing: 18) {
                stickEditor("左摇杆", settings: $profiles.draft.leftStick, x: controllers.input.lx, y: controllers.input.ly)
                stickEditor("右摇杆", settings: $profiles.draft.rightStick, x: controllers.input.rx, y: controllers.input.ry)
            }
            card {
                Label("如何调整死区", systemImage: "info.circle").font(.headline)
                Text("松开摇杆，观察原始输入是否偏离中心。逐步增大死区，直到预览输出稳定归零。灵敏度控制死区外的输入增益，输出最大为 1。")
                    .foregroundStyle(.secondary).lineSpacing(5)
            }
        }
    }

    private var profileManagement: some View {
        VStack(alignment: .leading, spacing: 22) {
            card {
                Text("当前配置").font(.headline)
                TextField("配置名称", text: $profiles.draft.name).textFieldStyle(.roundedBorder)
                Text("配置保存到本机 Application Support/DualShock/Profiles。切换配置时会自动保存当前更改，退出前请点击保存。")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("复制为新配置") { profiles.duplicate() }
                    Button("导入 JSON…") { profiles.importProfile() }
                    Button("导出 JSON…") { profiles.exportProfile() }
                    Spacer()
                    Button("删除", role: .destructive) { confirmingDelete = true }.disabled(profiles.profiles.count < 2)
                }
            }
            ForEach(profiles.profiles) { profile in
                card {
                    HStack {
                        Image(systemName: "doc.text").font(.title2).foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(profile.name).font(.headline)
                            Text("左摇杆死区 \(Int(profile.leftStick.deadzone * 100))% · 右摇杆死区 \(Int(profile.rightStick.deadzone * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(profile.id == profiles.draft.id ? "使用中" : "使用配置") { profiles.select(profile.id) }
                            .disabled(profile.id == profiles.draft.id)
                    }
                }
            }
            scopeNote
        }
    }

    private var scopeNote: some View {
        Label("映射、死区和灵敏度用于本应用的配置与输出预览，不会修改其他游戏的输入。", systemImage: "info.circle")
            .font(.callout).foregroundStyle(.secondary).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func stickEditor(_ title: String, settings: Binding<StickSettings>, x: Double, y: Double) -> some View {
        let output = settings.wrappedValue.process(x: x, y: y)
        return card {
            Text(title).font(.headline)
            StickPlot(x: output.x, y: output.y, deadzone: settings.wrappedValue.deadzone).frame(height: 175)
            Text(String(format: "输出 X %+.3f    Y %+.3f", output.x, output.y)).font(.caption.monospaced())
            Text(String(format: "原始 X %+.3f    Y %+.3f", x, y)).font(.caption.monospaced()).foregroundStyle(.secondary)
            HStack { Text("死区"); Spacer(); Text("\(Int(settings.wrappedValue.deadzone * 100))%").monospacedDigit() }
            Slider(value: settings.deadzone, in: 0...0.5, step: 0.01)
            HStack { Text("灵敏度"); Spacer(); Text(String(format: "%.2f×", settings.wrappedValue.sensitivity)).monospacedDigit() }
            Slider(value: settings.sensitivity, in: 0.2...2, step: 0.05)
            Toggle("反转 Y 轴", isOn: settings.invertY)
            Button("恢复默认") { settings.wrappedValue = StickSettings() }
        }
    }

    private func stickMonitor(_ title: String, x: Double, y: Double, deadzone: Double) -> some View {
        card {
            Text(title).font(.headline)
            StickPlot(x: x, y: y, deadzone: deadzone).frame(height: 140)
            Text(String(format: "X %+.3f    Y %+.3f", x, y)).font(.caption.monospaced()).frame(maxWidth: .infinity)
        }
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        card {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 19, weight: .semibold)).lineLimit(1)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18, content: content)
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(panelColor, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.055), lineWidth: 1))
    }
}

struct StickPlot: View {
    let x: Double
    let y: Double
    let deadzone: Double
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(.black.opacity(0.12))
                Circle().stroke(.white.opacity(0.15), lineWidth: 1)
                Circle().fill(accent.opacity(0.14)).frame(width: size * deadzone, height: size * deadzone)
                Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1)
                Circle().fill(accent).frame(width: 12, height: 12)
                    .shadow(color: accent.opacity(0.5), radius: 6)
                    .offset(x: x * (size / 2 - 6), y: -y * (size / 2 - 6))
            }.frame(width: size, height: size).frame(maxWidth: .infinity, maxHeight: .infinity)
        }.accessibilityLabel(String(format: "摇杆 X %.2f, Y %.2f", x, y))
    }
}

struct ControllerDiagram: View {
    let input: InputState
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 520, geometry.size.height / 260)
            ZStack {
                ControllerShell().fill(LinearGradient(colors: [Color(white: 0.27), Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                    .overlay(ControllerShell().stroke(Color(white: 0.38), lineWidth: 2))
                    .shadow(color: .black.opacity(0.4), radius: 15, y: 12)
                RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.12)).frame(width: 140, height: 75).position(x: 260, y: 72)
                RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 110, height: 3).shadow(color: accent, radius: 6).position(x: 260, y: 32)
                key(.up, symbol: "↑", x: 121, y: 67)
                key(.down, symbol: "↓", x: 121, y: 123)
                key(.left, symbol: "←", x: 93, y: 95)
                key(.right, symbol: "→", x: 149, y: 95)
                key(.y, symbol: "△", x: 399, y: 64)
                key(.a, symbol: "×", x: 399, y: 126)
                key(.x, symbol: "□", x: 368, y: 95)
                key(.b, symbol: "○", x: 430, y: 95)
                analog(x: input.lx, y: input.ly).position(x: 192, y: 162)
                analog(x: input.rx, y: input.ry).position(x: 328, y: 162)
                Image(systemName: "gamecontroller.fill").foregroundStyle(accent.opacity(0.8)).position(x: 260, y: 152)
                Text("L1 / L2").font(.caption2.monospaced()).foregroundStyle(.secondary).position(x: 126, y: 18)
                Text("R1 / R2").font(.caption2.monospaced()).foregroundStyle(.secondary).position(x: 394, y: 18)
            }.frame(width: 520, height: 260).scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityLabel("手柄实时按键示意图")
    }

    private func key(_ button: PadButton, symbol: String, x: Double, y: Double) -> some View {
        Text(symbol).font(.system(size: 19, weight: .medium))
            .frame(width: 29, height: 29)
            .background((input.buttons[button] ?? 0) > 0.1 ? accent : Color(white: 0.095), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1)).position(x: x, y: y)
    }

    private func analog(x: Double, y: Double) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.08)).frame(width: 62, height: 62)
            Circle().fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                .frame(width: 45, height: 45).overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                .offset(x: x * 9, y: -y * 9)
        }
    }
}

private struct ControllerShell: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 135, y: 27))
        p.addCurve(to: CGPoint(x: 65, y: 92), control1: CGPoint(x: 85, y: 20), control2: CGPoint(x: 70, y: 53))
        p.addCurve(to: CGPoint(x: 52, y: 222), control1: CGPoint(x: 49, y: 145), control2: CGPoint(x: 32, y: 209))
        p.addCurve(to: CGPoint(x: 124, y: 214), control1: CGPoint(x: 71, y: 246), control2: CGPoint(x: 103, y: 244))
        p.addLine(to: CGPoint(x: 157, y: 179))
        p.addQuadCurve(to: CGPoint(x: 363, y: 179), control: CGPoint(x: 260, y: 200))
        p.addLine(to: CGPoint(x: 396, y: 214))
        p.addCurve(to: CGPoint(x: 468, y: 222), control1: CGPoint(x: 417, y: 244), control2: CGPoint(x: 449, y: 246))
        p.addCurve(to: CGPoint(x: 455, y: 92), control1: CGPoint(x: 488, y: 209), control2: CGPoint(x: 471, y: 145))
        p.addCurve(to: CGPoint(x: 385, y: 27), control1: CGPoint(x: 450, y: 53), control2: CGPoint(x: 435, y: 20))
        p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width / 520, y: rect.height / 260))
    }
}
