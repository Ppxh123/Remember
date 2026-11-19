# 使用 Flutter 和本地 SQLite 开发首版

首版采用 Flutter 和 Dart，让 Android 与 iPhone 共享界面和日期规则，并分别在 Windows Android Emulator 和 macOS iPhone Simulator 验收。日期条目通过 sqflite 保存在本机 SQLite，便于离线持久化、后续表结构迁移和事务写入。凭据仍遵循设备认证与加密 ADR。
