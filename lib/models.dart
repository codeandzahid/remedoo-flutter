// Data models for the Remedoo patient app.
// All demo data lives in data/mock_data.dart; swap the provider functions
// there for Supabase queries when the backend is ready.

import 'package:flutter/material.dart';

class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String hospital;
  final double fee;
  final double rating;
  final int reviews;
  final int expYears;
  final int waitMin;
  final double distanceKm;
  final bool verified;
  final String about;
  final bool active;
  final String? upiId;
  final bool payInClinicEnabled;
  final bool upiEnabled;
  final int consultationDuration;

  /// Real contact number from the doctors table ('' when not
  /// provided).
  final String phone;

  /// Structured working_hours JSONB + vacation_dates from the
  /// doctors table (audit M14: booking used synthetic 9–5 slots
  /// for everyone). Null/empty = fall back to standard hours.
  final Map<String, dynamic>? workingHours;
  final List<String> vacationDates;

  /// doctors.video_consultation_enabled — the booking form only
  /// offers a video consult when the doctor does (audit Patient 13).
  final bool videoConsultationEnabled;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.fee,
    required this.rating,
    required this.reviews,
    required this.expYears,
    required this.waitMin,
    required this.distanceKm,
    required this.verified,
    required this.about,
    this.active = true,
    this.upiId,
    this.payInClinicEnabled = false,
    this.upiEnabled = false,
    this.consultationDuration = 30,
    this.phone = '',
    this.workingHours,
    this.vacationDates = const [],
    this.videoConsultationEnabled = false,
  });
}

class Hospital {
  final String id;
  final String name;
  final String location;
  final bool government;
  final bool hasIcu;
  final int beds;
  final double rating;
  final int reviews;
  final int waitMin;
  final double distanceKm;
  final bool verified;
  final bool active;
  final String? upiId;
  final bool payInClinicEnabled;
  final bool upiEnabled;

  /// Consultation / booking fee from the hospitals table
  /// (consultation_fee). The booking entry points used to
  /// hardcode ₹300 (form-pages audit Patient 19).
  final double fee;

  /// Structured working_hours JSONB (audit M14).
  final Map<String, dynamic>? workingHours;

  /// Real contact numbers from the hospitals table ('' when the
  /// hospital has not provided one — call actions hide rather than
  /// dial a placeholder).
  final String phone;
  final String emergencyContact;

  const Hospital({
    required this.id,
    required this.name,
    required this.location,
    required this.government,
    required this.hasIcu,
    required this.beds,
    required this.rating,
    required this.reviews,
    required this.waitMin,
    required this.distanceKm,
    required this.verified,
    this.active = true,
    this.upiId,
    this.payInClinicEnabled = false,
    this.upiEnabled = false,
    this.fee = 0,
    this.workingHours,
    this.phone = '',
    this.emergencyContact = '',
  });
}

class Lab {
  final String id;
  final String name;
  final String location;
  final int testCount;
  final int offers;
  final String turnaround;
  final double rating;
  final int reviews;
  final bool nabl;
  final bool verified;
  final double distanceKm;
  final bool active;
  final String? upiId;
  final bool payInClinicEnabled;
  final bool upiEnabled;

  /// Real contact number from the labs table ('' when not provided).
  final String phone;

  /// Structured working_hours JSONB (audit M14).
  final Map<String, dynamic>? workingHours;

  const Lab({
    required this.id,
    required this.name,
    required this.location,
    required this.testCount,
    required this.offers,
    required this.turnaround,
    required this.rating,
    required this.reviews,
    required this.nabl,
    required this.verified,
    required this.distanceKm,
    this.active = true,
    this.upiId,
    this.payInClinicEnabled = false,
    this.upiEnabled = false,
    this.phone = '',
    this.workingHours,
  });
}

class Pharmacy {
  final String id;
  final String name;
  final String location;
  final double rating;
  final int reviews;
  final String deliveryTime;
  final int itemCount;
  final int offers;
  final bool verified;
  final double distanceKm;
  final bool active;
  final String? upiId;
  final bool payInClinicEnabled;
  final bool upiEnabled;

