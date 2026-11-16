import 'dart:convert';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/staffpermission_provider.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/Add_workorder.dart'
    as staff_add;
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/Edit_workorders.dart'
    as staff_edit;
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/add_tenants.dart'
    as staff_field;
import 'package:three_zero_two_property/VendorModule/screen/work_order/Edit_workorders.dart'
    as vendor_edit;
import 'package:three_zero_two_property/constant/workorder_parts_limits.dart';
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/notification_provider.dart';
import 'package:three_zero_two_property/screens/Maintenance/Vendor/add_vendor.dart'
    as vendor_field;
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Add_workorder.dart'
    as admin_add;
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Edit_workorders.dart'
    as admin_edit;
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart'
    as admin_field;

/// Parts and Labor → Quantity and Price, like web staging (one rule on the
/// vendor Edit Work Order and the Admin/Staff Add/Edit Work Order):
/// Quantity takes digits only, 5 at most, and "Quantity cannot exceed 9,999"
/// stops the save; Price keeps only digits and ".", gets a keypad with a "."
/// key, must be a number with at most 2 decimals, and "Price cannot exceed
/// $999,999.99" stops the save. Before, the phone took any value, so 123456
/// and 99999999 were sent. Every Edit layout's save button reads "Update Work
/// Order", like web (the vendor phone and the Admin/Staff wide ones read
/// "Edit Work Order").
///
/// An iPhone set to a comma-decimal region has only "," on its decimal
/// keypad. Typing "12,50" used to give 1250 (the "," was dropped); one typed
/// "," is now the decimal point, so it gives 12.50. A pasted "1,234.50" still
/// loses its comma, like web (1234.50).
///
/// Also like web: a Quantity of 0 shows "Quantity must be at least 1" and a
/// Price of 0 shows "Price is required", and both stop the save (the server
/// refuses them too). A message longer than its box wraps and shows in full
/// (it was cut to one line on narrow boxes). On the vendor Edit, changing a
/// loaded row's Quantity or Price updates the row's amount before saving
/// (it kept the loaded amount).

const _qtyMessage = 'Quantity cannot exceed 9,999';
const _priceMessage = 'Price cannot exceed \$999,999.99';

final _part = {
  'parts_id': 'PT-1',
  'parts_quantity': 2,
  'account': 'Repairs',
  'description': 'Washer',
  'parts_price': 5.5,
  'amount': 11.0,
};

/// Admin/Staff sample (no category, vendor or staff picked: the fake server
/// lists none of them, and a dropdown value missing from its list would stop
/// the form; the Edit forms need the property listed).
final _adminWorkOrder = {
  'workOrder_id': 'WO-1',
  'ticket_number': '1001',
  'admin_id': 'ADMIN-1',
  'work_subject': 'Leaky tap',
  'status': 'In Progress',
  'priority': 'High',
  'date': '2026-10-30',
  'entry_allowed': true,
  'is_billable': false,
  'rental_id': 'P-1',
  'vendor_id': '',
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
  'partsandcharge_data': [_part],
  'workOrder_images': [],
};

final _vendorWorkOrder = {
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
  'vendor_notes': 'Bring a wrench',
  'workorder_updates': [],
  'partsandcharge_data': [_part],
  'workOrder_images': [],
};

class _Server {
  _Server({required this.vendor});
  final bool vendor;
  final List<Map<String, dynamic>> saves = [];

