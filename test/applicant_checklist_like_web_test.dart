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
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/Applicants/Summary/SummaryContent.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/Summary/SummaryContent.dart'
    as admin;
import 'package:three_zero_two_property/services/applicant_checklist_rules.dart';

/// Leasing → Applicants → applicant → Summary → Application Checklist, like
/// web staging (ApplicantSummary.jsx): Save Changes with nothing changed says
/// "Nothing has changed, nothing will be saved" and sends nothing; a real
/// change saves with "Checklist saved successfully"; a blank custom item is
/// not added; and the five standard items carry web's labels. Before, Save
/// Changes always sent, a blank item became an empty row, the labels were in
/// lower case and the message was "Applicant Updated Successfully".

const _applicant = {
  '_id': 'X-1',
  'applicant_id': 'A-1',
  'admin_id': 'ADMIN-1',
  'applicant_firstName': 'Pat',
  'applicant_lastName': 'Lee',
  'applicant_email': 'pat@example.com',
  'applicant_phoneNumber': '5551112222',
  'applicant_checklist': ['Pet deposit'],
  'applicant_checkedChecklist': ['CreditCheck'],
  'applicant_NotesAndFile': [],
  'applicant_status': [],
  'isMovedin': false,
  'form_submitted': true,
};

final _saves = <http.Request>[];
final _toasts = <String>[];

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

