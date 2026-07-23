# SerialTerminal - 串口调试助手

<p align="center">
  <img src="SerialTerminal/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="SerialTerminal 图标">
</p>

<p align="center">
  <strong>macOS 平台的轻量级串口调试工具</strong>
  <br>
  <sub>专为调试 STM32、Arduino 和其他嵌入式系统设计</sub>
</p>

<p align="center">
  <a href="https://github.com/BiKing567/Seiral-Terminal/releases">
    <img src="https://img.shields.io/github/v/release/BiKing567/Seiral-Terminal?style=flat-square" alt="版本">
  </a>
  <a href="https://github.com/BiKing567/Seiral-Terminal/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/BiKing567/Seiral-Terminal?style=flat-square" alt="许可证">
  </a>
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift">
  </a>
  <a href="https://developer.apple.com/macos">
    <img src="https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square" alt="macOS">
  </a>
</p>

---

## ✨ 功能特点

### 🔌 串口通信
- **自动检测串口** - 实时检测并列出可用串口
- **广泛的波特率支持** - 从 300 到 921600 波特
- **可配置参数** - 数据位（5-8）、校验位（无/奇/偶）、停止位（1/2）
- **流控制选项** - 硬件流控（RTS/CTS）、软件流控（XON/XOFF）、无流控

### 📊 显示模式
- **ASCII 模式** - 人类可读的文本显示
- **HEX 模式** - 十六进制数据视图
- **混合模式** - 同时显示 ASCII 和 HEX
- **时间戳** - 可选的毫秒级精度时间戳
- **颜色区分** - RX（绿色）和 TX（蓝色）消息清晰区分

### 💬 数据处理
- **文本输入** - 发送纯文本，自动添加换行
- **HEX 输入** - 发送十六进制原始数据（如 `01 02 03 04`）
- **自动滚动** - 自动滚动到最新消息
- **高效缓冲** - 优化的缓冲机制，支持按行和定时刷新

### 📁 日志记录
- **会话录制** - 将所有串口通信记录到文件
- **保留时间戳** - 日志中包含精确时间戳
- **便捷导出** - 保存为纯文本格式，便于分析

### 🎨 现代界面
- **原生 macOS 设计** - 使用 SwiftUI 构建，完美融入 macOS
- **深色模式支持** - 自动适配系统外观设置
- **响应式布局** - 自适应各种窗口大小
- **专属应用图标** - 专业的串口主题图标

## 🚀 快速开始

### 环境要求
- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本
- 支持 Intel 与 Apple Silicon 芯片
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 用于生成项目

### 安装方法

#### 从 Release 下载

