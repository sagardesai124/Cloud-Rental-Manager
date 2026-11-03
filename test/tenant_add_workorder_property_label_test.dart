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
import 'package:three_zero_two_property/TenantsModule/repository/permission_provider.dart';
import 'package:three_zero_two_property/TenantsModule/screen/work_order/add_workorder.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Tenant portal → Work Orders → Add → Property: each option reads
/// "Address (Status)", like live staging web (TAddWork: label
/// `${rental_adress} (${status})`). Mobile showed "Address - Status".
/// Picking a property must still load that property's units and still show
/// the expired-lease note, which the form works out from the option's key.

const _expiredNote =
    'Your lease for this property has expired. The work order will appear only on the admin/staff dashboard.';

class _Server {
  final List<String> unitRequests = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (path == '/api/tenant/tenant_property/T-1') {
      body = {
        'statusCode': 200,
        'data': [
          {'rental_id': 'R-1', 'rental_adress': '123 Main St', 'status': 'Active'},
          {'rental_id': 'R-2', 'rental_adress': '9 Oak Ave', 'status': 'Expired'},
        ],
      };
    } else if (path.startsWith('/api/unit/rental_unit_dropdown/')) {
      final rentalId = path.split('/').last;
      unitRequests.add(rentalId);
      body = {
        'statusCode': 200,
        'data': rentalId == 'R-1'
            ? [
                {'unit_id': 'U-1', 'rental_unit': '101'}
              ]
            : [],
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'tenant_id': 'T-1',
      'adminId': 'ADMIN-1',
      'role': 'Tenant',
    });
  });

  testWidgets(
      'Property options read "Address (Status)" like web, and picking one '
      'still loads its units and the expired-lease note', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      // The test font draws every glyph as a full em square, so dense rows
      // overflow at phone width; that layout noise is ignored.
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    final server = _Server();
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => PermissionProvider()),
          ],
          child: MaterialApp(home: Add_Workorder()),
        ));
        await _settle(tester, 30);

        // Open the Property list (the form's first "Select here").
        await tester.tap(find.text('Select here').first);
        await _settle(tester);
        expect(find.text('123 Main St (Active)'), findsWidgets);
        expect(find.text('9 Oak Ave (Expired)'), findsWidgets);
        expect(find.text('123 Main St - Active'), findsNothing);
        expect(find.text('9 Oak Ave - Expired'), findsNothing);

        // Pick the active property: its units load, no expired note.
        await tester.tap(find.text('123 Main St (Active)').last);
        await _settle(tester);
        expect(server.unitRequests, ['R-1'], reason: 'units of the picked property');
        expect(find.text('123 Main St (Active)'), findsWidgets,
            reason: 'the picked option shows in the box');
        expect(find.text(_expiredNote), findsNothing);

        // Pick the expired one: its units load and the note shows.
        await tester.tap(find.text('123 Main St (Active)').first);
        await _settle(tester);
        await tester.tap(find.text('9 Oak Ave (Expired)').last);
        await _settle(tester);
        expect(server.unitRequests, ['R-1', 'R-2']);
        expect(find.text(_expiredNote), findsOneWidget);
      }, () => server.client);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    } finally {
      FlutterError.onError = original;
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
