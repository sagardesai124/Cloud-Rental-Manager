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
import 'package:three_zero_two_property/Model/vendor.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Vendor/add_vendor.dart'
    as staff_add;
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Vendor/edit_vendor.dart'
    as staff_edit;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Vendor/add_vendor.dart'
    as admin_add;
import 'package:three_zero_two_property/screens/Maintenance/Vendor/edit_vendor.dart'
    as admin_edit;

/// Vendors → Add Vendor / Edit Vendor (Admin and Staff), like web staging
/// (AddVendor.jsx after CRM-5279, "we shouldn't collect or store SSN/EIN"):
/// ticking "This vendor receives 1099 forms" shows no Tax ID (EIN/SSN) box,
/// Edit Vendor never asks for the stored Tax ID (`include_tax_id`), and a
/// save never sends `tax_id`, so a vendor's stored value is left as it is.
/// Before, the app showed a Tax ID box under the tick box, Admin Edit loaded
/// the masked Tax ID, and a typed one was sent on save.

class _Server {
  final List<http.Request> requests = [];
  /// Vendor saves only (not the history log the app also posts).
  List<http.Request> get saves => requests
      .where((r) => r.method != 'GET' && r.url.path.startsWith('/api/vendor/'))
      .toList();
  List<String> get others => requests
      .where((r) => r.method != 'GET' && !r.url.path.startsWith('/api/vendor/'))
      .map((r) => '${r.method} ${r.url.path}')
      .toList();

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (request.method != 'GET' && path.startsWith('/api/vendor/')) {
      body = {'statusCode': 200, 'message': 'ok'};
    } else if (path == '/api/vendor/get_vendor/V-1') {
      body = {
        'statusCode': 200,
        'data': {
          'vendor_id': 'V-1',
          'admin_id': 'ADMIN-1',
          'vendor_name': 'Pat Plumbing',
          'vendor_phoneNumber': '5551234567',
          'vendor_email': 'vendor@test.com',
          'vendor_password': 'Str0ng!Pass2026',
          'trade': 'Plumbing',
          'is_1099': false,
        },
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens [form] on top of a plain page, so a save that closes the form has
/// somewhere to go back to.
class _Launcher extends StatefulWidget {
  const _Launcher(this.form);
  final Widget form;
  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => widget.form));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Vendors'));
}

Finder get _taxIdAnything => find.byWidgetPredicate((w) =>
    (w is Text && (w.data ?? '').contains('Tax ID')) ||
    (w is TextField &&
        (w.decoration?.hintText ?? '').toLowerCase().contains('tax id')));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  Future<_Server> open(WidgetTester tester, Widget form,
      {required bool isStaff, required double width}) async {
    SharedPreferences.setMockInitialValues(isStaff
        ? {
            'token': 'tkn',
            'adminId': 'ADMIN-1',
            'staff_id': 'STAFF-1',
            'role': 'Staffmember'
          }
        : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = _Server();
    final dates = DateProvider();
    await http.runWithClient(() async {
      await dates.loadDateFormat();
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DateProvider>.value(value: dates),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
          ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
        ],
        child: MaterialApp(home: _Launcher(form)),
      ));
      await _settle(tester);
    }, () => server.client);
    return server;
  }

  Future<void> quietOverflow(Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      // The test font draws every glyph as a full em square, so dense rows
      // overflow at phone width; that layout noise is ignored.
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await body();
    } finally {
      FlutterError.onError = original;
    }
  }

  final forms = <(String, bool, Widget Function(), String)>[
    ('Admin Add Vendor', false, () => const admin_add.Add_vendor(), 'Add Vendor'),
    ('Staff Add Vendor', true, () => const staff_add.Add_vendor(), 'Add Vendor'),
    ('Admin Edit Vendor', false, () => admin_edit.edit_vendor(vender_id: 'V-1'),
        'Update Vendor'),
    ('Staff Edit Vendor', true, () => staff_edit.edit_vendor(vender_id: 'V-1'),
        'Update Vendor'),
  ];

  for (final (name, isStaff, form, button) in forms) {
    for (final width in [430.0, 800.0]) {
      testWidgets(
          '$name @${width.toInt()}: ticking 1099 shows no Tax ID box, like web',
          (tester) async {
        await quietOverflow(() async {
          final server = await open(tester, form(), isStaff: isStaff, width: width);
          await http.runWithClient(() async {
            final tick = find.text('This vendor receives 1099 forms');
            expect(tick, findsOneWidget, reason: 'the form opened');
            expect(_taxIdAnything, findsNothing);

            await tester.ensureVisible(tick);
            await tester.tap(tick);
            await _settle(tester, 6);
            expect(
                tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue,
                reason: 'the 1099 box is ticked');
            expect(_taxIdAnything, findsNothing,
                reason: 'no Tax ID (EIN/SSN) box, like web');
            expect(find.textContaining('XX-XXXXXXX'), findsNothing);

            expect(
                server.requests
                    .where((r) => r.url.toString().contains('include_tax_id')),
                isEmpty,
                reason: 'the stored Tax ID is never asked for, like web');

            // Edit: ticking 1099 is a change, so it saves, without a Tax ID.
            if (button == 'Update Vendor' && width == 430.0) {
              final save = find.widgetWithText(ElevatedButton, button);
              await tester.ensureVisible(save);
              await tester.pump();
              await tester.tap(save);
              await _settle(tester);
              expect(server.saves, hasLength(1),
                  reason: 'the vendor was saved (other calls: ${server.others})');
              final body =
                  jsonDecode(server.saves.single.body) as Map<String, dynamic>;
              expect(body['is_1099'], isTrue);
              expect(body.containsKey('tax_id'), isFalse,
                  reason: 'no Tax ID is sent, so the stored one stays');
            }
          }, () => server.client);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        });
      });
    }
  }

  test('a saved vendor never carries a Tax ID, like web', () {
    final vendor = Vendor.fromJson({
      'vendor_name': 'Pat Plumbing',
      'vendor_email': 'vendor@test.com',
      'is_1099': true,
      'tax_id': '12-3456789',
    });
    final json = vendor.toJson();
    expect(json['is_1099'], isTrue);
    expect(json.containsKey('tax_id'), isFalse);
  });

  test('no vendor screen or repository asks for the Tax ID any more', () {
    for (final path in [
      'lib/screens/Maintenance/Vendor/add_vendor.dart',
      'lib/screens/Maintenance/Vendor/edit_vendor.dart',
      'lib/StaffModule/screen/Maintenance/Vendor/add_vendor.dart',
      'lib/StaffModule/screen/Maintenance/Vendor/edit_vendor.dart',
      'lib/repository/vendor_repository.dart',
      'lib/StaffModule/repository/vendor_repository.dart',
    ]) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, isNot(contains('include_tax_id')), reason: path);
      expect(code, isNot(contains('Tax ID (EIN/SSN)')), reason: path);
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
