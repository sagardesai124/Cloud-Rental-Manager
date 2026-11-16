import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

/// Settings → Late Fees, like web staging (Settings.jsx latefeeFormik and
/// LateFeeSection.jsx): a late fee rule, company-wide or a Property Owner
/// override, can't be saved without Number of Grace Period Days ("Required")
/// or the fee for the selected calculation ("Amount is required" /
/// "Percentage is required"); the message shows under the box and nothing
/// is sent. Before, the app sent the empty boxes and the server stored them
/// as 0 days and a 0 fee.

/// What the fake server holds and was sent.
bool _hasLateFee = true;
final List<http.Request> _saves = [];

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'}
    };
  } else if (path.startsWith('/api/latefee/latefee')) {
    if (request.method == 'GET') {
      body = _hasLateFee
          ? {
              'statusCode': 200,
              'data': {
                '_id': 'L-1',
                'admin_id': 'ADMIN-1',
                'createdAt': '2026-10-01T10:00:00.000Z',
                'updatedAt': '2026-10-01T10:00:00.000Z',
                'is_delete': false,
                '__v': 0,
                'latefee_id': 'LF-1',
                'duration': 5,
                'late_fee': 25,
                'grace_balance': 0,
                'calculation_type': 'fixed',
                'charge_account': 'Late Fee Income',
                'description': '',
              }
            }
          // No company late fee yet: the first save adds one.
          : {'statusCode': 201, 'message': 'Late fee not found'};
    } else {
      _saves.add(request);
      body = {'statusCode': 200, 'message': 'Late Fee Data Updated Successfully'};
    }
  } else if (path == '/api/property-owner-overrides/list/ADMIN-1') {
    body = {
      'statusCode': 200,
      'data': [
        {'rentalowner_id': 'RO-1', 'rentalOwner_name': 'Pat Owner'}
      ]
    };
  } else if (path == '/api/property-owner-overrides') {
    _saves.add(request);
    body = {'statusCode': 200, 'message': 'Override saved'};
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {
        'staff_permission': {'setting_view': true}
      }
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

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 20);
}

final _grace = find.byWidgetPredicate((w) =>
    w is TextField &&
    w.decoration?.hintText == '0' &&
    w.keyboardType == const TextInputType.numberWithOptions(decimal: false));
// Amount ($) is the first box with a "$" in front (Min. Balance is the
// second); Percentage (%) is the box ending in "%".
final _amount = find
    .byWidgetPredicate(
        (w) => w is TextField && w.decoration?.prefixIcon != null)
    .first;
final _percentage = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.suffixText == '%');

Future<void> _type(WidgetTester tester, Finder box, String text) async {
  await tester.ensureVisible(box);
  await tester.enterText(box, text);
  await _settle(tester, 5);
}

Future<void> _save(WidgetTester tester) => _tap(tester, 'Save');

