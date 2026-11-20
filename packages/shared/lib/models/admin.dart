import 'json.dart';

/// Admin, guard and platform models.
///
/// Same rules as the resident models: nested wins, flat is the fallback, and a
/// missing optional field degrades rather than throwing.

// ------------------------------------------------------------- approvals

/// One item in the admin moderation queue.
///
/// The approval request is a wrapper around an entity: `entityType` says what
/// is being moderated and `entityId` points at it. The admin actions on this
/// queue take the approval-request id, never the entity id.
class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.status,
    required this.rawStatus,
    required this.entityType,
    required this.entityId,
    this.title,
    this.submittedBy,
    this.submittedAt,
    this.decidedAt,
    this.decidedBy,
    this.reason,
    this.history = const [],
    this.autoPublish = false,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    final submittedBy = asMapOrNull(json['submittedBy']);
    final decidedBy = asMapOrNull(json['decidedBy']);
    return ApprovalRequest(
      id: asString(json['id']),
      status: humanize(asString(json['status'], fallback: 'SUBMITTED')),
      rawStatus: asString(json['status'], fallback: 'SUBMITTED').toUpperCase(),
      entityType: humanize(
        asString(json['entityType'], fallback: 'COMMUNITY_POST'),
      ),
      entityId: asString(json['entityId'] ?? json['entity'], fallback: ''),
      title: asStringOrNull(
        json['title'] ?? json['summary'] ?? json['entityTitle'],
      ),
      submittedBy: asStringOrNull(
        submittedBy?['name'] ?? json['submittedByName'],
      ),
      submittedAt: asDateOrNull(json['submittedAt'] ?? json['createdAt']),
      decidedAt: asDateOrNull(json['decidedAt']),
      decidedBy: asStringOrNull(decidedBy?['name'] ?? json['decidedByName']),
      reason: asStringOrNull(json['reason'] ?? json['decisionReason']),
      history: asMapList(json['history']),
      autoPublish: asBool(json['autoPublish']),
    );
  }

  final String id;
  final String status;

  /// The backend status exactly as sent (`UNDER_REVIEW`). [status] is the
  /// display label; compare against this one in code.
  final String rawStatus;
  final String entityType;
  final String entityId;
  final String? title;
  final String? submittedBy;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? reason;
  final List<Map<String, dynamic>> history;
  final bool autoPublish;

  bool get isPending =>
      rawStatus == 'SUBMITTED' || rawStatus == 'UNDER_REVIEW';

  String get entityLabel => switch (entityType.toUpperCase().replaceAll(' ', '_')) {
    'MARKETPLACE_LISTING' => 'Marketplace listing',
    'PROPERTY_LISTING' => 'Property listing',
    'COMMUNITY_POST' => 'Community post',
    'MOVE_REQUEST' => 'Move request',
    _ => entityType,
  };
}

// ------------------------------------------------------------ admin: staff

/// A staff member employed by the society.
class Staff {
  const Staff({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.phone,
    this.shift,
    this.vendorName,
    this.assignedTower,
    this.joinedAt,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    final vendor = asMapOrNull(json['vendor']);
    return Staff(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'Staff'),
      type: humanize(
        asString(json['type'] ?? json['staffType'], fallback: 'OTHER'),
      ),
      status: humanize(asString(json['status'], fallback: 'ACTIVE')),
      phone: asStringOrNull(json['phone'] ?? json['mobile']),
      shift: asStringOrNull(json['shift']) == null
          ? null
          : humanize(asString(json['shift'])),
      vendorName: asStringOrNull(vendor?['name'] ?? json['vendorName']),
      assignedTower: asStringOrNull(json['towerName'] ?? json['assignedTower']),
      joinedAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String name;
  final String type;
  final String status;
  final String? phone;
  final String? shift;
  final String? vendorName;
  final String? assignedTower;
  final DateTime? joinedAt;
}

/// A vendor or agency supplying staff or services.
class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    this.contactName,
    this.phone,
    this.email,
    this.contractUntil,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
    id: asString(json['id']),
    name: asString(json['name'] ?? json['vendorName'], fallback: 'Vendor'),
    category: humanize(
      asString(json['category'] ?? json['type'], fallback: 'OTHER'),
    ),
    status: humanize(asString(json['status'], fallback: 'ACTIVE')),
    contactName: asStringOrNull(json['contactName'] ?? json['contactPerson']),
    phone: asStringOrNull(json['phone'] ?? json['mobile']),
    email: asStringOrNull(json['email']),
    contractUntil: asDateOrNull(json['contractUntil'] ?? json['contractEnd']),
  );

