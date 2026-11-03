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
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Vendor/add_vendor.dart'
    as staff_add;
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Vendor/edit_vendor.dart'
    as staff_edit;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Vendor/add_vendor.dart'
    as admin_add;
import 'package:three_zero_two_property/screens/Maintenance/Vendor/edit_vendor.dart'
    as admin_edit;

/// Vendors → Add Vendor / Edit Vendor: the email box uses web's rule
/// (AddVendor on live staging: `/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/`
/// with "Invalid email address"). Before, the phone used a looser check that
/// let through emails web refuses, such as o'brien@test.com, so web could
/// not save that vendor later. Admin and Staff each have their own Add and
/// Edit forms; all four are covered.

/// Emails web refuses.
const _refused = [
  "o'brien@test.com",
  'josé@test.com',
  '"john doe"@test.com',
  'john!x@test.com',
  'john@[127.0.0.1]',
  'john@test.c',
];

/// Emails web accepts.
const _accepted = ['JOHN@TEST.COM', 'john..doe@test.com', 'john.smith+tag@test.com'];

class _Server {
  final List<http.Request> saves = [];
  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (request.method != 'GET' && path.startsWith('/api/vendor/')) {
      saves.add(request);
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
          // Strong enough for the app's password rule, so on the Edit
          // forms the email is the only thing that can stop a save.
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

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens [form] on top of a plain page, so a save that closes the form
/// has somewhere to go back to.
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
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => widget.form));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Vendors'));
}

Finder get _emailBox => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Enter email');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _Online();
  });

  final forms = <(String, bool, Widget Function(), String)>[
    ('Admin Add Vendor', false, () => const admin_add.Add_vendor(), 'Add Vendor'),
    ('Staff Add Vendor', true, () => const staff_add.Add_vendor(), 'Add Vendor'),
    ('Admin Edit Vendor', false, () => admin_edit.edit_vendor(vender_id: 'V-1'),
        'Update Vendor'),
    ('Staff Edit Vendor', true, () => staff_edit.edit_vendor(vender_id: 'V-1'),
        'Update Vendor'),
  ];

  for (final (name, isStaff, form, button) in forms) {
    testWidgets('$name: email checked with web\'s rule and message',
        (tester) async {
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
              ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
            ],
            child: MaterialApp(home: _Launcher(form())),
          ));
          await _settle(tester, 30);
          expect(_emailBox, findsOneWidget, reason: 'the form opened');

          Future<void> submit(String email) async {
            await tester.enterText(_emailBox, email);
            await tester.pump();
            final save = find.widgetWithText(ElevatedButton, button);
            await tester.ensureVisible(save);
            await tester.pump();
            await tester.tap(save);
            await _settle(tester);
          }

          for (final email in _refused) {
            await submit(email);
            expect(find.text('Invalid email address'), findsOneWidget,
                reason: '$email is refused, as on web');
          }
          expect(server.saves, isEmpty,
              reason: 'nothing is saved while the email is refused');

          // Accepted emails: run the form's own checks (what the save button
          // runs first) without saving, so every email can be tried.
          final formState = tester.state<FormState>(
              find.ancestor(of: _emailBox, matching: find.byType(Form)).first);
          for (final email in _accepted) {
            await tester.enterText(_emailBox, email);
            await tester.pump();
            formState.validate();
            await _settle(tester, 4);
            expect(find.text('Invalid email address'), findsNothing,
                reason: '$email is accepted, as on web');
          }
          expect(find.text('Email is not valid'), findsNothing,
              reason: 'the old message is gone');

          // Edit forms are otherwise complete, so an accepted email saves.
          if (button == 'Update Vendor') {
            await submit('john.smith+tag@test.com');
            expect(server.saves, hasLength(1), reason: 'the vendor was saved');
            expect(server.saves.single.body, contains('john.smith+tag@test.com'));
            expect(find.text('Vendors'), findsOneWidget,
                reason: 'the form closed after saving');
          }
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      } finally {
        FlutterError.onError = original;
      }
    });
  }
}

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
