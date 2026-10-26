# KeyGlow (KeyGrow) ⌨️✨

<p align="center">
  <img src="KeyGlow/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="KeyGlow Icon" />
</p>

<p align="center">
  <strong>一款轻量、极简、动画优雅丝滑的 macOS 原生键盘操作可视化工具</strong>
</p>

<p align="center">
  <a href="https://github.com/shuifa/KeyGrow/releases/latest"><img src="https://img.shields.io/github/v/release/shuifa/KeyGrow?style=flat-square&color=blue" alt="Latest Release" /></a>
  <a href="https://github.com/shuifa/KeyGrow/actions"><img src="https://img.shields.io/github/actions/workflow/status/shuifa/KeyGrow/ci.yml?branch=main&label=Build%20%26%20Test&style=flat-square" alt="CI Status" /></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0+-black?style=flat-square&logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9%20%2F%206.0-orange?style=flat-square&logo=swift" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License" />
</p>

---

## 📖 项目简介

**KeyGlow** 专为**屏幕录制、编程教学、设计演示、技术分享与直播**量身打造。参考了 Keystroke Pro 的核心体验与拟物灵感，融合现代化 macOS 设计语言，首要追求：**视觉极度精致、动画丝滑自然、系统性能零负担、核心功能简单克制**。

---

## 🆕 v0.14.1 变更摘要

- **组合间距收紧：** 连续按下的多个快捷键之间的间距由 18pt 调整为 9pt（组合内部键间距仍为 4pt），多键连发时排布更紧凑、更接近真实键盘密度。

---

## 🆕 v0.14 变更摘要

- **键帽立体结构重做：** 旧版把顶面与一块同尺寸的底座错位 3pt 叠放，四个边只有底部露出一条色带，读起来更像一张带投影的贴纸。新版把键帽本体改为**一整块拉长的圆角矩形**（含前壁厚度），顶面按水平方向收窄后覆盖其上，左右斜壁与底部前壁成为真实可见的体块。
- **方向光与折角：** 侧壁叠加左亮右暗的柱面明暗（与投影偏移方向一致），顶面下沿新增折角暗部，确保「顶面 → 前壁」有明确转折；侧壁颜色由顶面下沿压暗派生，过渡连续、无深色贴边。
- **投影分层：** 彩色环境光晕、大范围环境影、紧贴底沿的接触影三层叠加，键帽既有主题色的环境感，也被压实到桌面上。
- **比例自适应：** 前壁厚度、侧壁宽度、顶面圆角全部由键帽高度派生，设置面板 32pt 缩略图与悬浮层 54pt 键帽共用同一套比例。

---

## 🆕 v0.13 变更摘要

- **六套主题整体重做：** 旧版六套共用「浅灰字母键 + 一个饱和修饰键 + 一个暖色 Esc」的同一公式，只差色相，观感同质。新版把四档颜色升级为**四个光位**：字母键是底色、功能键是结构层、修饰键是强调音、Esc 是英雄键。
- **明度骨架各不相同：** 「曜石」是高反差黑金，「拿铁」四档单调下沉，「冰川 / 樱」柔和通透，「磷光 / 霓虹」深底荧光，六套是六种键盘而不再是同一块键盘换色。
- **主题更名（配置自动迁移）：** 石墨→曜石、纸感→拿铁、深海→冰川、日落→樱、终端→磷光、霓虹保持。旧 `themeID` 自动映射到新配色槽位，升级不会重置用户选择。
- **主题卡片升级：** 预览改用该主题的推荐材质（所见即点下去的结果），并新增「日 / 夜」双色卡带，不切换外观模式即可横向对比昼夜两档。

---

## 🆕 v0.12 变更摘要

- **配置重构：** 移除「常规键 / 修饰键 / Esc / 边框」四项逐类配色，改为 6 套内置主题；旧版本的配色设置会在升级时自动清理。
- **昼夜双档：** 每套主题自带白天 / 夜晚配色，默认跟随系统外观自动切换。
- **设置面板重组：** 单列长滚动改为「外观 / 行为 / 高级」三页签，并新增恢复默认、配置导出 / 导入。
- **问题修复：** 跟随鼠标定位偏移、事件回调对象泄漏、Esc 与功能键同色、键帽队列容量与文档不一致、字符大小写被强制大写、菜单随设置变更反复重建等。
- **视觉调整：** 彩色光晕降级、特殊键文字化、组合间距拉开、修饰键符号光学对齐、可选键帽托盘。

---

## ✨ 核心亮点

### 1. 拟物键帽视觉（Skeuomorphic Keycap）
- **物理质感：** 每一个按键渲染为微倒角圆角物理键帽：顶面按水平方向收窄后覆盖在整体侧壁之上，左右斜壁与底部前壁因此真实可见，再叠加左上来光的方向明暗、顶面/前壁折角暗部、渐变高光边框（Highlight Border）、接触阴影与低强度环境光晕（Drop Shadow）。
- **原生 SF Symbols 图标：** 修饰键统一采用 macOS 原生矢量图标（`command`, `option`, `control`, `shift`），严格遵循官方 `⌃ ⌥ ⇧ ⌘` 排序规范，并对各符号做光学尺寸校正。
- **特殊键文字优先：** `esc` / `tab` / `return` / `space` 直接以文字呈现，录屏与教学场景下比抽象图标更易读；方向键保留矢量箭头。
- **3 款键帽材质（不含颜色，与主题解耦）：**
  - **哑光实体：** 实体注塑键帽，微浮雕立体光影。
  - **磨砂玻璃：** 超薄毛玻璃（`.ultraThinMaterial`）着色玻璃，轻盈通透。
  - **极光染色：** 深色底 + 强调色霓虹染色，赛博风演示首选。

