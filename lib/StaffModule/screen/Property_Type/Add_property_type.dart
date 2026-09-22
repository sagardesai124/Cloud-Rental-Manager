import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/property_type_image_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constant/constant.dart';
import '../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../repository/Property_type.dart';
import '../../widgets/drawer_tiles.dart';
import '../../widgets/custom_drawer.dart';


class Add_property extends StatefulWidget {
  const Add_property({super.key});

  @override
  State<Add_property> createState() => _Add_propertyState();
}


class _Add_propertyState extends State<Add_property> {
  List<String> months = ['Residential', "Commercial"];
  final List<String> items = [
    'Residential',
    "Commercial",
  ];
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

  // Helper method to detect if device is tablet
  bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diagonal = (size.width * size.width + size.height * size.height);
    // Updated to better detect tablets including your 1280x1880 size
    return diagonal >
        800000; // Diagonal > 894px indicates tablet (covers your 1280x1880)
  }

  // Helper method to get responsive values
  double getResponsivePadding(BuildContext context) {
    if (isTablet(context)) {
      return MediaQuery.of(context).size.width *
          0.12; // 12% padding for tablets (optimized for 1280px width)
    }
    return MediaQuery.of(context).size.width < 500 ? 25 : 55;
  }

  double getResponsiveFontSize(
      BuildContext context, double mobileSize, double tabletSize) {
    if (isTablet(context)) {
      return tabletSize;
    }
    return MediaQuery.of(context).size.width < 500
        ? mobileSize
        : mobileSize + 3;
  }

  double getResponsiveWidth(
      BuildContext context, double mobileWidth, double tabletWidth) {
    if (isTablet(context)) {
      return tabletWidth;
    }
    return mobileWidth;
  }

  double getResponsiveHeight(
      BuildContext context, double mobileHeight, double tabletHeight) {
    if (isTablet(context)) {
      return tabletHeight;
    }
    return mobileHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Property Type",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: isTablet(context) ? 35 : 25,
            ),
            titleBar(
              width: MediaQuery.of(context).size.width * .88,
              title: 'Add Property Type',
            ),
            SizedBox(
              height: isTablet(context) ? 35 : 25,
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: getResponsivePadding(context),
                  right: getResponsivePadding(context)),
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
                      SizedBox(
                        height: isTablet(context) ? 30 : 20,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: isTablet(context) ? 25 : 15,
                          ),
                          Text(
                            "New Property Type",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor,
                                fontSize:
                                    getResponsiveFontSize(context, 17, 26)),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isTablet(context) ? 15 : 10,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: isTablet(context) ? 25 : 15,
                          ),
                          Text(
                            "Property Type *",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    getResponsiveFontSize(context, 15, 20)),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isTablet(context) ? 15 : 10,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: isTablet(context) ? 25 : 15,
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: Row(
                                children: [
                                  SizedBox(
                                    width: 4,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Type',
                                      style: TextStyle(
                                        fontSize: isTablet(context) ? 16 : 14,
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
                                              style: TextStyle(
                                                fontSize:
                                                    isTablet(context) ? 16 : 14,
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
                                height: isTablet(context) ? 60 : 50,
                                width: getResponsiveWidth(context, 160, 200),
                                padding: EdgeInsets.only(left: 14, right: 14),
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
                                width: isTablet(context) ? 250 : 200,
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
                              menuItemStyleData: MenuItemStyleData(
                                height: isTablet(context) ? 50 : 40,
                                padding: EdgeInsets.only(left: 14, right: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isTablet(context) ? 25 : 20,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: isTablet(context) ? 25 : 15,
                          ),
                          Text(
                            "Property Sub Type *",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    getResponsiveFontSize(context, 15, 20)),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isTablet(context) ? 15 : 10,
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: isTablet(context) ? 25 : 15,
                          ),
                          Material(
                            elevation: 2,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: getResponsiveWidth(context, 160, 200),
                              padding: EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextFormField(
                                controller: subtype,
                                style: TextStyle(
                                  fontSize: isTablet(context) ? 16 : 14,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Townhome",
                                  hintStyle: TextStyle(
                                    color: Colors.grey
                                        .withOpacity(0.6), // Light grey
                                    fontWeight: FontWeight.normal,
                                    fontSize: isTablet(context) ? 16 : 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isTablet(context) ? 25 : 20,
                      ),
                      Row(
                        children: [
                          if (MediaQuery.of(context).size.width < 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          if (MediaQuery.of(context).size.width > 500 &&
                              !isTablet(context))
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                          if (isTablet(context))
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          Container(
                            height: isTablet(context)
                                ? MediaQuery.of(context).size.height * 0.025
                                : MediaQuery.of(context).size.height * 0.02,
                            width: isTablet(context)
                                ? MediaQuery.of(context).size.height * 0.025
                                : MediaQuery.of(context).size.height * 0.02,
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
                              width: isTablet(context)
                                  ? MediaQuery.of(context).size.width * 0.03
                                  : MediaQuery.of(context).size.width * 0.02),
                          Text(
                            "Multi unit",
                            style: TextStyle(
                              fontSize: getResponsiveFontSize(context, 15, 18),
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
                      SizedBox(
                        height: isTablet(context) ? 25 : 20,
                      ),
                      Row(
                        children: [
                          if (MediaQuery.of(context).size.width < 500)
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          if (MediaQuery.of(context).size.width > 500 &&
                              !isTablet(context))
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.02),
                          if (isTablet(context))
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.05),
                          GestureDetector(
                            onTap: () async {
                              if (selectedValue == null ||
                                  subtype.text.trim().isEmpty) {
                                setState(() {
                                  iserror = true;
                                });
                              } else {
                                setState(() {
                                  isLoading = true;
                                  iserror = false;
                                });
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                String? id = prefs.getString("adminId");
                                PropertyTypeRepository()
                                    .addPropertyType(
                                  adminId: id!,
                                  propertyType: selectedValue,
                                  propertySubType: subtype.text.trim(),
                                  isMultiUnit: isChecked,
                                  propertyTypeImage: propertyTypeImage,
                                )
                                    .then((value) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                  Navigator.pop(context, true);
                                }).catchError((e) {
                                  setState(() {
                                    isLoading = false;
                                  });
                                });
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5.0),
                              child: Container(
                                height: getResponsiveHeight(context, 40, 50),
                                width: getResponsiveWidth(context, 160, 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5.0),
                                  color: blueColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey,
                                      offset: Offset(0.0, 1.0), //(x,y)
                                      blurRadius: 6.0,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isLoading
                                      ? SpinKitFadingCircle(
                                          color: Colors.white,
                                          size: isTablet(context) ? 30.0 : 25.0,
                                        )
                                      : Text(
                                          "Add",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: getResponsiveFontSize(
                                                  context, 15, 17)),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: isTablet(context) ? 20 : 15,
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Material(
                              elevation: 2,
                              child: Container(
                                  width: getResponsiveWidth(context, 90, 120),
                                  height: getResponsiveHeight(context, 40, 50),
                                  color: Colors.white,
                                  child: Center(
                                    child: Text(
                                      "Cancel",
                                      style: TextStyle(
                                        fontSize: getResponsiveFontSize(
                                            context, 14, 16),
                                      ),
                                    ),
                                  )),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isTablet(context) ? 15 : 10,
                      ),
                      if (iserror)
                        Text(
                          "Please fill in all fields correctly.",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: getResponsiveFontSize(context, 14, 16),
                          ),
                        ),
                      SizedBox(
                        height: isTablet(context) ? 15 : 10,
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
