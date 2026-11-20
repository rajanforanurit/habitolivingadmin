import 'dart:async';

import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/resident.dart';
import '../../models/society.dart';
import '../api_client.dart';

/// Society-admin API client.
///
/// Covers the 20 `Society Admin - *` sections of the backend (~290 routes).
/// Method names follow the section: `approvals()`, `approveRequest(id)`,
/// `residents()`, `generateInvoices(...)`, and so on.
///
/// Two conventions worth knowing:
/// - Approval actions take the **approval-request id**, never the entity id.
///   The backend rejects the entity id with a 404 that looks like a permissions
///   error, which is a confusing way to lose an afternoon.
/// - Reason fields are omitted entirely when empty. The backend's Zod schemas
///   declare them as `optional()` but reject an explicit `null`.
class AdminApi {
  AdminApi(this._api);
  final ApiClient _api;

  // ------------------------------------------------------------- approvals

  Future<PageResult<ApprovalRequest>> approvals({
    int page = 1,
    int limit = 20,
    String? status,
    String? entityType,
  }) async {
    final data = await _api.get(
      '/admin/approvals',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (entityType != null && entityType.isNotEmpty)
          'entityType': entityType,
      },
    );
    return PageResult.from(data, _api.lastMeta, ApprovalRequest.fromJson);
  }

  Future<ApprovalRequest> approval(String id) async {
    final data = await _api.get('/admin/approvals/$id');
    return ApprovalRequest.fromJson(reqMap(data, field: 'approval'));
  }

  Future<void> startReview(String id) async {
    await _api.post('/admin/approvals/$id/start-review');
  }

  Future<void> approve(String id, {String? note}) async {
    await _api.post(
      '/admin/approvals/$id/approve',
      body: {if (note != null && note.isNotEmpty) 'note': note},
    );
  }

  Future<void> reject(String id, {String? reason}) async {
    await _api.post(
      '/admin/approvals/$id/reject',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> requestChanges(String id, {String? reason}) async {
    await _api.post(
      '/admin/approvals/$id/request-changes',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> suspend(String id, {String? reason}) async {
    await _api.post(
      '/admin/approvals/$id/suspend',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> restore(String id) async {
    await _api.post('/admin/approvals/$id/restore');
  }

  Future<void> remove(String id, {String? reason}) async {
    await _api.post(
      '/admin/approvals/$id/remove',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  // ------------------------------------------------------------- residents

  Future<PageResult<Resident>> residents({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/residents',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Resident.fromJson);
  }

  Future<Resident> resident(String id) async {
    final data = await _api.get('/admin/residents/$id');
    return Resident.fromJson(reqMap(data, field: 'resident'));
  }

  /// Assign a flat, resident type and per-resident permission overrides.
  Future<void> assignResident(
    String id, {
    String? flatId,
    String? residentType,
    Map<String, bool>? permissions,
  }) async {
    await _api.patch(
      '/admin/residents/$id',
      body: {
        if (flatId != null && flatId.isNotEmpty) 'flatId': flatId,
        if (residentType != null && residentType.isNotEmpty)
          'residentType': residentType,
        if (permissions != null) 'permissions': permissions,
      },
    );
  }

  Future<void> approveResident(String id) async {
    await _api.post('/admin/residents/$id/approve');
  }

  Future<void> rejectResident(String id, {String? reason}) async {
    await _api.post(
      '/admin/residents/$id/reject',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> activateResident(String id) async {
    await _api.post('/admin/residents/$id/activate');
  }

  /// Deactivate a resident in this society only.
  Future<void> deactivateResident(String id) async {
    await _api.post('/admin/residents/$id/deactivate');
  }

  /// Record ownership or tenancy verification for a resident.
  /// Body matches the backend schema: { ownershipVerified, documentTypes?, notes? }.
  Future<void> recordVerification({
    required String residentId,
    required bool ownershipVerified,
    List<String>? documentTypes,
    String? notes,
  }) async {
    await _api.post(
      '/admin/residents/$residentId/verification',
      body: {
        'ownershipVerified': ownershipVerified,
        if (documentTypes != null && documentTypes.isNotEmpty)
          'documentTypes': documentTypes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<PageResult<MoveRequest>> moveRequests({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/move-requests',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, MoveRequest.fromJson);
  }

  // ------------------------------------------------------------- setup

  Future<List<Tower>> towers() async {
    final data = await _api.get('/admin/towers');
    return asMapList(data).map(Tower.fromJson).toList(growable: false);
  }

  Future<Tower> createTower({
    required String name,
    int? totalFloors,
    String? blockId,
    bool? hasLift,
  }) async {
    final data = await _api.post(
      '/admin/towers',
      body: {
        'name': name,
        if (totalFloors != null) 'totalFloors': totalFloors,
        if (blockId != null && blockId.isNotEmpty) 'blockId': blockId,
        if (hasLift != null) 'hasLift': hasLift,
      },
    );
    return Tower.fromJson(reqMap(data, field: 'tower'));
  }

  Future<void> updateTower(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/towers/$id', body: body);
  }

  Future<void> deleteTower(String id) async {
    await _api.delete('/admin/towers/$id');
  }

  Future<List<Floor>> floors({String? towerId}) async {
    final data = await _api.get(
      '/admin/floors',
      query: {if (towerId != null && towerId.isNotEmpty) 'towerId': towerId},
    );
    return asMapList(data).map(Floor.fromJson).toList(growable: false);
  }

  Future<Floor> createFloor({
    required String towerId,
    required int number,
  }) async {
    final data = await _api.post(
      '/admin/floors',
      body: {'towerId': towerId, 'number': number},
    );
    return Floor.fromJson(reqMap(data, field: 'floor'));
  }

  Future<List<Flat>> flats({
    String? towerId,
    String? floorId,
    int? limit,
  }) async {
    final data = await _api.get(
      '/admin/flats',
      query: {
        if (towerId != null && towerId.isNotEmpty) 'towerId': towerId,
        if (floorId != null && floorId.isNotEmpty) 'floorId': floorId,
        if (limit != null) 'limit': '$limit',
      },
    );
    return asMapList(data).map(Flat.fromJson).toList(growable: false);
  }

  Future<Flat> createFlat({
    required String label,
    required String unitNumber,
    String? towerId,
    String? floorId,
    int? areaSqft,
  }) async {
    final data = await _api.post(
      '/admin/flats',
      body: {
        'label': label,
        'unitNumber': unitNumber,
        if (towerId != null && towerId.isNotEmpty) 'towerId': towerId,
        if (floorId != null && floorId.isNotEmpty) 'floorId': floorId,
        if (areaSqft != null) 'areaSqft': areaSqft,
      },
    );
    return Flat.fromJson(reqMap(data, field: 'flat'));
  }

  /// Create many flats at once, e.g. a floor's numbering sequence.
  /// Body matches backend schema: { towerId, fromFloor, toFloor, unitsPerFloor, ... }.
  Future<Map<String, dynamic>> bulkCreateFlats({
    required String towerId,
    required int fromFloor,
    required int toFloor,
    required int unitsPerFloor,
    String? unitType,
    double? areaSqft,
  }) async {
    final data = await _api.post(
      '/admin/flats/bulk',
      body: {
        'towerId': towerId,
        'fromFloor': fromFloor,
        'toFloor': toFloor,
        'unitsPerFloor': unitsPerFloor,
        if (unitType != null && unitType.isNotEmpty) 'unitType': unitType,
        if (areaSqft != null) 'areaSqft': areaSqft,
      },
    );
    return reqMap(data, field: 'result');
  }

  Future<Map<String, dynamic>> society() async {
    final data = await _api.get('/admin/society');
    return reqMap(data, field: 'society');
  }

  Future<void> updateSociety(Map<String, dynamic> body) async {
    await _api.patch('/admin/society', body: body);
  }

  Future<List<Gate>> gates() async {
    final data = await _api.get('/admin/gates');
    return asMapList(data).map(Gate.fromJson).toList(growable: false);
  }

  Future<Gate> createGate({
    required String name,
    String? type,
    String? location,
  }) async {
    final data = await _api.post(
      '/admin/gates',
      body: {
        'name': name,
        if (type != null && type.isNotEmpty) 'type': type,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );
    return Gate.fromJson(reqMap(data, field: 'gate'));
  }

  Future<void> deleteGate(String id) async {
    await _api.delete('/admin/gates/$id');
  }

  // ------------------------------------------------------------- roles

  Future<List<Role>> roles() async {
    final data = await _api.get('/admin/roles');
    return asMapList(data).map(Role.fromJson).toList(growable: false);
  }

  Future<Role> role(String id) async {
    final data = await _api.get('/admin/roles/$id');
    return Role.fromJson(reqMap(data, field: 'role'));
  }

  Future<Role> createRole({
    required String name,
    required String key,
    String? description,
    List<String> permissions = const [],
  }) async {
    final data = await _api.post(
      '/admin/roles',
      body: {
        'key': key,
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        'permissions': permissions,
      },
    );
    return Role.fromJson(reqMap(data, field: 'role'));
  }

  Future<void> updateRole(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/roles/$id', body: body);
  }

  Future<void> deleteRole(String id) async {
    await _api.delete('/admin/roles/$id');
  }

  /// The permission catalogue: every permission key and what it grants.
  Future<List<Map<String, dynamic>>> permissions() async {
    return asMapList(await _api.get('/admin/permissions'));
  }

  // ------------------------------------------------------------- administrators

  Future<List<AdminUser>> admins() async {
    final data = await _api.get('/admin/admins');
    return asMapList(data).map(AdminUser.fromJson).toList(growable: false);
  }

  Future<AdminUser> createAdmin({
    required String name,
    required String mobile,
    String? email,
    required String roleId,
    String? password,
    String? designation,
  }) async {
    final data = await _api.post(
      '/admin/admins',
      body: {
        'name': name,
        'mobile': mobile,
        if (email != null && email.isNotEmpty) 'email': email,
        'roleId': roleId,
        if (password != null && password.isNotEmpty) 'password': password,
        if (designation != null && designation.isNotEmpty)
          'designation': designation,
      },
    );
    return AdminUser.fromJson(reqMap(data, field: 'admin'));
  }

  Future<void> updateAdmin(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/admins/$id', body: body);
  }

  Future<void> deactivateAdmin(String id) async {
    await _api.patch('/admin/admins/$id', body: {'status': 'INACTIVE'});
  }

  /// Revoke all sessions for an admin and set a temporary password.
  /// Returns `{ temporaryPassword }` — shown once, then discarded.
  Future<Map<String, dynamic>> resetAdminAccess(String id) async {
    final data = await _api.post('/admin/admins/$id/reset-access');
    return reqMap(data, field: 'result');
  }

  // ------------------------------------------------------------- security

  Future<List<EmergencyAlert>> alerts({String? status}) async {
    final data = await _api.get(
      '/admin/security/alerts',
      query: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return asMapList(data).map(EmergencyAlert.fromJson).toList(growable: false);
  }

  Future<void> updateAlert(
    String id, {
    required String status,
    String? note,
  }) async {
    await _api.patch(
      '/admin/security/alerts/$id',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<PageResult<Incident>> incidents({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/security/incidents',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Incident.fromJson);
  }

  Future<void> updateIncident(
    String id, {
    required String status,
    String? note,
  }) async {
    await _api.patch(
      '/admin/security/incidents/$id',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<List<EmergencyContact>> emergencyContacts() async {
    final data = await _api.get('/admin/security/contacts');
    return asMapList(
      data,
    ).map(EmergencyContact.fromJson).toList(growable: false);
  }

  Future<EmergencyContact> createEmergencyContact({
    required String name,
    required String category,
    required String phone,
    bool available24x7 = false,
    String? description,
  }) async {
    final data = await _api.post(
      '/admin/security/contacts',
      body: {
        'name': name,
        'category': category,
        'phone': phone,
        'available24x7': available24x7,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return EmergencyContact.fromJson(reqMap(data, field: 'contact'));
  }

  Future<void> updateEmergencyContact(
    String id,
    Map<String, dynamic> body,
  ) async {
    await _api.patch('/admin/security/contacts/$id', body: body);
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _api.delete('/admin/security/contacts/$id');
  }

  Future<PageResult<Visitor>> visitors({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/visitors',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Visitor.fromJson);
  }

  Future<List<Visitor>> activeVisitors() async {
    final data = await _api.get('/admin/visitors/active');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  Future<PageResult<Delivery>> deliveries({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/admin/deliveries',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Delivery.fromJson);
  }

  Future<Map<String, dynamic>> flatVisitorSummary(String flatId) async {
    final data = await _api.get('/admin/flats/$flatId/visitor-summary');
    return reqMap(data, field: 'summary');
  }

  // ------------------------------------------------------------- guards

  Future<List<Guard>> guards() async {
    final data = await _api.get('/admin/guards');
    return asMapList(data).map(Guard.fromJson).toList(growable: false);
  }

  Future<Guard> createGuard({
    required String name,
    required String mobile,
    required String password,
    String? gateId,
    String? shift,
  }) async {
    final data = await _api.post(
      '/admin/guards',
      body: {
        'name': name,
        'mobile': mobile,
        'password': password,
        if (gateId != null && gateId.isNotEmpty) 'gateId': gateId,
        if (shift != null && shift.isNotEmpty) 'shift': shift,
      },
    );
    return Guard.fromJson(reqMap(data, field: 'guard'));
  }

  Future<void> updateGuard(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/guards/$id', body: body);
  }

  Future<void> deactivateGuard(String id) async {
    await _api.post('/admin/guards/$id/deactivate');
  }

  // ------------------------------------------------------------- vehicles

  Future<PageResult<SocietyVehicle>> vehicles({
    int page = 1,
    int limit = 20,
    String? type,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/vehicles',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (type != null && type.isNotEmpty) 'type': type,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, SocietyVehicle.fromJson);
  }

  Future<List<ParkingSlot>> parkingSlots({String? status}) async {
    final data = await _api.get(
      '/admin/parking/slots',
      query: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return asMapList(data).map(ParkingSlot.fromJson).toList(growable: false);
  }

  Future<ParkingSlot> createParkingSlot({
    required String label,
    String type = 'CAR',
    String? level,
  }) async {
    final data = await _api.post(
      '/admin/parking/slots',
      body: {
        'code': label,
        'type': type,
        if (level != null && level.isNotEmpty) 'level': level,
      },
    );
    return ParkingSlot.fromJson(reqMap(data, field: 'slot'));
  }

  Future<List<Map<String, dynamic>>> parkingRequests({String? status}) async {
    final data = await _api.get(
      '/admin/parking/requests',
      query: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return asMapList(data);
  }

  Future<void> respondParkingRequest(String id, {required bool approve}) async {
    await _api.post(
      '/admin/parking/requests/$id/${approve ? 'approve' : 'reject'}',
    );
  }

  // ------------------------------------------------------------- staff

  Future<PageResult<Staff>> staff({
    int page = 1,
    int limit = 20,
    String? type,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/staff',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Staff.fromJson);
  }

  Future<Staff> createStaff({
    required String name,
    required String type,
    String? phone,
    String? shift,
  }) async {
    final data = await _api.post(
      '/admin/staff',
      body: {
        'name': name,
        'type': type,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (shift != null && shift.isNotEmpty) 'shift': shift,
      },
    );
    return Staff.fromJson(reqMap(data, field: 'staff'));
  }

  Future<void> updateStaff(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/staff/$id', body: body);
  }

  Future<void> deleteStaff(String id) async {
    await _api.delete('/admin/staff/$id');
  }

  Future<PageResult<StaffTask>> tasks({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/tasks',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, StaffTask.fromJson);
  }

  Future<StaffTask> createTask({
    required String title,
    String? assigneeId,
    String? description,
    DateTime? dueDate,
    String? priority,
  }) async {
    final data = await _api.post(
      '/admin/tasks',
      body: {
        'title': title,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assigneeId': assigneeId,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
        if (priority != null && priority.isNotEmpty) 'priority': priority,
      },
    );
    return StaffTask.fromJson(reqMap(data, field: 'task'));
  }

  Future<void> updateTask(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/tasks/$id', body: body);
  }

  Future<PageResult<Asset>> assets({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/admin/assets',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Asset.fromJson);
  }

  Future<Map<String, dynamic>> lowStock() async {
    final data = await _api.get('/admin/inventory/low-stock');
    return reqMap(data, field: 'items');
  }

  Future<PageResult<Vendor>> vendors({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/admin/vendors',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Vendor.fromJson);
  }

  Future<Vendor> createVendor({
    required String name,
    required String category,
    String? contactName,
    String? phone,
    String? email,
  }) async {
    final data = await _api.post(
      '/admin/vendors',
      body: {
        'name': name,
        'category': category,
        if (contactName != null && contactName.isNotEmpty)
          'contactName': contactName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return Vendor.fromJson(reqMap(data, field: 'vendor'));
  }

  Future<void> updateVendor(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/vendors/$id', body: body);
  }

  Future<PageResult<ServiceProvider>> serviceProviders({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/admin/service-providers',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, ServiceProvider.fromJson);
  }

  // ------------------------------------------------------------- finance

  Future<PageResult<Charge>> charges({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/admin/finance/charges',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Charge.fromJson);
  }

  Future<Charge> createCharge(Map<String, dynamic> body) async {
    final data = await _api.post('/admin/finance/charges', body: body);
    return Charge.fromJson(reqMap(data, field: 'charge'));
  }

  Future<void> updateCharge(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/finance/charges/$id', body: body);
  }

  Future<void> deleteCharge(String id) async {
    await _api.delete('/admin/finance/charges/$id');
  }

  /// Generate maintenance bills for a period. Returns how many invoices were
  /// created, which the UI shows as a confirmation.
  Future<Map<String, dynamic>> generateInvoices({
    required String period,
    String? chargeId,
    List<String>? flatIds,
  }) async {
    final data = await _api.post(
      '/admin/finance/invoices/generate',
      body: {
        'period': period,
        if (chargeId != null && chargeId.isNotEmpty) 'chargeId': chargeId,
        if (flatIds != null && flatIds.isNotEmpty) 'flatIds': flatIds,
      },
    );
    return reqMap(data, field: 'result');
  }

  Future<PageResult<Invoice>> invoices({
    int page = 1,
    int limit = 20,
    String? status,
    String? period,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/finance/invoices',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (period != null && period.isNotEmpty) 'period': period,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Invoice.fromJson);
  }

  Future<Invoice> createInvoice({
    required String flatId,
    required double amount,
    required String type,
    String? period,
    DateTime? dueDate,
    String? description,
  }) async {
    // Backend adhocBody: { flatId, title, items: [{ title, amount, type? }], dueDate }.
    final due = dueDate ?? DateTime.now().add(const Duration(days: 15));
    final lineTitle = (description == null || description.trim().isEmpty)
        ? type
        : description.trim();
    final data = await _api.post(
      '/admin/finance/invoices',
      body: {
        'flatId': flatId,
        'title': lineTitle,
        'items': [
          {'title': lineTitle, 'amount': amount, 'type': type},
        ],
        'dueDate':
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
      },
    );
    return Invoice.fromJson(reqMap(data, field: 'invoice'));
  }

  /// Add a waiver (negative) or adjustment (positive) to an invoice.
  Future<void> adjustInvoice(
    String id, {
    required double amount,
    required String note,
  }) async {
    await _api.post(
      '/admin/finance/invoices/$id/adjust',
      body: {'amount': amount, 'note': note},
    );
  }

  Future<void> cancelInvoice(String id, {String? reason}) async {
    await _api.post(
      '/admin/finance/invoices/$id/cancel',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  /// Mark overdue invoices and apply late-payment penalties.
  Future<Map<String, dynamic>> applyPenalties({String? period}) async {
    final data = await _api.post(
      '/admin/finance/penalties/apply',
      body: {if (period != null && period.isNotEmpty) 'period': period},
    );
    return reqMap(data, field: 'result');
  }

  /// Record a cash, cheque or bank-transfer payment against an invoice.
  Future<AdminPayment> recordOfflinePayment({
    required String invoiceId,
    required String method,
    required double amount,
    DateTime? paidAt,
    String? note,
    String? reference,
  }) async {
    final data = await _api.post(
      '/admin/finance/payments/offline',
      body: {
        'invoiceId': invoiceId,
        'method': method,
        'amount': amount,
        if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
        if (note != null && note.isNotEmpty) 'note': note,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      },
    );
    return AdminPayment.fromJson(reqMap(data, field: 'payment'));
  }

  Future<PageResult<AdminPayment>> payments({
    int page = 1,
    int limit = 20,
    String? method,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/finance/payments',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (method != null && method.isNotEmpty) 'method': method,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, AdminPayment.fromJson);
  }

  Future<FinanceSummary> financeSummary({String? period}) async {
    final data = await _api.get(
      '/admin/finance/reports/summary',
      query: {if (period != null && period.isNotEmpty) 'period': period},
    );
    return FinanceSummary.fromJson(reqMap(data, field: 'summary'));
  }

  Future<PageResult<Expense>> expenses({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    final data = await _api.get(
      '/admin/finance/expenses',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    return PageResult.from(data, _api.lastMeta, Expense.fromJson);
  }

  Future<Expense> createExpense({
    required String title,
    required String category,
    required double amount,
    DateTime? spentAt,
    String? vendorId,
    String? note,
  }) async {
    final spent = spentAt ?? DateTime.now();
    final data = await _api.post(
      '/admin/finance/expenses',
      body: {
        'title': title,
        'category': category,
        'amount': amount,
        // Backend: date (dateOnly), notes, paymentStatus (default PAID), paymentMode.
        'date':
            '${spent.year}-${spent.month.toString().padLeft(2, '0')}-${spent.day.toString().padLeft(2, '0')}',
        if (vendorId != null && vendorId.isNotEmpty) 'vendorId': vendorId,
        if (note != null && note.isNotEmpty) 'notes': note,
      },
    );
    return Expense.fromJson(reqMap(data, field: 'expense'));
  }

  Future<void> updateExpense(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/finance/expenses/$id', body: body);
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('/admin/finance/expenses/$id');
  }

  // ------------------------------------------------------------- amenities

  Future<List<Amenity>> amenities() async {
    final data = await _api.get('/admin/amenities');
    return asMapList(data).map(Amenity.fromJson).toList(growable: false);
  }

  Future<Amenity> createAmenity(Map<String, dynamic> body) async {
    final data = await _api.post('/admin/amenities', body: body);
    return Amenity.fromJson(reqMap(data, field: 'amenity'));
  }

  Future<void> updateAmenity(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/amenities/$id', body: body);
  }

  Future<void> deleteAmenity(String id) async {
    await _api.delete('/admin/amenities/$id');
  }

  Future<PageResult<Booking>> amenityBookings({
    int page = 1,
    int limit = 20,
    String? status,
    String? date,
  }) async {
    final data = await _api.get(
      '/admin/amenities/bookings',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );
    return PageResult.from(data, _api.lastMeta, Booking.fromJson);
  }

  Future<void> markBooking(String id, {required String status}) async {
    await _api.post('/admin/amenities/bookings/$id/${status.toLowerCase()}');
  }

  // ------------------------------------------------------------- marketplace

  Future<List<Map<String, dynamic>>> marketplaceCategories() async {
    return asMapList(await _api.get('/admin/marketplace/categories'));
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? icon,
  }) async {
    final data = await _api.post(
      '/admin/marketplace/categories',
      body: {'name': name, if (icon != null && icon.isNotEmpty) 'icon': icon},
    );
    return reqMap(data, field: 'category');
  }

  Future<void> updateCategory(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/marketplace/categories/$id', body: body);
  }

  Future<void> deleteCategory(String id) async {
    await _api.delete('/admin/marketplace/categories/$id');
  }

  Future<PageResult<Listing>> marketplaceListings({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/marketplace/listings',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Listing.fromJson);
  }

  Future<List<Map<String, dynamic>>> listingReports({String? status}) async {
    final data = await _api.get(
      '/admin/marketplace/listings/reports',
      query: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return asMapList(data);
  }

  Future<void> removeListing(String id) async {
    await _api.delete('/admin/marketplace/listings/$id');
  }

  Future<void> resolveListingReport(
    String id, {
    required String decision,
  }) async {
    await _api.post(
      '/admin/marketplace/listings/reports/$id/resolve',
      body: {'decision': decision},
    );
  }

  // ------------------------------------------------------------- property

  Future<PageResult<PropertyListing>> propertyListings({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/property/listings',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, PropertyListing.fromJson);
  }

  Future<List<Map<String, dynamic>>> propertyReports({String? status}) async {
    final data = await _api.get(
      '/admin/property/listings/reports',
      query: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return asMapList(data);
  }

  Future<void> removePropertyListing(String id) async {
    await _api.delete('/admin/property/listings/$id');
  }

  Future<void> resolvePropertyReport(
    String id, {
    required String decision,
  }) async {
    await _api.post(
      '/admin/property/listings/reports/$id/resolve',
      body: {'decision': decision},
    );
  }

  // ------------------------------------------------------------- communication

  Future<PageResult<AdminNotice>> notices({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  }) async {
    final data = await _api.get(
      '/admin/notices',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return PageResult.from(data, _api.lastMeta, AdminNotice.fromJson);
  }

  /// Create a notice. The caller publishes it separately when ready, which lets
  /// a draft be prepared without broadcasting.
  /// Body matches noticeBody: `{title, body, type, audience:{all,towerIds,flatIds},
  /// pinned, attachments}`. `publish: true` saves as DRAFT and immediately
  /// publishes, because crudRoutes creates notices in DRAFT state.
  Future<AdminNotice> createNotice({
    required String title,
    required String body,
    String type = 'ANNOUNCEMENT',
    String? audience,
    List<String>? flatIds,
    List<String>? towerIds,
    bool publish = false,
  }) async {
    final targetAll =
        (flatIds == null || flatIds.isEmpty) &&
        (towerIds == null || towerIds.isEmpty);
    final data = await _api.post(
      '/admin/notices',
      body: {
        'title': title,
        'body': body,
        'type': type,
        'audience': {
          'all': targetAll,
          'towerIds': towerIds ?? const [],
          'flatIds': flatIds ?? const [],
        },
      },
    );
    final notice = AdminNotice.fromJson(reqMap(data, field: 'notice'));
    if (publish) {
      await publishNotice(notice.id);
      return notice;
    }
    return notice;
  }

  Future<void> publishNotice(String id) async {
    await _api.post('/admin/notices/$id/publish');
  }

  Future<void> archiveNotice(String id) async {
    await _api.post('/admin/notices/$id/archive');
  }

  Future<void> deleteNotice(String id) async {
    await _api.delete('/admin/notices/$id');
  }

  Future<List<Map<String, dynamic>>> polls({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/admin/polls',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return asMapList(data);
  }

  Future<Map<String, dynamic>> createPoll(Map<String, dynamic> body) async {
    final data = await _api.post('/admin/polls', body: body);
    return reqMap(data, field: 'poll');
  }

  Future<void> updatePoll(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/polls/$id', body: body);
  }

  Future<void> activatePoll(String id) async {
    await _api.post('/admin/polls/$id/activate');
  }

  Future<void> closePoll(String id) async {
    await _api.post('/admin/polls/$id/close');
  }

  Future<Map<String, dynamic>> pollResults(String id) async {
    final data = await _api.get('/admin/polls/$id/results');
    return reqMap(data, field: 'results');
  }

  Future<void> deletePoll(String id) async {
    await _api.delete('/admin/polls/$id');
  }

  Future<PageResult<Post>> communityPosts({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/community-posts',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Post.fromJson);
  }

  Future<void> removePost(String id, {String? reason}) async {
    await _api.post(
      '/admin/community-posts/$id/remove',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> blockUser(String userId, {String? reason}) async {
    await _api.post(
      '/admin/blocks',
      body: {
        'userId': userId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<List<Map<String, dynamic>>> blocks() async {
    return asMapList(await _api.get('/admin/blocks'));
  }

  Future<Map<String, dynamic>> createBlock({
    required String name,
    String? description,
  }) async {
    final data = await _api.post(
      '/admin/blocks',
      body: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return reqMap(data, field: 'block');
  }

  Future<void> updateBlock(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/blocks/$id', body: body);
  }

  Future<void> deleteBlock(String id) async {
    await _api.delete('/admin/blocks/$id');
  }

  // ------------------------------------------------------------- documents

  Future<List<DocumentRecord>> documents({String? scope}) async {
    final data = await _api.get(
      '/admin/documents',
      query: {if (scope != null && scope.isNotEmpty) 'scope': scope},
    );
    return asMapList(data).map(DocumentRecord.fromJson).toList(growable: false);
  }

  Future<DocumentRecord> createDocument({
    required String title,
    required String category,
    required String fileId,
    String? description,
  }) async {
    final data = await _api.post(
      '/admin/documents',
      body: {
        'title': title,
        'category': category,
        'fileId': fileId,
        'scope': 'SOCIETY',
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return DocumentRecord.fromJson(reqMap(data, field: 'document'));
  }

  Future<void> updateDocument(String id, Map<String, dynamic> body) async {
    await _api.patch('/admin/documents/$id', body: body);
  }

  Future<void> deleteDocument(String id) async {
    await _api.delete('/admin/documents/$id');
  }

  // ------------------------------------------------------------- helpdesk

  Future<PageResult<Complaint>> complaints({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    String? priority,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/complaints',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
      },
    );
    return PageResult.from(data, _api.lastMeta, Complaint.fromJson);
  }

  Future<Complaint> complaint(String id) async {
    final data = await _api.get('/admin/complaints/$id');
    return Complaint.fromJson(reqMap(data, field: 'complaint'));
  }

  Future<void> assignComplaint({
    required String id,
    required String assigneeId,
    String assigneeType = 'STAFF',
  }) async {
    await _api.post(
      '/admin/complaints/$id/assign',
      body: {'assigneeId': assigneeId, 'assigneeType': assigneeType},
    );
  }

  Future<void> updateComplaintStatus({
    required String id,
    required String status,
    String? note,
  }) async {
    await _api.post(
      '/admin/complaints/$id/status',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<void> commentOnComplaint(String id, String body) async {
    await _api.post('/admin/complaints/$id/comments', body: {'body': body});
  }

  Future<Map<String, dynamic>> complaintReportsSummary() async {
    final data = await _api.get('/admin/complaints/reports/summary');
    return reqMap(data, field: 'summary');
  }

  // ------------------------------------------------------------- support

  Future<PageResult<SupportTicket>> supportTickets({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/support-tickets',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, SupportTicket.fromJson);
  }

  /// Raise a support ticket with the platform team.
  Future<SupportTicket> raiseTicket({
    required String subject,
    required String description,
    String category = 'OTHER',
    String priority = 'MEDIUM',
  }) async {
    final data = await _api.post(
      '/admin/support-tickets',
      body: {
        'subject': subject,
        'description': description,
        'category': category,
        'priority': priority,
      },
    );
    return SupportTicket.fromJson(reqMap(data, field: 'ticket'));
  }

  /// Comment on a ticket thread.
  Future<void> replyToTicket(String id, {required String message}) async {
    await _api.post(
      '/admin/support-tickets/$id/comments',
      body: {'message': message},
    );
  }

  // ------------------------------------------------------------- reports

  Future<Map<String, dynamic>> overview() async {
    final data = await _api.get('/admin/reports/overview');
    return reqMap(data, field: 'overview');
  }

  Future<List<Map<String, dynamic>>> visitorReport({
    String? from,
    String? to,
  }) async {
    final data = await _api.get(
      '/admin/reports/visitors',
      query: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    return asMapList(data);
  }

  Future<List<AuditLog>> auditLogs({int page = 1, int limit = 50}) async {
    final data = await _api.get(
      '/admin/audit-logs',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return asMapList(data).map(AuditLog.fromJson).toList(growable: false);
  }
}
