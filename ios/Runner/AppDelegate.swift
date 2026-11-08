import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Supaya notifikasi lokal tetap tampil saat aplikasi di depan.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Ruang kosong penyimpanan, untuk cek sebelum unduh murottal.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "StorageChannel") {
      let channel = FlutterMethodChannel(name: "quran.murojaah/storage", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "freeBytes" else { return result(FlutterMethodNotImplemented) }
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
          .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        result(values?.volumeAvailableCapacityForImportantUsage)
      }
    }
  }
}
