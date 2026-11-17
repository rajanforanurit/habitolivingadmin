import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Thin wrapper around the Mobile Ads SDK.
///
/// The SDK is initialised lazily, the first time an ad widget needs it, so the
/// rest of the app (and every other role) never pays for it. Initialisation
/// failures are swallowed: no ads is an acceptable outcome, a crash is not.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  Future<bool>? _init;

  Future<bool> ensureInitialised() {
    return _init ??= _initialise();
  }

  Future<bool> _initialise() async {
    if (!AdConfig.supported) return false;
    try {
      await MobileAds.instance.initialize();
      return true;
    } catch (e) {
      debugPrint('MobileAds init failed (ads disabled): $e');
      return false;
    }
  }

  /// The request used for every native ad in the app.
  AdRequest request() => const AdRequest(keywords: AdConfig.keywords);
}
