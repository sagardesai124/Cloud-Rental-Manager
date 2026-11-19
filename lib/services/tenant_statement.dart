/// Tenant Statement letterhead on the lease ledger export (Lease → Financial
/// → Export, Admin and Staff), like web staging (utils/tenantStatement.js,
/// CRM-5247): the company name, address and phone top-left, "Tenant
/// Statement" with the period it covers and "Report Date: <today>" in the
/// middle, the company's logo top-right (its name when there is no usable
/// logo), then the tenant name(s) and the address the statement is about, and
/// the property line above the table. No unit anywhere. The same facts lead
/// the Excel and CSV exports, so all three formats say the same thing.
library;

import 'package:intl/intl.dart';

import 'app_date_format.dart';

String _clean(Object? v) => v == null ? '' : v.toString().trim();

/// A ledger or filter date as a day, read like web's LEDGER_DATE_FORMATS
/// ("YYYY-MM-DD", "MM/DD/YYYY", "M/D/YYYY", ISO 8601), or null.
DateTime? statementDay(String? value) {
  final s = _clean(value);
  if (s.isEmpty) return null;
  for (final pattern in const ['yyyy-MM-dd', 'MM/dd/yyyy', 'M/d/yyyy']) {
    try {
      final d = DateFormat(pattern).parseStrict(s);
      return DateTime(d.year, d.month, d.day);
    } catch (_) {}
  }
  final iso = DateTime.tryParse(s);
  if (iso == null) return null;
  final local = iso.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The period the statement covers, like web's statementDateRange:
/// from = the From filter, else the earliest exported row;
/// to   = the To filter, else the statement date (today).
({DateTime? from, DateTime to}) statementDateRange({
  required Iterable<String?> rowDates,
  String? fromDate,
  String? toDate,
  DateTime? now,
}) {
  final days = rowDates.map(statementDay).whereType<DateTime>().toList()
    ..sort();
  final from = statementDay(fromDate) ?? (days.isEmpty ? null : days.first);
  final today = now ?? DateTime.now();
  final to = statementDay(toDate) ?? DateTime(today.year, today.month, today.day);
  return (from: from, to: to);
}

String _cityStateZip(Object? city, Object? state, Object? zip) {
  final c = _clean(city);
  final sz = [_clean(state), _clean(zip)].where((s) => s.isNotEmpty).join(' ');
  return [c, sz].where((s) => s.isNotEmpty).join(', ');
}

/// Company letterhead lines, like web's companyAddressLines: street,
/// "City, ST ZIP", phone. The mailing address first, the office second.
List<String> companyAddressLines(Map<String, dynamic> company) {
  List<String> pick(String prefix) {
    final street = _clean(company['${prefix}_street']);
    final csz = _cityStateZip(company['${prefix}_city'],
        company['${prefix}_state'], company['${prefix}_zip']);
    if (street.isNotEmpty || csz.isNotEmpty) {
      return [street, csz].where((s) => s.isNotEmpty).toList();
    }
    final single = _clean(company['${prefix}_address']);
    return single.isEmpty ? [] : [single];
  }

  final mailing = pick('mailing');
  final address = mailing.isNotEmpty ? mailing : pick('office');
  final phone = _clean(company['office_phone_number']).isNotEmpty
      ? _clean(company['office_phone_number'])
      : _clean(company['phone_number']);
  return phone.isEmpty ? address : [...address, phone];
}

/// Everything the statement prints above the table, like web's
/// buildTenantStatementHeader.
class TenantStatementHeader {
  const TenantStatementHeader({
    required this.companyName,
    required this.companyLines,
    required this.logo,
    required this.dateRangeText,
    required this.tenantNames,
    required this.mailingLines,
    required this.propertyLine,
    required this.reportDate,
  });

  final String title = 'Tenant Statement';
  final String companyName;
  final List<String> companyLines;

  /// The company's brand logo as stored (a data URI or an http(s) URL).
  final String? logo;
  final String dateRangeText;
  final List<String> tenantNames;
  final List<String> mailingLines;
  final String propertyLine;
  final String reportDate;
}

/// [company] is web's GET /tenantRental/companyName/:admin_id reply,
/// [leaseTenant] the `data` of GET /leases/lease_tenant/:lease_id,
/// [fallbackAddress] the lease's street when [leaseTenant] has none,
/// [rowDates] the exported rows' dates, [fromDate] / [toDate] the tab's
/// filters and [datePattern] the company's date format (intl tokens).
TenantStatementHeader buildTenantStatementHeader({
  Map<String, dynamic> company = const {},
  Map<String, dynamic> leaseTenant = const {},
  String? fallbackAddress,
  Iterable<String?> rowDates = const [],
  String? fromDate,
  String? toDate,
  String? datePattern,
  DateTime? now,
}) {
  final printedAt = now ?? DateTime.now();
  final companyName = _clean(company['company_name']).isNotEmpty
      ? _clean(company['company_name'])
      : _clean(company['company_dba']);

  final tenants = leaseTenant['tenants'];
  final tenantNames = (tenants is List ? tenants : const [])
      .map((t) => t is Map
          ? [_clean(t['tenant_firstName']), _clean(t['tenant_lastName'])]
              .where((s) => s.isNotEmpty)
              .join(' ')
          : '')
      .where((s) => s.isNotEmpty)
      .toList();

  // No unit anywhere on the statement, like web: the street address of the
  // property is what the tenant and a court read.
  final street = _clean(leaseTenant['rental_adress']).isNotEmpty
      ? _clean(leaseTenant['rental_adress'])
      : _clean(fallbackAddress);
  final mailingLines = [
    street,
    _cityStateZip(leaseTenant['rental_city'], leaseTenant['rental_state'],
        leaseTenant['rental_zip']),
  ].where((s) => s.isNotEmpty).toList();

  final range = statementDateRange(
      rowDates: rowDates, fromDate: fromDate, toDate: toDate, now: printedAt);
  String fmt(DateTime? d) => d == null ? '' : AppDateFormat.format(d, datePattern);
  final dateRangeText =
      [fmt(range.from), fmt(range.to)].where((s) => s.isNotEmpty).join(' - ');

  final logo = _clean(company['brand_logo']);
  return TenantStatementHeader(
    companyName: companyName,
    companyLines: companyAddressLines(company),
    logo: logo.isEmpty ? null : logo,
    dateRangeText: dateRangeText,
    tenantNames: tenantNames,
    mailingLines: mailingLines,
    propertyLine: street,
    reportDate: fmt(printedAt),
  );
}

/// The rows that lead the Excel and CSV exports, like web's
/// tenantStatementSheetRows: the same facts, one per row, each followed by a
/// blank row where web has one.
List<List<String>> tenantStatementSheetRows(TenantStatementHeader h) => [
      [h.title],
      if (h.dateRangeText.isNotEmpty) ['Period: ${h.dateRangeText}'],
      if (h.reportDate.isNotEmpty) ['Report Date: ${h.reportDate}'],
      if (h.companyName.isNotEmpty) [h.companyName],
      for (final line in h.companyLines) [line],
      [],
      if (h.tenantNames.isNotEmpty) [h.tenantNames.join(', ')],
      for (final line in h.mailingLines) [line],
      if (h.propertyLine.isNotEmpty) [h.propertyLine],
      [],
    ];

/// [row] padded with empty cells to [width] columns (web's padToTable).
List<String> padStatementRow(List<String> row, int width) =>
    [...row, for (var i = row.length; i < width; i++) ''];

// ── The statement table, like web (LeaseFinancialTab → buildStatementRow) ──

/// The table's columns, like web's statementHead.
const List<String> tenantStatementHead = [
  'Date',
  'Tenant',
  'Type',
  'Description',
  'Charge',
  'Payment',
  'Balance',
];

/// Charge, Payment and Balance: on the right in every format, header too,
/// like web.
const Set<int> tenantStatementMoneyColumns = {4, 5, 6};

final NumberFormat _usd =
    NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);