  final String id;
  final String name;
  final String category;
  final String status;
  final String? contactName;
  final String? phone;
  final String? email;
  final DateTime? contractUntil;
}

/// A task assigned to staff.
class StaffTask {
  const StaffTask({
    required this.id,
    required this.title,
    required this.status,
    this.assignee,
    this.dueDate,
    this.priority,
    this.createdAt,
  });

  factory StaffTask.fromJson(Map<String, dynamic> json) {
    final assignee = asMapOrNull(json['assignee']);
    return StaffTask(
      id: asString(json['id']),
      title: asString(json['title'], fallback: 'Task'),
      status: humanize(asString(json['status'], fallback: 'TODO')),
      assignee: asStringOrNull(assignee?['name'] ?? json['assigneeName']),
      dueDate: asDateOrNull(json['dueDate']),
      priority: asStringOrNull(json['priority']) == null
          ? null
          : humanize(asString(json['priority'])),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String title;
  final String status;
  final String? assignee;
  final DateTime? dueDate;
  final String? priority;
  final DateTime? createdAt;
}

/// A society asset (equipment, furniture, appliances).
class Asset {
  const Asset({
    required this.id,
    required this.name,
    required this.status,
    this.category,
    this.quantity = 1,
    this.location,
    this.purchaseDate,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Asset'),
    status: humanize(asString(json['status'], fallback: 'IN_USE')),
    category: asStringOrNull(json['category']) == null
        ? null
        : humanize(asString(json['category'])),
    quantity: asInt(json['quantity'], fallback: 1),
    location: asStringOrNull(json['location']),
    purchaseDate: asDateOrNull(json['purchaseDate']),
  );

  final String id;
  final String name;
  final String status;
  final String? category;
  final int quantity;
  final String? location;
  final DateTime? purchaseDate;
}

// --------------------------------------------------------- admin: vehicles

/// A vehicle registered in the society (admin view).
class SocietyVehicle {
  const SocietyVehicle({
    required this.id,
    required this.plate,
    required this.type,
    this.ownerName,
    this.flatLabel,
    this.status,
    this.slotLabel,
  });

  factory SocietyVehicle.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return SocietyVehicle(
      id: asString(json['id']),
      plate: asString(json['plateNumber'] ?? json['plate'], fallback: '—'),
      type: humanize(
        asString(json['type'] ?? json['vehicleType'], fallback: 'CAR'),
      ),
      ownerName: asStringOrNull(json['ownerName']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      status: asStringOrNull(json['status']) == null
          ? null
          : humanize(asString(json['status'])),
      slotLabel: asStringOrNull(json['slotLabel'] ?? json['parkingSlot']),
    );
  }

  final String id;
  final String plate;
  final String type;
  final String? ownerName;
  final String? flatLabel;
  final String? status;
  final String? slotLabel;
}

/// A guard on duty.
class Guard {
  const Guard({
    required this.id,
    required this.name,
    required this.status,
    this.phone,
    this.gate,
    this.shift,
    this.shiftEndsAt,
    this.onDuty = false,
  });

  factory Guard.fromJson(Map<String, dynamic> json) {
    // The backend nests the person under `user` and sends the gate as an id.
    final user = asMapOrNull(json['user']);
    return Guard(
      id: asString(json['id'] ?? json['userId']),
      name: asString(user?['name'] ?? json['name'], fallback: 'Guard'),
      status: humanize(asString(json['status'], fallback: 'ACTIVE')),
      phone: asStringOrNull(user?['mobile'] ?? json['phone'] ?? json['mobile']),
      gate: asStringOrNull(json['gateName'] ?? json['assignedGate']),
      shift: asStringOrNull(json['shift']) == null
          ? null
          : humanize(asString(json['shift'])),
      shiftEndsAt: asDateOrNull(json['shiftEndsAt']),
      onDuty: asBool(json['onDuty']),
    );
  }

  final String id;
  final String name;
  final String status;
  final String? phone;
  final String? gate;
  final String? shift;
  final DateTime? shiftEndsAt;
  final bool onDuty;
}

/// A gate in the society.
class Gate {
  const Gate({required this.id, required this.name, this.assignedGuards = 0});

  factory Gate.fromJson(Map<String, dynamic> json) => Gate(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Gate'),
    assignedGuards: asInt(json['guardCount'] ?? json['guards']),
  );

  final String id;
  final String name;
  final int assignedGuards;
}

// ------------------------------------------------------------- admin: money

/// A charge definition used when generating invoices.
class Charge {
  const Charge({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.frequency,
    this.calculation = 'FIXED',
    this.active = true,
  });

  factory Charge.fromJson(Map<String, dynamic> json) => Charge(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Charge'),
    type: humanize(
      asString(json['chargeType'] ?? json['type'], fallback: 'MAINTENANCE'),
    ),
    amount: asDouble(json['amount'] ?? json['rate']),
    frequency: humanize(asString(json['frequency'], fallback: 'MONTHLY')),
    calculation: humanize(asString(json['calcMethod'], fallback: 'FIXED')),
    active: asBool(json['isActive'] ?? json['active'], fallback: true),
  );

  final String id;
  final String name;
  final String type;
  final double amount;
  final String frequency;
  final String calculation;
  final bool active;
}

/// An expense recorded by the admin.
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.spentAt,
    this.vendor,
    this.note,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final vendor = asMapOrNull(json['vendor']);
    return Expense(
      id: asString(json['id']),
      title: asString(
        json['title'] ?? json['description'],
        fallback: 'Expense',
      ),
      category: humanize(asString(json['category'], fallback: 'OTHER')),
      amount: asDouble(json['amount']),
      spentAt: asDateOrNull(
        json['spentAt'] ?? json['date'] ?? json['createdAt'],
      ),
      vendor: asStringOrNull(vendor?['name'] ?? json['vendorName']),
      note: asStringOrNull(json['note']),
    );
  }

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime? spentAt;
  final String? vendor;
  final String? note;
}

/// The finance summary shown at the top of the admin finance screen.
class FinanceSummary {
  const FinanceSummary({
    this.collected = 0,
    this.outstanding = 0,
    this.expenses = 0,
    this.overdue = 0,
    this.collectionRate = 0,
    this.monthlyTrend = const [],
    this.overdueInvoiceCount = 0,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    final overdueAmount = asDouble(json['overdue'] ?? json['totalOverdue']);
    return FinanceSummary(
      collected: asDouble(json['collected'] ?? json['totalCollected']),
      outstanding: asDouble(json['outstanding'] ?? json['totalOutstanding']),
      // The backend reports overdue as a *count of invoices* under
      // `overdueInvoices`; the amount-shaped key is kept for other callers.
      overdue: overdueAmount,
      overdueInvoiceCount: asInt(json['overdueInvoices']),
      expenses: asDouble(json['expenses'] ?? json['totalExpenses']),
      collectionRate: asDouble(
        json['collectionEfficiency'] ?? json['collectionRate'] ?? json['rate'],
      ),
      monthlyTrend: asMapList(
        json['monthly'] ?? json['monthlyTrend'] ?? json['trend'],
      ),
    );
  }

  final double collected;
  final double outstanding;
  final double expenses;
  final double overdue;
  final double collectionRate;
  final List<Map<String, dynamic>> monthlyTrend;
  final int overdueInvoiceCount;

  double get net => collected - expenses;
  static const empty = FinanceSummary();
}

/// A payment record as the admin sees it.
class AdminPayment {
  const AdminPayment({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    this.payerName,
    this.flatLabel,
    this.invoiceNumber,
    this.paidAt,
  });

