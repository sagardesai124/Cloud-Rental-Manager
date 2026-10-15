import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/Applicants/Summary/applicant_summery2.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/Summary/applicant_summery2.dart'
    as admin;

/// The applicant Summary's status actions follow web (ApplicantSummary.jsx),
/// Admin and Staff, against a fake server:
///  - submitted application: Approve Applicant + Reject Applicant
///  - draft: "incomplete" note, Send Completion Reminder Email, Reject
///    (sent as web's draft rejection)
///  - never submitted: no Approve, also after a rejection
/// Each action sends once, with a spinner, and the page reloads.

const _incomplete =
    'This application is incomplete and can not be accepted at this time.';

final List<String> _toasts = [];

class _Server {
  _Server({
    this.status = 'Undecided',
    this.submitted = false,
    this.draft = false,
    this.reminderFails = false,
    this.movedIn = false,
  });
  String status;
  final bool submitted;
  final bool draft;
  final bool reminderFails;
  final bool movedIn;
  final List<http.Request> requests = [];
  Completer<void>? gate;

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/api/auth') {
      return _json({
        'statusCode': 200,
        'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
      });
    }
    if (path == '/api/applicant/applicant_summary/A-1') {
      return _json({
        'statusCode': 200,
        'data': [
          {
            'applicant_id': 'A-1',
            'admin_id': 'ADMIN-1',
            'applicant_firstName': 'Pat',
            'applicant_lastName': 'Lee',
            'applicant_email': 'pat@example.com',
            'applicant_phoneNumber': '5551234567',
            'applicant_checklist': [],
            'applicant_checkedChecklist': [],
            'applicant_NotesAndFile': [],
            'isMovedin': movedIn,
            'form_submitted': submitted,
            'draft_saved': draft,
            'applicant_status': [
              {'status': status, 'updateAt': '2026-10-14 10:00:00'}
            ],
            'lease_data': {
              'lease_id': 'L-1',
              'rental_id': 'R-1',
              'unit_id': 'U-1',
              'rental_adress': '1 Test Street',
            },
          }
        ],
      });
    }
    if (path == '/api/applicant/applicant/A-1/status' ||
        path == '/api/applicant/applicant/A-1/reject-draft') {
      if (gate != null) await gate!.future;
      final body = jsonDecode(request.body) as Map;
      status = path.endsWith('reject-draft') ? 'Rejected' : '${body['status']}';
      return _json({
        'statusCode': 200,
        'message': path.endsWith('reject-draft')
            ? 'Draft Applicant Rejected Successfully'
            : 'Status updated'
      });
    }
    if (path == '/api/applicant/applicant/completion-reminder/A-1') {
      if (gate != null) await gate!.future;
      if (reminderFails) {
        return http.Response(
            jsonEncode({
              'statusCode': 400,
              'message': 'Email configuration not found'
            }),
            400,
            headers: {'content-type': 'application/json'});
      }
      return _json({'statusCode': 200, 'message': 'Mail Sent Successfully'});
    }
    return _json({'statusCode': 200, 'data': []});
  });

  List<http.Request> sent(String suffix) => requests
      .where((r) =>
          r.method != 'GET' && r.url.path == '/api/applicant/applicant/$suffix')
      .toList();
  int get summaryLoads => requests
      .where((r) => r.url.path == '/api/applicant/applicant_summary/A-1')
      .length;
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 16]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _open(WidgetTester tester, bool isStaff) async {
  tester.view.physicalSize = const Size(430, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  final permissions = StaffPermissionProvider();
  if (isStaff) await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(value: permissions),
      ChangeNotifierProvider(create: (_) => SelectedTenantsProvider()),
      ChangeNotifierProvider(create: (_) => SelectedCosignersProvider()),
    ],
    child: MaterialApp(
      home: isStaff
          ? staff.applicant_summery(applicant_id: 'A-1')
          : admin.applicant_summery(applicant_id: 'A-1'),
    ),
  ));
  await _settle(tester, 30);
  expect(find.text('Pat Lee'), findsWidgets, reason: 'summary loaded');
}

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.text(label);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      if (call.method == 'showToast') {
        _toasts.add('${(call.arguments as Map)['msg']}');
      }
      return true;
    });
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<void> run(WidgetTester tester, _Server server,
      Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(body, () => server.client);
      if (server.gate != null && !server.gate!.isCompleted) {
        server.gate!.complete();
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  for (final isStaff in [false, true]) {
    final who = isStaff ? 'Staff' : 'Admin';
    group(who, () {
      setUp(() {
        SharedPreferences.setMockInitialValues(isStaff
            ? {
                'token': 'tkn',
                'adminId': 'ADMIN-1',
                'staff_id': 'STAFF-1',
                'role': 'Staffmember'
              }
            : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      });

      testWidgets(
          'submitted: Approve sends once with a spinner, page reloads to '
          'Create Lease', (tester) async {
        final server = _Server(submitted: true)..gate = Completer<void>();
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text('Approve Applicant'), findsOneWidget);
          expect(find.text('Reject Applicant'), findsOneWidget);
          expect(find.text(_incomplete), findsNothing);
          final loads = server.summaryLoads;

          await _tap(tester, 'Approve Applicant');
          expect(find.byType(CircularProgressIndicator), findsWidgets,
              reason: 'spinner while approving');
          expect(find.text('Approve Applicant'), findsNothing);
          await _settle(tester, 4);
          // Reject is ignored while approving.
          await _tap(tester, 'Reject Applicant');
          expect(find.text('Reject Applicant'), findsOneWidget,
              reason: 'no reject dialog opened');

          server.gate!.complete();
          await _settle(tester, 30);
          expect(server.sent('A-1/status'), hasLength(1));
          final body = jsonDecode(server.sent('A-1/status').single.body) as Map;
          expect(body['status'], 'Approved');
          expect(body['rental_id'], 'R-1');
          expect(_toasts,
              contains('The Applicant Status has been changed to Approved'));
          expect(server.summaryLoads, greaterThan(loads));
          expect(find.text('Create Lease'), findsOneWidget);
          expect(find.text('Approve Applicant'), findsNothing);
          // Web's Summary tab offers Change to Reject once approved.
          expect(find.text('Change to Reject'), findsOneWidget);
        });
      });

      testWidgets('submitted: Reject asks for a reason and sends the status',
          (tester) async {
        final server = _Server(submitted: true);
        await run(tester, server, () async {
          await _open(tester, isStaff);
          await _tap(tester, 'Reject Applicant');
          await _settle(tester, 10);
          final reason = find.byWidgetPredicate((w) =>
              w is TextField &&
              w.decoration?.hintText == 'Enter reason for rejection');
          expect(reason, findsOneWidget, reason: 'reason popup open');
          // Web: Reject Applicant does nothing until a reason is typed.
          await tester.tap(find.text('Reject Applicant').last);
          await _settle(tester, 10);
          expect(reason, findsOneWidget, reason: 'popup still open');
          expect(server.sent('A-1/status'), isEmpty);
          await tester.enterText(reason, 'Low income');
          await tester.pump();
          await tester.tap(find.text('Reject Applicant').last);
          await _settle(tester, 30);
          expect(server.sent('A-1/reject-draft'), isEmpty);
          final body = jsonDecode(server.sent('A-1/status').single.body) as Map;
          expect(body['status'], 'Rejected');
          expect(body['rejection_reason'], 'Low income');
          expect(_toasts, contains('Applicant status changed to Rejected'));
          // Rejected but submitted: Approve is offered again, with Reject
          // Applicant shown disabled, as on web.
          expect(find.text('Approve Applicant'), findsOneWidget);
          expect(find.text('Reject Applicant'), findsOneWidget);
          await _tap(tester, 'Reject Applicant');
          await _settle(tester, 10);
          expect(reason, findsNothing, reason: 'disabled: no popup');
        });
      });

      testWidgets(
          'draft: incomplete note, reminder sends once, Reject uses the '
          'draft rejection; no Approve', (tester) async {
        final server = _Server(draft: true)..gate = Completer<void>();
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text(_incomplete), findsOneWidget);
          expect(find.text('Send Completion Reminder Email'), findsOneWidget);
          expect(find.text('Reject Applicant'), findsOneWidget);
          expect(find.text('Approve Applicant'), findsNothing);

          await _tap(tester, 'Send Completion Reminder Email');
          expect(find.text('Send Completion Reminder Email'), findsNothing,
              reason: 'spinner while sending');
          server.gate!.complete();
          await _settle(tester, 30);
          expect(server.sent('completion-reminder/A-1'), hasLength(1));
          expect(_toasts, contains('Completion reminder email sent successfully'));

          await _tap(tester, 'Reject Applicant');
          await _settle(tester, 10);
          await tester.enterText(find.byType(TextField).last, 'No reply');
          await tester.pump();
          await tester.tap(find.text('Reject Applicant').last);
          await _settle(tester, 30);
          expect(server.sent('A-1/status'), isEmpty,
              reason: 'a draft is not rejected through the status call');
          final body =
              jsonDecode(server.sent('A-1/reject-draft').single.body) as Map;
          expect(body['rejection_reason'], 'No reply');
          expect(body['rental_id'], 'R-1');
          expect(_toasts, contains('Draft Applicant Rejected Successfully'));
        });
      });

      testWidgets('draft: a failed reminder shows the server reason',
          (tester) async {
        final server = _Server(draft: true, reminderFails: true);
        await run(tester, server, () async {
          await _open(tester, isStaff);
          await _tap(tester, 'Send Completion Reminder Email');
          await _settle(tester, 20);
          expect(_toasts, contains('Email configuration not found'));
          expect(find.text('Send Completion Reminder Email'), findsOneWidget,
              reason: 'button back for another try');
        });
      });

      testWidgets('never submitted: no Approve or Reject, as on web',
          (tester) async {
        final server = _Server();
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text('Approve Applicant'), findsNothing);
          expect(find.text('Reject Applicant'), findsNothing);
          expect(find.text(_incomplete), findsNothing);
        });
      });

      testWidgets('rejected, never submitted: no Approve', (tester) async {
        final server = _Server(status: 'Rejected');
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text('Approve Applicant'), findsNothing);
        });
      });

      testWidgets(
          'approved: Create Lease + Change to Reject, which asks for a reason '
          'and sends the status', (tester) async {
        final server = _Server(status: 'Approved', submitted: true);
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text('Create Lease'), findsOneWidget);
          expect(find.text('Change to Reject'), findsOneWidget);
          expect(find.text('Approve Applicant'), findsNothing);
          expect(find.text(_incomplete), findsNothing);

          await _tap(tester, 'Change to Reject');
          await _settle(tester, 10);
          await tester.enterText(find.byType(TextField).last, 'Changed mind');
          await tester.pump();
          await tester.tap(find.text('Reject Applicant').last);
          await _settle(tester, 30);
          expect(server.sent('A-1/reject-draft'), isEmpty);
          final body = jsonDecode(server.sent('A-1/status').single.body) as Map;
          expect(body['status'], 'Rejected');
          expect(body['rejection_reason'], 'Changed mind');
          expect(_toasts, contains('Applicant status changed to Rejected'));
          expect(find.text('Create Lease'), findsNothing);
        });
      });

      testWidgets(
          'approved but back in draft: incomplete note with Reminder and '
          'Reject, plus Create Lease; no Change to Reject', (tester) async {
        final server = _Server(status: 'Approved', draft: true);
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text(_incomplete), findsOneWidget);
          expect(find.text('Send Completion Reminder Email'), findsOneWidget);
          expect(find.text('Create Lease'), findsOneWidget);
          expect(find.text('Change to Reject'), findsNothing);

          await _tap(tester, 'Reject Applicant');
          await _settle(tester, 10);
          await tester.enterText(find.byType(TextField).last, 'Incomplete');
          await tester.pump();
          await tester.tap(find.text('Reject Applicant').last);
          await _settle(tester, 30);
          expect(server.sent('A-1/status'), isEmpty);
          expect(server.sent('A-1/reject-draft'), hasLength(1));
        });
      });

      testWidgets(
          'moved in but back in draft: incomplete note with Reminder and '
          'Reject next to Lease Created, as on web', (tester) async {
        final server = _Server(status: 'Approved', draft: true, movedIn: true);
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text(_incomplete), findsOneWidget);
          expect(find.text('Send Completion Reminder Email'), findsOneWidget);
          expect(find.text('Lease Created'), findsOneWidget);
          expect(find.text('Create Lease'), findsNothing);
          expect(find.text('Change to Reject'), findsNothing);

          // Web leaves Reject enabled here; it uses the draft rejection.
          await _tap(tester, 'Reject Applicant');
          await _settle(tester, 10);
          await tester.enterText(find.byType(TextField).last, 'Withdrawn');
          await tester.pump();
          await tester.tap(find.text('Reject Applicant').last);
          await _settle(tester, 30);
          expect(server.sent('A-1/status'), isEmpty);
          expect(server.sent('A-1/reject-draft'), hasLength(1));
        });
      });

      testWidgets('moved in: only Lease Created', (tester) async {
        final server =
            _Server(status: 'Approved', submitted: true, movedIn: true);
        await run(tester, server, () async {
          await _open(tester, isStaff);
          expect(find.text('Lease Created'), findsOneWidget);
          expect(find.text('Create Lease'), findsNothing);
          expect(find.text('Change to Reject'), findsNothing);
          expect(find.text('Reject Applicant'), findsNothing);
        });
      });
    });
  }
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
