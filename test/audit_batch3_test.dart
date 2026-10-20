// Batch 3 audit fixes (2026-10-19): reminders persisted with
// their real repeat, edit support for the device-local datasets,
// notification delete/clear, uploaded-report delete, gender save.
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('reminders', () {
    test('addReminder stores the chosen repeat, not in notes', () {
      final s = AppState();
      s.addReminder(
        title: 'Vitamin D',
        date: DateTime(2026, 10, 20),
        timeLabel: '09:00',
        notes: '',
        repeat: 'Weekly',
      );
      expect(s.reminders, hasLength(1));
      expect(s.reminders.single.repeat, 'Weekly');
      expect(s.reminders.single.notes, '');
    });

    test('Reminder JSON round-trips repeat and done', () {
      final r = Reminder(
        id: 'R1',
        title: 'BP pill',
        date: DateTime(2026, 10, 19, 8, 30),
        timeLabel: '08:30',
        notes: 'after food',
        repeat: 'Once',
        done: true,
      );
      final back = Reminder.fromJson(r.toJson());
      expect(back.id, 'R1');
      expect(back.repeat, 'Once');
      expect(back.done, isTrue);
      expect(back.notes, 'after food');
      expect(back.date, DateTime(2026, 10, 19, 8, 30));
    });

    test('updateReminder edits fields and keeps done state', () {
      final s = AppState();
      s.addReminder(
        title: 'Old',
        date: DateTime(2026, 10, 19),
        timeLabel: '09:00',
        notes: '',
        repeat: 'Daily',
      );
      final id = s.reminders.single.id;
      s.toggleReminder(id);
      s.updateReminder(id, title: 'New', repeat: 'Weekly');
      expect(s.reminders.single.title, 'New');
      expect(s.reminders.single.repeat, 'Weekly');
      expect(s.reminders.single.done, isTrue);
    });
  });

  group('edit support for device-local datasets', () {
    test('updateSavedAddress replaces in place', () {
      final s = AppState();
      s.addSavedAddress(const SavedAddress(
          id: 'A1', label: 'Home', address: 'Old street'));
      s.updateSavedAddress(const SavedAddress(
          id: 'A1', label: 'Home', address: 'New street 42'));
      expect(s.savedAddresses, hasLength(1));
      expect(s.savedAddresses.single.address, 'New street 42');
    });

    test('updateVital replaces the reading value', () {
      final s = AppState();
      s.addVital(VitalReading(
          id: 'V1',
          type: 'weight',
          value: 70,
          date: DateTime(2026, 10, 19)));
      s.updateVital(VitalReading(
          id: 'V1',
          type: 'weight',
          value: 71.5,
          date: DateTime(2026, 10, 19)));
      expect(s.vitals, hasLength(1));
      expect(s.vitals.single.value, 71.5);
    });

    test('updateHistoryEntry replaces the entry', () {
      final s = AppState();
      s.addHistoryEntry(HistoryEntry(
          id: 'H1',
          kind: 'Allergy',
          title: 'Penicillin',
          date: DateTime(2026, 1, 1),
          notes: ''));
      s.updateHistoryEntry(HistoryEntry(
          id: 'H1',
          kind: 'Allergy',
          title: 'Penicillin + sulfa',
          date: DateTime(2026, 1, 1),
          notes: 'severe'));
      expect(s.historyEntries.single.title, 'Penicillin + sulfa');
      expect(s.historyEntries.single.notes, 'severe');
    });

    test('updateFamilyMember replaces fields in place', () {
      final s = AppState();
      s.addFamilyMember(name: 'Amina', relation: 'Mother', age: 60);
      final id = s.family.single.id;
      s.updateFamilyMember(
          id: id, name: 'Amina K', relation: 'Mother', age: 61);
      expect(s.family, hasLength(1));
      expect(s.family.single.name, 'Amina K');
      expect(s.family.single.age, 61);
    });
  });

  group('deletes', () {
    test('removeUploadedReport removes only uploaded reports', () {
      final s = AppState();
      s.addUploadedReport(LabReport(
        id: 'U1',
        patientName: 'P',
        labName: 'My Upload',
        date: DateTime(2026, 10, 19),
        status: 'Completed',
        tests: const [],
        fileUrl: 'https://example.com/r.pdf',
        fileName: 'r.pdf',
      ));
      expect(s.reports, hasLength(1));
      s.removeUploadedReport('U1');
      expect(s.reports, isEmpty);
    });

    test('removeNotification and clearNotifications shrink the list',
        () {
      final s = AppState();
      s.addNotification(title: 'One', message: 'm1', category: 'system');
      s.addNotification(title: 'Two', message: 'm2', category: 'system');
      expect(s.notifications, hasLength(2));
      s.removeNotification(s.notifications.first.id);
      expect(s.notifications, hasLength(1));
      s.clearNotifications();
      expect(s.notifications, isEmpty);
    });
  });

  group('profile gender', () {
    test('updateProfile stores gender on state', () async {
      final s = AppState();
      await s.updateProfile(gender: 'Female');
      expect(s.gender, 'Female');
    });
  });
}
