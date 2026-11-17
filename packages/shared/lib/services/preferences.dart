import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user preferences.
///
/// Deliberately small: only the things that must survive a restart. Everything
/// else (notification categories, delivery preferences) is owned by the backend
/// through the profile API, so the app does not keep a second copy that can
/// disagree.
///
/// Unknown or corrupt values fall back to a sane default rather than throwing:
/// a preferences store must never be the reason the app fails to start.
class Preferences extends ChangeNotifier {
  Preferences._();
  static final Preferences instance = Preferences._();

  static const _kThemeMode = 'pref.themeMode';
  static const _kPushEnabled = 'pref.pushEnabled';
  static const _kOnboardingSeen = 'pref.onboardingSeen';

  ThemeMode _themeMode = ThemeMode.light;
  bool _pushEnabled = true;
  bool _onboardingSeen = false;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get pushEnabled => _pushEnabled;
  bool get onboardingSeen => _onboardingSeen;
  bool get loaded => _loaded;

  /// Reads the store once at startup. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = _themeModeFrom(prefs.getString(_kThemeMode));
      _pushEnabled = prefs.getBool(_kPushEnabled) ?? true;
      _onboardingSeen = prefs.getBool(_kOnboardingSeen) ?? false;
    } catch (_) {
      // Keep the defaults.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _write(_kThemeMode, mode.name);
  }

  /// Cycles light → dark → system, which is what the settings row does.
  Future<void> cycleThemeMode() async {
    final next = switch (_themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setThemeMode(next);
  }

  Future<void> setPushEnabled(bool value) async {
    if (_pushEnabled == value) return;
    _pushEnabled = value;
    notifyListeners();
    await _write(_kPushEnabled, value);
  }

  Future<void> setOnboardingSeen(bool value) async {
    if (_onboardingSeen == value) return;
    _onboardingSeen = value;
    notifyListeners();
    await _write(_kOnboardingSeen, value);
  }

  Future<void> _write(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else {
        await prefs.setString(key, value as String);
      }
    } catch (_) {
      // A failed write must not break the setting in memory.
    }
  }

  static ThemeMode _themeModeFrom(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    // Light is the default: the app is designed light-first, and a resident who
    // has never picked a mode should not land in a dark app just because their
    // phone is in dark mode.
    _ => ThemeMode.light,
  };
}

/// A human label for the current theme mode, used by the settings row.
extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}
