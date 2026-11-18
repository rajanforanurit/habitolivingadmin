import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/call_service.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/future_body.dart';

/// Who the signed-in user may call, and their recent calls.
///
/// The list comes from the backend, which only returns people in the same
/// society whom this role is allowed to call. Phone numbers are never shown:
/// the call goes through the app.
class CallContactsScreen extends StatefulWidget {
  const CallContactsScreen({super.key});

  @override
  State<CallContactsScreen> createState() => _CallContactsScreenState();
}

class _CallContactsScreenState extends State<CallContactsScreen> {
  String _role = '';
  String _search = '';
  String _tab = 'people';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _call(CallContact c) async {
    try {
      // The call screen opens by itself once the call is ringing
      // (IncomingCallOverlay listens to the call state).
      await AppServices.instance.calls.start(c);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Calls',
      subtitle: 'In-app calls with your society',
      fillBody: true,
      header: Column(
        children: [
          FilterChips(
            options: const [('people', 'People'), ('history', 'Recent')],
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
          if (_tab == 'people') ...[
            const SizedBox(height: Tokens.space2),
            SearchField(
              hint: 'Search by name',
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) setState(() => _search = v.trim());
                });
              },
            ),
            const SizedBox(height: Tokens.space2),
            FilterChips(
              options: const [('', 'Everyone'), ('RESIDENT', 'Residents'), ('GUARD', 'Guards'), ('SOCIETY_ADMIN', 'Admins')],
              value: _role,
              onChanged: (v) => setState(() => _role = v),
            ),
          ],
        ],
      ),
      body: _tab == 'people' ? _people() : _history(),
    );
  }

  Widget _people() => FutureBody<List<CallContact>>(
    key: ValueKey('$_role|$_search'),
    load: () => AppServices.instance.ops.callContacts(role: _role.isEmpty ? null : _role, search: _search),
    emptyIcon: Icons2.phone,
    emptyTitle: 'No one to call',
    emptyMessage: 'People in your society who you can call appear here.',
    builder: (context, people, _) => ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: Tokens.space8),
      itemCount: people.length,
      separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
      itemBuilder: (context, i) {
        final p = people[i];
        return Panel(
          child: Row(
            children: [
              InitialsAvatar(name: p.name),
              const SizedBox(width: Tokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                    Text(
                      [p.roleLabel, if (p.label != null) p.label!].join(' · '),
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Call ${p.name}',
                style: IconButton.styleFrom(backgroundColor: Tokens.positive, foregroundColor: Colors.white),
                icon: const AppIcon(Icons2.phone, size: IconSize.row, color: Colors.white),
                onPressed: () => _call(p),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _history() {
    final me = AppServices.instance.session.user?.id;
    return PagedBody<CallRecord>(
      key: const ValueKey('history'),
      refreshOn: const ['call:ended', 'call:missed', 'call:rejected', 'call:cancelled'],
      emptyIcon: Icons2.phone,
      emptyTitle: 'No calls yet',
      fetch: (page) => AppServices.instance.ops.callHistory(page: page),
      itemBuilder: (context, c, _) {
        final outgoing = c.callerId == me;
        final other = outgoing ? c.calleeName : c.callerName;
        final missed = c.status == 'MISSED' || (!outgoing && (c.status == 'CANCELLED' || c.status == 'REJECTED'));
        return Panel(
          child: Row(
            children: [
              AppIcon(
                missed ? Icons2.warning : Icons2.phone,
                size: IconSize.row,
                color: missed ? Tokens.danger : Tokens.inkMuted,
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(other ?? 'Unknown', style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                    Text(
                      [
                        outgoing ? 'Outgoing' : 'Incoming',
                        Fmt.dateTime(c.createdAt),
                        if (c.duration != null) _mmss(c.duration!),
                      ].join(' · '),
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: switch (c.status) {
                  'ENDED' => 'Completed',
                  'MISSED' => 'Missed',
                  'REJECTED' => 'Declined',
                  'CANCELLED' => 'Cancelled',
                  _ => c.status,
                },
                tone: missed ? Tone.danger : Tone.neutral,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// The active call: who, how long, and the mute / speaker / hang-up controls.
/// Shown for an outgoing call, a connecting call and a connected call; an
/// incoming ring uses [IncomingCallOverlay] first.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    AppServices.instance.calls.addListener(_onChange);
  }

  @override
  void dispose() {
    _tick?.cancel();
    AppServices.instance.calls.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final calls = AppServices.instance.calls;
    if (calls.phase == CallPhase.idle && mounted) {
      Navigator.of(context).maybePop();
    } else if (mounted) {
      setState(() {});
    }
  }

  String _status(CallService calls) => switch (calls.phase) {
    CallPhase.outgoing => 'Calling…',
    CallPhase.incoming => 'Incoming call',
    CallPhase.connecting => 'Connecting…',
    CallPhase.connected => _elapsed(calls.connectedAt),
    CallPhase.ended => calls.endReason ?? 'Call ended',
    CallPhase.idle => '',
  };

  static String _elapsed(DateTime? since) {
    if (since == null) return 'Connected';
    final d = DateTime.now().difference(since);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final calls = AppServices.instance.calls;
    final live = calls.phase == CallPhase.connected;
    return PopScope(
      canPop: calls.phase == CallPhase.idle || calls.phase == CallPhase.ended,
      child: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space6),
            child: Column(
              children: [
                const Spacer(),
                InitialsAvatar(name: calls.peerName, size: 112),
                const SizedBox(height: Tokens.space6),
                Text(
                  calls.peerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'InstrumentSans', fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                if (calls.peerLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(calls.peerLabel!, style: const TextStyle(fontFamily: 'InstrumentSans', color: Colors.white70)),
                  ),
                const SizedBox(height: Tokens.space3),
                Text(_status(calls), style: const TextStyle(fontFamily: 'InstrumentSans', fontSize: 16, color: Colors.white70)),
                const Spacer(),
                if (calls.phase != CallPhase.ended)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundButton(
                        icon: calls.muted ? Icons.mic_off : Icons.mic,
                        label: calls.muted ? 'Unmute' : 'Mute',
                        active: calls.muted,
                        onTap: live ? () => calls.toggleMute() : null,
                      ),
                      _RoundButton(
                        icon: Icons.call_end,
                        label: calls.phase == CallPhase.outgoing ? 'Cancel' : 'End',
                        color: Tokens.danger,
                        onTap: () => calls.hangUp(),
                      ),
                      _RoundButton(
                        icon: calls.speaker ? Icons.volume_up : Icons.volume_down,
                        label: 'Speaker',
                        active: calls.speaker,
                        onTap: live ? () => calls.toggleSpeaker() : null,
                      ),
                    ],
                  ),
                const SizedBox(height: Tokens.space6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap, this.color, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color ?? (active ? Colors.white : Colors.white24),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(icon, color: color != null ? Colors.white : (active ? Colors.black : (enabled ? Colors.white : Colors.white38)), size: 30),
            ),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        Text(label, style: const TextStyle(fontFamily: 'InstrumentSans', fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

/// Mounted once above the signed-in shell. Shows a full-screen ring for an
/// incoming call, and opens [CallScreen] once it is answered.
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> {
  bool _screenOpen = false;

  @override
  void initState() {
    super.initState();
    final calls = AppServices.instance.calls;
    calls.attach();
    calls.addListener(_onChange);
  }

  @override
  void dispose() {
    AppServices.instance.calls.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final calls = AppServices.instance.calls;
    final inCall = calls.phase == CallPhase.connecting || calls.phase == CallPhase.connected || calls.phase == CallPhase.outgoing;
    if (inCall && !_screenOpen) {
      _screenOpen = true;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CallScreen(), fullscreenDialog: true))
          .whenComplete(() => _screenOpen = false);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final calls = AppServices.instance.calls;
    return Stack(
      children: [
        widget.child,
        if (calls.phase == CallPhase.incoming)
          Positioned.fill(
            child: Material(
              color: const Color(0xFF101418),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space6),
                  child: Column(
                    children: [
                      const Spacer(),
                      InitialsAvatar(name: calls.peerName, size: 112),
                      const SizedBox(height: Tokens.space6),
                      Text(calls.peerName, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'InstrumentSans', fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white)),
                      if (calls.peerLabel != null)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(calls.peerLabel!, style: const TextStyle(fontFamily: 'InstrumentSans', color: Colors.white70))),
                      const SizedBox(height: Tokens.space3),
                      const Text('Incoming call…', style: TextStyle(fontFamily: 'InstrumentSans', fontSize: 16, color: Colors.white70)),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundButton(icon: Icons.call_end, label: 'Decline', color: Tokens.danger, onTap: () => calls.reject()),
                          _RoundButton(icon: Icons.call, label: 'Answer', color: Tokens.positive, onTap: () => calls.accept()),
                        ],
                      ),
                      const SizedBox(height: Tokens.space6),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