Map<String, dynamic> _sent(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// Opens the real Settings screen on its Late Fees section as Admin.
Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    if (details.library == 'image resource service') return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
      tester.view.physicalSize = const Size(430, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final dates = DateProvider();
      await dates.loadDateFormat();
      final permissions = StaffPermissionProvider();
      await permissions.fetchPermissions();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DateProvider>.value(value: dates),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider<StaffPermissionProvider>.value(
              value: permissions),
        ],
        child: const MaterialApp(home: TabBarExample()),
      ));
      await _settle(tester, 40);
      await _tap(tester, 'Late Fees');
      await _settle(tester, 20);
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

  group("web's messages", () {
    test('grace period', () {
      expect(kLateFeeGraceRequiredMessage, 'Required');
      expect(lateFeeGraceProblem(''), 'Required');
      expect(lateFeeGraceProblem('   '), 'Required');
      expect(lateFeeGraceProblem('0'), isNull, reason: '0 days is allowed');
      expect(lateFeeGraceProblem('5'), isNull);
    });

    test('fee, for the selected calculation', () {
      expect(lateFeeAmountProblem('', calculationType: 'fixed'),
          'Amount is required');
      expect(lateFeeAmountProblem(' ', calculationType: 'percent'),
          'Percentage is required');
      expect(lateFeeAmountProblem('', calculationType: ''),
          'Amount is required',
          reason: 'web: anything but "percent" is an amount');
      expect(lateFeeAmountProblem('.', calculationType: 'fixed'),
          'Amount must be a number');
      expect(lateFeeAmountProblem('1.2.3', calculationType: 'percent'),
          'Percentage must be a number');
      for (final ok in ['0', '25', '2.5', '1,250.50']) {
        expect(lateFeeAmountProblem(ok, calculationType: 'fixed'), isNull,
            reason: ok);
      }
    });
  });

  group('on the Admin Late Fees screen', () {
    setUp(() {
      _hasLateFee = true;
      _saves.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    testWidgets('company late fee: an empty grace period or fee is refused '
        'with web\'s message; filled in, it saves', (tester) async {
      await _run(tester, () async {
        expect(find.text('Required'), findsNothing);

        // Empty grace period: "Required" under it, nothing sent.
        await _type(tester, _grace, '');
        await _save(tester);
        expect(find.text('Required'), findsOneWidget);
        expect(_saves, isEmpty);

        // The message clears as soon as the box is filled.
        await _type(tester, _grace, '3');
        expect(find.text('Required'), findsNothing);

        // Empty Amount ($): "Amount is required", nothing sent.
        await _type(tester, _amount, '');
        await _save(tester);
        expect(find.text('Amount is required'), findsOneWidget);
        expect(_saves, isEmpty);

        // Switching to Percent asks for the percentage instead.
        await _tap(tester, 'Percent');
        expect(find.text('Percentage is required'), findsOneWidget);
        expect(find.text('Amount is required'), findsNothing);
        await _save(tester);
        expect(_saves, isEmpty);

        // Filled in, it saves as before.
        await _type(tester, _percentage, '10');
        expect(find.text('Percentage is required'), findsNothing);
        await _save(tester);
        expect(_saves, hasLength(1));
        final sent = _sent(_saves.single);
        expect(_saves.single.method, 'PUT');
        expect(_saves.single.url.path, '/api/latefee/latefee/LF-1');
        expect(sent['duration'], 3);
        expect(sent['late_fee'], 10);
        expect(sent['calculation_type'], 'percent');
      });
    });

    testWidgets('first late fee: both boxes are needed before it is added',
        (tester) async {
      _hasLateFee = false;
      await _run(tester, () async {
        // Save turns on as soon as something is typed, as before.
        await _type(tester, _amount, '15');
        await _save(tester);
        expect(find.text('Required'), findsOneWidget,
            reason: 'no grace period yet');
        expect(_saves, isEmpty);

        await _type(tester, _grace, '2');
        await _save(tester);
        expect(_saves, hasLength(1));
        expect(_saves.single.method, 'POST');
        final sent = _sent(_saves.single);
        expect(sent['duration'], 2);
        expect(sent['late_fee'], 15);
      });
    });

    testWidgets('Property Owner override: the same rules apply',
        (tester) async {
      await _run(tester, () async {
        final owner = find.byWidgetPredicate((w) =>
            w is DropdownButton2<String> &&
            (w.items ?? const []).any((i) => i.value == 'RO-1'));
        expect(owner, findsOneWidget);
        tester.widget<DropdownButton2<String>>(owner).onChanged!('RO-1');
        await _settle(tester, 5);

        await _type(tester, _grace, '');
        await _type(tester, _amount, '');
        await _save(tester);
        expect(find.text('Required'), findsOneWidget);
        expect(find.text('Amount is required'), findsOneWidget);
        expect(_saves, isEmpty, reason: 'no override is saved');

        await _type(tester, _grace, '4');
        await _type(tester, _amount, '30');
        await _save(tester);
        expect(_saves, hasLength(1));
        expect(_saves.single.url.path, '/api/property-owner-overrides');
        final rules = _sent(_saves.single)['late_fee_rules'] as Map;
        expect(rules['duration'], 4);
        expect(rules['late_fee'], 30);
        expect(_sent(_saves.single)['rentalowner_id'], 'RO-1');
      });
    });
  });
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
