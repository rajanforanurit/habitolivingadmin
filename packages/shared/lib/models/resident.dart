import '../services/format.dart';
import 'json.dart';

/// Resident-facing domain models.
///
/// Every type here mirrors a real backend payload. Where the backend nests an
/// entity (`{ userId, user: {...} }`), the nested form wins and the flat form is
/// a fallback, because that is how the API actually shapes data.

// ------------------------------------------------------------------ notices

enum NoticeKind { announcement, emergency, circular, event }

/// Human label for a notice kind.
extension NoticeKindLabel on NoticeKind {
  String get label => switch (this) {
    NoticeKind.announcement => 'Notice',
    NoticeKind.emergency => 'Emergency',
    NoticeKind.circular => 'Circular',
    NoticeKind.event => 'Event',
  };
}

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.status,
    this.summary,
    this.publishedAt,
    this.createdAt,
    this.author,
    this.isRead = false,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
    id: asString(json['id']),
    title: asString(json['title'], fallback: 'Notice'),
    body: asString(json['body']),
    summary: asStringOrNull(json['summary'] ?? json['excerpt']),
    kind: _noticeKind(asString(json['type'])),
    status: humanize(asString(json['status'], fallback: 'PUBLISHED')),
    publishedAt: asDateOrNull(json['publishedAt'] ?? json['createdAt']),
    createdAt: asDateOrNull(json['createdAt']),
    author: asStringOrNull(json['authorName'] ?? json['createdByName']),
    isRead: asBool(json['isRead'] ?? (json['readAt'] != null)),
  );

  final String id;
  final String title;
  final String body;
  final String? summary;
  final NoticeKind kind;
  final String status;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final String? author;
  final bool isRead;

  String get kindLabel => switch (kind) {
    NoticeKind.announcement => 'Announcement',
    NoticeKind.emergency => 'Emergency',
    NoticeKind.circular => 'Circular',
    NoticeKind.event => 'Event',
  };

  static NoticeKind _noticeKind(String raw) => switch (raw.toUpperCase()) {
    'EMERGENCY' => NoticeKind.emergency,
    'CIRCULAR' => NoticeKind.circular,
    'EVENT' => NoticeKind.event,
    _ => NoticeKind.announcement,
  };

  /// True when the body is longer than the card shows.
  bool get isLong => body.length > 180;

  /// First line of the body, for cards.
  String get preview {
    final source = (summary != null && summary!.trim().isNotEmpty)
        ? summary!
        : body;
    final firstLine = source.trim().split('\n').first;
    return firstLine.length <= 140
        ? firstLine
        : '${firstLine.substring(0, 140)}…';
  }
}

// --------------------------------------------------------------- invoices

enum InvoiceStatusValue { unpaid, partiallyPaid, paid, overdue, cancelled }

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.amount,
    required this.status,
    required this.chargeType,
    this.period,
    this.dueDate,
    this.paidAmount = 0,
    this.flatLabel,
    this.lineItems = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return Invoice(
      id: asString(json['id']),
      number: asString(
        json['invoiceNumber'] ?? json['number'] ?? json['invoiceNo'],
        fallback: 'Invoice',
      ),
      amount: asDouble(json['amount'] ?? json['total'] ?? json['amountDue']),
      status: _invoiceStatus(asString(json['status'])),
      chargeType: humanize(
        asString(json['chargeType'] ?? json['type'], fallback: 'MAINTENANCE'),
      ),
      period: asStringOrNull(json['period'] ?? json['month']),
      dueDate: asDateOrNull(json['dueDate']),
      paidAmount: asDouble(json['paidAmount'] ?? json['amountPaid']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      lineItems: asMapList(json['lineItems'] ?? json['items']),
    );
  }

  final String id;
  final String number;
  final double amount;
  final InvoiceStatusValue status;
  final String chargeType;
  final String? period;
  final DateTime? dueDate;
  final double paidAmount;
  final String? flatLabel;
  final List<Map<String, dynamic>> lineItems;

  double get balance => (amount - paidAmount).clamp(0, double.infinity);

  bool get isPaid => status == InvoiceStatusValue.paid;

  String get statusLabel => switch (status) {
    InvoiceStatusValue.unpaid => 'Unpaid',
    InvoiceStatusValue.partiallyPaid => 'Partly paid',
    InvoiceStatusValue.paid => 'Paid',
    InvoiceStatusValue.overdue => 'Overdue',
    InvoiceStatusValue.cancelled => 'Cancelled',
  };

  static InvoiceStatusValue _invoiceStatus(String raw) =>
      switch (raw.toUpperCase()) {
        'PAID' => InvoiceStatusValue.paid,
        'PARTIALLY_PAID' => InvoiceStatusValue.partiallyPaid,
        'OVERDUE' => InvoiceStatusValue.overdue,
        'CANCELLED' => InvoiceStatusValue.cancelled,
        _ => InvoiceStatusValue.unpaid,
      };
}

