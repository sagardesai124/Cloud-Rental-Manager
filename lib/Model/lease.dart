import 'dart:convert';

class Lease {
  ChargeData chargeData;
  CosignerData cosignerData;
  LeaseData leaseData;
  List<TenantData> tenantData;

  Lease({
    required this.chargeData,
    required this.cosignerData,
    required this.leaseData,
    required this.tenantData,
  });

  factory Lease.fromJson(Map<String, dynamic> json) {
    return Lease(
      chargeData: ChargeData.fromJson(json['chargeData']),
      cosignerData: CosignerData.fromJson(json['cosignerData']),
      leaseData: LeaseData.fromJson(json['leaseData']),
      tenantData: (json['tenantData'] as List)
          .map((i) => TenantData.fromJson(i))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chargeData': chargeData.toJson(),
      'cosignerData': cosignerData.toJson(),
      'leaseData': leaseData.toJson(),
      'tenantData': tenantData.map((i) => i.toJson()).toList(),
    };
  }
}

class ChargeData {
  String adminId;
  List<Entry> entry;
  bool isLeaseAdded;

  ChargeData({
    required this.adminId,
    required this.entry,
    required this.isLeaseAdded,
  });

  factory ChargeData.fromJson(Map<String, dynamic> json) {
    return ChargeData(
      adminId: json['admin_id'],
      entry: (json['entry'] as List).map((i) => Entry.fromJson(i)).toList(),
      isLeaseAdded: json['is_leaseAdded'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'entry': entry.map((i) => i.toJson()).toList(),
      'is_leaseAdded': isLeaseAdded,
    };
  }
}

class Entry {
  String account;
  double? amount;
  String chargeType;
  String date;
  bool isRepeatable;
  String memo;
  String? rentCycle;
  String? tenantId;
  String? entry_id;

  Entry(
      {required this.account,
      required this.amount,
      required this.chargeType,
      required this.date,
      required this.isRepeatable,
      required this.memo,
      this.rentCycle,
      this.tenantId,
      this.entry_id});

  factory Entry.fromJson(Map<String, dynamic> json) {
    json.forEach((key, value) {
    });
    return Entry(
        account: json['account'],
        amount:
            json['amount'] != null ? (json['amount'] as num).toDouble() : null,
        chargeType: json['charge_type'],
        date: json['date'],
        isRepeatable: json['is_repeatable'] ?? false,
        memo: json['memo'] ?? "",
        rentCycle: json['rent_cycle'],
        tenantId: json['tenant_id'],
        entry_id: json['entry_id']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'account': account,
      'amount': amount,
      'charge_type': chargeType,
      'date': date,
      'is_repeatable': isRepeatable,
      'memo': memo,
      'tenant_id': tenantId,
      'entry_id': entry_id,
      'rent_cycle': rentCycle
    };

    // if (chargeType != "Recurring Charge") {
    //   data['rent_cycle'] = rentCycle;
    // }
    return data;
    // return {
    //   'account': account,
    //   'amount': amount,
    //   'charge_type': chargeType,
    //   'date': date,
    //   'is_repeatable': isRepeatable,
    //   'memo': memo,
    //   'rent_cycle': rentCycle,
    //   'tenant_id': tenantId,
    //   'entry_id':entry_id
    // };
  }
}

class CosignerData {
  String? adminId;
  String? cosignerAddress;
  String? cosignerAlternativeEmail;
  String? cosignerAlternativeNumber;
  String? cosignerCity;
  String? cosignerCountry;
  String? cosignerEmail;
  String? cosignerFirstName;
  String? cosignerId;
  String? cosignerLastName;
  String? cosignerPhoneNumber;
  String? cosignerPostalcode;

  CosignerData({
    this.adminId,
    this.cosignerAddress,
    this.cosignerAlternativeEmail,
    this.cosignerAlternativeNumber,
    this.cosignerCity,
    this.cosignerCountry,
    this.cosignerEmail,
    this.cosignerFirstName,
    this.cosignerId,
    this.cosignerLastName,
    this.cosignerPhoneNumber,
    this.cosignerPostalcode,
  });

