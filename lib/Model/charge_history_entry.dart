/// One entry in a scheduled charge's change history (audit log).
///
/// Backed by `GET /api/charge/scheduled-charges/{task_id}/history`, which
/// returns `{ statusCode, data: [ { action, entity, description, reason, by,
/// at } ] }`. Entries are ordered newest-first by the server.
class ChargeHistoryEntry {
  /// e.g. "UPDATE", "CREATE", "DELETE" (a cancel). May be empty.
  final String action;

  /// Human-readable sentence, e.g. "Updated rent charge: $18 (2032-06-02)".
  final String description;

  /// Optional reason, carried on cancellations.
  final String reason;

  /// Username who made the change, e.g. "Mark Due"; "System" when unknown.
  final String by;

  /// ISO timestamp of the change (server `createdAt`).
  final String at;

  ChargeHistoryEntry({
    required this.action,
    required this.description,
    required this.reason,
    required this.by,
    required this.at,
  });

  factory ChargeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ChargeHistoryEntry(
      action: (json['action'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      by: (json['by'] ?? '').toString(),
      at: (json['at'] ?? '').toString(),
    );
  }
}