class InvoiceSummary {
  const InvoiceSummary({
    this.outstanding = 0,
    this.overdue = 0,
    this.paidThisYear = 0,
    this.invoiceCount = 0,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) => InvoiceSummary(
    outstanding: asDouble(json['outstanding'] ?? json['totalOutstanding']),
    overdue: asDouble(json['overdue'] ?? json['totalOverdue']),
    paidThisYear: asDouble(json['paidThisYear'] ?? json['yearPaid']),
    invoiceCount: asInt(json['count'] ?? json['total']),
  );

  final double outstanding;
  final double overdue;
  final double paidThisYear;
  final int invoiceCount;

  static const empty = InvoiceSummary();
  bool get hasDues => outstanding > 0;
}

class PaymentReceipt {
  const PaymentReceipt({
    required this.id,
    required this.reference,
    required this.amount,
    required this.method,
    required this.status,
    this.paidAt,
    this.invoiceId,
    this.note,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) => PaymentReceipt(
    id: asString(json['id']),
    reference: asString(
      json['transactionRef'] ?? json['reference'] ?? json['gatewayPaymentId'],
      fallback: 'Payment',
    ),
    amount: asDouble(json['amount']),
    method: humanize(asString(json['method'], fallback: 'ONLINE')),
    status: humanize(asString(json['status'], fallback: 'INITIATED')),
    paidAt: asDateOrNull(json['paidAt'] ?? json['createdAt']),
    invoiceId: asStringOrNull(json['invoiceId']),
    note: asStringOrNull(json['note']),
  );

  final String id;
  final String reference;
  final double amount;
  final String method;
  final String status;
  final DateTime? paidAt;
  final String? invoiceId;
  final String? note;
}

/// The result of starting a payment. The backend uses a mock gateway in
/// development and returns the fields needed to settle it.
class PaymentStart {
  const PaymentStart({
    required this.paymentId,
    this.orderId,
    this.checkout,
    this.devHint,
  });

  factory PaymentStart.fromJson(Map<String, dynamic> json) {
    final checkout = asMapOrNull(json['checkout']);
    return PaymentStart(
      paymentId: asString(json['id'] ?? json['paymentId']),
      orderId: asStringOrNull(json['orderId'] ?? checkout?['orderId']),
      checkout: checkout,
      devHint: asMapOrNull(checkout?['devHint']),
    );
  }

  final String paymentId;
  final String? orderId;
  final Map<String, dynamic>? checkout;
  final Map<String, dynamic>? devHint;

  /// In development the mock gateway hands back a payment id and signature that
  /// settle the payment. Present only when the backend is in dev mode.
  String? get devPaymentId => asStringOrNull(devHint?['paymentId']);
  String? get devSignature => asStringOrNull(devHint?['signature']);
  bool get hasDevHint => devHint != null;
}

// --------------------------------------------------------------- visitors

enum VisitorStatusValue {
  expected,
  pendingApproval,
  approved,
  checkedIn,
  checkedOut,
  rejected,
  denied,
  cancelled,
  expired,
}

/// Human labels for the visitor lifecycle, shared by every visitor card.
extension VisitorStatusLabel on VisitorStatusValue {
  String get label => switch (this) {
    VisitorStatusValue.expected => 'Expected',
    VisitorStatusValue.pendingApproval => 'Awaiting approval',
    VisitorStatusValue.approved => 'Approved',
    VisitorStatusValue.checkedIn => 'Checked in',
    VisitorStatusValue.checkedOut => 'Checked out',
    VisitorStatusValue.rejected => 'Rejected',
    VisitorStatusValue.denied => 'Denied',
    VisitorStatusValue.cancelled => 'Cancelled',
    VisitorStatusValue.expired => 'Expired',
  };

