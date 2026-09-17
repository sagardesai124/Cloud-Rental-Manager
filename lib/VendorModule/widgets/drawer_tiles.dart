import 'package:flutter/material.dart';

import 'package:three_zero_two_property/screens/Leasing/RentalRoll/newAddLease.dart';


import '../../constant/constant.dart';
import '../../widgets/navigation_helper.dart';
import '../screen/dashboard.dart';
import '../screen/profile.dart';
import '../screen/work_order/workorder_table.dart';


Widget buildListTile(
  BuildContext context,
  Widget leadingIcon,
  String title,
  bool active,
) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: active ? blueColor : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
    ),
    padding: EdgeInsets.symmetric(horizontal: 5),
    child: ListTile(
      onTap: () {
      //  navigateToOption(context, "Properties");
        if (title == "Dashboard") {
        /*  Navigator.push(
              context, MaterialPageRoute(builder: (context) => Dashboard_vendors()));*/
        } else if (title == "Profile") {
          // Same as the other three drawers: replace the stack instead of
          // growing it, so back returns to the dashboard rather than walking
          // through a copy of every screen the user has opened.
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => Profile_screen(),
            "Profile",
          );
        }/* else if (title == "Properties") {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => PropertyTable()));
        }
        else if (title == "Financial") {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => FinancialTable()));
        }*/
        else if (title == "Work Order") {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => WorkOrderTable(),
            "Work Order",
          );
        }

      },
      leading: leadingIcon,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: active ? Colors.white : blueColor,
        ),
      ),
    ),
  );
}

void navigateToOption(
  BuildContext context,
  String option,
) {
  int index = 0;
  Map<String, WidgetBuilder> routes = {
 //   "Properties": (context) => PropertyTable(),
   /* "RentalOwner": (context) => Rentalowner_table(),
    "Tenants": (context) => Tenants_table(),
    "Vendor": (context) => Vendor_table(),
    "Work Order": (context) => Workorder_table(),
    "Rent Roll": (context) => Lease_table(),
    "Applicants": (context) => Applicants_table(),
    "Vendor": (context) => Vendor_table(),*/

  };
  Navigator.push(
    context,
    MaterialPageRoute(builder: routes[option]!),
  );
}

Widget buildDropdownListTile(BuildContext context, Widget leadingIcon,
    String title, List<String> subTopics,
    {String? selectedSubtopic, bool? initvalue}) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 14),
    padding: EdgeInsets.symmetric(horizontal: 5),
    // decoration: BoxDecoration(
    //   color: subTopics.contains(selectedOption) ? blueColor : Colors.transparent,
    //   borderRadius: BorderRadius.circular(10),
    // ),
    child: ExpansionTile(
      // initiallyExpanded: initvalue!,
      leading: leadingIcon,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: blueColor,
        ),
      ),
      children: subTopics.map((
        subTopic,
      ) {
        bool active = selectedSubtopic == subTopic;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            decoration: BoxDecoration(
              color:
                  active ? blueColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              // tileColor: selectedSubtopic == subTopic ? Colors.red :Colors.transparent ,
              title: Text(
                subTopic,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? Colors.white : blueColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                navigateToOption(context, subTopic);
              },
            ),
          ),
        );
      }).toList(),
    ),
  );
}
