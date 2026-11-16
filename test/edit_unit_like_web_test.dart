import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/model/unitsummery_propeties.dart';
import 'package:three_zero_two_property/services/unit_edit_check.dart';

/// Property › Units › Edit Unit, like web staging: saving without a change
/// sends nothing, says "No changes detected" and keeps the form open
/// (Units.jsx isUnitEditUnchanged, used by PropDetails.jsx and
/// StaffPropertyDetail.jsx), and every form is headed "Edit Unit Details".

const _pages = {
  'Admin': 'lib/screens/Rental/Properties/summery_page.dart',
  'Staff': 'lib/StaffModule/screen/Rental/Properties/summery_page.dart',
};

const _beds = ['1 Bed', '2 Bed', '3 Bed', '9+ Bed'];
const _baths = ['1 Bath', '1.5 Bath', '2 Bath', '5+ Bath'];

unit_properties _unit() => unit_properties(
      unitId: 'U-1',
      rentalunit: 'A1',
      rentalunitadress: '1 Oak Street',
      rentalsqft: '900',
      rentalbed: '2 Bed',
      rentalbath: '1.5 Bath',
      rentalImages: ['a.jpg', 'b.jpg'],
    );

void main() {
  test("web's message", () {
    expect(unitEditNoChangesMessage, 'No changes detected');
  });

  group('isUnitEditUnchanged, like web', () {
    bool unchanged({
      String unitNumber = 'A1',
      String address = '1 Oak Street',
      String sqft = '900',
      String bed = '2 Bed',
      String bath = '1.5 Bath',
      List<String> photos = const ['a.jpg', 'b.jpg'],
      bool newPhotos = false,
    }) =>
        isUnitEditUnchanged(_unit(),
            unitNumber: unitNumber,
            address: address,
            sqft: sqft,
            bed: bed,
            bath: bath,
            photos: photos,
            newPhotos: newPhotos,
            bedOptions: _beds,
            bathOptions: _baths);

    test('an untouched form is unchanged; spaces around text do not count',
        () {
      expect(unchanged(), isTrue);
      expect(unchanged(unitNumber: ' A1 ', address: '1 Oak Street  '), isTrue);
    });

    test('any real field change is a change', () {
      expect(unchanged(unitNumber: 'A2'), isFalse);
      expect(unchanged(address: '2 Oak Street'), isFalse);
      expect(unchanged(sqft: '901'), isFalse);
      expect(unchanged(bed: '3 Bed'), isFalse);
      expect(unchanged(bath: '2 Bath'), isFalse);
    });

    test('photos: same list in the same order, nothing new', () {
      expect(unchanged(photos: ['a.jpg', 'b.jpg', 'c.jpg']), isFalse,
          reason: 'added');
      expect(unchanged(photos: ['a.jpg']), isFalse, reason: 'removed');
      expect(unchanged(photos: ['b.jpg', 'a.jpg']), isFalse,
          reason: 'reordered, as web compares in order');
      expect(unchanged(newPhotos: true), isFalse,
          reason: 'a picked photo, like a new File on web');
    });

    test('only the fields a form edits are compared', () {
      // A commercial form has no bed or bath.
      expect(
          isUnitEditUnchanged(_unit(),
              unitNumber: 'A1',
              address: '1 Oak Street',
              sqft: '900',
              photos: ['a.jpg', 'b.jpg']),
          isTrue);
      // A single-unit commercial form edits only the area.
      expect(isUnitEditUnchanged(_unit(), sqft: '900'), isTrue);
      expect(isUnitEditUnchanged(_unit(), sqft: '950'), isFalse);
    });

    test('empty and missing saved values match an empty box', () {
      final bare = unit_properties(unitId: 'U-2');
      expect(
          isUnitEditUnchanged(bare,
              unitNumber: '', address: ' ', sqft: '', photos: []),
          isTrue);
      expect(isUnitEditUnchanged(bare, sqft: '100'), isFalse);
    });

    test('a bed/bath dropdown the form rewrote, but nobody touched, is '
        'unchanged', () {
      final odd = unit_properties(
          unitId: 'U-3', rentalbed: '2', rentalbath: '6.5', rentalsqft: '900');
      // The form shows the saved "2" as "2 Bed" and "6.5" as "5+ Bath".
      expect(
          isUnitEditUnchanged(odd,
              bed: '2 Bed',
              bath: '5+ Bath',
              bedOptions: _beds,
              bathOptions: _baths),
          isTrue);
      expect(
          isUnitEditUnchanged(odd,
              bed: '3 Bed',
              bath: '5+ Bath',
              bedOptions: _beds,
              bathOptions: _baths),
          isFalse,
          reason: 'a different bed is a change');
    });

    test("bed/bath are shown the way the page's dropdowns rewrite them", () {
      expect(unitBedShown('2 Bed', _beds), '2 Bed');
      expect(unitBedShown('4', _beds), '4 Bed');
      expect(unitBedShown('12 beds', _beds), '9+ Bed');
      expect(unitBedShown('', _beds), '');
      expect(unitBathShown('1.5 Bath', _baths), '1.5 Bath');
      expect(unitBathShown('2', _baths), '2 Bath');
      expect(unitBathShown('2.3', _baths), '2.5 Bath');
      expect(unitBathShown('7', _baths), '5+ Bath');
    });
  });

  group('every Edit Unit save checks first', () {
    for (final entry in _pages.entries) {
      test(entry.key, () {
        final src = File(entry.value).readAsStringSync();
        final lines = src.split('\n');
        final saves = <int>[
          for (var i = 0; i < lines.length; i++)
            if (lines[i].contains('.Editunit(') &&
                !lines[i].trimLeft().startsWith('//'))
              i
        ];
        expect(saves, hasLength(6),
            reason: 'residential and commercial, single-unit and multi-unit '
                '(phone and tablet)');
        for (final i in saves) {
          final before = lines.sublist(i - 40, i).join('\n');
          final check = before.lastIndexOf('isUnitEditUnchanged(');
          expect(check, isNonNegative, reason: 'save at line ${i + 1}');
          final rest = before.substring(check);
          expect(rest, contains('unitEditNoChangesMessage'),
              reason: 'line ${i + 1}');
          expect(rest, contains('return;'),
              reason: 'nothing is sent, the form stays open (${i + 1})');
          expect(before.substring(0, check), contains('iserror'),
              reason: 'required fields are checked first, like web');
          // The check compares against the unit this save updates.
          // (Some saves split "data\n.first" over lines, so ignore spaces.)
          final save =
              lines.sublist(i, i + 30).join().replaceAll(RegExp(r'\s+'), '');
          final unit = RegExp(r'isUnitEditUnchanged\(\s*([A-Za-z_][\w.\[\]0-9]*)')
              .firstMatch(rest)!
              .group(1)!;
          final saved = unit == 'data[0]' || unit == 'data.first'
              ? unit
              : '$unit.unitId';
          if (unit != 'data[0]') {
            expect(save, contains(saved), reason: 'line ${i + 1}');
          }
        }
      });
    }
  });

  test('every Edit Unit form is headed "Edit Unit Details", like web', () {
    for (final path in _pages.values) {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains('Edid Unit')), reason: path);
      expect('"Edit Unit Details"'.allMatches(src).length,
          greaterThanOrEqualTo(6),
          reason: path);
    }
  });
}