  /// Whether the status reads as a positive outcome.
  bool get isPositive =>
      this == VisitorStatusValue.approved ||
      this == VisitorStatusValue.checkedIn;
}

class Visitor {
  const Visitor({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.phone,
    this.purpose,
    this.flatLabel,
    this.scheduledAt,
    this.checkedInAt,
    this.checkedOutAt,
    this.passCode,
    this.vehicleNumber,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return Visitor(
      id: asString(json['id']),
      name: asString(json['name'] ?? json['visitorName'], fallback: 'Visitor'),
      type: humanize(
        asString(json['type'] ?? json['visitorType'], fallback: 'GUEST'),
      ),
      status: _visitorStatus(asString(json['status'])),
      phone: asStringOrNull(json['phone'] ?? json['mobile']),
      purpose: asStringOrNull(json['purpose']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      scheduledAt: asDateOrNull(
        json['scheduledAt'] ?? json['validFrom'] ?? json['createdAt'],
      ),
      checkedInAt: asDateOrNull(json['checkedInAt']),
      checkedOutAt: asDateOrNull(json['checkedOutAt']),
      passCode: asStringOrNull(json['passCode'] ?? json['code']),
      vehicleNumber: asStringOrNull(json['vehicleNumber']),
    );
  }

  final String id;
  final String name;
  final String type;
  final VisitorStatusValue status;
  final String? phone;
  final String? purpose;
  final String? flatLabel;
  final DateTime? scheduledAt;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String? passCode;
  final String? vehicleNumber;

  bool get isWaiting => status == VisitorStatusValue.pendingApproval;
  bool get isOnPremises => status == VisitorStatusValue.checkedIn;

  static VisitorStatusValue _visitorStatus(String raw) =>
      switch (raw.toUpperCase()) {
        'EXPECTED' => VisitorStatusValue.expected,
        'PENDING_APPROVAL' => VisitorStatusValue.pendingApproval,
        'APPROVED' => VisitorStatusValue.approved,
        'CHECKED_IN' => VisitorStatusValue.checkedIn,
        'CHECKED_OUT' => VisitorStatusValue.checkedOut,
        'REJECTED' => VisitorStatusValue.rejected,
        'DENIED' => VisitorStatusValue.denied,
        'CANCELLED' => VisitorStatusValue.cancelled,
        _ => VisitorStatusValue.expired,
      };
}

/// An invitation the resident created for a guest.
class VisitorInvitation {
  const VisitorInvitation({
    required this.id,
    required this.name,
    required this.status,
    this.phone,
    this.validFrom,
    this.validTo,
    this.purpose,
    this.passCode,
    this.usesRemaining,
    this.flatLabel,
    this.createdAt,
  });

  factory VisitorInvitation.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return VisitorInvitation(
      id: asString(json['id']),
      name: asString(json['name'] ?? json['guestName'], fallback: 'Guest'),
      status: humanize(asString(json['status'], fallback: 'ACTIVE')),
      phone: asStringOrNull(json['phone'] ?? json['mobile']),
      validFrom: asDateOrNull(json['validFrom']),
      validTo: asDateOrNull(json['validTo']),
      purpose: asStringOrNull(json['purpose']),
      passCode: asStringOrNull(json['passCode'] ?? json['code']),
      usesRemaining: asIntOrNull(
        json['usesRemaining'] ?? json['remainingUses'],
      ),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String name;
  final String status;
  final String? phone;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? purpose;
  final String? passCode;
  final int? usesRemaining;
  final String? flatLabel;
  final DateTime? createdAt;
}

enum DeliveryStatusValue {
  pendingApproval,
  approved,
  rejected,
  entered,
  exited,
  leftAtGate,
  collected,
}

class Delivery {
  const Delivery({
    required this.id,
    required this.status,
    this.courier,
    this.type,
    this.flatLabel,
    this.arrivedAt,
    this.decidedAt,
    this.note,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return Delivery(
      id: asString(json['id']),
      status: _deliveryStatus(asString(json['status'])),
      courier: asStringOrNull(
        json['courier'] ??
            json['company'] ??
            json['agentName'] ??
            json['deliveryPartner'],
      ),
      type: _optionalHumanized(json['deliveryType'] ?? json['type']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      arrivedAt: asDateOrNull(json['arrivedAt'] ?? json['createdAt']),
      decidedAt: asDateOrNull(json['decidedAt']),
      note: asStringOrNull(json['note']),
    );
  }

  final String id;
  final DeliveryStatusValue status;
  final String? courier;
  final String? type;
  final String? flatLabel;
  final DateTime? arrivedAt;
  final DateTime? decidedAt;
  final String? note;

  bool get isWaiting => status == DeliveryStatusValue.pendingApproval;

  static DeliveryStatusValue _deliveryStatus(String raw) =>
      switch (raw.toUpperCase()) {
        'PENDING_APPROVAL' => DeliveryStatusValue.pendingApproval,
        'APPROVED' => DeliveryStatusValue.approved,
        'REJECTED' => DeliveryStatusValue.rejected,
        'ENTERED' => DeliveryStatusValue.entered,
        'EXITED' => DeliveryStatusValue.exited,
        'LEFT_AT_GATE' => DeliveryStatusValue.leftAtGate,
        'COLLECTED' => DeliveryStatusValue.collected,
        _ => DeliveryStatusValue.pendingApproval,
      };
}

// ---------------------------------------------------------------- amenities

class Amenity {
  const Amenity({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.slotsEnabled = false,
    this.fee = 0,
    this.openTime,
    this.closeTime,
    this.imageUrl,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) => Amenity(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Amenity'),
    type: humanize(asString(json['type'], fallback: 'OTHER')),
    description: asStringOrNull(json['description']),
    slotsEnabled: asBool(json['slotsEnabled'] ?? json['bookingEnabled']),
    fee: asDouble(json['fee'] ?? json['charge'] ?? json['price']),
    openTime: asStringOrNull(json['openTime']),
    closeTime: asStringOrNull(json['closeTime']),
    imageUrl: asStringOrNull(json['imageUrl'] ?? json['image']),
  );

  final String id;
  final String name;
  final String type;
  final String? description;
  final bool slotsEnabled;
  final double fee;
  final String? openTime;
  final String? closeTime;
  final String? imageUrl;
}

class Booking {
  const Booking({
    required this.id,
    required this.amenityName,
    required this.status,
    this.date,
    this.slot,
    this.amount = 0,
    this.amenityId = '',
    this.flatLabel,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final amenity = asMapOrNull(json['amenity']);
    return Booking(
      id: asString(json['id']),
      amenityName: asString(
        amenity?['name'] ?? json['amenityName'],
        fallback: 'Booking',
      ),
      amenityId: asStringOrNull(json['amenityId'] ?? amenity?['id']) ?? '',
      status: humanize(asString(json['status'], fallback: 'PENDING')),
      date: asDateOrNull(json['date'] ?? json['bookingDate']),
      slot: asStringOrNull(json['slot'] ?? json['timeSlot']),
      amount: asDouble(json['amount'] ?? json['fee']),
      flatLabel: asStringOrNull(
        asMapOrNull(json['flat'])?['label'] ?? json['flatLabel'],
      ),
    );
  }

  final String id;
  final String amenityId;
  final String amenityName;
  final String status;
  final DateTime? date;
  final String? slot;
  final double amount;
  final String? flatLabel;

  /// A booking can be cancelled while it is still pending or confirmed — once
  /// the slot has passed there is nothing to cancel.
  bool get isCancellable =>
      status.toUpperCase() == 'PENDING' ||
      status.toUpperCase() == 'CONFIRMED' ||
      status.toUpperCase() == 'BOOKED';

  /// The slot as a date-time when the backend sends one; the slot label is the
  /// fallback because `slot` is free text.
  DateTime? get startAt => date;
}

/// One bookable slot on a date.
class Slot {
  const Slot({
    required this.id,
    required this.label,
    this.available = true,
    this.fee = 0,
  });

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
    id: asString(json['id'] ?? json['slot'] ?? json['label']),
    label: asString(
      json['label'] ?? json['slot'] ?? json['time'],
      fallback: 'Slot',
    ),
    available: asBool(json['available'], fallback: true),
    fee: asDouble(json['fee'] ?? json['amount']),
  );

  final String id;
  final String label;
  final bool available;
  final double fee;
}

// --------------------------------------------------------------- helpdesk

enum ComplaintStatusValue {
  open,
  assigned,
  inProgress,
  resolved,
  closed,
  reopened,
  escalated,
}

class Complaint {
  const Complaint({
    required this.id,
    required this.subject,
    required this.status,
    required this.category,
    required this.priority,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.assignedTo,
    this.resolutionNote,
    this.rating,
    this.ticketNumber,
    this.attachments = const [],
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
    id: asString(json['id']),
    subject: asString(json['subject'] ?? json['title'], fallback: 'Complaint'),
    status: _complaintStatus(asString(json['status'])),
    category: humanize(asString(json['category'], fallback: 'OTHER')),
    priority: humanize(asString(json['priority'], fallback: 'MEDIUM')),
    description: asStringOrNull(json['description']),
    createdAt: asDateOrNull(json['createdAt']),
    updatedAt: asDateOrNull(json['updatedAt']),
    assignedTo: asStringOrNull(
      asMapOrNull(json['assignedTo'])?['name'] ?? json['assignedToName'],
    ),
    resolutionNote: asStringOrNull(
      json['resolutionNote'] ?? json['resolution'],
    ),
    rating: asIntOrNull(json['rating']),
    ticketNumber: asStringOrNull(json['ticketNumber'] ?? json['number']),
    attachments: asMapList(json['attachments'] ?? json['fileIds']),
  );

  final String id;
  final String subject;
  final ComplaintStatusValue status;
  final String category;
  final String priority;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? assignedTo;
  final String? resolutionNote;
  final int? rating;
  final String? ticketNumber;
  final List<Map<String, dynamic>> attachments;

  bool get isClosed =>
      status == ComplaintStatusValue.resolved ||
      status == ComplaintStatusValue.closed;

  bool get canReopen => isClosed;

  /// Human label for [status]. The backend uses a wider set of statuses than the
  /// enum models, so anything unrecognised falls back to a readable form.
  String get statusLabel => switch (status) {
    ComplaintStatusValue.open => 'Open',
    ComplaintStatusValue.assigned => 'Assigned',
    ComplaintStatusValue.inProgress => 'In progress',
    ComplaintStatusValue.resolved => 'Resolved',
    ComplaintStatusValue.closed => 'Closed',
    ComplaintStatusValue.reopened => 'Reopened',
    ComplaintStatusValue.escalated => 'Escalated',
  };

  static ComplaintStatusValue _complaintStatus(String raw) =>
      switch (raw.toUpperCase()) {
        'OPEN' => ComplaintStatusValue.open,
        'ASSIGNED' => ComplaintStatusValue.assigned,
        'IN_PROGRESS' => ComplaintStatusValue.inProgress,
        'RESOLVED' => ComplaintStatusValue.resolved,
        'CLOSED' => ComplaintStatusValue.closed,
        'REOPENED' => ComplaintStatusValue.reopened,
        _ => ComplaintStatusValue.escalated,
      };
}

/// A message on a complaint thread.
class ComplaintComment {
  const ComplaintComment({
    required this.id,
    required this.body,
    required this.authorName,
    this.isStaff = false,
    this.createdAt,
  });

  /// The backend returns `{ authorId, authorRole, message, isInternal, at }`.
  /// There is no `author.name`, so the role decides the label: the resident's
  /// own messages read as "You", everything else as the office that answered.
  factory ComplaintComment.fromJson(Map<String, dynamic> json) {
    final role = asStringOrNull(json['authorRole']);
    return ComplaintComment(
      id: asString(json['id'] ?? json['authorId'] ?? json['at'] ?? 'comment'),
      body: asString(
        json['message'] ?? json['body'] ?? json['text'] ?? json['comment'],
      ),
      authorName:
          asStringOrNull(json['authorName']) ??
          switch (role) {
            'RESIDENT' => 'You',
            'SOCIETY_ADMIN' => 'Society office',
            'VENDOR' => 'Vendor',
            'STAFF' => 'Staff',
            _ => humanize(role ?? 'user'),
          },
      isStaff: asBool(
        json['isStaff'] ??
            json['fromStaff'] ??
            (role != null && role != 'RESIDENT'),
      ),
      createdAt: asDateOrNull(json['at'] ?? json['createdAt']),
    );
  }

  final String id;
  final String body;
  final String authorName;
  final bool isStaff;
  final DateTime? createdAt;
}

// ---------------------------------------------------------------- community

class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    required this.authorName,
    this.authorRole,
    this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.images = const [],
    this.poll,
    this.kind,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = asMapOrNull(json['author']);
    return Post(
      id: asString(json['id']),
      title: asString(json['title'], fallback: ''),
      body: asString(json['body'] ?? json['content']),
      status: humanize(asString(json['status'], fallback: 'PUBLISHED')),
      authorName: asString(
        author?['name'] ?? json['authorName'],
        fallback: 'Resident',
      ),
      authorRole: asStringOrNull(author?['userType'] ?? json['authorRole']),
      createdAt: asDateOrNull(json['createdAt']),
      likeCount: asInt(json['likeCount'] ?? json['likes']),
      commentCount: asInt(json['commentCount'] ?? json['comments']),
      liked: asBool(json['liked'] ?? json['isLiked']),
      images: asMapList(json['images'] ?? json['fileIds']),
      poll: asMapOrNull(json['poll']),
      kind: asStringOrNull(json['kind']),
    );
  }

  final String id;
  final String title;
  final String body;
  final String status;
  final String authorName;
  final String? authorRole;
  final DateTime? createdAt;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final List<Map<String, dynamic>> images;
  final Map<String, dynamic>? poll;
  final String? kind;

  bool get isDraft => status.toUpperCase() == 'DRAFT';

  /// The card body: the title when there is one, otherwise the first lines.
  String get preview {
    if (title.isNotEmpty) return title;
    return body.trim().split('\n').take(3).join(' ');
  }

  /// Trims a long body for the feed, preserving the full text for detail.
  String get excerpt {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 220 ? flat : '${flat.substring(0, 220)}…';
  }
}

/// A poll attached to a community post.
class Poll {
  const Poll({
    required this.id,
    required this.question,
    required this.status,
    this.options = const [],
    this.totalVotes = 0,
    this.votedOptionId,
    this.showResults = false,
  });

  factory Poll.fromJson(Map<String, dynamic> json) => Poll(
    id: asString(json['id']),
    question: asString(json['question'] ?? json['title'], fallback: 'Poll'),
    status: humanize(asString(json['status'], fallback: 'ACTIVE')),
    options: asMapList(
      json['options'],
    ).map(PollOption.fromJson).toList(growable: false),
    totalVotes: asInt(json['totalVotes'] ?? json['voteCount']),
    votedOptionId: asStringOrNull(json['votedOptionId']),
    showResults: asBool(json['showResults']),
  );

  final String id;
  final String question;
  final String status;
  final List<PollOption> options;
  final int totalVotes;
  final String? votedOptionId;
  final bool showResults;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get hasVoted => votedOptionId != null;
}

class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    this.votes = 0,
    this.percent = 0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
    id: asString(json['id'] ?? json['optionId']),
    label: asString(json['label'] ?? json['text'], fallback: 'Option'),
    votes: asInt(json['votes'] ?? json['count']),
    percent: asDouble(json['percent'] ?? json['percentage']),
  );

  final String id;
  final String label;
  final int votes;
  final double percent;
}

// -------------------------------------------------------------- directory

class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.name,
    this.flatLabel,
    this.towerName,
    this.phone,
    this.residentType,
  });

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return DirectoryEntry(
      id: asString(json['id'] ?? json['userId']),
      name: asString(
        json['name'] ?? asMapOrNull(json['user'])?['name'],
        fallback: 'Resident',
      ),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
      towerName: asStringOrNull(flat?['towerName'] ?? json['towerName']),
      phone: asStringOrNull(json['phone'] ?? json['mobile']),
      residentType: asStringOrNull(json['residentType']) == null
          ? null
          : humanize(asString(json['residentType'])),
    );
  }

