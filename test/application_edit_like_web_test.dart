import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/repository/application_rules_repo.dart';
import 'package:three_zero_two_property/services/application_edit_rules.dart';
import 'package:three_zero_two_property/services/zip_code.dart';
import 'package:three_zero_two_property/widgets/application_edit_form.dart';

/// Leasing → Applicants → applicant → Application → Edit (Admin and Staff
/// share ApplicationEditForm), like web staging (ApplicantForm.jsx and
/// applicantFormStepValidation.jsx): Applicant Birth Date stops 18 years
/// ago, a resident's Date of Birth can't be in the future, Move In Date is
/// today or later, Driver's License Number takes letters, numbers and dashes
/// and must be 5 to 20 characters, and Zip Code is 12345 or 12345-6789 (not
/// 00000): 5 digits in the applicant's and References' boxes, ZIP+4 with
/// the dash in Address History. Only Birth Date shows a message; the others
/// turn red, with "Please correct the red boxes above" by Save. Before, any
/// date from 1900 to 2100 was taken, the license took any text and zip took
/// 4 to 10 digits.

const _fmt = 'MM/dd/yyyy';
final DateTime _today = DateUtils.dateOnly(DateTime.now());
String _shown(DateTime d) => DateFormat(_fmt).format(d);
String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _typed(List<TextInputFormatter> formatters, String text) {
  var value = TextEditingValue(
      text: text, selection: TextSelection.collapsed(offset: text.length));
  for (final f in formatters) {
    value = f.formatEditUpdate(TextEditingValue.empty, value);
  }
  return value.text;
}

Map<String, dynamic> _raw({
  String license = 'D1234567',
  String zip = '78701',
  DateTime? birth,
  DateTime? moveIn,
  DateTime? residentBirth,
  String addressZip = '78701-1234',
  String referenceZip = '78702',
  bool withResident = true,
}) =>
    {
      'applicant_firstName': 'Ann',
      'applicant_lastName': 'Lee',
      'applicant_email': 'ann@example.com',
      'state': 'Texas',
      'driver_license': license,
      'current_address': '1 Main St',
      'applicant_city': 'Austin',
      'applicant_state': 'Texas',
      'applicant_postalCode': zip,
      'applicant_phoneNumber': '(512) 555-0100',
      'applicant_birthDate': _iso(birth ?? DateTime(_today.year - 30, 1, 15)),
      'move_in_date': _iso(moveIn ?? _today.add(const Duration(days: 30))),
      'additional_residents': [
        if (withResident)
          {
            'name': 'Sam Lee',
            'relation': 'Son',
            'dob': _iso(residentBirth ?? DateTime(_today.year - 5, 3, 1)),
          }
      ],
      'address_history': [
        {
          'street': '1 Main St',
          'city': 'Austin',
          'state': 'Texas',
          'zip': addressZip,
          'is_current_address': true,
        }
      ],
      'personal_references': [
        {'name': 'Bob Ray', 'zip': referenceZip}
      ],
    };

/// The box currently showing [text].
Finder _box(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == text,
    description: 'box showing "$text"');

String? _errorOf(WidgetTester tester, String text) =>
    tester.widget<TextField>(_box(text)).decoration?.errorText;

/// The box using [controller], whatever it shows.
Finder _boxOf(TextEditingController controller) => find.byWidgetPredicate(
    (w) => w is TextField && identical(w.controller, controller));

/// Red border with no message under it, like web.
bool _isRedBoxOnly(WidgetTester tester, String text) {
  final decoration = tester.widget<TextField>(_box(text)).decoration!;
  final error = decoration.error;
  return decoration.errorText == null &&
      error is SizedBox &&
      error.width == 0 &&
      error.height == 0;
}

/// The first empty box with [hint] (resident rows come before References
/// and Emergency Contact).
Finder _emptyBox(String hint) => find
    .byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.hintText == hint &&
        (w.controller?.text ?? '').isEmpty)
    .first;