  /// Real contact number from the pharmacies table ('' when not
  /// provided).
  final String phone;

  const Pharmacy({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.deliveryTime,
    required this.itemCount,
    required this.offers,
    required this.verified,
    required this.distanceKm,
    this.active = true,
    this.upiId,
    this.payInClinicEnabled = false,
    this.upiEnabled = false,
    this.phone = '',
  });
}

class Medicine {
  final String id;
  final String pharmacyId;
  final String name;
  final String pack;
  final String brand;
  final double price;
  final double mrp;
  final bool rxRequired;
  final String category;
  final bool active;
  final String? imageUrl;

  const Medicine({
    required this.id,
    required this.pharmacyId,
    required this.name,
    required this.pack,
    required this.brand,
    required this.price,
    required this.mrp,
    required this.rxRequired,
    required this.category,
    this.active = true,
    this.imageUrl,
  });
}

class CartLine {
  final Medicine medicine;
  int qty;

  CartLine({required this.medicine, this.qty = 1});

  double get lineTotal => medicine.price * qty;
}

class MedOrder {
  final String id;
  final String pharmacyName;
  final List<CartLine> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String address;
  final String payment;
  final DateTime placedAt;
  String status; // placed, confirmed, out_for_delivery, delivered

  /// Special instructions the patient typed at checkout (sent to the
  /// backend orders.notes column; '' when none).
  final String notes;

  /// The pharmacy this order belongs to (backend pharmacy id; the
  /// in-house storefront uses 'remedoo'). Null for older local rows.
  final String? pharmacyId;

  /// Backend payment fields (orders table): 'online'/'cod' and the
  /// payment status ('pending', 'paid'…). Null for demo/local rows
  /// that never carried them.
  final String? paymentMethod;
  final String? paymentStatus;

  /// Checkout reference (ORD…/APT…) linking this order to its
  /// Remedoo Pay session, and the customer's own UPI ID captured at
  /// checkout so the provider can refund to it.
  final String? paymentRef;
  final String? customerUpi;

  /// Signed URL of the prescription file uploaded at checkout
  /// (orders.prescription_url). Null when no file was attached —
  /// the file used to be filename-only and never uploaded
  /// (form-pages audit M3).
  final String? prescriptionUrl;

  /// Refund tracking after a paid-online order is cancelled:
  /// refundStatus 'requested' | 'refunded' (null = no refund).
  String? refundStatus;
  double? refundAmount;
  DateTime? refundAt;
  String? refundUtr;
  DateTime? refundRequestedAt;

  MedOrder({
    required this.id,
    required this.pharmacyName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.address,
    required this.payment,
    required this.placedAt,
    this.status = 'placed',
    this.notes = '',
    this.pharmacyId,
    this.paymentMethod,
    this.paymentStatus,
    this.paymentRef,
    this.customerUpi,
    this.prescriptionUrl,
    this.refundStatus,
    this.refundAmount,
    this.refundAt,
    this.refundUtr,
    this.refundRequestedAt,
  });

  bool get isActive => status != 'delivered' && status != 'cancelled';

  /// The patient may cancel only before dispatch (2026-10-19).
  bool get isCancellable => status == 'placed' || status == 'confirmed';

  /// True when this order was paid online: explicit backend fields
  /// first, the legacy display text ('Pay Online', 'online') as the
  /// fallback for older rows.
  bool get isPaidOnline {
    if (paymentMethod != null) return paymentMethod == 'online';
    final p = payment.toLowerCase();
    return p.contains('online') || p.contains('upi');
  }

  List<CartLine> get lines => items;
  String get eta => '35-45 min';
}

class Appointment {
  final String id;
  final String doctorName;
  final String specialty;
  final String place;
  final DateTime date;
  final String timeLabel;
  final double fee;
  final String payment;
  final String kind; // doctor, hospital, lab
  final String refId;
  final String notes;
  final List<LabTest> tests;
  String status; // pending, upcoming, cancelled
  final String? bookingForMemberId;
  final String? bookingForName;
  final String? prescriptionPath;
  final String? prescriptionName;

