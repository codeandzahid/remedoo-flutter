import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/utils/working_hours.dart';

/// Form-pages audit Batch 5 — working hours drive slots (M4/M14),
/// blocked slots + vacation, doctor video/department booking
/// (Patient 12/13), shared payments card (Panelist 15),
/// destructive-action prompts (Panelist 17), lab note label +
/// reviews sections (Panelist 21).
void main() {
  group('working hours parsing (M4)', () {
    test('legacy range-key shape parses per day', () {
      final h = parseWorkingHours(const {
        'mon-fri': '09:00-17:00',
        'sat': '09:00-14:00',
        'sun': 'closed',
      });
      expect(h['mon']!.isOpen, isTrue);
      expect(h['mon']!.start, '09:00');
      expect(h['fri']!.end, '17:00');
      expect(h['sat']!.end, '14:00');
      expect(h['sun']!.isOpen, isFalse);
    });

    test('null/garbage hours fall back to the standard week', () {
      final h = parseWorkingHours(null);
      expect(h['mon']!.isOpen, isTrue);
      expect(h['sun']!.isOpen, isFalse);
      final g = parseWorkingHours(const {'note': 'whenever'});
      expect(g['mon']!.start, '09:00');
    });

    test('round-trip keeps the structured shape, never a note', () {
      final json = workingHoursToJson(parseWorkingHours(const {
        'mon-fri': '10:00-18:00',
        'sat': 'closed',
        'sun': 'closed',
      }));
      expect(json['mon'], '10:00-18:00');
      expect(json['sat'], 'closed');
      expect(json.containsKey('mon-fri'), isFalse);
      expect(json.containsKey('note'), isFalse);
    });
  });

  group('slots from hours (M14)', () {
    test('respects opening hours and duration', () {
      final h = parseWorkingHours(const {
        'mon': '09:00-12:00',
      });
      final monday = DateTime(2026, 10, 26); // a Monday
      final slots = slotsForDate(h, monday, durationMinutes: 60);
      expect(slots, ['09:00', '10:00', '11:00']);
    });

    test('closed days and vacation days yield no slots', () {
      final h = parseWorkingHours(const {
        'mon-fri': '09:00-17:00',
        'sat': '09:00-14:00',
        'sun': 'closed',
      });
      final sunday = DateTime(2026, 10, 25);
      expect(slotsForDate(h, sunday), isEmpty);
      final monday = DateTime(2026, 10, 26);
      expect(
        slotsForDate(h, monday, vacationDates: const ['2026-10-26']),
        isEmpty,
      );
      expect(slotsForDate(h, monday), isNotEmpty);
    });

    test('blocked slot filtering covers ranges and full days', () {
      final partial = {
        'is_full_day': false,
        'start_time': '10:00:00',
        'end_time': '12:00:00',
      };
      expect(slotBlocked('10:30', partial), isTrue);
      expect(slotBlocked('09:30', partial), isFalse);
      expect(slotBlocked('12:30', partial), isFalse);
      expect(slotBlocked('09:00', {'is_full_day': true}), isTrue);
    });
  });

  group('source guards', () {
    String read(String p) => File(p).readAsStringSync();

    test('M4: the corrupting note-write is gone', () {
      final doctor = read('lib/screens/partner/doctor_dashboard.dart');
      expect(doctor.contains("{'note':"), isFalse);
      expect(doctor.contains('workingHoursToJson(_hoursValue)'), isTrue);
      expect(doctor.contains('WorkingHoursEditor'), isTrue);
    });

    test('Panelist 15: doctor payments use the shared card', () {
      final doctor = read('lib/screens/partner/doctor_dashboard.dart');
      expect(
          doctor.contains("ProviderUpiSettingsCard(\n          table: 'doctors'") ||
              doctor.contains("table: 'doctors',"),
          isTrue);
    });

    test('Panelist 17: destructive actions prompt and write reasons',
        () {
      final payments = read('lib/widgets/provider_payments.dart');
      expect(payments.contains('promptActionReason'), isTrue);
      expect(payments.contains('promptCompletionDetails'), isTrue);
      final repo = read('lib/services/supabase_repository.dart');
      expect(repo.contains("'rejection_reason': rejectionReason"), isTrue);
      expect(repo.contains("'consultation_notes': consultationNotes"),
          isTrue);
      expect(repo.contains("'follow_up_date': followUpDate"), isTrue);
      final pharmacy =
          read('lib/screens/partner/pharmacy_dashboard.dart');
      expect(pharmacy.contains('Cancel this order?'), isTrue);
    });

    test('Panelist 21: lab notes labelled honestly; reviews shared',
        () {
      final lab = read('lib/screens/partner/lab_dashboard.dart');
      expect(lab.contains('Tests: '), isFalse);
      expect(lab.contains('Note: '), isTrue);
      for (final f in [
        'lib/screens/partner/hospital_dashboard.dart',
        'lib/screens/partner/lab_dashboard.dart',
        'lib/screens/partner/pharmacy_dashboard.dart',
      ]) {
        expect(read(f).contains('ProviderReviewsList'), isTrue,
            reason: f);
        expect(read(f).contains('fetchProviderReviews'), isTrue,
            reason: f);
      }
    });

    test('Patient 12/13: booking carries department and video flag',
        () {
      final booking = read('lib/screens/booking_screen.dart');
      expect(booking.contains('department: _department.text'), isTrue);
      expect(booking.contains('isVideoConsultation: _video'), isTrue);
      final state = read('lib/state/app_state.dart');
      expect(state.contains('department: appt.department'), isTrue);
      expect(state.contains('isVideoConsultation: appt.isVideoConsultation') ||
          state.contains('is_video_consultation'), isTrue);
      final repo = read('lib/services/supabase_repository.dart');
      expect(repo.contains("'department': department,"), isTrue);
      expect(repo.contains("'is_video_consultation': isVideoConsultation"),
          isTrue);
    });

    test('blocked slots go through the privacy-safe RPC', () {
      final repo = read('lib/services/supabase_repository.dart');
      expect(repo.contains("'doctor_blocked_slots_for'"), isTrue);
      final sql =
          read('supabase/migration/doctor_blocked_slots_public.sql');
      expect(sql.contains('SECURITY DEFINER'), isTrue);
      expect(sql.contains('reason'), isTrue); // documents exclusion
    });

    test('doctorSlotsFor honours stored working hours', () {
      final state = read('lib/state/app_state.dart');
      expect(state.contains('slotsForDate('), isTrue);
      expect(state.contains('parseWorkingHours(hoursRaw)'), isTrue);
      expect(state.contains('slotBlocked(label, b)'), isTrue);
      expect(state.contains('_blockedSlotsByDoctor'), isTrue);
    });
  });
}