  late final MockClient client = MockClient((request) async {
    final path = request.url.path;
    Object body = {'statusCode': 200, 'data': []};
    if (request.method == 'PUT' || request.method == 'POST') {
      if (path.startsWith('/api/work-order/work-order')) {
        saves.add(jsonDecode(request.body) as Map<String, dynamic>);
        body = {'statusCode': 200, 'message': 'Work Order updated'};
      }
    } else if (path == '/api/auth') {
      body = {
        'statusCode': 200,
        'themes': {'format': 'MM/DD/YYYY', 'timeFormat': '12'}
      };
    } else if (path.startsWith('/api/work-order/workorder_details/')) {
      body = {'statusCode': 200, 'data': vendor ? _vendorWorkOrder : _adminWorkOrder};
    } else if (path.startsWith('/api/rentals/rentals/')) {
      body = {
        'statusCode': 200,
        'data': [
          {'rental_id': 'P-1', 'rental_adress': '123 Main St'}
        ]
      };
    } else if (vendor && path.startsWith('/api/settings/allCategories/')) {
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
}

Future<void> _settle(WidgetTester tester, [int ticks = 40]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The parts box with this hint, from whichever CustomTextField the form uses.
Finder _box(String hint) => find.byWidgetPredicate((w) =>
    (w is admin_field.CustomTextField && w.hintText == hint) ||
    (w is staff_field.CustomTextField && w.hintText == hint) ||
    (w is vendor_field.CustomTextField && w.hintText == hint));

Finder _input(Finder box) =>
    find.descendant(of: box, matching: find.byType(EditableText));

String _text(WidgetTester tester, Finder box) =>
    tester.widget<EditableText>(_input(box)).controller.text;

/// Types [keys] one at a time into an empty box, the way a keypad does: each
/// key is sent as what the box shows now plus that key.
Future<void> _type(WidgetTester tester, Finder box, String keys) async {
  await tester.enterText(_input(box), '');
  for (final key in keys.split('')) {
    await tester.enterText(_input(box), _text(tester, box) + key);
  }
  await tester.pump();
}

/// [message] shows in full under [box]: not cut ("…") and inside the box's
/// width and height, wrapping when the box is narrow.
void _expectWholeMessage(WidgetTester tester, Finder box, String message) {
  final text = find.descendant(of: box, matching: find.text(message));
  expect(text, findsOneWidget, reason: message);
  expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse,
      reason: '"$message" is not cut');
  final boxRect = tester.getRect(box);
  final textRect = tester.getRect(text);
  expect(textRect.right, lessThanOrEqualTo(boxRect.right + 0.01),
      reason: '"$message" stays inside the box');
  expect(textRect.bottom, lessThanOrEqualTo(boxRect.bottom + 0.01),
      reason: '"$message" stays inside the box');
}

/// A button (ElevatedButton and friends) showing this label.
Finder _button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

/// The box's own check (CustomTextField wraps its input in a FormField).
FormFieldState<String> _check(WidgetTester tester, Finder box) =>
    tester.state<FormFieldState<String>>(
        find.descendant(of: box, matching: find.byType(FormField<String>)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
    ConnectivityPlatform.instance = _OnlineConnectivity();
  });

  Future<void> run(WidgetTester tester, Widget form, String role,
      {required double width,
      required bool addRow,
      bool edit = false,
      Future<void> Function(_Server server)? save}) async {
    tester.view.physicalSize = Size(width, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'S-1',
      'vendor_id': 'V-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      // The test font draws every glyph as a full em square, so dense rows
      // overflow at phone width; that layout noise is ignored.
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    final server = _Server(vendor: role == 'Vendor');
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
          ],
          child: MaterialApp(home: Scaffold(body: form)),
        ));
        await _settle(tester);

        if (addRow) {
          final add = find.textContaining('Add Row');
          await tester.ensureVisible(add.first);
          await tester.pump();
          await tester.tap(add.first);
          await _settle(tester, 10);
        }

        final qty = _box('Quantity');
        final price = _box('Price');
        expect(qty, findsOneWidget, reason: 'one parts row on screen');
        expect(price, findsOneWidget);

        if (edit) {
          expect(_button('Update Work Order'), findsOneWidget,
              reason: 'save button, like web');
          expect(_button('Edit Work Order'), findsNothing);
        }

        // Keypads: Quantity keeps the number pad; Price gets a "." key. Both
        // keep the Done bar (KeyboardActions) and its layout.
        expect(tester.widget<EditableText>(_input(qty)).keyboardType,
            TextInputType.number);
        expect(tester.widget<EditableText>(_input(price)).keyboardType,
            const TextInputType.numberWithOptions(decimal: true));
        expect(find.descendant(of: qty, matching: find.byType(KeyboardActions)),
            findsOneWidget);
        expect(
            find.descendant(of: price, matching: find.byType(KeyboardActions)),
            findsOneWidget);

        // Typing, like web: Quantity keeps digits, 5 at most; Price keeps
        // digits and ".".
        await tester.enterText(_input(qty), '12a3456');
        await tester.enterText(_input(price), '9a9,9.5x');
        await tester.pump();
        expect(_text(tester, qty), '12345');
        expect(_text(tester, price), '999.5');

        // A comma-region iPhone keypad: a typed "," is the decimal point
        // while there is no "." yet; a second one is dropped. A pasted
        // "1,234.50" loses its comma, like web.
        await _type(tester, price, '12,50');
        expect(_text(tester, price), '12.50');
        await _type(tester, price, '12,5,0');
        expect(_text(tester, price), '12.50');
        await _type(tester, price, '1.5,');
        expect(_text(tester, price), '1.5');
        await tester.enterText(_input(price), '1,234.50');
        await tester.pump();
        expect(_text(tester, price), '1234.50');

        // Above the limits: the web messages, and the form refuses to save.
        await tester.enterText(_input(price), '99999999');
        await tester.pump();
        final formState = tester.state<FormState>(
            find.ancestor(of: qty, matching: find.byType(Form)).first);
        expect(formState.validate(), isFalse);
        await tester.pump();
        expect(find.text(_qtyMessage), findsOneWidget);
        expect(find.text(_priceMessage), findsOneWidget);
        expect(_check(tester, qty).hasError, isTrue);
        expect(_check(tester, price).hasError, isTrue);

        // At the limits: no message, and both boxes pass.
        await tester.enterText(_input(qty), '9999');
        await tester.enterText(_input(price), '999999.99');
        await tester.pump();
        formState.validate();
        await tester.pump();
        expect(find.text(_qtyMessage), findsNothing);
        expect(find.text(_priceMessage), findsNothing);
        expect(_check(tester, qty).hasError, isFalse);
        expect(_check(tester, price).hasError, isFalse);

        // Zero, like web: Quantity at least 1 and a Price above 0.
        for (final zero in const ['0', '0.00', '0.']) {
          await tester.enterText(_input(qty), '0');
          await tester.enterText(_input(price), zero);
          await tester.pump();
          expect(formState.validate(), isFalse, reason: zero);
          await tester.pump();
          expect(find.text('Quantity must be at least 1'), findsOneWidget);
          expect(find.text('Price is required'), findsOneWidget, reason: zero);
          expect(_check(tester, qty).hasError, isTrue);
          expect(_check(tester, price).hasError, isTrue, reason: zero);
        }
        await tester.enterText(_input(qty), '1');
        await tester.enterText(_input(price), '0.01');
        await tester.pump();
        formState.validate();
        await tester.pump();
        expect(find.text('Quantity must be at least 1'), findsNothing);
        expect(find.text('Price is required'), findsNothing);
        expect(_check(tester, qty).hasError, isFalse);
        expect(_check(tester, price).hasError, isFalse);

        // Price must also be a number with at most 2 decimals; web checks
        // that before the cap.
        for (final c in const [
          ['12.345', 'Price can have at most 2 decimal places'],
          ['1.2.3', 'Price must be a number'],
          ['.', 'Price must be a number'],
          ['1234567.891', 'Price can have at most 2 decimal places'],
        ]) {
          await tester.enterText(_input(price), c[0]);
          await tester.pump();
          expect(_text(tester, price), c[0]);
          expect(formState.validate(), isFalse, reason: c[0]);
          await tester.pump();
          expect(find.text(c[1]), findsOneWidget, reason: c[0]);
          expect(_check(tester, price).hasError, isTrue, reason: c[0]);
          _expectWholeMessage(tester, price, c[1]);
        }

        // The longest messages at once, Quantity and Price side by side.
        await tester.enterText(_input(qty), '12345');
        await tester.enterText(_input(price), '99999999');
        await tester.pump();
        formState.validate();
        await tester.pump();
        _expectWholeMessage(tester, qty, _qtyMessage);
        _expectWholeMessage(tester, price, _priceMessage);
        if (width < 500 && role != 'Vendor') {
          // On a phone these fit on one line, and the box keeps its old
          // height with a message (74), so the phone looks as before.
          expect(tester.getSize(qty).height, 74);
          expect(tester.getSize(price).height, 74);
        }
        await tester.enterText(_input(price), '12.5');
        await tester.pump();
        formState.validate();
        await tester.pump();
        expect(find.text('Price must be a number'), findsNothing);
        expect(find.text('Price can have at most 2 decimal places'),
            findsNothing);
        expect(_check(tester, price).hasError, isFalse);

        if (save != null) await save(server);
      }, () => server.client);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  /// Vendor, end to end: saving with 12345 / 99999999 sends nothing and
  /// shows both messages; with 9,999 / $999,999.99 it saves those numbers.
  Future<void> vendorSave(WidgetTester tester, _Server server) async {
    final qty = _box('Quantity');
    final price = _box('Price');
    final update = _button('Update Work Order');

    await tester.enterText(_input(qty), '123456');
    await tester.enterText(_input(price), '99999999');
    await _settle(tester, 10);
    await tester.ensureVisible(update);
    await tester.pump();
    await tester.tap(update);
    await _settle(tester);
    expect(server.saves, isEmpty, reason: 'refused, like web');
    expect(find.text(_qtyMessage), findsOneWidget);
    expect(find.text(_priceMessage), findsOneWidget);

    // 0 / 0 is refused too, with web's messages.
    await tester.enterText(_input(qty), '0');
    await tester.enterText(_input(price), '0');
    await _settle(tester, 10);
    await tester.ensureVisible(update);
    await tester.pump();
    await tester.tap(update);
    await _settle(tester);
    expect(server.saves, isEmpty, reason: 'refused, like web');
    expect(find.text('Quantity must be at least 1'), findsOneWidget);
    expect(find.text('Price is required'), findsOneWidget);

    // Typed on a comma-region keypad: "999999,99" saves 999999.99.
    await tester.enterText(_input(qty), '9999');
    await _type(tester, price, '999999,99');
    await _settle(tester, 10);
    expect(_text(tester, _box('Total')), (9999 * 999999.99).toStringAsFixed(2),
        reason: "the row's Total follows Quantity x Price");
    await tester.ensureVisible(update);
    await tester.pump();
    await tester.tap(update);
    await _settle(tester);
    expect(server.saves, hasLength(1));
    final parts = server.saves.single['parts'] as List;
    expect(parts.single['parts_quantity'], 9999);
    expect(parts.single['parts_price'], 999999.99);
    // The loaded row's amount follows the new Quantity and Price.
    expect(parts.single['amount'],
        double.parse((9999 * 999999.99).toStringAsFixed(2)));
  }

  test('Price formatter: one typed "," is the decimal point', () {
    TextEditingValue apply(TextEditingValue old, TextEditingValue next) {
      var value = next;
      for (final f in partsPriceInputFormatters) {
        value = f.formatEditUpdate(old, value);
      }
      return value;
    }

    TextEditingValue v(String text, int start, [int? end]) => TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: start, extentOffset: end ?? start));

    // Typed in the middle: "1250" with the cursor after "12".
    expect(apply(v('1250', 2), v('12,50', 3)).text, '12.50');
    // Typed over a selection: "99" selected in "1990" → "1,0" → "1.0".
    expect(apply(v('1990', 1, 3), v('1,0', 2)).text, '1.0');
    // No cursor yet (text set by the app): counts as typed at the end.
    expect(apply(const TextEditingValue(text: '12'), v('12,', 3)).text, '12.');
    // A "." is already there: the "," is dropped.
    expect(apply(v('1.5', 3), v('1.5,', 4)).text, '1.5');
    // Pasted text keeps web's rule: commas dropped.
    expect(apply(v('', 0), v('1,234.50', 8)).text, '1234.50');
    expect(apply(v('', 0), v('12,50', 5)).text, '1250');
    // A "," typed as a thousands mark (a keyboard with both keys) becomes
    // the point too, and the decimals rule then stops the save, so the
    // number is never changed without a message.
    final typed = apply(v('1', 1), v('1,', 2)).text;
    expect(typed, '1.');
    expect(partsPriceCheck('${typed}250'),
        'Price can have at most 2 decimal places');
  });

  test('Quantity rule: below 1 is refused, older "0.5" too', () {
    expect(partsQtyCheck('0'), 'Quantity must be at least 1');
    expect(partsQtyCheck('0.5'), 'Quantity must be at least 1');
    expect(partsQtyCheck('1'), isNull);
    expect(partsQtyCheck(''), isNull, reason: 'empty keeps its own message');
  });

  // The loaded row's Total follows Quantity x Price, but only when they
  // change: tapping into a box (the cursor moves) keeps the saved Total and
  // Update stays off; a change turns it on, and changing it back turns it
  // off again. Same on every Edit form (vendor, Admin, Staff; both layouts).
  Future<void> tapKeepsUpdateOff(WidgetTester tester, Widget form, String role,
      {required double width}) async {
    tester.view.physicalSize = Size(width, 9000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'token': 'tkn',
      'adminId': 'ADMIN-1',
      'staff_id': 'S-1',
      'vendor_id': 'V-1',
      'role': role,
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    final server = _Server(vendor: role == 'Vendor');
    try {
      await http.runWithClient(() async {
        final dates = DateProvider();
        await dates.loadDateFormat();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<DateProvider>.value(value: dates),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (_) => StaffPermissionProvider()),
          ],
          child: MaterialApp(home: Scaffold(body: form)),
        ));
        await _settle(tester);
        final qty = _box('Quantity');
        final price = _box('Price');
        final update = _button('Update Work Order');
        bool updateOn() =>
            tester.widget<ButtonStyleButton>(update).onPressed != null;
        expect(updateOn(), isFalse, reason: 'nothing changed yet');

        for (final box in [qty, price]) {
          await tester.ensureVisible(box);
          await tester.pump();
          await tester.tap(_input(box));
          await _settle(tester, 5);
        }
        expect(_text(tester, _box('Total')), '11.0', reason: 'as saved');
        expect(updateOn(), isFalse, reason: 'tapping is not a change');

        await tester.enterText(_input(qty), '3');
        await _settle(tester, 5);
        expect(_text(tester, _box('Total')), '16.50');
        expect(updateOn(), isTrue);
        await tester.enterText(_input(qty), '2');
        await _settle(tester, 5);
        expect(updateOn(), isFalse, reason: 'back to the saved row');
        expect(server.saves, isEmpty);
      }, () => server.client);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    } finally {
      FlutterError.onError = original;
    }
  }

  testWidgets('Vendor Edit: tapping a saved row keeps Update off',
      (t) async => tapKeepsUpdateOff(
          t, vendor_edit.Edit_Workorder(workorderId: 'WO-1'), 'Vendor',
          width: 430));
  for (final c in [
    ('Admin Edit, phone', 'Admin', 430.0, false),
    ('Admin Edit, wide', 'Admin', 800.0, true),
    ('Staff Edit, phone', 'Staffmember', 430.0, false),
    ('Staff Edit, wide', 'Staffmember', 800.0, true),
  ]) {
    testWidgets('${c.$1}: tapping a saved row keeps Update off', (t) async {
      final staff = c.$2 == 'Staffmember';
      final Widget form = c.$4
          ? (staff
              ? staff_edit.EditWorkOrderForTablet(workorderId: 'WO-1')
              : admin_edit.EditWorkOrderForTablet(workorderId: 'WO-1'))
          : (staff
              ? staff_edit.EditWorkOrderForMobile(workorderId: 'WO-1')
              : admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'));
      await tapKeepsUpdateOff(t, form, c.$2, width: c.$3);
    });
  }

  testWidgets('Vendor Edit, phone', (t) async => run(
      t, vendor_edit.Edit_Workorder(workorderId: 'WO-1'), 'Vendor',
      width: 430, addRow: false, edit: true, save: (s) => vendorSave(t, s)));
  testWidgets('Vendor Edit, wide', (t) async => run(
      t, vendor_edit.Edit_Workorder(workorderId: 'WO-1'), 'Vendor',
      width: 900, addRow: false, edit: true, save: (s) => vendorSave(t, s)));
  testWidgets('Admin Add, phone', (t) async => run(
      t, admin_add.AddWorkOrderForMobile(), 'Admin',
      width: 430, addRow: true));
  testWidgets('Admin Add, wide', (t) async => run(
      t, admin_add.AddWorkOrderForTablet(), 'Admin',
      width: 800, addRow: true));
  testWidgets('Admin Edit, phone', (t) async => run(
      t, admin_edit.EditWorkOrderForMobile(workorderId: 'WO-1'), 'Admin',
      width: 430, addRow: false, edit: true));
  testWidgets('Admin Edit, wide', (t) async => run(
      t, admin_edit.EditWorkOrderForTablet(workorderId: 'WO-1'), 'Admin',
      width: 800, addRow: false, edit: true));
  testWidgets('Staff Add, phone', (t) async => run(
      t, staff_add.AddWorkOrderForMobile(), 'Staffmember',
      width: 430, addRow: true));
  testWidgets('Staff Add, wide', (t) async => run(
      t, staff_add.AddWorkOrderForTablet(), 'Staffmember',
      width: 800, addRow: true));
  testWidgets('Staff Edit, phone', (t) async => run(
      t, staff_edit.EditWorkOrderForMobile(workorderId: 'WO-1'), 'Staffmember',
      width: 430, addRow: false, edit: true));
  testWidgets('Staff Edit, wide', (t) async => run(
      t, staff_edit.EditWorkOrderForTablet(workorderId: 'WO-1'), 'Staffmember',
      width: 800, addRow: false, edit: true));
}

class _OnlineConnectivity extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.wifi;
  @override
  Stream<ConnectivityResult> get onConnectivityChanged => const Stream.empty();
}