  factory AdminPayment.fromJson(Map<String, dynamic> json) {
    final payer = asMapOrNull(json['user']);
    final flat = asMapOrNull(json['flat']);
    return AdminPayment(
      id: asString(json['id']),
      amount: asDouble(json['amount']),
      method: humanize(asString(json['method'], fallback: 'ONLINE')),
      status: humanize(asString(json['status'], fallback: 'INITIATED')),
      payerName: asStringOrNull(payer?['name'] ?? json['payerName']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      invoiceNumber: asStringOrNull(json['invoiceNumber']),
      paidAt: asDateOrNull(json['paidAt'] ?? json['createdAt']),
    );
  }

  final String id;
  final double amount;
  final String method;
  final String status;
  final String? payerName;
  final String? flatLabel;
  final String? invoiceNumber;
  final DateTime? paidAt;
}

// -------------------------------------------------------------- admin: misc

/// A role with its permission set.
class Role {
  const Role({
    required this.id,
    required this.name,
    this.description,
    this.permissions = const [],
    this.isSystem = false,
    this.memberCount = 0,
  });

  factory Role.fromJson(Map<String, dynamic> json) => Role(
    id: asString(json['id']),
    name: humanize(asString(json['name'], fallback: 'Role')),
    description: asStringOrNull(json['description']),
    permissions: asList(
      json['permissions'],
    ).map((p) => p.toString()).toList(growable: false),
    isSystem: asBool(json['isSystem']),
    memberCount: asInt(json['memberCount'] ?? json['users']),
  );

