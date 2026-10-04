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
    this.payInClinicEnabled = true,
    this.upiEnabled = true,
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
    this.payInClinicEnabled = true,
    this.upiEnabled = true,
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
    this.payInClinicEnabled = true,
    this.upiEnabled = true,
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
    this.payInClinicEnabled = true,
    this.upiEnabled = true,
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
  });

  bool get isActive => status != 'delivered';

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
  String status; // upcoming, cancelled

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
  });

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

  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.age,
  });
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

  const LabReport({
    required this.id,
    required this.patientName,
    required this.labName,
    required this.date,
    required this.status,
    required this.tests,
  });
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

  Review({
    required this.appointmentId,
    required this.stars,
    required this.comment,
    this.hidden = false,
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
  final double amount;
  final String reason;
  final DateTime date;
  String status; // requested, approved, rejected, completed

  RefundRequest({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.reason,
    required this.date,
    this.status = 'requested',
  });
}
