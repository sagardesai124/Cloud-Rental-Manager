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
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/EditProperties.dart'
    as staff_edit;
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/add_property.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/EditProperties.dart'
    as admin_edit;
import 'package:three_zero_two_property/widgets/property_type_popup.dart';

/// Edit Property, like web staging (Rentals.jsx / Staffpropertyadd.jsx, the
/// pages Admin and Staff use to add and edit a property): the property type
/// can be changed while editing. Every unit is kept with its id, values,
/// amenities and photo; the save sends the new type. Before, the type list
/// was locked on Edit Property, so the Add / Edit Property Type popup could
/// not be reached there either.

const _rental = {
  '_id': 'X-R1',
  'rental_id': 'R-1',
  'admin_id': 'ADMIN-1',
  'property_id': 'PT-1',
  'rentalowner_id': 'RO-1',
  'rental_adress': '12 Main St',
  'rental_city': 'Austin',
  'rental_state': 'TX',
  'rental_country': 'USA',
  'rental_postcode': '73301',
  'placed_in_service': '2024-01-15',
  'subdivision': '',
  'staffmember_id': '',
  'property_type_data': {
    'property_id': 'PT-1',
    'property_type': 'Residential',
    'propertysub_type': 'Townhome',
    'is_multiunit': false,
  },
  'rental_owner_data': {
    'rentalowner_id': 'RO-1',
    'rentalOwner_name': 'Pat Owner',
    'rentalOwner_firstName': 'Pat',
    'rentalOwner_lastName': 'Owner',
    'rentalOwner_companyName': 'Pat Co',
    'rentalOwner_primaryEmail': 'pat@example.com',
    'rentalOwner_phoneNumber': '5551112222',
    'street_address': '1 Owner Way',
    'city': 'Austin',
    'state': 'TX',
    'country': 'USA',
    'postal_code': '73301',
    'processor_list': [
      {'processor_id': 'PR-1'}
    ],
  },
};

const _unit = {
  '_id': 'X-U1',
  'unit_id': 'U-1',
  'rental_id': 'R-1',
  'admin_id': 'ADMIN-1',
  'rental_unit': '',
  'rental_unit_adress': '',
  'rental_sqft': '900',
  'rental_bath': '1 Bath',
  'rental_bed': '2 Bed',
  'rental_unit_price': '1500',
  'lease_term': 'ContactForDetails',
  'description': 'Sunny unit',
  'amenities': ['Pool'],
  'rental_images': ['u1.png'],
};

const _types = [
  {
    'property_id': 'PT-1',
    'admin_id': 'ADMIN-1',
    'property_type': 'Residential',
    'propertysub_type': 'Townhome',
    'is_multiunit': false,
  },
  {
    'property_id': 'PT-2',
    'admin_id': 'ADMIN-1',
    'property_type': 'Residential',
    'propertysub_type': 'Duplex',
    'is_multiunit': true,
  },
  {
    'property_id': 'PT-3',
    'admin_id': 'ADMIN-1',
    'property_type': 'Commercial',
    'propertysub_type': 'Office',
    'is_multiunit': false,
  },
];

final _saves = <http.Request>[];
final _toasts = <String>[];

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

final _server = MockClient((request) async {
  final path = request.url.path;
  if (request.method == 'PUT' && path == '/api/rentals/rentals/R-1') {
    _saves.add(request);
    return _json({'statusCode': 200, 'message': 'Property Updated'});
  }
  if (path == '/api/rentals/rental_summary/R-1') {
    return _json({
      'statusCode': 200,
      'data': [_rental]
    });
  }
  if (path == '/api/unit/rental_unit/R-1') {
    return _json({
      'statusCode': 200,
      'data': [_unit]
    });
  }
  if (path == '/api/propertytype/property_type/ADMIN-1') {
    return _json({'statusCode': 200, 'data': _types});
  }
  if (path.startsWith('/api/rentals/rental-owners/')) return _json([]);
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  return _json({'statusCode': 200, 'data': []});
});

Map<String, dynamic> _body(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

Future<void> _settle(WidgetTester tester, [int ticks = 20]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target, warnIfMissed: false);
  await _settle(tester, 12);
}

/// A text box currently showing [text].
Finder _box(String text) => find.byWidgetPredicate(
    (w) => w is EditableText && w.controller.text == text);

/// The Property Type list (the one that offers "Add New properties").
final _typeList = find.byWidgetPredicate((w) =>
    w is DropdownButton2<String> &&
    (w.items ?? const []).any((i) => i.value == 'Edit_properties'));

Future<void> _open(WidgetTester tester, bool isStaff) async {
  SharedPreferences.setMockInitialValues(isStaff
      ? {
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'role': 'Staffmember',
        }
      : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
  tester.view.physicalSize = const Size(430, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dates = DateProvider();
  await dates.loadDateFormat();
  final property =
      Rentals.fromJson(jsonDecode(jsonEncode(_rental)) as Map<String, dynamic>);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<DateProvider>.value(value: dates),
      ChangeNotifierProvider(create: (_) => OwnerDetailsProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
      ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
    ],
    child: MaterialApp(
      home: isStaff
          ? staff_edit.Edit_properties(properties: property, rentalId: 'R-1')
          : admin_edit.Edit_properties(properties: property, rentalId: 'R-1'),
    ),
  ));
  await _settle(tester, 80);
  expect(_typeList, findsOneWidget);
  expect(_box('900'), findsWidgets, reason: 'the saved unit loaded');
}

