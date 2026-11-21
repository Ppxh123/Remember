import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let storage = FlutterMethodChannel(
      name: "io.github.ppxh123.remember/storage",
      binaryMessenger: messenger
    )
    storage.setMethodCallHandler { call, result in
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

    let deviceCalendar = FlutterMethodChannel(
      name: "io.github.ppxh123.remember/device_calendar",
      binaryMessenger: messenger
    )
    deviceCalendar.setMethodCallHandler { call, result in
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .autoupdatingCurrent
      if call.method == "instantAt" {
        guard let parts = call.arguments as? [Int], parts.count == 5,
          let instant = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: parts[3], minute: parts[4]))
        else {
          result(FlutterError(code: "invalid_time", message: nil, details: nil))
          return
        }
        result(Int64((instant.timeIntervalSince1970 * 1000).rounded()))
        return
      }
      guard call.method == "dayAt" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let milliseconds = call.arguments as? NSNumber else {
        result(FlutterError(code: "invalid_instant", message: nil, details: nil))
        return
      }

      let instant = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000)
      let date = calendar.dateComponents([.year, .month, .day], from: instant)
      guard let year = date.year, let month = date.month, let day = date.day,
        let interval = calendar.dateInterval(of: .day, for: instant)
      else {
        result(FlutterError(code: "calendar_unavailable", message: nil, details: nil))
        return
      }
      let nextStart = Int64((interval.end.timeIntervalSince1970 * 1000).rounded())
      result([Int64(year), Int64(month), Int64(day), nextStart])
    }

    FlutterEventChannel(
      name: "io.github.ppxh123.remember/clock_changes",
      binaryMessenger: messenger
    ).setStreamHandler(ClockChanges())
  }
}

private final class ClockChanges: NSObject, FlutterStreamHandler {
  private var observers: [NSObjectProtocol] = []

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    removeObservers()
    let names: [Notification.Name] = [
      .NSSystemTimeZoneDidChange,
      UIApplication.significantTimeChangeNotification,
    ]
    observers = names.map { name in
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        events(nil)
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    removeObservers()
    return nil
  }

  private func removeObservers() {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
  }

  deinit {
    removeObservers()
  }
}