  final String id;
  final String name;
  final String? flatLabel;
  final String? towerName;
  final String? phone;
  final String? residentType;

  String get subtitle {
    final flat = flatLabel ?? 'Resident';
    return residentType == null ? flat : '$flat · $residentType!';
  }
}

// ------------------------------------------------------------------- misc

/// A notification in the user's inbox.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
    this.data = const {},
    this.societyId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: asString(json['id']),
        type: humanize(asString(json['type'], fallback: 'SYSTEM')),
        title: asString(json['title'], fallback: 'Notification'),
        body: asString(json['body']),
        readAt: asDateOrNull(json['readAt']),
        createdAt: asDateOrNull(json['createdAt']),
        data: asMap(json['data']),
        societyId: asStringOrNull(json['societyId']),
      );

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;
  final Map<String, dynamic> data;
  final String? societyId;

  bool get isRead => readAt != null;

  /// A route hint from the payload so a tap opens the right screen.
  String? get route {
    final r = data['route'];
    if (r is String && r.isNotEmpty) return r;
    final id = data['id'] ?? data['entityId'];
    final kind = type.toUpperCase();
    if (id == null || id is! String) return null;
    return switch (kind) {
      'VISITOR' => '/resident/visitors/$id',
      'PAYMENT' || 'BOOKING' => '/resident/payments',
      'COMPLAINT' => '/resident/helpdesk/$id',
      'ANNOUNCEMENT' => '/resident/notices/$id',
      'APPROVAL' => '/admin/approvals/$id',
      _ => null,
    };
  }
}

