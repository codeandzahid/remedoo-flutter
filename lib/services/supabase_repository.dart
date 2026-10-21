import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'auth_service.dart';

/// Production data layer: reads/writes the live Supabase tables that back
/// the Remedoo product (catalog + user data). The Flutter models are mapped
/// from the Supabase column names here, so the rest of the app keeps using
/// [Doctor], [Hospital], etc. unchanged.
///
/// Catalog tables are publicly readable; user tables (appointments, orders,
/// favorites, family_members, profiles) are protected by Row Level Security
/// (`auth.uid() = user_id`), so every write below automatically runs as the
/// signed-in user. All methods are best-effort: they return empty/fallback
/// values on error and never throw into the UI layer.
class SupabaseRepository {
  SupabaseRepository._();
  static final SupabaseRepository instance = SupabaseRepository._();

  bool get _ready => AuthService.instance.isInitialized;
  SupabaseClient get _db => AuthService.instance.client;

  // ---------------------------------------------------------------- catalog

  /// Only approved providers are shown to patients.
  static const _approved = 'approved';

  Future<List<Doctor>> fetchDoctors() async {
    if (!_ready) return const [];
    try {
      // hospital_id -> hospitals(name) embedded join for the display name.
      final rows = await _db
          .from('doctors')
          .select('*, hospitals(name)')
          .eq('approval_status', _approved)
          .order('is_featured', ascending: false)
          .order('rating', ascending: false)
          .limit(200);
      return rows.map(_toDoctor).toList();
    } catch (e) {
      debugPrint('fetchDoctors failed: $e');
      return const [];
    }
  }

  Doctor _toDoctor(Map<String, dynamic> r) {
    final hosp = r['hospitals'];
    final fee = (r['consultation_fee'] as num?)?.toDouble() ?? 0;
    return Doctor(
      id: '${r['id']}',
      name: '${r['name'] ?? ''}',
      specialty: '${r['specialization'] ?? 'General'}',
      hospital: hosp is Map ? '${hosp['name'] ?? ''}' : '',
      fee: fee,
      rating: (r['rating'] as num?)?.toDouble() ?? 0,
      reviews: 0,
      expYears: (r['experience_years'] as num?)?.toInt() ?? 0,
      waitMin: 15,
      distanceKm: 0,
      verified: r['approval_status'] == _approved,
      about: '${r['bio'] ?? ''}',
      upiId: r['upi_id']?.toString(),
      payInClinicEnabled: r['pay_in_clinic_enabled'] == true,
      upiEnabled: r['upi_enabled'] == true,
      consultationDuration:
          (r['consultation_duration'] as num?)?.toInt() ?? 30,
      phone: '${r['phone'] ?? ''}',
      workingHours: r['working_hours'] is Map
          ? Map<String, dynamic>.from(r['working_hours'] as Map)
          : null,
      vacationDates: r['vacation_dates'] is List
          ? (r['vacation_dates'] as List).map((e) => '$e').toList()
          : const [],
      videoConsultationEnabled:
          r['video_consultation_enabled'] == true,
    );
  }

