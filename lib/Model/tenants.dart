import 'package:flutter/material.dart';
import 'package:three_zero_two_property/constant/constant.dart';

class TenantResponse {
  int? statusCode;
  List<Tenant>? data;

  TenantResponse({this.statusCode, this.data});

  TenantResponse.fromJson(Map<String, dynamic> json) {
    statusCode = json['statusCode'];
    if (json['data'] != null) {
      data = <Tenant>[];
      json['data'].forEach((v) {
        data!.add(Tenant.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['statusCode'] = statusCode;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Tenant {
  String? id;
  String? tenantId;
  String? applicantId;
  String? adminId;
  String? tenantFirstName;
  String? tenantLastName;
  String? tenantPhoneNumber;
  String? tenantAlternativeNumber;
  String? tenantEmail;
  String? tenantAlternativeEmail;
  String? tenantPassword;
  String? tenantBirthDate;
  bool? tenant_residentStatus;
  String? taxPayerId;
  bool? tenantResidentStatus;
  TextEditingController? rentShareController;
  String? comments;
  EmergencyContact? emergencyContact;
  List<EmergencyContactItem>? emergencyContacts;
  List<TenantLeaseData>? leaseData; // Changed to match JSON field name
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? v;
  String? rentalAddress;
  String? rentalUnit;
  dynamic? rentshare;
  bool? enableoverrideFee;
  double? overRideFee;
  bool? allowAch;
  bool? allowCard;
  String? welcomeEmailSentAt;
  String? passwordSetAt;
  bool? hasPassword;
  // Web parity (TenantsTable.js): drives the row's Enable/Disable 2FA action.
  bool twoFactorEnabled = false;
  // Welcome-email flow (replaces the password field) — captured from
  // AddTenantCosignerScreen; matches the web lease dialog.
  bool? sendWelcomeEmail;
  // Web parity (CRM-4585): pets / vehicles captured by AddTenantCosignerScreen
  // for a NEW tenant, forwarded on the lease payload. Not parsed in fromJson —
  // an existing tenant keeps its stored arrays untouched.
  List<Map<String, String>>? pets;
  List<Map<String, String>>? vehicles;

  Tenant({
    this.id,
    this.tenantId,
    this.applicantId,
    this.adminId,
    this.tenantFirstName,
    this.tenantLastName,
    this.tenantPhoneNumber,
    this.tenantAlternativeNumber,
    this.tenantEmail,
    this.tenantAlternativeEmail,
    this.tenantPassword,
    this.tenantBirthDate,
    this.taxPayerId,
    this.tenantResidentStatus,
    this.comments,
    this.rentshare,
    this.emergencyContact,
    this.emergencyContacts,
    this.tenant_residentStatus,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.v,
    this.rentalAddress,
    this.rentalUnit,
    this.rentShareController,
    this.leaseData,
    this.enableoverrideFee,
    this.overRideFee,
    this.allowAch,
    this.allowCard,
    this.sendWelcomeEmail,
    this.pets,
    this.vehicles,
  }); // Added leaseData

  Tenant.fromJson(Map<String, dynamic> json) {
    tenantId = json['tenant_id'];
    applicantId = json['applicant_id'];
    tenantResidentStatus = json['tenant_residentStatus'];
    adminId = json['admin_id'];
    tenantFirstName = json['tenant_firstName'].toString();
    tenantLastName = json['tenant_lastName'].toString();
    tenantPhoneNumber = json['tenant_phoneNumber'].toString();
    tenantAlternativeNumber = json['tenant_alternativeNumber'].toString();
    tenantEmail = json['tenant_email'].toString();
    tenantAlternativeEmail = json['tenant_alternativeEmail'].toString();
    tenantPassword = json['tenant_password'];
    tenantBirthDate = json['tenant_birthDate'];
    taxPayerId = json['taxPayer_id'];
    comments = json['comments'];
    rentshare = json['percentage'] ?? "";
    emergencyContact = json['emergency_contact'] != null
        ? EmergencyContact.fromJson(json['emergency_contact'])
        : null;
    if (json['emergency_contacts'] != null) {
      emergencyContacts = <EmergencyContactItem>[];
      for (var v in json['emergency_contacts']) {
        if (v is Map<String, dynamic>) {
          emergencyContacts!.add(EmergencyContactItem.fromJson(v));
        }
      }
    }
    final createdRaw = json['createdAt']?.toString() ?? '';
    createdAt = createdRaw.isEmpty
        ? (json['updatedAt']?.toString())
        : createdRaw;
    updatedAt = json['updatedAt'];
    rentalAddress = json['rental_adress'] ?? '';

    rentalUnit = json['rental_unit'];
    overRideFee = json['override_fee'] != null
        ? double.tryParse(json['override_fee'].toString())
        : null;
    enableoverrideFee = json['enable_override_fee'];
    allowAch = json['allow_ach'];
    allowCard = json['allow_card'];
    welcomeEmailSentAt = json['welcome_email_sent_at']?.toString();
    passwordSetAt = json['password_set_at']?.toString();
    hasPassword = json['has_password'] == true ||
        (json['tenant_password'] != null &&
            json['tenant_password'].toString().isNotEmpty);
    twoFactorEnabled = json['two_factor_enabled'] == true;
    if (json['leaseData'] != null) {
      // Fixed the field name
      leaseData = <TenantLeaseData>[];
      json['leaseData'].forEach((v) {
        leaseData!.add(TenantLeaseData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = id;
    data['tenant_id'] = tenantId;
    data['applicant_id'] = applicantId;
    data['admin_id'] = adminId;
    data['tenant_residentStatus'] = tenantResidentStatus;
    data['tenant_firstName'] = tenantFirstName;
    data['tenant_lastName'] = tenantLastName;
    data['tenant_phoneNumber'] = tenantPhoneNumber;
    data['tenant_alternativeNumber'] = tenantAlternativeNumber;
    data['tenant_email'] = tenantEmail;
    data['tenant_alternativeEmail'] = tenantAlternativeEmail;
    data['tenant_password'] = tenantPassword;
    data['tenant_birthDate'] = tenantBirthDate;
    data['taxPayer_id'] = taxPayerId;
    data['comments'] = comments;
    if (emergencyContact != null) {
      data['emergency_contact'] = emergencyContact!.toJson();
    }
    if (emergencyContacts != null) {
      data['emergency_contacts'] =
          emergencyContacts!.map((e) => e.toJson()).toList();
    }
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['rental_adress'] = rentalAddress;
    data['override_fee'] = overRideFee;
    data['enable_override_fee'] = enableoverrideFee;
    data['allow_ach'] = allowAch;
    data['allow_card'] = allowCard;
    data['rental_unit'] = rentalUnit;
    if (leaseData != null) {
      data['leaseData'] =
          leaseData!.map((v) => v.toJson()).toList(); // Fixed the field name
    }
    return data;
  }
}

class EmergencyContact {
  String? name;
  String? relation;
  String? email;
  String? phoneNumber;

  EmergencyContact({this.name, this.relation, this.email, this.phoneNumber});

  EmergencyContact.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? "";
    relation = json['relation'] ?? "";
    email = json['email'] ?? "";
    phoneNumber = json['phoneNumber'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['relation'] = relation;
    data['email'] = email;
    data['phoneNumber'] = phoneNumber;
    return data;
  }
}

/// Single item in the emergency_contacts array (from API).
class EmergencyContactItem {
  String? contactId;
  String? name;
  String? relation;
  String? email;
  String? phoneNumber;

  EmergencyContactItem({
    this.contactId,
    this.name,
    this.relation,
    this.email,
    this.phoneNumber,
  });

  EmergencyContactItem.fromJson(Map<String, dynamic> json) {
    contactId = json['contact_id']?.toString();
    name = json['name'] ?? "";
    relation = json['relation'] ?? "";
    email = json['email'] ?? "";
    phoneNumber = json['phoneNumber']?.toString() ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['contact_id'] = contactId;
    data['name'] = name;
    data['relation'] = relation;
    data['email'] = email;
    data['phoneNumber'] = phoneNumber;
    return data;
  }
}

/// Merged row for display: legacy (emergency_contact) + emergency_contacts.
class MergedEmergencyContact {
  final String contactId;
  final String name;
  final String relation;
  final String email;
  final String phoneNumber;
  final bool isLegacy;

  MergedEmergencyContact({
    required this.contactId,
    required this.name,
    required this.relation,
    required this.email,
    required this.phoneNumber,
    required this.isLegacy,
  });
}

/// Combine old (emergency_contact) + new (emergency_contacts) for display.
/// Single record gets contact_id "primary" so edit can target the right API.
List<MergedEmergencyContact> getCombinedEmergencyContacts(Tenant? tenant) {
  final list = <MergedEmergencyContact>[];
  if (tenant == null) return list;

  final ec = tenant.emergencyContact;
  final hasLegacy = ec != null &&
      ((ec.name ?? '').isNotEmpty ||
          (ec.relation ?? '').isNotEmpty ||
          (ec.email ?? '').isNotEmpty ||
          (ec.phoneNumber ?? '').isNotEmpty);
  if (hasLegacy) {
    list.add(MergedEmergencyContact(
      contactId: 'primary',
      name: ec.name ?? '',
      relation: ec.relation ?? '',
      email: ec.email ?? '',
      phoneNumber: ec.phoneNumber ?? '',
      isLegacy: true,
    ));
  }

  for (var c in tenant.emergencyContacts ?? []) {
    if (c.contactId != null && c.contactId!.isNotEmpty) {
      list.add(MergedEmergencyContact(
        contactId: c.contactId!,
        name: c.name ?? '',
        relation: c.relation ?? '',
        email: c.email ?? '',
        phoneNumber: c.phoneNumber ?? '',
        isLegacy: false,
      ));
    }
  }
  return list;
}

class TenantLeaseData {
  String? leaseId;
  String? startDate;
  String? endDate;
  String? leaseType;
  String? rentalId;
  String? rentalAdress;
  String? rentalownerId;
  String? unitId;
  String? rentalUnit;
  /// `num?` + asNumN: the API can return this as an int, a decimal or a
  /// numeric string. A raw assignment to `int?` threw on anything but an
  /// int, and because it throws inside fromJson it took the whole list
  /// down, not just the one row.
  num? rentAmount;

  TenantLeaseData(
      {this.leaseId,
      this.startDate,
      this.endDate,
      this.leaseType,
      this.rentalId,
      this.rentalAdress,
      this.rentalownerId,
      this.unitId,
      this.rentalUnit,
      this.rentAmount});

  TenantLeaseData.fromJson(Map<String, dynamic> json) {
    leaseId = json['lease_id'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    leaseType = json['lease_type'];
    rentalId = json['rental_id'];
    rentalAdress = json['rental_adress'];
    rentalownerId = json['rentalowner_id'];
    unitId = json['unit_id'];
    rentalUnit = json['rental_unit'];
    rentAmount = asNumN(json['rent_amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['lease_id'] = leaseId;
    data['start_date'] = startDate;
    data['end_date'] = endDate;
    data['lease_type'] = leaseType;
    data['rental_id'] = rentalId;
    data['rental_adress'] = rentalAdress;
    data['rentalowner_id'] = rentalownerId;
    data['unit_id'] = unitId;
    data['rental_unit'] = rentalUnit;
    data['rent_amount'] = rentAmount;
    return data;
  }
}
