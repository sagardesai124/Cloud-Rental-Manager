import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/services/tenant_delete_reason.dart';

/// Delete Tenant (Admin and Staff Tenants list): the reason follows web
/// staging (tenants-v2/tenantRows.js `deleteReasonProblem`) — not blank,
/// letters, numbers and spaces only — and the pop-up says "tenant!".

/// Web's own function, written out the same way.
String? _web(String r) {
  if (r.trim().isEmpty) return 'Enter a reason for deleting this tenant.';
  if (!RegExp(r'^[a-zA-Z0-9 ]*$').hasMatch(r)) {
    return 'Use only letters A–Z, numbers and spaces in the reason.';
  }
  return null;
}

const _screens = [
  'lib/screens/Rental/Tenants/Tenants_table.dart',
  'lib/StaffModule/screen/Rental/Tenants/Tenants_table.dart',
];

void main() {
  test('same result and message as web for every reason', () {
    const reasons = [
      '', '   ', 'moved out.', 'moved out', 'Moved Out 2026', 'lease#1',
      'bad-tenant', "o'brien left", 'ok ', ' ok', 'a_b', 'reason!', '123',
    ];
    for (final r in reasons) {
      expect(tenantDeleteReasonProblem(r), _web(r), reason: '"$r"');
    }
  });

  test('blocks blank, spaces-only and symbols; allows letters, numbers, spaces',
      () {
    expect(tenantDeleteReasonProblem(''),
        'Enter a reason for deleting this tenant.');
    expect(tenantDeleteReasonProblem('   '),
        'Enter a reason for deleting this tenant.');
    expect(tenantDeleteReasonProblem('moved out.'),
        'Use only letters A–Z, numbers and spaces in the reason.');
    expect(tenantDeleteReasonProblem('moved out'), isNull);
    expect(tenantDeleteReasonProblem('Unit 4B moved out 2026'), isNull);
  });

  for (final path in _screens) {
    test('$path: delete pop-up uses the web rule and "tenant!"', () {
      final src = File(path).readAsStringSync();
      expect(src, contains('recover this tenant!"'));
      expect(src, isNot(contains('recover this Tenants!')));
      expect('tenantDeleteReasonProblem(reason.text)'.allMatches(src).length, 1);
      expect(src, isNot(contains('if (reason.text.isEmpty)')),
          reason: 'spaces-only must not get through');
    });
  }
}
