import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';
import 'package:three_zero_two_property/repository/Communication/lease_communication_repo.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/Recurring_Payments_Configuration_repo.dart';
import 'package:three_zero_two_property/repository/Scheduled_Payment_repo.dart';
import 'package:three_zero_two_property/repository/SettingWorkorder.dart';
import 'package:three_zero_two_property/repository/applicant_summery_repo.dart';
import 'package:three_zero_two_property/repository/appliance_note_service.dart';
import 'package:three_zero_two_property/repository/upcoming_renewal_repo.dart';
import 'package:three_zero_two_property/repository/vendor_repository.dart';

/// The server only accepts the logged-in user's OWN id in the `id` header
/// (VerifyToken.js, development-2.2): an admin id is honoured only with an
/// admin token. These shared repositories are reached from Staff screens, so a
/// Staff session must send staff_id while the company id stays in the URL or
/// body — and an Admin session must keep sending adminId exactly as before,
/// even when an earlier Staff session left a stale staff_id behind.

const _adminId = 'ADMIN-1';
const _staffId = 'STAFF-1';

const Map<String, Object> _adminPrefs = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Admin',
  // Left behind by an earlier Staff session; must be ignored for Admin.
  'staff_id': 'STALE-STAFF',
};

const Map<String, Object> _staffPrefs = {
  'token': 'tkn',
  'adminId': _adminId,
  'role': 'Staffmember',
  'staff_id': _staffId,
};

class _Case {
  final String name;
  final Future<Object?> Function() call;

  /// Where the company id must still appear: 'url', 'body' or null.
  final String? scopeIn;
  final String reply;

  const _Case(this.name, this.call,
      {this.scopeIn, this.reply = '{"statusCode":200,"data":[]}'});
}

/// Runs [call] against a fake server and returns the single request it sent.
Future<http.Request> _capture(
    Map<String, Object> prefs, _Case c) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sent = <http.Request>[];
  final client = MockClient((request) async {
    sent.add(request);
    return http.Response(c.reply, 200,
        headers: {'content-type': 'application/json'});
  });
  await http.runWithClient(() async {
    try {
      await c.call();
    } catch (_) {
      // Parsing the canned reply may fail; only the outgoing request matters.
    }
  }, () => client);
  expect(sent, hasLength(1), reason: '${c.name}: expected one request');
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

  final cases = <_Case>[
    _Case('Scheduled Payments - list',
        () => Scheduled_Payment_repo().fetchScheduled_Payment(),
        scopeIn: 'url'),
    _Case(
        'Scheduled Payments - delete',
        () => Scheduled_Payment_repo()
            .DeleteScheduled_Payment(pro_id: 'TASK-1', reason: 'r'),
        reply: '{"statusCode":200,"message":"ok"}'),
    _Case('Scheduled Payments - PDF header',
        () => GetAddressAdminPdfService().fetchAdminAddress(),
        scopeIn: 'url'),
    _Case('Upcoming Renewal',
        () => Upcoming_renewal_repo().fetchupcomingrenewal(),
        scopeIn: 'url'),
    _Case(
        'Appliance note - add',
        () => ApplianceNoteService()
            .addNote(applianceId: 'AP-1', noteText: 'note'),
        scopeIn: 'body'),
    _Case(
        'Appliance note - update',
        () => ApplianceNoteService()
            .updateNote(noteId: 'N-1', noteText: 'note', applianceId: 'AP-1')),
    _Case(
        'Appliance note - delete',
        () => ApplianceNoteService()
            .deleteNote(noteId: 'N-1', applianceId: 'AP-1')),
    _Case(
        'Applicant - Save Applicant',
        () => ApplicantSummeryRepository()
            .editApplicantSummaryForm(Data(), 'APP-1')),
    _Case('Lease Communication tab',
        () => EmailLogRepository().fetchEmailLog('LEASE-1')),
    _Case(
        'Recurring Payments Configuration report',
        () => Recurring_Payments_Configuration_Services()
            .fetchRecurringPaymentConfiguration(),
        scopeIn: 'url'),
    _Case('Settings - Work Order defaults', () => fetchWorkOrderSetting(),
        scopeIn: 'url'),
    _Case('Settings - vendor list',
        () => VendorRepository(baseUrl: '').getVendors(),
        scopeIn: 'url'),
  ];

  for (final c in cases) {
    group(c.name, () {
      test('Staff sends its own staff_id', () async {
        final request = await _capture(_staffPrefs, c);
        expect(request.headers['id'], 'CRM $_staffId');
        if (c.scopeIn == 'url') {
          expect(request.url.toString(), contains(_adminId));
        } else if (c.scopeIn == 'body') {
          expect(request.body, contains(_adminId));
        }
      });

      test('Admin still sends adminId (stale staff_id ignored)', () async {
        final request = await _capture(_adminPrefs, c);
        expect(request.headers['id'], 'CRM $_adminId');
        if (c.scopeIn == 'url') {
          expect(request.url.toString(), contains(_adminId));
        } else if (c.scopeIn == 'body') {
          expect(request.body, contains(_adminId));
        }
      });
    });
  }
}
