import 'dart:async';

import '../../models/json.dart';
import '../../models/resident.dart';
import '../api_client.dart';

/// File upload and download service.
///
/// The backend stores uploads and serves them back at `GET /files/{id}`,
/// authenticated. Two things matter for the UI:
///
/// - Uploads are multipart. [uploadFile] returns the file id, which every
///   create flow needs to attach images or documents to an entity.
/// - Downloads need the bearer token, so a plain `Image.network` will 401.
///   [fetchBytes] is used for protected images; [FileImageProvider] wraps it so
///   a widget can render an authenticated image.
class FilesApi {
  FilesApi(this._api);
  final ApiClient _api;

  /// Uploads a file and returns its id.
  ///
  /// `purpose` should be one of the backend `FilePurpose` values (PROFILE,
  /// VERIFICATION, LISTING, COMPLAINT, DOCUMENT, VISITOR, STAFF, INVOICE,
  /// OTHER) so the backend can validate the type.
  Future<String> upload({
    required List<int> bytes,
    required String fileName,
    required String purpose,
    String mimeType = 'application/octet-stream',
  }) async {
    final data = await _api.upload(
      '/files',
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      extra: {'purpose': purpose},
    );
    final map = asMap(data);
    // The endpoint returns the created file: { id, url, ... }.
    final id = asStringOrNull(map['id'] ?? at(map['file'], 'id'));
    if (id == null) {
      throw ModelParseException('file', 'upload response had no id');
    }
    return id;
  }

  /// Fetches the bytes of an uploaded file with authentication.
  Future<List<int>> fetch(String fileId) => _api.fetchBytes('/files/$fileId');
}

/// Notification inbox API.
class NotificationsApi {
  NotificationsApi(this._api);
  final ApiClient _api;

  Future<PageResult<AppNotification>> list({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final data = await _api.get(
      '/notifications',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (unreadOnly) 'unread': 'true',
      },
    );
    return PageResult.from(data, _api.lastMeta, AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final data = await _api.get('/notifications/unread-count');
    return asInt(asMap(data)['count']);
  }

  Future<void> markRead(String id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<int> markAllRead() async {
    final data = await _api.post('/notifications/read-all');
    return asInt(asMap(data)['updated']);
  }
}

/// Push-notification token API (see the push notifications phase).
///
/// The backend stores one token per device and fans out pushes to it when a
/// notification is created. The client registers the token after login and
/// removes it on logout.
class PushTokenApi {
  PushTokenApi(this._api);
  final ApiClient _api;

  /// Registers or refreshes this device's push token (idempotent upsert).
  Future<void> register({
    required String token,
    required String platform, // 'ANDROID' | 'IOS'
    String? deviceId,
    String? deviceName,
  }) async {
    await _api.post(
      '/user/push-tokens',
      body: {
        'token': token,
        'platform': platform,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        if (deviceName != null && deviceName.isNotEmpty)
          'deviceName': deviceName,
      },
    );
  }

  /// Removes a token when the user signs out or revokes notifications.
  Future<void> remove(String token) async {
    await _api.post('/user/push-tokens/remove', body: {'token': token});
  }

  /// Ops check: which transports the server has configured.
  Future<Map<String, dynamic>> health() async {
    final data = await _api.get('/user/push-tokens/health');
    return reqMap(data, field: 'pushHealth');
  }
}