  final String id;
  final String name;
  final String? description;
  final List<String> permissions;
  final bool isSystem;
  final int memberCount;
}

/// An administrator account inside a society.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.mobile,
    required this.status,
    this.email,
    this.roleName,
    this.lastLoginAt,
    this.societyId,
    this.societyName,
    this.societyCode,
    this.designation,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final user = asMapOrNull(json['user']);
    final society = asMapOrNull(json['society']);
    return AdminUser(
      societyId: asStringOrNull(society?['id'] ?? json['societyId']),
      societyName: asStringOrNull(society?['name']),
      societyCode: asStringOrNull(society?['code']),
      designation: asStringOrNull(json['designation']),
      id: asString(json['id'] ?? json['userId']),
      name: asString(at(user, 'name') ?? json['name'], fallback: 'Admin'),
      mobile: asString(at(user, 'mobile') ?? json['mobile']),
      email: asStringOrNull(at(user, 'email') ?? json['email']),
      status: humanize(asString(json['status'], fallback: 'ACTIVE')),
      roleName: _roleName(json),
      lastLoginAt: asDateOrNull(at(user, 'lastLoginAt') ?? json['lastLoginAt']),
    );
  }

  final String? societyId;
  final String? societyName;
  final String? societyCode;
  final String? designation;
  final String id;
  final String name;
  final String mobile;
  final String? email;
  final String status;
  final String? roleName;
  final DateTime? lastLoginAt;
}

/// A society announcement or notice as the admin sees it.
class AdminNotice {
  const AdminNotice({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    this.audience,
    this.publishedAt,
    this.authorName,
    this.createdAt,
  });

  factory AdminNotice.fromJson(Map<String, dynamic> json) => AdminNotice(
    id: asString(json['id']),
    title: asString(json['title'], fallback: 'Notice'),
    type: humanize(asString(json['type'], fallback: 'ANNOUNCEMENT')),
    status: humanize(asString(json['status'], fallback: 'DRAFT')),
    audience: asStringOrNull(json['audience']) == null
        ? null
        : humanize(asString(json['audience'])),
    publishedAt: asDateOrNull(json['publishedAt']),
    authorName: asStringOrNull(json['authorName']),
    createdAt: asDateOrNull(json['createdAt']),
  );

  final String id;
  final String title;
  final String type;
  final String status;
  final String? audience;
  final DateTime? publishedAt;
  final String? authorName;
  final DateTime? createdAt;
}

/// A support ticket (society support or platform support).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.category,
    required this.priority,
    this.description,
    this.raisedBy,
    this.createdAt,
    this.updatedAt,
    this.resolution,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: asString(json['id']),
    subject: asString(json['subject'] ?? json['title'], fallback: 'Ticket'),
    status: humanize(asString(json['status'], fallback: 'OPEN')),
    category: humanize(asString(json['category'], fallback: 'OTHER')),
    priority: humanize(asString(json['priority'], fallback: 'MEDIUM')),
    description: asStringOrNull(json['description']),
    raisedBy: asStringOrNull(json['raisedByName'] ?? json['raisedBy']),
    createdAt: asDateOrNull(json['createdAt']),
    updatedAt: asDateOrNull(json['updatedAt']),
    resolution: asStringOrNull(json['resolution']),
  );

  final String id;
  final String subject;
  final String status;
  final String category;
  final String priority;
  final String? description;
  final String? raisedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? resolution;
}

