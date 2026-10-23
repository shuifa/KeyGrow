# AGENTS.md — KeyGlow 开发与协同规范

> **本文档专为在 KeyGlow 项目中协同工作的 AI 编码助手（如 Antigravity、Claude Code、Cursor、GitHub Copilot 等）编写。**  
> 任何进入该代码库的 Agent 在理解需求、定位代码、实施变更或执行构建与提交前，应优先遵循本文档中的架构设计、开发规范与技术约束。

---

## 1. 项目概览 (Project Overview)

- **项目名称**：KeyGlow (KeyGrow)
- **定位**：轻量、极简、拟物高质感、无干扰穿透的 macOS 原生键盘操作可视化工具，专为屏幕录制、编程教学、设计演示、技术分享与直播打造。
- **目标平台**：macOS 14.0 (Sonoma) 及更高版本（Apple Silicon & Intel）
- **开发语言与编译器**：Swift 5.9 / 6.0，Xcode 15+ / 16+
- **核心技术栈**：
  - **UI 与动效**：原生 SwiftUI 5，结合 `phaseAnimator` 与 Spring 弹簧物理曲线。
  - **悬浮窗管理**：AppKit `NSPanel` + `NSHostingController`（鼠标穿透、全屏多桌面常驻、不夺焦点）。
  - **底层按键捕获**：CoreGraphics `CGEventTap` (`.listenOnly`) + Carbon TIS 键盘布局解析。
  - **菜单栏常驻**：`NSStatusItem` 菜单栏图标，提供启停、模式过滤、外观风格与偏好设置。
- **外部依赖**：**零外部三方依赖（Zero External Dependencies）**，完全基于 Apple 原生系统 Framework，无需 CocoaPods、Carthage 或 SPM 外部包。

---

## 2. 目录结构与模块职责 (Directory & Architecture)

```text
KeyGlow/
├── KeyGlow.xcodeproj/                 # Xcode 工程配置文件
├── KeyGlow/                           # 核心应用程序源码
│   ├── KeyGlowApp.swift               # SwiftUI App 入口，声明 Settings Scene，委托 AppDelegate
│   ├── App/                           # 生命周期与菜单栏常驻
│   │   ├── AppDelegate.swift          # 全局生命周期管理，初始化引擎与权限检测
│   │   ├── MenuBarManager.swift       # NSStatusItem 菜单栏控制器（模式、风格、启停）
│   │   └── PreferencesWindowController.swift # 偏好设置独立窗口控制器（单例）
│   ├── Services/                      # 后台监听与按键解析核心服务
│   │   ├── KeyMonitor.swift           # @MainActor 监听引擎 + 后台专用线程 KeyMonitorWorker
│   │   └── KeyCodeMapper.swift        # Carbon/CGEvent 键码解析、Unicode 提取与 SF Symbols 映射
│   ├── Models/                        # 数据模型与配置定义
│   │   ├── AppSettings.swift          # 用户偏好持久化（UserDefaults）、配置迁移、快照导入导出
│   │   ├── KeyStroke.swift            # 按键/组合键数据模型（含 SF Symbols / 修饰键等）
│   │   ├── KeycapTheme.swift          # 【配色单一数据源】RGB 基元、色板派生、6 套主题 × 昼夜双档、外观模式
│   │   ├── KeycapStyle.swift          # 键帽材质枚举（哑光实体、磨砂玻璃、极光染色，不含颜色）
│   │   ├── DisplayAnchor.swift        # 5 种屏幕定位锚点（底部居中、左下、右下、顶部、跟随光标）
│   │   └── DisplayMode.swift          # 显示过滤模式（仅快捷键模式、全按键模式）
│   ├── UI/                            # 原生界面与悬浮层组件
│   │   ├── OverlayPanelController.swift # KeyGlowPanel (穿透 NSPanel)、多显示器定位、外观模式绑定
│   │   ├── OverlayContentView.swift   # 按键队列容器（右进左出 Spring 动效、可选键帽托盘）
│   │   ├── KeycapView.swift           # 按键组合视图：按角色从主题取色 + 连按角标
│   │   ├── KeycapItemView.swift       # 单个键帽的材质/光照/排版渲染（颜色由外部传入 palette）
│   │   └── PreferencesView.swift      # 三页签偏好设置（外观 / 行为 / 高级）与实时预览
│   └── Assets.xcassets/               # 应用图标（16x16 ~ 1024x1024 全套尺寸）与色彩集
├── KeyGlowTests/                      # 单元测试（按键映射、修饰键排序、就地升级等）
│   └── KeyGlowTests.swift
├── KeyGlowUITests/                    # UI 自动化测试
│   └── KeyGlowUITests.swift
└── .github/workflows/                 # CI/CD 自动化流水线
    ├── ci.yml                         # 持续集成：代码编译与单元测试
    └── release.yml                    # 自动化发布：编译 Release、制作高清 icns、打包 DMG
```

