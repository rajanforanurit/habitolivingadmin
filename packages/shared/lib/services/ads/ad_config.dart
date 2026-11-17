import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AdConfig {
  AdConfig._();

  static const bool useLiveAds = bool.fromEnvironment(
    'ADMOB_LIVE',
    defaultValue: kReleaseMode,
  );

  static const String _liveNativeAndroid = String.fromEnvironment(
    'ADMOB_NATIVE_ANDROID',
    defaultValue: 'ca-app-pub-2305899806765378/1264851217',
  );

  static const String _liveNativeIos = String.fromEnvironment(
    'ADMOB_NATIVE_IOS',
    defaultValue: 'REPLACE_WITH_IOS_NATIVE_AD_UNIT_ID',
  );

  static const String _liveVideoAndroid = String.fromEnvironment(
    'ADMOB_VIDEO_ANDROID',
    defaultValue: '',
  );

  static const String _liveVideoIos = String.fromEnvironment(
    'ADMOB_VIDEO_IOS',
    defaultValue: '',
  );

  static const String _testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';

  static const String _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  static const String _testVideoAndroid =
      'ca-app-pub-3940256099942544/1044960115';

  static const String _testVideoIos = 'ca-app-pub-3940256099942544/2521693316';

  static bool get supported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static String get nativeUnitId {
    final android = Platform.isAndroid;

    if (!useLiveAds) {
      return android ? _testNativeAndroid : _testNativeIos;
    }

    return android ? _liveNativeAndroid : _liveNativeIos;
  }

  static String get videoUnitId {
    final android = Platform.isAndroid;

    if (!useLiveAds) {
      return android ? _testVideoAndroid : _testVideoIos;
    }

    final own = android ? _liveVideoAndroid : _liveVideoIos;

    return own.isNotEmpty ? own : nativeUnitId;
  }

  static bool isConfigured(String unitId) =>
      unitId.isNotEmpty && !unitId.startsWith('REPLACE');

  static const List<String> keywords = [
    'real estate',
    'home loan',
    'emi',
    'credit card',
    'banking',
    'insurance',
    'home appliances',
    'kitchenware',
    'furniture',
    'grooming',
    'personal care',
    'home services',
  ];

  static const int postsPerAd = 3;

  static const int maxAdsPerFeed = 4;
}
