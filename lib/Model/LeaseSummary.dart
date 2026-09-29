import 'dart:developer';

import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/constant/constant.dart';

class LeaseSummary {
  Data? data;
  String? message;

  LeaseSummary({this.data, this.message});

  LeaseSummary.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['message'] = message;
    return data;
  }
}

class Data {
  String? leaseId;
  List<String>? tenantId;
  String? adminId;
  String? rentalId;
  String? unitId;
  String? leaseType;
  bool? isEvicted;
  String? startDate;
  String? endDate;
  String? moveout_date;
  String? moveout_notice_given_date;
  bool? is_renewing;
  List<Tenant>? tenantData;
  String? rentalAddress;
  String? rentalImage;
  String? rentalCity;
  String? rentalCountry;
  String? rentalPostcode;
  String? propertySubType;
  String? rentalUnit;
  String? rentalUnitAddress;
  String? rentalSqft;
  String? rentalOwnerName;
  String? rentalOwnerCompanyName;
  String? rentalOwnerPrimaryEmail;
  String? rentalOwnerPhoneNumber;
  List<RecurringEntry>? entry;
  /// `num?` + asNumN: the API can return this as an int, a decimal or a
  /// numeric string. A raw assignment to `int?` threw on anything but an
  /// int, and because it throws inside fromJson it took the whole list
  /// down, not just the one row.
  num? amount;
  // Web parity (FinancialSummaryCard): the rent row label is driven by
  // rent_cycle ("Weekly Rent", "Monthly Rent"), and Due Date reads N/A
  // when rentDueDate is absent — common on At-will leases.
  String? rentCycle;
  String? rentDueDate;
  String? date;
  List<RenewLeases>? renewLeases;
  Data(
      {this.leaseId,
      this.tenantId,
      this.adminId,
      this.rentalId,
      this.unitId,
      this.leaseType,
      this.isEvicted,
      this.startDate,
      this.endDate,
      this.tenantData,
      this.rentalAddress,
      this.rentalImage,
      this.rentalCity,
      this.rentalCountry,
      this.rentalPostcode,
      this.propertySubType,
      this.rentalUnit,
      this.rentalUnitAddress,
      this.rentalSqft,
      this.rentalOwnerName,
      this.rentalOwnerCompanyName,
      this.rentalOwnerPrimaryEmail,
      this.rentalOwnerPhoneNumber,
      this.amount,
      this.date,
      this.moveout_date,
      this.moveout_notice_given_date,
      this.renewLeases,
      this.entry});

