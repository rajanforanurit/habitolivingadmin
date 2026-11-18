import 'dart:async';

import '../../models/json.dart';
import '../../models/ops.dart';
import '../api_client.dart';

/// Society-operations API: helpdesk, platform monitoring, emergency alarm
/// management, community moderation reads, property info and in-app calls.
///
/// Every call is scoped to the signed-in admin's society by the backend; the
/// client never sends a society id.
class SocietyOpsApi {
  SocietyOpsApi(this._api);
  final ApiClient _api;

  static Map<String, String> _page(int page, int limit) => {
    'page': '$page',
    'limit': '$limit',
  };

  // ------------------------------------------------------- property info

  /// Floor plan, property details and hospitals. Read-only for society
  /// admins; the Super Admin owns them.
  Future<SocietyInfo> societyInfo() async {
    final data = await _api.get('/admin/society');
    return SocietyInfo.fromJson(reqMap(data, field: 'society'));
  }

  // ------------------------------------------------------------ helpdesk

  Future<PageResult<HelpdeskContact>> helpdesk({
    int page = 1,
    int limit = 50,
    String? category,
    String? search,
  }) async {
    final data = await _api.get(
      '/admin/helpdesk',
      query: {
        ..._page(page, limit),
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, HelpdeskContact.fromJson);
  }

  Future<List<CategoryCount>> helpdeskCategories() async {
    final data = await _api.get('/admin/helpdesk/categories');
    return asMapList(data).map(CategoryCount.fromJson).toList(growable: false);
  }

  Future<HelpdeskContact> createHelpdesk({
    required String name,
    required String mobile,
    required String category,
    String? alternateMobile,
    String? designation,
    String? description,
    String? availability,
    bool isVisible = true,
  }) async {
    final data = await _api.post(
      '/admin/helpdesk',
      body: _helpdeskBody(
        name: name,
        mobile: mobile,
        category: category,
        alternateMobile: alternateMobile,
        designation: designation,
        description: description,
        availability: availability,
        isVisible: isVisible,
      ),
    );
    return HelpdeskContact.fromJson(reqMap(data, field: 'contact'));
  }

  Future<void> updateHelpdesk(
    String id, {
    required String name,
    required String mobile,
    required String category,
    String? alternateMobile,
    String? designation,
    String? description,
    String? availability,
    bool isVisible = true,
  }) async {
    await _api.patch(
      '/admin/helpdesk/$id',
      body: _helpdeskBody(
        name: name,
        mobile: mobile,
        category: category,
        alternateMobile: alternateMobile,
        designation: designation,
        description: description,
        availability: availability,
        isVisible: isVisible,
      ),
    );
  }

  Future<void> setHelpdeskVisible(String id, bool visible) async {
    await _api.patch('/admin/helpdesk/$id', body: {'isVisible': visible});
  }

  Future<void> deleteHelpdesk(String id) async {
    await _api.delete('/admin/helpdesk/$id');
  }

  static Map<String, dynamic> _helpdeskBody({
    required String name,
    required String mobile,
    required String category,
    String? alternateMobile,
    String? designation,
    String? description,
    String? availability,
    required bool isVisible,
  }) {
    bool has(String? v) => v != null && v.trim().isNotEmpty;
    return {
      'name': name.trim(),
      'mobile': mobile.trim(),
      'category': category.trim(),
      if (has(alternateMobile)) 'alternateMobile': alternateMobile!.trim(),
      if (has(designation)) 'designation': designation!.trim(),
      if (has(description)) 'description': description!.trim(),
      if (has(availability)) 'availability': availability!.trim(),
      'isVisible': isVisible,
    };
  }

  // ------------------------------------------------------ platform monitor

  Future<AuthSummary> platformSummary({int days = 7}) async {
    final data = await _api.get(
      '/admin/platform/summary',
      query: {'days': '$days'},
    );
    return AuthSummary.fromJson(reqMap(data, field: 'summary'));
  }

  Future<PageResult<LoginActivity>> loginActivity({
    int page = 1,
    int limit = 20,
    bool? success,
  }) async {
    final data = await _api.get(
      '/admin/platform/login-activity',
      query: {..._page(page, limit), if (success != null) 'success': '$success'},
    );
    return PageResult.from(data, _api.lastMeta, LoginActivity.fromJson);
  }

  Future<PageResult<AuthEvent>> authEvents({
    int page = 1,
    int limit = 20,
    int? status,
  }) async {
    final data = await _api.get(
      '/admin/platform/auth-events',
      query: {..._page(page, limit), if (status != null) 'status': '$status'},
    );
    return PageResult.from(data, _api.lastMeta, AuthEvent.fromJson);
  }

  // ---------------------------------------------------------- emergency

  Future<PageResult<EmergencyAlarm>> alarms({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/security/alerts',
      query: {
        ..._page(page, limit),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, EmergencyAlarm.fromJson);
  }

  /// [status] is `ACKNOWLEDGED`, `RESOLVED` or `FALSE_ALARM`.
  Future<void> updateAlarm(String id, {required String status, String? note}) async {
    await _api.patch(
      '/admin/security/alerts/$id',
      body: {
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<PageResult<StaffMessage>> staffMessages({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/admin/security/staff-messages',
      query: _page(page, limit),
    );
    return PageResult.from(data, _api.lastMeta, StaffMessage.fromJson);
  }

  Future<List<ManagedEmergencyContact>> managedContacts() async {
    final data = await _api.get(
      '/admin/security/contacts',
      query: {'limit': '100'},
    );
    return asMapList(
      data,
    ).map(ManagedEmergencyContact.fromJson).toList(growable: false);
  }

  Future<List<CategoryCount>> contactCategories() async {
    final data = await _api.get('/admin/security/contacts/categories');
    return asMapList(data).map(CategoryCount.fromJson).toList(growable: false);
  }

  Future<void> saveContact({
    String? id,
    required String name,
    required String phone,
    required String category,
    String? notes,
    required bool visibleToResidents,
    required bool visibleToGuards,
  }) async {
    final body = {
      'name': name.trim(),
      'phone': phone.trim(),
      'category': category.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'visibleToResidents': visibleToResidents,
      'visibleToGuards': visibleToGuards,
    };
    if (id == null) {
      await _api.post('/admin/security/contacts', body: body);
    } else {
      await _api.patch('/admin/security/contacts/$id', body: body);
    }
  }

  Future<void> deleteContact(String id) async {
    await _api.delete('/admin/security/contacts/$id');
  }

  // -------------------------------------------------- community moderation

  /// Posts in a status, with the author's mobile. Use [moderationQueue] for
  /// approve / reject: those actions need the approval-request id.
  Future<PageResult<ModerationPost>> posts({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/admin/community-posts',
      query: {
        ..._page(page, limit),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, ModerationPost.fromJson);
  }

  Future<ModerationPost> post(String id) async {
    final data = await _api.get('/admin/community-posts/$id');
    return ModerationPost.fromJson(reqMap(data, field: 'post'));
  }

  // ---------------------------------------------------------------- calls

  Future<IceConfig> iceServers() async {
    final data = await _api.get('/calls/ice-servers');
    return IceConfig.fromJson(reqMap(data, field: 'ice'));
  }

  Future<List<CallContact>> callContacts({String? role, String? search}) async {
    final data = await _api.get(
      '/calls/contacts',
      query: {
        'limit': '100',
        if (role != null && role.isNotEmpty) 'role': role,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return asMapList(data).map(CallContact.fromJson).toList(growable: false);
  }

  Future<PageResult<CallRecord>> callHistory({int page = 1, int limit = 30}) async {
    final data = await _api.get('/calls/history', query: _page(page, limit));
    return PageResult.from(data, _api.lastMeta, CallRecord.fromJson);
  }

  Future<CallRecord> startCall(String calleeId) async {
    final data = await _api.post('/calls', body: {'calleeId': calleeId});
    return CallRecord.fromJson(reqMap(data, field: 'call'));
  }

  Future<CallRecord> callStatus(String id) async {
    final data = await _api.get('/calls/$id');
    return CallRecord.fromJson(reqMap(data, field: 'call'));
  }

  Future<void> acceptCall(String id) async => _api.post('/calls/$id/accept');
  Future<void> rejectCall(String id) async => _api.post('/calls/$id/reject');
  Future<void> cancelCall(String id) async => _api.post('/calls/$id/cancel');
  Future<void> endCall(String id) async => _api.post('/calls/$id/end');
}