/// Web's formatLedgerAmountSigned: $1,234.56, negatives in parentheses.
String formatLedgerAmountSigned(num? value) {
  final n = value?.toDouble();
  if (n == null || n.isNaN) return _usd.format(0);
  if (n < 0) return '(${_usd.format(n.abs())})';
  return _usd.format(n);
}

/// The row's date, like web: the first entry's date, else the payment's,
/// else the charge's, else when it was created, in the company's format;
/// "-" when there is none.
String statementDateCell(Iterable<String?> candidates, String? datePattern) {
  String? raw;
  for (final d in candidates) {
    if (d != null && d.isNotEmpty) {
      raw = d;
      break;
    }
  }
  if (raw == null) return '-';
  final day = statementDay(raw);
  if (day == null) return 'Invalid date';
  return AppDateFormat.format(day, datePattern);
}

/// Web's getLedgerExportTenantCell: the tenant's name, "External Source" for
/// a payment with no tenant, otherwise "-".
String statementTenantCell({Object? tenantData, String? type}) {
  if (tenantData != null) {
    final t = tenantData is Map ? tenantData : const {};
    final name =
        '${_clean(t['tenant_firstName'])} ${_clean(t['tenant_lastName'])}'
            .trim();
    return name.isEmpty ? '-' : name;
  }
  if (type == 'Payment') return 'External Source';
  return '-';
}

