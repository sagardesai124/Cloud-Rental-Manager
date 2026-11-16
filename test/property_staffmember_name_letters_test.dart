import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/services/letters_only.dart';

/// Add / Edit Property → Manager → "Add New Staffmember": the Staff Member
/// Name takes letters and spaces only, like web staging StaffMemberModal.jsx
/// (`/^[a-zA-Z\s]*$/` on every change), for Admin and Staff.

TextEditingValue _v(String t) =>
    TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));

String _edit(String from, String to) =>
    typedLettersAndSpacesOnly.formatEditUpdate(_v(from), _v(to)).text;

/// Web's own rule: keep the change only when the whole value matches.
String _web(String from, String to) =>
    RegExp(r'^[a-zA-Z\s]*$').hasMatch(to) ? to : from;

const _forms = [
  'lib/screens/Rental/Properties/add_new_property.dart',
  'lib/screens/Rental/Properties/EditProperties.dart',
  'lib/StaffModule/screen/Rental/Properties/add_new_property.dart',
  'lib/StaffModule/screen/Rental/Properties/EditProperties.dart',
];

void main() {
  test('same result as web for typing and pasting a staff name', () {
    const cases = [
      ['', 'J'], ['John', 'John3'], ['John', 'John#'], ['', 'John3#'],
      ['John', 'John Smith'], ['John', 'Jo'], ['', 'Mary Ann'],
      ['Mary', 'Mary@'], ['', '123'],
    ];
    for (final c in cases) {
      expect(_edit(c[0], c[1]), _web(c[0], c[1]), reason: '${c[0]} -> ${c[1]}');
    }
  });

  for (final path in _forms) {
    test('$path: Staff Member Name uses the letters-only rule', () {
      final src = File(path).readAsStringSync();
      expect('controller: name,'.allMatches(src).length, 1,
          reason: 'one staff name box per form');
      final at = src.indexOf('controller: name,');
      final field = src.substring(at, src.indexOf('decoration:', at));
      expect(field, contains('inputFormatters: [typedLettersAndSpacesOnly]'));
      expect(src.substring(at, src.indexOf('),', src.indexOf('hintText:', at))),
          contains('staff member name'),
          reason: 'it is the Add New Staffmember name box');
    });
  }

  testWidgets('typing John3# one key at a time keeps "John", like web',
      (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
            controller: c, inputFormatters: [typedLettersAndSpacesOnly]),
      ),
    ));
    var typed = '';
    for (final ch in 'John3#'.split('')) {
      typed = c.text + ch;
      await tester.enterText(find.byType(TextField), typed);
    }
    expect(c.text, 'John');
    await tester.enterText(find.byType(TextField), 'John Smith');
    expect(c.text, 'John Smith', reason: 'spaces are allowed');
  });
}
