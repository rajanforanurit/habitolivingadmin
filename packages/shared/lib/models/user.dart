/// Data models mirroring the backend auth payloads
/// (`GET /auth/me` and `POST /auth/login` → `data.user` / `data.societies`).
library;

import 'json.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.mobile,
    required this.userType,
    required this.isActive,
    required this.isMobileVerified,
    required this.mustChangePassword,
    this.email,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'User'),
      mobile: asString(json['mobile']),
      email: asStringOrNull(json['email']),
      userType: asString(json['userType'], fallback: 'RESIDENT'),
      isActive: asBool(json['isActive'], fallback: true),
      isMobileVerified: asBool(json['isMobileVerified']),
      mustChangePassword: asBool(json['mustChangePassword']),
    );
  }

  final String id;
  final String name;
  final String mobile;
  final String? email;
  final String userType; // SUPER_ADMIN | SOCIETY_ADMIN | GUARD | RESIDENT
  final bool isActive;
  final bool isMobileVerified;
  final bool mustChangePassword;
}

class MemberFlat {
  const MemberFlat({
    required this.flatId,
    required this.residentType,
    required this.status,
    this.label,
  });

  factory MemberFlat.fromJson(Map<String, dynamic> json) {
    return MemberFlat(
      flatId: asString(json['flatId']),
      label: asStringOrNull(json['label']),
      residentType: asString(json['residentType']),
      status: asString(json['status']),
    );
  }

  final String flatId;
  final String? label;
  final String residentType;
  final String status;
}

class SocietyMembership {
  const SocietyMembership({
    required this.societyId,
    required this.societyName,
    required this.role,
    required this.status,
    this.flats = const [],
  });

  factory SocietyMembership.fromJson(Map<String, dynamic> json) {
    return SocietyMembership(
      societyId: asString(json['societyId']),
      societyName: asString(json['societyName'], fallback: 'Society'),
      role: asString(json['role'], fallback: 'RESIDENT'),
      status: asString(json['status']),
      flats: asMapList(
        json['flats'],
      ).map(MemberFlat.fromJson).toList(growable: false),
    );
  }

  final String societyId;
  final String societyName;
  final String role; // SUPER_ADMIN | SOCIETY_ADMIN | GUARD | RESIDENT
  final String status; // e.g. APPROVED
  final List<MemberFlat> flats;
}

/// Full session identity returned by `/auth/login` and `/auth/me`.
class AuthIdentity {
  const AuthIdentity({
    required this.user,
    required this.societies,
    this.activeSocietyId,
  });

  factory AuthIdentity.fromJson(Map<String, dynamic> json) {
    return AuthIdentity(
      user: AppUser.fromJson(reqMap(json['user'], field: 'user')),
      societies: asMapList(
        json['societies'],
      ).map(SocietyMembership.fromJson).toList(growable: false),
      activeSocietyId: asStringOrNull(json['activeSocietyId']),
    );
  }

  final AppUser user;
  final List<SocietyMembership> societies;
  final String? activeSocietyId;

  /// The membership for the active society, if there is one.
  SocietyMembership? get activeMembership {
    if (societies.isEmpty) return null;
    final id = activeSocietyId;
    if (id != null) {
      for (final s in societies) {
        if (s.societyId == id) return s;
      }
    }
    return societies.first;
  }

  /// Every flat the user belongs to, across societies, for pickers.
  List<MemberFlat> get allFlats =>
      societies.expand((s) => s.flats).toList(growable: false);

  bool get isSuperAdmin => user.userType == 'SUPER_ADMIN';
  bool get isSocietyAdmin => user.userType == 'SOCIETY_ADMIN';
  bool get isGuard => user.userType == 'GUARD';
  bool get isResident => user.userType == 'RESIDENT';
}

/// Token pair returned by login / refresh / switch-society.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    this.societyId,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: asString(json['accessToken']),
      refreshToken: asString(json['refreshToken']),
      expiresIn: asIntOrNull(json['expiresIn']),
      societyId: asStringOrNull(json['societyId']),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int? expiresIn;
  final String? societyId;
}

/// The four roles the platform supports.
///
/// Mirrors `UserType` in `backend/src/common/constants/enums.ts`. The wire
/// value is what the API sends; the Dart value is what the UI switches on.
enum UserRole {
  superAdmin('SUPER_ADMIN'),
  societyAdmin('SOCIETY_ADMIN'),
  guard('GUARD'),
  resident('RESIDENT');

  const UserRole(this.wire);
  final String wire;

  static UserRole fromWire(String? value) {
    return switch ((value ?? '').toUpperCase()) {
      'SUPER_ADMIN' => UserRole.superAdmin,
      'SOCIETY_ADMIN' => UserRole.societyAdmin,
      'GUARD' => UserRole.guard,
      _ => UserRole.resident,
    };
  }

  /// True for the two admin roles, which share a lot of screens.
  bool get isAdmin =>
      this == UserRole.superAdmin || this == UserRole.societyAdmin;
}
