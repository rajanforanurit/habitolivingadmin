import 'dart:async';

import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/resident.dart';
import '../api_client.dart';

/// Guard API client: the 32 routes under `/guard`.
///
/// The guard's job at the gate is fast lookup and clear decisions, so this
/// client keeps those actions one call each: lookup a flat, verify a pass,
/// record entry or exit, deny.
class GuardApi {
  GuardApi(this._api);
  final ApiClient _api;

  /// Today's briefing: expected visitors, pending approvals, active alerts and
  /// the assigned gate.
  Future<GuardDashboard> dashboard() async {
    final data = await _api.get('/guard/dashboard');
    return GuardDashboard.fromJson(reqMap(data, field: 'dashboard'));
  }

  /// The gate this guard is assigned to.
  Future<String> myGate() async {
    final data = await _api.get('/guard/gate');
    return asString(
      reqMap(data, field: 'gate')['name'],
      fallback: 'Unassigned',
    );
  }

  /// Look up a destination flat by label. Returns the matching flats.
  Future<List<Map<String, dynamic>>> lookupFlat(String query) async {
    final data = await _api.get(
      '/guard/flats/lookup',
      query: {'q': query, if (query.trim().isNotEmpty) 'search': query.trim()},
    );
    return asMapList(data);
  }

  /// Search visitor records (history and current).
  Future<PageResult<Visitor>> visitors({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final data = await _api.get(
      '/guard/visitors',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Visitor.fromJson);
  }

  /// Visitors waiting for a resident decision.
  Future<List<Visitor>> pendingVisitors() async {
    final data = await _api.get('/guard/visitors/pending');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  /// Visitors currently inside the society.
  Future<List<Visitor>> activeVisitors() async {
    final data = await _api.get('/guard/visitors/active');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  /// Pre-approved visitors expected today.
  Future<List<Visitor>> expectedVisitors() async {
    final data = await _api.get('/guard/visitors/expected');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  /// Register a walk-in visitor and ask the resident to approve.
  Future<Visitor> registerVisitor({
    required String name,
    required String flatId,
    String? phone,
    String? purpose,
    String? vehicleNumber,
  }) async {
    final data = await _api.post(
      '/guard/visitors',
      body: {
        'name': name,
        'flatId': flatId,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (vehicleNumber != null && vehicleNumber.isNotEmpty)
          'vehicleNumber': vehicleNumber,
      },
    );
    return Visitor.fromJson(reqMap(data, field: 'visitor'));
  }

  /// Verify a visitor pass by its OTP code or scanned QR token.
  Future<Visitor> verifyPass(String code) async {
    final data = await _api.post(
      '/guard/visitors/verify',
      body: {'code': code},
    );
    return Visitor.fromJson(reqMap(data, field: 'visitor'));
  }

  /// Record an emergency entry (ambulance, fire, police). Bypasses approval.
  Future<Visitor> emergencyEntry({
    required String flatId,
    required String type,
    String? name,
    String? note,
  }) async {
    final data = await _api.post(
      '/guard/visitors/emergency-entry',
      body: {
        'flatId': flatId,
        'type': type,
        if (name != null && name.isNotEmpty) 'name': name,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Visitor.fromJson(reqMap(data, field: 'visitor'));
  }

  /// Re-contact the resident for an approval decision.
  Future<void> requestApproval(String visitorId) async {
    await _api.post('/guard/visitors/$visitorId/request-approval');
  }

  Future<void> recordEntry(String visitorId) async {
    await _api.post('/guard/visitors/$visitorId/entry');
  }

  Future<void> recordExit(String visitorId) async {
    await _api.post('/guard/visitors/$visitorId/exit');
  }

  Future<void> denyEntry(String visitorId, {String? reason}) async {
    await _api.post(
      '/guard/visitors/$visitorId/deny',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  // ------------------------------------------------------------ deliveries

  Future<PageResult<Delivery>> deliveries({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    final data = await _api.get(
      '/guard/deliveries',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Delivery.fromJson);
  }

  /// Register delivery personnel and notify the resident.
  Future<Delivery> registerDelivery({
    required String flatId,
    String? courier,
    String? type,
    String? note,
  }) async {
    final data = await _api.post(
      '/guard/deliveries',
      body: {
        'flatId': flatId,
        if (courier != null && courier.isNotEmpty) 'courier': courier,
        if (type != null && type.isNotEmpty) 'type': type,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Delivery.fromJson(reqMap(data, field: 'delivery'));
  }

  Future<void> requestDeliveryApproval(String deliveryId) async {
    await _api.post('/guard/deliveries/$deliveryId/request-approval');
  }

  Future<void> recordDeliveryEntry(String deliveryId) async {
    await _api.post('/guard/deliveries/$deliveryId/entry');
  }

  Future<void> recordDeliveryExit(String deliveryId) async {
    await _api.post('/guard/deliveries/$deliveryId/exit');
  }

  /// Accept a parcel at the gate and generate a collection OTP for the resident.
  Future<Map<String, dynamic>> leaveAtGate(String deliveryId) async {
    final data = await _api.post('/guard/deliveries/$deliveryId/leave-at-gate');
    return reqMap(data, field: 'delivery');
  }

  /// Hand a parcel over after the resident presents the OTP.
  Future<void> handOver(String deliveryId, {required String otp}) async {
    await _api.post(
      '/guard/deliveries/$deliveryId/handover',
      body: {'otp': otp},
    );
  }

  // ---------------------------------------------------------- domestic help

  /// Verify a domestic worker by their entry code.
  Future<Map<String, dynamic>> lookupHelper(String code) async {
    final data = await _api.post(
      '/guard/domestic-help/lookup',
      body: {'code': code},
    );
    return reqMap(data, field: 'helper');
  }

  Future<void> checkInHelper(String assignmentId) async {
    await _api.post(
      '/guard/domestic-help/check-in',
      body: {'assignmentId': assignmentId},
    );
  }

  Future<void> checkOutHelper(String assignmentId) async {
    await _api.post(
      '/guard/domestic-help/check-out',
      body: {'assignmentId': assignmentId},
    );
  }

  /// Verified domestic workers on today's roster.
  Future<List<ExpectedHelper>> expectedHelpers() async {
    final data = await _api.get('/guard/domestic-help/expected');
    return asMapList(data).map(ExpectedHelper.fromJson).toList(growable: false);
  }

  Future<void> reportUnauthorizedHelper({
    required String name,
    String? flatId,
    String? note,
  }) async {
    await _api.post(
      '/guard/domestic-help/unauthorized-report',
      body: {
        'name': name,
        if (flatId != null && flatId.isNotEmpty) 'flatId': flatId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  // ---------------------------------------------------------------- alerts

  Future<List<EmergencyAlert>> activeAlerts() async {
    final data = await _api.get('/guard/alerts');
    return asMapList(data).map(EmergencyAlert.fromJson).toList(growable: false);
  }

  /// Raise an emergency alert (fire, medical, security).
  Future<EmergencyAlert> raiseAlert({
    required String type,
    String? location,
    String? message,
  }) async {
    final data = await _api.post(
      '/guard/alerts',
      body: {
        'type': type,
        if (location != null && location.isNotEmpty) 'location': location,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return EmergencyAlert.fromJson(reqMap(data, field: 'alert'));
  }

  /// Acknowledge or resolve an alert.
  Future<void> updateAlert(
    String id, {
    required String status,
    String? note,
  }) async {
    await _api.patch(
      '/guard/alerts/$id',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  // ------------------------------------------------------------- incidents

  Future<Incident> reportIncident({
    required String type,
    String? description,
    String? location,
  }) async {
    final data = await _api.post(
      '/guard/incidents',
      body: {
        'type': type,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );
    return Incident.fromJson(reqMap(data, field: 'incident'));
  }

  // -------------------------------------------------------- emergency contacts

  Future<List<EmergencyContact>> emergencyContacts() async {
    final data = await _api.get('/guard/emergency-contacts');
    return asMapList(
      data,
    ).map(EmergencyContact.fromJson).toList(growable: false);
  }

  // ------------------------------------------------------------ lost & found

  Future<List<Map<String, dynamic>>> lostAndFound({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/guard/lost-found',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return asMapList(data);
  }
}
