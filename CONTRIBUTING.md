# Contributing to SerialTerminal

Thank you for your interest in contributing to SerialTerminal! This document provides guidelines and instructions for contributing.

## 🎯 Ways to Contribute

### 🐛 Reporting Bugs
- Check if the bug has already been reported in [Issues](https://github.com/yourusername/SerialTerminal/issues)
- Use the bug report template when creating a new issue
- Include:
  - macOS version
  - Xcode version
  - Device/board information
  - Steps to reproduce
  - Expected vs actual behavior
  - Relevant logs or screenshots

### 💡 Suggesting Features
- Check existing [feature requests](https://github.com/yourusername/SerialTerminal/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)
- Use the feature request template
- Describe the use case and motivation
- Explain how it would benefit users

### 🔧 Pull Requests

#### Before Starting
1. **Check existing issues** - Avoid duplicate work
2. **Fork the repository** - Create your own copy
3. **Create a branch** - Use descriptive naming:
   - `feature/hex-display`
   - `bugfix/connection-timeout`
   - `docs/update-readme`

#### Development Setup

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/SerialTerminal.git
cd SerialTerminal

# 3. Add upstream remote
git remote add upstream https://github.com/yourusername/SerialTerminal.git

# 4. Create a feature branch
git checkout -b feature/your-feature-name

# 5. Generate Xcode project
xcodegen

# 6. Open in Xcode
open SerialTerminal.xcodeproj
```

#### Making Changes

1. **Code Style**
   - Follow Swift API Design Guidelines
   - Use meaningful variable and function names
   - Add comments for complex logic
   - Keep functions small and focused

2. **Swift Style Guidelines**
   ```swift
   // ✅ Good
   func connect(to port: SerialPortInfo) {
       serialManager.connect(to: port)
   }
   
   // ❌ Avoid
   func connect(port: SerialPortInfo) {
       manager.connect(port)
   }
   ```

3. **Documentation**
   - Update README.md for new features
   - Add inline comments for complex code
   - Document public interfaces

#### Testing

```bash
# Run tests in Xcode
# Use ⌘+U or Product > Test

# Test manually:
# 1. Connect a device (Arduino/STM32)
# 2. Verify basic functionality:
#    - Port detection
#    - Connection/disconnection
#    - Data transmission
#    - Display modes
```

#### Commit Guidelines

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove)
- Keep commits focused and atomic

```bash
# Examples
git commit -m "Add HEX input mode for raw data transmission"
git commit -m "Fix connection timeout issue on macOS 14"
git commit -m "Improve message buffering to reduce display flicker"
git commit -m "Update baud rate dropdown to include 460800"
```

#### Pull Request Process

1. **Keep PRs focused** - One feature or fix per PR
2. **Update documentation** - Include usage examples
3. **Test thoroughly** - Manual testing on real hardware
4. **Follow template** - Use PR template (auto-generated)

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Documentation update
- [ ] Code refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing performed
- [ ] Tested on real hardware

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
```

## 🏗️ Project Structure

```
SerialTerminal/
├── main.swift              # Entry point
├── AppDelegate.swift       # App lifecycle
├── ContentView.swift       # UI components
├── SerialPortManager.swift # Core serial logic
└── Assets.xcassets/        # Icons and resources
```

## 🐛 Testing Guidelines

### Manual Testing Checklist

When adding features, test:

- [ ] Serial port detection
- [ ] Connection with different baud rates
- [ ] Data transmission (TX)
- [ ] Data reception (RX)
- [ ] ASCII display mode
- [ ] HEX display mode
- [ ] Combined display mode
- [ ] Timestamps toggle
- [ ] Auto-scroll toggle
- [ ] Message clearing
- [ ] Session logging
- [ ] Settings persistence
- [ ] Dark mode compatibility

### Hardware Testing

Test with multiple devices:
- [ ] Arduino Uno/Nano
- [ ] STM32F103 (Blue Pill)
- [ ] STM32F4xx
- [ ] ESP32/ESP8266
- [ ] CH340-based devices
- [ ] CP2102-based devices

## 📝 Documentation

### Updating Documentation

- **README.md** - Main documentation
- **Code comments** - Inline documentation
- **Issue descriptions** - Bug and feature details

### Documentation Style

- Use clear, concise language
- Include code examples where appropriate
- Add screenshots for UI changes
- Explain the "why" not just the "what"

## 🔍 Code Review Process

All submissions require review. We use GitHub pull requests for this purpose.

Review criteria:
- Code quality and style
- Test coverage
- Documentation completeness
- Compatibility
- Performance impact

## 🚀 Release Process

1. Version bump (semantic versioning)
2. Update CHANGELOG.md
3. Create GitHub release
4. Build and attach .app file
5. Announce (if applicable)

## 📧 Contact

- **Issues**: [GitHub Issues](https://github.com/yourusername/SerialTerminal/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/SerialTerminal/discussions)

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉
