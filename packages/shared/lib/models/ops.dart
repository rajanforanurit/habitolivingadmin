/// Models for the society-operations endpoints: property info, helpdesk,
/// platform monitoring, emergency alarms, staff messages and in-app calls.
///
/// Every `raw*` / `*Key` field keeps the backend value unchanged for logic;
/// the matching display field is humanised for the UI. Never compare against a
/// display label.
library;

import 'json.dart';

// ---------------------------------------------------------------- property

/// One floor plan entry. [fileId] points at an uploaded image or PDF.
class FloorPlan {
  const FloorPlan({required this.title, this.description, this.fileId});

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
    title: asString(json['title']),
    description: asStringOrNull(json['description']),
    fileId: asStringOrNull(json['fileId'] ?? json['file']),
  );

  final String title;
  final String? description;
  final String? fileId;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    if (fileId != null && fileId!.isNotEmpty) 'fileId': fileId,
  };

  FloorPlan copyWith({String? title, String? description, String? fileId}) =>
      FloorPlan(
        title: title ?? this.title,
        description: description ?? this.description,
        fileId: fileId ?? this.fileId,
      );
}

/// The property description the platform team maintains for a society.
class PropertyDetails {
  const PropertyDetails({
    this.propertyName,
    this.description,
    this.totalTowers,
    this.totalFloors,
    this.totalUnits,
    this.parkingInfo,
    this.notes,
    this.floorPlans = const [],
    this.towers = const [],
    this.singleFamily,
  });

  factory PropertyDetails.fromJson(dynamic raw) {
    final json = asMap(raw);
    return PropertyDetails(
      propertyName: asStringOrNull(json['propertyName']),
      description: asStringOrNull(json['description']),
      totalTowers: asIntOrNull(json['totalTowers']),
      totalFloors: asIntOrNull(json['totalFloors']),
      totalUnits: asIntOrNull(json['totalUnits']),
      parkingInfo: asStringOrNull(json['parkingInfo']),
      notes: asStringOrNull(json['notes']),
      floorPlans: asMapList(
        json['floorPlans'],
      ).map(FloorPlan.fromJson).toList(growable: false),
      towers: asMapList(
        json['towers'],
      ).map(TowerConfig.fromJson).toList(growable: false),
      singleFamily: _singleFamilyOrNull(json['singleFamily']),
    );
  }

  static const empty = PropertyDetails();

  /// A single-family block only when it actually has houses (an empty stored
  /// object, e.g. on a multifamily society, means there is none).
  static SingleFamilyConfig? _singleFamilyOrNull(dynamic raw) {
    if (raw is! Map) return null;
    final sf = SingleFamilyConfig.fromJson(asMap(raw));
    return sf.totalHouses > 0 ? sf : null;
  }

  final String? propertyName;
  final String? description;
  final int? totalTowers;
  final int? totalFloors;
  final int? totalUnits;
  final String? parkingInfo;
  final String? notes;
  final List<FloorPlan> floorPlans;

  /// Multifamily layout: every tower with its flat names.
  final List<TowerConfig> towers;

  /// Single-family layout: the named houses / villas.
  final SingleFamilyConfig? singleFamily;

  bool get hasLayout => towers.isNotEmpty || singleFamily != null;

  bool get isEmpty =>
      !hasLayout &&
      (propertyName ?? '').isEmpty &&
      (description ?? '').isEmpty &&
      totalTowers == null &&
      totalFloors == null &&
      totalUnits == null &&
      (parkingInfo ?? '').isEmpty &&
      (notes ?? '').isEmpty &&
      floorPlans.isEmpty;

  /// The request body. Only filled fields are sent, so the backend's
  /// validation never sees an empty string where it expects a value.
  Map<String, dynamic> toJson() {
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      if (clean(propertyName) != null) 'propertyName': clean(propertyName),
      if (clean(description) != null) 'description': clean(description),
      if (clean(parkingInfo) != null) 'parkingInfo': clean(parkingInfo),
      if (clean(notes) != null) 'notes': clean(notes),
      if (floorPlans.isNotEmpty) 'floorPlans': floorPlans.map((f) => f.toJson()).toList(),
      // Totals are derived by the server from the layout; only the layout is sent.
      if (towers.isNotEmpty) 'towers': towers.map((t) => t.toJson()).toList(),
      if (singleFamily != null) 'singleFamily': singleFamily!.toJson(),
    };
  }
}

/// One floor of a tower and how many units it has.
///
/// Legacy only: older societies stored their towers as floors with a unit count.
/// New towers store their flat names directly (see [TowerConfig.flats]).
class FloorConfig {
  const FloorConfig({required this.number, required this.units});

  factory FloorConfig.fromJson(Map<String, dynamic> json) => FloorConfig(
    number: asInt(json['number']),
    units: asInt(json['units']),
  );

  final int number;
  final int units;

  Map<String, dynamic> toJson() => {'number': number, 'units': units};
}

/// A tower: its name and the names of its flats (e.g. A-101, A-102).
///
/// Floors are not configured separately; the floor is part of the flat name.
/// Towers saved before this change carry a [code] and [floors] instead of
/// [flats]; [flatNames] expands those into the flat names they produced, so
/// older societies can still be viewed and extended.
class TowerConfig {
  const TowerConfig({
    required this.name,
    this.flats = const [],
    this.code = '',
    this.floors = const [],
  });

  factory TowerConfig.fromJson(Map<String, dynamic> json) => TowerConfig(
    name: asString(json['name']),
    flats: [
      for (final f in asList(json['flats']))
        if (asString(f).trim().isNotEmpty) asString(f).trim(),
    ],
    code: asString(json['code']),
    floors: asMapList(
      json['floors'],
    ).map(FloorConfig.fromJson).toList(growable: false),
  );

  final String name;

  /// The flat names in this tower, exactly as they are shown to residents.
  final List<String> flats;

  /// Legacy: the tower code used to generate unit numbers (A-101).
  final String code;

  /// Legacy: floors and their unit counts.
  final List<FloorConfig> floors;

  /// The flat names of this tower, whether stored directly or (for older
  /// towers) generated from the code and floors.
  List<String> get flatNames => flats.isNotEmpty
      ? flats
      : [for (final f in floors) ...unitsOn(f)];

  int get totalUnits => flatNames.length;

  /// Legacy `A-101`: tower code, floor number, then the unit's two-digit position.
  static String unitLabel(String code, int floor, int index) =>
      '$code-$floor${index.toString().padLeft(2, '0')}';

  /// Legacy: every unit label of one floor.
  List<String> unitsOn(FloorConfig f) => [
    for (var i = 1; i <= f.units; i++) unitLabel(code, f.number, i),
  ];

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'flats': [for (final f in flatNames) f.trim()],
  };
}

/// Single-family property: named houses / villas instead of towers.
///
/// New societies store each house's name in [houses]. Societies saved before
/// that store a count with a label prefix and start number instead;
/// [houseNames] expands those into the names they produced (H-1, H-2 ...), so
/// older societies can still be viewed and extended.
class SingleFamilyConfig {
  const SingleFamilyConfig({
    this.houses = const [],
    this.legacyTotal = 0,
    this.labelPrefix = 'H-',
    this.startNumber = 1,
  });

  factory SingleFamilyConfig.fromJson(Map<String, dynamic> json) =>
      SingleFamilyConfig(
        houses: [
          for (final h in asList(json['houses']))
            if (asString(h).trim().isNotEmpty) asString(h).trim(),
        ],
        legacyTotal: asInt(json['totalHouses']),
        labelPrefix: asString(json['labelPrefix'], fallback: 'H-'),
        startNumber: asInt(json['startNumber'], fallback: 1),
      );

  /// The name of every house / villa, as residents know it.
  final List<String> houses;

  /// Legacy: number of houses, named [labelPrefix] + number from [startNumber].
  final int legacyTotal;
  final String labelPrefix;
  final int startNumber;

  /// Every house name, whether stored directly or (older societies) generated.
  List<String> get houseNames => houses.isNotEmpty
      ? houses
      : [for (var i = 0; i < legacyTotal; i++) '$labelPrefix${startNumber + i}'];

  int get totalHouses => houseNames.length;

  /// The name of the house at [i] (empty when out of range).
  String labelAt(int i) {
    final names = houseNames;
    return i >= 0 && i < names.length ? names[i] : '';
  }

  Map<String, dynamic> toJson() => {
    'houses': [for (final h in houseNames) h.trim()],
  };
}

/// The two property types a society can be created with.
class PropertyKind {
  PropertyKind._();
  static const multifamily = 'MULTIFAMILY';
  static const singleFamily = 'SINGLE_FAMILY';

  static String label(String? v) => switch (v) {
    multifamily => 'Multifamily',
    singleFamily => 'Single family',
    _ => 'Not set',
  };
}

/// One administrator of a society, as the Super Admin sees them.
class AdministratorRecord {
  const AdministratorRecord({
    required this.id,
    required this.name,
    required this.status,
    this.mobile,
    this.email,
    this.designation,
    this.roleName,
    this.lastLoginAt,
    this.addedAt,
    this.isPrimary = false,
    this.mustChangePassword = false,
  });

  factory AdministratorRecord.fromJson(Map<String, dynamic> json) {
    final role = asMapOrNull(json['role']);
    return AdministratorRecord(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'Administrator'),
      status: asString(json['status'], fallback: 'ACTIVE').toUpperCase(),
      mobile: asStringOrNull(json['mobile']),
      email: asStringOrNull(json['email']),
      designation: asStringOrNull(json['designation']),
      roleName: asStringOrNull(role?['name']),
      lastLoginAt: asDateOrNull(json['lastLoginAt']),
      addedAt: asDateOrNull(json['addedAt']),
      isPrimary: json['isPrimary'] == true,
      mustChangePassword: json['mustChangePassword'] == true,
    );
  }

  final String id;
  final String name;
  final String status;
  final String? mobile;
  final String? email;
  final String? designation;
  final String? roleName;
  final DateTime? lastLoginAt;
  final DateTime? addedAt;
  final bool isPrimary;
  final bool mustChangePassword;

  bool get isActive => status == 'ACTIVE';
}

/// "Administration details" of a society: who runs it, who created or
/// approved it, and when. Built from saved records on the server.
class SocietyAdministration {
  const SocietyAdministration({
    required this.societyName,
    required this.code,
    required this.status,
    this.administrators = const [],
    this.createdAt,
    this.createdByName,
    this.approvedAt,
    this.approvedByName,
    this.statusReason,
    this.applicantName,
    this.applicantMobile,
    this.applicantEmail,
    this.applicantNotes,
  });

  factory SocietyAdministration.fromJson(Map<String, dynamic> json) {
    final applicant = asMapOrNull(json['applicant']);
    return SocietyAdministration(
      societyName: asString(json['societyName']),
      code: asString(json['code']),
      status: asString(json['status']).toUpperCase(),
      administrators: asMapList(
        json['administrators'],
      ).map(AdministratorRecord.fromJson).toList(growable: false),
      createdAt: asDateOrNull(json['createdAt']),
      createdByName: asStringOrNull(json['createdByName']),
      approvedAt: asDateOrNull(json['approvedAt']),
      approvedByName: asStringOrNull(json['approvedByName']),
      statusReason: asStringOrNull(json['statusReason']),
      applicantName: asStringOrNull(applicant?['name']),
      applicantMobile: asStringOrNull(applicant?['mobile']),
      applicantEmail: asStringOrNull(applicant?['email']),
      applicantNotes: asStringOrNull(applicant?['notes']),
    );
  }

  final String societyName;
  final String code;
  final String status;
  final List<AdministratorRecord> administrators;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? approvedAt;
  final String? approvedByName;
  final String? statusReason;
  final String? applicantName;
  final String? applicantMobile;
  final String? applicantEmail;
  final String? applicantNotes;

  AdministratorRecord? get primary {
    for (final a in administrators) {
      if (a.isPrimary) return a;
    }
    return administrators.isEmpty ? null : administrators.first;
  }

  bool get hasApplicant =>
      (applicantName ?? applicantMobile ?? applicantEmail) != null;
}

/// A nearby hospital.
class Hospital {
  const Hospital({
    required this.name,
    required this.phone,
    this.address,
    this.distanceKm,
    this.open24x7 = true,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
    name: asString(json['name']),
    phone: asString(json['phone']),
    address: asStringOrNull(json['address']),
    distanceKm: asDoubleOrNull(json['distanceKm']),
    open24x7: asBool(json['open24x7'], fallback: true),
  );

  final String name;
  final String phone;
  final String? address;
  final double? distanceKm;
  final bool open24x7;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'phone': phone.trim(),
    if (address != null && address!.trim().isNotEmpty)
      'address': address!.trim(),
    if (distanceKm != null) 'distanceKm': distanceKm,
    'open24x7': open24x7,
  };
}

/// Property details and hospitals of one society, read-only for everyone but
/// the Super Admin.
class SocietyInfo {
  const SocietyInfo({
    required this.societyName,
    this.propertyDetails = PropertyDetails.empty,
    this.hospitals = const [],
    this.phone,
    this.emergencyPhone,
    this.propertyType,
    this.code,
  });

  factory SocietyInfo.fromJson(Map<String, dynamic> json) {
    final contact = asMap(json['contact']);
    return SocietyInfo(
      propertyType: asStringOrNull(json['propertyType']),
      code: asStringOrNull(json['code']),
      societyName: asString(
        json['societyName'] ?? json['name'],
        fallback: 'Society',
      ),
      propertyDetails: PropertyDetails.fromJson(json['propertyDetails']),
      hospitals: asMapList(
        json['hospitals'],
      ).map(Hospital.fromJson).toList(growable: false),
      phone: asStringOrNull(contact['phone']),
      emergencyPhone: asStringOrNull(contact['emergencyPhone']),
    );
  }

  final String societyName;
  final PropertyDetails propertyDetails;
  final List<Hospital> hospitals;
  final String? phone;
  final String? emergencyPhone;

  /// `MULTIFAMILY` or `SINGLE_FAMILY`; null for societies set up before types existed.
  final String? propertyType;
  final String? code;
}

// ---------------------------------------------------------------- helpdesk

/// A service provider (plumber, doctor, mechanic...) published to residents.
class HelpdeskContact {
  const HelpdeskContact({
    required this.id,
    required this.name,
    required this.mobile,
    required this.category,
    this.alternateMobile,
    this.designation,
    this.description,
    this.availability,
    this.isVisible = true,
    this.order = 0,
  });

  factory HelpdeskContact.fromJson(Map<String, dynamic> json) =>
      HelpdeskContact(
        id: asString(json['id']),
        name: asString(json['name'], fallback: 'Contact'),
        mobile: asString(json['mobile']),
        alternateMobile: asStringOrNull(json['alternateMobile']),
        category: asString(json['category'], fallback: 'OTHER'),
        designation: asStringOrNull(json['designation']),
        description: asStringOrNull(json['description']),
        availability: asStringOrNull(json['availability']),
        isVisible: asBool(json['isVisible'], fallback: true),
        order: asInt(json['order']),
      );

  final String id;
  final String name;
  final String mobile;
  final String? alternateMobile;

  /// Backend key, e.g. `PEST_CONTROL`.
  final String category;
  final String? designation;
  final String? description;
  final String? availability;
  final bool isVisible;
  final int order;

  String get categoryLabel => humanize(category);
}

class CategoryCount {
  const CategoryCount({required this.category, required this.count});
  factory CategoryCount.fromJson(Map<String, dynamic> json) => CategoryCount(
    category: asString(json['category']),
    count: asInt(json['count']),
  );
  final String category;
  final int count;
  String get label => humanize(category);
}

// ---------------------------------------------------------------- platform

class AuthSummary {
  const AuthSummary({
    required this.days,
    required this.successful,
    required this.failed,
    required this.distinctUsers,
    required this.unauthorized,
    required this.forbidden,
    required this.rateLimited,
    required this.byDay,
    required this.suspicious,
  });

  factory AuthSummary.fromJson(Map<String, dynamic> json) {
    final logins = asMap(json['logins']);
    final errors = asMap(json['authErrors']);
    return AuthSummary(
      days: asInt(json['days'], fallback: 7),
      successful: asInt(logins['successful']),
      failed: asInt(logins['failed']),
      distinctUsers: asInt(logins['distinctUsers']),
      unauthorized: asInt(errors['unauthorized']),
      forbidden: asInt(errors['forbidden']),
      rateLimited: asInt(errors['rateLimited']),
      byDay: asMapList(json['byDay']),
      suspicious: asMapList(json['suspicious']),
    );
  }

  final int days;
  final int successful;
  final int failed;
  final int distinctUsers;
  final int unauthorized;
  final int forbidden;
  final int rateLimited;
  final List<Map<String, dynamic>> byDay;
  final List<Map<String, dynamic>> suspicious;
}

class LoginActivity {
  const LoginActivity({
    required this.id,
    required this.identifier,
    required this.success,
    this.userName,
    this.userType,
    this.reason,
    this.method,
    this.ip,
    this.userAgent,
    this.createdAt,
  });