1. 从 [Releases](https://github.com/BiKing567/Seiral-Terminal/releases) 下载最新的 `.dmg` 文件
2. 拖动到应用程序文件夹
3. 启动 SerialTerminal

#### 从源码编译

```bash
# 克隆仓库
git clone https://github.com/BiKing567/Seiral-Terminal.git
cd Seiral-Terminal

# 生成 Xcode 项目
xcodegen

# 在 Xcode 中打开
open SerialTerminal.xcodeproj

# 编译运行（在 Xcode 中按 ⌘+R）
```

### 首次使用

1. **连接设备** - 通过 USB 连接您的 STM32/Arduino
2. **选择串口** - 从下拉菜单中选择串口
3. **配置参数** - 设置波特率（常用 115200）
4. **点击连接** - 点击绿色的"连接"按钮
5. **开始通信** - 发送命令并查看响应！

## 📖 使用指南

### 连接工具栏

```
┌─────────────────────────────────────────────────────────────────┐
│ [串口选择 ▼] [波特率 ▼] [连接/断开]                    [⚙️ 设置] │
└─────────────────────────────────────────────────────────────────┘
```

- **串口选择**：显示所有检测到的串口，点击可刷新列表
- **波特率**：从标准速率中选择（9600、115200 等）
- **连接/断开**：切换按钮（绿色=连接，红色=断开）
- **设置**：打开高级配置（数据位、校验位等）

### 终端视图

```
┌─────────────────────────────────────────────────────────────────┐
│ [ASCII ▼]              [✓] 时间戳  [✓] 自动滚动  [🗑️]          │
├─────────────────────────────────────────────────────────────────┤
│ [12:34:56.789] [RX] 收到: Hello from STM32!                     │
│ [12:34:56.801] [TX] 发送: ping                                    │
│ [12:34:56.823] [RX] 收到: pong                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 发送面板

```
┌─────────────────────────────────────────────────────────────────┐
│ [文本|HEX] [__________________________] [📤 发送] [⏺️ 记录]     │
└─────────────────────────────────────────────────────────────────┘
```

- **文本/HEX 切换**：在文本和十六进制输入之间切换
- **输入框**：输入消息内容或 HEX 数据
- **发送按钮**：传输数据（也可按回车键）
- **记录按钮**：开始/停止记录到文件

### 高级设置

```
┌─────────────────────────────────────────────────────────────────┐
│ 数据位：       [8 ▼]                                              │
│ 校验位：     [无 ▼]                                               │
│ 停止位：     [1 ▼]                                               │
│ 流控制：    [无 ▼]                                               │
│                                                      [确定]      │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ 项目架构

```
SerialTerminal/
├── main.swift                    # 应用入口
├── AppDelegate.swift             # 应用生命周期管理
├── ContentView.swift             # SwiftUI 主界面
├── SerialPortManager.swift       # 串口通信层
├── Assets.xcassets/              # 应用图标和资源
├── Info.plist                   # 应用配置
└── SerialTerminal.entitlements  # 安全权限配置
```

### 核心组件

#### SerialPortManager
使用 IOKit 进行底层串口通信：
- 通过 IOKit 枚举串口
- POSIX termios 配置
- 基于 DispatchSource 的异步读取
- 线程安全的数据缓冲管理

#### TerminalViewModel
业务逻辑和状态管理：
- 消息缓冲和格式化
- 显示模式切换（ASCII/HEX/混合）
- 会话日志记录
- 数据传输处理

#### ContentView
SwiftUI 界面组件：
- 连接工具栏
- 终端显示区域
- 消息输入面板
- 设置页面

## 🛠️ 开发指南

### 编译项目

```bash
# Debug 版本
xcodebuild -project SerialTerminal.xcodeproj -scheme SerialTerminal -configuration Debug build

# Release 版本
xcodebuild -project SerialTerminal.xcodeproj -scheme SerialTerminal -configuration Release build
```

### 测试

```bash
# 在 Xcode 中打开并运行测试
open SerialTerminal.xcodeproj
# 使用 ⌘+U 运行测试
```

### 参与贡献

1. **Fork 仓库**
2. **创建功能分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **编写代码**
4. **运行测试**
5. **提交 Pull Request**

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 📋 支持的设备

### USB 转串口芯片
- ✅ CH340/CH341（常见于 Arduino 克隆版）
- ✅ CP2102/CP2104（Silicon Labs）
- ✅ FTDI FT232R/FT230X
- ✅ PL2303（Prolific）
- ✅ STM32 内置 USB

### 微控制器
- ✅ STM32 系列（所有型号）
- ✅ Arduino（Uno、Nano、Mega 等）
- ✅ ESP32/ESP8266
- ✅ 树莓派 Pico
- ✅ 任何带 UART 接口的设备

## 🐛 常见问题

### 串口未检测到
- **检查 USB 连接** - 尝试更换 USB 端口
- **安装驱动** - 部分设备需要安装驱动：
  - CH340：http://www.wch.cn/downloads/CH341SER_MAC_ZIP.html
  - CP2102：https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
- **检查权限** - 确保已授予串口访问权限

### 连接问题
- **验证波特率** - 确保与设备配置一致
- **检查流控制** - 如未使用请禁用
- **使用更短的线缆** - USB 延长线可能导致问题

### 数据显示问题
- **编码错误** - 确保使用 UTF-8 编码
- **换行符缺失** - 检查设备是否发送 `\r\n` 或 `\n`
- **缓冲延迟** - 可增加缓冲刷新间隔

## 📄 许可证

本项目采用 **Apache 2.0** - 详见 [LICENSE](LICENSE) 文件。

### LGPL v3 许可证说明

LGPL v3 是一个宽松的 copyleft 许可证，主要特点包括：

- ✅ **可以免费使用** - 个人和商业使用均完全免费
- ✅ **可以嵌入到闭源软件中** - 只要保持 SerialTerminal 库的独立性
- ✅ **修改需开源** - 如果修改了 SerialTerminal 的源代码，必须发布修改后的版本
- 📋 **说明要求** - 在使用 LGPL 库的软件中需要明确说明使用了 SerialTerminal
- 📋 **提供源代码** - 需要提供获取 SerialTerminal 源代码的途径

简单来说：
- 你可以自由使用 SerialTerminal
- 如果你修改了 SerialTerminal，需要开源修改后的代码
- 你可以将 SerialTerminal 集成到闭源软件中（只要保持分离）

## 🙏 致谢

- **SwiftUI** - 现代化的声明式 UI 框架
- **IOKit** - macOS 平台底层串口访问
- **XcodeGen** - 出色的 Xcode 项目生成工具

## 📬 联系方式

- **GitHub Issues**：[报告问题或请求功能](https://github.com/BiKing567/Seiral-Terminal/issues)

## 📊 项目统计

<p align="center">
  <img src="https://img.shields.io/github/downloads/BiKing567/Seiral-Terminal/total?style=flat-square" alt="下载量">
  <img src="https://img.shields.io/github/stars/BiKing567/Seiral-Terminal?style=flat-square" alt="星标">
  <img src="https://img.shields.io/github/forks/BiKing567/Seiral-Terminal?style=flat-square" alt="分支">
</p>

---

<p align="center">
  为嵌入式系统社区用心打造 ❤️
</p>
