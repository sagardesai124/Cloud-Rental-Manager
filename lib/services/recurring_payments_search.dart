import 'package:three_zero_two_property/Model/Recurring_Payments_Configuration_model.dart';

/// The Recurring Payments Configuration search, the same as web's
/// (Recurring-Payment-Report/Report.jsx handleSearch): keeps a property when
/// any of its leases matches the address, the unit, a tenant's name, or a
/// recurring payment's day, account or amount. An empty search keeps all.
List<Data> filterRecurringPayments(List<Data> data, String search) {
  final query = search.trim().toLowerCase();
  if (query.isEmpty) return data;

  bool matches(Object? value) =>
      value != null && _webString(value).toLowerCase().contains(query);

  return data.where((property) {
    return (property.leases ?? []).any((lease) =>
        matches(lease.rentalAdress) ||
        matches(lease.rentalUnit) ||
        (lease.tenants ?? []).any((tenant) =>
            matches(tenant.tenantName) ||
            (tenant.recurrings ?? []).any((recurring) =>
                matches(recurring.date) ||
                matches(recurring.account) ||
                matches(recurring.amount))));
  }).toList();
}

/// A value as web prints it: whole amounts without ".0" (100, not 100.0).
String _webString(Object value) {
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
