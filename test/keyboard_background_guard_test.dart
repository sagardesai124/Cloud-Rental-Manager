import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/widgets/keyboard_background_guard.dart';

/// QA (Android, My Profile): with First Name focused, going Home and back
/// from Recent apps left the keyboard's space reserved — the page stayed
/// squeezed above a blank white area and the text was cut off. The app now
/// closes the keyboard when it is hidden on Android, so it comes back at full
/// height.

const _field = Key('first-name');

Future<void> _showForm(WidgetTester tester, {bool guard = true}) async {
  await tester.pumpWidget(MaterialApp(
    builder: guard
        ? (context, child) => KeyboardBackgroundGuard(child: child!)
        : null,
    home: const Scaffold(body: Center(child: TextField(key: _field))),
  ));
  await tester.tap(find.byKey(_field));
  await tester.pump();
  expect(_focused(tester), isTrue, reason: 'First Name focused');
  expect(tester.testTextInput.isVisible, isTrue, reason: 'keyboard open');
}

bool _focused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

/// Home pressed: the app goes inactive, then hidden, then paused.
Future<void> _goHome(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

/// Opened again from Recent apps.
Future<void> _comeBack(WidgetTester tester) async {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

void main() {
  testWidgets('Android: going Home closes the keyboard, so the app comes back '
      'at full height', (tester) async {
    await _showForm(tester);
    await _goHome(tester);
    expect(_focused(tester), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await _comeBack(tester);
    expect(_focused(tester), isFalse);
    expect(tester.testTextInput.isVisible, isFalse,
        reason: 'no keyboard space left reserved');
    // Typing still works after coming back.
    await tester.tap(find.byKey(_field));
    await tester.enterText(find.byKey(_field), 'Mary');
    expect(find.text('Mary'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android: a brief interruption (notification shade, permission '
      'dialog) keeps the keyboard', (tester) async {
    await _showForm(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_focused(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS: unchanged — the keyboard is left as it was',
      (tester) async {
    await _showForm(tester);
    await _goHome(tester);
    expect(_focused(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('control: without the guard, Android keeps the field focused '
      'while hidden (the reported problem)', (tester) async {
    await _showForm(tester, guard: false);
    await _goHome(tester);
    expect(_focused(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('the app root wraps every screen in the guard', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains("import 'widgets/keyboard_background_guard.dart';"));
    final builder = src.substring(src.indexOf('builder: (context, child) {'));
    expect(
        RegExp(r'return KeyboardBackgroundGuard\(\s*child: ScrollConfiguration\(')
            .hasMatch(builder),
        isTrue);
  });
}