  /// Raw backend status from the appointments table ('pending',
  /// 'confirmed', 'cancelled'…). The local [status] is a display
  /// word ('pending', 'upcoming' for confirmed/completed,
  /// 'cancelled'), so the confirmed-cancel OTP gate reads this
  /// field instead.
  final String? remoteStatus;

  /// Checkout reference (APT…) linking this appointment to its
  /// Remedoo Pay session, and the customer's own UPI ID captured at
  /// booking so the provider can refund to it.
  final String? paymentRef;
  final String? customerUpi;

  /// Department + video-consult choice (appointments.department /
  /// is_video_consultation) — the booking form never collected
  /// them (form-pages audit Patient 13).
  final String? department;
  final bool isVideoConsultation;

  /// Refund tracking after a paid-online appointment is cancelled.
  String? refundStatus;
  double? refundAmount;
  DateTime? refundAt;
  String? refundUtr;
  DateTime? refundRequestedAt;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.place,
    required this.date,
    required this.timeLabel,
    required this.fee,
    required this.payment,
    this.kind = 'doctor',
    this.refId = '',
    this.notes = '',
    this.tests = const [],
    this.status = 'upcoming',
    this.bookingForMemberId,
    this.bookingForName,
    this.prescriptionPath,
    this.prescriptionName,
    this.remoteStatus,
    this.paymentRef,
    this.customerUpi,
    this.department,
    this.isVideoConsultation = false,
    this.refundStatus,
    this.refundAmount,
    this.refundAt,
    this.refundUtr,
    this.refundRequestedAt,
  });

  /// True when the fee was paid online (the payment label says so).
  bool get isPaidOnline {
    final p = payment.toLowerCase();
    return p.contains('online') || p.contains('upi');
  }

  String get dateLabel => '${date.day}/${date.month}/${date.year}';
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final String category; // appointments, orders, system
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    this.read = false,
  });

  String get body => message;

  IconData get icon {
    switch (category) {
      case 'appointments':
        return Icons.calendar_month;
      case 'orders':
        return Icons.shopping_bag;
      default:
        return Icons.notifications;
    }
  }
}

class FamilyMember {
  final String id;
  final String name;
  final String relation;
  final int age;
  final String? reason;

  /// The rest of the family_members record (form-pages audit
  /// Patient 9: the form used to collect name/relation/age only,
  /// and age never survived a reload because date_of_birth was
  /// never written).
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? allergies;
  final String? chronicConditions;

  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.age,
    this.reason,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.chronicConditions,
  });

  /// Whole years between a date of birth and [now] — a bare year
  /// subtraction overstates the age before this year's birthday.
  static int ageFromDob(DateTime dob, [DateTime? now]) {
    final n = now ?? DateTime.now();
    var years = n.year - dob.year;
    if (n.month < dob.month ||
        (n.month == dob.month && n.day < dob.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }
}

class Reminder {
  final String id;
  final String title;
  final DateTime date;
  final String timeLabel;
  final String notes;
  final String repeat;
  bool done;

  Reminder({
    required this.id,
    required this.title,
    required this.date,
    required this.timeLabel,
    required this.notes,
    this.repeat = 'Daily',
    this.done = false,
  });

  bool get completed => done;
  String get time => timeLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'timeLabel': timeLabel,
        'notes': notes,
        'repeat': repeat,
        'done': done,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        timeLabel: j['timeLabel'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        repeat: j['repeat'] as String? ?? 'Daily',
        done: j['done'] as bool? ?? false,
      );
}

class LabTest {
  final String id;
  final String name;
  final double price;
  final String turnaround;
  final String category;

  const LabTest({
    required this.id,
    required this.name,
    required this.price,
    this.turnaround = '6-12 hrs',
    this.category = 'General',
  });
}

/// Patient lab report with a results table.
class LabReport {
  final String id;
  final String patientName;
  final String labName;
  final DateTime date;
  final String status; // In Progress, Completed
  final List<Map<String, String>> tests;

  /// Set when the patient uploaded this report file themselves
  /// (owner feature 2026-10-19): a signed URL to the stored file.
  final String? fileUrl;
  final String? fileName;

  const LabReport({
    required this.id,
    required this.patientName,
    required this.labName,
    required this.date,
    required this.status,
    required this.tests,
    this.fileUrl,
    this.fileName,
  });

  bool get isUploaded => fileUrl != null;
}

/// A health fact the patient adds to their Medical History
/// themselves (2026-10-19): allergy, condition, surgery, medication…
class HistoryEntry {
  final String id;
  final String kind; // Allergy, Condition, Surgery, Medication, Other
  final String title;
  final DateTime date;
  final String notes;

  const HistoryEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        kind: j['kind'] as String? ?? 'Other',
        title: j['title'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        notes: j['notes'] as String? ?? '',
      );
}

/// One saved delivery address in the patient's address book
/// (2026-10-19): a label (Home, Office…) plus the full address.
class SavedAddress {
  final String id;
  final String label;
  final String address;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'address': address};

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] as String,
        label: j['label'] as String? ?? 'Home',
        address: j['address'] as String? ?? '',
      );
}

