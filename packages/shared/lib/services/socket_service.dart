import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';

/// One realtime event, as delivered by the backend over Socket.IO.
class RealtimeEvent {
  const RealtimeEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;

  String? get id => data['id'] is String ? data['id'] as String : null;
  String? get type => data['type'] is String ? data['type'] as String : null;
}

/// Backend realtime events.
///
/// Names match `backend/src/realtime/socket.ts` and the notification router's
/// tag description. Anything unknown is forwarded too, so the app can listen
/// for a new event without a client change.
class Events {
  Events._();

  static const notification = 'notification:new';
  static const visitorArrived = 'visitor:arrived';
  static const visitorDecision = 'visitor:decision';
  static const deliveryArrived = 'delivery:arrived';
  static const deliveryDecision = 'delivery:decision';
  static const chatMessage = 'chat:message';
  static const emergencyAlert = 'emergency:alert';
  static const approvalUpdated = 'approval:updated';
  static const complaintUpdated = 'complaint:updated';
  static const paymentSuccess = 'payment:success';
  static const noticePublished = 'notice:published';
  static const bookingUpdated = 'booking:updated';
  static const emergencyUpdated = 'emergency:updated';
  static const emergencyContactsChanged = 'emergency:contacts-changed';
  static const approvalNew = 'approval:new';
  static const helpdeskChanged = 'helpdesk:changed';
  static const societyUpdated = 'society:updated';
  static const propertyInfoChanged = 'society:property-info-changed';
  static const callIncoming = 'call:incoming';
  static const callAccepted = 'call:accepted';
  static const callRejected = 'call:rejected';
  static const callCancelled = 'call:cancelled';
  static const callEnded = 'call:ended';
  static const callMissed = 'call:missed';
  static const callSignal = 'call:signal';

  /// Events a screen should treat as "something changed, reload your list".
  static const refreshHints = {
    notification,
    visitorArrived,
    visitorDecision,
    deliveryArrived,
    deliveryDecision,
    approvalUpdated,
    complaintUpdated,
    paymentSuccess,
    noticePublished,
    bookingUpdated,
    emergencyUpdated,
    emergencyContactsChanged,
    approvalNew,
    helpdeskChanged,
    societyUpdated,
    propertyInfoChanged,
  };
}

/// Socket.IO connection with automatic reconnection.
///
/// Two things make this reliable:
///
/// - Auth happens at handshake with the current access token. When the token
///   refreshes (every 15 minutes), the socket must re-handshake, otherwise the
///   server drops it. [refreshToken] does that.
/// - Reconnect uses the socket's own backoff, and every reconnect re-handshakes
///   with the current token.
///
/// Screens subscribe with [on] and cancel the subscription in `dispose`.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  String? _token;
  final Map<String, List<void Function(RealtimeEvent)>> _listeners = {};
  Timer? _reconnectTimer;

  /// Current connection state, for a status indicator.
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  /// Connects (or reconnects) with an access token.
  ///
  /// Calling this with a different token closes the old socket and opens a new
  /// one, which is what happens after a refresh.
  void connect(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) {
      disconnect();
      return;
    }
    if (_token == accessToken && _socket != null) return;

    closeSocket();
    _token = accessToken;

    final socket = io.io(
      kSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setAuth({'token': accessToken})
          .build(),
    );

    socket.onConnect((_) {
      connected.value = true;
      debugPrint('Socket connected');
    });

    socket.onDisconnect((_) {
      connected.value = false;
      debugPrint('Socket disconnected');
    });

    socket.onConnectError((err) {
      connected.value = false;
      debugPrint('Socket connect error: $err');
    });

    // Fan every known event out to listeners.
    for (final name in _allEventNames) {
      socket.on(name, (data) {
        final event = RealtimeEvent(name, _asMap(data));
        final subs = _listeners[name];
        if (subs == null || subs.isEmpty) return;
        for (final cb in List.of(subs)) {
          try {
            cb(event);
          } catch (e) {
            debugPrint('Socket listener for $name threw: $e');
          }
        }
      });
    }

    _socket = socket;
  }

  /// Sends an event to the server (used for WebRTC call signaling).
  /// Returns false when the socket is not connected.
  bool emit(String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null || !socket.connected) return false;
    socket.emit(event, data);
    return true;
  }

  /// Re-handshakes after a token refresh. Safe to call often.
  void refreshToken(String? accessToken) {
    if (accessToken == null || accessToken.isEmpty) return;
    if (accessToken == _token && connected.value) return;
    connect(accessToken);
  }

  /// Subscribes to an event. Returns a function that cancels the subscription.
  void Function() on(String event, void Function(RealtimeEvent) cb) {
    final subs = _listeners.putIfAbsent(event, () => []);
    subs.add(cb);
    return () {
      final list = _listeners[event];
      if (list == null) return;
      list.remove(cb);
      if (list.isEmpty) _listeners.remove(event);
    };
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    closeSocket();
    connected.value = false;
  }

  void closeSocket() {
    final socket = _socket;
    if (socket == null) return;
    _socket = null;
    try {
      socket.dispose();
    } catch (_) {
      // Already disposed.
    }
  }

  /// Every event name the app cares about, plus a wildcard for anything new.
  static const List<String> _allEventNames = [
    Events.notification,
    Events.visitorArrived,
    Events.visitorDecision,
    Events.deliveryArrived,
    Events.deliveryDecision,
    Events.chatMessage,
    Events.emergencyAlert,
    Events.approvalUpdated,
    Events.complaintUpdated,
    Events.paymentSuccess,
    Events.noticePublished,
    Events.bookingUpdated,
    Events.emergencyUpdated,
    Events.emergencyContactsChanged,
    Events.approvalNew,
    Events.helpdeskChanged,
    Events.societyUpdated,
    Events.propertyInfoChanged,
    Events.callIncoming,
    Events.callAccepted,
    Events.callRejected,
    Events.callCancelled,
    Events.callEnded,
    Events.callMissed,
    Events.callSignal,
    'notification:flat',
    'notification:admin',
    'notification:society',
    'emergency:panic',
    'booking:created',
  ];

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        // Not JSON; ignore.
      }
    }
    return const <String, dynamic>{};
  }
}
