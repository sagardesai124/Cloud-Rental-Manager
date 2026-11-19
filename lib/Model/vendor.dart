class Vendor {
  String? adminId;
  String? vendorId;
  String? vendorName;
  String? vendorPhoneNumber;
  String? vendorEmail;
  String? vendorPassword;
  String? trade;

  /// Web parity: "This vendor receives 1099 forms" on Add/Edit Vendor.
  /// Server schema defaults it to false, so a vendor created without it was
  /// silently never flagged for 1099 tax reporting.
  bool? is1099;

  // No Tax ID (EIN/SSN), like web staging (CRM-5279): Add/Edit Vendor no
  // longer collects it, so the app never loads or sends `tax_id` and a
  // vendor's stored value is left as it is.

  Vendor({
    this.adminId,
    this.vendorId,

    this.vendorName,
    this.vendorPhoneNumber,
    this.vendorEmail,
    this.vendorPassword,
    this.trade,
    this.is1099,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      adminId: json['admin_id'],
      vendorId: json['vendor_id'],
      vendorName: json['vendor_name'],
      vendorPhoneNumber: json['vendor_phoneNumber']?.toString(),
      vendorEmail: json['vendor_email'],
      vendorPassword: json['vendor_password'],
      trade: json['trade'],
      is1099: json['is_1099'] is bool ? json['is_1099'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'admin_id': adminId,
      'vendor_name': vendorName,
      'vendor_phoneNumber': vendorPhoneNumber,
      'vendor_email': vendorEmail,
      'vendor_password': vendorPassword,
      'trade': trade,
      'is_1099': is1099 ?? false,
    };
  }
}
