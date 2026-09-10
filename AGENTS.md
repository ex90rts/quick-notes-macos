# Quick Notes macOS 项目指南

本文件记录本项目已经验证过的测试、视觉验收和发布流程。不要在新任务中重新试错。

## 项目约束

- 目标平台是 macOS 15+、Apple Silicon（arm64）。
- `Package.swift` 是命令行构建入口；`QuickNotes.xcodeproj` 直接复用同一批源码和测试，不得复制出第二套实现。
- 除非用户明确要求，不要改变现有功能、数据格式、交互语义或视觉风格。
- UI 改动既要验证逻辑，也要检查真实运行效果；单元测试通过不等于视觉正确。

## 固定工具链

不要直接运行裸 `swift test` 或 `swift build`。系统 Command Line Tools 曾出现 Swift 编译器与 SDK 小版本不匹配；本项目已验证可用的是完整 Xcode Beta 工具链：

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

SwiftPM 的模块缓存和 scratch path 必须使用绝对路径。日常完整测试使用：

```sh
env \
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/quick-notes-module-cache \
  CLANG_MODULE_CACHE_PATH=/private/tmp/quick-notes-clang-cache \
  xcrun swift test --arch arm64 \
  --scratch-path /private/tmp/quick-notes-build
```

需要快速验证单个回归时，在同一命令末尾添加 `--filter '<测试名或模式>'`。完成局部验证后仍需运行一次完整测试。

如果正确命令因沙箱权限失败，下一次尝试应直接使用批准的沙箱外执行，不要改回系统 `swift` 或连续尝试不同的相对缓存路径。工具链/缓存错误必须与源码编译错误明确区分。

## 修改后的验证顺序

1. 运行与改动直接相关的定向测试；新增行为需覆盖正常路径和边界值。
2. 运行上面的完整测试命令，记录实际通过数量，不要在文档或汇报中写死历史测试数量。
3. 运行 `git diff --check`，再审阅改动范围，确认没有临时测试文件、构建产物或无关修改。
4. 只要用户要求打包，或需要交付可运行应用，就继续执行下方 Release 流程；不要用 Debug/旧的 `dist` 应用代替最终验收。

## UI 与“颜值”验收

除非用户在当前任务中明确要求，否则不得使用 Computer Use、CUA 或其他界面自动化工具操作、读取或截图检查真实应用。默认由用户完成人工视觉验收；Agent 只负责源码审阅、测试、构建和产物核验，并在汇报中明确未进行真实界面检查。

UI 修改应在实现和静态审阅时覆盖与改动有关的以下状态，供用户进行最终视觉验收：

- 浅色与暗色模式；颜色优先使用 `AppTheme` 中的 macOS 语义色，避免用固定白色或浅灰充当背景。
- 默认、hover、pressed、focused、selected、disabled 状态，以及弹窗、Popover、子页面返回按钮和输入框。
- 无滚动、刚越过阈值、深度滚动，以及列表第一项/最后一项等视口边界位置。
- 动画开启和“减少动态效果”状态；延迟 hover 任务必须能在鼠标移开时取消。
- Tooltip、菜单等浮层若要跨越 `ScrollView` 边界，必须在页面外层实际验证。提高 `zIndex` 不能突破父级裁剪；此类浮层应由页面级 overlay 根据锚点绘制。

对列表外观进行验收时，数据应覆盖短/长内容、有/无标题、有/无标签、链接、置顶和足够产生滚动的条目。未经用户明确授权，不得向真实持久化仓库写入测试数据；需要造数时使用一次性、可清理的测试辅助代码，并在结束后删除且检查 Git 状态。

用户进行视觉验收时应使用刚生成的 `dist/QuickNotes.app`。除非用户明确要求 Agent 使用界面自动化，否则人工观察由用户完成；汇报时不得仅凭测试通过宣称“视觉无误”。

## Release 打包

发布统一使用仓库脚本。脚本会运行完整测试、构建 arm64 Release、生成图标、检查最低系统版本、执行 ad-hoc 签名，并以暂存目录成功构建后再覆盖正式产物：

```sh
env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./scripts/build-release.sh
```

固定产物为：

- `dist/QuickNotes.app`
- `dist/QuickNotes-<version>-macOS-arm64.zip`
- `dist/QuickNotes-<version>-macOS-arm64.dmg`

脚本从 `Info.plist` 读取版本号并覆盖该版本对应的三个固定产物。不要手工拼装 `.app`、ZIP 或 DMG，也不要把 `.build/` 或 `dist/` 提交到 Git。

本项目用户已明确要求：每次完成应用代码、资源或配置改动，都必须修改 `Info.plist`，将 `CFBundleShortVersionString` 的补丁版本和 `CFBundleVersion` 各递增 1；然后执行完整 Release 打包与最终核验。不要把“实现功能”与“发布本次改动”拆开处理。

打包后执行最终核验：

```sh
/usr/bin/plutil -extract CFBundleShortVersionString raw dist/QuickNotes.app/Contents/Info.plist
/usr/bin/plutil -extract CFBundleVersion raw dist/QuickNotes.app/Contents/Info.plist
/usr/bin/lipo -archs dist/QuickNotes.app/Contents/MacOS/QuickNotes
/usr/bin/codesign --verify --strict --verbose=2 dist/QuickNotes.app
```

期望架构为 `arm64`，签名验证成功，应用内版本与 `Info.plist` 一致。

## 重启应用

本项目用户已明确要求：每次应用改动打包成功并通过最终核验后，都必须重启应用。先确认当前 Quick Notes 进程，再按 Bundle ID 正常退出并启动本次刚打包的绝对路径：

```sh
ps -axo pid=,command= | rg '[Q]uickNotes' || true
osascript -e 'tell application id "com.webber.QuickNotes" to quit'
open -n /Users/webber/Workspace/aboutme/quick-notes-macos/dist/QuickNotes.app
ps -axo pid=,command= | rg '[Q]uickNotes' || true
```

正常退出失败时，必须先确认准确 PID 和可执行文件路径，再决定是否结束该单一进程。不要使用宽泛的 `pkill`。GUI 启动或进程操作若被沙箱拦截，应走标准授权流程。