/// A family member's attendance record for a domestic helper.
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.markedBy,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: asString(json['id']),
        date: asDate(json['date']),
        status: humanize(asString(json['status'], fallback: 'PRESENT')),
        markedBy: asStringOrNull(json['markedByName'] ?? json['markedBy']),
      );

  final String id;
  final DateTime date;
  final String status;
  final String? markedBy;
}

/// A domestic helper employed by the resident's flat.
class DomesticHelper {
  const DomesticHelper({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.phone,
    this.verified = false,
    this.attendance = const [],
    this.payments = const [],
    this.joinedAt,
  });

  factory DomesticHelper.fromJson(Map<String, dynamic> json) => DomesticHelper(
    id: asString(json['id']),
    name: asString(json['name'], fallback: 'Helper'),
    type: humanize(asString(json['type'], fallback: 'MAID')),
    status: humanize(
      asString(json['status'], fallback: 'PENDING_VERIFICATION'),
    ),
    phone: asStringOrNull(json['phone'] ?? json['mobile']),
    verified: asBool(json['verified']),
    attendance: asMapList(
      json['attendance'],
    ).map(AttendanceRecord.fromJson).toList(growable: false),
    payments: asMapList(json['payments']),
    joinedAt: asDateOrNull(json['createdAt']),
  );

