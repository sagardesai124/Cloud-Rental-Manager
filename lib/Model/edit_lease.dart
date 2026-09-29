import 'package:three_zero_two_property/constant/constant.dart' show asDouble;
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/Model/unit.dart';


import '../repository/unit_data.dart';
import 'RentalOwnersData.dart';

import 'cosigner.dart';
import 'lease.dart';

class LeaseDetails {
  final EditLease lease;
  final List<Tenant>? tenant;
  final List<Cosigner>? cosigner;
  final EditRental rental;
  final unit_lease unitData;
  List? one_charge_data;
  List? rec_charge_data;
  final List<Entry>? rentCharges;
  final List<Entry>? securityCharges;

  LeaseDetails({
    required this.lease,
    required this.tenant,
    required this.rental,
    required this.unitData,
    this.one_charge_data,
    this.rentCharges,
    this.cosigner,
    this.rec_charge_data,
    this.securityCharges,
  });

  factory LeaseDetails.fromJson(Map<String, dynamic> json) {

    return LeaseDetails(

      cosigner: json['cosigner'] != null
          ? (json['cosigner'] as List)
              .map((tenant) => Cosigner.fromJson(tenant))
              .toList()
          : null,
      tenant: json['tenant'] != null
          ? (json['tenant'] as List)
              .map((tenant) => Tenant.fromJson(tenant))
              .toList()
          : null,

      rental: EditRental.fromJson(json['rental']),
      unitData: unit_lease.fromJson(json['unit_data'] ?? {}),
      one_charge_data: json["one_charge_data"] != null ?   json["one_charge_data"]:[],
      rec_charge_data: json['rec_charge_data']!=null ? json['rec_charge_data']:[],
      rentCharges: json['rent_charge_data'] != null
          ? (json['rent_charge_data'] as List<dynamic>)
              .map((charge) => Entry.fromJson(charge as Map<String, dynamic>))
              .toList()
          : [],
      securityCharges: json['security_charge_data'] != null
          ? (json['security_charge_data'] as List<dynamic>)
              .map((charge) => Entry.fromJson(charge as Map<String, dynamic>))
              .toList()
          : [],
      lease: EditLease.fromJson(json['leases']),
    );
  }
}

class EditRental {
  String? id;
  String? rentalId;
  
  String? adminId;
  String? rentalOwnerId;
  String? propertyId;
  String? rentalAddress;
  bool? isRentOn;
  String? rentalCity;
  String? rentalState;
  String? rentalCountry;
  String? rentalPostcode;
  String? rentalImage;
  String? staffMemberId;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  int? v;

  EditRental({
    this.id,
    this.rentalId,
    this.adminId,
    this.rentalOwnerId,
    this.propertyId,
    this.rentalAddress,
    this.isRentOn,
    this.rentalCity,
    this.rentalState,
    this.rentalCountry,
    this.rentalPostcode,
    this.rentalImage,
    this.staffMemberId,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.v,
  });

