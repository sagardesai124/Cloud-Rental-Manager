

class WorkOrder {
  String? workOrderId;
  String? workSubject;
  String? workCategory;
  String? priority;
  String? status;
  bool? isBillable;
  String? createdAt;
  String? updatedAt;
  String? date;
  String? rentalId;
  String? unitId;
  String? rentalAddress;
  String? rentalUnit;
  String? ticketNumber;
  String? staffMemberName;

  WorkOrder({
    this.workOrderId,
    this.workSubject,
    this.workCategory,
    this.priority,
    this.status,
    this.isBillable,
    this.createdAt,
    this.updatedAt,
    this.date,
    this.rentalId,
    this.unitId,
    this.rentalAddress,
    this.rentalUnit,
    this.ticketNumber,
    this.staffMemberName,
  });

  WorkOrder.fromJson(Map<String, dynamic> json) {
   // print(json);
    workOrderId = json['workOrder_id']??"";
    workSubject = json['work_subject']??"";
    workCategory = json['work_category']??"";
    priority = json['priority']??"";
    status = json['status']??"";
    isBillable = json['is_billable'] is bool ? json['is_billable'] as bool : null;
    createdAt = json['createdAt']??"";
    updatedAt = json['updatedAt']??"";
    date = json['date']??"";
    rentalId = json['rental_id']??"";
    unitId = json['unit_id']??"";
    rentalAddress = json['rental_adress']??"";
    rentalUnit = json['rental_unit']??"";
    ticketNumber = json['ticket_number']??"";
    // Kept empty when nobody is assigned; the list shows "-" like web.
    staffMemberName = json['staffmember_name'];
  }
}

/// Property line for the tenant Work Orders list — web parity
/// (TenantWork.jsx makeRentalAddress): "address, unit", the address alone
/// when there is no unit, "-" when there is no address.
String workOrderPropertyLine(WorkOrder w) {
  final address = (w.rentalAddress ?? '').trim();
  if (address.isEmpty) return '-';
  final unit = (w.rentalUnit ?? '').trim();
  return unit.isEmpty ? address : '$address, $unit';
}

/// "Assigned" value for the tenant Work Orders list — web parity
/// (TenantWork.jsx `staffmember_name || "-"`).
String workOrderAssignedLine(WorkOrder w) {
  final name = (w.staffMemberName ?? '').trim();
  return name.isEmpty ? '-' : name;
}