---

## 3. 构建、测试与运行命令 (Build & Test Commands)

### 3.1 命令行编译环境配置
在部分 macOS 环境下，默认命令行可能指向 Command Line Tools，导致 `xcodebuild` 提示找不到 Xcode：
```bash
# 若遇 xcode-select: error: tool 'xcodebuild' requires Xcode，可显式指定 Xcode 路径：
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

### 3.2 调试构建 (Debug Build)
```bash
# 标准调试编译（CODE_SIGNING_ALLOWED=NO 避免本地签名证书缺失问题）
xcodebuild clean build \
  -project KeyGlow.xcodeproj \
  -scheme KeyGlow \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

# 沙箱环境或避免写入用户 Library 时，可指定局部 DerivedData：
xcodebuild clean build \
  -project KeyGlow.xcodeproj \
  -scheme KeyGlow \
  -destination 'platform=macOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

### 3.3 运行单元测试 (Unit Tests)
```bash
# 执行单元测试用例
xcodebuild test \
  -project KeyGlow.xcodeproj \
  -scheme KeyGlow \
  -destination 'platform=macOS' \
  -only-testing:KeyGlowTests \
  CODE_SIGNING_ALLOWED=NO
```

### 3.4 Release 打包与 DMG 生成
打包流程定义于 `.github/workflows/release.yml`，本地如需完整验证：
```bash
# 1. 编译 Release
xcodebuild clean build \
  -project KeyGlow.xcodeproj \
  -scheme KeyGlow \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO

# 2. 生成全套标准 AppIcon.icns
mkdir -p icon_staging.iconset
cp KeyGlow/Assets.xcassets/AppIcon.appiconset/icon_*.png icon_staging.iconset/
iconutil -c icns icon_staging.iconset -o ./DerivedData/Build/Products/Release/KeyGlow.app/Contents/Resources/AppIcon.icns
rm -rf icon_staging.iconset

# 3. 使用 hdiutil 制作 UDZO 只读高压缩 DMG
mkdir -p dmg_staging
ditto ./DerivedData/Build/Products/Release/KeyGlow.app dmg_staging/KeyGlow.app
ln -s /Applications dmg_staging/Applications
hdiutil create -volname "KeyGlow" -srcfolder dmg_staging -ov -format UDZO "KeyGlow-output.dmg"
rm -rf dmg_staging
```

---

## 4. 关键技术约束与避坑指南 (Critical Constraints & Gotchas)

### 4.1 CGEventTap 监听与权限保护
- **必须使用 `.listenOnly` 模式**：
  KeyGlow 仅作可视化呈现，绝不可拦截、修改或吞掉键盘事件（不能使用 `.defaultTap`）。
- **超时与禁用自愈机制**：
  当系统高负载导致超时，事件会收到 `.tapDisabledByTimeout` 或 `.tapDisabledByUserInput`。在 `handleEvent` 中必须捕获该信号并执行 `CGEvent.tapEnable(tap: tap, enable: true)` 恢复监听。
- **密码安全输入（Secure Event Input）静默降级**：
  在处理按键前必须检查 `IsSecureEventInputEnabled()`。当用户在 Terminal `sudo`、系统密码框或浏览器密码字段输入时，必须直接静默 `return`，绝不记录、展示或崩溃，严格保护用户隐私安全。
- **辅助功能权限（Accessibility）**：
  通过 `AXIsProcessTrusted()` 检查权限。未授权时优雅在 UI 提示引导用户前往「系统设置 -> 隐私与安全性 -> 辅助功能」，严禁强退应用。

### 4.2 悬浮窗 (KeyGlowPanel) 与穿透机制
- **完全鼠标穿透与无焦点**：
  - `KeyGlowPanel` 必须设置 `ignoresMouseEvents = true`，鼠标手势与滚轮 100% 穿透到底层窗口。
  - 重写 `canBecomeKey` 与 `canBecomeMain` 恒返回 `false`，确保打字时绝对不抢夺焦点。
  - 配置 `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`，保证跨虚拟桌面与全屏应用常驻。
- **防 NSHostingController 尺寸死循环**：
  在 `OverlayPanelController.swift` 中，`NSHostingController` 必须设置：
  ```swift
  hostingController.sizingOptions = []
  ```
  严禁将动态 SwiftUI 尺寸反向推给 `NSPanel` 约束，否则会导致 Auto Layout 递归更新死锁崩溃。

