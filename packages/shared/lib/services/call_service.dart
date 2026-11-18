import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/json.dart';
import '../models/ops.dart';
import 'api/society_ops_api.dart';
import 'socket_service.dart';

/// Where a call is in its life.
enum CallPhase {
  idle,

  /// I started a call and the other side is ringing.
  outgoing,

  /// Someone is calling me.
  incoming,

  /// Accepted; exchanging WebRTC offers and candidates.
  connecting,

  /// Audio is flowing.
  connected,

  /// Finished, rejected, missed or failed. Shown briefly, then idle.
  ended,
}

/// In-app audio calling.
///
/// Architecture: the REST API (`/calls`) owns call state and authorisation,
/// Socket.IO only relays WebRTC signaling (`call:signal`), and the audio itself
/// travels peer-to-peer over WebRTC through the STUN/TURN servers the backend
/// hands out. Socket.IO never carries audio.
///
/// One call at a time per device. UI listens to this object (it is a
/// [ChangeNotifier]); the incoming-call overlay and the call screen are both
/// driven from [phase].
class CallService extends ChangeNotifier {
  CallService(this._api, this._socket);

  final SocietyOpsApi _api;
  final SocketService _socket;

  CallPhase _phase = CallPhase.idle;
  CallRecord? _call;
  bool _isCaller = false;
  String? _peerName;
  String? _peerLabel;
  String? _endReason;
  bool _muted = false;
  bool _speaker = false;
  DateTime? _connectedAt;
  Timer? _ringTimer;
  Timer? _resetTimer;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;
  final List<void Function()> _subs = [];
  bool _attached = false;

  CallPhase get phase => _phase;
  CallRecord? get call => _call;
  bool get isCaller => _isCaller;
  String get peerName => _peerName ?? 'Unknown';
  String? get peerLabel => _peerLabel;
  String? get endReason => _endReason;
  bool get muted => _muted;
  bool get speaker => _speaker;
  DateTime? get connectedAt => _connectedAt;
  bool get busy => _phase != CallPhase.idle && _phase != CallPhase.ended;

  /// Subscribes to the call events. Safe to call repeatedly; the signed-in
  /// shell calls it once.
  void attach() {
    if (_attached) return;
    _attached = true;
    _subs
      ..add(_socket.on(Events.callIncoming, _onIncoming))
      ..add(_socket.on(Events.callAccepted, _onAccepted))
      ..add(_socket.on(Events.callRejected, (e) => _finish('Call declined')))
      ..add(_socket.on(Events.callCancelled, (e) => _finish('Call cancelled')))
      ..add(_socket.on(Events.callEnded, (e) => _finish('Call ended')))
      ..add(_socket.on(Events.callMissed, (e) => _finish('No answer')))
      ..add(_socket.on(Events.callSignal, _onSignal));
  }

  /// Called on sign-out: drop any call and stop listening.
  void reset() {
    for (final cancel in _subs) {
      cancel();
    }
    _subs.clear();
    _attached = false;
    unawaited(_teardown());
    _phase = CallPhase.idle;
    _call = null;
    notifyListeners();
  }

  // ----------------------------------------------------------- outgoing

  /// Rings [contact]. Throws the API's message when the call is refused
  /// (outside the society, busy, ...).
  Future<void> start(CallContact contact) async {
    if (busy) throw StateError('You are already on a call.');
    _resetTimer?.cancel();
    _isCaller = true;
    _peerName = contact.name;
    _peerLabel = contact.label ?? contact.roleLabel;
    _endReason = null;
    try {
      final record = await _api.startCall(contact.userId);
      _call = record;
      _setPhase(CallPhase.outgoing);
      _armRingTimeout();
    } catch (_) {
      _setPhase(CallPhase.idle);
      rethrow;
    }
  }

  // ----------------------------------------------------------- incoming

  void _onIncoming(RealtimeEvent e) {
    final d = e.data;
    final callId = asStringOrNull(d['callId']);
    if (callId == null) return;
    if (busy) {
      // Already on a call: decline quietly so the caller is not left ringing.
      unawaited(_api.rejectCall(callId).catchError((_) {}));
      return;
    }
    _resetTimer?.cancel();
    _isCaller = false;
    _peerName = asString(d['callerName'], fallback: 'Incoming call');
    final role = asString(d['callerRole']);
    final label = asStringOrNull(d['callerLabel']);
    _peerLabel = switch (role) {
      'RESIDENT' => label == null ? 'Resident' : 'Flat $label',
      'GUARD' => label == null ? 'Security guard' : 'Security · $label',
      'SOCIETY_ADMIN' => label ?? 'Society admin',
      _ => label,
    };
    _endReason = null;
    _call = CallRecord(
      id: callId,
      callerId: asString(d['callerId']),
      calleeId: '',
      status: 'RINGING',
      callerName: _peerName,
      callerLabel: label,
    );
    _setPhase(CallPhase.incoming);
    _armRingTimeout(seconds: asInt(d['ringSeconds'], fallback: 45));
  }

