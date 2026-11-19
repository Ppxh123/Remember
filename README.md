# 莫忘

莫忘 1.0 面向 Android 手机和 iPhone。首次打开直接进入日期页，可离线保存和查看一次性日期。日期按北京时间显示倒计时。

开发环境使用 Flutter 3.44.6。技术栈及本地存储的选型见 [ADR 0004](docs/adr/0004-flutter-and-local-sqlite.md)。

## 开发和验证

```sh
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <设备 ID>
flutter test -d <设备 ID> integration_test/date_persistence_test.dart
```

Windows 可使用 Android Emulator。iPhone 模拟器在 macOS 上运行，GitHub Actions 的 iPhone Simulator 工作流会运行系统集成测试。
