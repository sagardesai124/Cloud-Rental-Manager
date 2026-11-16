import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/widgets/template_name_date_helper.dart';

/// Templates › Add/Edit › Name, like web staging (AddTemplate.jsx): an info
/// tip "${date} - Current Date (<date format>)" next to Name, and typing `$`,
/// `${` or `${d…` in the Name box suggests "${date} - Current Date", which
/// completes `${date}` when tapped.

const _forms = [
  'lib/screens/Communications/Templates/Add_mail.dart',
  'lib/StaffModule/screen/Communications/Templates/Add_mail.dart',
];

void main() {
  group("when the suggestion shows (web's rule)", () {
    test('shows after typing \$, \${ or \${d…', () {
      expect(showTemplateDateSuggestion(r'$', ''), isTrue);
      expect(showTemplateDateSuggestion(r'Late Notice $', 'Late Notice '), isTrue);
      expect(showTemplateDateSuggestion(r'Late ${', r'Late $'), isTrue);
      expect(showTemplateDateSuggestion(r'Late ${d', r'Late ${'), isTrue);
      expect(showTemplateDateSuggestion(r'Late ${Da', r'Late ${D'), isTrue);
      expect(showTemplateDateSuggestion(r'Late ${date', r'Late ${dat'), isTrue);
    });

    test('does not show otherwise', () {
      expect(showTemplateDateSuggestion('Late', 'Lat'), isFalse);
      expect(showTemplateDateSuggestion(r'Late ${x', r'Late ${'), isFalse);
      expect(showTemplateDateSuggestion(r'Late ${date}', r'Late ${date'), isFalse,
          reason: 'already complete');
      expect(showTemplateDateSuggestion(r'Rent ${date} $', r'Rent ${date} '),
          isFalse,
          reason: 'web never offers it again once the name has \${date}');
      expect(showTemplateDateSuggestion(r'Late $', r'Late ${'), isFalse,
          reason: 'deleting never shows it');
    });
  });

  test("picking it completes \${date} exactly like web", () {
    expect(completeTemplateDate(r'Late Notice $'), r'Late Notice ${date}');
    expect(completeTemplateDate(r'Late ${'), r'Late ${date}');
    expect(completeTemplateDate(r'Late ${d'), r'Late ${date}');
    expect(completeTemplateDate(r'Late ${DaT'), r'Late ${date}');
    expect(completeTemplateDate(r'$5 off ${da'), r'$5 off ${date}');
    expect(completeTemplateDate('Late'), r'Late${date}');
  });

  test("the info tip uses web's words and the company date format", () {
    expect(templateNameDateTip('MM/dd/yyyy'),
        'You can use the following dynamic variable:\n• \${date} - Current Date (MM/DD/YYYY)');
    expect(templateNameDateTip('dd/MM/yyyy'), endsWith('(DD/MM/YYYY)'));
    expect(templateNameDateTip('yyyy-MM-dd'), endsWith('(YYYY-MM-DD)'));
  });

  group('suggestion under the Name box', () {
    late TextEditingController name;
    late FocusNode focus;
    var tappedOutside = 0;

    Future<void> pumpBox(WidgetTester tester) async {
      name = TextEditingController();
      focus = FocusNode();
      tappedOutside = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 40),
              SizedBox(
                height: 47,
                width: 300,
                child: TemplateDateTypeAhead(
                  controller: name,
                  focusNode: focus,
                  child: TextField(
                    controller: name,
                    focusNode: focus,
                    // The template screen moves focus away on an outside tap.
                    onTapOutside: (_) {
                      tappedOutside++;
                      focus.unfocus();
                    },
                    decoration: const InputDecoration(hintText: 'Enter name'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.tap(find.byType(TextField));
      await tester.pump();
    }

    final suggestion = find.text(r'${date} - Current Date');

    testWidgets('typing \$ shows it; tapping it completes \${date}',
        (tester) async {
      await pumpBox(tester);
      await tester.enterText(find.byType(TextField), 'Late Notice ');
      await tester.pump();
      expect(suggestion, findsNothing);

      await tester.enterText(find.byType(TextField), r'Late Notice $');
      await tester.pump();
      expect(suggestion, findsOneWidget);

      await tester.tap(suggestion);
      await tester.pump();
      expect(name.text, r'Late Notice ${date}');
      expect(name.selection.baseOffset, name.text.length,
          reason: 'cursor at the end');
      expect(suggestion, findsNothing);
      expect(tappedOutside, 0,
          reason: 'tapping the suggestion is not a tap outside the Name box');
      expect(focus.hasFocus, isTrue);

      // Once the name has ${date}, typing $ again offers nothing.
      await tester.enterText(find.byType(TextField), r'Late Notice ${date} $');
      await tester.pump();
      expect(suggestion, findsNothing);
    });

    testWidgets('\${d keeps it open; deleting or leaving the box hides it',
        (tester) async {
      await pumpBox(tester);
      await tester.enterText(find.byType(TextField), r'Rent ${');
      await tester.pump();
      expect(suggestion, findsOneWidget);
      await tester.enterText(find.byType(TextField), r'Rent ${d');
      await tester.pump();
      expect(suggestion, findsOneWidget);

      await tester.enterText(find.byType(TextField), r'Rent ${');
      await tester.pump();
      expect(suggestion, findsNothing, reason: 'deleting hides it');

      await tester.enterText(find.byType(TextField), r'Rent ${da');
      await tester.pump();
      expect(suggestion, findsOneWidget);
      focus.unfocus();
      await tester.pump();
      expect(suggestion, findsNothing, reason: 'leaving the box hides it');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), r'Rent ${dat');
      await tester.pump();
      await tester.tap(suggestion);
      await tester.pump();
      expect(name.text, r'Rent ${date}');
    });

    testWidgets('a saved name loaded with \$ does not pop it up',
        (tester) async {
      await pumpBox(tester);
      focus.unfocus();
      await tester.pump();
      name.text = r'Deposit $';
      await tester.pump();
      expect(suggestion, findsNothing);
    });
  });

  testWidgets('the info icon shows the tip with the company date format',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DateProvider(),
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: TemplateNameDateTip(color: Colors.blue)),
        ),
      ),
    ));
    await tester.tap(find.byType(TemplateNameDateTip));
    await tester.pumpAndSettle();
    expect(find.textContaining('You can use the following dynamic variable:'),
        findsOneWidget);
    expect(find.textContaining(r'${date} - Current Date (MM/DD/YYYY)'),
        findsOneWidget);
  });

  for (final path in _forms) {
    test('$path: Name has the tip and the \${date} suggestion', () {
      final src = File(path).readAsStringSync();
      expect(src, contains(
          "import 'package:three_zero_two_property/widgets/template_name_date_helper.dart';"));
      final label = src.indexOf("Text('Name *',");
      expect(label, isNonNegative);
      expect(src.substring(label, label + 600), contains('TemplateNameDateTip('));
      final box = src.indexOf('child: TemplateDateTypeAhead(');
      expect(box, isNonNegative);
      final wrapped = src.substring(box, src.indexOf('hintText: "Enter name"', box));
      expect(wrapped, contains('controller: name,'));
      expect(wrapped, contains('focusNode: _nameFocusNode!,'));
      expect(wrapped, contains('child: TextField('));
      expect('TemplateDateTypeAhead('.allMatches(src).length, 1);
    });
  }
}
