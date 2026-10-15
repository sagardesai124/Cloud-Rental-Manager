import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/model/cosigner.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';

/// A lease can't hold two cosigners with the same email or phone number,
/// with web's messages (RentRollLeasing.jsx cosigner submit).

const _emailClash = 'A cosigner with this email already exists on this lease.';
const _phoneClash =
    'A cosigner with this phone number already exists on this lease.';

Cosigner _c(String email, String phone, {String? id}) => Cosigner(
      cosignerId: id,
      firstName: 'Pat',
      lastName: 'Lee',
      phoneNumber: phone,
      email: email,
      streetAddress: '',
      city: '',
      country: '',
      postalCode: '',
    );

void main() {
  final onLease = [_c('pat@example.com', '(424) 252-5252', id: 'C-1')];

  test('a new cosigner with different email and phone is fine', () {
    expect(cosignerDuplicateError(onLease, _c('sam@example.com', '5551234567')),
        isNull);
  });

  test('same email, any letter case: web message', () {
    expect(
        cosignerDuplicateError(onLease, _c(' PAT@example.com ', '5551234567')),
        _emailClash);
  });

  test('same phone, compared by digits only: web message', () {
    expect(cosignerDuplicateError(onLease, _c('sam@example.com', '4242525252')),
        _phoneClash);
  });

  test('editing a cosigner does not clash with itself', () {
    expect(
        cosignerDuplicateError(onLease, _c('pat@example.com', '4242525252'),
            editIndex: 0),
        isNull);
    expect(
        cosignerDuplicateError(
            onLease, _c('pat@example.com', '4242525252', id: 'C-1')),
        isNull);
  });

  test('editing one cosigner to another cosigner\'s email clashes', () {
    final two = [...onLease, _c('sam@example.com', '5551234567')];
    expect(
        cosignerDuplicateError(two, _c('pat@example.com', '5551234567'),
            editIndex: 1),
        _emailClash);
  });

  test('empty email or phone is not compared', () {
    final blank = [_c('', '')];
    expect(cosignerDuplicateError(blank, _c('', '')), isNull);
  });
}
