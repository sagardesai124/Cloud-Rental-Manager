import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:three_zero_two_property/constant/constant.dart';

/// Reusable US-state picker that mirrors the web forms, which render State as a
/// select over the 50 US states (`US_STATES_OPTIONS`) and store the full state
/// name as the value. Mobile previously used free-text inputs on these forms,
/// which allowed typos and mixed abbreviation/full-name formats to be saved.
///
/// The widget is controller-backed on purpose: the picked full name is written
/// straight back into the caller's existing [TextEditingController], so every
/// screen's save payload and change-detection keep reading the same field they
/// always did — swapping the widget in requires no change to save logic.
///
/// A previously stored value (which may be an ISO code like "CA" or free text
/// typed before this was a dropdown) is normalised with [canonicalUsStateName]
/// for pre-selection: a known code/name resolves to its full-name option, and
/// anything unrecognised is still shown rather than blanked, matching web's
/// `renderValue`.
class UsStateDropdown extends StatefulWidget {
  final TextEditingController controller;

  /// Placeholder shown when nothing is selected yet.
  final String hintText;

  /// Called after a state is picked (and after [controller] is updated) so the
  /// caller can clear its own validation flag / trigger a rebuild, exactly as
  /// the old field's `onChanged` did.
  final ValueChanged<String>? onChanged;

  /// Outline colour, so a caller can match an error border if it wants to.
  final Color? borderColor;

  final double height;

  const UsStateDropdown({
    Key? key,
    required this.controller,
    this.hintText = 'Select State',
    this.onChanged,
    this.borderColor,
    this.height = 50,
  }) : super(key: key);

  @override
  State<UsStateDropdown> createState() => _UsStateDropdownState();
}

class _UsStateDropdownState extends State<UsStateDropdown> {
  @override
  Widget build(BuildContext context) {
    // Read from the controller on every build so an external update (e.g. an
    // edit screen loading a record asynchronously and then calling setState)
    // is reflected without the caller having to touch this widget.
    final String current = canonicalUsStateName(widget.controller.text);
    final bool isKnown = kUsStateNames.contains(current);

    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.borderColor ?? outlineClr, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: isKnown ? current : null,
          hint: Text(
            current.isEmpty ? widget.hintText : current,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: current.isEmpty ? mutedClr : Colors.black87,
            ),
          ),
          items: kUsStateNames
              .map((state) => DropdownMenuItem<String>(
                    value: state,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        state,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                      ),
                    ),
                  ))
              .toList(),
          selectedItemBuilder: (context) => kUsStateNames
              .map((state) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      state,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => widget.controller.text = value);
            widget.onChanged?.call(value);
          },
          buttonStyleData: ButtonStyleData(
            padding: EdgeInsets.zero,
            height: widget.height,
          ),
          iconStyleData: IconStyleData(
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: blueColor, size: 22),
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight:
                (MediaQuery.sizeOf(context).height * 0.35).clamp(200.0, 320.0),
            elevation: 3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outlineClr),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            height: 42,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