  factory CosignerData.fromJson(Map<String, dynamic> json) {
    return CosignerData(
      adminId: json['admin_id'],
      cosignerAddress: json['cosigner_address'],
      cosignerAlternativeEmail: json['cosigner_alternativeEmail'],
      cosignerAlternativeNumber: json['cosigner_alternativeNumber'],
      cosignerCity: json['cosigner_city'],
      cosignerCountry: json['cosigner_country'],
      cosignerEmail: json['cosigner_email'],
      cosignerFirstName: json['cosigner_firstName'],
      cosignerId: json['cosigner_id'],
      cosignerLastName: json['cosigner_lastName'],
      cosignerPhoneNumber: json['cosigner_phoneNumber'],
      cosignerPostalcode: json['cosigner_postalcode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'cosigner_address': cosignerAddress,
      'cosigner_alternativeEmail': cosignerAlternativeEmail,
      'cosigner_alternativeNumber': cosignerAlternativeNumber,
      'cosigner_city': cosignerCity,
      'cosigner_country': cosignerCountry,
      'cosigner_email': cosignerEmail,
      'cosigner_firstName': cosignerFirstName,
      'cosigner_id': cosignerId,
      'cosigner_lastName': cosignerLastName,
      'cosigner_phoneNumber': cosignerPhoneNumber,
      'cosigner_postalcode': cosignerPostalcode,
    };
  }
}

class LeaseData {
  String? leaseId;
  String? adminId;
  String? companyName;
  String? proRatedRent;
  String? endDate;
  List<Entry>? entry;
  String? leaseAmount;
  String? leaseType;
  String? rentalId;
  String? startDate;
  List<String>? tenantId;
  bool? tenantResidentStatus;
  String? unitId;
  String? memo;
  bool? isProRent;
  List<String>? uploadedFile;
  bool? creditCardAccepted;
  bool? debitCardAccepted;
  bool? achAccepted;
  bool? leasePaymentSettings;

  LeaseData({
    this.leaseId,
    this.adminId,
    this.companyName,
    this.proRatedRent,
    this.endDate,
    this.memo,
    this.entry,
    this.leaseAmount,
    this.leaseType,
    this.rentalId,
    this.startDate,
    this.tenantId,
    this.tenantResidentStatus,
    this.unitId,
    this.uploadedFile,
    this.isProRent,
    this.creditCardAccepted,
    this.debitCardAccepted,
    this.achAccepted,
    this.leasePaymentSettings,
  });

