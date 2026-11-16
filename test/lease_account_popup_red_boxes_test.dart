import 'dart:convert';
import 'dart:io';

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
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/newAddLease.dart'
    as staff_lease;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/add_tenants.dart'
    as staff_tenants;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/newAddLease.dart'
    as admin_lease;
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart'
    as admin_tenants;
import 'package:three_zero_two_property/widgets/account_form_web_rules.dart';

/// The "Add account" pop-ups inside Add / Edit / Renew Lease, like web staging
/// (one form on web: AccountDialog.jsx): tapping Add with empty required
/// fields turns Account Name, Account Type and Fund Type into red boxes,
/// shows "Account name is required" under the name and "Please correct the
/// red boxes above" above the buttons. Each box clears as it is filled; an
/// emptied name turns red again. The selects show only the red box.

const _red = Color(0xFFDC3545);

/// Red boxes drawn inside [within] (Container / DropdownButton2 decorations).
int _redBoxes(WidgetTester tester, Finder within) => tester
    .widgetList<DecoratedBox>(
        find.descendant(of: within, matching: find.byType(DecoratedBox)))
    .where((d) {
  final deco = d.decoration;
  return deco is BoxDecoration &&
      deco.border is Border &&
      (deco.border as Border).top.color == _red;
}).length;

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // ---------- the shared boxes: opt-in, everything else unchanged ----------
  for (final role in ['Admin', 'Staff']) {
    Widget nameBox(TextEditingController c, {bool webStyle = true}) =>
        role == 'Admin'
            ? admin_tenants.CustomTextField(
                hintText: 'Enter Account Name',
                controller: c,
                showElevation: false,
                borderColor: const Color(0xFFCED4DA),
                requiredMessage: webStyle ? kAccountNameRequiredMessage : null,
                redBorderOnError: webStyle,
              )
            : staff_tenants.CustomTextField(
                hintText: 'Enter Account Name',
                controller: c,
                showElevation: false,
                borderColor: const Color(0xFFCED4DA),
                requiredMessage: webStyle ? kAccountNameRequiredMessage : null,
                redBorderOnError: webStyle,
              );

    testWidgets('$role name box: web style is red + "Account name is required"',
        (tester) async {
      final form = GlobalKey<FormState>();
      final c = TextEditingController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Form(key: form, child: nameBox(c)))));

      expect(_redBoxes(tester, find.byType(Scaffold)), 0);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text(kAccountNameRequiredMessage), findsOneWidget);
      expect(_redBoxes(tester, find.byType(Scaffold)), 1);

      await tester.enterText(find.byType(TextField), 'Rent');
      await tester.pump();
      expect(find.text(kAccountNameRequiredMessage), findsNothing);
      expect(_redBoxes(tester, find.byType(Scaffold)), 0);

      // Emptied again: red again, like web.
      await tester.enterText(find.byType(TextField), '  ');
      await tester.pump();
      expect(find.text(kAccountNameRequiredMessage), findsOneWidget);
      expect(_redBoxes(tester, find.byType(Scaffold)), 1);
      expect(form.currentState!.validate(), isFalse,
          reason: 'spaces only still blocks Add');
    });

    testWidgets('$role name box: without the opt-in nothing changes',
        (tester) async {
      final form = GlobalKey<FormState>();
      final c = TextEditingController();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Form(key: form, child: nameBox(c, webStyle: false)))));
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please enter account name'), findsOneWidget,
          reason: 'the old message for every other box');
      expect(_redBoxes(tester, find.byType(Scaffold)), 0,
          reason: 'no red box unless asked for');
    });
  }

  for (final role in ['Admin', 'Staff']) {
    Widget dropdown(ValueChanged<String?> onChanged, {bool webStyle = true}) {
      String? check(String? v) =>
          (v == null || v.isEmpty) ? kSelectAccountTypeMessage : null;
      return role == 'Admin'
          ? admin_lease.CustomDropdown(
              labelText: 'Select Account Type',
              items: kAccountTypeOptions,
              selectedValue: null,
              onChanged: onChanged,
              validator: check,
              useBorderStyle: true,
              errorBorderOnly: webStyle,
            )
          : staff_lease.CustomDropdown(
              labelText: 'Select Account Type',
              items: kAccountTypeOptions,
              selectedValue: null,
              onChanged: onChanged,
              validator: check,
              useBorderStyle: true,
              errorBorderOnly: webStyle,
            );
    }

    testWidgets('$role dropdown: web style is a red box with no text',
        (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Form(key: form, child: dropdown((_) {})))));
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(_redBoxes(tester, find.byType(Scaffold)), 1);
      expect(find.text(kSelectAccountTypeMessage), findsNothing,
          reason: "web's selects show only the red box");

      await tester.tap(find.ancestor(
          of: find.text('Select Account Type'),
          matching: find.byType(DropdownButton2<String>)));
      await _settle(tester);
      await tester.tap(find.text('Liability Account').last);
      await _settle(tester);
      expect(_redBoxes(tester, find.byType(Scaffold)), 0,
          reason: 'picking a value clears it');
    });

    testWidgets('$role dropdown: without the opt-in nothing changes',
        (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Form(
                  key: form, child: dropdown((_) {}, webStyle: false)))));
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text(kSelectAccountTypeMessage), findsOneWidget);
      expect(_redBoxes(tester, find.byType(Scaffold)), 0);
    });
  }

  // ---------- the real One Time Fee › Add account pop-up ----------
  group('Add Lease › One Time Fee › + Add New Account', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    for (final role in ['Admin', 'Staff']) {
      testWidgets('$role: red boxes and messages like web, then it saves',
          (tester) async {
        SharedPreferences.setMockInitialValues(
            {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': role});
        final posts = <Map<String, dynamic>>[];
        final server = MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' && path == '/api/accounts/accounts') {
            posts.add(jsonDecode(request.body) as Map<String, dynamic>);
            return _json({'statusCode': 200, 'message': 'New account added'});
          }
          if (path.startsWith('/api/accounts/accounts/')) {
            return _json({
              'statusCode': 200,
              'data': [
                {'account': 'Rent'}
              ]
            });
          }
          return _json({'statusCode': 200, 'data': []});
        });

        tester.view.physicalSize = const Size(1080, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final original = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) return;
          original?.call(d);
        };
        addTearDown(() => FlutterError.onError = original);

        await http.runWithClient(() async {
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DateProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(
                  create: (_) => checkPlanPurchaseProiver()),
              ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: role == 'Admin'
                      ? admin_lease.OneTimeChargePopUp(onSave: (_) {})
                      : staff_lease.OneTimeChargePopUp(onSave: (_) {}),
                ),
              ),
            ),
          ));
          await _settle(tester, 30);

          // Account › + Add New Account opens the pop-up.
          await tester.tap(find.byType(DropdownButton2<String>).first);
          await _settle(tester);
          await tester.tap(find.text('+ Add New Account').last);
          await _settle(tester, 30);
          final dialog = find.byType(Dialog);
          expect(dialog, findsOneWidget);
          Finder inDialog(Finder f) =>
              find.descendant(of: dialog, matching: f);
          final add = inDialog(find.widgetWithText(ElevatedButton, 'Add'));

          // Nothing is red before Add.
          expect(_redBoxes(tester, dialog), 0);
          expect(find.text(kAccountFixRedBoxesMessage), findsNothing);

          // Add with everything empty: web's red boxes and messages.
          await tester.tap(add);
          await _settle(tester);
          expect(_redBoxes(tester, dialog), 3,
              reason: 'name, account type and fund type');
          expect(inDialog(find.text(kAccountNameRequiredMessage)),
              findsOneWidget);
          expect(inDialog(find.text(kAccountFixRedBoxesMessage)),
              findsOneWidget);
          expect(find.text(kSelectAccountTypeMessage), findsNothing);
          expect(find.text(kSelectFundTypeMessage), findsNothing);
          expect(find.text('Please enter account name'), findsNothing);
          expect(posts, isEmpty);

          // Filling each field clears its box.
          final name = inDialog(find.byWidgetPredicate((w) =>
              w is TextField && w.decoration?.hintText == 'Enter Account Name'));
          await tester.enterText(name, 'Deposit Fee');
          await _settle(tester, 5);
          expect(_redBoxes(tester, dialog), 2);
          expect(inDialog(find.text(kAccountNameRequiredMessage)), findsNothing);
          expect(inDialog(find.text(kAccountFixRedBoxesMessage)),
              findsOneWidget);

          await tester.tap(find.ancestor(
              of: inDialog(find.text('Select Account Type')),
              matching: find.byType(DropdownButton2<String>)));
          await _settle(tester);
          await tester.tap(find.text('Liability Account').last);
          await _settle(tester);
          expect(_redBoxes(tester, dialog), 1);

          await tester.tap(find.ancestor(
              of: inDialog(find.text('Select Fund Type')),
              matching: find.byType(DropdownButton2<String>)));
          await _settle(tester);
          await tester.tap(find.text('Reserve').last);
          await _settle(tester);
          expect(_redBoxes(tester, dialog), 0);
          expect(inDialog(find.text(kAccountFixRedBoxesMessage)), findsNothing);

          // Emptying the name turns it red again, like web.
          await tester.enterText(name, '');
          await _settle(tester, 5);
          expect(_redBoxes(tester, dialog), 1);
          expect(inDialog(find.text(kAccountNameRequiredMessage)),
              findsOneWidget);
          expect(inDialog(find.text(kAccountFixRedBoxesMessage)),
              findsOneWidget);
          await tester.enterText(name, 'Deposit Fee');
          await _settle(tester, 5);

          // Everything filled (Notes left empty): it saves.
          await tester.tap(add);
          await _settle(tester, 30);
          expect(posts, hasLength(1));
          expect(posts.single['account'], 'Deposit Fee');
          expect(posts.single['account_type'], 'Liability Account');
          expect(posts.single['fund_type'], 'Reserve');
          expect(posts.single['notes'], '');
          expect(find.byType(Dialog), findsNothing);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));
        }, () => server);
      });
    }
  });

  // ---------- every live pop-up is wired the same way ----------
  const popups = {
    'lib/screens/Leasing/RentalRoll/newAddLease.dart': 2,
    'lib/screens/Leasing/RentalRoll/edit_lease.dart': 2,
    'lib/screens/Leasing/RentalRoll/RenewLease.dart': 1,
    'lib/StaffModule/screen/Leasing/RentalRoll/newAddLease.dart': 2,
    'lib/StaffModule/screen/Leasing/RentalRoll/edit_lease.dart': 2,
    'lib/StaffModule/screen/Leasing/RentalRoll/RenewLease.dart': 1,
  };
  String live(String path) => File(path)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  for (final e in popups.entries) {
    test('${e.key}: ${e.value} pop-up(s) show red boxes like web', () {
      final src = live(e.key);
      final n = e.value;
      int count(String s) => s.allMatches(src).length;
      expect(count('requiredMessage: kAccountNameRequiredMessage,'), n);
      expect(count('redBorderOnError: true,'), n);
      expect(count('errorBorderOnly: true,'), 2 * n,
          reason: 'Account Type and Fund Type');
      expect(count('setState(() => accountSubmitted = true);'), n);
      expect(count('bool accountSubmitted = false;'), n);
      expect(count('kAccountFixRedBoxesMessage,'), n);
      expect(src, isNot(contains("'Please fill all fields'")));
      if (e.key.contains('RenewLease')) {
        expect(count('_subFormKey.currentState?.validate();'), greaterThanOrEqualTo(n));
      }
    });
  }
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

class _Online extends ConnectivityPlatform with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
