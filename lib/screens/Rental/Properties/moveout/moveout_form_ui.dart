import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import 'lease_end_decision.dart' show leaseEndNormDate;

/// Shared look of the Move Out Tenants form (lease and property move-out,
/// Admin and Staff, full screen and popup). Visual only — every screen keeps
/// its own selection, date pickers, validation and submit logic and hands
/// them to these widgets. Wording follows the web move-out modal.
class MoveoutColors {
  static const navy = Color(0xFF1C2D4E);
  static const title = Color(0xFF152B51);
  static const text = Color(0xFF1B2436);
  static const muted = Color(0xFF6B7A90);
  static const faint = Color(0xFF94A1B4);
  static const border = Color(0xFFE4E8EF);
  static const pageBg = Color(0xFFF4F6F9);
  static const tint = Color(0xFFEEF3FA);
  static const tintBorder = Color(0xFFDCE6F5);
  static const softBg = Color(0xFFF8FAFC);
  static const disabledBg = Color(0xFFEFF2F6);
  static const blue = Color(0xFF2C72E0);
}

const String moveoutIntroText =
    "Select tenants to move out. If everyone is moving, the lease will end on "
    "the last move-out date. If some tenants are staying, you'll need to renew "
    "the lease. Note: Renters insurance policies will be permanently deleted "
    "upon move-out.";

/// Navy bar at the top of the form.
class MoveoutHeader extends StatelessWidget {
  final String title;
  const MoveoutHeader({super.key, this.title = 'Move Out Tenants'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: MoveoutColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Light-blue note with an info icon.
class MoveoutInfoBanner extends StatelessWidget {
  final String text;
  const MoveoutInfoBanner({super.key, this.text = moveoutIntroText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoveoutColors.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MoveoutColors.tintBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline,
                size: 20, color: MoveoutColors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: MoveoutColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded section card with an optional title.
class MoveoutCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const MoveoutCard({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MoveoutColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: MoveoutColors.title)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Label over value, as in the Property Details card.
class MoveoutLabelValue extends StatelessWidget {
  final String label;
  final String value;
  const MoveoutLabelValue(
      {super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MoveoutColors.muted)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MoveoutColors.text)),
      ],
    );
  }
}

/// Property Details card: address on its own row, lease type and term below.
class MoveoutPropertyDetails extends StatelessWidget {
  final String address;
  final String leaseType;
  final String startEnd;
  const MoveoutPropertyDetails({
    super.key,
    required this.address,
    required this.leaseType,
    required this.startEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MoveoutCard(
      title: 'Property Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoveoutLabelValue(label: 'Address / Unit', value: address),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 4,
                  child: MoveoutLabelValue(
                      label: 'Lease Type', value: leaseType)),
              const SizedBox(width: 12),
              Expanded(
                  flex: 6,
                  child: MoveoutLabelValue(
                      label: 'Start - End', value: startEnd)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tenant in Tenant Details: checkbox + name, then the two date fields.
/// Selected tenants get a navy outline; the others are greyed out.
class MoveoutTenantTile extends StatelessWidget {
  final String name;
  final bool selected;

  /// Null when the tenant cannot be toggled (single-tenant popup).
  final ValueChanged<bool?>? onChanged;
  final Widget noticeField;
  final Widget moveOutField;

  const MoveoutTenantTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onChanged,
    required this.noticeField,
    required this.moveOutField,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: selected ? MoveoutColors.title : MoveoutColors.muted);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: selected ? Colors.white : MoveoutColors.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected ? MoveoutColors.navy : MoveoutColors.border,
            width: selected ? 1.2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: selected,
                  onChanged: onChanged,
                  activeColor: MoveoutColors.navy,
                  side: const BorderSide(color: MoveoutColors.faint, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? MoveoutColors.text
                            : MoveoutColors.muted)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: MoveoutColors.border),
          ),
          Text('Notice Given Date', style: labelStyle),
          const SizedBox(height: 8),
          noticeField,
          const SizedBox(height: 14),
          Text('Move-Out Date', style: labelStyle),
          const SizedBox(height: 8),
          moveOutField,
        ],
      ),
    );
  }
}

/// Box behind a move-out date field (the TextField and its calendar button
/// stay in each screen, with that screen's own picker logic).
BoxDecoration moveoutDateBoxDecoration({required bool enabled}) =>
    BoxDecoration(
      color: enabled ? Colors.white : MoveoutColors.disabledBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: MoveoutColors.border),
    );

TextStyle moveoutDateTextStyle({required bool enabled}) => TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: enabled ? MoveoutColors.text : MoveoutColors.faint,
    );

/// Upload Move-out Documents card; [files] is the picked-file list.
class MoveoutUploadCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget? files;
  const MoveoutUploadCard({super.key, required this.onTap, this.files});

  @override
  Widget build(BuildContext context) {
    return MoveoutCard(
      title: 'Upload Move-out Documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('moveout-upload'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MoveoutColors.softBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MoveoutColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: MoveoutColors.tint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_upload_outlined,
                        color: MoveoutColors.blue),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Click to upload documents',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MoveoutColors.blue)),
                        SizedBox(height: 3),
                        Text('Maximum of 10',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: MoveoutColors.muted)),
                        Text('.pdf, .doc, .docx, .jpg, .jpeg, .png',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: MoveoutColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (files != null) files!,
        ],
      ),
    );
  }
}

