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
}
