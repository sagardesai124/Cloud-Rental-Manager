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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Property Tax/Add_property_Tax.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Property Tax/Add_property_Tax.dart'
    as admin;
import 'package:three_zero_two_property/services/web_parse_float.dart';

/// Property Tax → Assessment Value, like web staging. Web's check is
/// `parseFloat(value)` must be a number ≥ 0, and it saves `parseFloat(value)`:
/// so "1.2.3" is accepted and saved as 1.2, while "." shows "Assessment Value
/// must be a valid number" and is not saved. The app used to accept anything
/// and save 0 for a value it could not read.
///
/// Edit's "No changes were made" check reads the value the same way, so
/// "1.2.3" typed over a stored 0 is a change (it used to be refused). An
/// exponent counts like parseFloat ("1e5" = 100000), so a very large stored
/// value, which shows as "1e+21", is saved back unchanged (it used to save 1).

/// The body of every create request the screen sends.
final List<Map<String, dynamic>> _saved = [];

/// The path and body of every update request the screen sends.
final List<String> _updatedPaths = [];
final List<Map<String, dynamic>> _updated = [];

/// A saved tax record, as Edit opens it.
const _existing = <String, dynamic>{
  '_id': 'T-1',
  'tax_year': 2025,
  'tax_amount': 100,
  'assessment_value': 1500,
  'tax_authority': 'County',
  'status': 'Due',
  'notes': '',
};

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/taxes' && request.method == 'POST') {
    _saved.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response(jsonEncode({'success': true, 'data': {}}), 201,
        headers: {'content-type': 'application/json'});
  }
  if (path.startsWith('/api/taxes/') && request.method == 'PUT') {
    _updatedPaths.add(path);
    _updated.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response(jsonEncode({'success': true, 'data': {}}), 200,
        headers: {'content-type': 'application/json'});
  }
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'}
    };
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {'staff_permission': {}}
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder _field(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

/// Opens the real Property Tax screen: Add, or Edit when [taxId] is given.
Future<void> _pumpScreen(WidgetTester tester,
    {required bool isStaff,
    String? taxId,
    Map<String, dynamic>? taxData}) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember'
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  final permissions = StaffPermissionProvider();
  await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider<StaffPermissionProvider>.value(
          value: permissions),
    ],
    child: MaterialApp(
      home: isStaff
          ? staff.Add_property_Tax(
              propertyId: 'P-1', taxId: taxId, taxData: taxData)
          : admin.Add_property_Tax(
              propertyId: 'P-1', taxId: taxId, taxData: taxData),
    ),
  ));
  await _settle(tester);
}

/// Opens the real Add Property Tax screen and fills a valid year and amount.
Future<void> _open(WidgetTester tester, {required bool isStaff}) async {
  await _pumpScreen(tester, isStaff: isStaff);

  final year = DateTime.now().year.toString();
  await tester.tap(find.text('Select tax year'));
  await _settle(tester, 10);
  await tester.tap(find.text(year).last);
  await _settle(tester, 10);
  await tester.enterText(_field('\$ Enter Tax amount'), '100');
  await _settle(tester, 4);
}

