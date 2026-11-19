import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/history_item_model.dart';
import 'package:three_zero_two_property/enums/history_type.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/services/lease_history_search.dart';
import 'package:three_zero_two_property/widgets/custom_history_table.dart';
import 'package:three_zero_two_property/widgets/dashboard_pagination_footer.dart';

/// Leasing → Leases → lease → Lease History (Admin and Staff), like web
/// staging (RentRollDetail/LeaseSummaryTab.jsx + CommonPagination): a search
/// box ("Search type, action, or description") that matches category, type,
/// action, description as shown, who made the change and the date shown,
/// ignoring case, and starts again at page 1; "No history matches your
/// search" / "No history available for this lease"; page sizes 5–100 or
/// "All" ("Showing all N records"), the size remembered. Other History
/// sections are unchanged. Before, Lease History had no search, a fixed 10
/// rows a page and said "No history data available".

List<Map<String, dynamic>> _rows() => [
      for (var i = 1; i <= 12; i++)
        {
          '_id': 'h$i',
          'date': '2026-11-${'$i'.padLeft(2, '0')}T12:00:00.000Z',
          'category': i == 1 ? 'Payment' : 'Lease',
          'type': 'Lease',
          'action': 'Action A${'$i'.padLeft(2, '0')}',
          'description': i == 2
              ? 'Charge added: \$1000.00 for Rent. Charge Date: 2026-10-09'
              : 'Lease updated',
          'performed_by': i == 3 ? 'Mark Due' : 'Alex Reyy',
        }
    ];

MockClient _server(List<Map<String, dynamic>> leaseRows,
        {Future<void>? gate}) =>
    MockClient((request) async {
      if (gate != null) await gate;
      final path = request.url.path;
      if (path.endsWith('/leases/lease_history/L1')) {
        return http.Response(
            jsonEncode({'statusCode': 200, 'data': leaseRows}), 200);
      }
      if (path.contains('/history/')) {
        return http.Response(
            jsonEncode({
              'statusCode': 200,
              'data': [],
              'pagination': {
                'total': 0,
                'page': 1,
                'limit': 10,
                'totalPages': 1
              }
            }),
            200);
      }
      return http.Response('{}', 404);
    });

Future<void> _settle(WidgetTester tester, [int frames = 15]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpTable(WidgetTester tester,
    {HistoryType type = HistoryType.lease, String id = 'L1'}) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider<DateProvider>(
    create: (_) => DateProvider(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomHistoryTable(
            historyType: type,
            entityId: id,
            title: type == HistoryType.lease ? 'Lease History' : 'History',
            blueColor: const Color(0xFF152B51),
          ),
        ),
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _run(
    List<Map<String, dynamic>> leaseRows, Future<void> Function() body,
    {Future<void>? gate}) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await http.runWithClient(body, () => _server(leaseRows, gate: gate));
  } finally {
    FlutterError.onError = original;
  }
}

Finder get _searchBox => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == leaseHistorySearchHint);

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(_searchBox, text);
  await _settle(tester, 3);
}

Finder _chevron(IconData icon) =>
    find.byWidgetPredicate((w) => w is FaIcon && w.icon == icon);

Future<void> _pickPageSize(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<int>));
  await _settle(tester, 5);
  await tester.tap(find.text(label).last);
  await _settle(tester, 5);
}