/// Web's message when a move-out is sent without a ticked tenant or with a
/// ticked tenant's date left empty (LeaseTenantsTab.jsx handleMoveout,
/// PropDetails.jsx).
const moveoutDatesRequiredMessage =
    '"Notice Given Date" and "Move-Out Date" are required for all selected tenants';

/// Web's check before a move-out is sent: at least one tenant is ticked and
/// every ticked tenant has both dates. One entry per ticked tenant.
bool moveoutDatesMissing(List<String> noticeDates, List<String> moveOutDates) =>
    noticeDates.isEmpty ||
    noticeDates.any((d) => d.trim().isEmpty) ||
    moveOutDates.any((d) => d.trim().isEmpty);

/// The date a move-out date field's calendar opens on: the date the field
/// shows, or today when it is empty or unreadable.
DateTime moveoutPickerInitialDate(String shown) {
  final picked = DateTime.tryParse(reverseFormatDate(shown));
  if (picked == null || picked.year < 2000 || picked.year > 2100) {
    return DateTime.now();
  }
  return picked;
}

/// The days a move-out date field's calendar offers, and the day it opens on.
class MoveoutPickerRange {
  final DateTime first;
  final DateTime last;
  final DateTime initial;
  const MoveoutPickerRange(this.first, this.last, this.initial);
}