/// An audit log entry.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.action,
    this.actorName,
    this.target,
    this.detail,
    this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final actor = asMapOrNull(json['actor']);
    return AuditLog(
      id: asString(json['id']),
      action: humanize(asString(json['action'], fallback: 'ACTION')),
      actorName: asStringOrNull(actor?['name'] ?? json['actorName']),
      target: asStringOrNull(json['target'] ?? json['targetId']),
      detail: asStringOrNull(json['detail'] ?? json['metadata']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String action;
  final String? actorName;
  final String? target;
  final String? detail;
  final DateTime? createdAt;
}

/// A platform-level report row (used by the reports screens).
class ReportSummary {
  const ReportSummary({
    required this.title,
    required this.value,
    this.hint,
    this.trend,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
    title: humanize(asString(json['title'] ?? json['label'])),
    value: asString(json['value']),
    hint: asStringOrNull(json['hint'] ?? json['subtitle']),
    trend: asDoubleOrNull(json['trend']),
  );

  final String title;
  final String value;
  final String? hint;
  final double? trend;
}

// ------------------------------------------------------- guard: dashboard

/// The guard's daily briefing: how much is waiting at the gate right now.
/// Matches `GET /guard/dashboard` exactly.
class GuardDashboard {
  const GuardDashboard({
    this.todayVisitors = 0,
    this.todayDeliveries = 0,
    this.domesticHelpPresent = 0,
    this.expectedVisitors = 0,
    this.pendingVisitors = 0,
    this.pendingDeliveries = 0,
    this.activeVisitors = 0,
    this.activeAlerts = 0,
    this.recentActivity = const [],
  });

  factory GuardDashboard.fromJson(Map<String, dynamic> json) {
    final today = asMapOrNull(json['today']) ?? const {};
    final pending = asMapOrNull(json['pendingApprovals']) ?? const {};
    return GuardDashboard(
      todayVisitors: asInt(today['visitors']),
      todayDeliveries: asInt(today['deliveries']),
      domesticHelpPresent: asInt(today['domesticHelpPresent']),
      expectedVisitors: asInt(json['expectedVisitors']),
      pendingVisitors: asInt(pending['visitors'] ?? json['pendingVisitors']),
      pendingDeliveries: asInt(
        pending['deliveries'] ?? json['pendingDeliveries'],
      ),
      activeVisitors: asInt(json['activeVisitors']),
      activeAlerts: asInt(
        json['activeEmergencyAlerts'] ?? json['activeAlerts'],
      ),
      recentActivity: asMapList(json['recentActivity']),
    );
  }

  /// What happened at the gate today, including completed visits.
  final int todayVisitors;
  final int todayDeliveries;
  final int domesticHelpPresent;

  final int expectedVisitors;
  final int pendingVisitors;
  final int pendingDeliveries;
  final int activeVisitors;
  final int activeAlerts;

  /// Recent gate movement, newest first: `{flatLabel, name, status, id, …}`.
  final List<Map<String, dynamic>> recentActivity;

  bool get hasWork =>
      pendingVisitors > 0 || pendingDeliveries > 0 || activeAlerts > 0;

  static const empty = GuardDashboard();
}

/// An emergency alert broadcast to guards and admins.
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.type,
    required this.status,
    this.flatLabel,
    this.raisedBy,
    this.location,
    this.message,
    this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return EmergencyAlert(
      id: asString(json['id']),
      type: humanize(asString(json['type'], fallback: 'PANIC')),
      status: humanize(asString(json['status'], fallback: 'ACTIVE')),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      raisedBy: asStringOrNull(json['raisedByName'] ?? json['raisedBy']),
      location: asStringOrNull(json['location']),
      message: asStringOrNull(json['message'] ?? json['description']),
      createdAt: asDateOrNull(json['createdAt']),
      acknowledgedAt: asDateOrNull(json['acknowledgedAt']),
      resolvedAt: asDateOrNull(json['resolvedAt']),
    );
  }

  final String id;
  final String type;
  final String status;
  final String? flatLabel;
  final String? raisedBy;
  final String? location;
  final String? message;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

/// A domestic worker expected on today's roster.
class ExpectedHelper {
  const ExpectedHelper({
    required this.id,
    required this.name,
    required this.type,
    this.phone,
    this.flatLabel,
    this.expectedAt,
    this.checkedIn = false,
  });

  factory ExpectedHelper.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return ExpectedHelper(
      id: asString(json['id'] ?? json['assignmentId']),
      name: asString(json['name'], fallback: 'Helper'),
      type: humanize(asString(json['type'], fallback: 'MAID')),
      phone: asStringOrNull(json['phone'] ?? json['mobile']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      expectedAt: asDateOrNull(json['expectedAt'] ?? json['date']),
      checkedIn: asBool(json['checkedIn']),
    );
  }

  final String id;
  final String name;
  final String type;
  final String? phone;
  final String? flatLabel;
  final DateTime? expectedAt;
  final bool checkedIn;
}

// ------------------------------------------------------ super admin: platform

/// A society as the platform operator sees it.
class PlatformSociety {
  const PlatformSociety({
    required this.id,
    required this.name,
    required this.status,
    this.rawStatus = 'PENDING',
    this.code,
    this.city,
    this.state,
    this.plan,
    this.residentCount = 0,
    this.adminName,
    this.adminMobile,
    this.createdAt,
    this.features = const {},
    this.propertyType,
    this.totalUnits,
  });

  factory PlatformSociety.fromJson(Map<String, dynamic> json) {
    // The list/detail record carries no admin; a pending registration has its
    // applicant. The real administrators come from the administration endpoint.
    final primaryAdmin =
        asMapOrNull(json['primaryAdmin']) ?? asMapOrNull(json['applicant']);
    final plan = asMapOrNull(json['plan']);
    return PlatformSociety(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'Society'),
      status: humanize(asString(json['status'], fallback: 'PENDING')),
      rawStatus: asString(json['status'], fallback: 'PENDING').toUpperCase(),
      code: asStringOrNull(json['code']),
      city: asStringOrNull(_addr(json)['city'] ?? json['city']),
      state: asStringOrNull(_addr(json)['state'] ?? json['state']),
      plan: asStringOrNull(at(plan, 'name') ?? json['planName']),
      residentCount: asInt(json['residentCount'] ?? json['residents']),
      adminName: asStringOrNull(at(primaryAdmin, 'name') ?? json['adminName']),
      adminMobile: asStringOrNull(
        at(primaryAdmin, 'mobile') ?? json['adminMobile'],
      ),
      createdAt: asDateOrNull(json['createdAt']),
      features: asMap(json['features']).map((k, v) => MapEntry(k, v == true)),
      propertyType: asStringOrNull(json['propertyType']),
      totalUnits: asIntOrNull(json['totalUnits']),
    );
  }

  final String id;
  final String name;
  final String status;
  final String? propertyType;
  final int? totalUnits;

  /// Backend status (`PENDING`, `ACTIVE`, `INACTIVE`, `REJECTED`, ...). Use
  /// this for logic; [status] is the display label.
  final String rawStatus;
  final String? code;
  final String? city;
  final String? state;
  final String? plan;
  final int residentCount;
  final String? adminName;
  final String? adminMobile;
  final DateTime? createdAt;
  final Map<String, bool> features;
}

