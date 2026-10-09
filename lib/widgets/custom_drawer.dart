import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:provider/provider.dart'; // Unused import
// import 'package:cupertino_icons/cupertino_icons.dart'; // Unused import
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'drawer_tiles.dart';

class CustomDrawer extends StatefulWidget {
  final String currentpage;
  final bool dropdown;

  CustomDrawer({required this.currentpage, required this.dropdown});
  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool isLoading = true;
  String? _brandLogoBase64;
  @override
  void initState() {
    super.initState();
    // _loadPermissions();
    _loadBrandLogo();
  }

  Future<void> _loadBrandLogo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? logo = prefs.getString('brand_logo');

    if (logo != null && logo.isNotEmpty && logo.startsWith('data:image')) {
      setState(() {
        _brandLogoBase64 = logo.split(',').last;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    /*   if (isLoading) {
      return Center(child: Text(""));
    }

    if (permissions == null) {
      return Center(child: Text('Failed to load permissions'));
    }
*/

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(80),
        bottomRight: Radius.circular(80),
      ),
      child: Drawer(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _brandLogoBase64 != null
                  ? const SizedBox(height: 10)
                  : const SizedBox(height: 80),
              // Padding(
              //   padding: const EdgeInsets.all(20.0),
              //   child: Image.asset("assets/images/logo.png"),
              // ),
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: _brandLogoBase64 != null
                    ? Container(
                        // color: Colors.blue,
                        child: Image.memory(
                          base64Decode(_brandLogoBase64!),
                          //  height: 100,
                          // width: 100,
                        ),
                      )
                    : Image.asset(
                        "assets/images/logo.png",
                        // height: 100,
                      ),
              ),
              // const SizedBox(height: 5),
              buildListTile(
                context,
                widget.currentpage == "Dashboard"
                    ? SvgPicture.asset(
                        "assets/images/tenants/dashboard1.svg",
                        fit: BoxFit.cover,
                        height: 20,
                        width: 20,
                      )
                    : SvgPicture.asset(
                        "assets/images/tenants/dashboard.svg",
                        fit: BoxFit.cover,
                        height: 20,
                        width: 20,
                        color: blueColor,
                      ),
                "Dashboard",
                widget.currentpage == "Dashboard",
              ),

              // Properties as top-level menu item
              buildListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.buildingUser,
                  size: 20,
                  color: widget.currentpage == "Properties"
                      ? Colors.white
                      : blueColor,
                ),
                "Properties",
                widget.currentpage == "Properties",
              ),

              // ── Mortgage moved to Reports → "Loan Summary Report" ─────────
              // Hidden from the sidebar (kept for future use — do NOT delete).
              // Re-enable by uncommenting.
              // buildListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.handHoldingDollar,
              //     size: 18,
              //     color: widget.currentpage == "Mortgage"
              //         ? Colors.white
              //         : blueColor,
              //   ),
              //   "Mortgage",
              //   widget.currentpage == "Mortgage",
              // ),

