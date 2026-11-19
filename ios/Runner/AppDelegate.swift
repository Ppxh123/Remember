import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "io.github.ppxh123.remember/storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "prepareLocalDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        let files = FileManager.default
        let support = try files.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        var directory = support.appendingPathComponent("Remember", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        var attributes = URLResourceValues()
        attributes.isExcludedFromBackup = true
        try directory.setResourceValues(attributes)
        result(directory.path)
      } catch {
        result(FlutterError(code: "local_storage_unavailable", message: nil, details: nil))
      }
    }
  }
}
