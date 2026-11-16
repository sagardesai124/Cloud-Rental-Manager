import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/services/letters_only.dart';

/// Add / Edit Property City and Country, like web staging (Rentals.jsx —
/// the page both Admin and Staff use): what you type or paste must be
/// letters and spaces, otherwise it is ignored. What is already in the box
/// is never changed.

TextEditingValue _v(String t, [int? cursor]) => TextEditingValue(
    text: t, selection: TextSelection.collapsed(offset: cursor ?? t.length));

String _edit(String from, String to) =>
    typedLettersAndSpacesOnly.formatEditUpdate(_v(from), _v(to)).text;

/// Web's own rule (Rentals.jsx handleChange): keep the change only when the
/// whole new value is letters and spaces.
String _web(String from, String to) =>
    RegExp(r'^[a-zA-Z\s]*$').hasMatch(to) ? to : from;

const _forms = [
  'lib/screens/Rental/Properties/add_new_property.dart',
  'lib/screens/Rental/Properties/EditProperties.dart',
  'lib/StaffModule/screen/Rental/Properties/add_new_property.dart',
  'lib/StaffModule/screen/Rental/Properties/EditProperties.dart',
];

void main() {
  test('typing: letters and spaces go in, numbers and symbols do not', () {
    expect(_edit('Austi', 'Austin'), 'Austin');
    expect(_edit('New', 'New '), 'New ');
    expect(_edit('Austin', 'Austin1'), 'Austin');
    expect(_edit('Austin', 'Austin#'), 'Austin');
    expect(_edit('', '9'), '');
    expect(_edit('USA', 'USA!'), 'USA');
  });

  test('pasting text with a number or symbol is ignored, like web', () {
    expect(_edit('', 'Austin123'), '');
    expect(_edit('Aus', 'AusUSA#1'), 'Aus');
    expect(_edit('', 'Salt Lake City'), 'Salt Lake City');
  });

  test('same result as web for every ordinary edit', () {
    const cases = [
      ['', 'A'], ['A', 'Au'], ['Austin', 'Austin1'], ['Austin', 'Austi'],
      ['Austin', ''], ['', 'Austin123'], ['New York', 'New Yorkk'],
      ['Newark', 'Newark99!'], ['United States', 'United States9'],
      ['Dallas', 'Dal'], ['Boston', 'Bo ston'], ['Reno', 'Re#no'],
    ];
    for (final c in cases) {
      expect(_edit(c[0], c[1]), _web(c[0], c[1]), reason: '${c[0]} -> ${c[1]}');
    }
  });

  test('a saved value is never changed by typing next to it', () {
    expect(_edit('St. Louis', 'St. Louisx'), 'St. Louisx',
        reason: 'the dot from web stays');
    expect(_edit('Winston-Salem', 'Winston-Salem '), 'Winston-Salem ');
    expect(_edit('St. Louis', 'St. Louis1'), 'St. Louis',
        reason: 'a digit is still refused');
  });

  test('a saved value like "N/A" can be deleted', () {
    expect(_edit('N/A', 'N/'), 'N/');
    expect(_edit('N/', 'N'), 'N');
    expect(_edit('N/A', ''), '');
    expect(_edit('N/A', 'U'), 'U', reason: 'select all and type');
    expect(_edit('N/A', '7'), 'N/A', reason: 'select all and type a digit');
  });

  test('typing in the middle keeps the cursor edit', () {
    final r = typedLettersAndSpacesOnly.formatEditUpdate(
        _v('Nwark', 1), _v('Newark', 2));
    expect(r.text, 'Newark');
    expect(r.selection.baseOffset, 2);
  });

  for (final path in _forms) {
    test('$path: City and Country use the rule', () {
      final src = File(path).readAsStringSync();
      for (final ctl in ['city', 'country']) {
        final at = src.indexOf('controller: $ctl,');
        expect(at, isNonNegative, reason: ctl);
        expect('controller: $ctl,'.allMatches(src).length, 1,
            reason: 'one $ctl box per form');
        final field = src.substring(at, src.indexOf('decoration:', at));
        expect(field, contains('inputFormatters: [typedLettersAndSpacesOnly]'),
            reason: ctl);
      }
      expect(src, contains("import 'package:three_zero_two_property/services/letters_only.dart';"));
    });
  }

  testWidgets('a City box with the rule: digits typed or pasted stay out',
      (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
            controller: c, inputFormatters: [typedLettersAndSpacesOnly]),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Austin');
    expect(c.text, 'Austin');
    await tester.enterText(find.byType(TextField), 'Austin123');
    expect(c.text, 'Austin', reason: 'paste with digits ignored, like web');
    await tester.enterText(find.byType(TextField), 'Salt Lake City');
    expect(c.text, 'Salt Lake City');
  });
}
