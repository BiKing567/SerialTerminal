# 贡献指南

感谢你对 SerialTerminal 项目的兴趣！本文档提供了贡献的指导说明。

## 🎯 贡献方式

### 🐛 报告问题
- 在 [Issues](https://github.com/BiKing567/SerialTerminal/issues) 中检查该问题是否已被报告
- 使用问题报告模板创建新的 issue
- 请包含：
  - macOS 版本
  - Xcode 版本
  - 设备/开发板信息
  - 复现步骤
  - 期望行为 vs 实际行为
  - 相关日志或截图

### 💡 建议功能
- 检查已有的 [功能请求](https://github.com/BiKing567/SerialTerminal/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
- 使用功能请求模板
- 描述使用场景和动机
- 解释它如何让用户受益

### 🔧 提交代码（Pull Requests）

#### 开始之前
1. **检查现有 issues** - 避免重复工作
2. **Fork 仓库** - 创建你自己的副本
3. **创建分支** - 使用描述性的命名：
   - `feature/hex-display`
   - `bugfix/connection-timeout`
   - `docs/update-readme`

#### 开发环境搭建

```bash
# 1. 在 GitHub 上 Fork 仓库

# 2. 克隆你的 Fork
git clone https://github.com/BiKing567/SerialTerminal.git
cd SerialTerminal

# 3. 添加上游仓库
git remote add upstream https://github.com/BiKing567/SerialTerminal.git

# 4. 创建功能分支
git checkout -b feature/your-feature-name

# 5. 生成 Xcode 项目
xcodegen

# 6. 用 Xcode 打开
open SerialTerminal.xcodeproj
```

#### 进行修改

1. **代码风格**
   - 遵循 Swift API 设计指南
   - 使用有意义的变量和函数名称
   - 为复杂逻辑添加注释
   - 保持函数小而专注

2. **Swift 风格指南**
   ```swift
   // ✅ 好的写法
   func connect(to port: SerialPortInfo) {
       serialManager.connect(to: port)
   }
   
   // ❌ 避免这样写
   func connect(port: SerialPortInfo) {
       manager.connect(port)
   }
   ```

3. **文档**
   - 为新功能更新 README.md
   - 为复杂代码添加内联注释
   - 文档化公开接口

#### 测试

```bash
# 在 Xcode 中运行测试
# 使用 ⌘+U 或 Product > Test

# 手动测试：
# 1. 连接设备（Arduino/STM32）
# 2. 验证基本功能：
#    - 端口检测
#    - 连接/断开
#    - 数据传输
#    - 显示模式
```

#### 提交规范

- 使用清晰、描述性的提交信息
- 以动词开头（Add、Fix、Update、Remove）
- 保持提交专注且原子化

```bash
# 示例
git commit -m "Add HEX input mode for raw data transmission"
git commit -m "Fix connection timeout issue on macOS 14"
git commit -m "Improve message buffering to reduce display flicker"
git commit -m "Update baud rate dropdown to include 460800"
```

#### Pull Request 流程

1. **保持 PR 专注** - 每个 PR 只包含一个功能或修复
2. **更新文档** - 包含使用示例
3. **充分测试** - 在真实硬件上进行手动测试
4. **遵循模板** - 使用自动生成的 PR 模板

```markdown
## 描述
变更的简要描述

## 变更类型
- [ ] Bug 修复（非破坏性变更）
- [ ] 新功能（非破坏性变更）
- [ ] 文档更新
- [ ] 代码重构

## 测试
- [ ] 添加/更新了单元测试
- [ ] 进行了手动测试
- [ ] 在真实硬件上测试

## 检查清单
- [ ] 代码遵循项目风格指南
- [ ] 完成了自我审查
- [ ] 为复杂代码添加了注释
- [ ] 文档已更新
```

## 🏗️ 项目结构

```
SerialTerminal/
├── main.swift              # 程序入口
├── AppDelegate.swift       # 应用生命周期
├── ContentView.swift       # UI 组件
├── SerialPortManager.swift # 核心串口逻辑
└── Assets.xcassets/        # 图标和资源
```

## 🐛 测试指南

### 手动测试清单

添加功能时，请测试：

- [ ] 串口检测
- [ ] 使用不同波特率连接
- [ ] 数据发送（TX）
- [ ] 数据接收（RX）
- [ ] ASCII 显示模式
- [ ] HEX 显示模式
- [ ] 混合显示模式
- [ ] 时间戳开关
- [ ] 自动滚动开关
- [ ] 清空消息
- [ ] 会话日志
- [ ] 设置持久化
- [ ] 深色模式兼容性

### 硬件测试

使用多种设备测试：
- [ ] Arduino Uno/Nano
- [ ] STM32F103（Blue Pill）
- [ ] STM32F4xx
- [ ] ESP32/ESP8266
- [ ] 基于 CH340 的设备
- [ ] 基于 CP2102 的设备

## 📝 文档

### 更新文档

- **README.md** - 主要文档
- **代码注释** - 内联文档
- **Issue 描述** - 问题和功能详情

### 文档风格

- 使用清晰、简洁的语言
- 适当包含代码示例
- 为 UI 变化添加截图
- 解释"为什么"而不只是"是什么"

## 🔍 代码审查流程

所有提交都需要审查。我们使用 GitHub pull requests 进行此操作。

审查标准：
- 代码质量和风格
- 测试覆盖率
- 文档完整性
- 兼容性
- 性能影响

## 🚀 发布流程

1. 版本升级（语义化版本）
2. 更新 CHANGELOG.md
3. 创建 GitHub 发布
4. 构建并附加 .app 文件
5. 发布公告（如适用）

## 📧 联系方式

- **问题**: [GitHub Issues](https://github.com/BiKing567/SerialTerminal/issues)
- **讨论**: [GitHub Discussions](https://github.com/BiKing567/SerialTerminal/discussions)

## 📄 许可证

通过贡献，你同意你的贡献将根据 MIT 许可证进行许可。

---

感谢你的贡献！🎉
