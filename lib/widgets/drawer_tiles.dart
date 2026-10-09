import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import '../screens/Communications/Send E-mail/send_mail.dart';
import '../screens/Leasing/Pending_lease/Pending_lease.dart';
import '../screens/Rental/mortgage/mortgageTable.dart';
import 'navigation_helper.dart';

import 'package:three_zero_two_property/screens/Leasing/upcoming_renewal/upcoming_renewal.dart';
import 'package:three_zero_two_property/screens/Reports/ReportsMainScreen.dart';

import '../screens/Communications/Send E-mail/Send_email_table.dart';
import '../screens/Communications/Templates/Templet_table.dart';
import '../screens/Leasing/Applicants/Applicants_table.dart';

import '../screens/Leasing/RentalRoll/lease_table.dart';
import '../screens/Leasing/Scheduled_Payments/Scheduled_Payments_table.dart';
import '../screens/Leasing/scheduled_charges/ScheduledCharge.dart';
import '../screens/Maintenance/Vendor/Vendor_table.dart';
import '../screens/Maintenance/Workorder/Workorder_table.dart';
import '../screens/Rental/Properties/Properties_table.dart';
import '../screens/Rental/Tenants/Tenants_table.dart';
import '../screens/BidRoom/bid_room_table.dart';
// import '../screens/Rental/mortgage/mortgageTable.dart'; // Commented out - Mortgage feature preserved but not shown in sidebar
import '../screens/Dashboard/dashboard_one.dart';
// import '../screens/Property_Type/Property_type_table.dart'; // Moved to Settings
// import '../screens/Rental/Rentalowner/Rentalowner_table.dart'; // Moved to Settings as Property Owners
import '../screens/Staff_Member/Staffmemvertable.dart';
import '../screens/Profile/Settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/VendorModule/screen/bid_room/vendor_bid_room_table.dart';

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
        if (title == "Dashboard" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => Dashboard(),
            "Dashboard",
          );
        } else if (title == "Staff" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => StaffTable(),
            "Staff",
          );
        } else if (title == "Reports" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => ReportsMainScreen(),
            "Reports",
          );
        } else if (title == "Work Orders" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => Workorder_table(),
            "Work Orders",
          );
        } else if (title == "Properties" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => PropertiesTable(),
            "Properties",
          );
        } else if (title == "Mortgage" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => MortgageTable(),
            "Mortgage",
          );
        } else if (title == "Tenants" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => Tenants_table(),
            "Tenants",
          );
        } else if (title == "Bid Room" && active != true) {
          SharedPreferences.getInstance().then((prefs) {
            String? vendorId = prefs.getString('vendor_id');
            if (vendorId != null && vendorId.isNotEmpty) {
              NavigationHelper.navigateWithValidationBuilder(
                context,
                (context) => VendorBidRoomTable(),
                "Bid Room",
              );
            } else {
              NavigationHelper.navigateWithValidationBuilder(
                context,
                (context) => BidRoomTable(),
                "Bid Room",
              );
            }
          });
        } else if (title == "Vendors" && active != true) {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => Vendor_table(),
            "Vendors",
          );
        } else if (title == "Settings") {
          NavigationHelper.navigateWithValidationBuilder(
            context,
            (context) => TabBarExample(),
            "Settings",
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

void navigateToOption(BuildContext context, String option, bool isActive) {
  Map<String, WidgetBuilder> routes = {
    "Properties": (context) => PropertiesTable(),
    "Mortgage": (context) => MortgageTable(),
    "Tenants": (context) => Tenants_table(),
    // "Rental Owner": (context) => Rentalowner_table(), // Moved to Settings as "Property Owners"
    // "Property Type": (context) => PropertyTable(), // Moved to Settings
    "Vendors": (context) => Vendor_table(),
    "Work Orders": (context) => Workorder_table(),
    "Bid Room": (context) => BidRoomTable(),
    "Leases": (context) => Lease_table(),
    "Templates": (context) => TempletTable(),
    // "E-mail Logs": (context) => Email_log_tablee(),
    "E-mail Logs": (context) => Send_Email_table(),
    "Send E-mail": (context) => send_email(), //Send_Email_table(),
    "Applicants": (context) => Applicants_table(),
    "Upcoming Renewals": (context) => Upcomingrenewal(),
    "Pending Leases": (context) => Pending_lease(),
    "Scheduled Payments": (context) => Scheduled_Payments_table(),
    "Scheduled Charges": (context) => ScheduledChargeTable(),
    // "Mortgage": (context) => MortgageTable() // Commented out - not deleted
    // "Work Orders": (context) => Cardpayment(leaseId: '',),
  };

  // Handle Property Owners and Property Type navigation to Settings
  if (option == "Property Owners" || option == "Rental Owner") {
    NavigationHelper.navigateWithValidationBuilder(
      context,
      (context) => TabBarExample(initialTab: 'Property Owners'),
      "Settings",
    );
  } else if (option == "Property Type") {
    NavigationHelper.navigateWithValidationBuilder(
      context,
      (context) => TabBarExample(initialTab: 'Property Type'),
      "Settings",
    );
  } else if (option == "Bid Room") {
    SharedPreferences.getInstance().then((prefs) {
      String? vendorId = prefs.getString('vendor_id');
      if (vendorId != null && vendorId.isNotEmpty) {
        NavigationHelper.navigateWithValidationBuilder(
          context,
          (context) => VendorBidRoomTable(),
          "Bid Room",
        );
      } else {
        NavigationHelper.navigateWithValidationBuilder(
          context,
          (context) => BidRoomTable(),
          "Bid Room",
        );
      }
    });
  } else if (routes.containsKey(option)) {
    NavigationHelper.navigateWithValidationBuilder(
      context,
      routes[option]!,
      option,
    );
  }
}

const _kCommLeafPages = ['Send E-mail', 'E-mail Logs', 'Templates'];
const _kCommEmailPages = ['Send E-mail', 'E-mail Logs'];

/// Communications → Email (nested) → Send E-mail / E-mail Logs; SMS (placeholder); Templates.
Widget buildCommunicationsSection(
  BuildContext context, {
  required String currentpage,
  required bool dropdown,
}) {
  final String? selected = dropdown ? currentpage : null;
  final bool commOpen =
      selected != null && _kCommLeafPages.contains(currentpage);
  final bool emailOpen =
      selected != null && _kCommEmailPages.contains(currentpage);

  Widget iconForPage(String page, bool active) {
    final Color c = active ? Colors.white : blueColor;
    switch (page) {
      case 'Send E-mail':
        return FaIcon(FontAwesomeIcons.envelopeCircleCheck, size: 20, color: c);
      case 'E-mail Logs':
        return FaIcon(FontAwesomeIcons.envelopeOpenText, size: 20, color: c);
      case 'Templates':
        return FaIcon(FontAwesomeIcons.fileLines, size: 20, color: c);
      default:
        return FaIcon(FontAwesomeIcons.circle, size: 20, color: c);
    }
  }

  /// Same row layout as [buildDropdownListTile] children (Leasing sub-items).
  Widget emailLeafTile(String title) {
    final bool active = currentpage == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        decoration: BoxDecoration(
          color: active ? blueColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: iconForPage(title, active),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: active ? Colors.white : blueColor,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            navigateToOption(context, title, active);
          },
        ),
      ),
    );
  }

  final Color chevronCollapsed = Colors.grey.shade600;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 14),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: commOpen,
        maintainState: true,
        childrenPadding: EdgeInsets.zero,
        iconColor: blueColor,
        collapsedIconColor: chevronCollapsed,
        // Match [buildDropdownListTile] / Leasing: raw FaIcon, size 22 (admin drawer).
        leading: FaIcon(
          FontAwesomeIcons.comments,
          size: 22,
          color: blueColor,
        ),
        title: Text(
          'Communications',
          style: TextStyle(
            color: blueColor,
            fontSize: 15,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color:  Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExpansionTile(
                      initiallyExpanded: emailOpen,
                      childrenPadding: EdgeInsets.zero,
                      iconColor: blueColor,
                      collapsedIconColor: chevronCollapsed,
                      leading: FaIcon(
                        FontAwesomeIcons.envelope,
                        size: 20,
                        color: blueColor,
                      ),
                      title: Text(
                        'Email',
                        style: TextStyle(
                          color: blueColor,
                          fontSize: 15,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                emailLeafTile('Send E-mail'),
                                emailLeafTile('E-mail Logs'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ExpansionTile(
                    //   initiallyExpanded: false,
                    //   childrenPadding: EdgeInsets.zero,
                    //   iconColor: blueColor,
                    //   collapsedIconColor: chevronCollapsed,
                    //   leading: FaIcon(
                    //     FontAwesomeIcons.comment,
                    //     size: 18,
                    //     color: blueColor,
                    //   ),
                    //   title: Text(
                    //     'SMS',
                    //     style: TextStyle(
                    //       color: blueColor,
                    //       fontSize: 15,
                    //     ),
                    //   ),
                    //   children: [
                    //     Padding(
                    //       padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    //       child: Text(
                    //         'Coming soon',
                    //         style: TextStyle(
                    //           fontSize: 13,
                    //           color: Colors.grey.shade600,
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                   
                    Padding(
                      padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                      child: () {
                        final bool active = currentpage == 'Templates';
                        return Container(
                          decoration: BoxDecoration(
                            color: active ? blueColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: iconForPage('Templates', active),
                            title: Text(
                              'Templates',
                              style: TextStyle(
                                fontSize: 15,
                                color: active ? Colors.white : blueColor,
                              ),
                            ),
                            trailing: const SizedBox(
                              width: 24,
                              height: 24,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              navigateToOption(context, 'Templates', active);
                            },
                          ),
                        );
                      }(),
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

const _kPropertyMaintenancePages = ['Bid Room', 'Vendors'];

/// Property Maintenance → Bid Room / Vendors (grouped collapsible section).
///
/// Web-aligned grouping: Bid Room and Vendors are nested under a single
/// "Property Maintenance" parent. Mirrors [buildCommunicationsSection] styling.
/// Auto-expands whenever the current page is one of its children, so the
/// active row stays highlighted regardless of the [dropdown] flag.
Widget buildPropertyMaintenanceSection(
  BuildContext context, {
  required String currentpage,
  required bool dropdown,
}) {
  final bool sectionOpen = _kPropertyMaintenancePages.contains(currentpage);

  Widget iconForPage(String page, bool active) {
    final Color c = active ? Colors.white : blueColor;
    switch (page) {
      case 'Bid Room':
        return FaIcon(FontAwesomeIcons.fileLines, size: 20, color: c);
      case 'Vendors':
        return FaIcon(FontAwesomeIcons.user, size: 20, color: c);
      default:
        return FaIcon(FontAwesomeIcons.circle, size: 20, color: c);
    }
  }

  /// Same row layout as the Communications leaf tiles.
  Widget leafTile(String title) {
    final bool active = currentpage == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        decoration: BoxDecoration(
          color: active ? blueColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: iconForPage(title, active),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: active ? Colors.white : blueColor,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            navigateToOption(context, title, active);
          },
        ),
      ),
    );
  }

  final Color chevronCollapsed = Colors.grey.shade600;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 14),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: sectionOpen,
        maintainState: true,
        childrenPadding: EdgeInsets.zero,
        iconColor: blueColor,
        collapsedIconColor: chevronCollapsed,
        leading: FaIcon(
          FontAwesomeIcons.fileCirclePlus,
          size: 22,
          color: blueColor,
        ),
        title: Text(
          'Property Maintenance',
          style: TextStyle(
            color: blueColor,
            fontSize: 15,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  leafTile('Bid Room'),
                  leafTile('Vendors'),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildDropdownListTile(
  BuildContext context,
  Widget leadingIcon,
  String title,
  List<String> subTopics,
  List<Widget> subTopicIcons, {
  String? selectedSubtopic,
  bool? initvalue,
}) {
  // Check if the selectedSubtopic is in the list of subTopics
  bool isExpanded =
      selectedSubtopic != null && subTopics.contains(selectedSubtopic);

  return Container(
    margin: EdgeInsets.symmetric(horizontal: 14),
    padding: EdgeInsets.symmetric(horizontal: 5),
    child: ExpansionTile(
      initiallyExpanded: isExpanded,
      leading: leadingIcon,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: blueColor,
        ),
      ),
      children: subTopics.asMap().entries.map((entry) {
        int index = entry.key;
        String subTopic = entry.value;
        bool active = selectedSubtopic == subTopic;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            decoration: BoxDecoration(
              color: active ? blueColor : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: subTopicIcons[index], // Add icon here
              title: Text(
                subTopic,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? Colors.white : blueColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                navigateToOption(context, subTopic, active);
              },
            ),
          ),
        );
      }).toList(),
    ),
  );
}
