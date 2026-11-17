import 'package:flutter/material.dart';

import '../tokens.dart';

/// The tone of a status. Five tones, each with a background and a foreground
/// that pass contrast. Nothing else is allowed: no gradients, no glow, no
/// left-stripe accent.
enum Tone { neutral, info, positive, warning, danger, accent }

extension ToneColors on Tone {
  Color get background {
    return switch (this) {
      Tone.neutral => Tokens.neutralTagTint,
      Tone.info => Tokens.infoTint,
      Tone.positive => Tokens.positiveTint,
      Tone.warning => Tokens.warningTint,
      Tone.danger => Tokens.dangerTint,
      Tone.accent => Tokens.accentTint,
    };
  }

  Color get foreground {
    return switch (this) {
      Tone.neutral => Tokens.neutralTag,
      Tone.info => Tokens.info,
      Tone.positive => Tokens.positive,
      Tone.warning => Tokens.warning,
      Tone.danger => Tokens.danger,
      Tone.accent => Tokens.accent,
    };
  }
}

/// A status pill: small, one line, one colour pair.
///
/// Used for every backend status value. The label is derived here so the whole
/// app spells "UNDER_REVIEW" as "Under review" in one place.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = Tone.neutral,
    this.dot = false,
  });

  final String label;
  final Tone tone;

  /// Draw a small dot before the label. Use for live state (arrived, active),
  /// not for every badge.
  final bool dot;

  /// Builds the right badge for a backend status string.
  ///
  /// `contextual` picks the tone: the same word can be good in one domain and
  /// bad in another (REJECTED for a complaint is bad, for a request it is
  /// neutral), so the mapping is explicit rather than guessed.
  factory StatusBadge.forStatus(
    String status, {
    Key? key,
    bool dot = false,
    StatusDomain? domain,
  }) {
    final (label, tone) = StatusTone.resolve(status, domain: domain);
    return StatusBadge(key: key, label: label, tone: tone, dot: dot);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(Tokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: tone.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Which domain a status belongs to. Some words mean different things in
/// different domains, so the mapping is explicit.
enum StatusDomain {
  generic,
  approval,
  resident,
  visitor,
  delivery,
  payment,
  invoice,
  complaint,
  booking,
  helpdesk,
  ticket,
  society,
  listing,
  report,
  alert,
  incident,
  attendance,
  domesticHelp,
  parking,
  task,
  notice,
}

/// Maps a backend status enum to a human label and a tone.
///
/// Every enum in `backend/src/common/constants/enums.ts` is covered. Unknown
/// values fall back to a neutral badge showing the value with underscores
/// replaced by spaces, so a new backend status never breaks the UI.
class StatusTone {
  StatusTone._();

  static const Map<String, (String, Tone)> _generic = {
    // positive
    'ACTIVE': ('Active', Tone.positive),
    'APPROVED': ('Approved', Tone.positive),
    'PUBLISHED': ('Published', Tone.positive),
    'PAID': ('Paid', Tone.positive),
    'SUCCESS': ('Successful', Tone.positive),
    'VERIFIED': ('Verified', Tone.positive),
    'PRESENT': ('Present', Tone.positive),
    'DONE': ('Done', Tone.positive),
    'RESOLVED': ('Resolved', Tone.positive),
    'CONFIRMED': ('Confirmed', Tone.positive),
    'COMPLETED': ('Completed', Tone.positive),
    'CLAIMED': ('Claimed', Tone.positive),
    'CHECKED_IN': ('Checked in', Tone.positive),
    'ENTERED': ('Entered', Tone.positive),
    'COLLECTED': ('Collected', Tone.positive),
    'AVAILABLE': ('Available', Tone.positive),
    'IN_STOCK': ('In stock', Tone.positive),
    'CLOSED_WON': ('Closed', Tone.positive),
    // pending / in flight
    'PENDING': ('Pending', Tone.warning),
    'PENDING_APPROVAL': ('Awaiting approval', Tone.warning),
    'PENDING_VERIFICATION': ('Awaiting verification', Tone.warning),
    'UNDER_REVIEW': ('Under review', Tone.warning),
    'SUBMITTED': ('Submitted', Tone.info),
    'DRAFT': ('Draft', Tone.neutral),
    'CHANGES_REQUESTED': ('Changes requested', Tone.warning),
    'IN_PROGRESS': ('In progress', Tone.info),
    'ASSIGNED': ('Assigned', Tone.info),
    'REOPENED': ('Reopened', Tone.warning),
    'ESCALATED': ('Escalated', Tone.warning),
    'INVESTIGATING': ('Investigating', Tone.info),
    'OPEN': ('Open', Tone.info),
    'PARTIALLY_PAID': ('Partly paid', Tone.warning),
    'OVERDUE': ('Overdue', Tone.danger),
    'ACKNOWLEDGED': ('Acknowledged', Tone.info),
    'INITIATED': ('Initiated', Tone.info),
    'EXPECTED': ('Expected', Tone.info),
    'TIMEOUT_ALLOWED': ('Auto approved', Tone.info),
    'LEFT_AT_GATE': ('Left at gate', Tone.info),
    'IN_USE': ('In use', Tone.info),
    'UNDER_MAINTENANCE': ('Under maintenance', Tone.warning),
    'ONLINE': ('Online', Tone.info),
    'REVIEWED': ('Reviewed', Tone.info),
    'HALF_DAY': ('Half day', Tone.info),
    'LEAVE': ('On leave', Tone.neutral),
    'NO_SHOW': ('No show', Tone.danger),
    // negative
    'INACTIVE': ('Inactive', Tone.neutral),
    'REJECTED': ('Rejected', Tone.danger),
    'SUSPENDED': ('Suspended', Tone.danger),
    'EXPIRED': ('Expired', Tone.neutral),
    'REMOVED': ('Removed', Tone.danger),
    'CANCELLED': ('Cancelled', Tone.neutral),
    'DENIED': ('Denied', Tone.danger),
    'FAILED': ('Failed', Tone.danger),
    'REFUNDED': ('Refunded', Tone.info),
    'DISMISSED': ('Dismissed', Tone.neutral),
    'FALSE_ALARM': ('False alarm', Tone.neutral),
    'BLOCKED': ('Blocked', Tone.danger),
    'MOVED_OUT': ('Moved out', Tone.neutral),
    'TERMINATED': ('Terminated', Tone.danger),
    'RETIRED': ('Retired', Tone.neutral),
    'ARCHIVED': ('Archived', Tone.neutral),
    'EXHAUSTED': ('Exhausted', Tone.neutral),
    'ABSENT': ('Absent', Tone.danger),
    'CLOSED': ('Closed', Tone.neutral),
    'DISABLED': ('Disabled', Tone.neutral),
    // contextual fallbacks (used when no domain override exists)
    'OCCUPIED': ('Occupied', Tone.info),
    'VACANT': ('Vacant', Tone.neutral),
    'ALLOCATED': ('Allocated', Tone.info),
    'REJECTED_BY_ADMIN': ('Rejected', Tone.danger),
  };

  static const Map<StatusDomain, Map<String, (String, Tone)>> _byDomain = {
    StatusDomain.approval: {
      'APPROVED': ('Approved', Tone.positive),
      'REJECTED': ('Rejected', Tone.danger),
      'PUBLISHED': ('Published', Tone.positive),
      'SUSPENDED': ('SUSPENDED', Tone.warning),
    },
    StatusDomain.invoice: {
      'UNPAID': ('Unpaid', Tone.warning),
      'PAID': ('Paid', Tone.positive),
      'OVERDUE': ('Overdue', Tone.danger),
      'PARTIALLY_PAID': ('Partly paid', Tone.warning),
      'CANCELLED': ('Cancelled', Tone.neutral),
    },
    StatusDomain.payment: {
      'INITIATED': ('Initiated', Tone.info),
      'PENDING_VERIFICATION': ('Awaiting verification', Tone.warning),
      'SUCCESS': ('Successful', Tone.positive),
      'FAILED': ('Failed', Tone.danger),
      'REFUNDED': ('Refunded', Tone.info),
    },
    StatusDomain.visitor: {
      'EXPECTED': ('Expected', Tone.info),
      'PENDING_APPROVAL': ('Awaiting approval', Tone.warning),
      'APPROVED': ('Approved', Tone.positive),
      'CHECKED_IN': ('Checked in', Tone.positive),
      'CHECKED_OUT': ('Checked out', Tone.neutral),
      'DENIED': ('Denied', Tone.danger),
    },
    StatusDomain.complaint: {
      'OPEN': ('Open', Tone.info),
      'ASSIGNED': ('Assigned', Tone.info),
      'IN_PROGRESS': ('In progress', Tone.info),
      'RESOLVED': ('Resolved', Tone.positive),
      'CLOSED': ('Closed', Tone.neutral),
      'REOPENED': ('Reopened', Tone.warning),
      'ESCALATED': ('Escalated', Tone.danger),
    },
    StatusDomain.resident: {
      'PENDING': ('Pending', Tone.warning),
      'APPROVED': ('Approved', Tone.positive),
      'REJECTED': ('Rejected', Tone.danger),
      'MOVED_OUT': ('Moved out', Tone.neutral),
    },
  };

  /// Returns `(label, tone)` for a backend status value.
  static (String, Tone) resolve(String status, {StatusDomain? domain}) {
    if (status.trim().isEmpty) return ('Unknown', Tone.neutral);

    final key = status.trim().toUpperCase();

    if (domain != null) {
      final override = _byDomain[domain]?[key];
      if (override != null) return override;
    }

    final base = _generic[key];
    if (base != null) return base;

    // Unknown value: show it readably rather than hiding it.
    final readable = key
        .toLowerCase()
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    return (readable, Tone.neutral);
  }
}

/// A neutral tag for enum values that are not statuses (categories, types).
///
/// Same visual weight as a badge but never coloured: categories are labels, not
/// states, and colouring them would compete with real statuses.
class MetaTag extends StatelessWidget {
  const MetaTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Tokens.space2, vertical: 3),
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(Tokens.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeXs,
          height: 1.1,
          fontWeight: FontWeight.w500,
          color: Tokens.inkMuted,
        ),
      ),
    );
  }
}
