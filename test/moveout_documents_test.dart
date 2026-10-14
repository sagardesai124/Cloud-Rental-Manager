import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart';

/// Move-out documents follow the web's rules and messages
/// (RentRollDetail.jsx handleMoveoutFileChange): at most 10 in total, no file
/// name twice, only .pdf/.doc/.docx/.jpg/.jpeg/.png, at most 5 MB each.

const _mb = 1024 * 1024;

MoveoutDocumentCheck _check(List<String> existing, List<String> names,
        [List<int>? sizes]) =>
    checkMoveoutDocuments(
      existingNames: existing,
      pickedNames: names,
      pickedSizes: sizes ?? names.map((_) => _mb).toList(),
    );

void main() {
  group('checkMoveoutDocuments (web rules)', () {
    test('accepts the six web file types, any letter case', () {
      final c = _check([], ['a.pdf', 'b.doc', 'c.docx', 'd.JPG', 'e.jpeg', 'f.png']);
      expect(c.accepted, [0, 1, 2, 3, 4, 5]);
      expect(c.errors, isEmpty);
    });

    test('rejects other types with the web message', () {
      final c = _check([], ['notes.txt', 'photo.heic', 'scan.pdf', 'noext']);
      expect(c.accepted, [2]);
      expect(c.errors, [
        'Invalid file type: notes.txt',
        'Invalid file type: photo.heic',
        'Invalid file type: noext',
      ]);
    });

    test('rejects files over 5 MB with the web message', () {
      final c = _check([], ['big.pdf', 'ok.pdf'], [5 * _mb + 1, 5 * _mb]);
      expect(c.accepted, [1]);
      expect(c.errors, ['File too large (max 5MB): big.pdf']);
    });

    test('rejects a file already added (same name, like web)', () {
      final c = _check(['lease.pdf'], ['lease.pdf', 'keys.jpg']);
      expect(c.accepted, [1]);
      expect(c.errors, ['File "lease.pdf" has already been added']);
    });

    test('a different-size file with an added name is still refused, like web',
        () {
      final c = _check(['scan.pdf'], ['scan.pdf'], [2 * _mb]);
      expect(c.accepted, isEmpty);
      expect(c.errors, ['File "scan.pdf" has already been added']);
    });

    test('more than 10 in total adds nothing, like web', () {
      final existing = List.generate(8, (i) => 'f$i.pdf');
      final c = _check(existing, ['a.pdf', 'b.pdf', 'c.pdf']);
      expect(c.accepted, isEmpty);
      expect(c.errors, ['Maximum 10 files can be uploaded at once']);
      expect(_check(existing, ['a.pdf', 'b.pdf']).accepted, [0, 1]);
    });
  });

  group('MoveoutPickedFileTile', () {
    testWidgets('shows the name, sends the description, removes', (tester) async {
      var removed = false;
      String? description;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MoveoutPickedFileTile(
            fileName: 'keys_returned.pdf',
            onRemove: () => removed = true,
            onDescriptionChanged: (v) => description = v,
          ),
        ),
      ));
      expect(find.text('keys_returned.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.text('Enter description'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('moveout-file-description')), 'Keys returned');
      expect(description, 'Keys returned');

      await tester.tap(find.byKey(const Key('moveout-file-remove')));
      expect(removed, isTrue);
    });

    testWidgets('a typed description stays with its file when another is removed',
        (tester) async {
      final files = [Object(), Object()];
      final names = {files[0]: 'first.pdf', files[1]: 'second.png'};
      late StateSetter setOuter;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            setOuter = setState;
            return Column(
              children: files
                  .map((f) => MoveoutPickedFileTile(
                        key: ObjectKey(f),
                        fileName: names[f]!,
                        onRemove: () {},
                        onDescriptionChanged: (_) {},
                      ))
                  .toList(),
            );
          }),
        ),
      ));
      await tester.enterText(
          find.byKey(const Key('moveout-file-description')).at(1),
          'Signed inspection photo');

      setOuter(() => files.removeAt(0));
      await tester.pump();

      expect(find.text('first.pdf'), findsNothing);
      expect(find.text('second.png'), findsOneWidget);
      expect(find.text('Signed inspection photo'), findsOneWidget);
    });
  });
}