/// One health-number reading logged by the patient (2026-10-19):
/// BP (systolic/diastolic mmHg), sugar (mg/dL) or weight (kg).
class VitalReading {
  final String id;
  final String type; // bp, sugar, weight
  final double value; // sugar mg/dL, weight kg, BP systolic
  final double? value2; // BP diastolic
  final DateTime date;

  const VitalReading({
    required this.id,
    required this.type,
    required this.value,
    this.value2,
    required this.date,
  });

  String get label => switch (type) {
        'bp' => '${value.round()}/${(value2 ?? 0).round()}',
        'sugar' => '${value.round()} mg/dL',
        _ => '${value.toStringAsFixed(1)} kg',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'value2': value2,
        'date': date.toIso8601String(),
      };

  factory VitalReading.fromJson(Map<String, dynamic> j) => VitalReading(
        id: j['id'] as String,
        type: j['type'] as String,
        value: (j['value'] as num).toDouble(),
        value2: (j['value2'] as num?)?.toDouble(),
        date: DateTime.parse(j['date'] as String),
      );
}

class SupportTicket {
  final String id;
  final String subject;
  final String category;
  final String description;
  final DateTime date;
  String status; // open, resolved
  String response;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.description,
    required this.date,
    this.status = 'open',
    this.response = '',
  });
}

class DriverDelivery {
  final String id;
  final String orderId;
  final String pharmacy;
  final String address;
  final double amount;
  String status; // assigned, accepted, picked_up, delivered

  DriverDelivery({
    required this.id,
    required this.orderId,
    required this.pharmacy,
    required this.address,
    required this.amount,
    this.status = 'assigned',
  });

  String get pharmacyName => pharmacy;
}

class Review {
  final String appointmentId;
  final int stars;
  final String comment;
  bool hidden;

  /// Backend row id (reviews table) once persisted; null for a
  /// local-only review (form-pages audit M6: reviews used to live
  /// only in an in-memory map and vanished on restart).
  final String? id;

  /// Who was reviewed (reviews.provider_id / provider_type).
  final String? providerId;
  final String? providerType;

  /// Moderation note written from Admin > Reviews.
  String adminNotes;

  Review({
    required this.appointmentId,
    required this.stars,
    required this.comment,
    this.hidden = false,
    this.id,
    this.providerId,
    this.providerType,
    this.adminNotes = '',
  });
}

/// Provider onboarding application (admin approvals).
class ProviderApplication {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String license;
  final DateTime date;
  String status; // pending, approved, rejected

  ProviderApplication({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.license,
    required this.date,
    this.status = 'pending',
  });
}

/// Emergency SOS alert (admin dispatch board).
class SosAlert {
  final String id;
  final String name;
  final String phone;
  final String location;
  final DateTime time;
  String status; // new, acknowledged, dispatched

  SosAlert({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.time,
    this.status = 'new',
  });
}

/// Refund request (admin refunds board).
class RefundRequest {
  final String id;
  final String orderId;
  final String? appointmentId;
  final double amount;
  final String reason;
  final DateTime date;
  String status; // requested, processing, rejected, completed

  RefundRequest({
    required this.id,
    required this.orderId,
    this.appointmentId,
    required this.amount,
    required this.reason,
    required this.date,
    this.status = 'requested',
  });
}
