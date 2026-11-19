class ScheduledCharges {
  String? taskId;
  String? actionDate;
  String? account;
  String? chargeType;
  String? description;
  double amount;
  String? leaseId;
  String? rentalId;
  String? rentalAddress;
  String? taskType;
  /// "Weekly" / "Monthly" — the lease list sends it; the all-charges list
  /// does not, so [frequency] falls back to [taskType] like web.
  String? rentCycle;
  /// Sent by the lease list; null on the all-charges list.
  bool? isRecurring;

  ScheduledCharges({
    this.taskId,
    this.actionDate,
    this.account,
    this.chargeType,
    this.description,
    double? amount,
    this.leaseId,
    this.rentalId,
    this.rentalAddress,
    this.taskType,
    this.rentCycle,
    this.isRecurring,
  }) : amount = amount ?? 0.0;

  ScheduledCharges.fromJson(Map<String, dynamic> json)
      : taskId = json['task_id'],
        actionDate = json['action_date'],
        account = json['account'],
        chargeType = json['charge_type'],
        description = json['description'],
        amount = (json['amount'] is int)
            ? (json['amount'] as int).toDouble()
            : (json['amount'] is String)
            ? double.tryParse(json['amount']) ?? 0.0
            : (json['amount'] is double)
            ? json['amount']
            : 0.0,
        leaseId = json['lease_id'],
        rentalId = json['rental_id'],
        rentalAddress = json['rental_address'],
        taskType = json['task_type'],
        rentCycle = json['rent_cycle']?.toString(),
        isRecurring = json['is_recurring'] is bool ? json['is_recurring'] : null;

  /// Same as web staging's Manage Charges: `rent_cycle === "Weekly"` → Weekly,
  /// a WEEKLY_CHARGE task → Weekly, otherwise Monthly.
  String get frequency {
    if (rentCycle != null && rentCycle!.isNotEmpty) {
      return rentCycle == 'Weekly' ? 'Weekly' : 'Monthly';
    }
    return taskType == 'WEEKLY_CHARGE' ? 'Weekly' : 'Monthly';
  }

  /// Same as web staging: use `is_recurring` when sent, else a
  /// MONTHLY_CHARGE / WEEKLY_CHARGE task, else a Rent / Recurring Charge type.
  bool get recurring {
    if (isRecurring != null) return isRecurring!;
    if (taskType == 'MONTHLY_CHARGE' || taskType == 'WEEKLY_CHARGE') return true;
    return chargeType == 'Rent' || chargeType == 'Recurring Charge';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    data['task_id'] = taskId;
    data['action_date'] = actionDate;
    data['account'] = account;
    data['charge_type'] = chargeType;
    data['description'] = description;
    data['amount'] = amount;
    data['lease_id'] = leaseId;
    data['rental_id'] = rentalId;
    data['rental_address'] = rentalAddress;
    data['task_type'] = taskType;
    data['rent_cycle'] = rentCycle;
    data['is_recurring'] = isRecurring;
    return data;
  }
}
