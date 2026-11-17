import 'json.dart';

/// Society, tower, floor and flat.
///
/// These four types are the backbone of the app: every row of data is attached
/// to a flat, and every flat is inside a society the user belongs to. The
/// shapes mirror the backend enums in
/// `backend/src/common/constants/enums.ts`.

class Society {
  const Society({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.status,
    this.address,
    this.city,
    this.state,
    this.createdAt,
  });

  factory Society.fromJson(Map<String, dynamic> json) {
    final address = asMapOrNull(json['address']);
    return Society(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'Society'),
      code: asString(json['code']),
      type: humanize(asString(json['type'], fallback: 'APARTMENT')),
      status: asString(json['status'], fallback: 'ACTIVE'),
      address: asStringOrNull(address?['line1'] ?? json['addressLine1']),
      city: asStringOrNull(address?['city'] ?? json['city']),
      state: asStringOrNull(address?['state'] ?? json['state']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String name;
  final String code;
  final String type;
  final String status;
  final String? address;
  final String? city;
  final String? state;
  final DateTime? createdAt;

  /// One-line location, e.g. "Patna, Bihar". Null when the backend has no
  /// address at all.
  String? get location {
    final parts = [
      city,
      state,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return address;
    return parts.join(', ');
  }

  String get initial =>
      name.trim().isEmpty ? 'S' : name.trim()[0].toUpperCase();
}

class Tower {
  const Tower({
    required this.id,
    required this.name,
    this.floors = 0,
    this.flats = 0,
  });

  factory Tower.fromJson(Map<String, dynamic> json) => Tower(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Tower'),
    floors: asInt(json['floorCount'] ?? json['floors']),
    flats: asInt(json['flatCount'] ?? json['flats']),
  );

  final String id;
  final String name;
  final int floors;
  final int flats;
}

class Floor {
  const Floor({
    required this.id,
    required this.number,
    this.towerId,
    this.flats = 0,
  });

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
    id: asString(json['id']),
    number: asInt(json['number']),
    towerId: asStringOrNull(json['towerId']),
    flats: asInt(json['flatCount'] ?? json['flats']),
  );

  final String id;
  final int number;
  final String? towerId;
  final int flats;
}

/// A flat (apartment unit) in a society.
class Flat {
  const Flat({
    required this.id,
    required this.label,
    required this.status,
    this.towerId,
    this.floorId,
    this.towerName,
    this.floorNumber,
    this.areaSqft,
    this.occupancy = '',
  });

  factory Flat.fromJson(Map<String, dynamic> json) {
    final tower = asMapOrNull(json['tower']);
    final floor = asMapOrNull(json['floor']);
    return Flat(
      id: asString(json['id'] ?? json['flatId']),
      label: asString(
        json['label'] ?? json['number'] ?? json['name'],
        fallback: 'Flat',
      ),
      status: humanize(asString(json['status'], fallback: 'VACANT')),
      towerId: asStringOrNull(json['towerId'] ?? tower?['id']),
      floorId: asStringOrNull(json['floorId'] ?? floor?['id']),
      towerName: asStringOrNull(tower?['name'] ?? json['towerName']),
      floorNumber: asIntOrNull(floor?['number'] ?? json['floorNumber']),
      areaSqft: asIntOrNull(json['areaSqft'] ?? json['area']),
      occupancy: humanize(asString(json['occupancy'], fallback: '')),
    );
  }

  final String id;
  final String label;
  final String status;
  final String? towerId;
  final String? floorId;
  final String? towerName;
  final int? floorNumber;
  final int? areaSqft;
  final String occupancy;

  /// "B-1204 · Tower B", or just the label when the tower is unknown.
  String get qualified {
    if (towerName == null || towerName!.isEmpty) return label;
    return '$label · $towerName';
  }
}

/// A resident record: a user attached to a flat with a role.
class Resident {
  const Resident({
    required this.id,
    required this.userId,
    required this.name,
    required this.mobile,
    required this.status,
    required this.residentType,
    this.flat,
    this.email,
    this.userType = 'RESIDENT',
    this.joinedAt,
    this.permissions = const {},
  });

  factory Resident.fromJson(Map<String, dynamic> json) {
    // The backend nests the user: { userId, user: { name, mobile, email } }.
    // Some admin list endpoints flatten it. Read both.
    final user = asMapOrNull(json['user']);
    final flat = asMapOrNull(json['flat']);
    return Resident(
      id: asString(json['id']),
      userId: asString(json['userId'] ?? json['_id'] ?? user?['id']),
      name: asString(
        user?['name'] ?? json['name'] ?? json['residentName'],
        fallback: 'Resident',
      ),
      mobile: asString(user?['mobile'] ?? json['mobile']),
      email: asStringOrNull(user?['email'] ?? json['email']),
      status: humanize(asString(json['status'], fallback: 'PENDING')),
      residentType: humanize(asString(json['residentType'], fallback: 'OWNER')),
      userType: humanize(
        asString(user?['userType'] ?? json['userType'], fallback: 'RESIDENT'),
      ),
      flat: flat != null
          ? Flat.fromJson({
              'id': json['flatId'],
              'label': flat['label'],
              'status': flat['status'],
            })
          : (json['flatId'] != null
                ? Flat.fromJson({
                    'id': json['flatId'],
                    'label': json['flatNumber'],
                  })
                : null),
      joinedAt: asDateOrNull(json['createdAt'] ?? json['joinedAt']),
      permissions: asMap(
        json['permissions'],
      ).map((k, v) => MapEntry(k, v == true)),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String mobile;
  final String? email;
  final String status;
  final String residentType;
  final String userType;
  final Flat? flat;
  final DateTime? joinedAt;
  final Map<String, bool> permissions;
}

/// The user's membership of one society.
class Membership {
  const Membership({
    required this.id,
    required this.societyId,
    required this.societyName,
    required this.role,
    required this.status,
    this.flats = const [],
    this.joinedAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: asString(json['id'] ?? json['membershipId']),
      societyId: asString(json['societyId']),
      societyName: asString(
        json['societyName'] ?? json['society'] ?? json['name'],
        fallback: 'Society',
      ),
      role: humanize(asString(json['role'], fallback: 'RESIDENT')),
      status: humanize(asString(json['status'], fallback: 'APPROVED')),
      flats: asMapList(
        json['flats'],
      ).map(Flat.fromJson).toList(growable: false),
      joinedAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String societyId;
  final String societyName;
  final String role;
  final String status;
  final List<Flat> flats;
  final DateTime? joinedAt;

  bool get isAdmin => role.toUpperCase().contains('ADMIN');

  /// "Green Valley · B-1204" for a member with one flat.
  String get summary {
    if (flats.isEmpty) return societyName;
    final labels = flats.map((f) => f.label).join(', ');
    return '$societyName · $labels';
  }
}

/// A membership request the user has made to join a society.
class SocietyRequest {
  const SocietyRequest({
    required this.id,
    required this.status,
    this.societyId,
    this.societyName,
    this.flatLabel,
    this.requestedAt,
    this.note,
    this.documentCount = 0,
  });

  factory SocietyRequest.fromJson(Map<String, dynamic> json) {
    final society = asMapOrNull(json['society']);
    return SocietyRequest(
      id: asString(json['id']),
      status: humanize(asString(json['status'], fallback: 'PENDING')),
      societyId: asStringOrNull(json['societyId'] ?? society?['id']),
      societyName: asStringOrNull(society?['name'] ?? json['societyName']),
      flatLabel: asStringOrNull(json['flatLabel'] ?? json['flatNumber']),
      requestedAt: asDateOrNull(json['createdAt']),
      note: asStringOrNull(json['note'] ?? json['reason']),
      documentCount: asInt(
        json['documentCount'] ??
            (json['documents'] is List
                ? (json['documents'] as List).length
                : 0),
      ),
    );
  }

  final String id;
  final String status;
  final String? societyId;
  final String? societyName;
  final String? flatLabel;
  final DateTime? requestedAt;
  final String? note;
  final int documentCount;
}

/// A family member attached to the resident's flat.
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    this.age,
    this.mobile,
    this.idProofAttached = false,
    this.status,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Family member'),
    relation: humanize(asString(json['relation'], fallback: 'FAMILY_MEMBER')),
    age: asIntOrNull(json['age']),
    mobile: asStringOrNull(json['mobile']),
    idProofAttached: asBool(
      json['idProofAttached'] ?? (json['verificationFileId'] != null),
    ),
    status: asStringOrNull(json['status']) == null
        ? null
        : humanize(asString(json['status'])),
  );

  final String id;
  final String name;
  final String relation;
  final int? age;
  final String? mobile;
  final bool idProofAttached;
  final String? status;
}

/// A move-in / move-out request.
class MoveRequest {
  const MoveRequest({
    required this.id,
    required this.type,
    required this.status,
    this.moveDate,
    this.flatLabel,
    this.reason,
    this.submittedAt,
  });

  factory MoveRequest.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return MoveRequest(
      id: asString(json['id']),
      type: humanize(asString(json['type'], fallback: 'MOVE_IN')),
      status: humanize(asString(json['status'], fallback: 'SUBMITTED')),
      moveDate: asDateOrNull(json['moveDate']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      reason: asStringOrNull(json['reason']),
      submittedAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String type;
  final String status;
  final DateTime? moveDate;
  final String? flatLabel;
  final String? reason;
  final DateTime? submittedAt;

  bool get isMoveIn => type.toUpperCase().contains('IN');
}
