import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/workorder_summery.dart'
    as staff;
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/workorder_summery.dart'
    as admin;

/// Admin + Staff → Work Order Summary → Update: Save stays disabled until
/// something changes, like web (WorkOrderDetails.jsx: the Update button
/// handler sets the baseline, and the button is `disabled={... ||
/// !hasFormChanges}`). Web counts a changed status, assignee or due date, a
/// typed public/private note, or a picked photo. Before, Save was always
/// enabled, so saving an untouched form added a duplicate Update History row
/// and sent a "Work order has been updated" notification. Picking a status
/// also never redrew the form, so the new status didn't show. Every Update
/// also starts with no files, like web, and a photo picked after a video in an
/// earlier Update must not show that video's play icon.

final _workOrder = {
  'workOrder_id': 'WO-1',
  'ticket_number': '1001',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'work_category': 'Plumbing',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'staffmember_id': 'S-1',
  'staff_data': {'_id': 'S-1', 'firstname': 'Pat', 'lastname': 'Staff'},
  'property_data': {
    '_id': 'P-1',
    'property_name': 'Main St',
    'rental_adress': '123 Main St',
    'rental_city': 'Austin',
    'rental_state': 'TX',
    'rental_country': 'USA',
    'rental_postcode': '73301',
    'rental_image': '',
  },
  'unit_data': {
    '_id': 'U-1',
    'rental_unit_adress': '123 Main St',
    'rental_unit': 'A1',
    'unit_id': 'U-1',
  },
  'vendor_data': {'_id': 'V-1', 'vendor_name': 'Fixit Co'},
  'tenant_data': {'_id': 'T-1', 'tenant_firstName': 'Ruth', 'tenant_lastName': 'Moss'},
  'work_performed': 'Unit',
  'vendor_notes': '',
  'workorder_updates': [],
  'partsandcharge_data': [],
  'workOrder_images': [],
};

