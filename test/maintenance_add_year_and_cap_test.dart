import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Maintenance/Add_Edit_maintenance.dart';

/// Property → Annual Expenses → Maintenance, like staging web
/// (PropDetails.jsx handleAddMaintenance + MAX_ANNUAL_EXPENSE_AMOUNT):
/// - Add starts with no year ("Select Year"); it used to pre-fill this year.
/// - Amounts over $999,999,999.99 are refused with web's message and nothing
///   is sent; they used to save.
/// Admin and Staff share this form.

final List<http.Request> _sent = [];

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path.startsWith('/api/rentals/maintenance/')) {
    _sent.add(request);
    return _json({'statusCode': 200, 'message': 'ok'});
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '12'}
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _maxMsg = r'Amount must be less than $1,000,000,000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _sent.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
    SharedPreferences.setMockInitialValues(
        {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  });

  Future<void> open(WidgetTester tester, Add_Edit_maintenance form,
      Future<void> Function() body) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(home: form),
        ));
        await _settle(tester);
        await body();
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    } finally {
      FlutterError.onError = original;
    }
  }

  Finder amountField() => find.byType(TextField).first;
  final thisYear = DateTime.now().year.toString();

  testWidgets('Add: Year starts blank ("Select Year"), like web',
      (tester) async {
    await open(tester, const Add_Edit_maintenance(propertyId: 'P-1'),
        () async {
      expect(find.text('Select Year'), findsOneWidget);
      expect(find.text(thisYear), findsNothing,
          reason: 'the current year is no longer pre-selected');
    });
  });

  testWidgets('Add: amount over \$999,999,999.99 → web message, nothing sent',
      (tester) async {
    await open(tester, const Add_Edit_maintenance(propertyId: 'P-1'),
        () async {
      await tester.enterText(amountField(), '9999999999');
      await _settle(tester, 6);
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await _settle(tester, 10);
      // Errors show once Save is pressed (the form's existing behaviour).
      expect(find.text(_maxMsg), findsOneWidget);
      expect(_sent, isEmpty, reason: 'too large: not saved');
    });
  });

  testWidgets('Add: the maximum 999999999.99 itself is allowed',
      (tester) async {
    await open(tester, const Add_Edit_maintenance(propertyId: 'P-1'),
        () async {
      await tester.enterText(amountField(), '999999999.99');
      await _settle(tester, 6);
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await _settle(tester, 10);
      expect(find.text(_maxMsg), findsNothing);
    });
  });

  test('success and delete messages use web wording', () {
    final form = File(
            'lib/screens/Rental/Properties/Maintenance/Add_Edit_maintenance.dart')
        .readAsStringSync();
    final table = File(
            'lib/screens/Rental/Properties/Maintenance/maintenance_table.dart')
        .readAsStringSync();
    expect(form, contains("'Maintenance entry added'"));
    expect(form, contains("'Maintenance entry updated'"));
    expect(table, contains("'Maintenance entry deleted'"));
    expect(form, isNot(contains('Maintenance added successfully')));
  });

  testWidgets('Edit: keeps the saved year and amount', (tester) async {
    await open(
        tester,
        const Add_Edit_maintenance(
          propertyId: 'P-1',
          entryId: 'M-1',
          maintenanceData: {'year': '2024', 'amount': 1500},
        ), () async {
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('Select Year'), findsNothing);
      expect(find.text('1500'), findsOneWidget);
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
