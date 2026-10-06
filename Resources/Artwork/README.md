# 应用图标

`AppIcon.png` 是内置 image_gen 工具生成的透明背景原始图标。`scripts/build-icon.sh` 使用 macOS 自带的 `sips` 生成 16–1024 像素尺寸，通过 `iconutil` 输出 `dist/AppIcon.icns`，并提供 `dist/AppIcon-1024.png`。打包脚本将 ICNS 安装到 `.app/Contents/Resources`，由 `CFBundleIconFile` 引用。GitHub Actions 的 `DualShock-icons` artifact 提供这两种格式。

## 生成提示词

```text
Use case: stylized-concept. Asset type: production macOS application icon for DualShock controller management app. Create one square 1024x1024 icon: a premium dark graphite rounded-square macOS icon tile, with a centered sculpted gamepad viewed from slightly above, symmetric two short grips, distinctive two red thumbsticks, subtle lavender accent lighting, a simple D-pad on left and four small colored round buttons on right. Crisp polished 3D materials and restrained soft highlights, instantly legible silhouette at small Dock sizes. Tile occupies about 88% of canvas with generous transparent exterior corners, centered and straight, no perspective rotation of tile. Transparent background outside the rounded-square tile, not a checkerboard. No text, no letters, no logos, no watermark, no surrounding objects. Return a single finished icon, not a presentation sheet.
```
