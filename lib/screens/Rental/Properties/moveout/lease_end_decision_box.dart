import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

import 'lease_end_decision.dart';
import 'moveout_form_ui.dart';

/// The box every move-out form shows when it leaves nobody on a fixed-term
/// lease: does this move-out end the lease (on which date, why), or does the
/// tenant stay responsible through the written term? Same wording as the
/// web's components/moveout/LeaseEndDecision.jsx. Rules: lease_end_decision.dart.
///
/// Dates are shown in the company's date format and kept as yyyy-MM-dd.
class LeaseEndDecisionBox extends StatefulWidget {
  final LeaseEndAnswer value;
  final ValueChanged<LeaseEndAnswer> onChanged;
  final String? leaseStartDate;
  final String? leaseEndDate;
  final Iterable<String?> selectedMoveOutDates;

  const LeaseEndDecisionBox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.leaseStartDate,
    required this.leaseEndDate,
    required this.selectedMoveOutDates,
  });

  @override
  State<LeaseEndDecisionBox> createState() => _LeaseEndDecisionBoxState();
}

class _LeaseEndDecisionBoxState extends State<LeaseEndDecisionBox> {
  static const _border = MoveoutColors.border;
  static const _label = MoveoutColors.text;
  static const _muted = MoveoutColors.muted;

  late final TextEditingController _reasonText =
      TextEditingController(text: widget.value.reasonText);

  @override
  void dispose() {
    _reasonText.dispose();
    super.dispose();
  }

  String _display(String yyyyMMdd) {
    try {
      return Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(yyyyMMdd);
    } catch (_) {
      return yyyyMMdd;
    }
  }

  void _set(LeaseEndAnswer next) => widget.onChanged(next);

  Future<void> _pickDate(String endsOn, String term) async {
    final start = leaseEndNormDate(widget.leaseStartDate);
    final first = start.isNotEmpty ? DateTime.parse(start) : DateTime(2000);
    final last = term.isNotEmpty ? DateTime.parse(term) : DateTime(2101);
    var initial = endsOn.isNotEmpty ? DateTime.parse(endsOn) : DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: blueColor,
            onPrimary: Colors.white,
            onSurface: blueColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    _set(widget.value.copyWith(
        endsOn: leaseEndNormDate(picked.toIso8601String())));
  }

  Widget _choice({
    required bool selected,
    required String label,
    required VoidCallback onTap,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: blueColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _label)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.value;
    final latest = latestMoveOutDate(widget.selectedMoveOutDates);
    final term = leaseEndNormDate(widget.leaseEndDate);
    final termLabel = term.isNotEmpty ? _display(term) : 'the lease end';
    var endsOn = leaseEndNormDate(answer.endsOn);
    if (endsOn.isEmpty) endsOn = latest;
    final endsEarly = term.isNotEmpty && endsOn.isNotEmpty && endsOn != term;

    return Container(
      key: const Key('lease-end-decision'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This move-out leaves no tenant on the lease. Does it end the lease?',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MoveoutColors.title),
          ),
          const SizedBox(height: 4),
          Text(
            'Moving out does not end a lease by itself. The tenant stays '
            'responsible for rent and late fees through $termLabel unless you '
            'end the lease here, for example after an eviction, military '
            'orders, an accepted notice, or a release from a renewal.',
            style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
          ),
          const SizedBox(height: 10),
          _choice(
            key: const Key('lease-end-yes'),
            selected: answer.endsLease == true,
            label: 'Yes, the lease ends on',
            onTap: () =>
                _set(answer.copyWith(endsLease: true, endsOn: endsOn)),
          ),
          if (answer.endsLease == true)
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    key: const Key('lease-end-date'),
                    onTap: () => _pickDate(endsOn, term),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              endsOn.isNotEmpty ? _display(endsOn) : '',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: MoveoutColors.text),
                            ),
                          ),
                          const Icon(Icons.calendar_today_outlined,
                              size: 20, color: MoveoutColors.muted),
                        ],
                      ),
                    ),
                  ),
                  if (endsEarly) ...[
                    const SizedBox(height: 12),
                    Text('Reason the lease ends before $termLabel',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _label)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('lease-end-reason'),
                          isExpanded: true,
                          value: answer.reason,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Choose a reason',
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: _muted)),
                            ),
                            for (final r in leaseEndReasons)
                              DropdownMenuItem(
                                  value: r.value, child: Text(r.label)),
                          ],
                          onChanged: (v) =>
                              _set(answer.copyWith(reason: v ?? '')),
                        ),
                      ),
                    ),
                    if (answer.reason == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('lease-end-reason-text'),
                        controller: _reasonText,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          hintText: 'Why the lease ends early',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            _set(widget.value.copyWith(reasonText: v)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          _choice(
            key: const Key('lease-end-no'),
            selected: answer.endsLease == false,
            label: 'No, the tenant remains responsible through $termLabel',
            onTap: () => _set(answer.copyWith(endsLease: false, endsOn: '')),
          ),
        ],
      ),
    );
  }
}
