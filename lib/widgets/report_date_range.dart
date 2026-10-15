import 'package:flutter/material.dart';
import 'package:three_zero_two_property/constant/constant.dart';

/// Web's message when a report's From date is after its To date
/// (ExpiringRenterInsurancesReport.jsx, PropertyRevenueReport.jsx and the
/// other date-range reports).
const reportDateRangeMessage =
    'Invalid Date Range: From Date cannot be greater than To Date.';

/// The message for the From/To dates shown on a report, or null when the
/// range is fine. As on web, only two filled, readable dates are checked.
String? reportDateRangeError(String fromShown, String toShown) {
  final from = DateTime.tryParse(reverseFormatDate(fromShown));
  final to = DateTime.tryParse(reverseFormatDate(toShown));
  if (from == null || to == null) return null;
  return from.isAfter(to) ? reportDateRangeMessage : null;
}

/// The red line web shows under a report's From/To fields.
class ReportDateRangeErrorText extends StatelessWidget {
  final String message;
  const ReportDateRangeErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 5, right: 5),
      child: Text(
        message,
        key: const Key('report-date-range-error'),
        style: const TextStyle(
          color: Color(0xFFDC3545),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
