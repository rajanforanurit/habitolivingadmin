// In-app updater — install trigger (platform channel).
//
// The actual install is delegated to Android's package installer via a tiny
// MethodChannel (see android/app/src/main/kotlin/.../UpdateInstall.kt).
// The channel is registered by the platform code; on platforms without it
// (iOS, desktop, tests) this is a no-op that reports the failure cleanly.

import 'package:flutter/services.dart';

class UpdateInstall {
  UpdateInstall._();

  static const MethodChannel _channel = MethodChannel(
    'com.anuritinnovation.habitoliving/updater',
  );

  /// Ask Android to install the APK at [path]. Returns true when the install
  /// prompt was opened (the user still confirms in the system dialog).
  static Future<bool> install(String path) async {
    try {
      final ok = await _channel.invokeMethod<bool>('installApk', {
        'path': path,
      });
      return ok ?? false;
    } on PlatformException {
      // No platform implementation (e.g. iOS): fail soft.
      return false;
    }
  }
}