final _server = MockClient((request) async {
  final path = request.url.path;
  if (request.method == 'PUT' &&
      path.startsWith('/api/applicant/applicant/A-1')) {
    _saves.add(request);
    return _json({'statusCode': 200, 'message': 'Applicant updated'});
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

List<http.Request> get _checkedSaves =>
    _saves.where((r) => r.url.path == '/api/applicant/applicant/A-1').toList();
List<http.Request> get _itemSaves => _saves
    .where((r) => r.url.path == '/api/applicant/applicant/A-1/checklist')
    .toList();

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 10);
}

final _saveChanges = find.widgetWithText(ElevatedButton, 'Save Changes');

/// The checkbox on the checklist row with this label.
Finder _tick(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.byType(Checkbox));

final _newItemBox = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Enter Value');

/// Opens the real Summary tab of a saved applicant.
Future<void> _open(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember',
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  // Through JSON so the lists can grow, as they do from the server.
  final applicant = applicant_summery_details
      .fromJson(jsonDecode(jsonEncode(_applicant)) as Map<String, dynamic>);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: isStaff
            ? staff.SummaryContent(summery: applicant, applicant_id: 'A-1')
            : admin.SummaryContent(summery: applicant, applicant_id: 'A-1'),
      ),
    ),
  ));
  await _settle(tester, 30);
  expect(find.text('Application Checklist'), findsOneWidget);
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    if (details.library == 'image resource service') return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("web's rules", () {
    test("web's labels and messages", () {
      expect(kApplicantChecklistLabels, {
        'CreditCheck': 'Credit and Background Check',
        'EmploymentVerification': 'Employment Verification',
        'ApplicationFee': 'Application Fee Collected',
        'IncomeVerification': 'Income Verification',
        'LandlordVerification': 'Landlord Verification',
      });
      expect(applicantChecklistNoChangesMessage,
          'Nothing has changed, nothing will be saved');
      expect(applicantChecklistSavedMessage, 'Checklist saved successfully');
    });

    test('the checked items are compared ignoring order and repeats', () {
      const saved = ['CreditCheck', 'Pet deposit'];
      expect(applicantChecklistChanged(['CreditCheck', 'Pet deposit'], saved),
          isFalse);
      expect(applicantChecklistChanged(['Pet deposit', 'CreditCheck'], saved),
          isFalse);
      expect(
          applicantChecklistChanged(
              ['CreditCheck', 'CreditCheck', 'Pet deposit'], saved),
          isFalse);
      expect(applicantChecklistChanged(['CreditCheck'], saved), isTrue);
      expect(
          applicantChecklistChanged(
              ['CreditCheck', 'Pet deposit', 'IncomeVerification'], saved),
          isTrue);
      expect(applicantChecklistChanged(['CreditCheck', 'ApplicationFee'], saved),
          isTrue,
          reason: 'same count, different item');
      expect(applicantChecklistChanged([], []), isFalse);
    });

    test('a blank custom item is not added', () {
      expect(isBlankChecklistItem(''), isTrue);
      expect(isBlankChecklistItem('   '), isTrue);
      expect(isBlankChecklistItem('Pet deposit'), isFalse);
    });
  });

  group('on the applicant Summary tab', () {
    setUp(() {
      _saves.clear();
      _toasts.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        final args = call.arguments;
        if (args is Map && args['msg'] != null) _toasts.add('${args['msg']}');
        return true;
      });
      ConnectivityPlatform.instance = _Online();
    });

    for (final isStaff in [false, true]) {
      final role = isStaff ? 'Staff' : 'Admin';

      testWidgets("$role: the five standard items carry web's labels",
          (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);
          for (final label in kApplicantChecklistLabels.values) {
            expect(find.text(label), findsOneWidget, reason: label);
          }
          expect(find.text('Credit and background check'), findsNothing);
        });
      });

      testWidgets('$role: Save Changes with nothing changed saves nothing; a '
          'real change saves with the checklist message', (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);

          // Nothing changed: web's message, nothing sent.
          await _tap(tester, _saveChanges);
          expect(_toasts, [applicantChecklistNoChangesMessage]);
          expect(_saves, isEmpty);

          // Ticked and unticked again: still nothing to save.
          await _tap(tester, _tick('Income Verification'));
          await _tap(tester, _tick('Income Verification'));
          _toasts.clear();
          await _tap(tester, _saveChanges);
          expect(_toasts, [applicantChecklistNoChangesMessage]);
          expect(_saves, isEmpty);

          // A real change saves as before, with web's checklist message.
          await _tap(tester, _tick('Income Verification'));
          _toasts.clear();
          await _tap(tester, _saveChanges);
          expect(_checkedSaves, hasLength(1));
          final sent = (jsonDecode(_checkedSaves.single.body)
              as Map<String, dynamic>)['applicant'] as Map<String, dynamic>;
          expect(sent['applicant_checkedChecklist'],
              unorderedEquals(['CreditCheck', 'IncomeVerification']));
          expect(_toasts, [applicantChecklistSavedMessage]);
          expect(_toasts, isNot(contains('Applicant Updated Successfully')));

          // What was just saved is now the saved checklist.
          _toasts.clear();
          await _tap(tester, _saveChanges);
          expect(_toasts, [applicantChecklistNoChangesMessage]);
          expect(_checkedSaves, hasLength(1));
        });
      });

      testWidgets('$role: a blank custom item is skipped; a named one is '
          'added and removed as before', (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);
          await _tap(tester, find.text('Add Checklist'));
          expect(_newItemBox, findsOneWidget);
          final confirm = find.byIcon(Icons.check);

          // Blank and spaces-only: nothing added, nothing sent, box stays.
          await _tap(tester, confirm);
          await tester.enterText(_newItemBox, '   ');
          await _tap(tester, confirm);
          expect(_itemSaves, isEmpty);
          expect(_newItemBox, findsOneWidget);
          expect(find.byType(Checkbox), findsNWidgets(6),
              reason: 'the five standard items and "Pet deposit" only');

          // A named item is added and saved straight away, as before.
          await tester.enterText(_newItemBox, 'Renters insurance');
          await _tap(tester, confirm);
          expect(_itemSaves, hasLength(1));
          expect(
              (jsonDecode(_itemSaves.single.body)
                  as Map<String, dynamic>)['applicant_checklist'],
              ['Pet deposit', 'Renters insurance']);
          expect(find.text('Renters insurance'), findsOneWidget);
          expect(find.byType(Checkbox), findsNWidgets(7));

          // Removing a custom item still saves straight away.
          final remove = find.descendant(
              of: find
                  .ancestor(
                      of: find.text('Renters insurance'),
                      matching: find.byType(Row))
                  .first,
              matching: find.byIcon(Icons.close));
          await _tap(tester, remove);
          expect(_itemSaves, hasLength(2));
          expect(
              (jsonDecode(_itemSaves.last.body)
                  as Map<String, dynamic>)['applicant_checklist'],
              ['Pet deposit']);
          expect(find.text('Renters insurance'), findsNothing);
        });
      });
    }
  });
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
