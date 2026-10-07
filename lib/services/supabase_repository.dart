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
      payInClinicEnabled: r['pay_in_clinic_enabled'] != false,
      upiEnabled: r['upi_enabled'] != false,
      consultationDuration:
          (r['consultation_duration'] as num?)?.toInt() ?? 30,
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
      payInClinicEnabled: r['pay_in_clinic_enabled'] != false,
      upiEnabled: r['upi_enabled'] != false,
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
      payInClinicEnabled: r['pay_in_clinic_enabled'] != false,
      upiEnabled: r['upi_enabled'] != false,
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
      payInClinicEnabled: r['pay_in_clinic_enabled'] != false,
      upiEnabled: r['upi_enabled'] != false,
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
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final row = await _db.from('appointments').insert({
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
        'notes': notes,
      }).select('id');
      if (row.isNotEmpty) return '${row.first['id']}';
      return null;
    } catch (e) {
      debugPrint('bookAppointment failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAppointments() async {
    final uid = _uid;
    if (!_ready || uid == null) return const [];
    try {
      final rows = await _db
          .from('appointments')
          .select('*, doctors(name), hospitals(name), labs(name)')
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

  Future<bool> updateAppointmentStatus(String id, String status) async {
    if (!_ready) return false;
    try {
      await _db.from('appointments').update({'status': status}).eq('id', id);
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
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return false;
    try {
      await _db.from('support_messages').insert({
        'ticket_id': ticketId,
        'sender_id': uid,
        'sender_role': senderRole,
        'message': message,
      });
      return true;
    } catch (e) {
      debugPrint('sendTicketMessage failed: $e');
      return false;
    }
  }

  Future<String?> createSupportTicket({
    required String subject,
    required String category,
    required String description,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final row = await _db.from('support_tickets').insert({
        'user_id': uid,
        'subject': subject,
        'category': category,
        'description': description,
        'status': 'open',
        'sender_type': 'patient',
      }).select('id').single();
      return '${row['id']}';
    } catch (e) {
      debugPrint('createSupportTicket failed: $e');
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
      return List<Map<String, dynamic>>.from(rows);
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
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) return null;
    try {
      final order = await _db.from('orders').insert({
        'user_id': uid,
        'pharmacy_id': pharmacyId,
        'status': 'placed',
        'payment_method': payment == 'online' ? 'online' : 'cod',
        'payment_status': 'pending',
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total': total,
        'delivery_address': address,
        'notes': notes,
      }).select('id');
      if (order.isEmpty) return null;
      final orderId = '${order.first['id']}';
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
    try {
      await _db.from('provider_applications').update({
        'status': status,
        'decided_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('decideProviderApplication failed: $e');
      return false;
    }
  }

  /// Grants a role to a user. Callers must be admin (enforced by RLS).
  Future<bool> grantUserRole(String userId, String role) async {
    if (!_ready) return false;
    try {
      await _db.from('user_roles').upsert(
        {'user_id': userId, 'role': role},
        onConflict: 'user_id,role',
      );
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

  /// Provider updates the status of one of their appointments/bookings.
  Future<bool> updateAppointmentStatus(String id, String status) async {
    if (!_ready || _uid == null) return false;
    try {
      await _db
          .from('appointments')
          .update({'status': status})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateAppointmentStatus failed: $e');
      return false;
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
          .select('user_id, full_name, email, phone, created_at')
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

  /// Admin list of all appointments, newest first.
  Future<List<Map<String, dynamic>>> adminFetchAppointments() async {
    if (!_ready) return const [];
    try {
      final rows = await _db
          .from('appointments')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('adminFetchAppointments failed: $e');
      return const [];
    }
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
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
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

  /// Admin update of a refund status.
  Future<bool> updateRefund(String id, String status) async {
    if (!_ready) return false;
    try {
      await _db.from('refunds').update({'status': status}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateRefund failed: $e');
      return false;
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
      String table, String userId, String upiId) async {
    if (!_ready) return false;
    try {
      await _db.from(table).update({'upi_id': upiId}).eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('setProviderUpiOnRecord($table) failed: $e');
      return false;
    }
  }
}