              // Tenants as top-level menu item
              buildListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.houseChimneyUser,
                  size: 20,
                  color: widget.currentpage == "Tenants"
                      ? Colors.white
                      : blueColor,
                ),
                "Tenants",
                widget.currentpage == "Tenants",
              ),

              // Rentals dropdown removed - Rental Owner and Property Type moved to Settings
              // Mortgage commented out (not deleted)
              // buildDropdownListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.key,
              //     size: 20,
              //     color: blueColor,
              //   ),
              //   "Rentals",
              //   [
              //     "Properties",
              //     "Rental Owner",
              //     "Tenants",
              //     "Property Type",
              //     "Mortgage"
              //   ],
              //   [
              //     FaIcon(
              //       FontAwesomeIcons.buildingUser,
              //       size: 18,
              //       color: widget.currentpage == "Properties"
              //           ? Colors.white
              //           : blueColor,
              //     ), // Icon for Properties
              //     FaIcon(
              //       FontAwesomeIcons.houseChimneyUser,
              //       size: 18,
              //       color: widget.currentpage == "Rental Owner"
              //           ? Colors.white
              //           : blueColor,
              //     ), // Icon for RentalOwner
              //     FaIcon(
              //       FontAwesomeIcons.users,
              //       size: 18,
              //       color: widget.currentpage == "Tenants"
              //           ? Colors.white
              //           : blueColor,
              //     ),
              //     FaIcon(
              //       FontAwesomeIcons.house,
              //       size: 18,
              //       color: widget.currentpage == "Property Type"
              //           ? Colors.white
              //           : blueColor,
              //     ),
              //     FaIcon(
              //       FontAwesomeIcons.handHoldingDollar,
              //       size: 18,
              //       color: widget.currentpage == "Mortgage"
              //           ? Colors.white
              //           : blueColor,
              //     ),
              //     // Icon for Tenants
              //   ],
              //   selectedSubtopic: !widget.dropdown ? null : widget.currentpage,
              // ),
              buildDropdownListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.thumbsUp,
                  size: 22,
                  color: blueColor,
                ),
                "Leasing",
                [
                  "Leases",
                  "Applicants",
                  "Upcoming Renewals",
                  "Pending Leases",
                  "Scheduled Payments",
                  "Scheduled Charges",
                ],
                [
                  FaIcon(
                    FontAwesomeIcons.wallet,
                    size: 20,
                    color: widget.currentpage == "Leases"
                        ? Colors.white
                        : blueColor,
                  ), // Icon for Properties
                  FaIcon(
                    FontAwesomeIcons.addressCard,
                    size: 20,
                    color: widget.currentpage == "Applicants"
                        ? Colors.white
                        : blueColor,
                  ),

                  widget.currentpage == "Upcoming Renewals"
                      ? SvgPicture.asset(
                          "assets/images/upcoming white.svg",
                          fit: BoxFit.cover,
                          height: 23,
                          width: 23,
                        )
                      : SvgPicture.asset(
                          "assets/images/upcoming renewal.svg",
                          fit: BoxFit.cover,
                          height: 23,
                          width: 23,
                          color: blueColor,
                        ),
                        //Pending Lease
                  FaIcon(
                    FontAwesomeIcons.fileLines,
                    size: 20,
                    color: widget.currentpage == "Pending Leases"
                        ? Colors.white
                        : blueColor,
                  ),
                  FaIcon(
                    FontAwesomeIcons.clock,
                    size: 20,
                    color: widget.currentpage == "Scheduled Payments"
                        ? Colors.white
                        : blueColor,
                  ),
                  Icon(
                    Icons.calendar_month,
                    size: 22,
                    color: widget.currentpage == "Scheduled Charges"
                        ? Colors.white
                        : blueColor,
                  ) // Icon for RentalOwner
                  // FaIcon(
                  //   FontAwesomeIcons.clock,
                  //   size: 20,
                  //   color: widget.currentpage == "Scheduled Charges"
                  //       ? Colors.white
                  //       : blueColor,
                  // ),
                  //  FaIcon(FontAwesomeIcons.users, size: 20, color: blueColor), // Icon for Tenants
                ],
                selectedSubtopic: !widget.dropdown ? null : widget.currentpage,
              ),
              // Commented out Maintenance dropdown - Vendor moved to Settings
              // buildDropdownListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.screwdriverWrench,
              //     size: 20,
              //     color: blueColor,
              //   ),
              //   "Maintenance",
              //   ["Vendor", "Work Orders"],
              //   [
              //     FaIcon(
              //       FontAwesomeIcons.solidCircleUser,
              //       size: 20,
              //       color: widget.currentpage == "Vendor"
              //           ? Colors.white
              //           : blueColor,
              //     ), // Icon for Properties
              //     FaIcon(
              //       FontAwesomeIcons.bookBookmark,
              //       size: 20,
              //       color: widget.currentpage == "Work Orders"
              //           ? Colors.white
              //           : blueColor,
              //     ), // Icon for RentalOwner
              //     //  FaIcon(FontAwesomeIcons.users, size: 20, color: blueColor), // Icon for Tenants
              //   ],
              //   selectedSubtopic: !widget.dropdown ? null : widget.currentpage,
              // ),
              // Work Orders as direct item (Vendor moved to Settings)
              buildListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.bookBookmark,
                  size: 20,
                  color: widget.currentpage == "Work Orders"
                      ? Colors.white
                      : blueColor,
                ),
                "Work Orders",
                widget.currentpage == "Work Orders",
              ),
              // ── Bid Room & Vendors grouped under "Property Maintenance" ───
              // Web-aligned: these two are now nested inside the collapsible
              // "Property Maintenance" group below. The old direct tiles are
              // kept (commented) for future use — re-enable by uncommenting
              // and removing the buildPropertyMaintenanceSection call.
              // buildListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.fileLines,
              //     size: 20,
              //     color: widget.currentpage == "Bid Room"
              //         ? Colors.white
              //         : blueColor,
              //   ),
              //   "Bid Room",
              //   widget.currentpage == "Bid Room",
              // ),
              // buildListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.solidCircleUser,
              //     size: 20,
              //     color: widget.currentpage == "Vendors"
              //         ? Colors.white
              //         : blueColor,
              //   ),
              //   "Vendors",
              //   widget.currentpage == "Vendors",
              // ),
              buildPropertyMaintenanceSection(
                context,
                currentpage: widget.currentpage,
                dropdown: widget.dropdown,
              ),
              buildCommunicationsSection(
                context,
                currentpage: widget.currentpage,
                dropdown: widget.dropdown,
              ),
              buildListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.folderOpen,
                  size: 20,
                  color: widget.currentpage == "Reports"
                      ? Colors.white
                      : blueColor,
                ),
                "Reports",
                widget.currentpage == "Reports",
              ),
              // ── Staff entry hidden for now ───────────────────────────────
              // Will be migrated into Settings → "Team & Access". Keep this
              // code for future use (do NOT delete). Re-enable by uncommenting.
              // buildListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.userClock,
              //     size: 18,
              //     color:
              //         widget.currentpage == "Staff" ? Colors.white : blueColor,
              //   ),
              //   "Staff",
              //   widget.currentpage == "Staff",
              // ),
              buildListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.cog,
                  size: 20,
                  color: widget.currentpage == "Settings"
                      ? Colors.white
                      : blueColor,
                ),
                "Settings",
                widget.currentpage == "Settings",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
