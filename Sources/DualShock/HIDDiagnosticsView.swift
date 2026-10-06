import SwiftUI

struct HIDDiagnosticsView: View {
    @EnvironmentObject private var monitor: HIDMonitor
    @EnvironmentObject private var controllers: ControllerManager
    @State private var selectedID: String?
    private var selected: HIDDeviceSnapshot? { monitor.devices.first { $0.id == selectedID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("蓝牙已连接，但应用没有输入？").font(.title2.bold())
            Text("此页读取系统公开的 HID 手柄及原始输入，不按蓝牙名称猜测型号，也不假定 Button 编号对应 A/B/X/Y。请依次按下实体按键并观察数值。")
                .foregroundStyle(.secondary).lineSpacing(4)
            HStack {
                Label(monitor.status, systemImage: monitor.running ? "waveform.path.ecg" : "pause.circle")
                Spacer()
                Button("重新检测") { monitor.retry() }
                Button("导出诊断…") { monitor.export() }
            }
            if let message = monitor.message { Text(message).font(.callout).foregroundStyle(.secondary) }
            HStack {
                Text("Game Controller：\(controllers.devices.count) 个设备")
                Divider().frame(height: 16)
                Text("HID：\(monitor.devices.count) 个接口")
            }.font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            Text("两种检测结果可能指向同一只手柄；HID 接口数量不等于实体手柄数量。此页始终显示真实设备，不使用演示数据。")
                .font(.caption).foregroundStyle(.secondary)

            if monitor.devices.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Label("尚未发现 HID 游戏手柄", systemImage: "gamecontroller").font(.headline)
                    Text("确认手柄已在蓝牙中连接，按下任意按键唤醒它；也可换用支持数据传输的 USB 线。若系统提示需要输入监控权限，请授权后重新打开应用。")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("蓝牙设置") { controllers.openBluetooth() }
                        Button("输入监控设置") { openInputMonitoring() }
                    }
                }.padding(20).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Picker("HID 设备", selection: $selectedID) {
                    Text("选择设备").tag(Optional<String>.none)
                    ForEach(monitor.devices) { device in
                        Text("\(device.name) · \(device.transport) · \(device.id)").tag(Optional(device.id))
                    }
                }
            }
            if let device = selected {
                VStack(alignment: .leading, spacing: 12) {
                    Text(device.name).font(.headline)
                    Text(String(format: "VID %04X   PID %04X   %@", device.vendorID, device.productID, device.transport))
                        .font(.callout.monospaced()).textSelection(.enabled)
                    HStack {
                        Text("已收到 \(device.receivedValues) 次元素更新").monospacedDigit()
                        Spacer()
                        if let last = device.lastInput { Text(last, style: .time) }
                    }.font(.caption).foregroundStyle(.secondary)
                    if device.lastInput == nil {
                        Text("等待输入。枚举成功并不代表已收到按键数据；移动摇杆或按键后再观察。")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    if device.readings.isEmpty {
                        Text("设备未提供可读取的标准输入元素。可导出诊断报告，进一步确认协议。")
                            .foregroundStyle(.secondary)
                    } else {
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                            GridRow {
                                Text("输入元素")
                                Text("Report / Cookie")
                                Text("原始值")
                                Text("逻辑范围")
                                Text("轴归一化")
                            }.font(.caption).foregroundStyle(.secondary)
                            Divider().gridCellColumns(5)
                            ForEach(device.readings) { reading in
                                GridRow {
                                    Text(reading.label)
                                    Text("\(reading.reportID) / \(reading.id)").foregroundStyle(.secondary)
                                    Text(reading.value.map(String.init) ?? "未收到")
                                        .foregroundStyle(reading.value == nil ? Color.secondary : Color.primary)
                                    Text("\(reading.logicalMin)…\(reading.logicalMax)").foregroundStyle(.secondary)
                                    Text(reading.normalizedAxis.map { String(format: "%+.3f", $0) } ?? "—")
                                }.font(.system(.caption, design: .monospaced))
                            }
                        }.textSelection(.enabled)
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
            Text("此页仅做输入诊断，不会将未知 HID 数据自动映射成游戏按键，也不会向设备发送灯光、震动或固件命令。诊断文件包含设备名称、VID/PID、连接类型及输入数值，不包含设备序列号。")
                .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .onChange(of: monitor.devices.map(\.id)) { _, ids in
            if !ids.contains(selectedID ?? "") { selectedID = ids.first }
        }
    }

    private func openInputMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
