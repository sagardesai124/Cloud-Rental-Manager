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
import 'package:three_zero_two_property/Model/propertytype.dart';
import 'package:three_zero_two_property/StaffModule/repository/Property_type.dart'
    as staff_repo;
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/add_new_property.dart'
    as staff_add;
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/add_property.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/repository/Property_type.dart'
    as admin_repo;
import 'package:three_zero_two_property/screens/Rental/Properties/add_new_property.dart'
    as admin_add;
import 'package:three_zero_two_property/widgets/property_type_popup.dart';

/// Add Property / Edit Property → Add / Edit Property Type popup, like web
/// staging (AddpropertyModal.jsx, used by Rentals.jsx and
/// Staffpropertyadd.jsx): a Residential type needs a Syndication Property
/// Type (more choices when Multi Unit is ticked), Commercial has none, each
/// missing field shows web's message, the choice is saved with the type as
/// zillow_property_type, and the pencil next to a type edits it with the
/// saved choice filled in. Property Types → Add / Edit are left as they are,
/// as on web.

// ---------------------------------------------------------------- helpers

final _sent = <http.Request>[];
final _toasts = <String>[];
var _listFetches = 0;

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

const _types = [
  {
    '_id': 'X-1',
    'admin_id': 'ADMIN-1',
    'property_id': 'PT-1',
    'property_type': 'Residential',
    'propertysub_type': 'Townhome',
    'is_multiunit': false,
    'property_type_image': 'townhome.png',
    'zillow_property_type': 'TOWNHOUSE',
  },
  {
    '_id': 'X-2',
    'admin_id': 'ADMIN-1',
    'property_id': 'PT-2',
    'property_type': 'Commercial',
    'propertysub_type': 'Office',
    'is_multiunit': false,
    'property_type_image': '',
    'zillow_property_type': '',
  },
];

final _server = MockClient((request) async {
  final path = request.url.path;
  if (path == '/api/propertytype/property_type/ADMIN-1' &&
      request.method == 'GET') {
    _listFetches++;
    return _json({'statusCode': 200, 'data': _types});
  }
  if (path.startsWith('/api/propertytype/property_type') &&
      (request.method == 'POST' || request.method == 'PUT')) {
    _sent.add(request);
    return _json({
      'statusCode': 200,
      'message': request.method == 'POST'
          ? 'Property Type added Successfully'
          : 'Property type Updated Successfully',
    });
  }
  if (path == '/api/auth') {
    return _json({
      'statusCode': 200,
      'themes': {'format': 'YYYY-MM-DD', 'timeFormat': '24'},
    });
  }
  if (path.startsWith('/api/rentals/rental-owners/')) return _json([]);
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

// The field's label, "Syndication Property Type *".
final _syndicationLabel = find.byWidgetPredicate((w) =>
    w is RichText && w.text.toPlainText() == '$kSyndicationPropertyTypeLabel *');

Finder _inPopup(Finder f) =>
    find.descendant(of: find.byType(PropertyTypePopup), matching: f);

Finder get _popupDropdowns => _inPopup(
    find.byWidgetPredicate((w) => w is DropdownButton2<String>));

Future<void> _pick(WidgetTester tester, int dropdown, String label) async {
  await _tap(tester, _popupDropdowns.at(dropdown));
  await _tap(tester, find.text(label).last);
}

void _mockPlatform() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
    final args = call.arguments;
    if (args is Map && args['msg'] != null) _toasts.add('${args['msg']}');
    return true;
  });
  ConnectivityPlatform.instance = _Online();
}

