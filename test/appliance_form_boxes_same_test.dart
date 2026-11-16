import 'dart:convert';

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
import 'package:three_zero_two_property/Model/unit.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/Add_applience.dart'
    as staff_add;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/edit_appliences.dart'
    as staff_edit;
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/applience/Add_applience.dart'
    as admin_add;
import 'package:three_zero_two_property/screens/Rental/Properties/applience/edit_appliences.dart'
    as admin_edit;

/// Add / Edit Infrastructure (Admin and Staff): the Type, Category, Brand and
/// Status dropdowns look like the text boxes (Model, Serial Number, dates):
/// the same white box with a grey border, round corners, no shadow, the same
/// height, the text starting at the same place, and the same gap under the
/// label. Before, the dropdowns had a shadow, no border, smaller corners,
/// were shorter, and their text started further right.

class _Server {
  late final MockClient client = MockClient((request) async {
    Object body = {'statusCode': 200, 'data': []};
    if (request.url.path.contains('/api/settings/allCategories/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'category_id': 'C-1', 'name': 'Refrigerator', 'brands': ['LG']}
        ]
      };
    }
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
}

unit_appliance _fridge() => unit_appliance(
      applianceId: 'A-1',
      applianceName: 'Fridge',
      applianceDescription: 'Kitchen',
      categoryId: 'C-1',
      status: 'Working',
      brand: 'LG',
      installedDate: '2026-01-15',
    );

Future<void> _settle(WidgetTester tester, [int ticks = 30]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The app's font, so the boxes have their real height.
    final poppins = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/font/poppins.ttf'));
    await poppins.load();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'role': 'Staffmember',
      'staff_id': 'STAFF-1',
    });
  });

  final screens = <String, Widget Function()>{
    'Admin Add': () =>
        admin_add.AddApplience(unit: unit_properties(unitId: 'U-1')),
    'Staff Add': () =>
        staff_add.AddApplience(unit: unit_properties(unitId: 'U-1')),
    'Admin Edit': () => admin_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: _fridge()),
    'Staff Edit': () => staff_edit.Edit_applience(
        unit: unit_properties(unitId: 'U-1'), appliance: _fridge()),
  };

  // The dropdowns, top to bottom, by their label.
  final labels = <String, Finder>{
    'Type': find.text('Type *'),
    'Category': find.byWidgetPredicate((w) =>
        w is Text && (w.data == 'Category' || w.data == 'Category *')),
    'Brand': find.text('Brand'),
    'Status': find.text('Status'),
  };

  screens.forEach((name, build) {
    testWidgets('$name: every dropdown box looks like the text boxes',
        (tester) async {
      tester.view.physicalSize = const Size(440, 6000); // phone width
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      final server = _Server();
      try {
        await http.runWithClient(() async {
          final permissions = StaffPermissionProvider();
          await permissions.fetchPermissions();
          await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => DateProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider<StaffPermissionProvider>.value(
                  value: permissions),
            ],
            child: MaterialApp(
              // The app's theme (main.dart).
              theme: ThemeData(fontFamily: 'Poppins', useMaterial3: false),
              home: build(),
            ),
          ));
          await _settle(tester);

          // The example: the Model text box.
          final model = find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.hintText == 'Enter model');
          expect(model, findsOneWidget);
          final textBox =
              find.ancestor(of: model, matching: find.byType(DecoratedBox)).first;
          final textLook =
              tester.widget<DecoratedBox>(textBox).decoration as BoxDecoration;
          expect(textLook.border,
              Border.all(color: Colors.grey.shade300, width: 1.2),
              reason: 'found the text box itself');
          final textRect = tester.getRect(textBox);
          final textStart = tester
              .getRect(find.descendant(
                  of: model, matching: find.byType(EditableText)))
              .left;
          final labelGap =
              textRect.top - tester.getRect(find.text('Model')).bottom;

          final dropdowns =
              find.byWidgetPredicate((w) => w is DropdownButton2);
          expect(dropdowns, findsNWidgets(labels.length));
          var i = 0;
          for (final entry in labels.entries) {
            final field = entry.key;
            final dropdown = dropdowns.at(i++);
            final box = find
                .descendant(of: dropdown, matching: find.byType(DecoratedBox))
                .first;
            final look =
                tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
            final rect = tester.getRect(box);

            expect(look.color, textLook.color, reason: '$field: background');
            expect(look.border, textLook.border, reason: '$field: grey border');
            expect(look.borderRadius, textLook.borderRadius,
                reason: '$field: round corners');
            expect(look.boxShadow ?? const <BoxShadow>[], isEmpty,
                reason: '$field: no shadow');
            expect(rect.left, closeTo(textRect.left, 0.01),
                reason: '$field: left edge');
            expect(rect.right, closeTo(textRect.right, 0.01),
                reason: '$field: right edge');
            expect(rect.height, closeTo(textRect.height, 0.01),
                reason: '$field: height');
            final start = tester
                .getRect(find.descendant(
                    of: dropdown, matching: find.byType(IndexedStack)))
                .left;
            expect(start, closeTo(textStart, 0.01),
                reason: '$field: text starts where the text boxes\' text does');
            final gap = rect.top - tester.getRect(entry.value).bottom;
            expect(gap, closeTo(labelGap, 0.01),
                reason: '$field: gap under the label');
          }
        }, () => server.client);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        FlutterError.onError = original;
      }
    });
  });
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
