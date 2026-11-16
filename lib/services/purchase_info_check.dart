/// Property → Purchase Information, like web staging (PropDetails.jsx
/// handlePurchaseInfoSave).

/// Web's message when Save is tapped with every field empty.
const String purchaseInfoEmptyMessage = 'Please fill in at least one field.';

/// Web's message when Save is tapped without changing anything.
const String purchaseInfoNoChangesMessage = 'No changes to save.';

/// What the Purchase Price box shows for a saved price, like web's edit
/// window (`purchase_price || ""`): empty when there is none (or 0, which
/// the property page also shows as "N/A"), and a whole price without ".0"
/// (1500, not 1500.0).
String purchasePriceBoxText(num? price) {
  if (price == null || price == 0) return '';
  if (price % 1 == 0) return price.toInt().toString();
  return price.toString();
}

/// The typed price as a number, or null when the box is empty (or holds
/// only "."), which means no price.
double? _typedPrice(String text) => double.tryParse(text.trim());

/// The Purchase Price to send. An empty box stays empty, as web sends it
/// (the server then keeps no price); before, the app sent 0, which the
/// Mortgage report shows as "$0.00".
Object purchasePriceForSave(String text) => _typedPrice(text) ?? '';

/// A saved date as yyyy-MM-dd, the way web compares it
/// (`String(date).split("T")[0]`); empty when there is none.
String _savedDay(String? saved) {
  final s = (saved ?? '').trim();
  if (s.isEmpty || s == 'N/A') return '';
  final day = s.split('T').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return day;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return s;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)}';
}

/// null when the purchase information can be saved, otherwise web's
/// message. Like web, at least one of Purchase Date, Purchase Price and
/// Parcel Number must be filled in, and something must differ from what is
/// saved; either way the edit window stays open.
///
/// [date] is the chosen date as yyyy-MM-dd ('' when none). The price is
/// compared as a number, so an empty box matches no saved price.
String? purchaseInfoSaveProblem({
  required String date,
  required String price,
  required String parcel,
  String? savedDate,
  num? savedPrice,
  String? savedParcel,
}) {
  final newDate = date.trim();
  final newPrice = _typedPrice(price);
  final newParcel = parcel.trim();
  if (newDate.isEmpty && newPrice == null && newParcel.isEmpty) {
    return purchaseInfoEmptyMessage;
  }
  final unchanged = newDate == _savedDay(savedDate) &&
      newPrice == savedPrice?.toDouble() &&
      newParcel == (savedParcel ?? '').trim();
  return unchanged ? purchaseInfoNoChangesMessage : null;
}
