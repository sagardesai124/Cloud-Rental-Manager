

import 'dart:developer';

class LeaseLedger {
  List<Data>? data;
  double? totalBalance;
  String? message;
  List<Data>? tenantPayments;
  Map<String, dynamic>? tenantData;

  LeaseLedger({
    this.data,
    this.totalBalance,
    this.message,
    this.tenantPayments,
    this.tenantData,
  });

  LeaseLedger.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = [];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    totalBalance = (json['totalBalance'] as num?)?.toDouble();
    message = json['message'];
    if (json['tenantPayments'] != null) {
      tenantPayments = [];
      json['tenantPayments'].forEach((v) {
        tenantPayments!.add(Data.fromJson(v));
      });
    }
    tenantData = json['tenantData'] as Map<String, dynamic>?;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['totalBalance'] = totalBalance;
    data['message'] = message;
    return data;
  }
}

class Data {
  /// The payment's own date (its first entry's date), which web's refund
  /// modal pre-fills (LeaseFinancialTab: entry[0].date).
  String? get paymentDate =>
      (entry == null || entry!.isEmpty) ? null : entry!.first.date;

  String? sId;
  String? chargeId;
  String? adminId;
  String? leaseId;
  String? response;
  String? paymenttype;
  String? transactionid;
  String? customer_vault_id;
  String? billing_id;
  List<Entry>? entry;
  double? totalAmount; // Adjusted to double
  double? surcharge; // Adjusted to double
  bool? isLeaseAdded;
  String? type;
  List<dynamic>? uploadedFile;
  String? createdAt;
  String? updatedAt;
  bool? isDelete;
  String? paymentId;
  int? iV;
  String? check_number;
  String? reference;
  String? state;
  String? responseText;
  dynamic tenantData; // tenantData is dynamic to handle any JSON structure
  double? balance; // Adjusted to double

  Data({
    this.sId,
    this.chargeId,
    this.adminId,
    this.leaseId,
    this.response,
    this.paymenttype,
    this.transactionid,
    this.entry,
    this.totalAmount,
    this.isLeaseAdded,
    this.type,
    this.uploadedFile,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.iV,
    this.tenantData,
    this.balance,
    this.surcharge,
    this.customer_vault_id,
    this.paymentId,
    this.billing_id,
    this.check_number,
    this.reference,
    this.state,
    this.responseText
  });

  Data.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    chargeId = json['charge_id'];
    adminId = json['admin_id'];
    leaseId = json['lease_id'];
    paymenttype = json['payment_type'];
    response = json['response'];
    transactionid = json['transaction_id'];
    if (json['entry'] != null) {
      entry = [];
      json['entry'].forEach((v) {
        entry!.add(Entry.fromJson(v));
      });
    }
    totalAmount = (json['total_amount'] as num?)?.toDouble(); // Parse as double
    isLeaseAdded = json['is_leaseAdded'];
    type = json['type'];
    // The server's canonical column is `payment_attachment` (Payment.js copies
    // uploaded_file into it on save), and that is what web reads back when it
    // opens a payment for editing. `uploaded_file` is only the request-side
    // name, so read the canonical field first and fall back for older records.
    uploadedFile = json['payment_attachment'] ?? json['uploaded_file'] ?? [];
    createdAt = json['createdAt'];
    surcharge = json['surcharge'] != null
        ? (double.tryParse(json['surcharge'].toString()) ?? 0.0)
        : 0.0; // tryParse: a non-numeric surcharge must not crash ledger rendering

    updatedAt = json['updatedAt'];
    isDelete = json['is_delete'];
    iV = json['__v'];
    paymentId = json['payment_id'];
    tenantData = json['tenantData'];
    check_number = json["check_number"];
    reference = json["reference"];
    state = json["state"]?? "";
    responseText = json["responseText"]??"";
    balance = (json['balance'] as num?)?.toDouble()??0.0; // Parse as double
    // ?.toString() — a record with no saved card must keep these null, not
    // become the literal string "null": every consumer null-checks (?? ""),
    // but "null" passes those checks and gets sent to the payment API as if
    // it were a real gateway vault/billing id (Edit Payment, refund flows).
    // (.toString() never returns null, so the old `?? ""` was dead code.)
    customer_vault_id = json['customer_vault_id']?.toString();
    billing_id = json['billing_id']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['_id'] = sId;
    data['charge_id'] = chargeId;
    data['admin_id'] = adminId;
    data['lease_id'] = leaseId;
    if (entry != null) {
      data['entry'] = entry!.map((v) => v.toJson()).toList();
    }
    data['total_amount'] = totalAmount;
    data['is_leaseAdded'] = isLeaseAdded;
    data['type'] = type;
    if (uploadedFile != null) {
      data['uploaded_file'] = uploadedFile;
    }
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['is_delete'] = isDelete;
    data['__v'] = iV;
    data['tenantData'] = tenantData;
    data['balance'] = balance;
    return data;
  }
}

class Entry {
  String? entryId;
  String? memo;
  String? account;
  double? amount; // Adjusted to double
  String? date;
  String? rentCycle;
  bool? isPaid;
  bool? isLateFee;
  bool? isRepeatable;
  String? chargeType;
  String? sId;

  Entry({
    this.entryId,
    this.memo,
    this.account,
    this.amount,
    this.date,
    this.rentCycle,
    this.isPaid,
    this.isLateFee,
    this.isRepeatable,
    this.chargeType,
    this.sId,
  });

  Entry.fromJson(Map<String, dynamic> json) {
    entryId = json['entry_id'];
    memo = json['memo'];
    account = json['account'];
    amount = (json['amount'] as num?)?.toDouble(); // Parse as double
    date = json['date'];
    rentCycle = json['rent_cycle'];
    isPaid = json['is_paid'];
    isLateFee = json['is_lateFee'];
    isRepeatable = json['is_repeatable'];
    chargeType = json['charge_type'];
    sId = json['_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['entry_id'] = entryId;
    data['memo'] = memo;
    data['account'] = account;
    data['amount'] = amount;
    data['date'] = date;
    data['rent_cycle'] = rentCycle;
    data['is_paid'] = isPaid;
    data['is_lateFee'] = isLateFee;
    data['is_repeatable'] = isRepeatable;
    data['charge_type'] = chargeType;
    data['_id'] = sId;
    return data;
  }
}