/// Web's lease move-out calendars (LeaseTenantsTab / RentRollDetail): Notice
/// Given Date from lease start to lease end, Move-Out Date from the notice
/// date (else lease start) to lease end. A missing or unreadable bound stays
/// open; the calendar opens on the shown date, kept inside the range.
MoveoutPickerRange moveoutPickerRange(String shown,
    {String? minDate, String? maxDate}) {
  DateTime? day(String? d) {
    final parsed = DateTime.tryParse(leaseEndNormDate(d));
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  final last = day(maxDate) ?? DateTime(2101);
  var first = day(minDate) ?? DateTime(2000);
  if (first.isAfter(last)) first = last;
  final opened = moveoutPickerInitialDate(shown);
  var initial = DateTime(opened.year, opened.month, opened.day);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return MoveoutPickerRange(first, last, initial);
}

/// Earliest Move-Out Date on web: the tenant's notice date, else lease start.
/// [noticeShown] is the Notice Given Date field's text.
String? moveoutMinMoveOutDate(String noticeShown, String? leaseStartDate) {
  final notice = noticeShown.trim().isEmpty ? '' : reverseFormatDate(noticeShown);
  return notice.isNotEmpty ? notice : leaseStartDate;
}

bool _hasUnit(String u) =>
    u.isNotEmpty && u != '-' && u != 'null' && u != 'undefined';

/// Address / Unit on the lease move-out, like web makeRentalAddress
/// (plugins/helpers.jsx): "address - unit" when the lease has a unit, the
/// address alone when it has none, and the unit as is when it already holds
/// the address.
String moveoutAddressLine(String? address, String? unit) {
  final a = (address ?? '').trim();
  if (a.isEmpty || a == 'null') return '';
  final u = (unit ?? '').trim();
  if (!_hasUnit(u)) return a;
  if (u.contains(a)) return u;
  return '$a - $u';
}

/// Address / Unit on the property move-out, like web PropDetails: the street
/// line, then "- unit" when the tenant's lease has one.
String moveoutPropertyAddressLine(String? address, String? unit) {
  final street = moveoutStreetLine(address);
  final u = (unit ?? '').trim();
  return _hasUnit(u) ? '$street - $u' : street;
}

/// The street line like web getStreetLine (utils/propertyAddress.js). Older
/// properties stored Google's whole address ("562 E Wheatland Rd,
/// Duncanville, TX 75137, USA") as the street, so the trailing country,
/// "TX 75137" region and the city before it are peeled off. Web's property
/// move-out passes only the stored street (its tenant rows carry no city,
/// state or ZIP), so only those rules apply here.
String moveoutStreetLine(String? address) {
  final raw = (address ?? '').trim();
  if (!raw.contains(',')) return raw;
  final segments = raw.split(',').map((s) => s.trim()).toList();
  while (segments.length > 1 && segments.last.isEmpty) {
    segments.removeLast();
  }
  String norm(String s) =>
      s.toLowerCase().replaceAll('.', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  bool popIf(bool Function(String) test) {
    if (segments.length > 1 && test(segments.last)) {
      segments.removeLast();
      return true;
    }
    return false;
  }

  const countries = {'us', 'usa', 'united states', 'united states of america'};
  final unitMarker = RegExp(
      r'^(#|apt|apartment|unit|suite|ste|fl|floor|bldg|building|rm|room|lot|po box)\b',
      caseSensitive: false);
  popIf((s) => countries.contains(norm(s)));
  final regionStripped =
      popIf((s) => RegExp(r'^[A-Za-z]{2}\s+\d{5}(-\d{4})?$').hasMatch(s));
  popIf((s) =>
      regionStripped &&
      !RegExp(r'^\d').hasMatch(s) &&
      !unitMarker.hasMatch(s));
  return segments.join(', ');
}

/// Cancel / Move Out, side by side, as on web. While [busy] (the move-out is
/// being sent) Move Out shows a spinner and ignores taps.
class MoveoutActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onMoveOut;
  final bool busy;
  const MoveoutActions(
      {super.key,
      required this.onCancel,
      required this.onMoveOut,
      this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: Colors.white,
              side: const BorderSide(color: MoveoutColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MoveoutColors.title)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            key: const Key('moveout-submit'),
            onPressed: busy ? null : onMoveOut,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: MoveoutColors.navy,
              disabledBackgroundColor: MoveoutColors.navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: busy
                ? const SpinKitFadingCircle(color: Colors.white, size: 25.0)
                : const Text('Move Out',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

/// File types the web accepts for move-out documents.
const List<String> moveoutDocumentExtensions = [
  'pdf',
  'doc',
  'docx',
  'jpg',
  'jpeg',
  'png',
];

/// Result of [checkMoveoutDocuments]: which picked files to add (their
/// positions in the picked list) and the messages to show.
class MoveoutDocumentCheck {
  final List<int> accepted;
  final List<String> errors;
  const MoveoutDocumentCheck(this.accepted, this.errors);
}

/// The web's rules for adding move-out documents (RentRollDetail.jsx
/// handleMoveoutFileChange), with the same messages: at most 10 files in
/// total, no file twice, only [moveoutDocumentExtensions], and at most 5 MB
/// each. As on web, a file counts as already added when one with the same
/// name is already picked.
MoveoutDocumentCheck checkMoveoutDocuments({
  required List<String> existingNames,
  required List<String> pickedNames,
  required List<int> pickedSizes,
}) {
  if (pickedNames.length + existingNames.length > 10) {
    return const MoveoutDocumentCheck(
        [], ['Maximum 10 files can be uploaded at once']);
  }
  final accepted = <int>[];
  final errors = <String>[];
  for (var i = 0; i < pickedNames.length; i++) {
    final name = pickedNames[i];
    if (existingNames.contains(name)) {
      errors.add('File "$name" has already been added');
      continue;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final validType = moveoutDocumentExtensions.contains(ext);
    final validSize = pickedSizes[i] <= 5 * 1024 * 1024;
    if (!validType) errors.add('Invalid file type: $name');
    if (!validSize) errors.add('File too large (max 5MB): $name');
    if (validType && validSize) accepted.add(i);
  }
  return MoveoutDocumentCheck(accepted, errors);
}

/// One picked document under the upload card: type icon, file name, remove
/// button and its description.
class MoveoutPickedFileTile extends StatelessWidget {
  final String fileName;
  final VoidCallback onRemove;
  final ValueChanged<String> onDescriptionChanged;

  const MoveoutPickedFileTile({
    super.key,
    required this.fileName,
    required this.onRemove,
    required this.onDescriptionChanged,
  });

  IconData get _icon {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
      return Icons.image_outlined;
    }
    if (ext == 'doc' || ext == 'docx') return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: MoveoutColors.border),
    );
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoveoutColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: MoveoutColors.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 20, color: MoveoutColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MoveoutColors.text),
                ),
              ),
              IconButton(
                key: const Key('moveout-file-remove'),
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close,
                    size: 20, color: MoveoutColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              key: const Key('moveout-file-description'),
              onChanged: onDescriptionChanged,
              style: const TextStyle(fontSize: 14, color: MoveoutColors.text),
              decoration: const InputDecoration(
                hintText: 'Enter description',
                hintStyle: TextStyle(fontSize: 14, color: MoveoutColors.faint),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: MoveoutColors.navy),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Move In confirmation, same as web `handleMoveIn` (LeaseTenantsTab,
/// RentRollDetail, PropDetails): the tenant is moved in only after Confirm.
/// Cancel, the close button or a tap outside leaves the tenant as is.
const moveInConfirmTitle = 'Are you sure?';
const moveInConfirmText = 'Do you want to Move-in this Tenant?';
const moveInSuccessMessage = 'Tenant moved in successfully';

Future<bool> confirmMoveIn(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final confirmed = await Alert(
    context: context,
    type: AlertType.warning,
    title: moveInConfirmTitle,
    desc: moveInConfirmText,
    style: AlertStyle(backgroundColor: Colors.white),
    buttons: [
      DialogButton(
        key: const Key('move-in-cancel'),
        onPressed: () => navigator.pop(false),
        color: Colors.white,
        radius: BorderRadius.circular(8),
        border: Border.all(color: blueColor, width: 1.5),
        child: Text(
          'Cancel',
          style: TextStyle(
              color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      DialogButton(
        key: const Key('move-in-confirm'),
        onPressed: () => navigator.pop(true),
        color: blueColor,
        child: const Text(
          'Confirm',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    ],
  ).show();
  return confirmed == true;
}
