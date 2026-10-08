import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/lease.dart'
    as staff;
import 'package:three_zero_two_property/repository/lease.dart' as admin;

/// What the lease DELETE request carries, matched to web (RentRoll.jsx):
/// `{ reason }` for a lease that has not started, `{ reason, override: true }`
/// for a started lease — the server (LeaseService.deleteLease) refuses a
/// started lease without the override. Older servers (staging) ignore the
/// extra field, so sending it is safe there too.

Future<http.Request> _capture(Future<void> Function() call) async {
  final sent = <http.Request>[];
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(
        jsonEncode({'statusCode': 200, 'message': 'Lease deleted'}), 200,
        headers: {'content-type': 'application/json'});
  });
  await http.runWithClient(call, () => client);
  expect(sent, hasLength(1));
  return sent.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Fluttertoast talks to a platform channel; answer it so toasts no-op.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  group('Admin repository', () {
    setUp(() => SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'}));

    test('not started: reason only, no override (as before)', () async {
      final r = await _capture(() => admin.LeaseRepository().deleteLease(
          leaseId: 'L-1', companyName: 'Acme', reason: 'typo'));
      expect(r.method, 'DELETE');
      expect(r.url.path, '/api/leases/leases/L-1');
      expect(r.url.queryParameters['company_name'], 'Acme');
      expect(jsonDecode(r.body), {'reason': 'typo'});
      expect(r.headers['id'], 'CRM ADMIN-1');
    });

    test('started: reason + override:true (web parity)', () async {
      final r = await _capture(() => admin.LeaseRepository().deleteLease(
          leaseId: 'L-1', companyName: 'Acme', reason: 'typo', override: true));
      expect(jsonDecode(r.body), {'reason': 'typo', 'override': true});
    });
  });

  group('Staff repository', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'role': 'Staffmember',
          'staff_id': 'STAFF-1'
        }));

    test('not started: reason only, staff own id', () async {
      final r = await _capture(() => staff.LeaseRepository().deleteLease(
          leaseId: 'L-1', companyName: 'Acme', reason: 'typo'));
      expect(jsonDecode(r.body), {'reason': 'typo'});
      expect(r.headers['id'], 'CRM STAFF-1');
    });

    test('override flag is carried when asked', () async {
      final r = await _capture(() => staff.LeaseRepository().deleteLease(
          leaseId: 'L-1', companyName: 'Acme', reason: 'typo', override: true));
      expect(jsonDecode(r.body), {'reason': 'typo', 'override': true});
    });
  });

  test('a server refusal (payments / started) surfaces its message as an error',
      () async {
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'statusCode': 409,
          'code': 'LEASE_HAS_PAYMENTS',
          'message': "This lease has payments recorded, so it can't be deleted."
        }),
        409,
        headers: {'content-type': 'application/json'}));
    await http.runWithClient(() async {
      await expectLater(
          admin.LeaseRepository()
              .deleteLease(leaseId: 'L-1', companyName: 'Acme', reason: 'x'),
          throwsA(isA<Exception>()));
    }, () => client);
  });
}
