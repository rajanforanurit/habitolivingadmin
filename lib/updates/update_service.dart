/// In-app updater — self-contained module.
///
/// Checks GitHub for the newest release APK, compares versions, and offers a
/// download + install flow (Android opens the system install prompt; the user
/// always taps "Install" once — silent self-updates are Play-Store-only).
///
/// ## Removing this feature
/// Everything lives in this folder plus three one-line touches elsewhere:
///   1. `pubspec.yaml`        — the `package_info_plus` dependency
///   2. `AndroidManifest.xml` — the `REQUEST_INSTALL_PACKAGES` permission
///   3. `lib/main.dart`       — `UpdateService.instance.init()` + the banner
///
/// Delete `lib/updates/`, revert those three touches, done.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Where update metadata comes from. A public GitHub repo's "latest release":
/// the tag is the version (e.g. `v1.11.21`) and the first `.apk` asset is the
/// download. Override with `--dart-define=UPDATE_REPO=owner/name` if the app
/// moves to a different repo.
const String _updateRepo = String.fromEnvironment(
  'UPDATE_REPO',
  defaultValue: 'rajanforanurit/habitoliving',
);

/// A read-only GitHub token with access to the (private) updates repo, so the
/// app can read releases and download the APK without the user being logged in.
///
/// Security: this is a fine-grained, read-only token scoped to the single
/// repo (Contents:Read). It is embedded in the APK and therefore extractable —
/// acceptable because it grants nothing beyond reading this repo's releases.
/// If the repo ever goes public, remove this constant (the API works without it).
/// Override with --dart-define=GITHUB_UPDATE_TOKEN=... for CI builds.
const String _githubToken = String.fromEnvironment('GITHUB_UPDATE_TOKEN');

Map<String, String> get _githubHeaders => {
  'Accept': 'application/vnd.github+json',
  if (_githubToken.isNotEmpty) 'Authorization': 'Bearer $_githubToken',
};

/// A newer version is available on GitHub.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  /// Version without the leading `v` (e.g. `1.11.21`).
  final String version;

  /// Direct download URL of the release APK asset.
  final String downloadUrl;

  /// Release body, shown in the update dialog. May be empty.
  final String releaseNotes;
}

/// Which step of the update flow we are in.
enum UpdateStatus { idle, checking, available, downloading, readyToInstall, error }

/// The updater: version check, APK download, install trigger.
///
/// Design notes:
/// - The check is cached in memory for [checkInterval] so we do not hit the
///   GitHub API on every launch (unauthenticated GitHub API is rate-limited to
///   60 requests/hour per IP).
/// - Downloads go to the app's cache dir, so Android's package installer can
///   read them via a content:// FileProvider URI.
class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  UpdateInfo? _info;
  UpdateInfo? get info => _info;

  /// Human-readable error for the last failure (null when fine).
  String? _error;
  String? get error => _error;

  /// Downloaded APK path once [UpdateStatus.readyToInstall] is reached.
  String? _apkPath;
  String? get apkPath => _apkPath;

  /// Last check time, so rapid restarts do not re-hit GitHub.
  DateTime? _lastChecked;

  static const Duration checkInterval = Duration(hours: 6);

  bool _initialised = false;

  /// Load the installed version. Call once at startup (safe before runApp).
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    _installed = await _readInstalledVersion();
  }

  String? _installed;
  String? get installedVersion => _installed;

  Future<String?> _readInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      debugPrint('UpdateService: cannot read installed version: $e');
      return null;
    }
  }

  /// Whether [version] is strictly newer than [current].
  ///
  /// Compares dotted integers, so `1.11.21` > `1.11.20` and `1.12.0` > `1.11.99`.
  /// A version we cannot parse is treated as not newer (never downgrade).
  static bool isNewer(String current, String candidate) {
    List<int>? a;
    List<int>? b;
    try {
      a = current.split('.').map(int.parse).toList();
      b = candidate.split('.').map(int.parse).toList();
    } catch (_) {
      return false;
    }
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return y > x;
    }
    return false;
  }

  /// Check GitHub for a newer release. No-op while a download is in progress.
  ///
  /// Returns the update info when an update is available, otherwise null.
  Future<UpdateInfo?> check() async {
    if (_status == UpdateStatus.downloading) return _info;
    if (_lastChecked != null &&
        DateTime.now().difference(_lastChecked!) < checkInterval &&
        _status == UpdateStatus.available) {
      return _info;
    }
    _status = UpdateStatus.checking;
    _error = null;
    notifyListeners();
    debugPrint('UpdateService: checking $_updateRepo (token: ${_githubToken.isNotEmpty})');
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_updateRepo/releases/latest',
            ),
            headers: _githubHeaders,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('GitHub returned ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String? ?? '';
      final version = tag.replaceFirst(RegExp(r'^v'), '');
      final assets = (json['assets'] as List?) ?? const [];
      String? apkUrl;
      for (final a in assets) {
        final map = a as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = map['browser_download_url'] as String?;
          break;
        }
      }
      if (version.isEmpty || apkUrl == null) {
        throw Exception('Latest release has no version or APK asset');
      }
      final installed = _installed ?? await _readInstalledVersion();
      _installed = installed;
      debugPrint('UpdateService: installed=$installed latest=$version newer=${installed != null && isNewer(installed, version)}');
      if (installed == null || !isNewer(installed, version)) {
        _status = UpdateStatus.idle;
        _info = null;
        _lastChecked = DateTime.now();
        notifyListeners();
        return null;
      }
      _info = UpdateInfo(
        version: version,
        downloadUrl: apkUrl,
        releaseNotes: (json['body'] as String?) ?? '',
      );
      _status = UpdateStatus.available;
      _lastChecked = DateTime.now();
      notifyListeners();
      return _info;
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
      _status = UpdateStatus.error;
      _error = 'Could not check for updates: $e';
      notifyListeners();
      return null;
    }
  }

  /// Download the update APK. After this completes the status becomes
  /// [UpdateStatus.readyToInstall] and [apkPath] points at the file.
  Future<bool> download() async {
    final info = _info;
    if (info == null) return false;
    _status = UpdateStatus.downloading;
    _error = null;
    notifyListeners();
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) throw Exception('No downloads directory');
      final file = File('${dir.path}/habito-${info.version}.apk');
      final response = await http
          .get(Uri.parse(info.downloadUrl), headers: _githubHeaders)
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      await file.writeAsBytes(response.bodyBytes, flush: true);
      _apkPath = file.path;
      _status = UpdateStatus.readyToInstall;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UpdateService: download failed: $e');
      _status = UpdateStatus.error;
      _error = 'Download failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reset back to idle (e.g. the user dismissed the prompt).
  void dismiss() {
    _status = UpdateStatus.idle;
    _error = null;
    notifyListeners();
  }
}