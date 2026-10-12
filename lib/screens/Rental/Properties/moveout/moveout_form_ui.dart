import 'package:flutter/material.dart';

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

/// Cancel / Move Out, side by side, as on web.
class MoveoutActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onMoveOut;
  const MoveoutActions(
      {super.key, required this.onCancel, required this.onMoveOut});

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
            onPressed: onMoveOut,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: MoveoutColors.navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Move Out',
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
