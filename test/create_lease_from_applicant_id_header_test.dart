import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/model/lease.dart';
import 'package:three_zero_two_property/repository/lease.dart';

/// Lou's trace (10/6): Staff "Create Lease" from an applicant opens the ADMIN
/// Add Lease screen (addLease3), which loads the lease, saves it and marks the
/// applicant moved in through the shared lease repository. All three sent
/// `id: CRM <adminId>`, which the server (VerifyToken.js, production since
/// 10/5) refuses with a staff token. A Staff session must send its own
/// staff_id; an Admin session keeps adminId, even with a stale staff_id left
/// behind by an earlier Staff login.

const _adminId = 'ADMIN-1';
const _staffId = 'STAFF-1';

const Map<String, Object> _staffPrefs = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Staffmember',
  'staff_id': _staffId,
};

const Map<String, Object> _adminPrefsWithStaleStaffId = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Admin',
  'staff_id': 'STALE-STAFF',
};

/// postLease only serialises the lease; a real one isn't needed here.
class _FakeLease implements Lease {
  @override
  Map<String, dynamic> toJson() => {
        'leaseData': {'admin_id': _adminId}
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs [call] against a fake server and returns the single request it sent.
Future<http.Request> _capture(Future<void> Function() call,
    {int status = 200}) async {
  final sent = <http.Request>[];
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(
        jsonEncode({'statusCode': status, 'message': 'ok'}), status,
        headers: {'content-type': 'application/json'});
  });
  await http.runWithClient(call, () => client);
  expect(sent, hasLength(1));
  return sent.single;
}

Future<http.Request> _fetchLeaseDetails() => _capture(() async {
      // The fake server answers 404 so the parse is skipped; only the request
      // matters here.
      await expectLater(
          LeaseRepository().fetchLeaseDetails('L-1', applicantId: 'AP-1'),
          throwsA(isA<Exception>()));
    }, status: 404);

Future<http.Request> _postLease() =>
    _capture(() => LeaseRepository().postLease(_FakeLease()));

Future<http.Request> _moveIn() => _capture(
    () => LeaseRepository().ifApplicantMoveInTrue('AP-1', ['AP-1']));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Fluttertoast talks to a platform channel; answer it so toasts no-op.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  group('Staff session (staff opens Create Lease from an applicant)', () {
    setUp(() => SharedPreferences.setMockInitialValues(_staffPrefs));

    test('load lease: own staff_id', () async {
      final r = await _fetchLeaseDetails();
      expect(r.url.path, '/api/leases/get_lease/L-1');
      expect(r.url.queryParameters['applicant_id'], 'AP-1');
      expect(r.headers['id'], 'CRM $_staffId');
    });

    test('save lease: own staff_id, company id stays in the body', () async {
      final r = await _postLease();
      expect(r.method, 'POST');
      expect(r.url.path, '/api/leases/leases');
      expect(r.headers['id'], 'CRM $_staffId');
      expect(jsonDecode(r.body)['leaseData']['admin_id'], _adminId);
    });

    test('mark applicant moved in: own staff_id', () async {
      final r = await _moveIn();
      expect(r.method, 'PUT');
      expect(r.url.path, '/api/applicant/applicant-movein');
      expect(r.headers['id'], 'CRM $_staffId');
    });
  });

  group('Admin session keeps adminId (stale staff_id ignored)', () {
    setUp(() =>
        SharedPreferences.setMockInitialValues(_adminPrefsWithStaleStaffId));

    test('load lease', () async {
      expect((await _fetchLeaseDetails()).headers['id'], 'CRM $_adminId');
    });

    test('save lease', () async {
      expect((await _postLease()).headers['id'], 'CRM $_adminId');
    });

    test('mark applicant moved in', () async {
      expect((await _moveIn()).headers['id'], 'CRM $_adminId');
    });
  });
}