  Future<List<Hospital>> fetchHospitals() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('hospitals')
          .select()
          .eq('approval_status', _approved)
          .order('is_featured', ascending: false)
          .order('rating', ascending: false)
          .limit(200);
      return rows.map(_toHospital).toList();
    } catch (e) {
      debugPrint('fetchHospitals failed: $e');
      return const [];
    }
  }

  Hospital _toHospital(Map<String, dynamic> r) {
    return Hospital(
      id: '${r['id']}',
      name: '${r['name'] ?? ''}',
      location: '${r['location'] ?? ''}',
      government: r['is_government'] == true,
      hasIcu: r['icu_available'] == true,
      beds: (r['total_beds'] as num?)?.toInt() ??
          (r['beds'] as num?)?.toInt() ??
          0,
      rating: (r['rating'] as num?)?.toDouble() ?? 0,
      reviews: 0,
      waitMin: 20,
      distanceKm: 0,
      verified: r['approval_status'] == _approved,
      upiId: r['upi_id']?.toString(),
      payInClinicEnabled: r['pay_in_clinic_enabled'] == true,
      upiEnabled: r['upi_enabled'] == true,
      fee: (r['consultation_fee'] as num?)?.toDouble() ?? 0,
      workingHours: r['working_hours'] is Map
          ? Map<String, dynamic>.from(r['working_hours'] as Map)
          : null,
      phone: '${r['phone'] ?? ''}',
      emergencyContact: '${r['emergency_contact'] ?? ''}',
    );
  }

  Future<List<Lab>> fetchLabs() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('labs')
          .select()
          .eq('approval_status', _approved)
          .order('is_featured', ascending: false)
          .order('rating', ascending: false)
          .limit(200);
      return rows.map(_toLab).toList();
    } catch (e) {
      debugPrint('fetchLabs failed: $e');
      return const [];
    }
  }

  Lab _toLab(Map<String, dynamic> r) {
    final services = r['services'];
    return Lab(
      id: '${r['id']}',
      name: '${r['name'] ?? ''}',
      location: '${r['location'] ?? ''}',
      testCount: services is List ? services.length : 0,
      offers: 0,
      turnaround: '24 hrs',
      rating: (r['rating'] as num?)?.toDouble() ?? 0,
      reviews: 0,
      nabl: false,
      verified: r['approval_status'] == _approved,
      distanceKm: 0,
      upiId: r['upi_id']?.toString(),
      payInClinicEnabled: r['pay_in_clinic_enabled'] == true,
      upiEnabled: r['upi_enabled'] == true,
      phone: '${r['phone'] ?? ''}',
      workingHours: r['working_hours'] is Map
          ? Map<String, dynamic>.from(r['working_hours'] as Map)
          : null,
    );
  }

  Future<List<Pharmacy>> fetchPharmacies() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('pharmacies')
          .select()
          .eq('approval_status', _approved)
          .order('is_featured', ascending: false)
          .order('rating', ascending: false)
          .limit(200);
      return rows.map(_toPharmacy).toList();
    } catch (e) {
      debugPrint('fetchPharmacies failed: $e');
      return const [];
    }
  }

  Pharmacy _toPharmacy(Map<String, dynamic> r) {
    final inv = r['inventory'];
    return Pharmacy(
      id: '${r['id']}',
      name: '${r['name'] ?? ''}',
      location: '${r['location'] ?? ''}',
      rating: (r['rating'] as num?)?.toDouble() ?? 0,
      reviews: 0,
      deliveryTime: '45 min',
      itemCount: inv is List ? inv.length : 0,
      offers: 0,
      verified: r['approval_status'] == _approved,
      distanceKm: 0,
      upiId: r['upi_id']?.toString(),
      payInClinicEnabled: r['pay_in_clinic_enabled'] == true,
      upiEnabled: r['upi_enabled'] == true,
      phone: '${r['phone'] ?? ''}',
    );
  }

  Future<List<Medicine>> fetchMedicines() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('medicines')
          .select()
          .eq('in_stock', true)
          .order('is_featured', ascending: false)
          .limit(500);
      return rows.map(_toMedicine).toList();
    } catch (e) {
      debugPrint('fetchMedicines failed: $e');
      return const [];
    }
  }

  Medicine _toMedicine(Map<String, dynamic> r) {
    final mrp = (r['price'] as num?)?.toDouble() ?? 0;
    final disc = (r['discount_percent'] as num?)?.toDouble() ?? 0;
    return Medicine(
      id: '${r['id']}',
      pharmacyId: '${r['pharmacy_id'] ?? ''}',
      name: '${r['name'] ?? ''}',
      pack: '${r['unit'] ?? 'strip'}',
      brand: '${r['brand_name'] ?? r['manufacturer'] ?? ''}',
      price: mrp * (1 - disc / 100),
      mrp: mrp,
      rxRequired: r['requires_prescription'] == true,
      category: '${r['category'] ?? 'General'}',
      imageUrl: r['image_url'] as String?,
    );
  }

  Future<List<LabTest>> fetchLabTests() async {
    if (!_ready) return const [];
    try {
      final rows = await _db.from('lab_tests').select().limit(300);
      return rows.map(_toLabTest).toList();
    } catch (e) {
      debugPrint('fetchLabTests failed: $e');
      return const [];
    }
  }

  LabTest _toLabTest(Map<String, dynamic> r) {
    final price = (r['price'] as num?)?.toDouble() ?? 0;
    final disc = (r['discount_percent'] as num?)?.toDouble() ?? 0;
    return LabTest(
      id: '${r['id']}',
      name: '${r['name'] ?? ''}',
      price: price * (1 - disc / 100),
      turnaround: '${r['turnaround_time'] ?? '6-12 hrs'}',
      category: '${r['category'] ?? ''}',
      labId: r['lab_id']?.toString(),
      sampleType: '${r['sample_type'] ?? 'Blood'}',
      requiresFasting: r['requires_fasting'] == true,
      homeCollection: r['home_collection'] != false,
      homeCollectionFee:
          (r['home_collection_fee'] as num?)?.toDouble() ?? 0,
      description: '${r['description'] ?? ''}',
    );
  }

  // ------------------------------------------------------------ appointments

  String? get _uid => AuthService.instance.currentUser?.id;

  /// Books an appointment in the production table. Returns the new row id,
  /// or null when the write failed (offline / RLS / validation).
  Future<String?> bookAppointment({
    required String serviceType, // doctor | hospital | lab | pharmacy
    String? doctorId,
    String? hospitalId,
    String? labId,
    String? pharmacyId,
    required DateTime date,
    required String timeLabel, // 'HH:MM'
    String? notes,
    String? prescriptionUrl,
    String? paymentRef,
    String? customerUpi,
    // The family member this booking is for (appointments.
    // family_member_id). It used to be dropped on the floor: the
    // patient's "Booking for" choice never reached the insert and
    // was lost on reload (form-pages audit M7).
    String? familyMemberId,
    // Canonical appointments.payment_method value ('online' |
    // 'at_clinic', schema_part_02). Used to default to the column
    // default 'at_clinic' for EVERY booking, so a patient who paid
    // online was stored as pay-at-clinic.
    String paymentMethod = 'at_clinic',
    // Department + video-consult choice (audit Patient 13:
    // appointments.department / is_video_consultation existed but
    // the booking form never wrote them).
    String? department,
    bool isVideoConsultation = false,
    // Lab collection choice (audit Patient 11): walk-in vs home
    // collection + the collection address. The columns arrive
    // with the appointments_collection_type migration; until the
    // owner applies it the insert retries without them so a lab
    // booking never fails over a missing column.
    String? collectionType,
    String? collectionAddress,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    final payload = <String, dynamic>{
      'patient_id': uid,
      'service_type': serviceType,
      'doctor_id': doctorId,
      'hospital_id': hospitalId,
      'lab_id': labId,
      'pharmacy_id': pharmacyId,
      'appointment_date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'appointment_time': timeLabel.length >= 5
          ? timeLabel.substring(0, 5)
          : timeLabel,
      'status': 'pending',
      'payment_method': paymentMethod,
      'notes': notes,
      if (familyMemberId != null && familyMemberId.isNotEmpty)
        'family_member_id': familyMemberId,
      if (department != null && department.isNotEmpty)
        'department': department,
      'is_video_consultation': isVideoConsultation,
      // So the provider panel can open the patient's uploaded
      // prescription (the column exists; it was never written).
      if (prescriptionUrl != null && prescriptionUrl.isNotEmpty)
        'prescription_url': prescriptionUrl,
      if (collectionType != null && collectionType.isNotEmpty)
        'collection_type': collectionType,
      if (collectionAddress != null && collectionAddress.isNotEmpty)
        'collection_address': collectionAddress,
    };
    try {
      final row = await _db.from('appointments').insert(payload).select('id');
      if (row.isNotEmpty) {
        final id = '${row.first['id']}';
        await _patchPaymentInfo('appointments', id,
            paymentRef: paymentRef, customerUpi: customerUpi);
        return id;
      }
      return null;
    } catch (e) {
      if (payload.containsKey('collection_type')) {
        debugPrint('bookAppointment retrying without collection '
            'fields: $e');
        payload.remove('collection_type');
        payload.remove('collection_address');
        try {
          final row =
              await _db.from('appointments').insert(payload).select('id');
          if (row.isNotEmpty) {
            final id = '${row.first['id']}';
            await _patchPaymentInfo('appointments', id,
                paymentRef: paymentRef, customerUpi: customerUpi);
            return id;
          }
        } catch (e2) {
          debugPrint('bookAppointment retry failed: $e2');
        }
        return null;
      }
      debugPrint('bookAppointment failed: $e');
      return null;
    }
  }

  /// Best-effort write of the payment reference / customer UPI onto
  /// an orders or appointments row. Kept as a separate patch so the
  /// app keeps working before the cancel_otp_refunds migration is
  /// applied — a missing column just logs and moves on.
  Future<void> _patchPaymentInfo(
    String table,
    String id, {
    String? paymentRef,
    String? customerUpi,
  }) async {
    final patch = <String, dynamic>{
      if (paymentRef != null && paymentRef.isNotEmpty)
        'payment_ref': paymentRef,
      if (customerUpi != null && customerUpi.isNotEmpty)
        'customer_upi': customerUpi,
    };
    if (patch.isEmpty) return;
    try {
      await _db.from(table).update(patch).eq('id', id);
    } catch (e) {
      debugPrint('_patchPaymentInfo($table) failed: $e');
    }
  }

  /// Records a refund state on an orders row (patient cancel sets
  /// 'requested' + refund_requested_at; the panelist sets 'refunded'
  /// with the refund UTR after paying back).
  Future<bool> updateOrderRefund({
    required String id,
    required String refundStatus,
    double? refundAmount,
    String? refundUtr,
  }) async {
    if (!_ready) return false;
    try {
      await _db.from('orders').update({
        'refund_status': refundStatus,
        if (refundAmount != null) 'refund_amount': refundAmount,
        if (refundStatus == 'requested')
          'refund_requested_at': DateTime.now().toUtc().toIso8601String(),
        if (refundStatus == 'refunded') ...{
          'refund_at': DateTime.now().toUtc().toIso8601String(),
          if (refundUtr != null && refundUtr.isNotEmpty)
            'refund_utr': refundUtr,
        },
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateOrderRefund failed: $e');
      return false;
    }
  }

  /// Same as [updateOrderRefund] for an appointments row.
  Future<bool> updateAppointmentRefund({
    required String id,
    required String refundStatus,
    double? refundAmount,
    String? refundUtr,
  }) async {
    if (!_ready) return false;
    try {
      await _db.from('appointments').update({
        'refund_status': refundStatus,
        if (refundAmount != null) 'refund_amount': refundAmount,
        if (refundStatus == 'requested')
          'refund_requested_at': DateTime.now().toUtc().toIso8601String(),
        if (refundStatus == 'refunded') ...{
          'refund_at': DateTime.now().toUtc().toIso8601String(),
          if (refundUtr != null && refundUtr.isNotEmpty)
            'refund_utr': refundUtr,
        },
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateAppointmentRefund failed: $e');
      return false;
    }
  }

  /// Panelist side: mark the refund on whichever order row carries
  /// this checkout reference (payment_ref == the session's order_id).
  Future<bool> updateOrderRefundByPaymentRef(
      String paymentRef, String refundStatus,
      {String? refundUtr}) async {
    if (!_ready || paymentRef.isEmpty) return false;
    try {
      await _db.from('orders').update({
        'refund_status': refundStatus,
        if (refundStatus == 'requested')
          'refund_requested_at': DateTime.now().toUtc().toIso8601String(),
        if (refundStatus == 'refunded') ...{
          'refund_at': DateTime.now().toUtc().toIso8601String(),
          if (refundUtr != null && refundUtr.isNotEmpty)
            'refund_utr': refundUtr,
        },
      }).eq('payment_ref', paymentRef);
      return true;
    } catch (e) {
      debugPrint('updateOrderRefundByPaymentRef failed: $e');
      return false;
    }
  }

  /// Panelist side: same join for an appointments row.
  Future<bool> updateAppointmentRefundByPaymentRef(
      String paymentRef, String refundStatus,
      {String? refundUtr}) async {
    if (!_ready || paymentRef.isEmpty) return false;
    try {
      await _db.from('appointments').update({
        'refund_status': refundStatus,
        if (refundStatus == 'requested')
          'refund_requested_at': DateTime.now().toUtc().toIso8601String(),
        if (refundStatus == 'refunded') ...{
          'refund_at': DateTime.now().toUtc().toIso8601String(),
          if (refundUtr != null && refundUtr.isNotEmpty)
            'refund_utr': refundUtr,
        },
      }).eq('payment_ref', paymentRef);
      return true;
    } catch (e) {
      debugPrint('updateAppointmentRefundByPaymentRef failed: $e');
      return false;
    }
  }

  /// Best-effort refund flag on the Remedoo Pay session whose
  /// order_id is this checkout reference. Patients have no write
  /// access to sessions (RLS), so from the patient side this usually
  /// no-ops — the order/appointment row stays the source of truth.
  Future<bool> updateSessionRefundByRef(
      String paymentRef, String refundStatus,
      {String? refundUtr}) async {
    if (!_ready || paymentRef.isEmpty) return false;
    try {
      await _db.from('remedoo_pay_sessions').update({
        'refund_status': refundStatus,
        if (refundStatus == 'requested')
          'refund_requested_at': DateTime.now().toUtc().toIso8601String(),
        if (refundStatus == 'refunded') ...{
          'refund_at': DateTime.now().toUtc().toIso8601String(),
          if (refundUtr != null && refundUtr.isNotEmpty)
            'refund_utr': refundUtr,
        },
      }).eq('order_id', paymentRef);
      return true;
    } catch (e) {
      debugPrint('updateSessionRefundByRef failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppointments() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('appointments')
          // The doctor embed also carries specialization + fee: the
          // appointments table has no fee column of its own, so the
          // receipt/details read them from the doctor's record.
          .select(
              '*, doctors(name, specialization, consultation_fee), hospitals(name), labs(name)')
          .eq('patient_id', uid)
          .order('appointment_date', ascending: false)
          .order('appointment_time', ascending: false)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchAppointments failed: $e');
      return const [];
    }
  }

  Future<bool> cancelAppointment(String id) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', id)
          .eq('patient_id', uid);
      return true;
    } catch (e) {
      debugPrint('cancelAppointment failed: $e');
      return false;
    }
  }

  /// Moves an existing appointment to a new date/time in the
  /// backend (form-pages audit M2: reschedule used to be local-only,
  /// leaving the provider with the old slot). Patient-scoped like
  /// [cancelAppointment]. Returns false when the write failed.
  Future<bool> updateAppointmentSlot(
      String id, DateTime date, String timeLabel) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from('appointments').update({
        'appointment_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'appointment_time':
            timeLabel.length >= 5 ? timeLabel.substring(0, 5) : timeLabel,
      }).eq('id', id).eq('patient_id', uid);
      return true;
    } catch (e) {
      debugPrint('updateAppointmentSlot failed: $e');
      return false;
    }
  }

  Future<bool> updateAppointmentStatus(String id, String status,
      {String? rejectionReason,
      String? consultationNotes,
      String? followUpDate}) async {
    if (!_ready) return false;
    try {
      await _db.from('appointments').update({
        'status': status,
        // Panelist destructive/complete actions carry their
        // context (audit Panelist 17: these columns existed but
        // no panel ever wrote them).
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'rejection_reason': rejectionReason,
        if (consultationNotes != null && consultationNotes.isNotEmpty)
          'consultation_notes': consultationNotes,
        if (followUpDate != null && followUpDate.isNotEmpty)
          'follow_up_date': followUpDate,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateAppointmentStatus failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTicketMessages(
      String ticketId) async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('support_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('fetchTicketMessages failed: $e');
      return const [];
    }
  }

  Future<bool> sendTicketMessage({
    required String ticketId,
    required String message,
    required String senderRole,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from('support_messages').insert({
        'ticket_id': ticketId,
        'sender_id': uid,
        'sender_role': senderRole,
        'message': message,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentName != null) 'attachment_name': attachmentName,
        if (attachmentType != null) 'attachment_type': attachmentType,
      });
      return true;
    } catch (e) {
      debugPrint('sendTicketMessage failed: $e');
      return false;
    }
  }

  /// One support ticket row by id (media settings etc.).
  Future<Map<String, dynamic>?> fetchTicketById(String id) async {
    if (!_ready) return null;
    try {
      final row =
          await _db.from('support_tickets').select().eq('id', id).single();
      return normaliseTicketRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('fetchTicketById failed: $e');
      return null;
    }
  }

  /// Upload a support-chat attachment (image/PDF) to the private
  /// storage bucket under chat/<ticketId>/ and return a 1-year
  /// signed URL, mirroring the prescription upload pattern.
  /// Returns (signedUrl, errorMessage) — exactly one of them is null.
  /// The error is surfaced so upload failures are diagnosable in-app
  /// instead of failing silently.
  Future<(String?, String?)> uploadChatMediaData(
    Uint8List bytes,
    String fileName,
    String ticketId,
  ) async {
    final uid = _uid;
    if (!_ready || uid == null) {
      return (null, 'Not signed in — please log in again.');
    }
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? 'application/pdf'
          : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      // Storage rejects keys with spaces/special characters
      // ("Invalid key") — phone photo names often contain them.
      // Keep the original name for display (attachment_name) but
      // store under a sanitized key.
      final safeName =
          fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final storagePath =
          '$uid/chat/$ticketId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _db.storage.from('prescriptions').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final url = await _db.storage
          .from('prescriptions')
          .createSignedUrl(storagePath, 365 * 24 * 60 * 60);
      return (url, null);
    } catch (e) {
      debugPrint('uploadChatMedia failed: $e');
      final msg = e is StorageException ? e.message : '$e';
      return (null, msg);
    }
  }

  /// Uploads one provider registration document to the private
  /// 'certificates' bucket (audit M5: registration used to keep
  /// only the file name/size and throw the bytes away, so the
  /// license_url / gst_url on the approved provider record could
  /// never be set). Returns the storage path, or null on failure.
  /// The bucket's policies scope objects to the uploader's own
  /// folder; admins can read them for review.
  Future<String?> uploadProviderDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_ready || _uid == null) return null;
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? 'application/pdf'
          : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      final safeName =
          fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '$_uid/registration/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _db.storage.from('certificates').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      return path;
    } catch (e) {
      debugPrint('uploadProviderDocument failed: $e');
      return null;
    }
  }

  /// Long-lived signed URL for a private-bucket object (admin
  /// document review, approved-provider license links).
  Future<String?> signedStorageUrl(String bucket, String path,
      {int expiresInSeconds = 365 * 24 * 60 * 60}) async {
    if (!_ready) return null;
    try {
      return await _db.storage
          .from(bucket)
          .createSignedUrl(path, expiresInSeconds);
    } catch (e) {
      debugPrint('signedStorageUrl failed: $e');
      return null;
    }
  }

  /// Recent messages across many tickets (newest first) — used for
  /// WhatsApp-style chat lists: last-message previews + unread counts.
  Future<List<Map<String, dynamic>>> fetchMessagesForTickets(
    List<String> ticketIds, {
    int limit = 500,
  }) async {
    if (!_ready || ticketIds.isEmpty) return const [];
    try {
      final rows = await _db
          .from('support_messages')
          .select()
          .inFilter('ticket_id', ticketIds)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('fetchMessagesForTickets failed: $e');
      return const [];
    }
  }

  /// Mark the OTHER side's messages in a ticket as read.
  /// [readerRole] 'user' reads admin messages; 'admin' reads user ones.
  Future<void> markTicketMessagesRead({
    required String ticketId,
    required String readerRole,
  }) async {
    if (!_ready) return;
    try {
      await _db
          .from('support_messages')
          .update({'is_read': true})
          .eq('ticket_id', ticketId)
          .neq('sender_role', readerRole)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('markTicketMessagesRead failed: $e');
    }
  }

  /// One user's profile — admin checks who sent a support query.
  /// Includes the user's role when one is assigned.
  Future<Map<String, dynamic>?> fetchProfileByUserId(String userId) async {
    if (!_ready) return null;
    try {
      final rows = await _db
          .from('profiles')
          .select('user_id, full_name, email, phone, created_at')
          .eq('user_id', userId)
          .limit(1);
      if (rows.isEmpty) return null;
      final profile = Map<String, dynamic>.from(rows.first);
      try {
        final roleRows = await _db
            .from('user_roles')
            .select('role')
            .eq('user_id', userId)
            .limit(1);
        if (roleRows.isNotEmpty) {
          profile['role'] = '${roleRows.first['role']}';
        }
      } catch (_) {
        // Role is decorative here; the profile still loads.
      }
      return profile;
    } catch (e) {
      debugPrint('fetchProfileByUserId failed: $e');
      return null;
    }
  }

  Future<String?> createSupportTicket({
    required String subject,
    required String category,
    required String description,
    String priority = 'medium',
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final row = await _db.from('support_tickets').insert({
        'user_id': uid,
        'subject': subject,
        'category': category,
        'description': description,
        'priority': priority,
        'status': 'open',
        'sender_type': 'patient',
      }).select('id').single();
      return '${row['id']}';
    } catch (e) {
      debugPrint('createSupportTicket failed: $e');
      return null;
    }
  }

  /// Upload prescription file to storage, returns public URL.
  /// Accepts either in-memory bytes (web) or a local file path (mobile).
  Future<String?> uploadPrescriptionData(
    Uint8List? bytes,
    String? localPath,
    String fileName,
  ) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      Uint8List data;
      if (bytes != null) {
        data = bytes;
      } else if (localPath != null) {
        data = await File(localPath).readAsBytes();
      } else {
        return null;
      }
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? 'application/pdf'
          : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      final safeName =
          fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final storagePath =
          '$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await _db.storage.from('prescriptions').uploadBinary(
            storagePath,
            data,
            fileOptions: FileOptions(contentType: contentType),
          );
      // Create signed URL (valid 1 year) since bucket is private
      final url = await _db.storage
          .from('prescriptions')
          .createSignedUrl(storagePath, 365 * 24 * 60 * 60);
      return url;
    } catch (e) {
      debugPrint('uploadPrescription failed: $e');
      return null;
    }
  }

  /// Upload prescription file to storage, returns public URL
  Future<String?> uploadPrescription(
      String localPath, String fileName) async {
    return uploadPrescriptionData(null, localPath, fileName);
  }

  /// Pharmacy-side verification of an order's uploaded prescription
  /// (orders.prescription_verified_by / _at, schema_part_04).
  Future<bool> setOrderPrescriptionVerified(String orderId) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from('orders').update({
        'prescription_verified_by': uid,
        'prescription_verified_at':
            DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('setOrderPrescriptionVerified failed: $e');
      return false;
    }
  }

  /// Doctor blocked slots from [fromIso] onwards, as seen by a
  /// patient booking (audit M14 / Panelist 5: the table had zero
  /// Dart references). Reads go through the
  /// doctor_blocked_slots_for RPC because RLS only lets the
  /// doctor read the raw rows; the RPC exposes date/times only.
  /// Until that migration is applied this returns empty and the
  /// booking flow simply offers working-hours slots.
  Future<List<Map<String, dynamic>>> fetchBlockedSlots(
      String doctorId, {String? fromIso}) async {
    if (!_ready) return const [];
    try {
      final rows = await _db.rpc('doctor_blocked_slots_for', params: {
        'p_doctor_id': doctorId,
        'p_from': fromIso,
      });
      if (rows is List) return rows.cast<Map<String, dynamic>>();
      return const [];
    } catch (e) {
      debugPrint('fetchBlockedSlots failed: $e');
      return const [];
    }
  }

  /// The signed-in doctor's own blocked slots, with reasons —
  /// the management list in the doctor panel.
  Future<List<Map<String, dynamic>>> fetchOwnBlockedSlots() async {
    if (!_ready) return const [];
    try {
      final doctor = await fetchOwnProviderRecord('doctors');
      if (doctor == null) return const [];
      final rows = await _db
          .from('doctor_blocked_slots')
          .select()
          .eq('doctor_id', doctor['id'])
          .order('blocked_date');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOwnBlockedSlots failed: $e');
      return const [];
    }
  }

  /// Adds a blocked slot for the signed-in doctor's own record.
  Future<String?> addBlockedSlot({
    required String dateIso,
    String? startTime,
    String? endTime,
    bool isFullDay = false,
    String? reason,
  }) async {
    if (!_ready) return null;
    try {
      final doctor = await fetchOwnProviderRecord('doctors');
      if (doctor == null) return null;
      final rows = await _db.from('doctor_blocked_slots').insert({
        'doctor_id': doctor['id'],
        'blocked_date': dateIso,
        'start_time': startTime,
        'end_time': endTime,
        'is_full_day': isFullDay,
        'reason': reason,
      }).select('id');
      if (rows.isNotEmpty) return '${rows.first['id']}';
      return null;
    } catch (e) {
      debugPrint('addBlockedSlot failed: $e');
      return null;
    }
  }

  Future<bool> deleteBlockedSlot(String id) async {
    if (!_ready) return false;
    try {
      await _db.from('doctor_blocked_slots').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteBlockedSlot failed: $e');
      return false;
    }
  }

  /// Creates a doctor's prescription for an appointment
  /// (prescriptions + prescription_items, schema_part_02) — the
  /// doctor panel had no creation form at all (audit M3). The
  /// doctor row and the patient come from the appointment itself,
  /// which is what the RLS insert policy checks.
  Future<String?> createPrescription({
    required String appointmentId,
    String? diagnosis,
    String? notes,
    required List<Map<String, String>> items,
  }) async {
    if (!_ready) return null;
    try {
      final doctor = await fetchOwnProviderRecord('doctors');
      if (doctor == null) return null;
      final appt = await _db
          .from('appointments')
          .select('user_id')
          .eq('id', appointmentId)
          .single();
      final patientId = '${appt['user_id'] ?? ''}';
      if (patientId.isEmpty) return null;
      final row = await _db.from('prescriptions').insert({
        'appointment_id': appointmentId,
        'doctor_id': doctor['id'],
        'patient_id': patientId,
        if (diagnosis != null && diagnosis.isNotEmpty)
          'diagnosis': diagnosis,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }).select('id');
      if (row.isEmpty) return null;
      final prescriptionId = '${row.first['id']}';
      if (items.isNotEmpty) {
        await _db.from('prescription_items').insert([
          for (var i = 0; i < items.length; i++)
            {
              'prescription_id': prescriptionId,
              'medicine_name': items[i]['medicine_name'] ?? '',
              'generic_name': items[i]['generic_name'],
              'dosage': items[i]['dosage'] ?? '',
              'frequency': items[i]['frequency'] ?? '',
              'duration': items[i]['duration'] ?? '',
              'instructions': items[i]['instructions'],
              'sort_order': i,
            },
        ]);
      }
      return prescriptionId;
    } catch (e) {
      debugPrint('createPrescription failed: $e');
      return null;
    }
  }

  /// The prescription written for one appointment, with its items,
  /// or null when none exists yet.
  Future<Map<String, dynamic>?> fetchPrescriptionForAppointment(
      String appointmentId) async {
    if (!_ready) return null;
    try {
      final rows = await _db
          .from('prescriptions')
          .select()
          .eq('appointment_id', appointmentId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final p = Map<String, dynamic>.from(rows.first as Map);
      final items = await _db
          .from('prescription_items')
          .select()
          .eq('prescription_id', '${p['id']}')
          .order('sort_order');
      p['items'] = items
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      return p;
    } catch (e) {
      debugPrint('fetchPrescriptionForAppointment failed: $e');
      return null;
    }
  }

  /// Uploads a profile photo to the public `avatars` bucket and
  /// returns its public URL (2026-10-19).
  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
      final path =
          '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      await _db.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                contentType: 'image/${safeExt == 'jpg' ? 'jpeg' : safeExt}',
                upsert: true),
          );
      return _db.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadAvatar failed: $e');
      return null;
    }
  }

  /// Permanently deletes the signed-in user's account and their rows
  /// (SECURITY DEFINER function delete_my_account, 2026-10-19).
  Future<bool> deleteMyAccount() async {
    if (!_ready || _uid == null) return false;
    try {
      await _db.rpc('delete_my_account');
      return true;
    } catch (e) {
      debugPrint('deleteMyAccount failed: $e');
      return false;
    }
  }

  /// Existing-patient lookup for admin/panel form autofill (owner
  /// order, 2026-10-21): when an admin or panelist types a complete
  /// email or mobile number in a form, the `lookup_user_for_form`
  /// RPC (supabase/migration/lookup_user_for_form.sql) returns the
  /// matching patient's form details on an exact match, or nothing.
  ///
  /// The function is SECURITY DEFINER and enforces both gates in
  /// the database: the CALLER must hold an admin/staff/provider
  /// role, and the MATCH is patient accounts only — a provider,
  /// admin or staff email/mobile returns no row, so panelist data
  /// is never offered by this feature.
  ///
  /// Fails soft: any error (offline, or the migration not applied
  /// yet) returns null and the form simply never pops up.
  Future<Map<String, dynamic>?> lookupUserForForm(String value) async {
    if (!_ready) return null;
    try {
      final rows = await _db.rpc(
        'lookup_user_for_form',
        params: {'lookup_value': value.trim()},
      );
      if (rows is List && rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
      return null;
    } catch (e) {
      debugPrint('lookupUserForForm failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserTickets() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('support_tickets')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => normaliseTicketRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('fetchUserTickets failed: $e');
      return const [];
    }
  }

  // ------------------------------------------------------------------ orders

  /// Places a pharmacy order + its items. Returns the order id or null.
  Future<String?> placeOrder({
    required String pharmacyId,
    required List<CartLine> lines,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required String address,
    required String payment, // e.g. 'cod' | 'online'
    String? notes,
    String? paymentRef,
    String? customerUpi,
    String? prescriptionUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    // Canonicalise the payment method: callers may hand us the
    // display label ('Pay Online') — the stored value must be
    // 'online' | 'cod' (form-pages audit M1: an exact 'online' test
    // here silently stored every online order as COD + pending).
    final method =
        payment.toLowerCase().contains('online') ? 'online' : 'cod';
    try {
      final order = await _db.from('orders').insert({
        'user_id': uid,
        'pharmacy_id': pharmacyId,
        'status': 'placed',
        'payment_method': method,
        // An online order is only placed after its payment session
        // succeeded, matching the local MedOrder.paymentStatus.
        'payment_status': method == 'online' ? 'paid' : 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'delivery_address': address,
        'notes': notes,
        // The uploaded prescription file (audit M3): without this
        // the pharmacy received an Rx order with nothing to check.
        if (prescriptionUrl != null && prescriptionUrl.isNotEmpty)
          'prescription_url': prescriptionUrl,
      }).select('id');
      if (order.isEmpty) return null;
      final orderId = '${order.first['id']}';
      await _patchPaymentInfo('orders', orderId,
          paymentRef: paymentRef, customerUpi: customerUpi);
      if (lines.isNotEmpty) {
        await _db.from('order_items').insert([
          for (final l in lines)
            {
              'order_id': orderId,
              'medicine_id': l.medicine.id,
              'medicine_name': l.medicine.name,
              'quantity': l.qty,
              'unit_price': l.medicine.price,
              'total_price': l.medicine.price * l.qty,
            },
        ]);
      }
      return orderId;
    } catch (e) {
      debugPrint('placeOrder failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('orders')
          .select('*, pharmacies(name), order_items(*)')
          .eq('user_id', uid)
          .order('placed_at', ascending: false)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOrders failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------- favorites

  /// Returns favorite keys like `doctor:<uuid>`.
  Future<Set<String>> fetchFavorites() async {
    final uid = _uid;
    if (!_ready || uid == null) return const {};
    try {
      final rows = await _db
          .from('favorites')
          .select('provider_type, provider_id')
          .eq('user_id', uid);
      return {
        for (final r in rows) '${r['provider_type']}:${r['provider_id']}',
      };
    } catch (e) {
      debugPrint('fetchFavorites failed: $e');
      return const {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('notifications')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('fetchNotifications failed: $e');
      return const [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    if (!_ready) return;
    try {
      await _db.from('notifications').update({'read': true}).eq('id', id);
    } catch (e) {
      debugPrint('markNotificationRead failed: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    try {
      await _db
          .from('notifications')
          .update({'read': true})
          .eq('user_id', uid)
          .eq('read', false);
    } catch (e) {
      debugPrint('markAllNotificationsRead failed: $e');
    }
  }

  /// Deletes one of the signed-in user's notifications (the
  /// "Users can delete own notifications" RLS policy permits it).
  /// A no-op for ids that are not backend rows (e.g. locally
  /// generated notification ids simply match nothing).
  Future<void> deleteNotification(String id) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    try {
      await _db
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('deleteNotification failed: $e');
    }
  }

  /// Deletes all of the signed-in user's notifications.
  Future<void> deleteAllNotifications() async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    try {
      await _db.from('notifications').delete().eq('user_id', uid);
    } catch (e) {
      debugPrint('deleteAllNotifications failed: $e');
    }
  }

  /// Send a notification to a specific user (e.g. doctor approving → patient)
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    String type = 'appointment',
  }) async {
    if (!_ready) return false;
    try {
      await _db.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'read': false,
      });
      return true;
    } catch (e) {
      debugPrint('sendNotificationToUser failed: $e');
      return false;
    }
  }

  Future<bool> addFavorite(String type, String providerId) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from('favorites').upsert({
        'user_id': uid,
        'provider_type': type,
        'provider_id': providerId,
      }, onConflict: 'user_id, provider_type, provider_id');
      return true;
    } catch (e) {
      debugPrint('addFavorite failed: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(String type, String providerId) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('provider_type', type)
          .eq('provider_id', providerId);
      return true;
    } catch (e) {
      debugPrint('removeFavorite failed: $e');
      return false;
    }
  }

  // ----------------------------------------------------------------- profile

  Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final rows =
          await _db.from('profiles').select().eq('user_id', uid).limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
      return null;
    } catch (e) {
      debugPrint('fetchProfile failed: $e');
      return null;
    }
  }

  Future<bool> saveProfile(Map<String, dynamic> fields) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from('profiles').upsert(
        {'user_id': uid, ...fields},
        onConflict: 'user_id',
      );
      return true;
    } catch (e) {
      debugPrint('saveProfile failed: $e');
      return false;
    }
  }

  // ------------------------------------------------------------------ family

  Future<List<Map<String, dynamic>>> fetchFamily() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('family_members')
          .select()
          .eq('user_id', uid)
          .order('created_at');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchFamily failed: $e');
      return const [];
    }
  }

  /// Inserts a family member; returns the new row id or null on failure.
  Future<String?> addFamilyMember(Map<String, dynamic> fields) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final rows = await _db
          .from('family_members')
          .insert({'user_id': uid, ...fields})
          .select('id');
      if (rows.isNotEmpty) return '${rows.first['id']}';
      return null;
    } catch (e) {
      debugPrint('addFamilyMember failed: $e');
      return null;
    }
  }

  Future<bool> deleteFamilyMember(String id) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db
          .from('family_members')
          .delete()
          .eq('id', id)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('deleteFamilyMember failed: $e');
      return false;
    }
  }

  /// Updates a family member row owned by the signed-in user.
  Future<bool> updateFamilyMember(
      String id, Map<String, dynamic> fields) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db
          .from('family_members')
          .update(fields)
          .eq('id', id)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('updateFamilyMember failed: $e');
      return false;
    }
  }

  // --------------------------------------------------------------- reminders

  /// Health reminders (schema_part_04): reminders used to be
  /// device-local only (audit Patient 14). These mirror the family
  /// methods so AppState can write through and reload.
  Future<List<Map<String, dynamic>>> fetchReminders() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('health_reminders')
          .select()
          .eq('user_id', uid)
          .order('reminder_date');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchReminders failed: $e');
      return const [];
    }
  }

  Future<String?> createReminder(Map<String, dynamic> fields) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final rows = await _db
          .from('health_reminders')
          .insert({'user_id': uid, ...fields})
          .select('id');
      if (rows.isNotEmpty) return '${rows.first['id']}';
      return null;
    } catch (e) {
      debugPrint('createReminder failed: $e');
      return null;
    }
  }

  Future<bool> updateReminderRow(
      String id, Map<String, dynamic> fields) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db
          .from('health_reminders')
          .update(fields)
          .eq('id', id)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('updateReminderRow failed: $e');
      return false;
    }
  }

  Future<bool> deleteReminderRow(String id) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db
          .from('health_reminders')
          .delete()
          .eq('id', id)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('deleteReminderRow failed: $e');
      return false;
    }
  }

  // ------------------------------------------------------------------ themes

  /// Fetches theme pack availability (admin-controlled). Rows carry
  /// id, name, enabled, is_primary, ordered for display. Empty on failure
  /// (the caller falls back to all built-in packs).
  Future<List<Map<String, dynamic>>> fetchThemePacks() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('theme_packs')
          .select('id, name, enabled, is_primary')
          .order('sort_order');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchThemePacks failed: $e');
      return const [];
    }
  }

  /// Admin: enable or disable a theme pack project-wide.
  /// The primary theme cannot be disabled (enforced by the database).
  Future<bool> setThemePackEnabled(String id, bool enabled) async {
    if (!_ready) return false;
    try {
      await _db.from('theme_packs').update({'enabled': enabled}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('setThemePackEnabled failed: $e');
      return false;
    }
  }

  /// Saves the user's theme choice to their profile (syncs web <-> app).
  Future<bool> saveUserTheme(String packId) {
    return saveProfile({'theme_pack': packId});
  }

  /// Realtime stream of the user's theme_pack. When the user changes the
  /// theme on the website, the app picks it up live (and vice versa).
  Stream<String?> watchUserTheme() {
    final uid = _uid;
    if (!_ready || uid == null) return const Stream.empty();
    try {
      return _db
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .limit(1)
          .map((rows) =>
              rows.isEmpty ? null : rows.first['theme_pack'] as String?);
    } catch (e) {
      debugPrint('watchUserTheme failed: $e');
      return const Stream.empty();
    }
  }

  // ================= ADMIN BACKEND =================
  // Supabase-backed methods for the admin panel. All writes require the
  // signed-in user to hold the 'admin' role (enforced by RLS policies using
  // has_role(auth.uid(), 'admin')). Best-effort: safe defaults on error.

  /// Whether the signed-in user holds the admin role.
  Future<bool> isCurrentUserAdmin() async {
    if (!_ready) return false;
    try {
      final uid = _uid;
      if (uid == null) return false;
      final rows = await _db
          .from('user_roles')
          .select('role')
          .eq('user_id', uid)
          .eq('role', 'admin')
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('isCurrentUserAdmin failed: $e');
      return false;
    }
  }

  /// The signed-in user's staff access: their assigned admin sections,
  /// or null when they are not a staff (employee admin) account.
  Future<List<String>?> fetchOwnStaffAccess() async {
    if (!_ready) return null;
    try {
      final uid = _uid;
      if (uid == null) return null;
      final roles = await _db
          .from('user_roles')
          .select('role')
          .eq('user_id', uid)
          .eq('role', 'staff')
          .limit(1);
      if (roles.isEmpty) return null;
      final perms = await _db
          .from('staff_permissions')
          .select('sections')
          .eq('user_id', uid)
          .limit(1);
      if (perms.isEmpty) return const [];
      final raw = perms.first['sections'];
      if (raw is List) return raw.map((e) => '$e').toList();
      return const [];
    } catch (e) {
      debugPrint('fetchOwnStaffAccess failed: $e');
      return null;
    }
  }

  /// All staff accounts with their profile + assigned sections
  /// (super-admin view for Admin > Team).
  Future<List<Map<String, dynamic>>> fetchStaffMembers() async {
    if (!_ready) return const [];
    try {
      final roleRows = await _db
          .from('user_roles')
          .select('user_id')
          .eq('role', 'staff');
      final out = <Map<String, dynamic>>[];
      for (final r in roleRows) {
        final uid = '${r['user_id']}';
        Map<String, dynamic> profile = {};
        try {
          final p = await _db
              .from('profiles')
              .select('full_name, email, phone, status')
              .eq('user_id', uid)
              .limit(1);
          if (p.isNotEmpty) profile = Map<String, dynamic>.from(p.first);
        } catch (_) {}
        List<String> sections = const [];
        try {
          final perms = await _db
              .from('staff_permissions')
              .select('sections')
              .eq('user_id', uid)
              .limit(1);
          if (perms.isNotEmpty && perms.first['sections'] is List) {
            sections = (perms.first['sections'] as List)
                .map((e) => '$e')
                .toList();
          }
        } catch (_) {}
        out.add({
          'user_id': uid,
          'name': profile['full_name'] ?? '',
          'email': profile['email'] ?? '',
          'phone': profile['phone'] ?? '',
          'status': profile['status'] ?? 'active',
          'sections': sections,
        });
      }
      return out;
    } catch (e) {
      debugPrint('fetchStaffMembers failed: $e');
      return const [];
    }
  }

  /// Replace a staff member's assigned sections (super admin only;
  /// enforced by RLS).
  Future<bool> updateStaffSections(
      String userId, List<String> sections) async {
    if (!_ready) return false;
    try {
      await _db.from('staff_permissions').upsert({
        'user_id': userId,
        'sections': sections,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('updateStaffSections failed: $e');
      return false;
    }
  }

  /// Call the admin-staff Edge Function (create/delete staff accounts).
  /// Returns null on success, or the error message.
  Future<String?> invokeAdminStaff(Map<String, dynamic> payload) async {
    if (!_ready) return 'Not ready.';
    try {
      final res = await _db.functions.invoke('admin-staff', body: payload);
      final data = res.data;
      if (data is Map && data['error'] != null) return '${data['error']}';
      return null;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        return '${details['error']}';
      }
      return 'Request failed (${e.status}).';
    } catch (e) {
      debugPrint('invokeAdminStaff failed: $e');
      return 'Request failed.';
    }
  }

  /// Fetch an ENTIRE table in pages (Admin > Export Data). Runs under
  /// the caller's RLS — you only export what your account may see.
  Future<List<Map<String, dynamic>>> exportTable(String table) async {
    if (!_ready) return const [];
    final out = <Map<String, dynamic>>[];
    const pageSize = 1000;
    var from = 0;
    while (true) {
      final rows = await _db
          .from(table)
          .select()
          .range(from, from + pageSize - 1);
      out.addAll(rows.map((r) => Map<String, dynamic>.from(r)));
      if (rows.length < pageSize) break;
      from += pageSize;
      if (from > 200000) break; // hard safety stop
    }
    return out;
  }

  /// App-wide config key/value store (branding, fees, emergency numbers,
  /// maintenance mode...). Returns {key: valueMap}.
  Future<Map<String, Map<String, dynamic>>> fetchAppConfig() async {
    if (!_ready) return const {};
    try {
      final rows = await _db.from('app_config').select('key, value');
      final out = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        final v = r['value'];
        out['${r['key']}'] =
            v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
      }
      return out;
    } catch (e) {
      debugPrint('fetchAppConfig failed: $e');
      return const {};
    }
  }

  /// Saves one app_config entry (admin only via RLS).
  Future<bool> saveAppConfig(String key, Map<String, dynamic> value) async {
    if (!_ready) return false;
    try {
      await _db.from('app_config').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('saveAppConfig failed: $e');
      return false;
    }
  }

  /// Save a sensitive setting to secure_settings (admin-only table).
  /// Used for Razorpay secrets — never stored in client-readable app_config.
  Future<bool> saveSecureSetting(String key, String value) async {
    if (!_ready) return false;
    try {
      await _db.from('secure_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('saveSecureSetting failed: $e');
      return false;
    }
  }

  /// Read secure settings (admin only). Returns map of key->value.
  Future<Map<String, String>> fetchSecureSettings(List<String> keys) async {
    if (!_ready) return {};
    try {
      final rows = await _db
          .from('secure_settings')
          .select('key, value')
          .inFilter('key', keys);
      return {
        for (final r in rows) '${r['key']}': '${r['value']}',
      };
    } catch (e) {
      debugPrint('fetchSecureSettings failed: $e');
      return {};
    }
  }

  /// Admin read of any catalog table (all rows, incl. non-approved).
  Future<List<Map<String, dynamic>>> adminFetchAll(String table) async {
    if (!_ready) return const [];
    try {
      final rows =
          await _db.from(table).select('*').order('name').limit(500);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('adminFetchAll($table) failed: $e');
      return const [];
    }
  }

  /// Remedoo Pay payment sessions, newest first (admin management screen).
  Future<List<Map<String, dynamic>>> fetchRemedooPaySessions(
      {int limit = 100}) async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('remedoo_pay_sessions')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchRemedooPaySessions failed: $e');
      return const [];
    }
  }

  /// Admin manual control of a Remedoo Pay session (confirm paid /
  /// cancel / re-open as pending) from the management screen.
  Future<bool> updateRemedooPaySession(
      String id, Map<String, dynamic> patch) async {
    if (!_ready) return false;
    try {
      await _db.from('remedoo_pay_sessions').update(patch).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateRemedooPaySession failed: $e');
      return false;
    }
  }

  /// Admin insert/update of a catalog row. Returns the row id.
  Future<String?> adminUpsert(
      String table, Map<String, dynamic> row) async {
    if (!_ready) return null;
    try {
      final res = await _db
          .from(table)
          .upsert(row)
          .select('id')
          .maybeSingle();
      return res == null ? null : '${res['id']}';
    } catch (e) {
      debugPrint('adminUpsert($table) failed: $e');
      return null;
    }
  }

  /// Admin delete of a catalog row.
  Future<bool> adminDelete(String table, String id) async {
    if (!_ready) return false;
    try {
      await _db.from(table).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('adminDelete($table) failed: $e');
      return false;
    }
  }

  /// Submits a provider application (onboarding). Returns the application id.
  Future<String?> submitProviderApplication(
      Map<String, dynamic> app) async {
    if (!_ready) return null;
    try {
      final res = await _db
          .from('provider_applications')
          .insert(app)
          .select('id')
          .maybeSingle();
      return res == null ? null : '${res['id']}';
    } catch (e) {
      // The details column arrives with the
      // provider_application_details migration; until the owner
      // applies it, submit without details rather than failing
      // the whole registration.
      if (app.containsKey('details')) {
        debugPrint('submitProviderApplication retrying without '
            'details: $e');
        final trimmed = Map<String, dynamic>.from(app)
          ..remove('details');
        return submitProviderApplication(trimmed);
      }
      debugPrint('submitProviderApplication failed: $e');
      return null;
    }
  }

  /// Admin list of provider applications, newest first.
  Future<List<Map<String, dynamic>>> fetchProviderApplications() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('provider_applications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchProviderApplications failed: $e');
      return const [];
    }
  }

  /// Admin approve/reject of a provider application.
  Future<bool> decideProviderApplication(String id, String status) async {
    if (!_ready) return false;
    final stamp = <String, dynamic>{
      'status': status,
      'decided_at': DateTime.now().toIso8601String(),
      // Audit trail (Admin gap 28): who decided. The column
      // arrives with provider_application_decided_by.sql — retry
      // without it until that migration is applied.
      if (_uid != null) 'decided_by': _uid,
    };
    try {
      await _db.from('provider_applications').update(stamp).eq('id', id);
      return true;
    } catch (e) {
      try {
        await _db
            .from('provider_applications')
            .update({
              'status': status,
              'decided_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
        return true;
      } catch (e2) {
        debugPrint('decideProviderApplication failed: $e2');
        return false;
      }
    }
  }

  /// Grants a role to a user. Callers must be admin (enforced by RLS).
  /// Roles are strictly separated: one user holds exactly one role, so
  /// any existing role is replaced (matches the DB unique constraint on
  /// user_roles.user_id).
  Future<bool> grantUserRole(String userId, String role) async {
    if (!_ready) return false;
    try {
      await _db.from('user_roles').delete().eq('user_id', userId);
      await _db.from('user_roles').insert({'user_id': userId, 'role': role});
      return true;
    } catch (e) {
      debugPrint('grantUserRole failed: $e');
      return false;
    }
  }

  // ============ Provider-scoped methods (Partner app) ============

  /// Returns the provider's own catalog record (doctors/pharmacies/labs/hospitals
  /// row where user_id matches), or null.
  Future<Map<String, dynamic>?> fetchOwnProviderRecord(String table) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final rows = await _db
          .from(table)
          .select()
          .eq('user_id', uid)
          .limit(1);
      if (rows.isEmpty) return null;
      return (rows.first as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('fetchOwnProviderRecord($table) failed: $e');
      return null;
    }
  }

  /// Updates the provider's own catalog record.
  Future<bool> updateOwnProviderRecord(
      String table, Map<String, dynamic> values) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from(table).update(values).eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('updateOwnProviderRecord($table) failed: $e');
      return false;
    }
  }

  /// Reviews for the signed-in provider (public read; filtered by their record).
  Future<List<Map<String, dynamic>>> fetchProviderReviews(
      String providerType, String table) async {
    if (!_ready || _uid == null) return const [];
    try {
      final me = await fetchOwnProviderRecord(table);
      final pid = me?['id'];
      if (pid == null) return const [];
      final rows = await _db
          .from('reviews')
          .select()
          .eq('provider_type', providerType)
          .eq('provider_id', '$pid')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchProviderReviews failed: $e');
      return const [];
    }
  }

  /// Appointments for the signed-in doctor (via their doctors record).
  Future<List<Map<String, dynamic>>> fetchDoctorAppointments() async {
    if (!_ready || _uid == null) return const [];
    try {
      final me = await fetchOwnProviderRecord('doctors');
      final doctorId = me?['id'];
      if (doctorId == null) return const [];
      final rows = await _db
          .from('appointments')
          .select()
          .eq('doctor_id', doctorId)
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchDoctorAppointments failed: $e');
      return const [];
    }
  }

  /// Appointments for the signed-in hospital.
  Future<List<Map<String, dynamic>>> fetchHospitalAppointments() async {
    if (!_ready || _uid == null) return const [];
    try {
      final me = await fetchOwnProviderRecord('hospitals');
      final hospitalId = me?['id'];
      if (hospitalId == null) return const [];
      final rows = await _db
          .from('appointments')
          .select()
          .eq('hospital_id', hospitalId)
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchHospitalAppointments failed: $e');
      return const [];
    }
  }

  /// Bookings for the signed-in lab.
  Future<List<Map<String, dynamic>>> fetchLabBookings() async {
    if (!_ready || _uid == null) return const [];
    try {
      final me = await fetchOwnProviderRecord('labs');
      final labId = me?['id'];
      if (labId == null) return const [];
      final rows = await _db
          .from('appointments')
          .select()
          .eq('lab_id', labId)
          .order('appointment_date', ascending: true)
          .order('appointment_time', ascending: true)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchLabBookings failed: $e');
      return const [];
    }
  }

  /// Orders for the signed-in pharmacy, with items.
  Future<List<Map<String, dynamic>>> fetchPharmacyOrders() async {
    if (!_ready || _uid == null) return const [];
    try {
      final me = await fetchOwnProviderRecord('pharmacies');
      final pharmacyId = me?['id'];
      if (pharmacyId == null) return const [];
      final rows = await _db
          .from('orders')
          .select('*, order_items(*, medicines(name))')
          .eq('pharmacy_id', pharmacyId)
          .order('placed_at', ascending: false)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchPharmacyOrders failed: $e');
      return const [];
    }
  }

  /// Pharmacy updates the status of one of their orders.
  Future<bool> updateOrderStatus(String id, String status) async {
    if (!_ready || _uid == null) return false;
    try {
      final updates = <String, dynamic>{'status': status};
      final now = DateTime.now().toIso8601String();
      if (status == 'confirmed') updates['confirmed_at'] = now;
      if (status == 'out_for_delivery') updates['out_for_delivery_at'] = now;
      if (status == 'delivered') updates['delivered_at'] = now;
      if (status == 'cancelled') updates['cancelled_at'] = now;
      await _db.from('orders').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateOrderStatus failed: $e');
      return false;
    }
  }

  /// Admin list of announcements (broadcasts), newest first.
  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('announcements')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchAnnouncements failed: $e');
      return const [];
    }
  }

  /// Admin creates an announcement (broadcast).
  Future<bool> createAnnouncement(
      String title, String message, String audience) async {
    if (!_ready) return false;
    try {
      await _db.from('announcements').insert({
        'title': title,
        'message': message,
        'audience': audience,
      });
      return true;
    } catch (e) {
      debugPrint('createAnnouncement failed: $e');
      return false;
    }
  }

  /// Admin updates an announcement (audit Admin gap 19:
  /// announcements could only be published or deleted — a typo
  /// meant delete-and-republish).
  Future<bool> updateAnnouncement(String id,
      {String? title, String? message, String? audience}) async {
    if (!_ready) return false;
    try {
      await _db.from('announcements').update({
        if (title != null) 'title': title,
        if (message != null) 'message': message,
        if (audience != null) 'audience': audience,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateAnnouncement failed: $e');
      return false;
    }
  }

  /// Admin deletes an announcement.
  Future<bool> deleteAnnouncement(String id) async {
    if (!_ready) return false;
    try {
      await _db.from('announcements').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteAnnouncement failed: $e');
      return false;
    }
  }

  /// Latest announcements for display in the app (public read).
  Future<List<Map<String, dynamic>>> fetchLatestAnnouncements() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('announcements')
          .select('title, message, created_at')
          .order('created_at', ascending: false)
          .limit(5);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchLatestAnnouncements failed: $e');
      return const [];
    }
  }

  /// Admin list of all user profiles.
  Future<List<Map<String, dynamic>>> fetchAllProfiles() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('profiles')
          .select(
              'user_id, full_name, email, phone, created_at, status, gender, date_of_birth, address, language, upi_id, avatar_url')
          .order('created_at', ascending: false)
          .limit(500);
      final profiles = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      // Attach roles
      try {
        final roleRows = await _db.from('user_roles').select('user_id, role');
        final roleMap = <String, String>{};
        for (final r in roleRows) {
          roleMap['${r['user_id']}'] = '${r['role']}';
        }
        for (final p in profiles) {
          p['role'] = roleMap['${p['user_id']}'] ?? 'user';
        }
      } catch (_) {}
      return profiles;
    } catch (e) {
      debugPrint('fetchAllProfiles failed: $e');
      return const [];
    }
  }

  /// Admin edit of a user's profile row (audit Admin gap 6:
  /// Users could only have their role changed — name, phone,
  /// status and the rest were view-only, and nobody could be
  /// suspended). profiles.status 'suspended' is the deactivation
  /// flag the admin surfaces read.
  Future<bool> adminUpdateProfile(
      String userId, Map<String, dynamic> values) async {
    if (!_ready) return false;
    try {
      await _db.from('profiles').update(values).eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('adminUpdateProfile failed: $e');
      return false;
    }
  }

  Future<bool> setUserRole(String userId, String role) async {
    if (!_ready) return false;
    try {
      // Remove existing roles, then insert the new one (one role per user)
      await _db.from('user_roles').delete().eq('user_id', userId);
      await _db.from('user_roles').insert({'user_id': userId, 'role': role});
      return true;
    } catch (e) {
      debugPrint('setUserRole failed: $e');
      return false;
    }
  }

  /// Admin list of all orders with items, newest first.
  Future<List<Map<String, dynamic>>> adminFetchOrders() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('orders')
          .select('*, order_items(*)')
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('adminFetchOrders failed: $e');
      return const [];
    }
  }

  /// Admin update of an appointment (e.g. status).
  Future<bool> adminUpdateAppointment(
      String id, Map<String, dynamic> fields) async {
    if (!_ready) return false;
    try {
      await _db.from('appointments').update(fields).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('adminUpdateAppointment failed: $e');
      return false;
    }
  }

  /// Admin update of an order (e.g. status).
  Future<bool> adminUpdateOrder(
      String id, Map<String, dynamic> fields) async {
    if (!_ready) return false;
    try {
      await _db.from('orders').update(fields).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('adminUpdateOrder failed: $e');
      return false;
    }
  }

  /// Admin list of all appointments, newest first, with the booked
  /// provider's name embedded (the FK-backed relations). Patient
  /// names cannot be embedded — appointments.patient_id has no FK to
  /// profiles — so they are resolved client-side from the profiles
  /// table and stamped onto each row as 'patient_name' (same
  /// client-join pattern as fetchAllProfiles attaching roles).
  Future<List<Map<String, dynamic>>> adminFetchAppointments() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('appointments')
          // The doctors embed carries specialization + fee as well
          // (same embed as the patient fetch): appointments has no
          // fee column of its own, and the admin detail view reads
          // specialty and fee from the doctor's record.
          .select(
              '*, doctors(name, specialization, consultation_fee), hospitals(name), labs(name), pharmacies(name)')
          .order('created_at', ascending: false)
          .limit(200);
      final list = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      try {
        final profs = await _db
            .from('profiles')
            .select('user_id, full_name, email, phone')
            .limit(500);
        final byId = <String, Map<String, dynamic>>{
          for (final p in profs) '${p['user_id']}': p,
        };
        for (final r in list) {
          final p = byId['${r['patient_id']}'];
          if (p == null) continue;
          final name = '${p['full_name'] ?? ''}'.trim();
          r['patient_name'] = name.isNotEmpty ? name : '${p['email'] ?? ''}';
          // Contact fields for the admin detail view (display-only,
          // like the name — the appointments row itself has no FK to
          // profiles to embed).
          r['patient_email'] = '${p['email'] ?? ''}';
          r['patient_phone'] = '${p['phone'] ?? ''}';
        }
      } catch (_) {
        // Names are display-only; a profiles hiccup must not empty
        // the appointments list.
      }
      return list;
    } catch (e) {
      debugPrint('adminFetchAppointments failed: $e');
      return const [];
    }
  }

  /// The stored ticket vocabulary is open|in_progress|resolved|
  /// closed (schema_part_02). An older admin build also wrote a
  /// fifth value 'opened' on first view (form-pages audit M24) —
  /// reads normalise it back to 'open' so no ticket hides from
  /// filters or counts, and nothing writes it any more.
  static Map<String, dynamic> normaliseTicketRow(Map<String, dynamic> r) {
    if ('${r['status']}' == 'opened') r['status'] = 'open';
    return r;
  }

  /// Admin list of support tickets, newest first.
  Future<List<Map<String, dynamic>>> fetchSupportTickets() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('support_tickets')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);
      return rows
          .map((r) => normaliseTicketRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('fetchSupportTickets failed: $e');
      return const [];
    }
  }

  /// Admin update of a support ticket (status, reply...).
  Future<bool> updateSupportTicket(
      String id, Map<String, dynamic> fields) async {
    if (!_ready) return false;
    try {
      await _db.from('support_tickets').update(fields).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateSupportTicket failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------- reviews

  /// Persists a patient review (form-pages audit M6: reviews used
  /// to live only in an in-memory map). Returns the new row id.
  Future<String?> submitReview({
    required String providerId,
    required String providerType,
    required int rating,
    String? comment,
    String? appointmentId,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final row = await _db.from('reviews').insert({
        'user_id': uid,
        'provider_id': providerId,
        'provider_type': providerType,
        'rating': rating,
        'comment': comment,
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointment_id': appointmentId,
      }).select('id');
      return row.isNotEmpty ? '${row.first['id']}' : null;
    } catch (e) {
      debugPrint('submitReview failed: $e');
      return null;
    }
  }

  /// Every review, newest first (admin moderation + patient reload).
  Future<List<Map<String, dynamic>>> fetchReviews({String? userId}) async {
    if (!_ready) return const [];
    try {
      var q = _db.from('reviews').select('*');
      if (userId != null) q = q.eq('user_id', userId);
      final rows = await q.order('created_at', ascending: false).limit(500);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchReviews failed: $e');
      return const [];
    }
  }

  /// Admin moderation: reviews.status is 'approved' (visible) or
  /// 'hidden' (schema_part_03 moderation columns).
  Future<bool> setReviewStatus(String id, String status) async {
    if (!_ready) return false;
    try {
      await _db.from('reviews').update({'status': status}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('setReviewStatus failed: $e');
      return false;
    }
  }

  Future<bool> setReviewAdminNotes(String id, String notes) async {
    if (!_ready) return false;
    try {
      await _db
          .from('reviews')
          .update({'admin_notes': notes}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('setReviewAdminNotes failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------- refunds

  /// Creates a refunds-table row for the signed-in patient
  /// (form-pages audit M8: nothing ever inserted into refunds, so
  /// the patient tracker and the admin queue both stayed empty for
  /// real cancel-refunds).
  Future<String?> createRefundRequest({
    String? orderId,
    String? appointmentId,
    required double amount,
    required String reason,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final row = await _db.from('refunds').insert({
        'user_id': uid,
        if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointment_id': appointmentId,
        'amount': amount,
        'reason': reason,
        'status': 'requested',
      }).select('id');
      return row.isNotEmpty ? '${row.first['id']}' : null;
    } catch (e) {
      debugPrint('createRefundRequest failed: $e');
      return null;
    }
  }

  /// The signed-in patient's own refund rows, newest first.
  Future<List<Map<String, dynamic>>> fetchMyRefunds() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('refunds')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchMyRefunds failed: $e');
      return const [];
    }
  }

  /// Admin list of refunds, newest first.
  Future<List<Map<String, dynamic>>> fetchRefunds() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('refunds')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchRefunds failed: $e');
      return const [];
    }
  }

  /// Admin update of a refund status. The stored vocabulary is the
  /// schema's requested|processing|completed|rejected — the admin
  /// screen used to write 'approved', which the schema never lists
  /// (form-pages audit M8). Completing stamps processed_at; an
  /// admin note can ride along.
  Future<bool> updateRefund(String id, String status,
      {String? adminNotes}) async {
    if (!_ready) return false;
    try {
      await _db.from('refunds').update({
        'status': status,
        'admin_notes': ?adminNotes,
        if (status == 'completed')
          'processed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateRefund failed: $e');
      return false;
    }
  }

  /// Creates an emergency_requests row for the signed-in patient
  /// (form-pages audit Patient 17: SOS used to only dial — no
  /// backend record was ever created, so the admin Emergency
  /// board and ambulance assignment never saw the request).
  /// Coordinates ride along when the device provided them.
  Future<String?> createEmergencyRequest({
    double? latitude,
    double? longitude,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final rows = await _db.from('emergency_requests').insert({
        'patient_id': uid,
        'status': 'pending',
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }).select('id');
      if (rows.isNotEmpty) return '${rows.first['id']}';
      return null;
    } catch (e) {
      debugPrint('createEmergencyRequest failed: $e');
      return null;
    }
  }

  /// Admin list of emergency requests, newest first.
  Future<List<Map<String, dynamic>>> fetchEmergencyRequests() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('emergency_requests')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchEmergencyRequests failed: $e');
      return const [];
    }
  }

  /// Admin update of an emergency request (status, assigned ambulance...).
  Future<bool> updateEmergencyRequest(
      String id, Map<String, dynamic> fields) async {
    if (!_ready) return false;
    try {
      await _db.from('emergency_requests').update(fields).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateEmergencyRequest failed: $e');
      return false;
    }
  }

  /// Admin list of ambulances.
  Future<List<Map<String, dynamic>>> fetchAmbulances() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('ambulances')
          .select('*')
          .order('vehicle_number')
          .limit(100);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('fetchAmbulances failed: $e');
      return const [];
    }
  }

  /// Admin update of an ambulance (status, driver...).
  Future<bool> updateAmbulance(
      String id, Map<String, dynamic> fields) async {
    if (!_ready) return false;
    try {
      await _db.from('ambulances').update(fields).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateAmbulance failed: $e');
      return false;
    }
  }

  /// Admin update of a provider's payment settings (UPI ID, toggles).
  /// [table] is one of doctors/hospitals/labs/pharmacies.
  Future<bool> updateProviderPayment(String table, String id,
      {String? upiId, bool? upiEnabled, bool? payInClinicEnabled}) async {
    if (!_ready) return false;
    try {
      final fields = <String, dynamic>{};
      if (upiId != null) fields['upi_id'] = upiId;
      if (upiEnabled != null) fields['upi_enabled'] = upiEnabled;
      if (payInClinicEnabled != null) {
        fields['pay_in_clinic_enabled'] = payInClinicEnabled;
      }
      if (fields.isEmpty) return true;
      await _db.from(table).update(fields).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateProviderPayment failed: $e');
      return false;
    }
  }

  /// Sets the UPI ID on the provider record(s) linked to [userId].
  /// The caller loops the provider tables; returns true if no exception.
  Future<bool> setProviderUpiOnRecord(
      String table, String userId, String upiId,
      {String? payeeName, bool enable = false}) async {
    if (!_ready) return false;
    try {
      await _db.from(table).update({
        'upi_id': upiId,
        // The UPI setup dialog promises "patients can now pay
        // you" (audit Panelist 19) — that is only true when the
        // record's UPI toggle is actually switched on and the
        // payee name is stored alongside the ID.
        if (enable) 'upi_enabled': true,
        if (payeeName != null && payeeName.isNotEmpty)
          'upi_payee_name': payeeName,
      }).eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('setProviderUpiOnRecord($table) failed: $e');
      return false;
    }
  }

  // ------------------------------------------------------------ batch 7:
  // provider verticals (lab catalogue + samples, pharmacy
  // medicines, hospital units, payouts, driver)

  /// Resolves the signed-in provider's own record id in [table].
  Future<String?> _ownProviderId(String table) async {
    final me = await fetchOwnProviderRecord(table);
    final id = me?['id'];
    return id == null ? null : '$id';
  }

  // ----- Lab catalogue (audit Panelist 2 / M11) -----

  Future<List<Map<String, dynamic>>> fetchOwnLabTests() async {
    if (!_ready || _uid == null) return const [];
    final labId = await _ownProviderId('labs');
    if (labId == null) return const [];
    try {
      final rows = await _db
          .from('lab_tests')
          .select()
          .eq('lab_id', labId)
          .order('name');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOwnLabTests failed: $e');
      return const [];
    }
  }

  /// Insert (no id) or update (id present) one of the lab's own
  /// tests. lab_id is always forced to the caller's own lab.
  Future<bool> upsertOwnLabTest(Map<String, dynamic> values) async {
    if (!_ready || _uid == null) return false;
    final labId = await _ownProviderId('labs');
    if (labId == null) return false;
    try {
      final row = Map<String, dynamic>.from(values)
        ..['lab_id'] = labId;
      final id = row.remove('id');
      if (id != null && '$id'.isNotEmpty) {
        await _db.from('lab_tests').update(row).eq('id', '$id');
      } else {
        await _db.from('lab_tests').insert(row);
      }
      return true;
    } catch (e) {
      debugPrint('upsertOwnLabTest failed: $e');
      return false;
    }
  }

  Future<bool> deleteOwnLabTest(String id) async {
    if (!_ready) return false;
    try {
      await _db.from('lab_tests').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteOwnLabTest failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOwnLabPackages() async {
    if (!_ready || _uid == null) return const [];
    final labId = await _ownProviderId('labs');
    if (labId == null) return const [];
    try {
      final rows = await _db
          .from('lab_test_packages')
          .select()
          .eq('lab_id', labId)
          .order('name');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOwnLabPackages failed: $e');
      return const [];
    }
  }

  Future<bool> upsertOwnLabPackage(Map<String, dynamic> values) async {
    if (!_ready || _uid == null) return false;
    final labId = await _ownProviderId('labs');
    if (labId == null) return false;
    try {
      final row = Map<String, dynamic>.from(values)
        ..['lab_id'] = labId;
      final id = row.remove('id');
      if (id != null && '$id'.isNotEmpty) {
        await _db.from('lab_test_packages').update(row).eq('id', '$id');
      } else {
        await _db.from('lab_test_packages').insert(row);
      }
      return true;
    } catch (e) {
      debugPrint('upsertOwnLabPackage failed: $e');
      return false;
    }
  }

  Future<bool> deleteOwnLabPackage(String id) async {
    if (!_ready) return false;
    try {
      await _db.from('lab_test_packages').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteOwnLabPackage failed: $e');
      return false;
    }
  }

  // ----- Lab sample collections + reports (Panelist 2, Patient 11)

  Future<List<Map<String, dynamic>>> fetchLabSamples() async {
    if (!_ready || _uid == null) return const [];
    final labId = await _ownProviderId('labs');
    if (labId == null) return const [];
    try {
      final rows = await _db
          .from('lab_sample_collections')
          .select()
          .eq('lab_id', labId)
          .order('created_at', ascending: false)
          .limit(200);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchLabSamples failed: $e');
      return const [];
    }
  }

  /// The patient's own sample-collection rows (RLS: patients
  /// select own) — lab-issued reports surface from here.
  Future<List<Map<String, dynamic>>> fetchPatientLabSamples() async {
    if (!_ready || _uid == null) return const [];
    try {
      final rows = await _db
          .from('lab_sample_collections')
          .select()
          .eq('patient_id', _uid!)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchPatientLabSamples failed: $e');
      return const [];
    }
  }

  Future<bool> createLabSample(Map<String, dynamic> values) async {
    if (!_ready || _uid == null) return false;
    final labId = await _ownProviderId('labs');
    if (labId == null) return false;
    try {
      await _db.from('lab_sample_collections').insert({
        ...values,
        'lab_id': labId,
      });
      return true;
    } catch (e) {
      debugPrint('createLabSample failed: $e');
      return false;
    }
  }

  Future<bool> updateLabSample(
      String id, Map<String, dynamic> values) async {
    if (!_ready) return false;
    try {
      await _db
          .from('lab_sample_collections')
          .update(values)
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateLabSample failed: $e');
      return false;
    }
  }

  /// Uploads a finished lab report into the private lab-reports
  /// bucket. The storage policy lets a patient read only objects
  /// under their own user-id folder, so the path starts with the
  /// patient's id. Returns the storage path, or null on failure.
  Future<String?> uploadLabReport({
    required String patientId,
    required String sampleId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_ready) return null;
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? 'application/pdf'
          : 'image/${ext == 'jpg' ? 'jpeg' : ext}';
      final safeName =
          fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$patientId/${sampleId}_$safeName';
      await _db.storage.from('lab-reports').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
                contentType: contentType, upsert: true),
          );
      return path;
    } catch (e) {
      debugPrint('uploadLabReport failed: $e');
      return null;
    }
  }

  // ----- Pharmacy medicines & stock (Panelist 3 / 16) -----

  Future<List<Map<String, dynamic>>> fetchOwnMedicines() async {
    if (!_ready || _uid == null) return const [];
    final pharmacyId = await _ownProviderId('pharmacies');
    if (pharmacyId == null) return const [];
    try {
      final rows = await _db
          .from('medicines')
          .select()
          .eq('pharmacy_id', pharmacyId)
          .order('name');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOwnMedicines failed: $e');
      return const [];
    }
  }

  /// Relies on the "Pharmacies can manage own medicines" policy
  /// (migration pharmacy_medicines_policy.sql); until the owner
  /// applies it, writes fail closed and this returns false.
  Future<bool> upsertOwnMedicine(Map<String, dynamic> values) async {
    if (!_ready || _uid == null) return false;
    final pharmacyId = await _ownProviderId('pharmacies');
    if (pharmacyId == null) return false;
    try {
      final row = Map<String, dynamic>.from(values)
        ..['pharmacy_id'] = pharmacyId;
      final id = row.remove('id');
      if (id != null && '$id'.isNotEmpty) {
        await _db.from('medicines').update(row).eq('id', '$id');
      } else {
        await _db.from('medicines').insert(row);
      }
      return true;
    } catch (e) {
      debugPrint('upsertOwnMedicine failed: $e');
      return false;
    }
  }

  Future<bool> deleteOwnMedicine(String id) async {
    if (!_ready) return false;
    try {
      await _db.from('medicines').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteOwnMedicine failed: $e');
      return false;
    }
  }

  Future<bool> updateMedicineStock(String id, int quantity) async {
    if (!_ready) return false;
    try {
      await _db.from('medicines').update({
        'stock_quantity': quantity,
        'in_stock': quantity > 0,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateMedicineStock failed: $e');
      return false;
    }
  }

  // ----- Hospital units + ambulance config (Panelist 4) -----

  /// [table] is one of departments | operation_theaters |
  /// hospital_equipment — all share the hospital_id shape and
  /// the "hospital admins manage own" RLS pattern.
  Future<List<Map<String, dynamic>>> fetchOwnHospitalUnits(
      String table) async {
    if (!_ready || _uid == null) return const [];
    final hospitalId = await _ownProviderId('hospitals');
    if (hospitalId == null) return const [];
    try {
      final rows = await _db
          .from(table)
          .select()
          .eq('hospital_id', hospitalId)
          .order('created_at');
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOwnHospitalUnits($table) failed: $e');
      return const [];
    }
  }

  Future<bool> upsertHospitalUnit(
      String table, Map<String, dynamic> values) async {
    if (!_ready || _uid == null) return false;
    final hospitalId = await _ownProviderId('hospitals');
    if (hospitalId == null) return false;
    try {
      final row = Map<String, dynamic>.from(values)
        ..['hospital_id'] = hospitalId;
      final id = row.remove('id');
      if (id != null && '$id'.isNotEmpty) {
        await _db.from(table).update(row).eq('id', '$id');
      } else {
        await _db.from(table).insert(row);
      }
      return true;
    } catch (e) {
      debugPrint('upsertHospitalUnit($table) failed: $e');
      return false;
    }
  }

  Future<bool> deleteHospitalUnit(String table, String id) async {
    if (!_ready) return false;
    try {
      await _db.from(table).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteHospitalUnit($table) failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchAmbulanceConfig() async {
    if (!_ready || _uid == null) return null;
    final hospitalId = await _ownProviderId('hospitals');
    if (hospitalId == null) return null;
    try {
      return await _db
          .from('hospital_ambulance_config')
          .select()
          .eq('hospital_id', hospitalId)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchAmbulanceConfig failed: $e');
      return null;
    }
  }

  Future<bool> saveAmbulanceConfig(Map<String, dynamic> values) async {
    if (!_ready || _uid == null) return false;
    final hospitalId = await _ownProviderId('hospitals');
    if (hospitalId == null) return false;
    try {
      await _db.from('hospital_ambulance_config').upsert(
        {...values, 'hospital_id': hospitalId},
        onConflict: 'hospital_id',
      );
      return true;
    } catch (e) {
      debugPrint('saveAmbulanceConfig failed: $e');
      return false;
    }
  }

  // ----- Provider wallet / earnings / payouts (Panelist 11 / M20)

  Future<Map<String, dynamic>?> fetchProviderWallet(
      String providerType, String providerId) async {
    if (!_ready) return null;
    try {
      return await _db
          .from('provider_wallets')
          .select()
          .eq('provider_type', providerType)
          .eq('provider_id', providerId)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchProviderWallet failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProviderEarnings(
      String providerType, String providerId) async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('provider_earnings')
          .select()
          .eq('provider_type', providerType)
          .eq('provider_id', providerId)
          .order('created_at', ascending: false)
          .limit(50);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchProviderEarnings failed: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchOwnPayoutRequests() async {
    if (!_ready || _uid == null) return const [];
    try {
      final rows = await _db
          .from('payout_requests')
          .select()
          .eq('user_id', _uid!)
          .order('requested_at', ascending: false)
          .limit(50);
      return rows.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchOwnPayoutRequests failed: $e');
      return const [];
    }
  }

  Future<bool> createPayoutRequest({
    required String providerType,
    required String providerId,
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    if (!_ready || _uid == null) return false;
    try {
      await _db.from('payout_requests').insert({
        'provider_type': providerType,
        'provider_id': providerId,
        'user_id': _uid,
        'amount': amount,
        'bank_details': bankDetails,
      });
      return true;
    } catch (e) {
      debugPrint('createPayoutRequest failed: $e');
      return false;
    }
  }

  // ----- Driver (Panelist 9 / M19) -----

  Future<Map<String, dynamic>?> fetchOwnDriverRecord() async {
    if (!_ready || _uid == null) return null;
    try {
      return await _db
          .from('delivery_drivers')
          .select()
          .eq('user_id', _uid!)
          .maybeSingle();
    } catch (e) {
      debugPrint('fetchOwnDriverRecord failed: $e');
      return null;
    }
  }

  Future<bool> setDriverStatus(String driverId, String status) async {
    if (!_ready) return false;
    try {
      await _db
          .from('delivery_drivers')
          .update({'status': status}).eq('id', driverId);
      return true;
    } catch (e) {
      debugPrint('setDriverStatus failed: $e');
      return false;
    }
  }

  /// Deliveries assigned to the signed-in driver, each joined
  /// with its remedoo_orders row (items, total, payment method).
  Future<List<Map<String, dynamic>>> fetchDriverDeliveries() async {
    if (!_ready || _uid == null) return const [];
    final driver = await fetchOwnDriverRecord();
    if (driver == null) return const [];
    try {
      final rows = await _db
          .from('delivery_orders')
          .select()
          .eq('driver_id', '${driver['id']}')
          .order('created_at', ascending: false)
          .limit(100);
      final deliveries = rows.cast<Map<String, dynamic>>();
      for (final d in deliveries) {
        try {
          final order = await _db
              .from('remedoo_orders')
              .select()
              .eq('id', '${d['order_id']}')
              .maybeSingle();
          if (order != null) d['order'] = order;
        } catch (_) {
          // Order details are best-effort; the delivery row alone
          // still renders.
        }
      }
      return deliveries;
    } catch (e) {
      debugPrint('fetchDriverDeliveries failed: $e');
      return const [];
    }
  }

  Future<bool> updateDeliveryStatus(String id, String status) async {
    if (!_ready) return false;
    try {
      await _db.from('delivery_orders').update({
        'status': status,
        if (status == 'delivered')
          'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateDeliveryStatus failed: $e');
      return false;
    }
  }
}