  factory LoginActivity.fromJson(Map<String, dynamic> json) {
    final user = asMapOrNull(json['user']);
    return LoginActivity(
      id: asString(json['id']),
      identifier: asString(json['identifier']),
      success: asBool(json['success']),
      userName: asStringOrNull(user?['name']),
      userType: asStringOrNull(user?['userType']),
      reason: asStringOrNull(json['reason']),
      method: asStringOrNull(json['method']),
      ip: asStringOrNull(json['ip']),
      userAgent: asStringOrNull(json['userAgent']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String identifier;
  final bool success;
  final String? userName;
  final String? userType;
  final String? reason;
  final String? method;
  final String? ip;
  final String? userAgent;
  final DateTime? createdAt;
}

class AuthEvent {
  const AuthEvent({
    required this.id,
    required this.status,
    this.code,
    this.message,
    this.method,
    this.path,
    this.userName,
    this.ip,
    this.createdAt,
  });

  factory AuthEvent.fromJson(Map<String, dynamic> json) {
    final user = asMapOrNull(json['user']);
    return AuthEvent(
      id: asString(json['id']),
      status: asInt(json['status']),
      code: asStringOrNull(json['code']),
      message: asStringOrNull(json['message']),
      method: asStringOrNull(json['method']),
      path: asStringOrNull(json['path']),
      userName: asStringOrNull(user?['name']),
      ip: asStringOrNull(json['ip']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final int status;
  final String? code;
  final String? message;
  final String? method;
  final String? path;
  final String? userName;
  final String? ip;
  final DateTime? createdAt;

  String get title => switch (status) {
    401 => 'Unauthorised',
    403 => 'Forbidden',
    429 => 'Rate limited',
    _ => 'Error $status',
  };
}

// --------------------------------------------------------------- emergency

/// An emergency alarm or security alert with the full who/where/when.
class EmergencyAlarm {
  const EmergencyAlarm({
    required this.id,
    required this.rawStatus,
    required this.type,
    required this.source,
    this.raisedByName,
    this.raisedByMobile,
    this.flatLabel,
    this.location,
    this.message,
    this.createdAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.acknowledgedByRole,
    this.resolvedAt,
    this.resolvedByName,
    this.resolvedByRole,
    this.notifiedContacts = const [],
  });

  factory EmergencyAlarm.fromJson(Map<String, dynamic> json) => EmergencyAlarm(
    id: asString(json['id']),
    rawStatus: asString(json['status'], fallback: 'ACTIVE').toUpperCase(),
    type: asString(json['type'], fallback: 'PANIC'),
    source: asString(json['source'], fallback: 'RESIDENT'),
    raisedByName: asStringOrNull(json['raisedByName']),
    raisedByMobile: asStringOrNull(json['raisedByMobile']),
    flatLabel: asStringOrNull(json['flatLabel']),
    location: asStringOrNull(json['location']),
    message: asStringOrNull(json['message']),
    createdAt: asDateOrNull(json['createdAt']),
    acknowledgedAt: asDateOrNull(json['acknowledgedAt']),
    acknowledgedByName: asStringOrNull(json['acknowledgedByName']),
    acknowledgedByRole: asStringOrNull(json['acknowledgedByRole']),
    resolvedAt: asDateOrNull(json['resolvedAt']),
    resolvedByName: asStringOrNull(json['resolvedByName']),
    resolvedByRole: asStringOrNull(json['resolvedByRole']),
    notifiedContacts: asMapList(json['notifiedContacts']),
  );

  final String id;

  /// `ACTIVE`, `ACKNOWLEDGED`, `RESOLVED` or `FALSE_ALARM`.
  final String rawStatus;
  final String type;
  final String source;
  final String? raisedByName;
  final String? raisedByMobile;
  final String? flatLabel;
  final String? location;
  final String? message;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final String? acknowledgedByRole;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String? resolvedByRole;
  final List<Map<String, dynamic>> notifiedContacts;

  bool get isActive => rawStatus == 'ACTIVE';
  bool get isOpen => rawStatus == 'ACTIVE' || rawStatus == 'ACKNOWLEDGED';
  String get typeLabel => humanize(type);
  String get statusLabel => humanize(rawStatus);
}

class StaffMessage {
  const StaffMessage({
    required this.id,
    required this.audience,
    required this.message,
    this.fromName,
    this.flatLabel,
    this.subject,
    this.createdAt,
  });

  factory StaffMessage.fromJson(Map<String, dynamic> json) => StaffMessage(
    id: asString(json['id']),
    audience: asString(json['audience'], fallback: 'ADMIN'),
    message: asString(json['message']),
    fromName: asStringOrNull(json['fromName']),
    flatLabel: asStringOrNull(json['flatLabel']),
    subject: asStringOrNull(json['subject']),
    createdAt: asDateOrNull(json['createdAt']),
  );

  final String id;
  final String audience;
  final String message;
  final String? fromName;
  final String? flatLabel;
  final String? subject;
  final DateTime? createdAt;
}

/// A custom or standard emergency-contact entry with visibility flags.
class ManagedEmergencyContact {
  const ManagedEmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.notes,
    this.order = 0,
    this.visibleToResidents = true,
    this.visibleToGuards = true,
  });

  factory ManagedEmergencyContact.fromJson(Map<String, dynamic> json) =>
      ManagedEmergencyContact(
        id: asString(json['id']),
        name: asString(json['name'], fallback: 'Contact'),
        phone: asString(json['phone']),
        category: asString(json['category'], fallback: 'OTHER'),
        notes: asStringOrNull(json['notes']),
        order: asInt(json['order']),
        visibleToResidents: asBool(json['visibleToResidents'], fallback: true),
        visibleToGuards: asBool(json['visibleToGuards'], fallback: true),
      );

  final String id;
  final String name;
  final String phone;
  final String category;
  final String? notes;
  final int order;
  final bool visibleToResidents;
  final bool visibleToGuards;

  String get categoryLabel => humanize(category);
}

// ------------------------------------------------------------ community

/// A community post as the moderator sees it, with author contact details.
class ModerationPost {
  const ModerationPost({
    required this.id,
    required this.title,
    required this.body,
    required this.rawStatus,
    this.authorName,
    this.authorMobile,
    this.flatLabel,
    this.rejectionReason,
    this.imageIds = const [],
    this.createdAt,
    this.publishedAt,
  });

  factory ModerationPost.fromJson(Map<String, dynamic> json) => ModerationPost(
    id: asString(json['id']),
    title: asString(json['title']),
    body: asString(json['body']),
    rawStatus: asString(json['status'], fallback: 'SUBMITTED').toUpperCase(),
    authorName: asStringOrNull(json['authorName']),
    authorMobile: asStringOrNull(json['authorMobile']),
    flatLabel: asStringOrNull(json['flatLabel']),
    rejectionReason: asStringOrNull(json['rejectionReason']),
    imageIds: asList(json['images']).map((e) => '$e').toList(growable: false),
    createdAt: asDateOrNull(json['createdAt']),
    publishedAt: asDateOrNull(json['publishedAt']),
  );

  final String id;
  final String title;
  final String body;
  final String rawStatus;
  final String? authorName;
  final String? authorMobile;
  final String? flatLabel;
  final String? rejectionReason;
  final List<String> imageIds;
  final DateTime? createdAt;
  final DateTime? publishedAt;
}

// ------------------------------------------------------------------ calls

class CallContact {
  const CallContact({
    required this.userId,
    required this.name,
    required this.role,
    this.label,
  });

  factory CallContact.fromJson(Map<String, dynamic> json) => CallContact(
    userId: asString(json['userId']),
    name: asString(json['name'], fallback: 'User'),
    role: asString(json['role'], fallback: 'RESIDENT'),
    label: asStringOrNull(json['label']),
  );

  final String userId;
  final String name;

  /// `RESIDENT`, `GUARD` or `SOCIETY_ADMIN`.
  final String role;

  /// Flat for residents, gate for guards, designation for admins.
  final String? label;

  String get roleLabel => switch (role) {
    'RESIDENT' => 'Resident',
    'GUARD' => 'Security guard',
    'SOCIETY_ADMIN' => 'Society admin',
    _ => humanize(role),
  };
}

class CallRecord {
  const CallRecord({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.status,
    this.callerName,
    this.calleeName,
    this.callerLabel,
    this.calleeLabel,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: asString(json['id']),
    callerId: asString(json['callerId']),
    calleeId: asString(json['calleeId']),
    status: asString(json['status'], fallback: 'RINGING').toUpperCase(),
    callerName: asStringOrNull(json['callerName']),
    calleeName: asStringOrNull(json['calleeName']),
    callerLabel: asStringOrNull(json['callerLabel']),
    calleeLabel: asStringOrNull(json['calleeLabel']),
    createdAt: asDateOrNull(json['createdAt']),
    answeredAt: asDateOrNull(json['answeredAt']),
    endedAt: asDateOrNull(json['endedAt']),
  );

  final String id;
  final String callerId;
  final String calleeId;
  final String status;
  final String? callerName;
  final String? calleeName;
  final String? callerLabel;
  final String? calleeLabel;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  Duration? get duration =>
      (answeredAt != null && endedAt != null)
          ? endedAt!.difference(answeredAt!)
          : null;
}

class IceConfig {
  const IceConfig({required this.iceServers, required this.ringSeconds});

  factory IceConfig.fromJson(Map<String, dynamic> json) => IceConfig(
    iceServers: asMapList(json['iceServers']),
    ringSeconds: asInt(json['ringSeconds'], fallback: 45),
  );

  final List<Map<String, dynamic>> iceServers;
  final int ringSeconds;
}
