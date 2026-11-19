import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/Model/propertytype.dart';
import 'package:three_zero_two_property/constant/constant.dart';

/// The Add / Edit Property Type popup opened from Add Property and Edit
/// Property (Admin and Staff), like web staging's AddpropertyModal.jsx:
/// a Residential type carries a required Syndication Property Type, each
/// missing field shows web's message under its box, and the pencil next to
/// a type in the list reopens the popup filled in to edit it.

/// One Syndication Property Type choice: the value web saves
/// (`zillow_property_type`) and the label it shows.
class SyndicationOption {
  final String value;
  final String label;
  const SyndicationOption(this.value, this.label);
}

/// Web's single-unit choices.
const List<SyndicationOption> kSingleUnitSyndicationOptions = [
  SyndicationOption('CONDO', 'Condo / Apartment'),
  SyndicationOption('HOUSE', 'House'),
  SyndicationOption('TOWNHOUSE', 'Townhouse'),
];

/// Web's choices when Multi Unit is ticked: the single-unit ones plus the
/// larger multi-unit ones.
const List<SyndicationOption> kMultiUnitSyndicationOptions = [
  ...kSingleUnitSyndicationOptions,
  SyndicationOption('DIVIDED', 'Divided (Duplex/Triplex/Fourplex)'),
  SyndicationOption('MEDIUM', 'Medium (5-49 Units)'),
  SyndicationOption('LARGE', 'Large (50+ Units)'),
  SyndicationOption('COMMUNITY', 'Community / Mobile Home Park'),
];

List<SyndicationOption> syndicationOptionsFor(bool isMultiUnit) =>
    isMultiUnit ? kMultiUnitSyndicationOptions : kSingleUnitSyndicationOptions;

const String kResidential = 'Residential';
const List<String> kPropertyTypeKinds = [kResidential, 'Commercial'];

const String kSyndicationPropertyTypeLabel = 'Syndication Property Type';
const String kSyndicationPropertyTypeHint = 'Select Syndication Property Type';
const String kSyndicationTooltip =
    'Required for residential listings; used for syndication mapping';

// Web's messages (AddpropertyModal.jsx validationSchema).
const String kSelectPropertyTypeMessage = 'Please select property type';
const String kEnterPropertySubTypeMessage = 'Please enter property sub type';
const String kSelectSyndicationTypeMessage =
    'Please select Syndication Property Type';
const String kCorrectRedBoxesMessage = 'Please correct the red boxes above';

/// Web's message for each missing field; null where the field is fine.
class PropertyTypePopupErrors {
  final String? type;
  final String? subType;
  final String? syndication;
  const PropertyTypePopupErrors({this.type, this.subType, this.syndication});
  bool get any => type != null || subType != null || syndication != null;
}

/// Like web: the property type and sub type are always needed; the
/// Syndication Property Type only for a Residential type.
PropertyTypePopupErrors propertyTypePopupErrors({
  required String? type,
  required String subType,
  required String? syndication,
}) =>
    PropertyTypePopupErrors(
      type: (type ?? '').trim().isEmpty ? kSelectPropertyTypeMessage : null,
      subType: subType.trim().isEmpty ? kEnterPropertySubTypeMessage : null,
      syndication: type == kResidential && (syndication ?? '').trim().isEmpty
          ? kSelectSyndicationTypeMessage
          : null,
    );

/// The choice to keep when the type or Multi Unit changes: like web, it is
/// cleared when the type is no longer Residential; it is also cleared when
/// it is no longer offered (a multi-unit choice after unticking Multi Unit),
/// so a hidden value is never saved.
String? keptSyndicationChoice({
  required String? type,
  required bool isMultiUnit,
  required String? current,
}) {
  if (type != kResidential || current == null) return null;
  return syndicationOptionsFor(isMultiUnit).any((o) => o.value == current)
      ? current
      : null;
}

/// What the popup saves.
class PropertyTypePopupValues {
  final String propertyType;
  final String propertySubType;
  final bool isMultiUnit;

  /// Web's `zillow_property_type`: the chosen value for a Residential type,
  /// '' otherwise.
  final String syndicationType;

  const PropertyTypePopupValues({
    required this.propertyType,
    required this.propertySubType,
    required this.isMultiUnit,
    required this.syndicationType,
  });
}

/// Saves the popup's values; throws when the save fails (the popup then
/// stays open, as before).
typedef PropertyTypePopupSave = Future<void> Function(
    PropertyTypePopupValues values);

/// Opens the popup to add a property type, or to edit [editing]. Completes
/// with true once saved.
Future<bool?> showPropertyTypePopup(
  BuildContext context, {
  propertytype? editing,
  required PropertyTypePopupSave onSave,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => PropertyTypePopup(editing: editing, onSave: onSave),
  );
}

class PropertyTypePopup extends StatefulWidget {
  final propertytype? editing;
  final PropertyTypePopupSave onSave;
  const PropertyTypePopup({super.key, this.editing, required this.onSave});

  @override
  State<PropertyTypePopup> createState() => _PropertyTypePopupState();
}