  factory LeaseData.fromJson(Map<String, dynamic> json) {
    return LeaseData(
      leaseId: json['lease_id'],
      adminId: json['admin_id'],
      companyName: json['company_name'],
      proRatedRent: json['proRatedRent'],
      memo: json['memo'],
      endDate: json['end_date'],
      entry: (json['entry'] as List).map((i) => Entry.fromJson(i)).toList(),
      leaseAmount: json['lease_amount'],
      leaseType: json['lease_type'],
      rentalId: json['rental_id'],
      startDate: json['start_date'],
      tenantId: List<String>.from(json['tenant_id']),
      tenantResidentStatus: json['tenant_residentStatus'],
      unitId: json['unit_id'],
      isProRent: json['isProRent'],
      uploadedFile: List<String>.from(json['uploaded_file']),
      creditCardAccepted: json['creditCardAccepted'],
      debitCardAccepted: json['debitCardAccepted'],
      achAccepted: json['achAccepted'],
      leasePaymentSettings: json['leasePaymentSettings'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lease_id': leaseId,
      'admin_id': adminId,
      'company_name': companyName,
      'end_date': endDate,
      'entry': entry?.map((i) => i.toJson()).toList(),
      'lease_amount': leaseAmount,
      'lease_type': leaseType,
      'rental_id': rentalId,
      'start_date': startDate,
      'tenant_id': tenantId,
      'tenant_residentStatus': tenantResidentStatus,
      'unit_id': unitId,
      'isProRent': isProRent,
      'proRatedRent': proRatedRent,
      'uploaded_file': uploadedFile,
      'creditCardAccepted': creditCardAccepted,
      'debitCardAccepted': debitCardAccepted,
      'achAccepted': achAccepted,
      'leasePaymentSettings': leasePaymentSettings,
    };
  }
}

// class LeaseData {
//   String? leaseId;
//   String? adminId;
//   String? companyName;
//   String? endDate;
//   List<Entry>? entry;
//   int? leaseAmount;
//   String? leaseType;
//   String? rentalId;
//   String? startDate;
//   List<String>? tenantId;
//   bool? tenantResidentStatus;
//   String? unitId;
//   List<String>? uploadedFile;

//   LeaseData({
//     this.leaseId,
//     this.adminId,
//     this.companyName,
//     this.endDate,
//     this.entry,
//     this.leaseAmount,
//     this.leaseType,
//     this.rentalId,
//     this.startDate,
//     this.tenantId,
//     this.tenantResidentStatus,
//     this.unitId,
//     this.uploadedFile,
//   });

//   factory LeaseData.fromJson(Map<String, dynamic> json) {
//     List<String>? tenantIds = (json['tenant_id'] as List?)?.cast<String>();

//     return LeaseData(
//       leaseId: json['lease_id'],
//       adminId: json['admin_id'],
//       companyName: json['company_name'],
//       endDate: json['end_date'],
//       entry: (json['entry'] as List).map((e) => Entry.fromJson(e)).toList(),
//       leaseAmount: json['lease_amount'],
//       leaseType: json['lease_type'],
//       rentalId: json['rental_id'],
//       startDate: json['start_date'],
//       tenantId: tenantIds,
//       tenantResidentStatus: json['tenant_residentStatus'],
//       unitId: json['unit_id'],
//       uploadedFile: (json['uploaded_file'] as List?)?.cast<String>(),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{
//       'lease_id': leaseId,
//       'admin_id': adminId,
//       'company_name': companyName,
//       'end_date': endDate,
//       'lease_amount': leaseAmount,
//       'lease_type': leaseType,
//       'rental_id': rentalId,
//       'start_date': startDate,
//       'tenant_id': tenantId,
//       'tenant_residentStatus': tenantResidentStatus,
//       'unit_id': unitId,
//       'uploaded_file': uploadedFile,
//     };
//     if (entry != null) {
//       data['entry'] = entry!.map((e) => e.toJson()).toList();
//     }
//     return data;
//   }
// }

class TenantData {
  String? adminId;
  String? comments;
  String? createdAt;
  EmergencyContacts? emergencyContact;
  bool? isDelete;
  String? rentalAddress;
  String? rentalUnit;
  String? taxPayerId;
  String? tenantAlternativeEmail;
  String? tenantAlternativeNumber;
  String? tenantBirthDate;
  String? tenantEmail;
  String? tenantFirstName;
  String? tenant_residentStatus;
  String? tenantId;
  String? tenantLastName;
  String? tenantPassword;
  String? tenantPhoneNumber;
  String? updatedAt;
  String? rentShare;
  int? v;
  String? id;
  bool? sendWelcomeEmail;
  List<EmergencyContacts>? emergencyContactsList;
  bool? enableOverrideFee;
  String? overrideFee;
  bool? allowAch;
  bool? allowCard;
  // Web parity (CRM-4585): new-tenant pets / vehicles (sent only when set).
  List<Map<String, String>>? pets;
  List<Map<String, String>>? vehicles;

  TenantData({
    this.adminId,
    this.comments,
    this.createdAt,
    this.emergencyContact,
    this.isDelete,
    this.rentalAddress,
    this.rentalUnit,
    this.taxPayerId,
    this.tenantAlternativeEmail,
    this.tenantAlternativeNumber,
    this.tenantBirthDate,
    this.tenant_residentStatus,
    this.tenantEmail,
    this.tenantFirstName,
    this.tenantId,
    this.tenantLastName,
    this.tenantPassword,
    this.tenantPhoneNumber,
    this.updatedAt,
    this.rentShare,
    this.v,
    this.id,
    this.sendWelcomeEmail,
    this.emergencyContactsList,
    this.enableOverrideFee,
    this.overrideFee,
    this.allowAch,
    this.allowCard,
    this.pets,
    this.vehicles,
  });

