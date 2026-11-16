import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/All_categories_model.dart';
import 'package:three_zero_two_property/VendorModule/screen/work_order/Edit_workorders.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Vendor/add_vendor.dart'
    as vendor_field;

/// Vendor → Work Orders → Edit (phone): one text size in every box, the
/// fields web disables (Property, Category, Entry Allowed, Assigned To) in
/// web's disabled dropdown grey and the Due Date in web's disabled date box,
/// while web's read-only Subject and Work To Be Performed keep normal text,
/// and the same space above and below every box. Before, the values were 14 or 16, dark or
/// grey, and the gaps ran 20–51 pt (an empty photo line under Subject, and
/// hidden padding around Property and Assigned To).
///
/// Also checked with a unit (Unit is disabled on web too: grey, with the same
/// gaps) and on the wide layout (the same text size and greys, and the flat
/// Due Date box; its spacing was not changed).

// Web staging's disabled dropdown text (MUI text.disabled) and disabled
// Due Date box (DatePicker: #f8f9fa).
const _grey = Color(0x61000000);
const _dueDateBox = Color(0xFFF8F9FA);

final _workOrder = {
  'workOrder_id': 'WO-1',
  'admin_id': 'ADMIN-1',
  'vendor_id': 'V-1',
  'tenant_id': 'T-1',
  'work_subject': 'Leaky tap',
  'work_category': 'Plumbing',
  'work_performed': 'Unit',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'entry_allowed': true,
  'is_billable': false,
  'staffmember_id': 'S-1',
  'rental_id': 'P-1',
  'unit_id': 'U-1',
  'property_data': {
    '_id': 'P-1',
    'property_name': 'Main St',
    'rental_adress': '123 Main St',
    'rental_id': 'P-1',
  },
  'unit_data': {'_id': 'U-1', 'unit_no': 'A1'},
  'staff_data': {
    '_id': 'S-1',
    'staffmember_id': 'S-1',
    'staffmember_name': 'Pat Staff',
    'role': 'staff',
  },
  'vendor_data': {'_id': 'V-1', 'vendor_name': 'Fixit Co', 'vendor_type': 'Plumbing'},
  'tenant_data': {'_id': 'T-1', 'tenant_name': 'Ruth Moss'},
  'vendor_notes': 'Bring a wrench',
  'workorder_updates': [],
  'partsandcharge_data': [],
  'workOrder_images': [],
};

/// The fake server; [units] lists the property's units (none by default).
MockClient _server({List<Map<String, String>> units = const []}) =>
    MockClient((request) async {
  final path = request.url.path;
  Object body = {'statusCode': 200, 'data': []};
  if (path.startsWith('/api/unit/rental_unit/')) {
    body = {'statusCode': 200, 'data': units};
  } else if (path == '/api/auth') {
    body = {
      'statusCode': 200,
      'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
    };
  } else if (path.startsWith('/api/work-order/workorder_details/')) {
    body = {'statusCode': 200, 'data': _workOrder};
  } else if (path.startsWith('/api/settings/allCategories/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'category_id': 'C-1', 'name': 'Plumbing', 'brands': []},
      ]
    };
  }
  return http.Response(jsonEncode(body), 200,
      headers: {'content-type': 'application/json'});
});

Future<void> _settle(WidgetTester tester, [int ticks = 50]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

TextStyle _shown(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text).first).text.style!;

TextStyle _typed(WidgetTester tester, String text) => tester
    .widget<EditableText>(find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == text))
    .style;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'vendor_id': 'V-1',
      'role': 'Vendor',
    });
  });

  Future<void> check(WidgetTester tester,
      {required double width, required bool withUnit}) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          // The app's theme (main.dart): Material 2, Poppins.
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Poppins', useMaterial3: false),
            home: Edit_Workorder(workorderId: 'WO-1'),
          ),
        ));
        await _settle(tester);

        // Disabled on web: 14 and web's disabled grey.
        for (final style in [
          _shown(tester, '123 Main St'), // Property
          if (withUnit) _shown(tester, 'A1'), // Unit
          _shown(tester, 'Plumbing'), // Category
          _shown(tester, 'Yes'), // Entry Allowed
          _shown(tester, 'Pat Staff'), // Assigned To
        ]) {
          expect(style.fontSize, 14);
          expect(style.color, _grey);
        }
        // Read-only on web (Subject, Work To Be Performed) and boxes the
        // vendor can change: the same size, not grey.
        for (final style in [
          _typed(tester, 'Leaky tap'), // Subject
          _typed(tester, 'Unit'), // Work To Be Performed
          _shown(tester, 'In Progress'), // Status
          _typed(tester, 'Bring a wrench'), // Vendor Notes
        ]) {
          expect(style.fontSize, 14);
          expect(style.color, isNot(_grey));
        }

        // The Due Date box: web's disabled background, flat (no shadow).
        bool dueBox(Widget w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == _dueDateBox;
        expect(find.byWidgetPredicate(dueBox), findsOneWidget);
        final dueDecoration = tester
            .widget<Container>(find.byWidgetPredicate(dueBox))
            .decoration as BoxDecoration;
        expect(dueDecoration.boxShadow ?? const [], isEmpty);

        // The wide layout's spacing was not changed; only phone gaps below.
        if (width > 500) return;

        // The same space above and below every box.
        Rect box(Finder f) => tester.getRect(f.first);
        final label = {
          for (final t in [
            'Subject *',
            'Property *',
            if (withUnit) 'Unit',
            'Category',
            'Entry Allowed',
            'Assigned To *',
            'Work To Be Performed',
          ])
            t: tester.getRect(find.text(t).first)
        };
        final boxes = [
          box(find.byWidgetPredicate((w) =>
              w is vendor_field.CustomTextField && w.hintText == 'Add subject')),
          box(find.ancestor(
              of: find.text('123 Main St').first,
              matching: find.byType(DropdownButtonFormField2<String>))),
          if (withUnit)
            box(find.ancestor(
                of: find.text('A1').first,
                matching: find.byType(DropdownButtonFormField2<String>))),
          box(find.byType(DropdownButton2<allcategories_model>)),
          box(find.ancestor(
              of: find.text('Yes').first,
              matching: find.byType(DropdownButton2<String>))),
          box(find.ancestor(
              of: find.text('Pat Staff').first,
              matching: find.byType(DropdownButtonFormField2<String>))),
        ];
        final labels = label.values.toList();
        for (var i = 0; i < boxes.length; i++) {
          expect(boxes[i].top - labels[i].bottom, closeTo(10, 0.5),
              reason: 'label → box, ${label.keys.elementAt(i)}');
          expect(labels[i + 1].top - boxes[i].bottom, closeTo(10, 0.5),
              reason: 'box → next label, after ${label.keys.elementAt(i)}');
        }
        // The dropdowns are the same height: no hidden padding.
        final u = withUnit ? 1 : 0;
        expect(boxes[1].height, boxes[2 + u].height);
        if (withUnit) expect(boxes[2].height, boxes[3].height);
        expect(boxes[4 + u].height, boxes[3 + u].height);
      },
          () => _server(
              units: withUnit
                  ? const [
                      {'unit_id': 'U-1', 'rental_unit': 'A1'}
                    ]
                  : const []));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('phone layout: one text size, locked fields grey, even gaps',
      (tester) async => check(tester, width: 430, withUnit: false));
  testWidgets('phone layout with a unit: Unit grey too, the same gaps',
      (tester) async => check(tester, width: 430, withUnit: true));
  testWidgets('wide layout: one text size, the same greys, flat Due Date',
      (tester) async => check(tester, width: 900, withUnit: true));
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
