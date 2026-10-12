import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/moveout/repository.dart'
    as staff;
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/repository.dart'
    as admin;

/// Where the move-out request carries the lease-end answer
/// (Movedout_Tenants.js on development-2.2, POST lease_multiplemoveout):
/// top-level `leaseEnd` in a JSON body, inside the `data` JSON string in a
/// multipart body. With no answer the body is exactly what it was before.

const _tenants = [
  {
    'admin_id': 'ADMIN-1',
    'tenant_id': 'T-1',
    'lease_id': 'L-1',
    'moveout_notice_given_date': '2026-10-05',
    'moveout_date': '2026-10-31',
  }
];
const _leaseEnd = {
  'ends_lease': true,
  'ends_on': '2026-10-31',
  'reason': 'mutual_agreement'
};

Future<http.BaseRequest> _capture(Future<Object?> Function() call) async {
  final sent = <http.BaseRequest>[];
  final bodies = <String>[];
  final client = MockClient((request) async {
    sent.add(request);
    bodies.add(request.body);
    return http.Response(
        jsonEncode({'statusCode': 200, 'message': 'Moveout process completed.'}),
        200,
        headers: {'content-type': 'application/json'});
  });
  await http.runWithClient(() async {
    try {
      await call();
    } catch (_) {}
  }, () => client);
  expect(sent, hasLength(1));
  return sent.single;
}

/// The `data` field of a multipart body, decoded.
Map<String, dynamic> _multipartData(http.Request r) {
  final body = r.body;
  final m = RegExp(r'name="data"\r\n\r\n(.*?)\r\n--', dotAll: true)
      .firstMatch(body);
  expect(m, isNotNull, reason: 'multipart body has a data field');
  return jsonDecode(m!.group(1)!) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  setUp(() => SharedPreferences.setMockInitialValues(
      {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'}));

  Future<Object?> adminJson({Map<String, dynamic>? leaseEnd}) =>
      admin.LeaseMoveoutRepository().addMoveoutTenant(
        adminId: 'ADMIN-1',
        tenantId: 'T-1',
        leaseId: 'L-1',
        moveoutNoticeGivenDate: '2026-10-05',
        moveoutDate: '2026-10-31',
        multitenantdata: _tenants,
        leaseEnd: leaseEnd,
      );

  Future<Object?> adminMultipart({Map<String, dynamic>? leaseEnd}) =>
      admin.LeaseMoveoutRepository().addMoveoutTenantfromlease(
        adminId: 'ADMIN-1',
        tenantId: 'T-1',
        leaseId: 'L-1',
        moveoutNoticeGivenDate: '2026-10-05',
        moveoutDate: '2026-10-31',
        multitenantdata: _tenants,
        fileDescriptions: const [],
        selectedFiles: const <File>[],
        leaseEnd: leaseEnd,
      );

  group('Admin JSON (property move-out, lease tablet dialog)', () {
    test('no answer: body unchanged', () async {
      final r = await _capture(adminJson) as http.Request;
      expect(r.url.path, '/api/moveout/lease_multiplemoveout/L-1');
      expect(jsonDecode(r.body), {'moveoutTenants': _tenants});
    });

    test('answer: leaseEnd sent top-level', () async {
      final r = await _capture(() => adminJson(leaseEnd: _leaseEnd))
          as http.Request;
      expect(jsonDecode(r.body),
          {'moveoutTenants': _tenants, 'leaseEnd': _leaseEnd});
    });
  });

  group('Admin multipart (lease move-out screen)', () {
    test('no answer: data unchanged', () async {
      final r = await _capture(adminMultipart) as http.Request;
      expect(r.url.path, '/api/moveout/lease_multiplemoveout/L-1');
      expect(_multipartData(r),
          {'moveoutTenants': _tenants, 'descriptions': <String>[]});
    });

    test('answer: leaseEnd sent inside data', () async {
      final r = await _capture(() => adminMultipart(leaseEnd: {'ends_lease': false}))
          as http.Request;
      expect(_multipartData(r), {
        'moveoutTenants': _tenants,
        'descriptions': <String>[],
        'leaseEnd': {'ends_lease': false},
      });
    });
  });

  group('id header: the caller\'s own id', () {
    test('Admin with a staff_id left from an earlier Staff login sends adminId',
        () async {
      SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'role': 'Admin',
        'staff_id': 'STALE-STAFF',
      });
      final r = await _capture(adminJson) as http.Request;
      expect(r.headers['id'], 'CRM ADMIN-1');
    });

    test('Staff on the shared Admin repository sends staff_id', () async {
      SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'role': 'Staffmember',
        'staff_id': 'STAFF-1',
      });
      final r = await _capture(adminMultipart) as http.Request;
      expect(r.headers['id'], 'CRM STAFF-1');
    });
  });

  group('Staff JSON (lease tablet dialog)', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'role': 'Staffmember',
          'staff_id': 'STAFF-1',
        }));

    Future<Object?> staffJson({Map<String, dynamic>? leaseEnd}) =>
        staff.LeaseMoveoutRepository().addMoveoutTenant(
          adminId: 'ADMIN-1',
          tenantId: 'T-1',
          leaseId: 'L-1',
          moveoutNoticeGivenDate: '05-10-2026',
          moveoutDate: '2026-10-31',
          leaseEnd: leaseEnd,
        );

    test('no answer: no leaseEnd key', () async {
      final r = await _capture(staffJson) as http.Request;
      expect((jsonDecode(r.body) as Map).containsKey('leaseEnd'), isFalse);
    });

    test('answer: leaseEnd sent top-level', () async {
      final r = await _capture(() => staffJson(leaseEnd: _leaseEnd))
          as http.Request;
      expect(jsonDecode(r.body), {
        'moveoutTenants': [
          {
            'admin_id': 'ADMIN-1',
            'tenant_id': 'T-1',
            'lease_id': 'L-1',
            'moveout_notice_given_date': '2026-10-05',
            'moveout_date': '2026-10-31',
          }
        ],
        'leaseEnd': _leaseEnd,
      });
    });
  });
}