### 4.3 按键队列与修饰键连按升级逻辑
- **队列容量**：`activeStrokes` 最多保留 **3 个** 按键。超额时移除最左侧最早按下的元素。
- **动效方向**：严格遵循「**右边进、左边出**」流式过渡。
- **修饰键就地升级（In-place Replacement）**：
  - 单按修饰键（如按住 `⌘`）时立即展示卡片。
  - 若修饰键尚未松开，用户继续按下另一个修饰键（如 `⌥`）或普通键（如 `C`），**必须就地升级替换最后一个未松开的卡片**，而不是在队列中生成多个碎片卡片。
  - 用户松开所有修饰键后，下一次按键作为新卡片插入。
- **Fn / Globe 键识别**：
  现代 Mac 键盘 Globe/Fn 键码为 `179`，传统 Mac 键盘为 `63`。在 `KeyCodeMapper` 中必须正确解析为 `globe` SF Symbol 与 `"Fn"` 文本，禁止展示为未经映射的 `Key_179`。

### 4.4 Swift 6 与并发模型（Concurrency）
- `KeyMonitor` 标记为 `@MainActor`，所有对 UI 绑定的状态修改（`activeStrokes`、`punchTrigger`）必须在主线程调度。
- `KeyMonitorWorker` 运行在专有底层 `Thread`，回调通过 `Task { @MainActor in callback(...) }` 派发。
- 遵循 `Sendable` 约束，跨并发域传递的数据结构（如 `KeyStroke`）必须保证不可变且线程安全。

---

## 5. 编码规范与风格 (Code Style)

1. **命名规范**：
   - 遵循 Swift 官方 API Design Guidelines，采用清晰、具象的驼峰命名法（CamelCase）。
   - 视图组件后缀为 `View`（如 `KeycapItemView`），控制器后缀为 `Controller` / `Manager`。
2. **注释与文档**：
   - 保留文件顶部原有的版权与作者注释头。
   - 保留所有已存在的注释和文档字符串（docstrings）。
   - 关键算法（如键码解析、Spring 动效计算、状态机流转）必须配以清晰明了的中文注释。
3. **架构克制性**：
   - 严格遵循项目的极简克制原则，除非需求明确要求，否则不得引入庞杂的功能配置或无关的第三方库。

---

## 6. Git 协作与提交规范 (Git & Release Conventions)

### 6.1 分支管理
- `main`：稳定主分支，受保护分支。
- 任务分支：采用语义化前缀，例如：
  - `feat/...`：新增功能
  - `fix/...`：问题修复
  - `docs/...`：文档编写与更新
  - `refactor/...`：代码重构

### 6.2 提交信息规范 (Conventional Commits)
严格按照 Conventional Commits 规范格式书写提交信息：
```text
<type>(<scope>): <subject>
```
常见 `type` 类型：
- `feat`：新特性
- `fix`：修复 Bug
- `docs`：文档调整（如 `docs: add AGENTS.md`）
- `refactor`：重构（既不是新增功能也不是修复 bug 的代码变动）
- `test`：增加或修正测试
- `chore`：构建过程、辅助工具变动或版本发布
- `ci`：CI/CD 配置文件与脚本修改

### 6.3 版本号管理规则（⚠️ 核心禁忌）
- **严禁在普通开发或常规提交中擅自递增版本号**（包括但不限于 `KeyGlow.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION` 或 `CURRENT_PROJECT_VERSION`）。
- 版本号递增仅在正式发布流程中，由专属 Release 任务统一执行（例如 `chore(release): bump version to 0.6.0`）。

---

## 7. AI Agent 协作清单 (Agent Task Checklist)

在为 KeyGlow 实施任何代码变更时，请按顺序检查：
- [ ] 1. **确认意图**：是否符合简单克制、原生高性能、视觉精致的设计哲学？
- [ ] 2. **无外部依赖**：是否依赖了未经允许的三方库？
- [ ] 3. **主线程隔离**：所有更新 UI 的属性与视图操作是否都在 `@MainActor`？
- [ ] 4. **穿透与焦点安全**：是否破坏了 `NSPanel` 的穿透、无焦点以及 `sizingOptions = []` 保护？
- [ ] 5. **隐私与自愈**：是否保留了密码输入静默降级与 CGEventTap 超时自愈逻辑？
- [ ] 6. **编译验证**：使用 `xcodebuild` 命令完成编译，无新增 Warning。
- [ ] 7. **测试覆盖**：新增或修改逻辑是否补充了单元测试？所有现有测试是否均通过？
- [ ] 8. **提交规范**：是否使用了新分支？提交信息是否遵循 Conventional Commits？是否避免了无故修改版本号？
