import 'package:intl/intl.dart';
import 'package:three_zero_two_property/Model/lease_renewal_report.dart';
import 'package:three_zero_two_property/services/csv_row.dart';

/// The Lease Renewal CSV, the same as web's (LeaseRenewalReport.jsx
/// generateCSV): a "Leases Ending" section and a "MTM Leases" section (each
/// only when it has rows), web's headers with the rent years from the data,
/// every tenant on the lease, the first note, and [formatDate] (the account
/// date format) for the last increase date.
String buildLeaseRenewalCsv({
  required List<LeaseEnding> leasesEnding,
  required List<MonthToMonthLease> mtmLeases,
  required String Function(String date) formatDate,
}) {
  final money =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  String tenants(List<Tenant> list) {
    final names = list.map((t) => t.tenantName).join(', ');
    return names.isEmpty ? 'N/A' : names;
  }

  String orNo(String value) => value.isEmpty ? 'No' : value;
  String firstNote(List<Note> notes) =>
      notes.isNotEmpty ? notes.first.content : 'No notes';
  String rentYear(int year, String fallback) =>
      '${year != 0 ? year : fallback} Rent';

  final csv = StringBuffer();

  if (leasesEnding.isNotEmpty) {
    final years = leasesEnding.first.rentData;
    csv.writeln('Leases Ending');
    csv.writeln(csvRow([
      'Property',
      'Tenant',
      rentYear(years.year1, 'Year 1'),
      rentYear(years.year2, 'Year 2'),
      'Deposits',
      'New Rent',
      'Includes Trash?',
      'Increase',
      'Times Late',
      'Court Filings',
      'Need Trash Svc?',
      'Notes',
    ]));
    for (final lease in leasesEnding) {
      csv.writeln(csvRow([
        lease.propertyAddress,
        tenants(lease.tenants),
        money.format(lease.rentData.rentYear1),
        money.format(lease.rentData.rentYear2),
        money.format(lease.deposits.totalDeposits),
        money.format(lease.rentData.newRentAmount),
        orNo(lease.rentData.newRentIncludesTrashService),
        money.format(lease.rentData.rentIncrease),
        lease.metrics.timeLateCount,
        lease.metrics.courtFilings,
        orNo(lease.tenantNeedsTrashService),
        firstNote(lease.notes),
      ]));
    }
    csv.writeln();
  }

  if (mtmLeases.isNotEmpty) {
    final years = mtmLeases.first.rentData;
    csv.writeln('MTM Leases');
    csv.writeln(csvRow([
      'Property',
      'Tenant',
      rentYear(years.year1, 'Year 1'),
      rentYear(years.year2, 'Year 2'),
      rentYear(years.year3, 'Year 3'),
      'Last Increase',
      'Sec. Dep.',
      'New Rent',
      'Includes Trash?',
      'Increase',
      'Late',
      'Court',
      'Need Trash Svc?',
      'Notes',
    ]));
    for (final lease in mtmLeases) {
      final lastIncrease = lease.rentData.lastIncreaseDate;
      csv.writeln(csvRow([
        lease.propertyAddress,
        tenants(lease.tenants),
        money.format(lease.rentData.rentYear1),
        money.format(lease.rentData.rentYear2),
        money.format(lease.rentData.rentYear3),
        lastIncrease.isEmpty ? 'N/A' : formatDate(lastIncrease),
        money.format(lease.deposits.totalDeposits),
        money.format(lease.rentData.newRentAmount),
        orNo(lease.rentData.newRentIncludesTrashService),
        money.format(lease.rentData.rentIncrease),
        lease.metrics.timeLateCount,
        lease.metrics.courtFilings,
        orNo(lease.tenantNeedsTrashService),
        firstNote(lease.notes),
      ]));
    }
  }

  return csv.toString();
}