/// A subscription plan.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.interval,
    this.description,
    this.limits = const {},
    this.isActive = true,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Plan'),
    price: asDouble(json['price']),
    interval: humanize(
      asString(json['billingCycle'] ?? json['interval'], fallback: 'MONTHLY'),
    ),
    description: asStringOrNull(json['description']),
    limits: asMap(json['limits']),
    isActive: asBool(json['active'] ?? json['isActive'], fallback: true),
  );

  final String id;
  final String name;
  final double price;
  final String interval;
  final String? description;
  final Map<String, dynamic> limits;
  final bool isActive;
}

/// The platform health snapshot (`/super-admin/monitoring/health`),
/// matching the backend exactly.
class PlatformHealth {
  const PlatformHealth({
    this.status = 'UNKNOWN',
    this.uptimeSeconds = 0,
    this.databaseState = 'unknown',
    this.transactions = false,
    this.memoryMb = 0,
    this.realtimeConnections = 0,
    this.version = '',
    this.schedulerLastRunAt,
  });

  factory PlatformHealth.fromJson(Map<String, dynamic> json) {
    final database = asMapOrNull(json['database']) ?? const {};
    final scheduler = asMapOrNull(json['scheduler']) ?? const {};
    return PlatformHealth(
      status: humanize(asString(json['status'], fallback: 'UNKNOWN')),
      uptimeSeconds: asInt(json['uptimeSeconds']),
      databaseState: asString(database['state'], fallback: 'unknown'),
      transactions: asBool(database['transactions']),
      memoryMb: asInt(json['memoryMb']),
      realtimeConnections: asInt(json['realtimeConnections']),
      version: asStringOrNull(json['version']) ?? '',
      schedulerLastRunAt: asDateOrNull(scheduler['lastRunAt']),
    );
  }