  final String id;
  final String name;
  final String type;
  final String status;
  final String? phone;
  final bool verified;
  final List<AttendanceRecord> attendance;
  final List<Map<String, dynamic>> payments;
  final DateTime? joinedAt;
}

/// A service provider available to hire.
class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.name,
    required this.category,
    this.phone,
    this.rating,
    this.reviewCount = 0,
    this.verified = false,
    this.description,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) =>
      ServiceProvider(
        id: asString(json['id']),
        name: asString(json['name'], fallback: 'Provider'),
        category: humanize(asString(json['category'], fallback: 'OTHER')),
        phone: asStringOrNull(json['phone'] ?? json['mobile']),
        rating: _optionalDouble(json['rating'] ?? json['averageRating']),
        reviewCount: asInt(json['reviewCount'] ?? json['ratingsCount']),
        verified: asBool(json['verified']),
        description: asStringOrNull(json['description']),
      );

  final String id;
  final String name;
  final String category;
  final String? phone;
  final double? rating;
  final int reviewCount;
  final bool verified;
  final String? description;
}

/// An emergency contact (society emergency numbers).
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.category,
    this.phone,
    this.available24x7 = false,
    this.description,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: asString(json['id']),
        name: asString(json['name'], fallback: 'Contact'),
        category: humanize(
          asString(json['category'] ?? json['type'], fallback: 'OTHER'),
        ),
        phone: asStringOrNull(json['phone'] ?? json['mobile']),
        available24x7: asBool(json['available24x7'] ?? json['is24x7']),
        description: asStringOrNull(json['description']),
      );

  final String id;
  final String name;
  final String category;
  final String? phone;
  final bool available24x7;
  final String? description;
}

/// An incident reported by a resident or guard.
class Incident {
  const Incident({
    required this.id,
    required this.type,
    required this.status,
    this.description,
    this.location,
    this.reportedBy,
    this.createdAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
    id: asString(json['id']),
    type: humanize(asString(json['type'], fallback: 'OTHER')),
    status: humanize(asString(json['status'], fallback: 'OPEN')),
    description: asStringOrNull(json['description']),
    location: asStringOrNull(json['location']),
    reportedBy: asStringOrNull(json['reportedByName'] ?? json['reportedBy']),
    createdAt: asDateOrNull(json['createdAt']),
  );

  final String id;
  final String type;
  final String status;
  final String? description;
  final String? location;
  final String? reportedBy;
  final DateTime? createdAt;
}

/// A vehicle registered to the resident's flat.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.type,
    this.brand,
    this.model,
    this.parkingSlot,
    this.status,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: asString(json['id']),
    plate: asString(json['plateNumber'] ?? json['plate'], fallback: '—'),
    type: humanize(
      asString(json['type'] ?? json['vehicleType'], fallback: 'CAR'),
    ),
    brand: asStringOrNull(json['brand']),
    model: asStringOrNull(json['model']),
    parkingSlot: asStringOrNull(json['slotLabel'] ?? json['parkingSlot']),
    status: asStringOrNull(json['status']) == null
        ? null
        : humanize(asString(json['status'])),
  );

  final String id;
  final String plate;
  final String type;
  final String? brand;
  final String? model;
  final String? parkingSlot;
  final String? status;

  /// "Hyundai Creta" when both are known, else the type.
  String get description {
    if (brand != null && model != null) return '$brand $model';
    if (brand != null) return brand!;
    return type;
  }
}

