import 'dart:async';

import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/resident.dart';
import '../../models/society.dart';
import '../api_client.dart';

/// Resident API client.
///
/// One method group per backend section. Every method maps 1:1 to a route in
/// `backend/src/docs/routes-summary.json`, so adding a screen is a matter of
/// calling the matching method rather than guessing a URL.
///
/// Paginated methods return [PageResult<T>] so callers can implement load-more
/// without knowing about the backend's `{ data, meta }` envelope.
class ResidentApi {
  ResidentApi(this._api);
  final ApiClient _api;

  // ------------------------------------------------------ profile & membership

  Future<Map<String, dynamic>> profile() async {
    final data = await _api.get('/user/profile');
    return reqMap(data, field: 'profile');
  }

  /// Updates the resident's own profile. `body` is passed through so the caller
  /// decides which fields change; the backend validates.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final data = await _api.patch('/user/profile', body: body);
    return reqMap(data, field: 'profile');
  }

  /// Replaces the whole notification-preference map.
  Future<void> saveNotificationPreferences(Map<String, bool> prefs) async {
    await _api.put('/user/notification-preferences', body: prefs);
  }

  Future<List<SocietyRequest>> societyRequests() async {
    final data = await _api.get('/user/society-requests');
    return asMapList(data).map(SocietyRequest.fromJson).toList(growable: false);
  }

  /// Flats that belong to a society, so a resident can pick the right unit
  /// when applying. The backend requires the flat's id (flatId), not a free-
  /// text label, so this must come from the server.
  Future<List<Flat>> societyFlats(String societyId) async {
    final data = await _api.get('/auth/societies/$societyId/flats');
    return asMapList(data).map(Flat.fromJson).toList(growable: false);
  }

  /// Ask to join a society for a flat. The backend validates the flat belongs
  /// to that society and creates a PENDING request.
  ///
  /// [flatId] must be a real flat id from the server ([societyFlats]);
  /// [residentType] is one of OWNER | TENANT | FAMILY_MEMBER |
  /// AUTHORIZED_OCCUPANT (backend `ResidentType`).
  Future<SocietyRequest> requestMembership({
    required String societyId,
    required String flatId,
    required String residentType,
    String? note,
  }) async {
    final data = await _api.post(
      '/user/society-requests',
      body: {
        'societyId': societyId,
        'flatId': flatId,
        'residentType': residentType,
        'documents': <dynamic>[],
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return SocietyRequest.fromJson(reqMap(data, field: 'request'));
  }

  Future<void> attachVerificationDoc(String requestId, String fileId) async {
    await _api.post(
      '/user/society-requests/$requestId/documents',
      body: {'fileId': fileId},
    );
  }

  Future<void> cancelSocietyRequest(String requestId) async {
    await _api.delete('/user/society-requests/$requestId');
  }

  Future<List<FamilyMember>> family() async {
    final data = await _api.get('/user/family');
    return asMapList(data).map(FamilyMember.fromJson).toList(growable: false);
  }

  Future<FamilyMember> addFamilyMember(Map<String, dynamic> body) async {
    final data = await _api.post('/user/family', body: body);
    return FamilyMember.fromJson(reqMap(data, field: 'member'));
  }

  Future<FamilyMember> updateFamilyMember(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.patch('/user/family/$id', body: body);
    return FamilyMember.fromJson(reqMap(data, field: 'member'));
  }

  Future<void> deleteFamilyMember(String id) async {
    await _api.delete('/user/family/$id');
  }

  Future<List<MoveRequest>> moveRequests() async {
    final data = await _api.get('/user/move-requests');
    return asMapList(data).map(MoveRequest.fromJson).toList(growable: false);
  }

  Future<MoveRequest> createMoveRequest({
    required String type,
    required DateTime date,
    String? flatId,
    String? reason,
  }) async {
    final data = await _api.post(
      '/user/move-requests',
      body: {
        'type': type,
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (flatId != null && flatId.isNotEmpty) 'flatId': flatId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return MoveRequest.fromJson(reqMap(data, field: 'request'));
  }

  Future<void> withdrawMoveRequest(String id) async {
    await _api.post('/user/move-requests/$id/withdraw');
  }

  // ----------------------------------------------------------- notices

  Future<PageResult<Notice>> notices({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final data = await _api.get(
      '/user/notices',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Notice.fromJson);
  }

  Future<Notice> notice(String id) async {
    final data = await _api.get('/user/notices/$id');
    return Notice.fromJson(reqMap(data, field: 'notice'));
  }

  // ----------------------------------------------------------- directory

  Future<PageResult<DirectoryEntry>> directory({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final data = await _api.get(
      '/user/directory',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, DirectoryEntry.fromJson);
  }

  // ----------------------------------------------------------- invoices & payments

  Future<PageResult<Invoice>> invoices({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/user/invoices',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Invoice.fromJson);
  }

  Future<InvoiceSummary> invoiceSummary() async {
    final data = await _api.get('/user/invoices/summary');
    return InvoiceSummary.fromJson(reqMap(data, field: 'summary'));
  }

  Future<Invoice> invoice(String id) async {
    final data = await _api.get('/user/invoices/$id');
    return Invoice.fromJson(reqMap(data, field: 'invoice'));
  }

  /// Start a payment for an invoice. Returns the gateway payload, which the UI
  /// hands to [verifyPayment].
  Future<PaymentStart> payInvoice(String invoiceId) async {
    final data = await _api.post('/user/invoices/$invoiceId/pay');
    return PaymentStart.fromJson(reqMap(data, field: 'payment'));
  }

  /// Settle a gateway payment. In development the mock gateway returns a
  /// `devHint` with the payment id and signature to submit here.
  Future<Map<String, dynamic>> verifyPayment(
    String paymentId, {
    String? gatewayPaymentId,
    String? signature,
  }) async {
    final data = await _api.post(
      '/user/payments/$paymentId/verify',
      body: {
        if (gatewayPaymentId != null) 'paymentId': gatewayPaymentId,
        if (signature != null) 'signature': signature,
      },
    );
    return reqMap(data, field: 'payment');
  }

  Future<PageResult<PaymentReceipt>> payments({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/payments',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, PaymentReceipt.fromJson);
  }

  /// The receipt for a payment, ready to display or share.
  /// The receipt for an invoice's most recent settled payment.
  Future<Map<String, dynamic>> receiptById(String invoiceId) async {
    final data = await _api.get('/user/invoices/$invoiceId/receipt');
    return reqMap(data, field: 'receipt');
  }

  Future<Map<String, dynamic>> receipt(String paymentId) async {
    final data = await _api.get('/user/payments/$paymentId/receipt');
    return reqMap(data, field: 'receipt');
  }

  // ----------------------------------------------------------- amenities

  Future<List<Amenity>> amenities() async {
    final data = await _api.get('/user/amenities');
    return asMapList(data).map(Amenity.fromJson).toList(growable: false);
  }

  Future<PageResult<Booking>> bookings({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/user/amenities/bookings',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Booking.fromJson);
  }

  Future<List<Slot>> slots(String amenityId, DateTime date) async {
    final data = await _api.get(
      '/user/amenities/$amenityId/slots',
      query: {'date': date.toIso8601String().substring(0, 10)},
    );
    return asMapList(data).map(Slot.fromJson).toList(growable: false);
  }

  Future<Booking> book({
    required String amenityId,
    required String slotId,
    DateTime? date,
  }) async {
    final data = await _api.post(
      '/user/amenities/$amenityId/bookings',
      body: {
        'slotId': slotId,
        if (date != null) 'date': date.toIso8601String().substring(0, 10),
      },
    );
    return Booking.fromJson(reqMap(data, field: 'booking'));
  }

  Future<void> cancelBooking(String bookingId) async {
    await _api.post('/user/amenities/bookings/$bookingId/cancel');
  }

  // ----------------------------------------------------------- helpdesk

  Future<PageResult<Complaint>> complaints({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final data = await _api.get(
      '/user/complaints',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Complaint.fromJson);
  }

  Future<Complaint> complaint(String id) async {
    final data = await _api.get('/user/complaints/$id');
    return Complaint.fromJson(reqMap(data, field: 'complaint'));
  }

  /// The thread on a complaint.
  ///
  /// There is no `GET /complaints/:id/comments` route: comments come back
  /// inside the complaint payload (`complaint.comments`), which is also what
  /// the detail screen already fetches for the rest of the ticket.
  Future<List<ComplaintComment>> complaintComments(String id) async {
    final data = await _api.get('/user/complaints/$id');
    final complaint = reqMap(data, field: 'complaint');
    return asMapList(
      complaint['comments'] ?? const [],
    ).map(ComplaintComment.fromJson).toList(growable: false);
  }

  /// Raise a complaint. `fileIds` are ids returned by the files upload.
  Future<Complaint> raiseComplaint({
    required String category,
    required String subject,
    required String description,
    String priority = 'MEDIUM',
    List<String> fileIds = const [],
  }) async {
    final data = await _api.post(
      '/user/complaints',
      body: {
        'category': category,
        'subject': subject,
        'description': description,
        'priority': priority,
        if (fileIds.isNotEmpty) 'fileIds': fileIds,
      },
    );
    return Complaint.fromJson(reqMap(data, field: 'complaint'));
  }

  Future<void> commentOnComplaint(String id, String body) async {
    // The endpoint expects `message`; sending `body` fails schema validation.
    await _api.post('/user/complaints/$id/comments', body: {'message': body});
  }

  Future<void> rateComplaint(
    String id, {
    required int rating,
    String? feedback,
  }) async {
    await _api.post(
      '/user/complaints/$id/rate',
      body: {
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      },
    );
  }

  Future<void> reopenComplaint(String id, {String? reason}) async {
    await _api.post(
      '/user/complaints/$id/reopen',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  // ----------------------------------------------------------- visitors

  Future<PageResult<VisitorInvitation>> invitations({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/visitors/invitations',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, VisitorInvitation.fromJson);
  }

  Future<VisitorInvitation> createInvitation({
    required String name,
    String? phone,
    DateTime? validFrom,
    DateTime? validTo,
    String? purpose,
    int? maxUses,
  }) async {
    final data = await _api.post(
      '/user/visitors/invitations',
      body: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (validFrom != null) 'validFrom': validFrom.toIso8601String(),
        if (validTo != null) 'validTo': validTo.toIso8601String(),
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (maxUses != null) 'maxUses': maxUses,
      },
    );
    return VisitorInvitation.fromJson(reqMap(data, field: 'invitation'));
  }

  Future<void> cancelInvitation(String id) async {
    await _api.delete('/user/visitors/invitations/$id');
  }

  Future<PageResult<Visitor>> visitorHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/visitors',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Visitor.fromJson);
  }

  Future<List<Visitor>> pendingVisitors() async {
    final data = await _api.get('/user/visitors/pending');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  /// Pending approvals, same endpoint as [pendingVisitors]: the gate's list is
  /// short enough that the backend does not paginate it.
  Future<List<Visitor>> pendingVisitorApprovals() => pendingVisitors();

  /// Approve or reject a visitor at the gate.
  Future<void> respondToVisitor(
    String id, {
    required bool approve,
    String? reason,
  }) async {
    await _api.post(
      '/user/visitors/$id/respond',
      body: {
        'decision': approve ? 'APPROVED' : 'REJECTED',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<PageResult<Delivery>> deliveries({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/deliveries',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Delivery.fromJson);
  }

  /// Approve, reject, or accept a delivery to be left at the gate.
  Future<void> respondToDelivery(String id, {required String decision}) async {
    await _api.post(
      '/user/deliveries/$id/respond',
      body: {'decision': decision},
    );
  }

  /// Standing delivery preferences: leave-at-gate and auto-approve.
  Future<void> saveDeliveryPreferences({
    bool? leaveAtGate,
    bool? autoApprove,
  }) async {
    await _api.put(
      '/user/deliveries/preferences',
      body: {
        if (leaveAtGate != null) 'leaveAtGate': leaveAtGate,
        if (autoApprove != null) 'autoApprove': autoApprove,
      },
    );
  }

  // ----------------------------------------------------------- community

  Future<PageResult<Post>> posts({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/user/community/posts',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Post.fromJson);
  }

  Future<PageResult<Post>> myPosts({int page = 1, int limit = 10}) async {
    final data = await _api.get(
      '/user/community/posts/mine',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Post.fromJson);
  }

  Future<Post> createPostDraft({
    required String body,
    String? title,
    List<String> fileIds = const [],
    Map<String, dynamic>? poll,
  }) async {
    final data = await _api.post(
      '/user/community/posts',
      body: {
        'body': body,
        if (title != null && title.isNotEmpty) 'title': title,
        if (fileIds.isNotEmpty) 'fileIds': fileIds,
        if (poll != null) 'poll': poll,
      },
    );
    return Post.fromJson(reqMap(data, field: 'post'));
  }

  Future<void> updatePost(String id, Map<String, dynamic> body) async {
    await _api.patch('/user/community/posts/$id', body: body);
  }

  Future<void> submitPost(String id) async {
    await _api.post('/user/community/posts/$id/submit');
  }

  Future<void> withdrawPost(String id) async {
    await _api.post('/user/community/posts/$id/withdraw');
  }

  Future<List<Map<String, dynamic>>> postComments(String postId) async {
    return asMapList(await _api.get('/user/community/posts/$postId/comments'));
  }

  Future<void> commentOnPost(String postId, String text) async {
    await _api.post(
      '/user/community/posts/$postId/comments',
      body: {'text': text},
    );
  }

  Future<void> likePost(String postId, {required bool on}) async {
    await _api.request(
      on ? 'PUT' : 'DELETE',
      '/user/community/posts/$postId/like',
    );
  }

  Future<Map<String, dynamic>> pollResults(String pollId) async {
    return reqMap(
      await _api.get('/user/community/polls/$pollId/results'),
      field: 'results',
    );
  }

  Future<void> voteInPoll(String pollId, List<String> optionIds) async {
    await _api.post(
      '/user/community/polls/$pollId/vote',
      body: {'optionIds': optionIds},
    );
  }

  // ----------------------------------------------------------- marketplace

  Future<List<Map<String, dynamic>>> marketplaceCategories() async {
    return asMapList(await _api.get('/user/marketplace/categories'));
  }

  Future<PageResult<Listing>> listings({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
  }) async {
    final data = await _api.get(
      '/user/marketplace/listings',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Listing.fromJson);
  }

  Future<PageResult<Listing>> myListings({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/user/marketplace/listings/mine',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Listing.fromJson);
  }

  Future<Listing> createListing(Map<String, dynamic> body) async {
    final data = await _api.post('/user/marketplace/listings', body: body);
    return Listing.fromJson(reqMap(data, field: 'listing'));
  }

  Future<void> updateListing(String id, Map<String, dynamic> body) async {
    await _api.patch('/user/marketplace/listings/$id', body: body);
  }

  Future<void> submitListing(String id) async {
    await _api.post('/user/marketplace/listings/$id/submit');
  }

  Future<void> withdrawListing(String id) async {
    await _api.post('/user/marketplace/listings/$id/withdraw');
  }

  Future<void> markListingSold(String id) async {
    await _api.post('/user/marketplace/listings/$id/mark-sold');
  }

  Future<void> deleteListing(String id) async {
    await _api.delete('/user/marketplace/listings/$id');
  }

  Future<void> toggleListingFavourite(String id, {required bool on}) async {
    await _api.request(
      on ? 'POST' : 'DELETE',
      '/user/marketplace/listings/$id/favourite',
    );
  }

  Future<void> reportListing(String id, {required String reason}) async {
    await _api.post(
      '/user/marketplace/listings/$id/report',
      body: {'reason': reason},
    );
  }

  // ----------------------------------------------------------- property

  Future<PageResult<PropertyListing>> propertyListings({
    int page = 1,
    int limit = 20,
    String? purpose,
    String? search,
  }) async {
    final data = await _api.get(
      '/user/property/listings',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, PropertyListing.fromJson);
  }

  Future<PageResult<PropertyListing>> myPropertyListings({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/property/listings/mine',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, PropertyListing.fromJson);
  }

  Future<PageResult<PropertyInquiry>> inquiriesReceived({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/property/inquiries/received',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, PropertyInquiry.fromJson);
  }

  /// Register interest in a listing. The owner sees it under
  /// "inquiries received"; the resident gets an entry under
  /// "my inquiries".
  Future<PropertyInquiry> inquireProperty(
    String listingId, {
    String? message,
    String? phone,
  }) async {
    final data = await _api.post(
      '/user/property/listings/$listingId/inquiries',
      body: {
        if (message != null && message.isNotEmpty) 'message': message,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return PropertyInquiry.fromJson(asMapOrNull(data) ?? const {});
  }

  Future<PageResult<PropertyInquiry>> myInquiries({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/property/inquiries',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, PropertyInquiry.fromJson);
  }

  Future<void> updateInquiryStatus(String id, String status) async {
    await _api.patch('/user/property/inquiries/$id', body: {'status': status});
  }

  Future<PropertyListing> createPropertyListing(
    Map<String, dynamic> body,
  ) async {
    final data = await _api.post('/user/property/listings', body: body);
    return PropertyListing.fromJson(reqMap(data, field: 'listing'));
  }

  Future<void> updatePropertyListing(
    String id,
    Map<String, dynamic> body,
  ) async {
    await _api.patch('/user/property/listings/$id', body: body);
  }

  Future<void> submitPropertyListing(String id) async {
    await _api.post('/user/property/listings/$id/submit');
  }

  Future<void> withdrawPropertyListing(String id) async {
    await _api.post('/user/property/listings/$id/withdraw');
  }

  Future<void> closePropertyListing(String id) async {
    await _api.post('/user/property/listings/$id/close');
  }

  Future<void> deletePropertyListing(String id) async {
    await _api.delete('/user/property/listings/$id');
  }

  Future<void> togglePropertyFavourite(String id, {required bool on}) async {
    await _api.request(
      on ? 'POST' : 'DELETE',
      '/user/property/listings/$id/favourite',
    );
  }

  Future<void> reportPropertyListing(
    String id, {
    required String reason,
  }) async {
    await _api.post(
      '/user/property/listings/$id/report',
      body: {'reason': reason},
    );
  }

  // ----------------------------------------------------------- documents

  Future<PageResult<DocumentRecord>> documents({
    int page = 1,
    int limit = 30,
  }) async {
    final data = await _api.get(
      '/user/documents',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, DocumentRecord.fromJson);
  }

  /// Personal document upload. Body matches `personalDocBody`:
  /// `{title, description?, category, fileId}` — category is free-form from the
  /// backend enum, `PERSONAL` by default.
  Future<DocumentRecord> addDocument({
    required String title,
    required String category,
    required String fileId,
    String? notes,
  }) async {
    final data = await _api.post(
      '/user/documents',
      body: {
        'title': title,
        'category': category,
        'fileId': fileId,
        if (notes != null && notes.isNotEmpty) 'description': notes,
      },
    );
    return DocumentRecord.fromJson(reqMap(data, field: 'document'));
  }

  Future<void> updateDocument(String id, Map<String, dynamic> body) async {
    await _api.patch('/user/documents/$id', body: body);
  }

  Future<void> deleteDocument(String id) async {
    await _api.delete('/user/documents/$id');
  }

  // -------------------------------------------------------- domestic help

  /// Domestic helpers registered in this society (maids, cooks, drivers).
  ///
  /// The backend route is `/user/domestic-help` (singular, "My domestic
  /// help") — the plural form 404s. Helpers are returned as a paginated list.
  Future<List<DomesticHelper>> domesticHelpers({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final data = await _api.get(
      '/user/domestic-help',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data is List
        ? data
        : (asMapOrNull(data)?['items'] as List? ?? const <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DomesticHelper.fromJson)
        .toList(growable: false);
  }

  /// Service providers approved for this society (plumbers, electricians).
  Future<List<ServiceProvider>> serviceProviders({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    final data = await _api.get(
      '/user/service-providers',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final list = data is List
        ? data
        : (asMapOrNull(data)?['items'] as List? ?? const <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map(ServiceProvider.fromJson)
        .toList(growable: false);
  }

  Future<List<DomesticHelper>> myHelpers() async {
    final data = await _api.get('/user/domestic-help');
    return asMapList(data).map(DomesticHelper.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> helperDirectory({String? search}) async {
    return asMapList(
      await _api.get(
        '/user/domestic-help/directory',
        query: {
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> hireHelper({
    required String helperId,
    required String flatId,
    double? salary,
    String? notes,
  }) async {
    final data = await _api.post(
      '/user/domestic-help/hire',
      body: {
        'helperId': helperId,
        'flatId': flatId,
        if (salary != null) 'salary': salary,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return reqMap(data, field: 'assignment');
  }

  Future<void> releaseHelper(String assignmentId) async {
    await _api.post('/user/domestic-help/$assignmentId/release');
  }

  Future<void> markAttendance(
    String assignmentId, {
    required String status,
  }) async {
    await _api.post(
      '/user/domestic-help/$assignmentId/attendance',
      body: {
        'status': status,
        'date': DateTime.now().toIso8601String().substring(0, 10),
      },
    );
  }

  Future<void> recordHelperPayment({
    required String assignmentId,
    required String type,
    required double amount,
    String? note,
  }) async {
    await _api.post(
      '/user/domestic-help/$assignmentId/payments',
      body: {
        'type': type,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<void> rateHelper({
    required String assignmentId,
    required int rating,
    String? feedback,
  }) async {
    await _api.post(
      '/user/domestic-help/$assignmentId/rate',
      body: {
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      },
    );
  }

  Future<void> reviewProvider({
    required String providerId,
    required int rating,
    String? feedback,
  }) async {
    await _api.post(
      '/user/service-providers/$providerId/reviews',
      body: {
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      },
    );
  }

  // ----------------------------------------------------------- emergency

  Future<List<EmergencyContact>> emergencyContacts() async {
    final data = await _api.get('/user/emergency/contacts');
    return asMapList(
      data,
    ).map(EmergencyContact.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> personalContacts() async {
    return asMapList(await _api.get('/user/emergency/personal-contacts'));
  }

  Future<Map<String, dynamic>> addPersonalContact({
    required String name,
    required String phone,
    String? relation,
  }) async {
    final data = await _api.post(
      '/user/emergency/personal-contacts',
      body: {
        'name': name,
        'phone': phone,
        if (relation != null && relation.isNotEmpty) 'relation': relation,
      },
    );
    return reqMap(data, field: 'contact');
  }

  Future<void> deletePersonalContact(String id) async {
    await _api.delete('/user/emergency/personal-contacts/$id');
  }

  Future<PageResult<Incident>> incidents({int page = 1, int limit = 20}) async {
    final data = await _api.get(
      '/user/emergency/incidents',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, Incident.fromJson);
  }

  Future<Incident> reportIncident({
    required String type,
    String? description,
    String? location,
    List<String> fileIds = const [],
  }) async {
    final data = await _api.post(
      '/user/emergency/incidents',
      body: {
        'type': type,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
        if (fileIds.isNotEmpty) 'fileIds': fileIds,
      },
    );
    return Incident.fromJson(reqMap(data, field: 'incident'));
  }

  /// Trigger a panic alert. Guards and admins are alerted immediately over
  /// Socket.IO, so this is the highest-priority action in the app.
  Future<Map<String, dynamic>> raisePanic({
    String? location,
    String? message,
  }) async {
    final data = await _api.post(
      '/user/emergency/panic',
      body: {
        if (location != null && location.isNotEmpty) 'location': location,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return reqMap(data, field: 'alert');
  }

  /// Raise a society-wide alarm. The backend must fan this out to every
  /// resident of the caller's society (and guards/admins) and tag the event
  /// `scope: 'SOCIETY'`. This is deliberately a separate endpoint from
  /// [raisePanic] so a backend that has not shipped it fails loudly (404)
  /// instead of quietly alerting only security.
  Future<Map<String, dynamic>> raiseSocietyAlarm({
    String? flatLabel,
    String? message,
  }) async {
    final data = await _api.post(
      '/user/emergency/alarm',
      body: {
        if (flatLabel != null && flatLabel.isNotEmpty) 'flat': flatLabel,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return asMapOrNull(data) ?? const {};
  }

  /// Send a message to the society's security guards or admins.
  ///
  /// [audience] is `GUARDS` or `ADMIN`. Contract expected from the backend:
  /// `POST /user/emergency/staff-messages { audience, message, subject? }`.
  Future<void> sendStaffMessage({
    required String audience,
    required String message,
    String? subject,
  }) async {
    await _api.post(
      '/user/emergency/staff-messages',
      body: {
        'audience': audience,
        'message': message,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      },
    );
  }

  Future<PageResult<EmergencyAlert>> myAlerts({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/emergency/alerts',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, EmergencyAlert.fromJson);
  }

  Future<PageResult<EmergencyAlert>> alerts({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/emergency/alerts',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, EmergencyAlert.fromJson);
  }

  Future<PageResult<LostFoundItem>> lostAndFound({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/user/emergency/lost-found',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, LostFoundItem.fromJson);
  }

  // ----------------------------------------------------------- vehicles

  Future<List<Vehicle>> vehicles() async {
    final data = await _api.get('/user/vehicles');
    return asMapList(data).map(Vehicle.fromJson).toList(growable: false);
  }

  Future<Vehicle> addVehicle(Map<String, dynamic> body) async {
    final data = await _api.post('/user/vehicles', body: body);
    return Vehicle.fromJson(reqMap(data, field: 'vehicle'));
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> body) async {
    await _api.patch('/user/vehicles/$id', body: body);
  }

  Future<void> deleteVehicle(String id) async {
    await _api.delete('/user/vehicles/$id');
  }

  Future<List<ParkingSlot>> parkingSlots() async {
    final data = await _api.get('/user/parking/slots');
    return asMapList(data).map(ParkingSlot.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> parkingRequests() async {
    return asMapList(await _api.get('/user/parking/requests'));
  }

  Future<Map<String, dynamic>> requestParking({
    required String slotId,
    String? vehicleId,
  }) async {
    final data = await _api.post(
      '/user/parking/requests',
      body: {
        'slotId': slotId,
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      },
    );
    return reqMap(data, field: 'request');
  }

  Future<void> cancelParkingRequest(String id) async {
    await _api.delete('/user/parking/requests/$id');
  }

  // ----------------------------------------------------------- chat

  Future<List<Conversation>> conversations() async {
    final data = await _api.get('/user/chat/conversations');
    return asMapList(data).map(Conversation.fromJson).toList(growable: false);
  }

  /// Starts (or reopens) a direct conversation with another resident.
  ///
  /// The backend accepts `recipientUserId`, a `contextType` (DIRECT for a
  /// resident-to-resident chat) and an optional first `message`. It returns the
  /// conversation entity with participants, so the UI can open the thread.
  Future<Conversation> startConversation({
    required String recipientUserId,
    String contextType = 'DIRECT',
    String? message,
  }) async {
    final data = await _api.post(
      '/user/chat/conversations',
      body: {
        'recipientUserId': recipientUserId,
        'contextType': contextType,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    return Conversation.fromJson(asMapOrNull(data) ?? const {});
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final data = await _api.get(
      '/user/chat/conversations/$conversationId/messages',
    );
    return asMapList(data).map(ChatMessage.fromJson).toList(growable: false);
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    final data = await _api.post(
      '/user/chat/conversations/$conversationId/messages',
      // The backend message schema expects `text` (and optional `attachments`),
      // not `body`. Sending the wrong key produced a 422 and a stuck composer.
      body: {'text': body},
    );
    return ChatMessage.fromJson(asMapOrNull(data) ?? const {});
  }
}