final _server = MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    };
  } else if (path.startsWith('/api/work-order/workorder_details/')) {
    body = {'statusCode': 200, 'data': _workOrder};
  } else if (path.startsWith('/api/staffmember/staff_member/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'staffmember_id': 'S-1', 'staffmember_name': 'Pat Staff'},
        {'staffmember_id': 'S-2', 'staffmember_name': 'Lee Other'},
      ]
    };
  } else if (path.startsWith('/api/permission/permission/')) {
    body = {
      'statusCode': 200,
      'data': {
        'staff_permission': {
          'workorder_view': true,
          'workorder_add': true,
          'workorder_edit': true,
          'workorder_delete': true,
        }
      }
    };
  } else if (path.endsWith('/api/images/upload-workorder')) {
    body = {
      'status': 'ok',
      'files': [
        {'filename': 'upload.png'}
      ]
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _form => find.ancestor(
    of: find.text('Update Work Order'), matching: find.byType(Scaffold));

Finder _inForm(Finder f) => find.descendant(of: _form, matching: f);

bool _saveEnabled(WidgetTester tester) => tester
    .widget<ElevatedButton>(
        _inForm(find.widgetWithText(ElevatedButton, 'Save')))
    .onPressed !=
    null;

DropdownButton2<String> _dropdownWithValue(WidgetTester tester, String value) =>
    tester
        .widgetList<DropdownButton2<String>>(
            _inForm(find.byType(DropdownButton2<String>)))
        .firstWhere((d) => d.value == value);

Finder _noteField(String hint) => _inForm(find.byWidgetPredicate((w) =>
    w is TextField && w.decoration?.hintText == hint));

const _publicHint = 'Notes visible to all users';
const _privateHint = 'Notes visible only to admin and staff';

Future<void> _openUpdate(WidgetTester tester) async {
  final update = find.widgetWithText(ElevatedButton, 'Update');
  final openUpdate =
      update.evaluate().isNotEmpty ? update.first : find.text('Update').first;
  await tester.ensureVisible(openUpdate);
  await tester.pump();
  await tester.tap(openUpdate);
  await _settle(tester);
  expect(_form, findsOneWidget, reason: 'Update form is open');
}

// Real files for the fake gallery to hand back: the upload reads the file and
// the tile draws it.
late Directory _files;
late String _video, _photo, _thumb;
String _picked = '';

Finder get _tiles => _inForm(
    find.byWidgetPredicate((w) => w is Image && w.image is FileImage));
Finder get _playIcons => _inForm(find.byIcon(Icons.play_circle_fill));

/// Picks [file] from the gallery on the Update form. The upload reads the
/// real file, so alternate test time and real time until its tile shows.
Future<void> _attach(WidgetTester tester, String file) async {
  _picked = file;
  final before = _tiles.evaluate().length;
  final upload = _inForm(find.text('Upload Photos, Videos, or Documents'));
  await tester.ensureVisible(upload);
  await tester.pump();
  await tester.tap(upload);
  await _settle(tester, 10);
  await tester.tap(find.text('Gallery'));
  for (var i = 0; i < 40 && _tiles.evaluate().length == before; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
  }
  await _settle(tester, 10);
  expect(_tiles, findsNWidgets(before + 1), reason: 'the picked file shows');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    _files = Directory.systemTemp.createTempSync('wo_update_files');
    // A 1x1 PNG, so the tiles decode cleanly.
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
    _video = (File('${_files.path}/clip.mp4')..writeAsBytesSync([0, 0, 0, 0]))
        .path;
    _photo = (File('${_files.path}/photo.png')..writeAsBytesSync(png)).path;
    _thumb = (File('${_files.path}/clip_thumb.png')..writeAsBytesSync(png)).path;
  });

  tearDownAll(() => _files.deleteSync(recursive: true));

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/image_picker'),
        (call) async => call.method == 'pickMedia' ? [_picked] : null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.justsoft.xyz/video_thumbnail'),
        (_) async => _thumb);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    PathProviderPlatform.instance = _FakePaths();
  });

  Future<void> run(WidgetTester tester, Widget screen, String role,
      Future<void> Function(DateProvider dates) body) async {
    tester.view.physicalSize = const Size(430, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'STAFF-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
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
          child: MaterialApp(home: screen),
        ));
        await _settle(tester);
        await _openUpdate(tester);
        await body(dates);
      }, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  for (final c in [
    (
      name: 'Admin',
      screen: admin.Workorder_summery(workorder_id: 'WO-1') as Widget,
      role: 'Admin'
    ),
    (
      name: 'Staff',
      screen: staff.Workorder_summery(workorder_id: 'WO-1') as Widget,
      role: 'Staffmember'
    ),
  ]) {
    group('${c.name} Update Work Order', () {
      testWidgets('opens with Save disabled', (tester) async {
        await run(tester, c.screen, c.role, (_) async {
          expect(_dropdownWithValue(tester, 'In Progress').value, 'In Progress',
              reason: 'opens with the current status');
          expect(_saveEnabled(tester), isFalse,
              reason: 'nothing changed yet, like web');
        });
      });

      testWidgets('a note enables Save; spaces alone do not', (tester) async {
        await run(tester, c.screen, c.role, (_) async {
          for (final hint in [_publicHint, _privateHint]) {
            final note = _noteField(hint);
            expect(note, findsOneWidget, reason: '$hint field');
            await tester.enterText(note, '   ');
            await tester.pump();
            expect(_saveEnabled(tester), isFalse,
                reason: 'spaces only ($hint)');
            await tester.enterText(note, 'Checked the tap');
            await tester.pump();
            expect(_saveEnabled(tester), isTrue, reason: 'note typed ($hint)');
            await tester.enterText(note, '');
            await tester.pump();
            expect(_saveEnabled(tester), isFalse, reason: 'note cleared ($hint)');
          }
        });
      });

      testWidgets(
          'a new status shows and enables Save; changing it back disables it',
          (tester) async {
        await run(tester, c.screen, c.role, (_) async {
          _dropdownWithValue(tester, 'In Progress').onChanged!('Completed');
          await tester.pump();
          // The dropdown keeps every option's text in the tree for sizing, so
          // check the value it was rebuilt with, not just the text.
          expect(
              tester
                  .widgetList<DropdownButton2<String>>(
                      _inForm(find.byType(DropdownButton2<String>)))
                  .any((d) => d.value == 'Completed'),
              isTrue,
              reason: 'the picked status shows in the form');
          expect(_saveEnabled(tester), isTrue);
          _dropdownWithValue(tester, 'Completed').onChanged!('In Progress');
          await tester.pump();
          expect(_saveEnabled(tester), isFalse,
              reason: 'back to what it opened with');
        });
      });

      testWidgets('a new assignee enables Save', (tester) async {
        await run(tester, c.screen, c.role, (_) async {
          _dropdownWithValue(tester, 'S-1').onChanged!('S-2');
          await tester.pump();
          expect(_saveEnabled(tester), isTrue);
        });
      });

      testWidgets('a new due date enables Save', (tester) async {
        await run(tester, c.screen, c.role, (dates) async {
          final field = _inForm(find.text(dates.formatCurrentDate('2026-10-30')));
          expect(field, findsWidgets, reason: 'due date pre-filled');
          await tester.ensureVisible(field.first);
          await tester.pump();
          await tester.tap(field.first);
          await _settle(tester, 10);
          final picker = find.byType(DatePickerDialog);
          expect(picker, findsOneWidget);
          // The picker opens on the current month; any 1st differs from
          // 2026-10-30.
          await tester
              .tap(find.descendant(of: picker, matching: find.text('1')).first);
          await tester.pump();
          await tester.tap(find.text('OK'));
          await _settle(tester, 10);
          expect(_saveEnabled(tester), isTrue);
        });
      });

      testWidgets(
          'every Update starts with no files; a photo after a video shows no '
          'play icon', (tester) async {
        await run(tester, c.screen, c.role, (_) async {
          await _attach(tester, _video);
          expect(_playIcons, findsOneWidget,
              reason: 'the video tile shows its play icon');
          expect(_saveEnabled(tester), isTrue,
              reason: 'a picked file is a change, like web');

          // Leave without saving, then open Update again.
          Navigator.of(tester.element(_form)).pop();
          await _settle(tester);
          await _openUpdate(tester);
          expect(_tiles, findsNothing, reason: 'starts with no files, like web');
          expect(_saveEnabled(tester), isFalse);

          await _attach(tester, _photo);
          expect(_saveEnabled(tester), isTrue);
          expect(_playIcons, findsNothing,
              reason: 'the photo is not marked as the earlier video');
        });
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

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => _files.path;
}
