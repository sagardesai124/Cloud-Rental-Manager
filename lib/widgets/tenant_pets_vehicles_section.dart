// Pets + Vehicles sections for the tenant form (web parity, CRM-4218
// follow-up / CRM-4585). Mirrors web's shared TenantForm
// (Client/src/components/TenantForm/TenantFormFields.jsx + tenantFormConfig.js):
//
//  * Both sections sit between Emergency Contacts and Payment Settings.
//  * Optional and repeatable — "Add Pet" / "Add Vehicle" appends a blank row,
//    each row ("Pet #N" / "Vehicle #N") has its own remove button.
//  * No validation: empty / partial rows never block a save. Web trims and the
//    server drops fully-blank rows; mobile drops them before sending, which
//    lands on the same stored result.
//  * Payload keys match the Tenant sub-schema exactly:
//      pets:     { name, type, breed, color, weight, height, age, sex, neutered, declawed }
//      vehicles: { make_model, year, color, license_plate, state }
//    All values are strings. Vehicle `state` stores the full state NAME.
//
// Shared by every live tenant form: Admin + Staff Add Tenant, Admin + Staff
// Edit Tenant, and the lease flow's AddTenantCosignerScreen.

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

import 'package:three_zero_two_property/constant/constant.dart';
// Flag-driven CustomTextField used by the rest of the tenant form.
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart'
    show CustomTextField;

/// One field of a pet / vehicle row. [options] null => free-text input.
class TenantSubdocField {
  final String key;
  final String label;
  final List<String>? options;
  const TenantSubdocField(this.key, this.label, [this.options]);
}

/// Web `pets[]` row fields, in web order.
const List<TenantSubdocField> kTenantPetFields = [
  TenantSubdocField('name', 'Pet Name'),
  TenantSubdocField('type', 'Type'),
  TenantSubdocField('breed', 'Breed'),
  TenantSubdocField('color', 'Color'),
  TenantSubdocField('weight', 'Weight (lbs)'),
  TenantSubdocField('height', 'Full Grown Height'),
  TenantSubdocField('age', 'Age'),
  TenantSubdocField('sex', 'Sex', ['Male', 'Female']),
  TenantSubdocField('neutered', 'Spayed / Neutered', ['Yes', 'No']),
  TenantSubdocField('declawed', 'Declawed', ['Yes', 'No']),
];

/// Web `vehicles[]` row fields, in web order. State = US state full names.
const List<TenantSubdocField> kTenantVehicleFields = [
  TenantSubdocField('make_model', 'Make / Model'),
  TenantSubdocField('year', 'Year'),
  TenantSubdocField('color', 'Color'),
  TenantSubdocField('license_plate', 'License Plate'),
  TenantSubdocField('state', 'State', kUsStateNames),
];

/// Holds the input state for one pet or vehicle row.
class TenantSubdocRow {
  final List<TenantSubdocField> fields;
  final Map<String, TextEditingController> text = {};
  final Map<String, String> select = {};

  TenantSubdocRow(this.fields, [Map? initial]) {
    for (final f in fields) {
      final v = (initial?[f.key] ?? '').toString();
      if (f.options == null) {
        text[f.key] = TextEditingController(text: v);
      } else {
        select[f.key] = v;
      }
    }
  }

  TenantSubdocRow.pet([Map? initial]) : this(kTenantPetFields, initial);
  TenantSubdocRow.vehicle([Map? initial]) : this(kTenantVehicleFields, initial);

  /// Trimmed row, keyed exactly like the Tenant sub-schema.
  Map<String, String> toJson() => {
        for (final f in fields)
          f.key: f.options == null
              ? text[f.key]!.text.trim()
              : (select[f.key] ?? '').trim(),
      };

  bool get isBlank => toJson().values.every((v) => v.isEmpty);

  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
  }
}

/// Payload array for `pets` / `vehicles`: trimmed rows, fully-blank rows
/// dropped (same result as web's server-side normalize).
List<Map<String, String>> tenantSubdocPayload(List<TenantSubdocRow> rows) =>
    rows.where((r) => !r.isBlank).map((r) => r.toJson()).toList();

/// Parse a server `pets` / `vehicles` array into editable rows.
List<TenantSubdocRow> tenantSubdocRowsFromJson(
    dynamic raw, List<TenantSubdocField> fields) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((m) => TenantSubdocRow(fields, m))
      .where((r) => !r.isBlank)
      .toList();
}

/// A "Pets" or "Vehicles" card. The host owns [rows] (and disposes them);
/// [onChanged] must call the host's setState.
class TenantSubdocSection extends StatelessWidget {
  final String title;
  final String addLabel;
  final String emptyText;
  final String itemTitle;
  final List<TenantSubdocRow> rows;
  final TenantSubdocRow Function() newRow;
  final VoidCallback onChanged;

  const TenantSubdocSection({
    super.key,
    required this.title,
    required this.addLabel,
    required this.emptyText,
    required this.itemTitle,
    required this.rows,
    required this.newRow,
    required this.onChanged,
  });

