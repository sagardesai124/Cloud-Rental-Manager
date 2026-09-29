import 'package:three_zero_two_property/constant/constant.dart' show asDoubleN;

class tenant_lease {
  String? sId;
  String? leaseId;
  List<String>? tenantId;
  String? adminId;
  String? rentalId;
  String? unitId;
  String? leaseType;
  String? startDate;
  String? endDate;
  double? leaseAmount;
  List<String>? uploadedFile;
  List<Entry>? entry;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  List<Null>? moveoutTenant;
  int? iV;
  String? rentalAdress;
  String? rentCycle;
  String? rentDuedate;
  double? deposite;
  double? recurringCharge;

  tenant_lease(
      {this.sId,
      this.leaseId,
      this.tenantId,
      this.adminId,
      this.rentalId,
      this.unitId,
      this.leaseType,
      this.startDate,
      this.endDate,
      this.leaseAmount,
      this.uploadedFile,
      this.entry,
      this.createdAt,
      this.updatedAt,
      this.isDelete,
      this.moveoutTenant,
      this.iV,
      this.rentalAdress,
      this.rentCycle,
      this.rentDuedate,
      this.deposite,
      this.recurringCharge});

  tenant_lease.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    leaseId = json['lease_id'];
    tenantId = json['tenant_id'] != null
        ? (json['tenant_id'] as List).cast<String>()
        : <String>[];
    adminId = json['admin_id'];
    rentalId = json['rental_id'];
    unitId = json['unit_id'];
    leaseType = json['lease_type'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    leaseAmount = asDoubleN(json['lease_amount']);
    uploadedFile = json['uploaded_file'] != null
        ? (json['uploaded_file'] as List).cast<String>()
        : <String>[];
    if (json['entry'] != null) {
      entry = <Entry>[];
      json['entry'].forEach((v) {
        entry!.add(new Entry.fromJson(v));
      });
    }
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    isDelete = json['is_delete'];

    iV = json['__v'];
    rentalAdress = json['rental_adress'];
    rentCycle = json['rent_cycle'];
    rentDuedate = json['rent_duedate'];
    deposite =
        json['deposite'] != null ? (json['deposite'] as num).toDouble() : null;
    recurringCharge = json['recurringCharge'] != null
        ? (json['recurringCharge'] as num).toDouble()
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['lease_id'] = this.leaseId;
    data['tenant_id'] = this.tenantId;
    data['admin_id'] = this.adminId;
    data['rental_id'] = this.rentalId;
    data['unit_id'] = this.unitId;
    data['lease_type'] = this.leaseType;
    data['start_date'] = this.startDate;
    data['end_date'] = this.endDate;
    data['lease_amount'] = this.leaseAmount;
    data['uploaded_file'] = this.uploadedFile;
    if (this.entry != null) {
      data['entry'] = this.entry!.map((v) => v.toJson()).toList();
    }
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['is_delete'] = this.isDelete;

    data['__v'] = this.iV;
    data['rental_adress'] = this.rentalAdress;
    data['rent_cycle'] = this.rentCycle;
    data['rent_duedate'] = this.rentDuedate;
    data['deposite'] = this.deposite;
    data['recurringCharge'] = this.recurringCharge;
    return data;
  }
}

class Entry {
  String? entryId;
  String? date;
  String? chargeType;
  String? account;
  String? rentCycle;
  double? amount;
  String? sId;

  Entry(
      {this.entryId,
      this.date,
      this.chargeType,
      this.account,
      this.rentCycle,
      this.amount,
      this.sId});

  Entry.fromJson(Map<String, dynamic> json) {
    entryId = json['entry_id'];
    date = json['date'];
    chargeType = json['charge_type'];
    account = json['account'];
    rentCycle = json['rent_cycle'];
    amount = json['amount'] != null ? (json['amount'] as num).toDouble() : null;
    sId = json['_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['entry_id'] = this.entryId;
    data['date'] = this.date;
    data['charge_type'] = this.chargeType;
    data['account'] = this.account;
    data['rent_cycle'] = this.rentCycle;
    data['amount'] = this.amount;
    data['_id'] = this.sId;
    return data;
  }
}
