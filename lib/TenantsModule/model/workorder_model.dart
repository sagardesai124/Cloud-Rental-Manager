

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

/// Status filter for the tenant Work Orders list, in web's order
/// (TenantWork.jsx).
const List<String> tenantWorkOrderStatusOptions = [
  'All',
  'Open',
  'New',
  'In Progress',
  'On Hold',
  'Completed',
  'Over Due',
  'Closed',
];

/// Web's finished statuses (utils/workOrderOverdue.js
/// TERMINAL_WORKORDER_STATUSES): never "Open" and never overdue.
bool isFinishedWorkOrderStatus(String? status) {
  final s = (status ?? '').trim();
  return s == 'Completed' || s == 'Closed';
}

/// The stored due date as a calendar day, or null when it is missing or
/// can't be read (web: workOrderDueDay). Read as a day, never shifted by
/// time zone: "2026-11-15" is the 15th everywhere.
DateTime? workOrderDueDay(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  DateTime? day(int y, int m, int d) {
    final value = DateTime(y, m, d);
    return value.year == y && value.month == m && value.day == d ? value : null;
  }

  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) {
    return day(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
        int.parse(iso.group(3)!));
  }
  final us = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (us != null) {
    return day(int.parse(us.group(3)!), int.parse(us.group(1)!),
        int.parse(us.group(2)!));
  }
  final slash = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(s);
  if (slash != null) {
    return day(int.parse(slash.group(1)!), int.parse(slash.group(2)!),
        int.parse(slash.group(3)!));
  }
  final parsed = DateTime.tryParse(s);
  return parsed == null ? null : day(parsed.year, parsed.month, parsed.day);
}

/// Web's status filter (TenantWork.jsx): "All" (or none) keeps everything,
/// "Open" is everything not Completed or Closed, "Over Due" is due before
/// today and not finished, and any other choice matches the status name.
bool workOrderMatchesStatus(WorkOrder w, String? status,
    {required DateTime today}) {
  if (status == null || status.isEmpty || status == 'All') return true;
  if (status == 'Open') return !isFinishedWorkOrderStatus(w.status);
  if (status == 'Over Due') {
    if (isFinishedWorkOrderStatus(w.status)) return false;
    final due = workOrderDueDay(w.date);
    if (due == null) return false;
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }
  return (w.status ?? '').toLowerCase().contains(status.toLowerCase());
}

/// Web's search box (TenantWork.jsx): any part of the subject, category,
/// status, "address unit", assigned staff, priority or work order number,
/// ignoring upper and lower case.
bool workOrderMatchesSearch(WorkOrder w, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  bool has(String? value) => (value ?? '').toLowerCase().contains(q);
  // Web joins the address and unit with a space; the unit is the
  // rental_unit the server sends.
  return has(w.workSubject) ||
      has(w.workCategory) ||
      has(w.status) ||
      has('${w.rentalAddress ?? ''} ${w.rentalUnit ?? ''}') ||
      has(w.staffMemberName) ||
      has(w.priority) ||
      has(w.ticketNumber);
}

/// The tenant Work Orders list after web's status filter and then its
/// search, the same on the phone and wide layouts.
List<WorkOrder> filterTenantWorkOrders(List<WorkOrder> workOrders,
    {String? status, String search = '', DateTime? today}) {
  final now = today ?? DateTime.now();
  return workOrders
      .where((w) =>
          workOrderMatchesStatus(w, status, today: now) &&
          workOrderMatchesSearch(w, search))
      .toList();
}
