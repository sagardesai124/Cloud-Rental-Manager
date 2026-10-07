import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/Addmortgage.dart'
    as admin;
import 'package:three_zero_two_property/StaffModule/screen/Rental/mortgage/Addmortgage.dart'
    as staff;

/// When Add/Edit Mortgage cannot load its property list, it must behave like
/// web (Mortgage.jsx): no made-up properties, and an edited mortgage keeps the
/// properties it is linked to (web keeps mortgage.properties as-is). Before,
/// the screen filled the list with three hardcoded test properties, so an
/// edit could not match the mortgage's real properties and saving sent an
/// empty list — and if the request failed outright the edit form stayed blank.

/// A mortgage with every required field, linked to property R-9, as the
/// Mortgage list passes it (properties are rental ids).
const _mortgage = {
  'properties': ['R-9'],
  'bank_name': 'First Bank',
  'mortgage_no': 'LN-1',
  'mortgage_type': 'floating_rate',
  'start_date': '2024-01-01',
  'end_date': '2054-01-01',
  'loan_amount': 250000,
  'remaining_balance': 240000,
  'monthly_principal': 800,
  'monthly_interest': 400,
};

/// The same mortgage as the Mortgage Summary passes it to Edit: the details
/// endpoint (MortgageController.getMortgageDetails) returns property OBJECTS.
final _mortgageFromSummary = <String, dynamic>{
  ..._mortgage,
  'properties': [
    {'rental_id': 'R-9', 'address': '9 Real Street', 'city': 'Austin'}
  ],
};

enum _PropertyList { loaded, refused, offline }

bool _isMortgageSave(http.Request r) =>
    (r.method == 'POST' || r.method == 'PUT') &&
    r.url.path.startsWith('/api/mortgage');

class _Run {
  final List<http.Request> requests = [];
  late final MockClient client;

  _Run(_PropertyList list) {
    client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/mortgage/properties/list') {
        if (list == _PropertyList.offline) {
          throw http.ClientException('offline', request.url);
        }
        if (list == _PropertyList.loaded) {
          return http.Response(
              jsonEncode({
                'statusCode': 200,
                'data': [
                  {'rental_id': 'R-9', 'address': '9 Real Street'}
                ]
              }),
              200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}), 401,
            headers: {'content-type': 'application/json'});
      }
      if (_isMortgageSave(request)) {
        // Refuse the save itself so the screen stays put; only its body
        // is under test.
        return http.Response(
            jsonEncode({'statusCode': 400, 'message': 'not saved in test'}),
            400,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'statusCode': 200, 'data': []}), 200,
          headers: {'content-type': 'application/json'});
    });
  }

  Iterable<http.Request> get writes => requests.where(_isMortgageSave);
}

Future<void> _pumpEdit(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DateProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: MaterialApp(home: screen),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The test font draws every glyph as a full em square, so rows that fit on
/// a device overflow here; that layout noise is ignored.
Future<void> _withClient(_Run run, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => run.client);
  } finally {
    FlutterError.onError = original;
  }
}

/// Taps Update and returns the properties the save request sent.
Future<Object?> _savedProperties(WidgetTester tester, _Run run) async {
  final update = find.text('Update');
  await tester.ensureVisible(update);
  await tester.pump();
  await tester.tap(update);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(run.writes, hasLength(1), reason: 'Update should send once');
  return (jsonDecode(run.writes.single.body) as Map<String, dynamic>)[
      'properties'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final modules = <String,
      ({Map<String, Object> prefs, Widget Function(Map<String, dynamic>) edit})>{
    'Admin': (
      prefs: {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'},
      edit: (data) =>
          admin.AddMortgageScreen(mortgageId: 'M-1', mortgageData: data),
    ),
    'Staff': (
      prefs: {
        'token': 'tkn',
        'adminId': 'ADMIN-1',
        'role': 'Staffmember',
        'staff_id': 'STAFF-1'
      },
      edit: (data) =>
          staff.AddMortgageScreen(mortgageId: 'M-1', mortgageData: data),
    ),
  };

  modules.forEach((name, module) {
    group(name, () {
      testWidgets('list refused: saving an edit keeps its linked property',
          (tester) async {
        SharedPreferences.setMockInitialValues(module.prefs);
        final run = _Run(_PropertyList.refused);
        await _withClient(run, () async {
          await _pumpEdit(tester, module.edit(_mortgage));
          expect(await _savedProperties(tester, run), ['R-9'],
              reason: 'the mortgage must stay linked to its property');
          await tester.pumpWidget(const SizedBox());
        });
      });

      for (final list in [_PropertyList.loaded, _PropertyList.refused]) {
        testWidgets(
            'edit from Summary (property objects), list ${list.name}: '
            'saving keeps the real rental id', (tester) async {
          SharedPreferences.setMockInitialValues(module.prefs);
          final run = _Run(list);
          await _withClient(run, () async {
            await _pumpEdit(tester, module.edit(_mortgageFromSummary));
            expect(await _savedProperties(tester, run), ['R-9']);
            await tester.pumpWidget(const SizedBox());
          });
        });
      }

      testWidgets('request fails outright: the edit form is still filled',
          (tester) async {
        SharedPreferences.setMockInitialValues(module.prefs);
        final run = _Run(_PropertyList.offline);
        await _withClient(run, () async {
          await _pumpEdit(tester, module.edit(_mortgage));
          expect(find.text('First Bank'), findsOneWidget);
          expect(find.text('LN-1'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        });
      });
    });
  });
}