Future<List<Map<String, dynamic>>> _pumpForm(
    WidgetTester tester, Map<String, dynamic> raw,
    {Future<bool> Function()? residentDobRequired}) async {
  tester.view.physicalSize = const Size(1000, 9000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final saved = <Map<String, dynamic>>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ApplicationEditForm(
          raw: raw,
          applicantId: 'applicant-1',
          dateFormat: _fmt,
          onSave: (payload) async {
            saved.add(payload);
            return true;
          },
          onCancel: () {},
          onSaved: () {},
          loadResidentDobRequired: residentDobRequired,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return saved;
}

Future<void> _addResident(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Add Resident'));
  await tester.tap(find.text('Add Resident'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Application'));
  await tester.tap(find.text('Save Application'));
  await tester.pumpAndSettle();
}

const _redBoxMessages = [
  "Driver's license number must be at least 5 characters",
  "Driver's license number must be 20 characters or fewer",
  'Please enter a valid zip code (XXXXX or XXXXX-XXXX)',
  'A past date is not allowed',
  'Date of Birth cannot be a future date.',
];

void main() {
  group("Applicant Birth Date, like web's validateDateField('birthDate')", () {
    String? check(String shown) => applicantBirthDateError(shown, _fmt, _today);

    test('required', () {
      expect(check(''), 'Date of Birth is required');
    });

    test('not in the future', () {
      expect(check(_shown(_today.add(const Duration(days: 1)))),
          'Date of Birth cannot be a future date.');
    });

    test('at least 18 years old; exactly 18 today is fine', () {
      final latest = latestApplicantBirthDate(_today);
      expect(check(_shown(latest.add(const Duration(days: 1)))),
          'You must be at least 18 years old to apply.');
      expect(check(_shown(DateTime(_today.year - 17, 6, 1))),
          'You must be at least 18 years old to apply.');
      expect(check(_shown(latest)), isNull);
      expect(check(_shown(DateTime(_today.year - 40, 2, 3))), isNull);
    });

    test('the calendar stops 18 years ago', () {
      expect(latestApplicantBirthDate(DateTime(2026, 11, 17)),
          DateTime(2008, 11, 17));
    });

    test('before 1900 and unreadable dates, with web messages', () {
      expect(check('12/31/1899'), 'Please enter a valid date of birth.');
      expect(check('abc'), 'Invalid date format. Please use MM/DD/YYYY');
      expect(
          applicantBirthDateError('15-01-1990', 'dd-MM-yyyy', _today), isNull);
    });
  });

  group("Resident's Date of Birth, like web's 'birthDateNoMinAge'", () {
    String? check(String shown) => residentBirthDateError(shown, _fmt, _today);

    test('optional, not in the future, minors allowed', () {
      expect(check(''), isNull);
      expect(check(_shown(_today.add(const Duration(days: 1)))),
          'Date of Birth cannot be a future date.');
      expect(check(_shown(DateTime(_today.year - 5, 3, 1))), isNull);
      expect(check(_shown(_today)), isNull);
    });
  });

  group("Move In Date, like web's validateMoveInDate", () {
    String? check(String shown) => moveInDateError(shown, _fmt, _today);

    test('today or later; a past date is not allowed', () {
      expect(check(''), isNull);
      expect(check(_shown(_today)), isNull);
      expect(check(_shown(_today.add(const Duration(days: 45)))), isNull);
      expect(check(_shown(_today.subtract(const Duration(days: 1)))),
          'A past date is not allowed');
      expect(check('01/01/2019'), 'A past date is not allowed');
    });
  });

  group("Driver's License Number, like web", () {
    test('letters, numbers and dashes only while typing', () {
      expect(_typed([driverLicenseFormatter], 'ab 12@34-5#'), 'ab1234-5');
    });

    test('required, 5 to 20 characters', () {
      expect(driverLicenseError(''), "Driver's License Number is required");
      expect(driverLicenseError('AB12'),
          "Driver's license number must be at least 5 characters");
      expect(driverLicenseError('AB123'), isNull);
      expect(driverLicenseError('A' * 20), isNull);
      expect(driverLicenseError('A' * 21),
          "Driver's license number must be 20 characters or fewer");
    });
  });

  group("Zip Code, like web's validateZipCodeFormat and formatZipCode", () {
    test('12345 or 12345-6789, and not 00000', () {
      expect(applicationZipError('78701'), isNull);
      expect(applicationZipError('02101'), isNull);
      expect(applicationZipError('78701-1234'), isNull);
      for (final bad in ['1234', '123456', '78701-12', '00000', '00000-1234']) {
        expect(applicationZipError(bad),
            'Please enter a valid zip code (XXXXX or XXXXX-XXXX)',
            reason: bad);
      }
      expect(applicationZipError('', required: true), 'Zip Code is required');
      expect(applicationZipError(''), isNull);
    });

    test("applicant's and References' boxes take 5 digits", () {
      expect(_typed(fiveDigitZipFormatters(), '78701-1234'), '78701');
      expect(_typed(fiveDigitZipFormatters(), 'a7b8'), '78');
    });

    test('Address History adds the dash for ZIP+4', () {
      expect(_typed([zipCodeFormatter], '787011234'), '78701-1234');
      expect(_typed([zipCodeFormatter], '78701123456'), '78701-1234');
    });
  });

  group('on the real form (Admin and Staff)', () {
    testWidgets(
        'wrong values block Save: Birth Date shows its message, the rest '
        'turn red, with "Please correct the red boxes above"', (tester) async {
      final under18 = DateTime(_today.year - 17, _today.month, 1);
      final pastMoveIn = _today.subtract(const Duration(days: 30));
      final futureResident = _today.add(const Duration(days: 3));
      final saved = await _pumpForm(
          tester,
          _raw(
            license: 'AB12',
            zip: '1234',
            birth: under18,
            moveIn: pastMoveIn,
            residentBirth: futureResident,
            addressZip: '00000',
            referenceZip: '123',
          ));
      final heightBefore = tester.getSize(_box('AB12')).height;
      expect(find.text('Please correct the red boxes above'), findsNothing);

      await _tapSave(tester);

      expect(saved, isEmpty);
      expect(find.text('Please correct the red boxes above'), findsOneWidget);
      expect(find.text('You must be at least 18 years old to apply.'),
          findsOneWidget);
      expect(_errorOf(tester, _shown(under18)),
          'You must be at least 18 years old to apply.');
      for (final redOnly in [
        'AB12',
        '1234',
        _shown(pastMoveIn),
        _shown(futureResident),
        '00000',
        '123',
      ]) {
        expect(_isRedBoxOnly(tester, redOnly), isTrue, reason: redOnly);
      }
      for (final message in _redBoxMessages) {
        expect(find.text(message), findsNothing, reason: message);
      }
      // A red box only: no empty message line under it.
      expect(tester.getSize(_box('AB12')).height, heightBefore);
    });

    testWidgets("right values save with web's formats", (tester) async {
      final saved = await _pumpForm(tester, _raw());

      // No autocorrect on the license (iPhone turned "ab " into "an ").
      final license = tester.widget<TextField>(_box('D1234567'));
      expect(license.autocorrect, isFalse);
      expect(license.enableSuggestions, isFalse);
      await tester.enterText(_box('D1234567'), 'ab 12@34-5');
      // A full 5-digit box takes no 6th digit, like web's maxLength 5.
      await tester.enterText(_box('78701'), '787019');
      expect(_box('78701'), findsOneWidget);
      await tester.enterText(_box('78701-1234'), '787051234');
      final referenceZip = tester.widget<TextField>(_box('78702')).controller!;
      await tester.enterText(_boxOf(referenceZip), '');
      await tester.enterText(_boxOf(referenceZip), '78703-99');
      await tester.pumpAndSettle();
      expect(_box('ab1234-5'), findsOneWidget);
      expect(_box('78705-1234'), findsOneWidget);
      expect(_box('78703'), findsOneWidget);

      await _tapSave(tester);

      expect(find.text('Please correct the red boxes above'), findsNothing);
      expect(saved, hasLength(1));
      final payload = saved.single;
      expect(payload['driver_license'], 'ab1234-5');
      expect(payload['applicant_postalCode'], '78701');
      expect((payload['address_history'] as List).single['zip'], '78705-1234');
      expect(
          (payload['personal_references'] as List).single['zip'], '78703');
      // A 5-year-old resident is fine, like web.
      expect((payload['additional_residents'] as List).single['dob'],
          _iso(DateTime(_today.year - 5, 3, 1)));
    });

    testWidgets('the red-box line goes once the boxes are fixed',
        (tester) async {
      final saved = await _pumpForm(tester, _raw(license: 'AB12'));

      await _tapSave(tester);
      expect(saved, isEmpty);
      expect(find.text('Please correct the red boxes above'), findsOneWidget);

      await tester.enterText(_box('AB12'), 'AB12345');
      await tester.pumpAndSettle();
      expect(find.text('Please correct the red boxes above'), findsNothing);

      await _tapSave(tester);
      expect(saved, hasLength(1));
    });

    testWidgets("the calendars stop where web's do", (tester) async {
      final under18 = DateTime(_today.year - 17, _today.month, 1);
      final pastMoveIn = _today.subtract(const Duration(days: 30));
      final futureResident = _today.add(const Duration(days: 3));
      await _pumpForm(
          tester,
          _raw(
              birth: under18,
              moveIn: pastMoveIn,
              residentBirth: futureResident));

      // Saved dates outside the limits still open the calendar.
      await tester.tap(_box(_shown(under18)));
      await tester.pumpAndSettle();
      var dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dialog.lastDate, latestApplicantBirthDate(_today));
      expect(dialog.firstDate, DateTime(1900));
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();

      await tester.tap(_box(_shown(pastMoveIn)));
      await tester.pumpAndSettle();
      dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dialog.firstDate, _today);
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();

      await tester.tap(_box(_shown(futureResident)));
      await tester.pumpAndSettle();
      final calendar =
          tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(calendar.lastDate, _today);
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    test('Admin and Staff both open this form, each loading the setting '
        'with its own id', () {
      const screens = {
        'lib/screens/Leasing/Applicants/Summary/ApplicantContent.dart':
            'asStaff: false',
        'lib/StaffModule/screen/Leasing/Applicants/Summary/ApplicantContent.dart':
            'asStaff: true',
      };
      screens.forEach((path, role) {
        final source = File(path).readAsStringSync();
        expect(source, contains('ApplicationEditForm('), reason: path);
        expect(source, contains('fetchResidentDobRequired('), reason: path);
        expect(source, contains(role), reason: path);
      });
    });
  });

  group("Additional Residents, like web's additionalResidentDob.js", () {
    test('the setting: unset means required; only an explicit false turns '
        'it off', () {
      Map<String, dynamic> withDob(Object? dob) => {
            'additionalResidents': {
              'fields': {'dob': dob}
            }
          };
      expect(residentDobRequired(null), isTrue);
      expect(residentDobRequired(const {}), isTrue);
      expect(residentDobRequired(withDob({'required': false})), isFalse);
      expect(residentDobRequired(withDob({'required': true})), isTrue);
      expect(residentDobRequired(withDob(const {})), isTrue);
      expect(residentDobRequired(withDob({'required': 'false'})), isTrue);
      expect(residentDobRequired(withDob(null)), isTrue);
      // The older settings key is read the same way.
      expect(
          residentDobRequired({
            'additional_residents': {
              'fields': {
                'dob': {'required': false}
              }
            }
          }),
          isFalse);
    });

    test('Name and Relation always; Date of Birth when the setting is on', () {
      expect(residentNameError(' '), 'Name is required');
      expect(residentRelationError(''), 'Relation is required');
      expect(residentNameError('Sam'), isNull);
      expect(residentBirthDateError('', _fmt, _today, required: true),
          'Date of birth is required');
      expect(residentBirthDateError('', _fmt, _today), isNull);
    });
  });

  group('loading the setting like web: company, then the property owner', () {
    late List<http.Request> requests;

    setUp(() => SharedPreferences.setMockInitialValues(
        {'adminId': 'admin-1', 'staff_id': 'staff-9', 'token': 'tok'}));

    Future<bool> load(Map<String, dynamic> raw, Map<String, Object> replies,
        {bool asStaff = false}) {
      requests = [];
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final key = path.substring(path.indexOf('/api/') + 5) +
            (request.url.query.isEmpty ? '' : '?${request.url.query}');
        final reply = replies[key];
        return reply == null
            ? http.Response('{}', 500)
            : http.Response(jsonEncode(reply), 200);
      });
      return http.runWithClient(
          () => fetchResidentDobRequired(raw: raw, asStaff: asStaff),
          () => client);
    }

    Map<String, Object> rules(bool dobRequired) => {
          'additionalResidents': {
            'fields': {
              'dob': {'required': dobRequired}
            }
          }
        };
    const company = 'tenant/step-configurations/admin-1';
    const summary = 'rentals/rental_summary/prop-1';
    const owner =
        'property-owner-overrides/effective/application-rules/owner-1?admin_id=admin-1';

    test("the property owner's rules win over the company's", () async {
      final required = await load(
          {'admin_id': 'admin-1', 'selected_property': 'prop-1'},
          {
            company: {'statusCode': 200, 'data': rules(true)},
            summary: {
              'statusCode': 200,
              'data': [
                {'rentalowner_id': 'owner-1'}
              ]
            },
            owner: {
              'statusCode': 200,
              'data': {'stepConfigurations': rules(false)}
            },
          });
      expect(required, isFalse);
      expect(requests, hasLength(3));
      expect(requests.first.headers['id'], 'CRM admin-1');
      expect(requests.first.headers['authorization'], 'CRM tok');
    });

    test('Staff sends its own id', () async {
      await load({'admin_id': 'admin-1'},
          {company: {'statusCode': 200, 'data': rules(true)}},
          asStaff: true);
      expect(requests.single.headers['id'], 'CRM staff-9');
    });

    test("the company's setting when there's no property owner", () async {
      expect(
          await load({'admin_id': 'admin-1'},
              {company: {'statusCode': 200, 'data': rules(false)}}),
          isFalse);
      expect(requests, hasLength(1));
      // The owner call failing keeps the company's setting, like web.
      expect(
          await load({'admin_id': 'admin-1', 'rental_id': 'prop-1'}, {
            company: {'statusCode': 200, 'data': rules(false)},
            summary: {
              'statusCode': 200,
              'data': {'rentalowner_id': 'owner-1'}
            },
          }),
          isFalse);
      expect(requests, hasLength(3));
    });

    test('required when nothing loads or there is no admin', () async {
      expect(await load({'admin_id': 'admin-1'}, const {}), isTrue);
      expect(await load({}, const {}), isTrue);
      expect(requests, isEmpty);
    });
  });

  group('resident rows on the real form', () {
    testWidgets('no empty resident row to start, like web; Save sends none',
        (tester) async {
      final saved = await _pumpForm(tester, _raw(withResident: false));
      expect(find.text('Resident 1'), findsNothing);

      await _tapSave(tester);

      expect(saved, hasLength(1));
      expect(saved.single['additional_residents'], isEmpty);
    });

    testWidgets(
        'an added resident needs Name, Relation and Date of Birth (red '
        'boxes), or Remove', (tester) async {
      final saved = await _pumpForm(tester, _raw(withResident: false));
      await _addResident(tester);
      expect(find.text('Resident 1'), findsOneWidget);
      expect(find.text('Name *', findRichText: true), findsWidgets);
      expect(find.text('Date of Birth *', findRichText: true), findsOneWidget);

      await _tapSave(tester);

      expect(saved, isEmpty);
      expect(find.text('Please correct the red boxes above'), findsOneWidget);
      for (final hint in ['Enter full name', 'Enter relationship', 'MM/DD/YYYY']) {
        final decoration = tester.widget<TextField>(_emptyBox(hint)).decoration!;
        expect(decoration.errorText, isNull, reason: hint);
        expect(decoration.error, isA<SizedBox>(), reason: hint);
      }
      for (final message in [
        'Name is required',
        'Relation is required',
        'Date of birth is required',
      ]) {
        expect(find.text(message), findsNothing, reason: message);
      }

      // The only row can be removed, like web.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Resident 1'), findsNothing);
      await _tapSave(tester);
      expect(saved, hasLength(1));
      expect(saved.single['additional_residents'], isEmpty);
    });

    testWidgets('setting on: a resident without Date of Birth is blocked',
        (tester) async {
      final saved = await _pumpForm(tester, _raw(withResident: false),
          residentDobRequired: () async => true);
      await _addResident(tester);
      await tester.enterText(_emptyBox('Enter full name'), 'Sam Lee');
      await tester.enterText(_emptyBox('Enter relationship'), 'Son');

      await _tapSave(tester);

      expect(saved, isEmpty);
      expect(
          tester.widget<TextField>(_emptyBox('MM/DD/YYYY')).decoration!.error,
          isA<SizedBox>());
    });

    testWidgets(
        'setting off ("Require date of birth" unticked): a resident saves '
        'without one', (tester) async {
      final saved = await _pumpForm(tester, _raw(withResident: false),
          residentDobRequired: () async => false);
      await _addResident(tester);
      expect(find.text('Date of Birth *', findRichText: true), findsNothing);
      expect(find.text('Date of Birth', findRichText: true), findsOneWidget);
      await tester.enterText(_emptyBox('Enter full name'), 'Sam Lee');
      await tester.enterText(_emptyBox('Enter relationship'), 'Son');

      await _tapSave(tester);

      expect(saved, hasLength(1));
      final resident =
          (saved.single['additional_residents'] as List).single as Map;
      expect(resident['name'], 'Sam Lee');
      expect(resident['relation'], 'Son');
      expect(resident['dob'], '');
    });
  });

  group(
      "name boxes take only what web's do: letters and spaces (Last Name "
      'hyphens too)', () {
    String edit(TextInputFormatter f, String from, String to) => f
        .formatEditUpdate(
            TextEditingValue(
                text: from,
                selection: TextSelection.collapsed(offset: from.length)),
            TextEditingValue(
                text: to,
                selection: TextSelection.collapsed(offset: to.length)))
        .text;

    test('a typed or pasted number or symbol is ignored, like web', () {
      expect(edit(lettersAndSpacesFormatter, '', 'Mary Ann'), 'Mary Ann');
      expect(edit(lettersAndSpacesFormatter, 'Mary', 'Mary2'), 'Mary');
      expect(edit(lettersAndSpacesFormatter, 'Sam', 'Sam-'), 'Sam');
      // Web ignores the whole paste rather than keeping its letters.
      expect(edit(lettersAndSpacesFormatter, '', "O'Brien"), '');
      expect(edit(lettersAndSpacesFormatter, 'Sam', 'Sa'), 'Sa');
      expect(edit(lastNameFormatter, 'Lee', 'Lee-Park'), 'Lee-Park');
      expect(edit(lastNameFormatter, 'Lee', 'Lee2'), 'Lee');
      expect(edit(lastNameFormatter, '', "O'Neil"), '');
    });

    testWidgets(
        'on the real form: First Name, Last Name, City, each resident, '
        'Address History, Employer, Reference and Emergency Contact',
        (tester) async {
      final raw = _raw()
        ..['address_history'] = [
          {
            'street': '1 Main St',
            'city': 'Dallas',
            'state': 'Texas',
            'zip': '78701-1234',
            'landlord': 'Pat Kim',
            'is_current_address': true,
          }
        ]
        ..['employment_history'] = [
          {'employer': 'Acme Corp', 'is_current_employment': true}
        ]
        ..['personal_references'] = [
          {'name': 'Bob Ray', 'city': 'Houston', 'zip': '78702'}
        ]
        ..['emergency_contacts'] = [
          {'name': 'Kim Ray', 'relationship': 'Friend'}
        ];
      final saved = await _pumpForm(tester, raw);

      // Box showing → [an edit web ignores, an edit web keeps].
      const boxes = {
        'Ann': ['Ann2', 'Anna Mae'], // First Name
        'Lee': ['Lee2', 'Lee-Park'], // Last Name
        'Austin': ['Austin1', 'Round Rock'], // City
        'Sam Lee': ['Sam Lee3', 'Sam Li'], // resident Name
        'Son': ['Son!', 'Grandson'], // resident Relation
        'Dallas': ['Dallas.', 'Plano'], // Address History City
        'Pat Kim': ['Pat Kim7', 'Pat King'], // Landlord Name
        'Acme Corp': ['AT&T', 'Acme Inc'], // Employer Name
        'Bob Ray': ['Bob Ray2', 'Bob Rey'], // Reference Name
        'Houston': ['Houston9', 'Katy'], // Reference City
        'Kim Ray': ['Kim@Ray', 'Kim Rae'], // Emergency Contact Name
        'Friend': ['Friend1', 'Neighbor'], // Relationship to Tenant
      };
      for (final entry in boxes.entries) {
        expect(_box(entry.key), findsOneWidget, reason: entry.key);
        final field = tester.widget<TextField>(_box(entry.key));
        final controller = field.controller!;
        // No autocorrect: iPhone would otherwise swap a word for one with an
        // apostrophe, which the rule rejects, losing the space typed after.
        expect(field.autocorrect, isFalse, reason: entry.key);
        expect(field.enableSuggestions, isFalse, reason: entry.key);
        await tester.enterText(_boxOf(controller), entry.value[0]);
        expect(controller.text, entry.key,
            reason: '"${entry.value[0]}" is ignored');
        await tester.enterText(_boxOf(controller), entry.value[1]);
        expect(controller.text, entry.value[1], reason: entry.value[1]);
      }

      // Other boxes are unchanged: Current Address still takes numbers.
      final street = tester.widget<TextField>(_box('1 Main St').first);
      await tester.enterText(_boxOf(street.controller!), '22 Oak St #5');
      expect(street.controller!.text, '22 Oak St #5');

      await _tapSave(tester);
      expect(saved, hasLength(1));
      expect(saved.single['applicant_firstName'], 'Anna Mae');
      expect(saved.single['applicant_lastName'], 'Lee-Park');
    });
  });
  group('when boxes turn red, like web: after leaving a box or after Save',
      () {
    // An applicant with empty Driver's License State and Number, Current
    // Address, State, Zip Code and Birth Date (like the one QA opened).
    Map<String, dynamic> emptyDetails() => _raw()
      ..['state'] = ''
      ..['driver_license'] = ''
      ..['current_address'] = ''
      ..['applicant_state'] = ''
      ..['applicant_postalCode'] = ''
      ..['applicant_birthDate'] = '';

    const emptyHints = [
      "Enter driver's license number",
      'Enter current address',
      'Zip Code',
    ];

    bool noError(TextField field) =>
        field.decoration?.error == null && field.decoration?.errorText == null;

    bool redBoxOnly(TextField field) {
      final decoration = field.decoration!;
      final error = decoration.error;
      return decoration.errorText == null &&
          error is SizedBox &&
          error.width == 0 &&
          error.height == 0;
    }

    Finder picker(int index) =>
        find.byType(DropdownButtonFormField2<String>).at(index);

    // 0 = Driver's License State, 1 = State.
    InputDecoration pickerDecoration(WidgetTester tester, int index) => tester
        .widget<InputDecorator>(find
            .descendant(of: picker(index), matching: find.byType(InputDecorator))
            .first)
        .decoration;

    // The form's red.
    const errColor = Color(0xFFE2574C);
    bool pickerRed(WidgetTester tester, int index) {
      final border = pickerDecoration(tester, index).enabledBorder;
      return border is OutlineInputBorder && border.borderSide.color == errColor;
    }

    testWidgets('typing in one box turns no other box red', (tester) async {
      final saved = await _pumpForm(tester, emptyDetails());

      await tester.enterText(_box('Austin').first, 'Plano');
      await tester.pumpAndSettle();

      for (final hint in emptyHints) {
        expect(noError(tester.widget<TextField>(_emptyBox(hint))), isTrue,
            reason: hint);
      }
      expect(pickerRed(tester, 0), isFalse);
      expect(pickerRed(tester, 1), isFalse);
      expect(find.text('Date of Birth is required'), findsNothing);
      expect(find.text('Please correct the red boxes above'), findsNothing);
      expect(saved, isEmpty);
    });

    testWidgets(
        'leaving a wrong box turns only that box red, then it follows each '
        'change', (tester) async {
      await _pumpForm(tester, _raw());

      await tester.enterText(_box('D1234567'), 'AB1');
      await tester.pumpAndSettle();
      // Still typing in it: not red yet, like web before the box is left.
      expect(noError(tester.widget<TextField>(_box('AB1'))), isTrue);

      await tester.tap(_box('Austin').first);
      await tester.pumpAndSettle();
      expect(redBoxOnly(tester.widget<TextField>(_box('AB1'))), isTrue);
      expect(noError(tester.widget<TextField>(_box('Austin').first)), isTrue);
      expect(pickerRed(tester, 0), isFalse);
      expect(find.text('Please correct the red boxes above'), findsOneWidget);

      await tester.enterText(_box('AB1'), 'AB12345');
      await tester.pumpAndSettle();
      expect(noError(tester.widget<TextField>(_box('AB12345'))), isTrue);
      expect(find.text('Please correct the red boxes above'), findsNothing);
    });

    testWidgets(
        'Save turns every wrong box and picker red with no message; only '
        'Applicant Birth Date shows one', (tester) async {
      final saved = await _pumpForm(tester, emptyDetails());
      final pickerHeight = tester.getSize(picker(0)).height;
      final boxHeight =
          tester.getSize(_emptyBox("Enter driver's license number")).height;

      await _tapSave(tester);

      expect(saved, isEmpty);
      expect(find.text('Please correct the red boxes above'), findsOneWidget);
      expect(find.text('Date of Birth is required'), findsOneWidget);
      for (final hint in emptyHints) {
        expect(redBoxOnly(tester.widget<TextField>(_emptyBox(hint))), isTrue,
            reason: hint);
      }
      for (final i in [0, 1]) {
        expect(pickerRed(tester, i), isTrue, reason: 'picker $i is red');
        expect(pickerDecoration(tester, i).errorText, isNull,
            reason: 'picker $i: no message');
      }
      for (final message in [
        "Please select Driver's License State",
        'Please select State',
        'Please enter current address',
        "Please enter driver's license number",
        "Driver's License Number is required",
        'Zip Code is required',
      ]) {
        expect(find.text(message), findsNothing, reason: message);
      }
      // Red only: no empty message line under the picker or the box.
      expect(tester.getSize(picker(0)).height, pickerHeight);
      expect(tester.getSize(_emptyBox("Enter driver's license number")).height,
          boxHeight);

      // After Save every box follows each change, like web.
      await tester.enterText(_emptyBox('Enter current address'), '9 Elm St');
      await tester.pumpAndSettle();
      expect(noError(tester.widget<TextField>(_box('9 Elm St'))), isTrue);
      expect(redBoxOnly(tester.widget<TextField>(
              _emptyBox("Enter driver's license number"))),
          isTrue);
      await tester.tap(picker(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alabama').last);
      await tester.pumpAndSettle();
      expect(pickerRed(tester, 1), isFalse);
      expect(pickerRed(tester, 0), isTrue);
    });
  });
}