Future<void> _save(WidgetTester tester, String assessment,
    {String button = 'Save'}) async {
  await tester.enterText(_field('\$ Enter assessment value'), assessment);
  await _settle(tester, 4);
  final save = find.text(button).last;
  await tester.ensureVisible(save);
  await tester.pump();
  await tester.tap(save, warnIfMissed: false);
  await _settle(tester, 20);
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  // Layout overflow (test font) and images (no decoding in tests) are noise
  // here.
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

  setUp(() {
    _saved.clear();
    _updated.clear();
    _updatedPaths.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  test('reads numbers like JavaScript parseFloat', () {
    // Expected values are what parseFloat returns in a browser.
    const cases = <String, double?>{
      '1.2.3': 1.2,
      '1500.50': 1500.5,
      '1.': 1,
      '.5': 0.5,
      '007': 7,
      '\$1,200.5': 1200.5,
      '.': null,
      '..5': null,
      '': null,
      // Exponents, like parseFloat.
      '1e5': 100000,
      '1.2e3': 1200,
      '1E5': 100000,
      '1e+21': 1e21,
      '1e-7': 1e-7,
      '.5e1': 5,
      '1.e2': 100,
      '-1e2': -100,
      '1.2e3.4': 1200,
      '1e5e6': 100000,
      '1e': 1,
      '1e+': 1,
      'e5': null,
    };
    cases.forEach((text, expected) {
      expect(parseFloatLikeWeb(text), expected, reason: '"$text"');
    });
  });

  for (final isStaff in [false, true]) {
    final who = isStaff ? 'Staff' : 'Admin';

    testWidgets('$who: "1.2.3" saves 1.2, like web', (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff: isStaff);
        await _save(tester, '1.2.3');
        expect(find.text('Assessment Value must be a valid number'),
            findsNothing);
        expect(_saved, hasLength(1));
        expect(_saved.single['assessment_value'], 1.2);
        expect(_saved.single['tax_amount'], 100.0);
      });
    });

    testWidgets('$who: "." shows web\'s message and does not save',
        (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff: isStaff);
        await _save(tester, '.');
        expect(find.text('Assessment Value must be a valid number'),
            findsOneWidget);
        expect(_saved, isEmpty);
      });
    });

    testWidgets('$who: a normal value and an empty one save as before',
        (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff: isStaff);
        await _save(tester, '1500.50');
        expect(_saved.single['assessment_value'], 1500.5);
      });
      _saved.clear();
      await _run(tester, () async {
        await _open(tester, isStaff: isStaff);
        await _save(tester, '');
        expect(_saved.single['assessment_value'], 0.0);
      });
    });

    // Web uses the same form, check and save for Edit (PUT /taxes/{id}).
    testWidgets('$who Edit: "1.2.3" updates the record to 1.2, like web',
        (tester) async {
      await _run(tester, () async {
        await _pumpScreen(tester,
            isStaff: isStaff, taxId: 'T-1', taxData: _existing);
        expect(find.text('Edit Tax Record'), findsOneWidget);
        await _save(tester, '1.2.3', button: 'Update');
        expect(find.text('Assessment Value must be a valid number'),
            findsNothing);
        expect(_updatedPaths, ['/api/taxes/T-1']);
        expect(_updated.single['assessment_value'], 1.2);
        expect(_updated.single['tax_amount'], 100.0);
        expect(_saved, isEmpty);
      });
    });

    testWidgets('$who Edit: "1.2.3" over a stored 0 is a change and saves 1.2',
        (tester) async {
      await _run(tester, () async {
        await _pumpScreen(tester,
            isStaff: isStaff,
            taxId: 'T-1',
            taxData: {..._existing, 'assessment_value': 0});
        await _save(tester, '1.2.3', button: 'Update');
        expect(_updatedPaths, ['/api/taxes/T-1'],
            reason: 'not refused as "No changes were made"');
        expect(_updated.single['assessment_value'], 1.2);
      });
    });

    testWidgets('$who Edit: nothing changed still says "No changes were made"',
        (tester) async {
      await _run(tester, () async {
        // Left as loaded, then retyped as "1500.0.0" (still 1500): no update.
        for (final typed in const [null, '1500.0.0']) {
          _updated.clear();
          _updatedPaths.clear();
          await _pumpScreen(tester,
              isStaff: isStaff, taxId: 'T-1', taxData: _existing);
          if (typed == null) {
            final update = find.text('Update').last;
            await tester.ensureVisible(update);
            await tester.pump();
            await tester.tap(update, warnIfMissed: false);
            await _settle(tester, 20);
          } else {
            await _save(tester, typed, button: 'Update');
          }
          expect(_updatedPaths, isEmpty, reason: '$typed');
          expect(_saved, isEmpty);
        }
      });
    });

    testWidgets('$who Edit: a stored 1e+21 is saved back unchanged',
        (tester) async {
      await _run(tester, () async {
        await _pumpScreen(tester,
            isStaff: isStaff,
            taxId: 'T-1',
            taxData: {..._existing, 'assessment_value': 1e21});
        expect(find.text('1e+21'), findsOneWidget);
        // Only the Tax Amount changes; the assessment box is left as loaded.
        await tester.enterText(_field('\$ Enter Tax amount'), '200');
        await _settle(tester, 4);
        final update = find.text('Update').last;
        await tester.ensureVisible(update);
        await tester.pump();
        await tester.tap(update, warnIfMissed: false);
        await _settle(tester, 20);
        expect(_updatedPaths, ['/api/taxes/T-1']);
        expect(_updated.single['tax_amount'], 200.0);
        expect(_updated.single['assessment_value'], 1e21);
      });
    });

    testWidgets('$who Edit: "." shows web\'s message and does not update',
        (tester) async {
      await _run(tester, () async {
        await _pumpScreen(tester,
            isStaff: isStaff, taxId: 'T-1', taxData: _existing);
        await _save(tester, '.', button: 'Update');
        expect(find.text('Assessment Value must be a valid number'),
            findsOneWidget);
        expect(_updated, isEmpty);
        expect(_saved, isEmpty);
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
