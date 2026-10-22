import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/utils/admin_user_edit.dart';

void main() {
  test('OTP is needed for email change or a new password only', () {
    expect(
        editNeedsOtp(
            oldEmail: 'a@x.com', newEmail: 'a@x.com', newPassword: ''),
        isFalse);
    expect(
        editNeedsOtp(
            oldEmail: 'a@x.com', newEmail: ' A@x.com ', newPassword: ''),
        isFalse);
    expect(
        editNeedsOtp(
            oldEmail: 'a@x.com', newEmail: 'b@x.com', newPassword: ''),
        isTrue);
    expect(
        editNeedsOtp(
            oldEmail: 'a@x.com',
            newEmail: 'a@x.com',
            newPassword: 'newpass123'),
        isTrue);
    expect(
        editNeedsOtp(
            oldEmail: 'a@x.com', newEmail: 'a@x.com', newPassword: '   '),
        isFalse);
  });

  test('validation catches bad email and short password', () {
    expect(validateAdminUserEdit(email: 'a@x.com', newPassword: ''), isNull);
    expect(
        validateAdminUserEdit(email: 'a@x.com', newPassword: '12345678'),
        isNull);
    expect(validateAdminUserEdit(email: 'nope', newPassword: ''),
        isNotNull);
    expect(validateAdminUserEdit(email: '', newPassword: ''), isNotNull);
    expect(
        validateAdminUserEdit(email: 'a@x.com', newPassword: 'short'),
        isNotNull);
  });
}
