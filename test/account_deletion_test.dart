import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/utils/account_deletion.dart';

void main() {
  final requested = DateTime(2026, 10, 22, 10, 0);

  test('erase time is exactly 72 hours after the request', () {
    expect(deletionEraseTime(requested), DateTime(2026, 10, 25, 10, 0));
    expect(accountDeletionWindow, const Duration(hours: 72));
  });

  test('window is open before 72 hours and expired at/after it', () {
    expect(
        deletionWindowExpired(requested, DateTime(2026, 10, 25, 9, 59)),
        isFalse);
    expect(
        deletionWindowExpired(requested, DateTime(2026, 10, 25, 10, 0)),
        isTrue);
    expect(
        deletionWindowExpired(requested, DateTime(2026, 10, 26)), isTrue);
  });

  test('hours left rounds up and never goes negative', () {
    expect(deletionHoursLeft(requested, DateTime(2026, 10, 22, 10, 0)), 72);
    expect(deletionHoursLeft(requested, DateTime(2026, 10, 23, 10, 30)), 48);
    expect(deletionHoursLeft(requested, DateTime(2026, 10, 26)), 0);
  });

  test('parse handles null, DateTime and ISO strings', () {
    expect(parseDeletionRequest(null), isNull);
    expect(parseDeletionRequest(requested), requested);
    expect(parseDeletionRequest('2026-10-22T10:00:00Z'),
        DateTime.utc(2026, 10, 22, 10));
    expect(parseDeletionRequest('not-a-date'), isNull);
    expect(parseDeletionRequest(''), isNull);
  });
}