/// Web's getLedgerExportDescription: "<payment type> <type> <response>
/// <response text>" for a processed payment, else the entries' memos (or
/// their accounts), else "-".
String statementDescription({
  String? type,
  String? response,
  String? paymentType,
  String? responseText,
  List<({String? memo, String? account})> entries = const [],
}) {
  if ((response ?? '').isNotEmpty && (paymentType ?? '').isNotEmpty) {
    return '$paymentType ${type ?? ''} $response ${responseText ?? ''}'.trim();
  }
  final parts = entries
      .map((e) =>
          (e.memo != null && e.memo!.trim().isNotEmpty) ? e.memo : e.account)
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .join(', ');
  return parts.isEmpty ? '-' : parts;
}

/// Web's getLedgerExportChargeCell: the amount of a charge or refund.
String statementChargeCell({String? type, double? totalAmount}) =>
    (type == 'Charge' || type == 'Refund')
        ? formatLedgerAmountSigned(totalAmount ?? 0)
        : '';

/// Web's getLedgerExportPaymentCell: the amount of a payment, blank at zero.
String statementPaymentCell({String? type, double? totalAmount}) {
  if (type != 'Payment') return '';
  final amount = totalAmount ?? 0;
  return amount == 0 ? '' : formatLedgerAmountSigned(amount);
}

/// Web's getLedgerExportBalanceCell.
String statementBalanceCell(double? balance) {
  if (balance == null) return formatLedgerAmountSigned(0);
  if (balance.abs() < 1e-10) return r'$0.00';
  return formatLedgerAmountSigned(balance);
}

/// One row of the table, like web's buildStatementRow.
List<String> tenantStatementRow({
  String? type,
  Object? tenantData,
  String? response,
  String? paymentType,
  String? responseText,
  List<({String? memo, String? account})> entries = const [],
  Iterable<String?> dates = const [],
  double? totalAmount,
  double? balance,
  String? datePattern,
}) =>
    [
      statementDateCell(dates, datePattern),
      statementTenantCell(tenantData: tenantData, type: type),
      (type ?? '').isEmpty ? '-' : type!,
      statementDescription(
          type: type,
          response: response,
          paymentType: paymentType,
          responseText: responseText,
          entries: entries),
      statementChargeCell(type: type, totalAmount: totalAmount),
      statementPaymentCell(type: type, totalAmount: totalAmount),
      statementBalanceCell(balance),
    ];

/// The CSV text, like web: each row as wide as the table, the money columns
/// padded on the left so they line up on the right, every cell quoted, rows
/// joined by a line break.
String tenantStatementCsv(List<List<String>> rows) {
  final width = tenantStatementHead.length;
  final table = [for (final row in rows) padStatementRow(row, width)];
  for (final col in tenantStatementMoneyColumns) {
    var widest = 0;
    for (final row in table) {
      if (row[col].length > widest) widest = row[col].length;
    }
    for (final row in table) {
      row[col] = row[col].padLeft(widest);
    }
  }
  return table
      .map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
      .join('\n');
}