  factory TenantSubdocSection.pets({
    required List<TenantSubdocRow> rows,
    required VoidCallback onChanged,
  }) =>
      TenantSubdocSection(
        title: 'Pets',
        addLabel: 'Add Pet',
        emptyText:
            'No pets added. Tap "Add Pet" to capture Pet Addendum details.',
        itemTitle: 'Pet',
        rows: rows,
        newRow: TenantSubdocRow.pet,
        onChanged: onChanged,
      );

  factory TenantSubdocSection.vehicles({
    required List<TenantSubdocRow> rows,
    required VoidCallback onChanged,
  }) =>
      TenantSubdocSection(
        title: 'Vehicles',
        addLabel: 'Add Vehicle',
        emptyText: 'No vehicles added. Tap "Add Vehicle" to capture Vehicle '
            'Registration / Parking details.',
        itemTitle: 'Vehicle',
        rows: rows,
        newRow: TenantSubdocRow.vehicle,
        onChanged: onChanged,
      );

  void _remove(int index) {
    final row = rows.removeAt(index);
    onChanged();
    // Dispose after the frame so the removed card's fields detach first.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  @override
  Widget build(BuildContext context) {
    // Same card as the host forms' _sectionCard.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navyClr,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  rows.add(newRow());
                  onChanged();
                },
                icon: Icon(Icons.add_circle_outline, size: 18, color: navyClr),
                label: Text(
                  addLabel,
                  style:
                      TextStyle(color: navyClr, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: outlineClr),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: pageBg,
                border: Border.all(color: borderClr),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: mutedClr,
                  fontSize: 13,
                ),
              ),
            )
          else
            ...List.generate(rows.length, (i) => _rowCard(i)),
        ],
      ),
    );
  }

  Widget _rowCard(int index) {
    final row = rows[index];
    return Container(
      // Keyed by the row object so removing a middle row never shifts
      // another row's inputs into the removed card's state.
      key: ObjectKey(row),
      margin: EdgeInsets.only(bottom: index == rows.length - 1 ? 0 : 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pageBg,
        border: Border.all(color: borderClr),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$itemTitle #${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyClr,
                  fontSize: 14,
                ),
              ),
              Semantics(
                label: 'Remove ${itemTitle.toLowerCase()} ${index + 1}',
                button: true,
                child: InkWell(
                  onTap: () => _remove(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: redClr.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.delete_outline, color: redClr, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Web lays fields out xs=6 (2-up); keep phones single-column like
          // the Emergency Contacts cards and go 2-up on wider screens.
          LayoutBuilder(builder: (context, c) {
            final twoUp = c.maxWidth >= 440;
            final w = twoUp ? (c.maxWidth - 14) / 2 : c.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final f in row.fields)
                  SizedBox(width: w, child: _field(row, f)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _field(TenantSubdocRow row, TenantSubdocField f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            f.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: navyClr,
            ),
          ),
        ),
        if (f.options == null)
          CustomTextField(
            hintText: 'Enter ${f.label.toLowerCase()}',
            controller: row.text[f.key],
            optional: true,
            showElevation: false,
            borderColor: outlineClr,
            borderWidth: 1,
          )
        else
          _dropdown(row, f),
      ],
    );
  }

  Widget _dropdown(TenantSubdocRow row, TenantSubdocField f) {
    final current = row.select[f.key] ?? '';
    final isState = f.key == 'state';
    // Web keeps a saved value that isn't in the list selectable, so opening
    // the form never silently blanks it.
    final values = <String>[
      '',
      if (current.isNotEmpty && !f.options!.contains(current)) current,
      ...f.options!,
    ];
    final placeholder = isState ? 'Select state' : 'Select';
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        value: current,
        items: values
            .map((v) => DropdownMenuItem<String>(
                  value: v,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      v.isEmpty ? placeholder : v,
                      style: TextStyle(
                        fontSize: 14,
                        color: v.isEmpty
                            ? const Color(0xFFb0b6c3)
                            : Colors.black87,
                      ),
                    ),
                  ),
                ))
            .toList(),
        selectedItemBuilder: (context) => values
            .map((v) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    v.isEmpty ? placeholder : v,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: v.isEmpty ? 13 : 14,
                      color: v.isEmpty
                          ? const Color(0xFFb0b6c3)
                          : Colors.black87,
                    ),
                  ),
                ))
            .toList(),
        onChanged: (v) {
          row.select[f.key] = v ?? '';
          onChanged();
        },
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.only(left: 16, right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: outlineClr),
          ),
        ),
        iconStyleData: IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: navyClr, size: 22),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: isState ? 320 : null,
          elevation: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            border: Border.all(color: borderClr),
          ),
        ),
        // Zero so the closed value lines up with the text inputs; rows get
        // their inset from the Padding inside each item.
        menuItemStyleData: const MenuItemStyleData(
          height: 42,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