/// A parking slot.
class ParkingSlot {
  const ParkingSlot({
    required this.id,
    required this.label,
    required this.status,
    this.type,
    this.flatLabel,
  });

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    final flat = asMapOrNull(json['flat']);
    return ParkingSlot(
      id: asString(json['id']),
      label: asString(
        json['code'] ?? json['label'] ?? json['slotNumber'],
        fallback: 'Slot',
      ),
      status: humanize(asString(json['status'], fallback: 'AVAILABLE')),
      type: _optionalHumanized(json['type']),
      flatLabel: asStringOrNull(flat?['label'] ?? json['flatLabel']),
    );
  }

  final String id;
  final String label;
  final String status;
  final String? type;
  final String? flatLabel;
}

/// A personal or society document.
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.scope,
    this.fileId,
    this.fileName,
    this.uploadedAt,
    this.uploadedBy,
    this.sizeBytes,
  });

  factory DocumentRecord.fromJson(Map<String, dynamic> json) => DocumentRecord(
    id: asString(json['id']),
    title: asString(
      json['title'] ?? json['name'] ?? json['fileName'],
      fallback: 'Document',
    ),
    category: humanize(asString(json['category'], fallback: 'OTHER')),
    scope: humanize(
      asString(json['scope'] ?? json['documentScope'], fallback: 'PERSONAL'),
    ),
    fileId: asStringOrNull(json['fileId'] ?? json['file']),
    fileName: asStringOrNull(json['fileName'] ?? json['originalName']),
    uploadedAt: asDateOrNull(json['createdAt'] ?? json['uploadedAt']),
    uploadedBy: asStringOrNull(json['uploadedByName'] ?? json['uploadedBy']),
    sizeBytes: asIntOrNull(json['sizeBytes'] ?? json['size']),
  );

  final String id;
  final String title;
  final String category;
  final String scope;
  final String? fileId;
  final String? fileName;
  final DateTime? uploadedAt;
  final String? uploadedBy;
  final int? sizeBytes;

  bool get isSocietyDoc => scope.toUpperCase() == 'SOCIETY';
}

/// A listing in the marketplace.
class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.status,
    required this.price,
    this.description,
    this.category,
    this.condition,
    this.images = const [],
    this.sellerName,
    this.location,
    this.createdAt,
    this.isMine = false,
    this.isFavourite = false,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    final seller = asMapOrNull(json['seller']);
    return Listing(
      id: asString(json['id']),
      title: asString(json['title'], fallback: 'Listing'),
      status: humanize(asString(json['status'], fallback: 'DRAFT')),
      price: asDouble(json['price']),
      description: asStringOrNull(json['description']),
      category: asStringOrNull(json['category']) == null
          ? null
          : humanize(asString(json['category'])),
      condition: _optionalHumanized(json['condition']),
      images: asMapList(json['images'] ?? json['fileIds']),
      sellerName: asStringOrNull(seller?['name'] ?? json['sellerName']),
      location: asStringOrNull(json['location']),
      createdAt: asDateOrNull(json['createdAt']),
      isMine: asBool(json['isMine']),
      isFavourite: asBool(json['isFavourite'] ?? json['favourited']),
    );
  }

  final String id;
  final String title;
  final String status;
  final double price;
  final String? description;
  final String? category;
  final String? condition;
  final List<Map<String, dynamic>> images;
  final String? sellerName;
  final String? location;
  final DateTime? createdAt;
  final bool isMine;
  final bool isFavourite;

  /// The first image, as a URL or file id, for a card thumbnail.
  String? get imageUrl {
    for (final image in images) {
      final url = asStringOrNull(image['url'] ?? image['fileUrl']);
      if (url != null) return url;
      final id = asStringOrNull(image['id'] ?? image['fileId']);
      if (id != null) return '/files/$id';
    }
    return null;
  }

  /// A price for a listing card: money for a sale, per-month for a rent.
  String get priceLabel => Fmt.money(price);
}

