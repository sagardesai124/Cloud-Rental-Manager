import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/moveout/repository.dart'
    as staff;
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/repository.dart'
    as admin;

/// Move In like web staging (LeaseTenantsTab / RentRollDetail / PropDetails
/// `handleMoveIn`): tapping Move In first asks "Are you sure? Do you want to
/// Move-in this Tenant?" with Cancel / Confirm. Only Confirm moves the tenant
/// in; Cancel, the close button or a tap outside does nothing. After a move-in
/// the screen stays open and refreshes, and the toast reads
/// "Tenant moved in successfully".

/// The 6 Move In buttons: Lease → Tenants (phone + wide) and Property →
/// Tenants, Admin and Staff.
const _screens = {
  'lib/screens/Leasing/RentalRoll/SummeryPageLease.dart': 2,
  'lib/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart': 2,
  'lib/screens/Rental/Properties/summery_page.dart': 1,
  'lib/StaffModule/screen/Rental/Properties/summery_page.dart': 1,
};

Future<bool?> _open(WidgetTester tester) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmMoveIn(context),
          child: const Text('Move In'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Move In'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Move In popup', () {
    testWidgets('shows web title, text and Cancel / Confirm', (tester) async {
      await _open(tester);
      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Do you want to Move-in this Tenant?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    Future<bool?> answer(WidgetTester tester, Object button) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmMoveIn(context),
              child: const Text('Move In'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Move In'));
      await tester.pumpAndSettle();
      if (button is Offset) {
        await tester.tapAt(button);
      } else {
        await tester.tap(button as Finder);
      }
      await tester.pumpAndSettle();
      expect(find.text('Do you want to Move-in this Tenant?'), findsNothing);
      return result;
    }

    testWidgets('Confirm → true', (tester) async {
      expect(await answer(tester, find.byKey(const Key('move-in-confirm'))),
          isTrue);
    });

    testWidgets('Cancel → false', (tester) async {
      expect(await answer(tester, find.byKey(const Key('move-in-cancel'))),
          isFalse);
    });

    testWidgets('tap outside → false', (tester) async {
      // Corner of the screen, outside the popup.
      expect(await answer(tester, const Offset(5, 5)), isFalse);
    });
  });

  group('Move In request', () {
    final toasts = <String>[];

    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        if (call.method == 'showToast') {
          toasts.add((call.arguments as Map)['msg'].toString());
        }
        return true;
      });
    });

    setUp(() {
      toasts.clear();
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
    });

    for (final (name, moveIn) in [
      (
        'Admin',
        () => admin.LeaseMoveoutRepository()
            .addMoveInTenant(adminId: 'ADMIN-1', tenantId: 'T-1', leaseId: 'L-1')
      ),
      (
        'Staff',
        () => staff.LeaseMoveoutRepository()
            .addMoveInTenant(adminId: 'ADMIN-1', tenantId: 'T-1', leaseId: 'L-1')
      ),
    ]) {
      test('$name: PUTs lease_movein and toasts web success text', () async {
        final sent = <http.Request>[];
        await http.runWithClient(() async {
          await moveIn();
        }, () => MockClient((request) async {
              sent.add(request);
              return http.Response(
                  jsonEncode({
                    'statusCode': 200,
                    'message': 'Tenant Moved In Successfully',
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
        expect(sent.single.method, 'PUT');
        expect(sent.single.url.path, '/api/moveout/lease_movein/L-1');
        expect(jsonDecode(sent.single.body),
            {'admin_id': 'ADMIN-1', 'tenant_id': 'T-1', 'lease_id': 'L-1'});
        expect(toasts, ['Tenant moved in successfully']);
      });
    }
  });

  test('every Move In button asks first and stays on the screen', () {
    for (final entry in _screens.entries) {
      final src = File(entry.key).readAsStringSync();
      final handlers = RegExp(
              r'if \(_moveInBusy\) return;(.*?)\.whenComplete\(\(\) => _moveInBusy = false\);',
              dotAll: true)
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toList();
      expect(handlers, hasLength(entry.value), reason: entry.key);
      for (final h in handlers) {
        final ask = h.indexOf('confirmMoveIn(context)');
        final send = h.indexOf('.addMoveInTenant(');
        expect(ask, isNonNegative, reason: '${entry.key}: no confirmation');
        expect(ask, lessThan(send), reason: '${entry.key}: asks after sending');
        expect(h.contains(RegExp(r'Navigator\.pop\(\s*context,\s*true\)')),
            isFalse,
            reason: '${entry.key}: closes the screen after Move In');
      }
    }
  });
}
