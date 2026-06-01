# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Serial port auto-detection
- Support for standard baud rates (300 - 921600)
- Configurable serial parameters:
  - Data bits (5-8)
  - Parity (None, Odd, Even)
  - Stop bits (1, 2)
  - Flow control (None, Hardware, Software)
- Multiple display modes:
  - ASCII mode
  - HEX mode
  - Combined ASCII + HEX mode
- Timestamps with millisecond precision
- Color-coded RX/TX messages
- Text and HEX input support
- Session logging to file
- Modern SwiftUI interface
- Custom app icon
- Auto-scroll functionality
- Efficient message buffering
- macOS 13.0+ support

### Supported Devices
- USB-to-Serial chips (CH340, CP2102, FTDI, PL2303)
- STM32 series microcontrollers
- Arduino boards
- ESP32/ESP8266
- Raspberry Pi Pico
- Any device with UART interface

## [Unreleased]

## [1.0.1] - 2026-06-01

### Changed
- **启动时自动刷新串口列表**：应用启动时会自动检测可用串口，并且每3秒自动刷新一次（未连接时）
- **默认波特率改为9600**：更符合大多数嵌入式设备的常用波特率
- **更新许可证为LGPL v3**：允许在闭源软件中链接使用

### Fixed
- 修复了串口列表可能不自动刷新的问题
- 改进了消息缓冲机制

### Planned Features
- DTR/RTS control
- Line ending configuration
- Multiple connection tabs
- Command presets
- Script automation
- Export/import settings
- Keyboard shortcuts
- Dark/Light mode toggle
- Language support (i18n)

---

## Version History

| Version | Status | Release Date |
|---------|--------|--------------|
| 1.0.1   | Latest | 2026-06-01  |
| 1.0.0   | Stable | 2024-01-01  |

## Versioning Strategy

This project uses semantic versioning (SemVer):
- **MAJOR** version: Breaking changes
- **MINOR** version: New features, backwards compatible
- **PATCH** version: Bug fixes, backwards compatible

## Release Process

1. Update version in `project.yml`
2. Update this CHANGELOG.md
3. Create Git tag: `git tag -a v1.0.0 -m "Release version 1.0.0"`
4. Push tag: `git push origin v1.0.0`
5. Create GitHub Release
6. Attach built application

## Security

For security vulnerabilities, please report to:
- Email: your.email@example.com
- GitHub: [Private Vulnerability Reporting](https://github.com/yourusername/SerialTerminal/security/advisories/new)

---

**Note**: Starting from version 1.0.0, this project follows semantic versioning. Please see the [releases page](https://github.com/yourusername/SerialTerminal/releases) for all available versions.