/// Opens the popup from a button, like the property form does.
Future<Future<bool?>> _openPopup(
  WidgetTester tester, {
  propertytype? editing,
  required PropertyTypePopupSave onSave,
}) async {
  late Future<bool?> result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => result =
                showPropertyTypePopup(context, editing: editing, onSave: onSave),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester);
  expect(find.byType(PropertyTypePopup), findsOneWidget);
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------ web's rules
  group("web's rules", () {
    test("web's choices, labels and messages", () {
      String show(List<SyndicationOption> o) =>
          o.map((e) => '${e.value}=${e.label}').join(' | ');
      expect(
          show(syndicationOptionsFor(false)),
          'CONDO=Condo / Apartment | HOUSE=House | TOWNHOUSE=Townhouse');
      expect(
          show(syndicationOptionsFor(true)),
          'CONDO=Condo / Apartment | HOUSE=House | TOWNHOUSE=Townhouse | '
          'DIVIDED=Divided (Duplex/Triplex/Fourplex) | '
          'MEDIUM=Medium (5-49 Units) | LARGE=Large (50+ Units) | '
          'COMMUNITY=Community / Mobile Home Park');
      expect(kSyndicationPropertyTypeLabel, 'Syndication Property Type');
      expect(kSyndicationPropertyTypeHint, 'Select Syndication Property Type');
      expect(kSelectPropertyTypeMessage, 'Please select property type');
      expect(kEnterPropertySubTypeMessage, 'Please enter property sub type');
      expect(kSelectSyndicationTypeMessage,
          'Please select Syndication Property Type');
      expect(kCorrectRedBoxesMessage, 'Please correct the red boxes above');
    });

    test('each missing field gets its own message', () {
      var e = propertyTypePopupErrors(type: null, subType: ' ', syndication: null);
      expect([e.type, e.subType, e.syndication],
          [kSelectPropertyTypeMessage, kEnterPropertySubTypeMessage, null]);
      e = propertyTypePopupErrors(
          type: 'Residential', subType: 'Townhome', syndication: null);
      expect(e.syndication, kSelectSyndicationTypeMessage,
          reason: 'needed for Residential');
      e = propertyTypePopupErrors(
          type: 'Commercial', subType: 'Office', syndication: null);
      expect(e.any, isFalse, reason: 'not needed for Commercial');
      e = propertyTypePopupErrors(
          type: 'Residential', subType: 'Townhome', syndication: 'HOUSE');
      expect(e.any, isFalse);
    });

    test('the choice is cleared when the type leaves Residential', () {
      expect(
          keptSyndicationChoice(
              type: 'Commercial', isMultiUnit: false, current: 'HOUSE'),
          isNull);
      expect(
          keptSyndicationChoice(
              type: 'Residential', isMultiUnit: false, current: 'HOUSE'),
          'HOUSE');
      expect(
          keptSyndicationChoice(
              type: 'Residential', isMultiUnit: false, current: 'LARGE'),
          isNull,
          reason: 'a multi-unit choice is not offered without Multi Unit');
      expect(
          keptSyndicationChoice(
              type: 'Residential', isMultiUnit: true, current: 'LARGE'),
          'LARGE');
    });
  });

  // ------------------------------------------------------------ the popup
  group('the popup', () {
    setUp(() {
      _sent.clear();
      _toasts.clear();
      _mockPlatform();
    });

    testWidgets('adding: Residential needs the Syndication Property Type',
        (tester) async {
      PropertyTypePopupValues? saved;
      final result = await _openPopup(tester, onSave: (v) async => saved = v);
      expect(find.text('New Property Type'), findsOneWidget);
      expect(_syndicationLabel, findsNothing, reason: 'no type chosen yet');

      // Nothing filled in: web's message under each missing field.
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Add'));
      expect(find.text(kSelectPropertyTypeMessage), findsOneWidget);
      expect(find.text(kEnterPropertySubTypeMessage), findsOneWidget);
      expect(find.text(kCorrectRedBoxesMessage), findsOneWidget);
      expect(saved, isNull);

      // Residential: the field appears, required.
      await _pick(tester, 0, 'Residential');
      expect(find.text(kSelectPropertyTypeMessage), findsNothing);
      expect(_syndicationLabel, findsOneWidget);
      expect(find.text(kSyndicationPropertyTypeHint), findsOneWidget);
      expect(find.text(kSelectSyndicationTypeMessage), findsOneWidget);

      await tester.enterText(_inPopup(find.byType(TextFormField)), 'Duplex');
      await _settle(tester, 5);
      expect(find.text(kEnterPropertySubTypeMessage), findsNothing);

      // Single unit: web's three choices.
      await _tap(tester, _popupDropdowns.at(1));
      expect(find.text('Condo / Apartment'), findsOneWidget);
      expect(find.text('Large (50+ Units)'), findsNothing);
      await _tap(tester, find.text('House').last);

      // Multi Unit: the larger choices too; a multi-unit choice is cleared
      // when Multi Unit is unticked again.
      await _tap(tester, _inPopup(find.byType(Checkbox)));
      await _pick(tester, 1, 'Divided (Duplex/Triplex/Fourplex)');
      await _tap(tester, _inPopup(find.byType(Checkbox)));
      expect(find.text('Divided (Duplex/Triplex/Fourplex)'), findsNothing);
      expect(find.text(kSelectSyndicationTypeMessage), findsOneWidget);
      await _tap(tester, _inPopup(find.byType(Checkbox)));
      await _pick(tester, 1, 'Divided (Duplex/Triplex/Fourplex)');
      expect(find.text(kCorrectRedBoxesMessage), findsNothing);

      await _tap(tester, find.widgetWithText(ElevatedButton, 'Add'));
      expect(saved, isNotNull);
      expect(saved!.propertyType, 'Residential');
      expect(saved!.propertySubType, 'Duplex');
      expect(saved!.isMultiUnit, isTrue);
      expect(saved!.syndicationType, 'DIVIDED');
      expect(await result, isTrue);
      expect(find.byType(PropertyTypePopup), findsNothing);
    });

    testWidgets('Commercial has no Syndication Property Type; switching to it '
        'clears the choice', (tester) async {
      PropertyTypePopupValues? saved;
      await _openPopup(tester, onSave: (v) async => saved = v);
      await _pick(tester, 0, 'Residential');
      await _pick(tester, 1, 'House');
      await _pick(tester, 0, 'Commercial');
      expect(_syndicationLabel, findsNothing);
      // Back to Residential: the earlier choice is gone, like web.
      await _pick(tester, 0, 'Residential');
      expect(find.text(kSyndicationPropertyTypeHint), findsOneWidget);
      await _pick(tester, 0, 'Commercial');
      await tester.enterText(_inPopup(find.byType(TextFormField)), 'Office');
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Add'));
      expect(saved!.propertyType, 'Commercial');
      expect(saved!.syndicationType, '');
    });

    testWidgets('editing: filled in from the saved type, saves with Update',
        (tester) async {
      PropertyTypePopupValues? saved;
      final type = propertytype.fromJson({
        'property_id': 'PT-9',
        'property_type': 'Residential',
        'propertysub_type': 'Apartments',
        'is_multiunit': true,
        'zillow_property_type': 'LARGE',
      });
      await _openPopup(tester, editing: type, onSave: (v) async => saved = v);
      expect(find.text('Edit Property Type'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Update'), findsOneWidget);
      expect(find.text('Large (50+ Units)'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(_inPopup(find.byType(TextFormField)))
              .controller!
              .text,
          'Apartments');
      await tester.enterText(
          _inPopup(find.byType(TextFormField)), 'Apartments North');
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Update'));
      expect(saved!.propertySubType, 'Apartments North');
      expect(saved!.isMultiUnit, isTrue);
      expect(saved!.syndicationType, 'LARGE');
    });

    testWidgets('a failed save keeps the popup open, as before',
        (tester) async {
      await _openPopup(tester,
          onSave: (_) async => throw Exception('Name Already Added'));
      await _pick(tester, 0, 'Commercial');
      await tester.enterText(_inPopup(find.byType(TextFormField)), 'Office');
      await _tap(tester, find.widgetWithText(ElevatedButton, 'Add'));
      expect(find.byType(PropertyTypePopup), findsOneWidget);
      expect(
          tester
              .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Add'))
              .onPressed,
          isNotNull);
    });
  });

  // ------------------------------------------------------------ the pencil
  group('the pencil', () {
    testWidgets('closes the open list without choosing the type, then edits',
        (tester) async {
      String? chosen;
      var edits = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) => DropdownButton2<String>(
                  isExpanded: true,
                  value: chosen,
                  hint: const Text('Add Property Type'),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'Townhome',
                      child: Row(children: [
                        const Expanded(child: Text('Townhome')),
                        PropertyTypeEditPencil(onEdit: () => edits++),
                      ]),
                    ),
                  ],
                  selectedItemBuilder: (_) => [const Text('Townhome')],
                  onChanged: (v) => setState(() => chosen = v),
                ),
              ),
            ),
          ),
        ),
      ));
      await _tap(tester, find.text('Add Property Type'));
      expect(find.byType(PropertyTypeEditPencil), findsOneWidget);
      await _tap(tester, find.byType(PropertyTypeEditPencil));
      expect(edits, 1);
      expect(chosen, isNull, reason: 'the type is not chosen');
      expect(find.byType(PropertyTypeEditPencil), findsNothing,
          reason: 'the list closed');
      expect(find.text('Add Property Type'), findsOneWidget,
          reason: 'the page is still there');
    });

    testWidgets('outside an open list it never closes the page',
        (tester) async {
      var edits = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator, home: const Text('home')));
      navigator.currentState!.push(MaterialPageRoute(
          builder: (_) => Scaffold(
              body: PropertyTypeEditPencil(onEdit: () => edits++))));
      await _settle(tester);
      await _tap(tester, find.byType(PropertyTypeEditPencil));
      expect(edits, 1);
      expect(find.byType(PropertyTypeEditPencil), findsOneWidget);
    });
  });

  // ------------------------------------------------------------ saving
  group('saving (Admin and Staff)', () {
    setUp(() {
      _sent.clear();
      _toasts.clear();
      _mockPlatform();
      SharedPreferences.setMockInitialValues(
          {'token': 'tkn', 'adminId': 'ADMIN-1', 'staff_id': 'STAFF-1'});
    });

    for (final who in ['Admin', 'Staff']) {
      test('$who: the choice is sent only when given', () async {
        await http.runWithClient(() async {
          Future<void> add({String? zillow}) => who == 'Admin'
              ? admin_repo.PropertyTypeRepository().addPropertyType(
                  adminId: 'ADMIN-1',
                  propertyType: 'Residential',
                  propertySubType: 'Duplex',
                  isMultiUnit: true,
                  zillowPropertyType: zillow)
              : staff_repo.PropertyTypeRepository().addPropertyType(
                  adminId: 'ADMIN-1',
                  propertyType: 'Residential',
                  propertySubType: 'Duplex',
                  isMultiUnit: true,
                  zillowPropertyType: zillow);
          Future<void> edit({String? zillow}) => who == 'Admin'
              ? admin_repo.PropertyTypeRepository().EditPropertyType(
                  adminId: 'ADMIN-1',
                  id: 'PT-1',
                  propertyType: 'Residential',
                  propertySubType: 'Townhome',
                  isMultiUnit: false,
                  propertyTypeImage: 'townhome.png',
                  zillowPropertyType: zillow)
              : staff_repo.PropertyTypeRepository().EditPropertyType(
                  adminId: 'ADMIN-1',
                  id: 'PT-1',
                  propertyType: 'Residential',
                  propertySubType: 'Townhome',
                  isMultiUnit: false,
                  propertyTypeImage: 'townhome.png',
                  zillowPropertyType: zillow);
          await add(zillow: 'DIVIDED');
          await add();
          await edit(zillow: 'HOUSE');
          await edit();
        }, () => _server);
        expect(_sent, hasLength(4));
        expect(_body(_sent[0])['zillow_property_type'], 'DIVIDED');
        expect(_body(_sent[1]).containsKey('zillow_property_type'), isFalse,
            reason: 'Property Types → Add sends no choice, like web');
        expect(_sent[2].method, 'PUT');
        expect(_sent[2].url.path, '/api/propertytype/property_type/PT-1');
        expect(_body(_sent[2])['zillow_property_type'], 'HOUSE');
        expect(_body(_sent[3]).containsKey('zillow_property_type'), isFalse,
            reason: 'Property Types → Edit keeps the stored choice');
      });
    }
  });

  // ------------------------------------------------------------ real screens
  group('on the real Add Property screen', () {
    setUp(() {
      _sent.clear();
      _toasts.clear();
      _listFetches = 0;
      _mockPlatform();
    });

    for (final isStaff in [false, true]) {
      final role = isStaff ? 'Staff' : 'Admin';
      testWidgets('$role: add a Residential type with its Syndication '
          'Property Type, and edit a type with the pencil', (tester) async {
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          if (details.library == 'image resource service') return;
          original?.call(details);
        };
        try {
          await http.runWithClient(() async {
            SharedPreferences.setMockInitialValues(isStaff
                ? {
                    'token': 'tkn',
                    'adminId': 'ADMIN-1',
                    'staff_id': 'STAFF-1',
                    'role': 'Staffmember',
                  }
                : {'token': 'tkn', 'adminId': 'ADMIN-1', 'role': 'Admin'});
            tester.view.physicalSize = const Size(430, 3200);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            final dates = DateProvider();
            await dates.loadDateFormat();
            await tester.pumpWidget(MultiProvider(
              providers: [
                ChangeNotifierProvider<DateProvider>.value(value: dates),
                ChangeNotifierProvider(create: (_) => OwnerDetailsProvider()),
                ChangeNotifierProvider(create: (_) => NotificationProvider()),
                ChangeNotifierProvider(
                    create: (_) => checkPlanPurchaseProiver()),
                ChangeNotifierProvider(
                    create: (_) => StaffPermissionProvider()),
              ],
              child: MaterialApp(
                home: isStaff
                    ? staff_add.Add_new_property()
                    : admin_add.Add_new_property(),
              ),
            ));
            await _settle(tester, 40);

            final typeList = find.byWidgetPredicate((w) =>
                w is DropdownButton2<String> &&
                (w.items ?? const [])
                    .any((i) => i.value == 'Edit_properties'));
            expect(typeList, findsOneWidget);

            // The pencil next to each type, like web.
            await _tap(tester, typeList);
            expect(find.byType(PropertyTypeEditPencil), findsNWidgets(2));
            final townhomePencil = find.descendant(
                of: find
                    .ancestor(
                        of: find.text('Townhome').last,
                        matching: find.byType(Row))
                    .first,
                matching: find.byType(PropertyTypeEditPencil));
            await _tap(tester, townhomePencil);
            expect(find.text('Edit Property Type'), findsOneWidget);
            expect(find.text('Townhouse'), findsOneWidget,
                reason: 'the saved choice is filled in');
            final fetchesBefore = _listFetches;
            await tester.enterText(
                _inPopup(find.byType(TextFormField)), 'Townhome Deluxe');
            await _tap(tester, find.widgetWithText(ElevatedButton, 'Update'));
            expect(_sent, hasLength(1));
            final put = _sent.single;
            expect(put.method, 'PUT');
            expect(put.url.path, '/api/propertytype/property_type/PT-1');
            expect(_body(put)['propertysub_type'], 'Townhome Deluxe');
            expect(_body(put)['zillow_property_type'], 'TOWNHOUSE');
            expect(_body(put)['property_type_image'], 'townhome.png',
                reason: 'the saved image is kept');
            expect(find.byType(PropertyTypePopup), findsNothing);
            expect(_listFetches, greaterThan(fetchesBefore),
                reason: 'the list is fetched again');

            // Add Property Type from the list: web's rules.
            await _tap(tester, typeList);
            await _tap(tester, find.text('Add New properties').last);
            expect(find.text('New Property Type'), findsOneWidget);
            await _pick(tester, 0, 'Residential');
            await tester.enterText(
                _inPopup(find.byType(TextFormField)), 'Duplex');
            await _tap(tester, _inPopup(find.byType(Checkbox)));
            await _tap(tester, find.widgetWithText(ElevatedButton, 'Add'));
            expect(find.text(kSelectSyndicationTypeMessage), findsOneWidget);
            expect(_sent, hasLength(1), reason: 'nothing sent yet');
            await _pick(tester, 1, 'Divided (Duplex/Triplex/Fourplex)');
            await _tap(tester, find.widgetWithText(ElevatedButton, 'Add'));
            expect(_sent, hasLength(2));
            final post = _sent.last;
            expect(post.method, 'POST');
            expect(_body(post)['property_type'], 'Residential');
            expect(_body(post)['propertysub_type'], 'Duplex');
            expect(_body(post)['is_multiunit'], isTrue);
            expect(_body(post)['zillow_property_type'], 'DIVIDED');
            expect(find.byType(PropertyTypePopup), findsNothing);

            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 2));
          }, () => _server);
        } finally {
          FlutterError.onError = original;
        }
      });
    }
  });

  // ------------------------------------------------------------ all 4 forms
  test('Add and Edit Property, Admin and Staff, use the popup and pencil', () {
    for (final path in [
      'lib/screens/Rental/Properties/add_new_property.dart',
      'lib/screens/Rental/Properties/EditProperties.dart',
      'lib/StaffModule/screen/Rental/Properties/add_new_property.dart',
      'lib/StaffModule/screen/Rental/Properties/EditProperties.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('showPropertyTypePopup('), reason: path);
      expect(src, contains('zillowPropertyType: values.syndicationType,'),
          reason: path);
      expect('PropertyTypeEditPencil('.allMatches(src).length, 1,
          reason: path);
      expect(src, contains('propertyTypeImage: item.propertyTypeImage,'),
          reason: path);
      expect(src, isNot(contains("'New Property Type'")),
          reason: '$path: the old popup is gone');
    }
    // Property Types → Add / Edit stay as they are, like web.
    for (final path in [
      'lib/screens/Property_Type/Add_property_type.dart',
      'lib/screens/Property_Type/Edit_property_type.dart',
      'lib/StaffModule/screen/Property_Type/Add_property_type.dart',
      'lib/StaffModule/screen/Property_Type/Edit_property_type.dart',
    ]) {
      expect(File(path).readAsStringSync(), isNot(contains('zillow')),
          reason: path);
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
