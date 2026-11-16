import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets local notifications (Snap moments) and push both reach Flutter.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerClipboardCheck(engineBridge.pluginRegistry)
  }

  /// Tells Flutter whether the clipboard probably holds a web link (an
  /// invite copied by the landing page) without reading it, so iOS only
  /// shows the "Allow Paste" prompt when there's something worth pasting.
  private func registerClipboardCheck(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "PowerCoupleClipboard") else { return }
    let channel = FlutterMethodChannel(name: "powercouple/clipboard", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "hasProbableWebURL" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard UIPasteboard.general.hasStrings || UIPasteboard.general.hasURLs else {
        result(false)
        return
      }
      UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { found in
        DispatchQueue.main.async {
          result((try? found.get())?.contains(.probableWebURL) ?? false)
        }
      }
    }
  }
}