Future<void> _pickType(WidgetTester tester, String subType) async {
  await _tap(tester, _typeList);
  await _tap(tester, find.text(subType).last);
}

Future<void> _save(WidgetTester tester) async {
  await _tap(tester, find.text('Update Property'));
  await _settle(tester, 30);
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
      await tester.pump(const Duration(seconds: 2));
    }, () => _server);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _saves.clear();
    _toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      final args = call.arguments;
      if (args is Map && args['msg'] != null) _toasts.add('${args['msg']}');
      return true;
    });
    ConnectivityPlatform.instance = _Online();
  });

  for (final isStaff in [false, true]) {
    final role = isStaff ? 'Staff' : 'Admin';

    testWidgets('$role: the type list opens on Edit Property, with the pencil',
        (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        final list = tester.widget<DropdownButton2<String>>(_typeList);
        expect(list.onChanged, isNotNull, reason: 'no longer locked');
        await _tap(tester, _typeList);
        expect(find.byType(PropertyTypeEditPencil), findsNWidgets(3));
      });
    });

    testWidgets('$role: Townhome → Duplex keeps the unit, laid out for '
        'multi-unit, and saves the new type', (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        await _pickType(tester, 'Duplex');

        // Laid out for a multi-unit residential type, values carried over.
        final unitName = find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == 'Enter unit');
        expect(unitName, findsOneWidget);
        expect(_box('900'), findsWidgets);
        expect(_box('1500'), findsWidgets);
        expect(_box('Sunny unit'), findsWidgets);

        await tester.enterText(unitName, 'A1');
        await _settle(tester, 5);
        await _save(tester);

        expect(_saves, hasLength(1));
        final body = _body(_saves.single);
        expect((body['rental'] as Map)['property_id'], 'PT-2');
        final units = body['units'] as List;
        expect(units, hasLength(1));
        final u = units.single as Map;
        expect(u['unit_id'], 'U-1', reason: 'the same unit, not a new one');
        expect(u['rental_unit'], 'A1');
        expect(u['rental_sqft'], '900');
        expect(u['rental_bed'], '2 Bed');
        expect(u['rental_bath'], '1 Bath');
        expect('${u['rental_unit_price']}', '1500');
        expect(u['description'], 'Sunny unit');
        expect(u['amenities'], ['Pool']);
        expect(u['rental_images'], ['u1.png'],
            reason: 'the photo is kept (web drops it)');
      });
    });

    testWidgets('$role: Townhome → Office keeps the unit and its bed and bath',
        (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        await _pickType(tester, 'Office');
        expect(_box('900'), findsWidgets);
        expect(_box('Sunny unit'), findsWidgets);

        // Only the type changed, and that is a change: it saves.
        await _save(tester);
        expect(_toasts, isNot(contains('No changes detected')));
        expect(_saves, hasLength(1));
        final body = _body(_saves.single);
        expect((body['rental'] as Map)['property_id'], 'PT-3');
        final u = (body['units'] as List).single as Map;
        expect(u['unit_id'], 'U-1');
        expect(u['rental_sqft'], '900');
        expect(u['rental_bed'], '2 Bed', reason: 'kept, like web');
        expect(u['rental_bath'], '1 Bath', reason: 'kept, like web');
        expect(u['description'], 'Sunny unit');
        expect(u['rental_images'], ['u1.png']);
      });
    });

    testWidgets('$role: "Add New properties" keeps the current type',
        (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        await _tap(tester, _typeList);
        await _tap(tester, find.text('Add New properties').last);
        expect(find.byType(PropertyTypePopup), findsOneWidget);
        await _tap(
            tester,
            find.descendant(
                of: find.byType(PropertyTypePopup),
                matching: find.widgetWithText(OutlinedButton, 'Cancel')));
        expect(find.byType(PropertyTypePopup), findsNothing);
        expect(tester.widget<DropdownButton2<String>>(_typeList).value,
            'Townhome');
      });
    });

    testWidgets('$role: nothing changed still saves nothing', (tester) async {
      await _run(tester, () async {
        await _open(tester, isStaff);
        await _save(tester);
        expect(_toasts, contains('No changes detected'));
        expect(_saves, isEmpty);
      });
    });
  }

  test('Admin and Staff Edit Property use the same rules', () {
    for (final path in [
      'lib/screens/Rental/Properties/EditProperties.dart',
      'lib/StaffModule/screen/Rental/Properties/EditProperties.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('onChanged: _unitsLoaded'), reason: path);
      expect(src, contains('_relayoutUnits(oldType: oldType, oldMulti: oldMulti);'),
          reason: path);
      expect('propertyId: _selectedTypeId,'.allMatches(src).length, 2,
          reason: path);
      expect(src, contains('_typeChanged ||'), reason: path);
      expect(src, isNot(contains('isEditable')), reason: path);
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
