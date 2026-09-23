import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/property_type_image_field.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../Model/propertytype.dart';
import '../../repository/Property_type.dart';
import '../../widgets/custom_drawer.dart';

class Edit_property_type extends StatefulWidget {
  propertytype property;
  Edit_property_type({super.key, required this.property});

  @override
  State<Edit_property_type> createState() => _Edit_property_typeState();
}

class _Edit_property_typeState extends State<Edit_property_type> {
  List<String> months = ['Residential', "Commercial"];
  final List<String> items = [
    'Residential',
    "Commercial",
  ];

  String? initialPropertyType;
  String? initialPropertySubType;
  bool? initialIsMultiUnit;
  String? initialPropertyTypeImage;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.property.propertyType;
    subtype.text = widget.property.propertysubType!;
    isChecked = widget.property.isMultiunit!;

    initialPropertyType = widget.property.propertyType;
    initialPropertySubType = widget.property.propertysubType!;
    initialIsMultiUnit = widget.property.isMultiunit!;
    propertyTypeImage = widget.property.propertyTypeImage ?? '';
    initialPropertyTypeImage = propertyTypeImage;
  }

  bool isLoading = false;
  String? selectedValue;
  bool isChecked = false;
  String propertyTypeImage = '';
  String selectedMonth = 'Residential';
  TextEditingController subtype = TextEditingController();

  @override
  void dispose() {
    subtype.dispose();
    super.dispose();
  }

  bool iserror = false;

  /// Unchanged from the previous layout: same change detection, same
  /// validation, same repository call and the same local model write-back.
  /// Only the surrounding presentation was rebuilt.
  Future<void> _submit() async {
    bool hasChanges = selectedValue != initialPropertyType ||
        subtype.text != initialPropertySubType ||
        isChecked != initialIsMultiUnit ||
        propertyTypeImage != initialPropertyTypeImage;

    if (selectedValue == null || subtype.text.trim().isEmpty) {
      setState(() {
        iserror = true;
      });
    } else if (hasChanges) {
      setState(() {
        isLoading = true;
        iserror = false;
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      PropertyTypeRepository()
          .EditPropertyType(
              adminId: id!,
              propertyType: selectedValue,
              propertySubType: subtype.text.trim(),
              isMultiUnit: isChecked,
              id: widget.property.propertyId,
              propertyTypeImage: propertyTypeImage)
          .then((value) {
        setState(() {
          widget.property.propertyType = selectedValue;
          widget.property.propertysubType = subtype.text;
          widget.property.adminId = id;
          widget.property.isMultiunit = isChecked;
          widget.property.propertyTypeImage = propertyTypeImage;
          widget.property.propertyId = widget.property.propertyId;
          isLoading = false;
        });
        Navigator.of(context).pop(true);
      }).catchError((e) {
        setState(() {
          isLoading = false;
        });
      });
    } else {
      Fluttertoast.showToast(
        msg: "Please update at least one field before submitting.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.red,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: pageBg,
      drawer: CustomDrawer(
        currentpage: "Property Type",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBar(
                  width: double.infinity,
                  radius: 14,
                  title: 'Edit Property Type',
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  title: 'Property Type Details',
                  children: [
                    _fieldLabel('Property Type', required: true),
                    _typeDropdown(),
                    const SizedBox(height: 18),
                    _fieldLabel('Property Sub Type', required: true),
                    _subTypeField(),
                    const SizedBox(height: 18),
                    _checkRow(
                      value: isChecked,
                      onChanged: (value) {
                        setState(() {
                          isChecked = value ?? false;
                        });
                      },
                      label: Text(
                        'Multi Unit',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: navyClr,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Property Type Image'),
                    PropertyTypeImageField(
                      value: propertyTypeImage,
                      propertyType: selectedValue,
                      isMultiUnit: isChecked,
                      onChanged: (v) => setState(() => propertyTypeImage = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Default image is used until you upload one.',
                      style: TextStyle(fontSize: 12, color: mutedClr),
                    ),
                    if (iserror) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Please fill in all fields correctly.',
                        style: TextStyle(
                          color: redClr,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _bottomActionBar(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ---- house design-system helpers (private per screen, as on add_tenants) ----

  Widget _sectionCard({
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) {
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: navyClr,
          ),
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: redClr,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }

  Widget _checkRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget label,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: navyClr,
            checkColor: Colors.white,
            side: BorderSide(color: checkOffClr, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: label),
      ],
    );
  }

  /// Full width now, where it used to be a fixed 160px box: the field is the
  /// page's primary input and a narrow control beside empty space read as
  /// unfinished.
  BoxDecoration get _fieldBox => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outlineClr),
      );

  Widget _typeDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(
          'Select type',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: mutedClr,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        items: items
            .map((String item) => DropdownMenuItem<String>(
                  value: item,
                  // Item padding lives here, not on menuItemStyleData: the package
                  // derives the closed button's inner inset from half that value.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: navyClr,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ))
            .toList(),
        // The closed button renders the item with menuItemStyleData's own
        // padding on top of the button's, so the selected value sat further
        // in than the text field below it. This draws the closed state
        // itself, with no padding, leaving only the button's 14.
        selectedItemBuilder: (context) => items
            .map((String item) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: navyClr,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        value: selectedValue,
        onChanged: (value) {
          setState(() {
            selectedValue = value;
          });
        },
        buttonStyleData: ButtonStyleData(
          height: 52,
          padding: const EdgeInsets.only(left: 14, right: 12),
          decoration: _fieldBox,
        ),
        iconStyleData: IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedClr),
          iconSize: 24,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        // Zero here on purpose: the package derives the CLOSED button's
        // inner padding from half of this value, which pushed the selected
        // value further in than the text field below it. Each item carries
        // its own padding instead, so the open menu is unchanged.
        menuItemStyleData: const MenuItemStyleData(
          height: 44,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _subTypeField() {
    return Container(
      decoration: _fieldBox,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextFormField(
        controller: subtype,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: navyClr,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: 'e.g. Townhome',
          hintStyle: TextStyle(
            color: mutedClr,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _bottomActionBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: outlineClr),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: mutedClr,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: navyClr,
              disabledBackgroundColor: navyClr.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isLoading
                ? const SpinKitFadingCircle(color: Colors.white, size: 22.0)
                : const Text(
                    'Update',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