  factory TenantData.fromJson(Map<String, dynamic> json) {
    return TenantData(
      adminId: json['admin_id'],
      comments: json['comments'],
      createdAt: json['createdAt'],
      emergencyContact: EmergencyContacts.fromJson(json['emergency_contact']),
      isDelete: json['is_delete'],
      rentalAddress: json['rental_adress'],
      rentalUnit: json['rental_unit'] ?? "",
      taxPayerId: json['taxPayer_id'],
      tenantAlternativeEmail: json['tenant_alternativeEmail'],
      tenantAlternativeNumber: json['tenant_alternativeNumber'],
      tenantBirthDate: json['tenant_birthDate'],
      tenantEmail: json['tenant_email'],
      tenantFirstName: json['tenant_firstName'],
      tenantId: json['tenant_id'],
      tenantLastName: json['tenant_lastName'],
      tenantPassword: json['tenant_password'],
      tenant_residentStatus: json['tenant_residentStatus'] ?? '',
      tenantPhoneNumber: json['tenant_phoneNumber'],
      updatedAt: json['updatedAt'],
      rentShare: json['percentage']?.toString() ?? "",
      v: json['__v'],
      id: json['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'comments': comments,
      'createdAt': createdAt,
      'emergency_contact': emergencyContact?.toJson(),
      'is_delete': isDelete,
      'rental_adress': rentalAddress,
      'rental_unit': rentalUnit,
      'tenant_alternativeEmail': tenantAlternativeEmail,
      'tenant_alternativeNumber': tenantAlternativeNumber,
      'tenant_birthDate': tenantBirthDate,
      'tenant_email': tenantEmail,
      'tenant_firstName': tenantFirstName,
      'tenant_residentStatus': tenant_residentStatus,
      'tenant_id': tenantId,
      'tenant_lastName': tenantLastName,
      'tenant_phoneNumber': tenantPhoneNumber,
      // Web parity (CRM-4132): send `percentage` as a NUMBER (e.g. 100 / 0),
      // matching web's numeric payload. Falls back to the raw value only if it
      // is non-numeric/empty, so nothing breaks for unexpected inputs.
      'percentage': rentShare == null
          ? null
          : (num.tryParse(rentShare!.trim()) ?? rentShare),
      // Web welcome-email flow: no tenant_password / taxPayer_id sent. A new
      // tenant (empty id) gets a welcome email; an existing one (has id) does not.
      'send_welcome_email': sendWelcomeEmail ?? ((tenantId ?? '').isEmpty),
      // Full-parity extras (emitted only when the submit populates them).
      if (emergencyContactsList != null)
        'emergency_contacts':
            emergencyContactsList!.map((e) => e.toJson()).toList(),
      if (enableOverrideFee != null) 'enable_override_fee': enableOverrideFee,
      if (overrideFee != null) 'override_fee': overrideFee,
      if (allowAch != null) 'allow_ach': allowAch,
      if (allowCard != null) 'allow_card': allowCard,
      if (pets != null) 'pets': pets,
      if (vehicles != null) 'vehicles': vehicles,
    };
  }
}

class EmergencyContacts {
  String? name;
  String? relation;
  String? email;
  String? phoneNumber;

  EmergencyContacts({
    this.name,
    this.relation,
    this.email,
    this.phoneNumber,
  });

  factory EmergencyContacts.fromJson(Map<String, dynamic> json) {
    return EmergencyContacts(
      name: json['name'] ?? "",
      relation: json['relation'] ?? "",
      email: json['email'] ?? "",
      phoneNumber: json['phoneNumber'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relation': relation,
      'email': email,
      'phoneNumber': phoneNumber,
    };
  }
}