/// A property listing (sale, rent, PG).
class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    required this.price,
    this.description,
    this.bhk,
    this.areaSqft,
    this.furnishing,
    this.location,
    this.images = const [],
    this.ownerName,
    this.createdAt,
    this.isMine = false,
    this.isFavourite = false,
  });

  factory PropertyListing.fromJson(Map<String, dynamic> json) {
    final owner = asMapOrNull(json['owner']);
    return PropertyListing(
      id: asString(json['id']),
      title: asString(json['title'], fallback: 'Property'),
      status: humanize(asString(json['status'], fallback: 'DRAFT')),
      type: humanize(
        asString(json['type'] ?? json['listingType'], fallback: 'FOR_SALE'),
      ),
      price: asDouble(json['price']),
      description: asStringOrNull(json['description']),
      bhk: asIntOrNull(json['bhk'] ?? json['bedrooms']),
      areaSqft: asIntOrNull(json['areaSqft'] ?? json['area']),
      furnishing: _optionalHumanized(json['furnishing']),
      location: asStringOrNull(json['location']),
      images: asMapList(json['images'] ?? json['fileIds']),
      ownerName: asStringOrNull(owner?['name'] ?? json['ownerName']),
      createdAt: asDateOrNull(json['createdAt']),
      isMine: asBool(json['isMine']),
      isFavourite: asBool(json['isFavourite'] ?? json['favourited']),
    );
  }

  final String id;
  final String title;
  final String status;
  final String type;
  final double price;
  final String? description;
  final int? bhk;
  final int? areaSqft;
  final String? furnishing;
  final String? location;
  final List<Map<String, dynamic>> images;
  final String? ownerName;
  final DateTime? createdAt;
  final bool isMine;
  final bool isFavourite;

  /// The listing type as a short word: "For sale" / "To let".
  String get purpose => type;

  /// When the listing was posted (alias used by the resident card).
  DateTime? get postedAt => createdAt;

  /// Bedrooms, when the office recorded them.
  int? get bedrooms => bhk;

  /// The flat label is not on the public card; the title carries it.
  String? get flatLabel => null;

  /// What to show where a price would be: money, plus "/month" for a rental.
  String get priceLabel => type.toUpperCase().contains('RENT')
      ? '${Fmt.money(price)}/mo'
      : Fmt.money(price);

  /// The owner's phone is not exposed on the resident card — the enquiry form
  /// is the supported path, so the call action is absent by design.
  String? get postedByPhone => null;

  /// "3 BHK · 1,450 sq ft" when the details are present.
  String? get spec {
    final parts = <String>[
      if (bhk != null) '$bhk BHK',
      if (areaSqft != null) '${_formatArea(areaSqft!)} sq ft',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _formatArea(int v) {
    final s = v.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// An inquiry from an interested resident about a property.
class PropertyInquiry {
  const PropertyInquiry({
    required this.id,
    required this.name,
    required this.status,
    this.phone,
    this.message,
    this.propertyTitle,
    this.createdAt,
  });

  factory PropertyInquiry.fromJson(Map<String, dynamic> json) {
    final property = asMapOrNull(json['property']);
    return PropertyInquiry(
      id: asString(json['id']),
      name: asString(json['name'] ?? json['inquirerName'], fallback: 'Enquiry'),
      status: humanize(asString(json['status'], fallback: 'NEW')),
      phone: asStringOrNull(json['phone'] ?? json['mobile']),
      message: asStringOrNull(json['message']),
      propertyTitle: asStringOrNull(
        property?['title'] ?? json['propertyTitle'],
      ),
      createdAt: asDateOrNull(json['createdAt']),
    );
  }

  final String id;
  final String name;
  final String status;
  final String? phone;
  final String? message;
  final String? propertyTitle;
  final DateTime? createdAt;
}

/// A chat conversation.
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    this.lastMessage,
    this.lastAt,
    this.unreadCount = 0,
    this.participantId,
    this.participantRole,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final last = asMapOrNull(json['lastMessage']);
    return Conversation(
      id: asString(json['id']),
      title: asString(
        json['title'] ?? json['name'] ?? json['subject'],
        fallback: 'Conversation',
      ),
      lastMessage: asStringOrNull(last?['body'] ?? json['lastMessageText']),
      lastAt: asDateOrNull(
        json['lastMessageAt'] ?? json['updatedAt'] ?? json['createdAt'],
      ),
      unreadCount: asInt(json['unreadCount']),
      participantId: asStringOrNull(json['participantId']),
      participantRole: _optionalHumanized(json['participantRole']),
    );
  }

  final String id;
  final String title;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unreadCount;
  final String? participantId;
  final String? participantRole;
}

/// One message in a conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.isMine,
    this.senderName,
    this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = asMapOrNull(json['sender']);
    return ChatMessage(
      id: asString(json['id']),
      body: asString(json['body'] ?? json['text']),
      isMine: asBool(json['isMine'] ?? json['fromMe']),
      senderName: asStringOrNull(sender?['name'] ?? json['senderName']),
      createdAt: asDateOrNull(json['createdAt']),
      readAt: asDateOrNull(json['readAt']),
    );
  }

  final String id;
  final String body;
  final bool isMine;
  final String? senderName;
  final DateTime? createdAt;
  final DateTime? readAt;
}

/// A lost-and-found report.
class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.title,
    required this.status,
    required this.kind,
    this.description,
    this.location,
    this.createdAt,
    this.reportedBy,
  });

  factory LostFoundItem.fromJson(Map<String, dynamic> json) => LostFoundItem(
    id: asString(json['id']),
    title: asString(json['title'], fallback: 'Item'),
    status: humanize(asString(json['status'], fallback: 'OPEN')),
    kind: humanize(asString(json['type'] ?? json['kind'], fallback: 'LOST')),
    description: asStringOrNull(json['description']),
    location: asStringOrNull(json['location']),
    createdAt: asDateOrNull(json['createdAt']),
    reportedBy: asStringOrNull(json['reportedByName']),
  );

  final String id;
  final String title;
  final String status;
  final String kind;
  final String? description;
  final String? location;
  final DateTime? createdAt;
  final String? reportedBy;
}

/// Humanizes a value that may be absent: `null` stays `null`.
String? _optionalHumanized(dynamic v) {
  final s = asStringOrNull(v);
  if (s == null || s.trim().isEmpty) return null;
  return humanize(s);
}

/// Reads a numeric value that may be absent.
double? _optionalDouble(dynamic v) => asDoubleOrNull(v);