HistoryItem _item({
  String category = '',
  String type = '',
  String action = '',
  String description = '',
  String username = '',
}) =>
    HistoryItem(
      id: '1',
      type: type,
      description: description,
      username: username,
      category: category,
      action: action,
      date: '',
      timestamp: 0,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group("web's description formatting (formatDaysInText, formatCurrencyInText)",
      () {
    test('stored days in the app date format; timestamps left alone', () {
      expect(formatDaysInText('Charge Date: 2026-10-09. Next', 'MM/dd/yyyy'),
          'Charge Date: 10/09/2026. Next');
      expect(formatDaysInText('Due 10/9/2026', 'MM/dd/yyyy'), 'Due 10/09/2026');
      expect(formatDaysInText('At 2026-10-09 14:05:00', 'MM/dd/yyyy'),
          'At 2026-10-09 14:05:00');
      expect(formatDaysInText('At 2026-10-09T14:05', 'MM/dd/yyyy'),
          'At 2026-10-09T14:05');
      expect(
          formatDaysInText('Bad 2026-13-45', 'MM/dd/yyyy'), 'Bad 2026-13-45');
    });

    test("a custom format with the day of the year shows as web's moment", () {
      // Web "YYYY-DDD" (day of the year) is "yyyy-ddd" in the app.
      expect(formatDaysInText('Charge Date: 2026-10-09', 'yyyy-ddd'),
          'Charge Date: 2026-282');
    });

    test(r'amounts as $#,###.##, negatives in parentheses', () {
      expect(formatCurrencyInText(r'Amount: $1000.00'), r'Amount: $1,000.00');
      expect(formatCurrencyInText(r'Paid $1000'), r'Paid $1,000.00');
      expect(formatCurrencyInText(r'Credit -$5'), r'Credit ($5.00)');
      expect(formatCurrencyInText(r'Credit $-5.5'), r'Credit ($5.50)');
      expect(formatCurrencyInText(r'Rate $0.0625'), r'Rate $0.0625');
      expect(formatCurrencyInText(r'US$5'), r'US$5');
      expect(formatCurrencyInText(r'Is $1,000.00'), r'Is $1,000.00');
    });
  });

  group("web's filterLeaseHistory", () {
    final item = _item(
      category: 'Payment',
      type: 'Charge',
      action: 'Charge Added',
      description: r'Rent charge of $1000.00 on 2026-10-09',
      username: 'Mark Due',
    );
    bool matches(String q) => leaseHistoryMatches(item, q,
        shownDate: '11/17/2026 10:00 AM', datePattern: 'MM/dd/yyyy');

    test('empty search keeps everything', () => expect(matches(''), isTrue));

    test('category, type, action, who and the date shown, any case', () {
      for (final q in [
        'payment',
        'CHARGE',
        'charge added',
        'mark due',
        '11/17/2026',
      ]) {
        expect(matches(q), isTrue, reason: q);
      }
      expect(matches('zzz'), isFalse);
    });

    test('the description as web shows it', () {
      expect(matches(r'$1,000.00'), isTrue);
      expect(matches('10/09/2026'), isTrue);
      // Web searches the shown text, so the stored "1000.00" doesn't match.
      expect(matches('1000.00'), isFalse);
    });
  });

  group('Lease History on the real table', () {
    testWidgets(
        "search box like web: finds an action, a person, a date and the "
        'description as shown, and starts again at page 1', (tester) async {
      await _run(_rows(), () async {
        await _pumpTable(tester);
        expect(_searchBox, findsOneWidget);
        expect(find.text('Page 1 of 2'), findsOneWidget);

        await tester.tap(_chevron(FontAwesomeIcons.circleChevronRight));
        await _settle(tester, 3);
        expect(find.text('Page 2 of 2'), findsOneWidget);
        expect(find.text('Action A11'), findsOneWidget);

        await _search(tester, 'a07');
        expect(find.text('Action A07'), findsOneWidget);
        expect(find.text('Action A01'), findsNothing);
        expect(find.text('Page 1 of 1'), findsOneWidget);

        await _search(tester, 'MARK DUE');
        expect(find.text('Action A03'), findsOneWidget);
        expect(find.text('Action A07'), findsNothing);

        await _search(tester, r'$1,000.00');
        expect(find.text('Action A02'), findsOneWidget);
        await _search(tester, '10/09/2026');
        expect(find.text('Action A02'), findsOneWidget);

        await _search(tester, '11/05/2026');
        expect(find.text('Action A05'), findsOneWidget);
        expect(find.text('Action A06'), findsNothing);
      });
    });

    testWidgets(
        'no matches: "No history matches your search", keeping the box and '
        'its focus; clearing brings the rows back', (tester) async {
      await _run(_rows(), () async {
        await _pumpTable(tester);
        await _search(tester, 'zzz');

        expect(find.text(leaseHistoryNoMatchMessage), findsOneWidget);
        expect(_searchBox, findsOneWidget);
        expect(
            tester
                .widget<EditableText>(find.descendant(
                    of: _searchBox, matching: find.byType(EditableText)))
                .focusNode
                .hasFocus,
            isTrue);

        await tester.tap(find.byIcon(Icons.close));
        await _settle(tester, 3);
        expect(find.text(leaseHistoryNoMatchMessage), findsNothing);
        expect(find.text('Page 1 of 2'), findsOneWidget);
      });
    });

    testWidgets(
        'page sizes 5 to 100 or "All" ("Showing all N records"); the size is '
        'remembered', (tester) async {
      await _run(_rows(), () async {
        await _pumpTable(tester);
        await _pickPageSize(tester, '5');
        expect(find.text('Page 1 of 3'), findsOneWidget);
        expect(
            (await SharedPreferences.getInstance())
                .getInt(leaseHistoryPageSizeKey),
            5);

        await _pickPageSize(tester, 'All');
        expect(find.text('Showing all 12 records'), findsOneWidget);
        expect(find.textContaining('Page '), findsNothing);
        expect(find.text('Action A12'), findsOneWidget);

        // Opening Lease History again uses the remembered size.
        await tester.pumpWidget(const SizedBox());
        await _pumpTable(tester);
        expect(find.text('Page 1 of 3'), findsOneWidget);
      });
    });

    testWidgets(r'a description shows amounts like web ($1,000.00)',
        (tester) async {
      await _run(_rows(), () async {
        await _pumpTable(tester);
        // Open the second row (Action A02) with its arrow.
        await tester.tap(_chevron(FontAwesomeIcons.sortDown).at(1));
        await _settle(tester, 5);
        expect(find.text('Description :'), findsOneWidget);
        expect(find.textContaining(r'$1,000.00'), findsWidgets);
        expect(find.textContaining(r'$1000.00'), findsNothing);
        expect(
            find.text(
                r'Charge added: $1,000.00 for Rent. Charge Date: 10/09/2026'),
            findsOneWidget);
      });
    });

    testWidgets(
        'a description shows dates exactly as web: a stored day in the app '
        'format, a time stamp left as written, and the search finds it',
        (tester) async {
      await _run([
        {
          '_id': 'h1',
          'date': '2026-11-01T12:00:00.000Z',
          'category': 'Lease',
          'type': 'Lease',
          'action': 'Rent Changed',
          'description':
              r'Rent changed to $1500 at 2026-10-09 14:05. Charge Date: 2026-10-09',
          'performed_by': 'Alex Reyy',
        }
      ], () async {
        await _pumpTable(tester);
        await _search(tester, '2026-10-09 14:05');
        expect(find.text('Rent Changed'), findsOneWidget);

        await tester.tap(_chevron(FontAwesomeIcons.sortDown).first);
        await _settle(tester, 5);
        expect(
            find.text(r'Rent changed to $1,500.00 at 2026-10-09 14:05. '
                'Charge Date: 10/09/2026'),
            findsOneWidget);
      });
    });

    testWidgets(
        'the search box shows while Lease History loads, like web, and a '
        'search typed meanwhile applies once it loads', (tester) async {
      final reply = Completer<void>();
      await _run(_rows(), () async {
        await _pumpTable(tester);
        expect(find.text('Action A01'), findsNothing);
        expect(_searchBox, findsOneWidget);

        await _search(tester, 'a07');
        reply.complete();
        await _settle(tester);
        expect(find.text('Action A07'), findsOneWidget);
        expect(find.text('Action A01'), findsNothing);
        expect(find.text('Page 1 of 1'), findsOneWidget);
      }, gate: reply.future);
    });

    testWidgets("no history at all: web's message, search box still there",
        (tester) async {
      await _run(const [], () async {
        await _pumpTable(tester);
        expect(find.text(leaseHistoryEmptyMessage), findsOneWidget);
        expect(_searchBox, findsOneWidget);
      });
    });

    testWidgets('other History sections are unchanged', (tester) async {
      await _run(const [], () async {
        await _pumpTable(tester, type: HistoryType.tenant, id: 'T1');
        expect(find.text('No history data available'), findsOneWidget);
        expect(_searchBox, findsNothing);
      });
    });
  });

  testWidgets('the shared footer is unchanged without "All"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardPaginationFooter(
          currentPage: 1,
          totalPages: 2,
          rowsPerPage: 10,
          onRowsPerPageChanged: (_) {},
        ),
      ),
    ));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsNothing);
    expect(find.text('Page 1 of 2'), findsOneWidget);
  });

  test('Admin and Staff Lease History use this table', () {
    for (final path in [
      'lib/screens/Leasing/RentalRoll/SummeryPageLease.dart',
      'lib/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('historyType: HistoryType.lease'), reason: path);
      expect(source, contains("title: 'Lease History'"), reason: path);
    }
  });
}