  Future<void> accept() async {
    final call = _call;
    if (call == null || _phase != CallPhase.incoming) return;
    try {
      await _api.acceptCall(call.id);
      _ringTimer?.cancel();
      _setPhase(CallPhase.connecting);
      await _createPeer();
    } catch (e) {
      await _finish('Could not answer: $e', notifyServer: false);
    }
  }

  Future<void> reject() async {
    final call = _call;
    if (call == null) return;
    try {
      await _api.rejectCall(call.id);
    } catch (_) {}
    await _finish('Call declined', notifyServer: false);
  }

  // ------------------------------------------------------------- signaling

  Future<void> _onAccepted(RealtimeEvent e) async {
    final call = _call;
    if (call == null || !_isCaller || e.data['callId'] != call.id) return;
    _ringTimer?.cancel();
    _setPhase(CallPhase.connecting);
    try {
      await _createPeer();
      final offer = await _pc!.createOffer({'offerToReceiveAudio': 1});
      await _pc!.setLocalDescription(offer);
      _sendSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
    } catch (err) {
      await _finish('Could not start audio: $err');
    }
  }

  Future<void> _onSignal(RealtimeEvent e) async {
    final call = _call;
    if (call == null || e.data['callId'] != call.id) return;
    final type = asString(e.data['type']);
    final data = asMap(e.data['data']);
    try {
      switch (type) {
        case 'offer':
          if (_pc == null) await _createPeer();
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
              asString(data['sdp']),
              asString(data['type'], fallback: 'offer'),
            ),
          );
          _remoteDescriptionSet = true;
          await _flushCandidates();
          final answer = await _pc!.createAnswer({'offerToReceiveAudio': 1});
          await _pc!.setLocalDescription(answer);
          _sendSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
        case 'answer':
          await _pc?.setRemoteDescription(
            RTCSessionDescription(
              asString(data['sdp']),
              asString(data['type'], fallback: 'answer'),
            ),
          );
          _remoteDescriptionSet = true;
          await _flushCandidates();
        case 'candidate':
          final c = RTCIceCandidate(
            asStringOrNull(data['candidate']),
            asStringOrNull(data['sdpMid']),
            asIntOrNull(data['sdpMLineIndex']),
          );
          if (_remoteDescriptionSet && _pc != null) {
            await _pc!.addCandidate(c);
          } else {
            _pendingCandidates.add(c);
          }
      }
    } catch (err) {
      debugPrint('Call signal $type failed: $err');
    }
  }

  void _sendSignal(String type, Map<String, dynamic> data) {
    final call = _call;
    if (call == null) return;
    _socket.emit(Events.callSignal, {
      'callId': call.id,
      'type': type,
      'data': data,
    });
  }

  Future<void> _flushCandidates() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in List.of(_pendingCandidates)) {
      await pc.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  // ------------------------------------------------------------ media/peer

  Future<void> _createPeer() async {
    if (_pc != null) return;
    final ice = await _api.iceServers();
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': {'echoCancellation': true, 'noiseSuppression': true},
      'video': false,
    });
    final pc = await createPeerConnection({
      'iceServers': ice.iceServers,
      'sdpSemantics': 'unified-plan',
    });
    for (final track in _local!.getAudioTracks()) {
      await pc.addTrack(track, _local!);
    }
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _sendSignal('candidate', {
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _connectedAt ??= DateTime.now();
          _setPhase(CallPhase.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          unawaited(_finish('Connection lost'));
        default:
          break;
      }
    };
    _pc = pc;
    _remoteDescriptionSet = false;
    // Earpiece by default, like a phone call.
    await Helper.setSpeakerphoneOn(false);
    _speaker = false;
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !_muted;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speaker = !_speaker;
    await Helper.setSpeakerphoneOn(_speaker);
    notifyListeners();
  }

  // --------------------------------------------------------------- ending

  /// Hang up, cancel or (for an unanswered incoming call) decline.
  Future<void> hangUp() async {
    final call = _call;
    if (call == null) return;
    try {
      switch (_phase) {
        case CallPhase.outgoing:
          await _api.cancelCall(call.id);
        case CallPhase.incoming:
          await _api.rejectCall(call.id);
        default:
          await _api.endCall(call.id);
      }
    } catch (_) {
      // The other side may have ended it first; either way we are done.
    }
    await _finish('Call ended', notifyServer: false);
  }

  void _armRingTimeout({int seconds = 45}) {
    _ringTimer?.cancel();
    _ringTimer = Timer(Duration(seconds: seconds + 3), () {
      if (_phase == CallPhase.outgoing || _phase == CallPhase.incoming) {
        unawaited(_finish('No answer', notifyServer: false));
      }
    });
  }

  Future<void> _finish(String reason, {bool notifyServer = false}) async {
    if (_phase == CallPhase.idle || _phase == CallPhase.ended) return;
    _ringTimer?.cancel();
    _endReason = reason;
    await _teardown();
    _setPhase(CallPhase.ended);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      _call = null;
      _setPhase(CallPhase.idle);
    });
  }

  Future<void> _teardown() async {
    _ringTimer?.cancel();
    try {
      for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _local?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _local = null;
    _pc = null;
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _muted = false;
    _connectedAt = null;
  }

  void _setPhase(CallPhase p) {
    _phase = p;
    notifyListeners();
  }
}
