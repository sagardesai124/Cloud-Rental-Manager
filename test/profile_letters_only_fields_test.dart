import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/screens/Profile/Profile_screen.dart';

/// Admin → My Profile: First Name, Last Name, City and Country take only
/// letters and spaces, like web (Profile.jsx `/^[a-zA-Z\s]*$/` on change).
/// A change with anything else is ignored, so "Pune7#" can't be typed or
/// pasted. Before, these fields accepted any character.

TextEditingValue _edit(String oldText, String newText) =>
    lettersAndSpacesOnly.formatEditUpdate(
      TextEditingValue(
          text: oldText,
          selection: TextSelection.collapsed(offset: oldText.length)),
      TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length)),
    );

void main() {
  test('letters and spaces go through', () {
    expect(_edit('', 'P').text, 'P');
    expect(_edit('New', 'New York').text, 'New York');
    expect(_edit('', 'United Kingdom').text, 'United Kingdom');
  });

  test('digits and symbols are ignored, like web', () {
    expect(_edit('Pune', 'Pune7').text, 'Pune');
    expect(_edit('Pune', 'Pune#').text, 'Pune');
    expect(_edit('', 'Pune7#').text, '', reason: 'a paste with 7# is ignored');
    expect(_edit('Ann', "Ann-Marie").text, 'Ann');
  });

  testWidgets('typing into a field with the rule keeps only valid input',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
            controller: controller, inputFormatters: [lettersAndSpacesOnly]),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Pune');
    expect(controller.text, 'Pune');
    await tester.enterText(find.byType(TextField), 'Pune7#');
    expect(controller.text, 'Pune');
  });

  test('only First Name, Last Name, City and Country use the rule', () {
    final src =
        File('lib/screens/Profile/Profile_screen.dart').readAsStringSync();
    final calls = src.split('buildTextField(').skip(1).map((chunk) {
      final end = chunk.indexOf('SizedBox(height: 16.0)');
      return end < 0 ? chunk : chunk.substring(0, end);
    });
    final withRule = <String>{};
    final withoutRule = <String>{};
    for (final call in calls) {
      final label = RegExp(r"^\s*'([^']+)'").firstMatch(call)?.group(1);
      if (label == null) continue; // the helper itself
      (call.contains('lettersAndSpacesOnly') ? withRule : withoutRule)
          .add(label);
    }
    expect(withRule, {'First Name', 'Last Name', 'City', 'Country'});
    expect(
        withoutRule,
        containsAll(
            ['Email Address', 'Phone Number', 'Company Name', 'Postal Code']));
  });
}
