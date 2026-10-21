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
import 'package:three_zero_two_property/Model/All_categories_model.dart';
import 'package:three_zero_two_property/VendorModule/screen/work_order/Edit_workorders.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';

/// Vendor → Work Orders → Edit: the Category is read-only, like web staging
/// (VendorAddWork.jsx renders it `disabled`), on both the phone and the wide
/// layout; the Due Date is read-only on the wide layout too (it already was
/// on the phone one). Before, a vendor could pick another category — even
/// "Other" — and save it, and change the due date on the wide layout.

final _workOrder = {
  'workOrder_id': 'WO-1',
  'admin_id': 'ADMIN-1',
  'vendor_id': 'V-1',
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
  'tenant_data': {
    '_id': 'T-1',
    'tenant_name': 'Ruth Moss',
    'email': 'ruth@example.com',
    'phone_number': '5551234567',
  },
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
  } else if (path.startsWith('/api/settings/allCategories/')) {
    body = {
      'statusCode': 200,
      'data': [
        {'category_id': 'C-1', 'name': 'Plumbing', 'brands': []},
        {'category_id': 'C-2', 'name': 'Other', 'brands': []},
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

Finder get _category => find.byType(DropdownButton2<allcategories_model>);

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

  Future<void> open(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dates = DateProvider();
    await dates.loadDateFormat();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DateProvider>.value(value: dates),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(home: Edit_Workorder(workorderId: 'WO-1')),
    ));
    await _settle(tester);
  }

  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    try {
      await http.runWithClient(body, () => _server);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  Future<void> expectCategoryLocked(WidgetTester tester) async {
    expect(_category, findsOneWidget);
    final dropdown = tester.widget<DropdownButton2<allcategories_model>>(_category);
    expect(dropdown.onChanged, isNull, reason: 'Category is read-only, like web');
    expect(find.text('Plumbing'), findsWidgets, reason: 'current category shown');

    // Tapping it opens nothing, so "Other" is never offered.
    await tester.ensureVisible(_category);
    await tester.pump();
    await tester.tap(_category, warnIfMissed: false);
    await _settle(tester, 10);
    expect(find.text('Other'), findsNothing);
  }

  testWidgets('phone layout: Category is read-only', (tester) async {
    await run(tester, () async {
      await open(tester, 430);
      await expectCategoryLocked(tester);
    });
  });

  testWidgets('wide layout: Category and Due Date are read-only',
      (tester) async {
    await run(tester, () async {
      await open(tester, 900);
      await expectCategoryLocked(tester);

      // Due date: tapping it opens no picker.
      final date = find.text('dd-mm-yyyy').evaluate().isNotEmpty
          ? find.text('dd-mm-yyyy')
          : find.textContaining('2026');
      expect(date, findsWidgets, reason: 'due date shown');
      await tester.ensureVisible(date.first);
      await tester.pump();
      await tester.tap(date.first, warnIfMissed: false);
      await _settle(tester, 10);
      expect(find.byType(DatePickerDialog), findsNothing,
          reason: 'Due Date is read-only, like web');
      expect(find.byType(Dialog), findsNothing);
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
