import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// One property a resident can switch to: a flat inside a society.
///
/// A resident with flats in two societies has two societies and (at least) two
/// properties; a resident with two flats in one society has one society and two
/// properties. [flat] is null for a membership that has no flat linked yet.
class ResidentProperty {
  const ResidentProperty({
    required this.societyId,
    required this.societyName,
    this.flat,
  });

  final String societyId;
  final String societyName;
  final MemberFlat? flat;

  /// Stable key for selection.
  String get key => '$societyId::${flat?.flatId ?? ''}';

  /// "A-101" or, with no flat linked, the society name.
  String get title {
    final label = (flat?.label ?? flat?.flatId ?? '').trim();
    return label.isEmpty ? societyName : label;
  }

  String get subtitle => flat == null ? 'No flat linked yet' : societyName;
}

/// The signed-in user's session, as the UI sees it.
///
/// Wraps [AuthIdentity] with the handful of questions screens ask: which society
/// am I in, what is my role, which flats do I belong to, and am I allowed to see
/// this section.
class Session extends ChangeNotifier {
  AuthIdentity? _identity;
  AuthIdentity? get identity => _identity;
  AppUser? get user => _identity?.user;
  bool get isSignedIn => _identity != null;

  String? get activeSocietyId {
    final id = _identity?.activeSocietyId;
    if (id != null) return id;
    // A freshly registered resident has no memberships yet. `.first` on an
    // empty list throws "Bad state: No element", which crashed the home tab
    // right after sign-up; return null instead and let the UI show the
    // "join a society" state.
    final societies = _identity?.societies ?? const [];
    return societies.isEmpty ? null : societies.first.societyId;
  }

  String get userType => _identity?.user.userType ?? '';

  /// The signed-in role as a typed value, for exhaustive `switch` in the UI.
  UserRole get role => UserRole.fromWire(userType);

  bool get isSuperAdmin => userType == 'SUPER_ADMIN';
  bool get isSocietyAdmin => userType == 'SOCIETY_ADMIN';
  bool get isGuard => userType == 'GUARD';
  bool get isResident => userType == 'RESIDENT';

  /// The membership for the active society.
  SocietyMembership? get membership {
    final id = activeSocietyId;
    final societies = _identity?.societies ?? const [];
    if (id != null) {
      for (final s in societies) {
        if (s.societyId == id) return s;
      }
    }
    return societies.isEmpty ? null : societies.first;
  }

  /// Every society the user belongs to, for the switcher.
  List<SocietyMembership> get societies => _identity?.societies ?? const [];

  /// The flats the user belongs to, for flat pickers.
  List<MemberFlat> get flats => _identity?.allFlats ?? const [];

  String get societyName => membership?.societyName ?? 'Society';

  String get displayName => user?.name ?? 'User';

  // ---------------------------------------------------------- properties

  String? _selectedPropertyKey;

  /// Every property the user has, across all their societies.
  List<ResidentProperty> get properties {
    final out = <ResidentProperty>[];
    for (final s in societies) {
      if (s.flats.isEmpty) {
        out.add(ResidentProperty(societyId: s.societyId, societyName: s.societyName));
      } else {
        for (final f in s.flats) {
          out.add(
            ResidentProperty(
              societyId: s.societyId,
              societyName: s.societyName,
              flat: f,
            ),
          );
        }
      }
    }
    return out;
  }

  /// The property shown in the Home header.
  ///
  /// Always belongs to the active society: the society decides which data the
  /// backend returns, so a stale selection from another society is ignored.
  ResidentProperty? get selectedProperty {
    final all = properties;
    if (all.isEmpty) return null;
    final activeId = activeSocietyId;
    final inActive = all.where((p) => p.societyId == activeId).toList();
    final pool = inActive.isEmpty ? all : inActive;
    for (final p in pool) {
      if (p.key == _selectedPropertyKey) return p;
    }
    return pool.first;
  }

  /// Remembers which flat the resident picked. Switching *society* is a
  /// separate step (it needs fresh tokens), done by the caller first.
  void selectProperty(ResidentProperty property) {
    _selectedPropertyKey = property.key;
    notifyListeners();
  }

  void update(AuthIdentity? identity) {
    _identity = identity;
    notifyListeners();
  }

  /// Called when the user switches society. The identity is re-fetched by the
  /// caller because switching issues fresh tokens.
  void setIdentity(AuthIdentity identity) => update(identity);

  void clear() {
    _identity = null;
    _selectedPropertyKey = null;
    notifyListeners();
  }
}
