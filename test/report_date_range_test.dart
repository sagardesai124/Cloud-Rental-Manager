import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';

/// Reports refuse a From date after the To date with web's message
/// (ExpiringRenterInsurancesReport.jsx / PropertyRevenueReport.jsx).
void main() {
  test('From after To: web message', () {
    expect(reportDateRangeError('2026-10-20', '2026-10-01'),
        'Invalid Date Range: From Date cannot be greater than To Date.');
  });

  test('From before or equal to To: fine', () {
    expect(reportDateRangeError('2026-10-01', '2026-10-20'), isNull);
    expect(reportDateRangeError('2026-10-01', '2026-10-01'), isNull);
  });

  test('company date formats are read correctly', () {
    expect(reportDateRangeError('10/20/2026', '10/01/2026'), isNotNull);
    expect(reportDateRangeError('10/01/2026', '10/20/2026'), isNull);
  });

  test('an empty date is not checked, like web', () {
    expect(reportDateRangeError('', '2026-10-01'), isNull);
    expect(reportDateRangeError('2026-10-20', ''), isNull);
  });
}
