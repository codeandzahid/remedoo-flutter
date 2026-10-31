import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/screens/admin/admin_crud_screen.dart';

/// Admin Add Driver login (owner order 2026-10-31): the Drivers form
/// takes the email + password the driver signs in with. A filled-in
/// email creates a fresh driver login; otherwise the row links an
/// existing account by user ID.
void main() {
  test('email given: needs a valid email and an 8+ password', () {
    expect(
        validateDriverAdd(
            email: 'not-an-email', password: '12345678', userId: ''),
        'Enter a valid email');
    expect(
        validateDriverAdd(
            email: 'driver@example.com', password: 'short', userId: ''),
        'Password must be at least 8 characters');
    expect(
        validateDriverAdd(
            email: 'driver@example.com', password: '12345678', userId: ''),
        isNull);
  });

  test('no email: needs a linked user ID', () {
    expect(validateDriverAdd(email: '', password: '', userId: ''),
        'Add a login email or a linked user ID');
    expect(validateDriverAdd(email: '', password: '', userId: 'uid-1'),
        isNull);
  });

  test('email given wins over a user ID', () {
    expect(
        validateDriverAdd(
            email: 'driver@example.com',
            password: '12345678',
            userId: 'uid-1'),
        isNull);
  });
}
