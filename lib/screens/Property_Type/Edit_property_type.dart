import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/property_type_image_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../Model/propertytype.dart';
import '../../repository/Property_type.dart';
import '../../widgets/drawer_tiles.dart';
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
    // TODO: implement initState
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Property Type",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 25,
            ),
            titleBar(
              width: MediaQuery.of(context).size.width * .88,
              title: 'Edit Property Type',
            ),
            const SizedBox(
              height: 25,
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width < 500 ? 25 : 55,
                  right: MediaQuery.of(context).size.width < 500 ? 25 : 55),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  // height: MediaQuery.of(context).size.height * .43,
                  width: MediaQuery.of(context).size.width * .99,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: blueColor,
                      )),
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 15,
                          ),
                          Text(
                            "Edit Property Type",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor,
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 17
                                        : 22),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 15,
                          ),
                          Text(
                            "Property Type *",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 15
                                        : 18),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 15,
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: const Row(
                                children: [
                                  SizedBox(
                                    width: 4,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Type',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              items: items
                                  .map(
                                      (String item) => DropdownMenuItem<String>(
                                            value: item,
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
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
                                height: 50,
                                width: 160,
                                padding:
                                    const EdgeInsets.only(left: 14, right: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.black26,
                                  ),
                                  color: Colors.white,
                                ),
                                elevation: 3,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 200,
                                width: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  //color: Colors.redAccent,
                                ),
                                offset: const Offset(-20, 0),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(40),
                                  thickness: MaterialStateProperty.all(6),
                                  thumbVisibility:
                                      MaterialStateProperty.all(true),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                                padding: EdgeInsets.only(left: 14, right: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 15,
                          ),
                          Text(
                            "Property Sub Type *",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 15
                                        : 18),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 15,
                          ),
                          Material(
                            elevation: 2,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: MediaQuery.of(context).size.width < 500
                                  ? 160
                                  : 160,
                              padding: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextFormField(
                                controller: subtype,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Townhome",
                                  hintStyle: TextStyle(
                                    color: Colors.grey
                                        .withOpacity(0.6), // Light grey
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        children: [
                          if (MediaQuery.of(context).size.width < 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          if (MediaQuery.of(context).size.width > 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.02,
                            width: MediaQuery.of(context).size.height * 0.02,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Checkbox(
                              activeColor: isChecked ? blueColor : Colors.white,
                              checkColor: Colors.white,
                              value:
                                  isChecked, // assuming _isChecked is a boolean variable indicating whether the checkbox is checked or not
                              onChanged: (value) {
                                setState(() {
                                  isChecked = value ??
                                      false; // ensure value is not null
                                });
                              },
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width * 0.02),
                          Text(
                            "Multi unit",
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 15
                                  : 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width * 0.05),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (MediaQuery.of(context).size.width < 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          if (MediaQuery.of(context).size.width > 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                          Expanded(
                            child: PropertyTypeImageField(
                              value: propertyTypeImage,
                              propertyType: selectedValue,
                              isMultiUnit: isChecked,
                              onChanged: (v) =>
                                  setState(() => propertyTypeImage = v),
                            ),
                          ),
                          SizedBox(
                              width: MediaQuery.of(context).size.width * 0.05),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        children: [
                          if (MediaQuery.of(context).size.width < 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          if (MediaQuery.of(context).size.width > 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                          GestureDetector(
                            onTap: () async {
                              bool hasChanges =
                                  selectedValue != initialPropertyType ||
                                      subtype.text != initialPropertySubType ||
                                      isChecked != initialIsMultiUnit ||
                                      propertyTypeImage !=
                                          initialPropertyTypeImage;

                              if (selectedValue == null ||
                                  subtype.text.trim().isEmpty) {
                                setState(() {
                                  iserror = true;
                                });
                              } else if (hasChanges) {
                                setState(() {
                                  isLoading = true;
                                  iserror = false;
                                });
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                String? id = prefs.getString("adminId");
                                PropertyTypeRepository()
                                    .EditPropertyType(
                                        adminId: id!,
                                        propertyType: selectedValue,
                                        propertySubType: subtype.text.trim(),
                                        isMultiUnit: isChecked,
                                        id: widget.property.propertyId,
                                        propertyTypeImage:
                                            propertyTypeImage)
                                    .then((value) {
                                  setState(() {
                                    widget.property.propertyType =
                                        selectedValue;
                                    widget.property.propertysubType =
                                        subtype.text;
                                    widget.property.adminId = id;
                                    widget.property.isMultiunit = isChecked;
                                    widget.property.propertyTypeImage =
                                        propertyTypeImage;
                                    widget.property.propertyId =
                                        widget.property.propertyId;
                                    isLoading = false;
                                  });
                                  Navigator.of(context).pop(true);
                                }).catchError((e) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                });
                              } else {
                               // Navigator.of(context).pop(false);
                                Fluttertoast.showToast(
                                  msg: "Please update at least one field before submitting.",
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.white,
                                  textColor: Colors.red,
                                  fontSize: 16.0,
                                );

                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5.0),
                              child: Container(
                                height: MediaQuery.of(context).size.width < 500
                                    ? 40
                                    : 45,
                                width: MediaQuery.of(context).size.width < 500
                                    ? 160
                                    : 165,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5.0),
                                  color: blueColor,
                                  boxShadow: [
                                    const BoxShadow(
                                      color: Colors.grey,
                                      offset: const Offset(0.0, 1.0), //(x,y)
                                      blurRadius: 6.0,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isLoading
                                      ? const SpinKitFadingCircle(
                                          color: Colors.white,
                                          size: 25.0,
                                        )
                                      : Text(
                                          "Update",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 15
                                                  : 15),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 15,
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Material(
                              elevation: 2,
                              child: Container(
                                  width: MediaQuery.of(context).size.width < 500
                                      ? 90
                                      : 100,
                                  height:
                                      MediaQuery.of(context).size.width < 500
                                          ? 40
                                          : 40,
                                  color: Colors.white,
                                  child: const Center(child: Text("Cancel"))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      if (iserror)
                        const Text(
                          "Please fill in all fields correctly.",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