  final String status;
  final int uptimeSeconds;
  final String databaseState;
  final bool transactions;
  final int memoryMb;
  final int realtimeConnections;
  final String version;
  final DateTime? schedulerLastRunAt;

  bool get isOk => status.toLowerCase() == 'ok';

  String get uptimeLabel {
    if (uptimeSeconds <= 0) return '—';
    final d = Duration(seconds: uptimeSeconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

/// A security event from the platform security screen.
class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.type,
    required this.severity,
    this.description,
    this.actor,
    this.ipAddress,
    this.createdAt,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    final actor = asMapOrNull(json['actor']);
    return SecurityEvent(
      id: asString(json['id']),
      type: humanize(
        asString(json['type'] ?? json['action'], fallback: 'EVENT'),
      ),
      severity: humanize(asString(json['severity'], fallback: 'INFO')),
      description: asStringOrNull(json['description'] ?? json['detail']),
      actor: asStringOrNull(at(actor, 'name') ?? json['actorName']),
      ipAddress: asStringOrNull(json['ipAddress'] ?? json['ip']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String type;
  final String severity;
  final String? description;
  final String? actor;
  final String? ipAddress;
  final DateTime? createdAt;
}

/// A login history entry.
class LoginRecord {
  const LoginRecord({
    required this.id,
    this.userName,
    this.success = true,
    this.ipAddress,
    this.device,
    this.loggedAt,
  });

  factory LoginRecord.fromJson(Map<String, dynamic> json) {
    final user = asMapOrNull(json['user']);
    return LoginRecord(
      id: asString(json['id']),
      userName: asStringOrNull(at(user, 'name') ?? json['userName']),
      success: asBool(json['success'] ?? json['succeeded'], fallback: true),
      ipAddress: asStringOrNull(json['ipAddress'] ?? json['ip']),
      device: asStringOrNull(json['device'] ?? json['userAgent']),
      loggedAt: asDateOrNull(json['createdAt'] ?? json['loggedAt']),
    );
  }

  final String id;
  final String? userName;
  final bool success;
  final String? ipAddress;
  final String? device;
  final DateTime? loggedAt;
}

/// A notification template (platform or society).
class NotificationTemplate {
  const NotificationTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.subject,
    this.body,
    this.channel,
  });

  factory NotificationTemplate.fromJson(Map<String, dynamic> json) =>
      NotificationTemplate(
        id: asString(json['id']),
        name: asString(json['name'], fallback: 'Template'),
        type: humanize(
          asString(json['type'] ?? json['event'], fallback: 'SYSTEM'),
        ),
        subject: asStringOrNull(json['subject'] ?? json['title']),
        body: asStringOrNull(json['body']),
        channel: asStringOrNull(json['channel']) == null
            ? null
            : humanize(asString(json['channel'])),
      );

  final String id;
  final String name;
  final String type;
  final String? subject;
  final String? body;
  final String? channel;
}

/// Reads `address` as a map (it may be absent or a string).
Map<String, dynamic> _addr(Map<String, dynamic> json) =>
    asMapOrNull(json['address']) ?? const {};

/// Reads the role name from either a nested role object or a flat field.
String? _roleName(Map<String, dynamic> json) {
  return asStringOrNull(at(json['role'], 'name') ?? json['roleName']);
}
