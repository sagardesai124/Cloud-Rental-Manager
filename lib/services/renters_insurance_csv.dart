import 'package:csv/csv.dart';
import 'package:three_zero_two_property/Model/RentarsInsuranceModel.dart';

/// Renter's Insurance → Export → CSV, written the way web writes it: the
/// column row, then one row per policy with the unit, tenant, provider,
/// policy id, `$` followed by the coverage amount exactly as saved (e.g.
/// `$100000`) and both dates in the account's date format. Lines end with
/// `\n`, like web's file.
String buildRentersInsuranceCsv(List<RentersInsuranceData> policies,
    String Function(String date) formatDate) {
  final List<List<dynamic>> rows = [
    [
      'Unit',
      'Tenant',
      'Insurance Provider',
      'Policy ID',
      'Liability Coverage',
      'Effective Date',
      'Expiration Date',
    ],
  ];
  for (final item in policies) {
    final insurance = item.rentersInsurance;
    if (insurance == null) continue;
    rows.add([
      item.unitDetails ?? '',
      item.tenantName ?? '',
      insurance.insuranceCompany ?? '',
      insurance.policyId ?? '',
      _webAmount(insurance.liabilityCoverage),
      insurance.effectiveDate != null
          ? formatDate(insurance.effectiveDate!)
          : '',
      insurance.expirationDate != null
          ? formatDate(insurance.expirationDate!)
          : '',
    ]);
  }
  return const ListToCsvConverter(eol: '\n').convert(rows);
}

/// `$` + the amount as web's template string prints it: a whole number has
/// no decimal part (100000, never 100000.0).
String _webAmount(dynamic amount) {
  if (amount == null) return '';
  if (amount is double && amount == amount.truncateToDouble()) {
    return '\$${amount.toInt()}';
  }
  return '\$$amount';
}