  Data.fromJson(Map<String, dynamic> json) {
    leaseId = json['lease_id'];
    tenantId =
        json['tenant_id'] != null ? List<String>.from(json['tenant_id']) : [];

    adminId = json['admin_id'];
    rentalId = json['rental_id'];
    unitId = json['unit_id'];
    leaseType = json['lease_type'];
    isEvicted = json['is_evicted'] == true;
    startDate = json['start_date'];
    endDate = json['end_date'];
    tenantData = json['tenant_data'] != null
        ? (json['tenant_data'] as List).map((e) => Tenant.fromJson(e)).toList()
        : [];
    rentalAddress = json['rental_adress'];
    rentalImage = json['rental_image'];
    rentalCity = json['rental_city'];
    rentalCountry = json['rental_country'];
    rentalPostcode = json['rental_postcode'];
    propertySubType = json['propertysub_type'];
    rentalUnit = json['rental_unit'];
    rentalUnitAddress = json['rental_unit_adress'];
    rentalSqft = json['rental_sqft'];
    rentalOwnerName = json['rentalOwner_name'];
    rentalOwnerCompanyName = json['rentalOwner_companyName'];
    rentalOwnerPrimaryEmail = json['rentalOwner_primaryEmail'];
    rentalOwnerPhoneNumber = json['rentalOwner_phoneNumber'];
    moveout_notice_given_date = json['moveout_notice_given_date'];
    moveout_date = json['moveout_date'];
    is_renewing = json['is_renewing'];
    if (json['entry'] != null) {
      entry = <RecurringEntry>[];
      json['entry'].forEach((v) {
        entry!.add(new RecurringEntry.fromJson(v));
      });
    }

    amount = asNumN(json['amount']);
    rentCycle = json['rent_cycle'];
    rentDueDate = json['rentDueDate']?.toString();
    date = json['date'];
    if (json['renewLeases'] != null) {
      renewLeases = <RenewLeases>[];
      json['renewLeases'].forEach((v) {
        renewLeases!.add(new RenewLeases.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['lease_id'] = leaseId;
    data['tenant_id'] = tenantId;
    data['admin_id'] = adminId;
    data['rental_id'] = rentalId;
    data['unit_id'] = unitId;
    data['lease_type'] = leaseType;
    data['is_evicted'] = isEvicted;
    data['start_date'] = startDate;
    data['end_date'] = endDate;
    if (tenantData != null) {
      data['tenant_data'] = tenantData!.map((v) => v.toJson()).toList();
    }
    data['rental_address'] = rentalAddress;
    data['rental_image'] = rentalImage;
    data['rental_city'] = rentalCity;
    data['rental_country'] = rentalCountry;
    data['rental_postcode'] = rentalPostcode;
    data['propertysub_type'] = propertySubType;
    data['rental_unit'] = rentalUnit;
    data['rental_unit_address'] = rentalUnitAddress;
    data['rental_sqft'] = rentalSqft;
    data['rentalOwner_name'] = rentalOwnerName;
    data['rentalOwner_companyName'] = rentalOwnerCompanyName;
    data['rentalOwner_primaryEmail'] = rentalOwnerPrimaryEmail;
    data['rentalOwner_phoneNumber'] = rentalOwnerPhoneNumber;
    data['amount'] = amount;
    data['rent_cycle'] = rentCycle;
    data['rentDueDate'] = rentDueDate;
    data['date'] = date;
    if (this.renewLeases != null) {
      data['renewLeases'] = this.renewLeases!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class LeaseTenant {
  String leaseId;
  String tenantId;
  String adminId;
  String rentalId;
  String? moveoutNoticeGivenDate;
  String? moveoutDate;
  String unitId;
  String leaseType;
  String startDate;
  String endDate;
  String tenantFirstName;
  String tenantLastName;
  String tenantPhoneNumber;
  String tenantEmail;
  String rentalAddress;
  String rentalUnit;
  bool? isSelected;
  bool? recurring;

  LeaseTenant({
    required this.leaseId,
    required this.tenantId,
    required this.adminId,
    required this.rentalId,
    this.moveoutNoticeGivenDate,
    this.moveoutDate,
    required this.unitId,
    required this.leaseType,
    required this.startDate,
    required this.endDate,
    required this.tenantFirstName,
    required this.tenantLastName,
    required this.tenantPhoneNumber,
    required this.tenantEmail,
    required this.rentalAddress,
    required this.rentalUnit,
    this.isSelected,
    this.recurring,
  });

  factory LeaseTenant.fromJson(Map<String, dynamic> json) {
    log(json.toString());
    return LeaseTenant(
      leaseId: json['lease_id'],
      tenantId: json['tenant_id'],
      adminId: json['admin_id'],
      rentalId: json['rental_id'],
      moveoutNoticeGivenDate: json['moveout_notice_given_date'] ?? "",
      moveoutDate: json['moveout_date'] ?? "",
      unitId: json['unit_id'] ?? "",
      leaseType: json['lease_type'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      tenantFirstName: json['tenant_firstName'],
      tenantLastName: json['tenant_lastName'],
      tenantPhoneNumber: json['tenant_phoneNumber'] ?? "",
      tenantEmail: json['tenant_email'],
      rentalAddress: json['rental_adress'],
      rentalUnit: json['rental_unit'] ?? "",
      recurring: json['recurring'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lease_id': leaseId,
      'tenant_id': tenantId,
      'admin_id': adminId,
      'rental_id': rentalId,
      'moveout_notice_given_date': moveoutNoticeGivenDate,
      'moveout_date': moveoutDate,
      'unit_id': unitId,
      'lease_type': leaseType,
      'start_date': startDate,
      'end_date': endDate,
      'tenant_firstName': tenantFirstName,
      'tenant_lastName': tenantLastName,
      'tenant_phoneNumber': tenantPhoneNumber,
      'tenant_email': tenantEmail,
      'rental_adress': rentalAddress,
      'rental_unit': rentalUnit,
      'recurring': recurring,
    };
  }
}

class RenewLeases {
  String? sId;
  String? renewId;
  String? leaseId;
  String? adminId;

  String? leaseType;
  String? startDate;
  String? endDate;
  List<String>? renewFileName;
  // String? renewfileName;
  double? amount;
  double? leaseAmount;
  bool? isDelete;
  bool? isrenewed;
  String? createdAt;
  String? updatedAt;
  int? iV;

  RenewLeases(
      {this.sId,
      this.renewId,
      this.leaseId,
      this.adminId,
      this.leaseType,
      this.startDate,
      this.endDate,
      this.renewFileName,
      // this.renewfileName,
      this.amount,
      this.leaseAmount,
      this.isDelete,
      this.isrenewed,
      this.createdAt,
      this.updatedAt,
      this.iV});

  RenewLeases.fromJson(Map<String, dynamic> json) {
    sId = json['_id'] ?? "";
    renewId = json['renew_id'] ?? "";
    // tenantId = json['tenant_id'] != null ? List<String>.from(json['tenant_id']) : [];
    leaseId = json['lease_id'] ?? "";
    adminId = json['admin_id'] ?? "";
    leaseType = json['lease_type'] ?? "";
    startDate = json['start_date'] ?? "";
    // renewFileName = json['renew_fileName'] != null
    // ? List<String>.from(json['renew_fileName'])
    // : [];
    // renewfileName = json['renew_fileName'] ?? "";
    // Handle renew_fileName: if it's a string, convert it to a list.
    if (json['renew_fileName'] != null) {
      if (json['renew_fileName'] is String) {
        renewFileName =
            json['renew_fileName'] == "" ? [] : [json['renew_fileName']];
      } else {
        renewFileName = List<String>.from(json['renew_fileName']);
      }
    } else {
      renewFileName = [];
    }

    endDate = json['end_date'] ?? "";
    // asDouble* (constant.dart): num, numeric string, or null all handled — a
    // string amount from the API can no longer throw on `as num` and crash the
    // Lease Summary screen. Same shared rule the Edit Lease model uses.
    amount = asDoubleN(json['amount']);
    leaseAmount = asDoubleN(json['lease_amount']);
    isDelete = json['is_delete'] ?? false;
    isrenewed = json['is_renewed'] ?? false;
    createdAt = json['createdAt'] ?? "";
    updatedAt = json['updatedAt'] ?? "";
    iV = json['__v'] is int ? json['__v'] as int : int.tryParse('${json['__v'] ?? ''}');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['renew_id'] = this.renewId;
    data['lease_id'] = this.leaseId;
    data['admin_id'] = this.adminId;

    data['lease_type'] = this.leaseType;
    data['start_date'] = this.startDate;
    // data['renew_fileName'] = this.renewFileName;
    // data['renew_fileName'] = this.renewfileName;
    data['renew_fileName'] = this.renewFileName ?? [];
    data['end_date'] = this.endDate;
    data['amount'] = this.amount;
    data['lease_amount'] = this.leaseAmount;
    data['is_delete'] = this.isDelete;
    data['is_renewed'] = this.isrenewed;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['__v'] = this.iV;
    return data;
  }
}

class RecurringEntry {
  String? entryId;
  String? account;
  double? amount;
  String? date;
  String? chargeType;
  String? memo;
  String? sId;

  RecurringEntry(
      {this.entryId,
      this.account,
      this.amount,
      this.date,
      this.chargeType,
      this.memo,
      this.sId});

  RecurringEntry.fromJson(Map<String, dynamic> json) {
    entryId = json['entry_id'];
    account = json['account'];
    // asDoubleN, not `.toDouble()`: the raw call had no null guard, so a
    // missing amount threw NoSuchMethodError — and a string amount threw
    // too. Type stays double?, so every caller is unaffected.
    amount = asDoubleN(json['amount']);
    date = json['date'];
    chargeType = json['charge_type'];
    memo = json['memo'];
    sId = json['_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['entry_id'] = this.entryId;
    data['account'] = this.account;
    data['amount'] = this.amount;
    data['date'] = this.date;
    data['charge_type'] = this.chargeType;
    data['memo'] = this.memo;
    data['_id'] = this.sId;
    return data;
  }
}