  factory EditRental.fromJson(Map<String, dynamic> json) {
    json.forEach((key, value) {
    });
    return EditRental(
      id: json['_id'],
      rentalId: json['rental_id'],
      adminId: json['admin_id'],
      rentalOwnerId: json['rentalowner_id'],
      propertyId: json['property_id'],
      rentalAddress: json['rental_adress'],
      isRentOn: json['is_rent_on'],
      rentalCity: json['rental_city'],
      rentalState: json['rental_state'],
      rentalCountry: json['rental_country'],
      rentalPostcode: json['rental_postcode'],
      rentalImage: json['rental_image'],
      staffMemberId: json['staffmember_id'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isDelete: json['is_delete'],
      v: json['__v'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'rental_id': rentalId,
      'admin_id': adminId,
      'rentalowner_id': rentalOwnerId,
      'property_id': propertyId,
      'rental_adress': rentalAddress,
      'is_rent_on': isRentOn,
      'rental_city': rentalCity,
      'rental_state': rentalState,
      'rental_country': rentalCountry,
      'rental_postcode': rentalPostcode,
      'rental_image': rentalImage,
      'staffmember_id': staffMemberId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'is_delete': isDelete,
      '__v': v,
    };
  }
}

class EditLease {
  final String id;
  final String leaseId;
  final List<String> tenantId;
  final String adminId;
  final String rentalId;
  final String unitId;
  final String leaseType;
  final String startDate;
  final String endDate;
  final double leaseAmount;
  final List<dynamic> uploadedFile;
  final List<Entry> entry;
  final String createdAt;
  final String updatedAt;
  final bool? creditCardAccepted;
  final bool? debitCardAccepted;
  final bool? achAccepted;
  final bool? leasePaymentSettings;
  final List<dynamic> moveoutTenant;
  final int v;

  EditLease({
    required this.id,
    required this.leaseId,
    required this.tenantId,
    required this.adminId,
    required this.rentalId,
    required this.unitId,
    required this.leaseType,
    required this.startDate,
    required this.endDate,
    required this.leaseAmount,
    required this.uploadedFile,
    required this.entry,
    required this.createdAt,
    required this.updatedAt,
    this.creditCardAccepted,
    this.debitCardAccepted,
    this.achAccepted,
    this.leasePaymentSettings,
    required this.moveoutTenant,
    required this.v,
  });

  factory EditLease.fromJson(Map<String, dynamic> json) {

    json.forEach((key, value) {
    });


   // print(json["moveout_tenant"] != null);
    // API sometimes sends rental_id / unit_id as lists, and stub applicant
    // leases omit createdAt — parse defensively so prefill never dies.
    String stringOrFirst(dynamic value) {
      if (value is List) {
        return value.isNotEmpty ? value[0].toString() : "";
      }
      return value?.toString() ?? "";
    }

    return EditLease(
      id: json['_id']?.toString() ?? "",
      leaseId: json['lease_id']?.toString() ?? "",
      tenantId: json['tenant_id'] != null ? List<String>.from(json['tenant_id']):[],
      adminId: json['admin_id']?.toString() ?? "",
      rentalId: stringOrFirst(json['rental_id']),
      unitId: stringOrFirst(json['unit_id']),
      leaseType: json['lease_type']?.toString() ?? "",
      startDate: json['start_date']?.toString() ?? "",
      endDate: json['end_date']?.toString() ?? "",
      leaseAmount: asDouble(json['lease_amount']),
      uploadedFile: json['uploaded_file'] != null ? List<dynamic>.from(json['uploaded_file']):[],
      entry: json['entry'] != null ? (json['entry'] as List)
          .map((entry) => Entry.fromJson(entry))
          .toList(): [],
      createdAt: json['createdAt']?.toString() ?? "",
      updatedAt: json['updatedAt']?.toString() ?? "",
      creditCardAccepted: json['creditCardAccepted'],
      debitCardAccepted: json['debitCardAccepted'],
      achAccepted: json['achAccepted'],
      leasePaymentSettings: json['leasePaymentSettings'],
      moveoutTenant: json['moveout_tenant'] != null ?  List<dynamic>.from(json['moveout_tenant']) : [],
      v: json['__v'] is int ? json['__v'] : (int.tryParse('${json['__v']}') ?? 0),
    );
  }
}

// class Entry {
//   final String entryId;
//   final String date;
//   final String chargeType;
//   final String account;
//   final String? rentCycle;
//   final double amount;
//   final String id;
//
//   Entry({
//     required this.entryId,
//     required this.date,
//     required this.chargeType,
//     required this.account,
//     this.rentCycle,
//     required this.amount,
//     required this.id,
//   });
//
//   factory Entry.fromJson(Map<String, dynamic> json) {
//     return Entry(
//       entryId: json['entry_id'],
//       date: json['date'],
//       chargeType: json['charge_type'],
//       account: json['account'],
//       rentCycle: json['rent_cycle'],
//       amount: json['amount'].toDouble(),
//       id: json['_id'],
//     );
//   }
// }