class _PropertyTypePopupState extends State<PropertyTypePopup> {
  String? _type;
  late final TextEditingController _subType;
  bool _multiUnit = false;
  String? _syndication;
  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    // Like web's edit: start from the saved type.
    _type = kPropertyTypeKinds.contains(e?.propertyType) ? e!.propertyType : null;
    _subType = TextEditingController(text: e?.propertysubType ?? '');
    _multiUnit = e?.isMultiunit ?? false;
    final saved = (e?.zillowPropertyType ?? '').trim();
    _syndication = keptSyndicationChoice(
      type: _type,
      isMultiUnit: _multiUnit,
      current: saved.isEmpty ? null : saved,
    );
  }

  @override
  void dispose() {
    _subType.dispose();
    super.dispose();
  }

  PropertyTypePopupErrors get _errors => _submitted
      ? propertyTypePopupErrors(
          type: _type, subType: _subType.text, syndication: _syndication)
      : const PropertyTypePopupErrors();

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (propertyTypePopupErrors(
            type: _type, subType: _subType.text, syndication: _syndication)
        .any) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(PropertyTypePopupValues(
        propertyType: _type!,
        propertySubType: _subType.text.trim(),
        isMultiUnit: _multiUnit,
        syndicationType: _type == kResidential ? (_syndication ?? '') : '',
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text, {Widget? leading}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Flexible(
              child: RichText(
                text: TextSpan(
                  text: text,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: navyClr),
                  children: [
                    TextSpan(
                        text: ' *',
                        style: TextStyle(
                            color: redClr, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _fieldError(String? message) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(message, style: TextStyle(color: redClr, fontSize: 12)),
        );

  Widget _dropdown<T>({
    required String hint,
    required T? value,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
    required bool hasError,
  }) {
    final textStyle =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: navyClr);
    return DropdownButtonHideUnderline(
      child: DropdownButton2<T>(
        isExpanded: true,
        hint: Text(hint,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: mutedClr),
            overflow: TextOverflow.ellipsis),
        items: values
            .map((v) => DropdownMenuItem<T>(
                  value: v,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(labelOf(v),
                        style: textStyle, overflow: TextOverflow.ellipsis),
                  ),
                ))
            .toList(),
        selectedItemBuilder: (context) => values
            .map((v) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(labelOf(v),
                      style: textStyle, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        value: value,
        onChanged: _saving ? null : onChanged,
        buttonStyleData: ButtonStyleData(
          height: 52,
          padding: const EdgeInsets.only(left: 14, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hasError ? redClr : outlineClr),
          ),
        ),
        iconStyleData: IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedClr),
          iconSize: 24,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 44,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errors = _errors;
    final options = syndicationOptionsFor(_multiUnit);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderClr),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editing ? 'Edit Property Type' : 'New Property Type',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: navyClr),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _saving ? null : () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F4F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 20, color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _label('Property Type'),
                _dropdown<String>(
                  hint: 'Select type',
                  value: _type,
                  values: kPropertyTypeKinds,
                  labelOf: (v) => v,
                  hasError: errors.type != null,
                  onChanged: (v) => setState(() {
                    _type = v;
                    // Like web: leaving Residential clears the choice.
                    _syndication = keptSyndicationChoice(
                        type: _type,
                        isMultiUnit: _multiUnit,
                        current: _syndication);
                  }),
                ),
                _fieldError(errors.type),
                const SizedBox(height: 18),
                _label('Property Sub Type'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: errors.subType != null ? redClr : outlineClr),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextFormField(
                    controller: _subType,
                    enabled: !_saving,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: navyClr),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      hintText: 'e.g. Townhome',
                      hintStyle: TextStyle(
                          color: mutedClr,
                          fontWeight: FontWeight.w500,
                          fontSize: 15),
                    ),
                  ),
                ),
                _fieldError(errors.subType),
                const SizedBox(height: 18),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _multiUnit,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                  _multiUnit = v ?? false;
                                  _syndication = keptSyndicationChoice(
                                      type: _type,
                                      isMultiUnit: _multiUnit,
                                      current: _syndication);
                                }),
                        activeColor: navyClr,
                        checkColor: Colors.white,
                        side: BorderSide(color: checkOffClr, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Multi Unit',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: navyClr),
                      ),
                    ),
                  ],
                ),
                // Like web: only a Residential type has one.
                if (_type == kResidential) ...[
                  const SizedBox(height: 18),
                  _label(
                    kSyndicationPropertyTypeLabel,
                    leading: Tooltip(
                      message: kSyndicationTooltip,
                      triggerMode: TooltipTriggerMode.tap,
                      child: Icon(Icons.info_outline,
                          size: 16, color: mutedClr),
                    ),
                  ),
                  _dropdown<String>(
                    hint: kSyndicationPropertyTypeHint,
                    value: _syndication,
                    values: options.map((o) => o.value).toList(),
                    labelOf: (v) =>
                        options.firstWhere((o) => o.value == v).label,
                    hasError: errors.syndication != null,
                    onChanged: (v) => setState(() => _syndication = v),
                  ),
                  _fieldError(errors.syndication),
                ],
                if (errors.any) ...[
                  const SizedBox(height: 14),
                  Text(
                    kCorrectRedBoxesMessage,
                    style: TextStyle(
                        color: redClr,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: outlineClr),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              color: mutedClr,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyClr,
                          disabledBackgroundColor: navyClr.withOpacity(0.6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _editing ? 'Update' : 'Add',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pencil next to a property type in the Add / Edit Property list, like
/// web's "Edit property type" icon: it closes the open list (without
/// choosing the type) and reopens the popup filled in.
class PropertyTypeEditPencil extends StatelessWidget {
  final VoidCallback onEdit;
  const PropertyTypeEditPencil({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Edit property type',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Inside the open list: close it first. Never pop the page itself.
          if (ModalRoute.of(context) is PopupRoute) {
            Navigator.of(context).pop();
          }
          onEdit();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(Icons.edit_outlined, size: 16, color: mutedClr),
        ),
      ),
    );
  }
}