### 2. 6 套内置主题 × 昼夜双档（Day / Night）
- 不再需要逐类调节「常规键 / 修饰键 / Esc / 边框」四个色号，改为**从一套主题里选一个**：
  - **曜石（默认）** 暖白字母 · 曜石黑结构 · 熔金 Esc
  - **拿铁** 奶油白字母 · 焦糖修饰 · 樱桃红 Esc
  - **冰川** 冰蓝白字母 · 海水蓝修饰 · 信号橙 Esc
  - **樱** 藕粉白字母 · 梅子紫修饰 · 墨蓝 Esc
  - **磷光** 灰绿白字母 · 荧光绿修饰 · 琥珀 Esc
  - **霓虹** 冷紫白字母 · 电紫修饰 · 荧光粉 Esc
- **每套主题都自带白天 / 夜晚两套完整配色**，默认「跟随系统」：macOS 切到深色，键帽自动切换到夜晚档，无需手动改主题。
- 主题内按**四个光位**分层取色：字母键保持中性低饱和作为底色，功能键（Return / Tab / 方向键）压成结构层与字母键拉开明度台阶，修饰键用唯一的高饱和强调色，Esc 用另一色系做整块键盘的对比焦点。


### 3. 「右边进、左边出」流式动效（Spring Physics）
- **流式队列：** 连续按键在屏幕上保留的键帽数量可配置（1 ~ 4 个，默认 3 个）。
- **右进左出：** 新按键自右侧带物理弹性初速度滑入，最左侧最早按下的按键超时或挤出时平滑向左滑出并淡隐，中间按键丝滑位移。
- **触感反馈：** 连续按下同一按键时触发物理微脉冲震颤（Tap Punch/Pulse），界面无多余数字干扰，节奏感明晰；也可开启 `×N` 角标合并计数。
- **组合分隔：** 组合内部键间距 4pt、组合之间 9pt，连续多个快捷键不会被读成一长串键帽。

### 4. 自由锚点与上下距离微调
- **5 种屏幕定位锚点：**
  - 屏幕底部居中（默认）
  - 屏幕左下角（左对齐自然展开）
  - 屏幕右下角（右对齐自然展开）
  - 屏幕顶部居中
  - 跟随鼠标光标
- **上下距离自由调节：** 支持滑动条调节距屏幕边缘的像素高度（20pt ~ 220pt），避开各类 Dock 栏与状态栏。

### 5. 穿透悬浮窗与极速架构
- **零干扰穿透：** 基于定制 `NSPanel`，配置 `ignoresMouseEvents = true`，鼠标点击与手势 100% 穿透到底层窗口，绝不阻碍用户操作。
- **多桌面与全屏穿透：** `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`，虚拟桌面 Spaces 切换及全屏应用时始终悬浮常驻，不抢夺输入焦点。
- **后台纯监听：** 基于 `CGEventTap`（`.listenOnly`）运行于专用后台线程，对日常打字零延迟；内置超时自愈机制；遇密码输入框（Secure Input）自动静默降级保护隐私。

---

## 📦 快速下载与安装

直接前往 **[GitHub Releases](https://github.com/shuifa/KeyGrow/releases)** 下载最新版本的 `.dmg` 安装包：

1. 下载 `KeyGlow-v0.14.dmg`。
2. 双击打开并将 **KeyGlow.app** 拖入 **Applications（应用程序）** 目录。
3. 启动应用并按提示授予辅助功能权限即可开始使用。

---

## 🛠️ 技术架构

- **UI & 动效：** 纯原生 SwiftUI 5，结合 `phaseAnimator`、Spring 弹簧物理曲线。
- **窗口管理：** AppKit `NSPanel` + `NSHostingController`（解耦布局约束，杜绝 Auto Layout 递归）。
- **底层监听：** CoreGraphics `CGEventTap` + Carbon 键码映射 + Unicode 字符提取。
- **常驻入口：** 状态栏菜单（`NSStatusItem`）常驻管理，支持一键切换监听、过滤模式、视觉风格与偏好设置。

---

## 🚀 编译与运行

### 系统要求
- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15.0+ / Swift 5.9+

### 构建步骤
```bash
# 克隆仓库
git clone git@github.com:shuifa/KeyGrow.git
cd KeyGrow

# 打开 Xcode 工程
open KeyGlow.xcodeproj
```
或者直接使用命令行构建：
```bash
xcodebuild -project KeyGlow.xcodeproj -scheme KeyGlow -destination 'platform=macOS' build
```

---

## 🔐 辅助功能权限说明

由于需要全局捕获快捷键，KeyGlow 首次运行时需要授予 **辅助功能权限（Accessibility）**：
1. 启动 KeyGlow，若尚未授权将自动弹出偏好设置。
2. 点击 **「去授权」** 按钮，系统将自动打开 **「系统设置 -> 隐私与安全性 -> 辅助功能」**。
3. 勾选 **KeyGlow** 即可立即开始使用。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 协议开源。
