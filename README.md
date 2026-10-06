# DualShock

面向 **macOS 14.0+（目标系统 14.7.2）** 的原生游戏手柄管理与配置应用，使用 SwiftUI 和 Apple Game Controller 框架，无第三方运行时依赖。支持 Apple Silicon 与 Intel Mac。

## 当前功能

- 自动枚举、切换和监测连接/断开的手柄，支持系统识别的扩展游戏手柄。
- 实时显示按键、方向键、双摇杆与模拟扳机输入；读取设备提供的电池信息。
- 深色中文界面，包含设备概览、输入测试、按键映射、摇杆设置和配置管理。
- 按键映射预设、径向死区、灵敏度与 Y 轴反转，实时查看处理后的输入。
- 支持设备的 LED 颜色设置；不支持的设备禁用应用按钮。
- 配置本地持久化、复制、删除及 JSON 导入/导出。导入校验参数范围，写入采用原子操作。
- 明确标记的演示模式，无手柄也能检查界面和配置处理。

**作用范围：** 按键映射和摇杆参数只影响本应用的输出预览，不会向其他游戏注入输入，也不会更改手柄固件。LED 应用按钮会控制选中设备的灯光。当前不提供虚拟手柄驱动、全局键鼠映射、固件升级、自适应扳机或震动控制；若需要这些功能，需要独立实现并进行真机验证。

## 构建与运行

在 macOS 14.7.2 上安装支持 macOS 14 的 Xcode / Command Line Tools：

```bash
xcode-select --install
git clone https://github.com/hjw21century/DualShock.git
cd DualShock
swift test
bash scripts/build-app.sh
open dist/DualShock.app
```

也可以用 Xcode 打开 `Package.swift`，选择 DualShock scheme 后运行。打包脚本构建 arm64 / x86_64 通用二进制，并生成 `.app` 与 ZIP。GitHub Actions 在每次提交时执行测试、构建并上传安装包 artifact。

构建产物采用本地 ad-hoc 签名，尚未使用 Developer ID 签名或公证。首次打开下载的产物时，macOS 可能需要在“系统设置 → 隐私与安全性”中允许打开。正式分发需配置开发者签名与 Apple 公证。

## 使用

1. USB 数据线连接手柄，或在系统蓝牙设置中先完成配对；设备会自动出现在侧栏。
2. 选择设备，在“输入测试”中检查原始输入。系统或设备不提供的电量显示“电量未知”。
3. 调整映射与摇杆参数，观察应用内输出预览；点击“保存配置”或按 `⌘S` 保存。
4. 灯光支持取决于设备与系统。选择颜色后点击“应用到手柄”，配置切换不会自动改变硬件灯光。
5. 在“配置管理”复制或导入配置；切换时会保存当前修改，退出前请主动保存。

配置保存在 `~/Library/Application Support/DualShock/Profiles/`。不能解析的文件会保留并报错，不会静默覆盖。

## 项目结构

```text
Sources/ControllerCore/       配置模型、输入变换、导入校验
Sources/DualShock/            SwiftUI 界面、设备发现与输入采样、配置存储
Tests/ControllerCoreTests/    死区、归一化、反转、配置往返与非法输入测试
Resources/Info.plist          macOS 应用信息
scripts/build-app.sh          通用 .app 打包脚本
.github/workflows/macos.yml   macOS 测试与构建
```

## 验证范围

开发环境为 Linux，无法在本机运行 Apple 框架或进行 macOS 真机测试。macOS 编译结果以仓库 Actions 为准。发布前请在 macOS 14.7.2 验证：USB/蓝牙接入、断开重连、多手柄切换、休眠唤醒、电池信息、灯光控制，以及配置保存后重启恢复。

初始提供的两张参考图 URL 返回 HTTP 401，当前界面是独立设计，尚未根据参考图逐项还原。

框架参考：[Apple GCController](https://developer.apple.com/documentation/gamecontroller/gccontroller)、[设备灯光](https://developer.apple.com/documentation/gamecontroller/gcdevicelight)。
