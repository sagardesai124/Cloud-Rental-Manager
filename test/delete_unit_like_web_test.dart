import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/properties_summery.dart'
    as staff;
import 'package:three_zero_two_property/repository/properties_summery.dart'
    as admin;
import 'package:three_zero_two_property/services/history_service.dart';
import 'package:three_zero_two_property/widgets/delete_unit_dialog.dart';

/// Property › Units › unit details › Delete Unit, like web staging
/// (Units.jsx handleDeleteUnit): "Are you sure?" with a reason box, Delete
/// disabled until the reason has something other than spaces, Cancel keeps
/// the unit, and the typed reason goes with DELETE /api/unit/unit/:id.
/// Before, one tap deleted the unit and the server logged
/// "No Reason Provided".

const _pages = {
  'Admin': 'lib/screens/Rental/Properties/summery_page.dart',
  'Staff': 'lib/StaffModule/screen/Rental/Properties/summery_page.dart',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'),
            (_) async => true);
  });

  group('the Delete Unit popup', () {
    testWidgets('shows web\'s texts; Delete waits for a real reason',
        (tester) async {
      final result = await _open(tester);

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Once deleted, you will not be able to recover this unit!'),
          findsOneWidget);
      expect(_reasonBox(tester).decoration?.hintText,
          'Enter reason for deletion');
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Disabled while empty, and a reason of only spaces doesn't count.
      expect(_deleteButton(tester).onPressed, isNull);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure?'), findsOneWidget, reason: 'still open');
      await tester.enterText(find.byKey(const Key('delete-unit-reason')), '   ');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNull, reason: 'only spaces');

      await tester.enterText(
          find.byKey(const Key('delete-unit-reason')), 'Duplicate unit');
      await tester.pump();
      expect(_deleteButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsNothing, reason: 'closed');
      expect(result.value, 'Duplicate unit', reason: 'the reason as typed');
      expect(result.done, isTrue);
    });

    testWidgets('Cancel closes it and deletes nothing', (tester) async {
      final result = await _open(tester);
      await tester.enterText(
          find.byKey(const Key('delete-unit-reason')), 'Duplicate unit');
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsNothing);
      expect(result.done, isTrue);
      expect(result.value, isNull, reason: 'null means keep the unit');
    });
  });

  group('the delete request sends the reason, like web', () {
    for (final role in ['Admin', 'Staff']) {
      test(role, () async {
        SharedPreferences.setMockInitialValues(
            {'token': 'tkn', 'adminId': 'A-1', 'staff_id': 'S-1'});
        final requests = <http.Request>[];
        final server = MockClient((request) async {
          requests.add(request);
          return http.Response(
              jsonEncode(
                  {'statusCode': 200, 'message': 'Unit deleted successfully.'}),
              200,
              headers: {'content-type': 'application/json'});
        });

        final data = await http.runWithClient(
            () => role == 'Admin'
                ? admin.Properies_summery_Repo()
                    .Deleteunit(unitId: 'U-1', reason: 'Duplicate unit')
                : staff.Properies_summery_Repo()
                    .Deleteunit(unitId: 'U-1', reason: 'Duplicate unit'),
            () => server);

        expect(requests, hasLength(1));
        final sent = requests.single;
        expect(sent.method, 'DELETE');
        expect(sent.url.path, '/api/unit/unit/U-1', reason: 'same call as web');
        expect(jsonDecode(sent.body), {'reason': 'Duplicate unit'});
        expect(data['statusCode'], 200);
      });
    }

    test('a refused delete still shows the server\'s message and fails',
        () async {
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'A-1'});
      final toasts = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
        toasts.add('${(call.arguments as Map)['msg']}');
        return true;
      });
      final server = MockClient((_) async => http.Response(
          jsonEncode({
            'statusCode': 201,
            'message':
                'Cannot delete unit. The unit is already assigned to a tenant.'
          }),
          201,
          headers: {'content-type': 'application/json'}));

      await expectLater(
          http.runWithClient(
              () => admin.Properies_summery_Repo()
                  .Deleteunit(unitId: 'U-1', reason: 'Duplicate unit'),
              () => server),
          throwsException);
      expect(toasts,
          ['Cannot delete unit. The unit is already assigned to a tenant.']);
    });
  });

  group('History entry after a delete, like web', () {
    test('the line reads "Unit <number> has been deleted"', () {
      expect(unitDeletedDescription(unitNumber: '1', unitId: 'U-1'),
          'Unit 1 has been deleted');
      expect(unitDeletedDescription(unitNumber: '', unitId: 'U-1'),
          'Unit U-1 has been deleted', reason: 'falls back to the id');
      expect(unitDeletedDescription(unitNumber: null, unitId: null),
          'Unit N/A has been deleted');
    });

    test("the name is web's: First Last, else email, else System", () async {
      SharedPreferences.setMockInitialValues({
        'first_name': 'Mark',
        'last_name': 'Due',
        'email': 'mark@example.com'
      });
      expect(HistoryService.usernameFrom(await SharedPreferences.getInstance()),
          'Mark Due');
      SharedPreferences.setMockInitialValues(
          {'first_name': 'Mark', 'email': 'mark@example.com'});
      expect(HistoryService.usernameFrom(await SharedPreferences.getInstance()),
          'mark@example.com', reason: 'web needs both names');
      SharedPreferences.setMockInitialValues({});
      expect(HistoryService.usernameFrom(await SharedPreferences.getInstance()),
          'System');
    });

    test('saveHistory posts what web posts, and a failure does not throw',
        () async {
      SharedPreferences.setMockInitialValues({
        'token': 'tkn',
        'adminId': 'A-1',
        'role': 'Admin',
        'first_name': 'Mark',
        'last_name': 'Due',
      });
      final requests = <http.Request>[];
      final ok = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'statusCode': 200}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(
          () => HistoryService.saveHistory(
                entityType: 'property',
                entityId: 'R-1',
                actionType: 'deleted',
                description: 'Unit 1 has been deleted',
                category: 'Unit',
                metadata: {'unit_id': 'U-1', 'unit_number': '1'},
              ),
          () => ok);
      expect(requests, hasLength(1));
      final sent = requests.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/history');
      expect(sent.headers['id'], 'CRM A-1');
      expect(jsonDecode(sent.body), {
        'entity_type': 'property',
        'entity_id': 'R-1',
        'action_type': 'deleted',
        'description': 'Unit 1 has been deleted',
        'username': 'Mark Due',
        'metadata': {'unit_id': 'U-1', 'unit_number': '1'},
        'category': 'Unit',
      });

      final down = MockClient((_) async => throw http.ClientException('down'));
      expect(
          await http.runWithClient(
              () => HistoryService.saveHistory(
                  entityType: 'property',
                  entityId: 'R-1',
                  actionType: 'deleted',
                  description: 'Unit 1 has been deleted'),
              () => down),
          isNull,
          reason: 'the delete is never undone by a History failure');
    });

    test('Admin logs it after the delete and refreshes History; Staff, like '
        "web's Staff page, does not", () {
      final adminSrc = File(_pages['Admin']!).readAsStringSync();
      final call = adminSrc.indexOf('.Deleteunit(');
      // From the delete call to the end of this button.
      final after =
          adminSrc.substring(call, adminSrc.indexOf("'Delete Unit',", call));
      final log = after.indexOf('HistoryService.saveHistory(');
      expect(log, isNonNegative, reason: 'saved after the delete');
      final logCall = after.substring(log, after.indexOf(');', log));
      expect(logCall, contains("entityType: 'property'"));
      expect(logCall, contains("actionType: 'deleted'"));
      expect(logCall, contains("category: 'Unit'"));
      expect(logCall, contains('unitDeletedDescription('));
      expect(after.indexOf('_historyRefreshKey++'), greaterThan(log),
          reason: 'History table reloads');

      final staffSrc = File(_pages['Staff']!).readAsStringSync();
      final staffCall = staffSrc.indexOf('.Deleteunit(');
      expect(
          staffSrc.substring(
              staffCall, staffSrc.indexOf("'Delete Unit',", staffCall)),
          isNot(contains('HistoryService.saveHistory(')));
    });
  });

  group('the Delete Unit button asks first', () {
    for (final entry in _pages.entries) {
      test(entry.key, () {
        final src = File(entry.value).readAsStringSync();
        expect(src, contains("'Delete Unit',"), reason: "web's button text");
        expect(src, isNot(contains("'Delete unit'")));
        final call = src.indexOf('.Deleteunit(');
        expect(call, isNonNegative);
        final ask = src.lastIndexOf('confirmDeleteUnit(context)', call);
        expect(ask, isNonNegative, reason: 'the popup comes first');
        final between = src.substring(ask, call);
        expect(between.length, lessThan(900), reason: 'same button');
        expect(between, contains('if (reason == null'),
            reason: 'Cancel stops before the delete');
        expect(src.substring(call, call + 160), contains('reason: reason'),
            reason: 'the typed reason goes with the delete');
      });
    }
  });
}

class _Result {
  bool done = false;
  String? value;
}

/// Opens the popup from a button and returns where its answer lands.
Future<_Result> _open(WidgetTester tester) async {
  final result = _Result();
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result.value = await confirmDeleteUnit(context);
              result.done = true;
            },
            child: const Text('Delete Unit'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Delete Unit'));
  await tester.pumpAndSettle();
  return result;
}

TextField _reasonBox(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('delete-unit-reason')));

DialogButton _deleteButton(WidgetTester tester) =>
    tester.widget<DialogButton>(find.byKey(const Key('delete-unit-confirm')));
