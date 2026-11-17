import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'socket_service.dart';

/// Everything tunable about the society alarm in one place.
class AlarmConfig {
  AlarmConfig._();

  /// Sound played on a resident's device when an alarm arrives.
  ///
  /// PLACEHOLDER: drop the real beep at `assets/sounds/alarm_beep.mp3` (and make
  /// sure `assets/sounds/` is listed under `flutter: assets:` in pubspec.yaml).
  /// Until the file exists the app falls back to the system alert sound, so
  /// nothing breaks. To use a different file or name, change only this line.
  static const String soundAsset = 'sounds/alarm_beep.mp3';

  /// Minimum gap between two alarms from the same device.
  static const Duration cooldown = Duration(minutes: 5);

  /// How long the raise button must be held before it fires.
  static const Duration holdToConfirm = Duration(seconds: 2);

  /// Payload `scope` that marks a society-wide resident alarm.
  static const String societyScope = 'SOCIETY';
}

/// An alarm raised by a neighbour, as delivered over the socket.
class SocietyAlarm {
  const SocietyAlarm({
    required this.id,
    this.societyId,
    this.flat,
    this.message,
    this.raisedById,
    this.raisedByName,
  });

  factory SocietyAlarm.fromEvent(RealtimeEvent event) {
    final d = event.data;
    String? str(dynamic v) => v is String && v.trim().isNotEmpty ? v : null;
    return SocietyAlarm(
      id: str(d['id']) ?? '${DateTime.now().millisecondsSinceEpoch}',
      societyId: str(d['societyId']),
      flat: str(d['flat'] ?? d['flatLabel']),
      message: str(d['message']),
      raisedById: str(d['raisedById'] ?? d['userId']),
      raisedByName: str(d['raisedByName'] ?? d['name']),
    );
  }

  final String id;
  final String? societyId;
  final String? flat;
  final String? message;
  final String? raisedById;
  final String? raisedByName;
}

/// Raising and receiving the society alarm.
///
/// Sending is guarded twice: the UI asks for a deliberate hold, and this service
/// enforces a cool-down that survives an app restart. The server should apply
/// its own rate limit as well; the client one is a convenience, not security.
///
/// Receiving only reacts to events that are (a) marked `scope: SOCIETY`, (b) for
/// the society the user is currently in, and (c) not raised by the user. The
/// server is responsible for sending an alarm only to the right society's
/// sockets; check (b) is defence in depth.
class AlarmService extends ChangeNotifier {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const _kLastRaised = 'alarm.lastRaisedAt';

  DateTime? _lastRaisedAt;
  bool _loaded = false;
  bool _sending = false;
  final AudioPlayer _player = AudioPlayer();
  final Set<String> _seen = <String>{};

  bool get isSending => _sending;

  /// Time left before another alarm may be sent, or zero.
  Duration get cooldownRemaining {
    final last = _lastRaisedAt;
    if (last == null) return Duration.zero;
    final left = AlarmConfig.cooldown - DateTime.now().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  bool get canRaise => !_sending && cooldownRemaining == Duration.zero;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kLastRaised);
      if (ms != null) {
        _lastRaisedAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {
      // No stored cool-down: start clean.
    }
    notifyListeners();
  }

  /// Sends the alarm. Throws on failure, so the caller can show the error and
  /// the cool-down is *not* consumed by a failed attempt.
  Future<void> raise({String? flatLabel, String? message}) async {
    await load();
    if (!canRaise) {
      throw StateError('An alarm was raised recently. Please wait.');
    }
    _sending = true;
    notifyListeners();
    try {
      await AppServices.instance.resident.raiseSocietyAlarm(
        flatLabel: flatLabel,
        message: message,
      );
      _lastRaisedAt = DateTime.now();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kLastRaised, _lastRaisedAt!.millisecondsSinceEpoch);
      } catch (_) {
        // In-memory cool-down still applies for this run.
      }
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Subscribes to incoming alarms. Returns a handle that cancels it.
  void Function() listen(void Function(SocietyAlarm alarm) onAlarm) {
    void handle(RealtimeEvent event) {
      if (event.data['scope'] != AlarmConfig.societyScope) return;
      final alarm = SocietyAlarm.fromEvent(event);

      final session = AppServices.instance.session;
      if (alarm.societyId != null &&
          alarm.societyId != session.activeSocietyId) {
        return; // Another society's alarm: never show it.
      }
      if (alarm.raisedById != null && alarm.raisedById == session.user?.id) {
        return; // Your own alarm: you already got the confirmation.
      }
      if (!_seen.add(alarm.id)) return; // Delivered twice (socket + replay).
      if (_seen.length > 50) _seen.remove(_seen.first);

      onAlarm(alarm);
    }

    final socket = AppServices.instance.socket;
    final cancels = <void Function()>[
      socket.on(Events.emergencyAlert, handle),
      socket.on('emergency:panic', handle),
    ];
    return () {
      for (final c in cancels) {
        c();
      }
    };
  }

  /// Plays the alert on this device.
  ///
  /// Uses the bundled beep when present, otherwise the system alert sound plus a
  /// vibration, so an alarm is never silent just because the asset is missing.
  Future<void> playAlert() async {
    unawaited(HapticFeedback.heavyImpact());
    try {
      await rootBundle.load('assets/${AlarmConfig.soundAsset}');
    } catch (_) {
      unawaited(SystemSound.play(SystemSoundType.alert));
      return;
    }
    try {
      await _player.stop();
      await _player.play(AssetSource(AlarmConfig.soundAsset));
    } catch (e) {
      debugPrint('Alarm sound failed, using system alert: $e');
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  Future<void> stopAlert() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
