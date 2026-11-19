import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Property_Type/Property_type_table.dart'
    as staff;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Property_Type/Property_type_table.dart'
    as admin;
import 'package:three_zero_two_property/services/property_type_search.dart';

/// Settings → Property Types, like web staging (property-types-v2, the page
/// Admin and Staff both use): the search also finds a type by its Created On
/// and Updated On dates as the list shows them (company date format), the
/// search text is trimmed, and the prompt reads "Search type or date". Before,
/// only the main type and sub type were searched, and the Staff list showed
/// its dates as yyyy-MM-dd whatever the company format.

const _types = [
  {
    '_id': 'X-1',
    'admin_id': 'ADMIN-1',
    'property_id': 'PT-1',
    'property_type': 'Residential',
    'propertysub_type': 'Townhome',
    'is_multiunit': false,
    'createdAt': '2026-09-24T10:15:30.000Z',
    'updatedAt': '2026-10-05T08:00:00.000Z',
  },
  {
    '_id': 'X-2',
    'admin_id': 'ADMIN-1',
    'property_id': 'PT-2',
    'property_type': 'Commercial',
    'propertysub_type': 'Office',
    'is_multiunit': false,
    'createdAt': '2026-08-01T12:00:00.000Z',
  },
];

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/propertytype/property_type/ADMIN-1') {
    return _json({'statusCode': 200, 'data': _types});
  }
  if (path.startsWith('/api/permission/permission/')) {
    return _json({
      'statusCode': 200,
      'data': {
        'staff_permission': {
          'propertytype_view': true,
          'propertytype_add': true,
          'propertytype_edit': true,
          'propertytype_delete': true,
        }
      }
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      // A company format that is neither yyyy-MM-dd nor the app default.
      'themes': {'format': 'DD/MM/YYYY', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _searchBox = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == kPropertyTypeSearchHint);

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(_searchBox, text);
  await _settle(tester, 6);
}

/// The sub types the list shows right now.
Set<String> _rows() => {
      for (final s in ['Townhome', 'Office'])
        if (find.text(s).evaluate().isNotEmpty) s
    };

Future<void> _open(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember',
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  // Staff permissions are loaded in the app before this list opens.
  final permissions = StaffPermissionProvider();
  if (isStaff) await permissions.fetchPermissions();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider<StaffPermissionProvider>.value(value: permissions),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
    ],
    // As Settings shows it: embedded in a scrolling list.
    child: MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          isStaff
              ? const staff.PropertyTable(isEmbedded: true)
              : const admin.PropertyTable(isEmbedded: true),
        ]),
      ),
    ),
  ));
  await _settle(tester, 40);
  expect(_rows(), {'Townhome', 'Office'});
}

Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    if (details.library == 'image resource service') return;
    original?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("web's rule", () {
    test("web's prompt", () {
      expect(kPropertyTypeSearchHint, 'Search type or date');
    });

    test('type, sub type and both dates as shown; trimmed; any case', () {
      bool match(String q) => propertyTypeMatchesSearch(q,
          type: 'Residential',
          subType: 'Townhome',
          createdOn: '24/09/2026',
          updatedOn: '05/10/2026');
      expect(match('resid'), isTrue);
      expect(match('TOWN'), isTrue);
      expect(match('24/09'), isTrue, reason: 'Created On as shown');
      expect(match('05/10/2026'), isTrue, reason: 'Updated On as shown');
      expect(match('  townhome  '), isTrue, reason: 'trimmed, like web');
      expect(match(''), isTrue);
      expect(match('   '), isTrue);
      expect(match('office'), isFalse);
      expect(match('2026-09-24'), isFalse,
          reason: 'the stored text is not what the list shows');
    });

    test('a missing date is never matched', () {
      expect(propertyTypeShownDay(null, (v) => 'shown $v'), '');
      expect(propertyTypeShownDay('  ', (v) => 'shown $v'), '');
      expect(propertyTypeShownDay('2026-08-01', (v) => 'shown $v'),
          'shown 2026-08-01');
      expect(
          propertyTypeMatchesSearch('n/a',
              type: 'Commercial', subType: 'Office', createdOn: '01/08/2026'),
          isFalse);
    });
  });

  group('on the real Property Types list', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('PonnamKarthik/fluttertoast'),
              (_) async => true);
      ConnectivityPlatform.instance = _Online();
    });

    for (final isStaff in [false, true]) {
      final role = isStaff ? 'Staff' : 'Admin';

      testWidgets('$role: search by type, sub type, Created On and Updated On '
          'as shown', (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);
          expect(_searchBox, findsOneWidget, reason: "web's prompt");

          await _search(tester, '24/09/2026');
          expect(_rows(), {'Townhome'}, reason: 'Created On');
          await _search(tester, '05/10/2026');
          expect(_rows(), {'Townhome'}, reason: 'Updated On');
          await _search(tester, '01/08');
          expect(_rows(), {'Office'}, reason: 'Created On, part of it');
          await _search(tester, '  office  ');
          expect(_rows(), {'Office'}, reason: 'trimmed');
          await _search(tester, 'resid');
          expect(_rows(), {'Townhome'}, reason: 'main type');

          // Text the list does not show is not matched.
          await _search(tester, '2026-09-24');
          expect(_rows(), isEmpty);
          await _search(tester, 't10:15');
          expect(_rows(), isEmpty);

          await _search(tester, '');
          expect(_rows(), {'Townhome', 'Office'});
        });
      });

      testWidgets('$role: the dates show in the company format',
          (tester) async {
        await _run(tester, () async {
          await _open(tester, isStaff);
          // The Townhome row's expand arrow (the column headers use the
          // same icon, so take the one level with the row).
          final arrows = find.byWidgetPredicate(
              (w) => w is FaIcon && w.icon == FontAwesomeIcons.sortDown);
          final rowY = tester.getCenter(find.text('Townhome')).dy;
          Finder? expand;
          var best = double.infinity;
          for (var i = 0; i < arrows.evaluate().length; i++) {
            final d = (tester.getCenter(arrows.at(i)).dy - rowY).abs();
            if (d < best) {
              best = d;
              expand = arrows.at(i);
            }
          }
          await tester.tap(expand!, warnIfMissed: false);
          await _settle(tester, 10);
          // "Created On : 24/09/2026" is one rich text line.
          Finder shows(String t) => find.textContaining(t, findRichText: true);
          expect(shows('Created On'), findsOneWidget, reason: 'row expanded');
          expect(shows('24/09/2026'), findsOneWidget,
              reason: 'Created On in the company format');
          expect(shows('05/10/2026'), findsOneWidget,
              reason: 'Updated On in the company format');
          expect(shows('2026-09-24'), findsNothing);
        });
      });
    }
  });

  test('Admin and Staff use the same rule and prompt', () {
    for (final path in [
      'lib/screens/Property_Type/Property_type_table.dart',
      'lib/StaffModule/screen/Property_Type/Property_type_table.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('propertyTypeMatchesSearch('), reason: path);
      expect(src, contains('hintText: kPropertyTypeSearchHint,'), reason: path);
      expect(src, isNot(contains('"Search here..."')), reason: path);
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

