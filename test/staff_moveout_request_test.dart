import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/moveout/repository.dart'
    as staff;

/// The Staff move-out dialog (Lease Summary → Tenants, tablet layout) posted a
/// single tenant to `/api/moveout/lease_moveout/:id`, a route the server
/// retired on 2026-07-08 (404 on staging, production and 2.2). Every move-out
/// now goes to `/api/moveout/lease_multiplemoveout/:lease_id`, which takes
/// `{ moveoutTenants: [{ tenant_id, lease_id, moveout_notice_given_date,
/// moveout_date }] }` (Movedout_Tenants.js) and reads an ambiguous dd-MM-yyyy
/// date month-first, so dates must go as yyyy-MM-dd.

Future<(http.Request, Object?)> _capture(Future<Object?> Function() call,
    {int status = 200, Map<String, Object?>? reply}) async {
  final sent = <http.Request>[];
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(
        jsonEncode(reply ??
            {
              'statusCode': 200,
              'message': 'Moveout process completed. 1 tenants processed, '
                  '0 tenants skipped (already moved out)',
            }),
        status,
        headers: {'content-type': 'application/json'});
  });
  Object? result;
  await http.runWithClient(() async {
    try {
      result = await call();
    } catch (e) {
      result = e;
    }
  }, () => client);
  expect(sent, hasLength(1));
  return (sent.single, result);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Fluttertoast talks to a platform channel; answer it so toasts no-op.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  setUp(() => SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'role': 'Staffmember',
        'staff_id': 'STAFF-1',
      }));

  // Exactly what the dialog passes: the notice date field holds dd-MM-yyyy,
  // the move-out date is the lease end already in yyyy-MM-dd.
  Future<Object?> moveOut() => staff.LeaseMoveoutRepository().addMoveoutTenant(
        adminId: 'ADMIN-1',
        tenantId: 'T-1',
        leaseId: 'L-1',
        moveoutNoticeGivenDate: '05-10-2026',
        moveoutDate: '2026-12-31',
      );

  test('posts to lease_multiplemoveout, not the retired lease_moveout',
      () async {
    final (r, _) = await _capture(moveOut);
    expect(r.method, 'POST');
    expect(r.url.path, '/api/moveout/lease_multiplemoveout/L-1');
  });

  test('sends the moveoutTenants list with the four keys the server needs',
      () async {
    final (r, _) = await _capture(moveOut);
    expect(jsonDecode(r.body), {
      'moveoutTenants': [
        {
          'admin_id': 'ADMIN-1',
          'tenant_id': 'T-1',
          'lease_id': 'L-1',
          'moveout_notice_given_date': '2026-10-05',
          'moveout_date': '2026-12-31',
        }
      ]
    });
  });

  test('keeps the Staff headers as before', () async {
    final (r, _) = await _capture(moveOut);
    expect(r.headers['authorization'], 'CRM tkn');
    expect(r.headers['id'], 'CRM STAFF-1');
    expect(r.headers['content-type'], startsWith('application/json'));
  });

  test('success reply is returned to the dialog (it then closes)', () async {
    final (_, result) = await _capture(moveOut);
    expect(result, isA<Map<String, dynamic>>());
    expect((result as Map)['statusCode'], 200);
  });

  test('server refusal still throws (dialog stays open, as before)', () async {
    final (_, result) = await _capture(moveOut,
        status: 400,
        reply: {'statusCode': 400, 'message': 'Invalid or empty tenant list'});
    expect(result, isA<Exception>());
  });
}
