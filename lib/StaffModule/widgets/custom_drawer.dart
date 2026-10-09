import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../repository/staffpermission_provider.dart';
import 'drawer_tiles.dart';

import '../model/staffpermission.dart';

class CustomDrawerStaff extends StatefulWidget {
  final String currentpage;
  final bool dropdown;

  CustomDrawerStaff({required this.currentpage, required this.dropdown});

  @override
  _CustomDrawerStaffState createState() => _CustomDrawerStaffState();
}

class _CustomDrawerStaffState extends State<CustomDrawerStaff> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // _loadPermissions();
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
    final permissionProvider = Provider.of<StaffPermissionProvider>(context);
    StaffPermission? permissions = permissionProvider.permissions;
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
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Image.asset("assets/images/logo.png"),
              ),
              const SizedBox(height: 40),
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

              // Properties as top-level menu item (with permission check)
              if (permissions != null && permissions.propertyView == true)
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
              // Re-enable by uncommenting (gated on permissions.mortgageView).
              // if (permissions != null && permissions.mortgageView == true)
              //   buildListTile(
              //     context,
              //     FaIcon(
              //       FontAwesomeIcons.handHoldingDollar,
              //       size: 20,
              //       color: widget.currentpage == "Mortgage"
              //           ? Colors.white
              //           : blueColor,
              //     ),
              //     "Mortgage",
              //     widget.currentpage == "Mortgage",
              //   ),
              // Tenants as top-level menu item (with permission check)
              if (permissions != null && permissions.tenantView == true)
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
              // Only show Rentals section if staff has any rental-related permissions
              // if (permissions != null &&
              //     (permissions.propertyView == true ||
              //         permissions.rentalownerView == true ||
              //         permissions.tenantView == true ||
              //         permissions.propertytypeView == true))
              //   buildDropdownListTile(
              //     context,
              //     FaIcon(
              //       FontAwesomeIcons.key,
              //       size: 20,
              //       color: blueColor,
              //     ),
              //     "Rentals",
              //     // Filter the options based on permissions
              //     [
              //       if (permissions.propertyView == true) "Properties",
              //       if (permissions.rentalownerView == true) "Rental Owner",
              //       if (permissions.tenantView == true) "Tenants",
              //       if (permissions.propertytypeView == true) "Property Type",
              //       "Mortgage",
              //     ],
              //     // Filter the icons based on permissions in the same order
              //     [
              //       if (permissions.propertyView == true)
              //         FaIcon(FontAwesomeIcons.buildingUser,
              //             size: 20,
              //             color: widget.currentpage == "Properties"
              //                 ? Colors.white
              //                 : blueColor), // Icon for Properties
              //       if (permissions.rentalownerView == true)
              //         FaIcon(FontAwesomeIcons.users,
              //             size: 20,
              //             color: widget.currentpage == "Rental Owner"
              //                 ? Colors.white
              //                 : blueColor), // Icon for RentalOwner
              //
              //       if (permissions.tenantView == true)
              //         FaIcon(FontAwesomeIcons.houseChimneyUser,
              //             size: 20,
              //             color: widget.currentpage == "Tenants"
              //                 ? Colors.white
              //                 : blueColor), // Icon for Tenants
              //       if (permissions.propertytypeView == true)
              //         FaIcon(
              //           FontAwesomeIcons.house,
              //           size: 20,
              //           color: widget.currentpage == "Property Type"
              //               ? Colors.white
              //               : blueColor,
              //         ),
              //       // if (permissions!.propertytypeView == true)
              //       FaIcon(
              //         FontAwesomeIcons.handHoldingDollar,
              //         size: 20,
              //         color: widget.currentpage == "Mortgage"
              //             ? Colors.white
              //             : blueColor,
              //       ),
              //     ],
              //     selectedSubtopic:
              //         !widget.dropdown ? null : widget.currentpage,
              //   ),
              // Only show Leasing section if staff has leasing-related permissions
              if (permissions != null &&
                  (permissions.leaseView == true ||
                      permissions.applicantView == true))
                buildDropdownListTile(
                  context,
                  FaIcon(
                    FontAwesomeIcons.thumbsUp,
                    size: 20,
                    color: blueColor,
                  ),
                  "Leasing",
                  [
                    if (permissions.leaseView == true) "Leases",
                    if (permissions.applicantView == true) "Applicants",
                    "Upcoming Renewals",
                    if (permissions.leaseView == true) "Pending Leases",
                    "Scheduled Payments",
                    "Scheduled Charges",
                  ],
                  [
                    if (permissions.leaseView == true)
                      FaIcon(
                        FontAwesomeIcons.wallet,
                        size: 20,
                        color: widget.currentpage == "Leases"
                            ? Colors.white
                            : blueColor,
                      ), // Icon for Leases
                    if (permissions.applicantView == true)
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
                            height: 27,
                            width: 27,
                          )
                        : SvgPicture.asset(
                            "assets/images/upcoming renewal.svg",
                            fit: BoxFit.cover,
                            height: 27,
                            width: 27,
                            color: blueColor,
                          ),
                    if (permissions.leaseView == true)
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
                      size: 25,
                      color: widget.currentpage == "Scheduled Charges"
                          ? Colors.white
                          : blueColor,
                    ) // Icon for Scheduled Charges
                    //  FaIcon(FontAwesomeIcons.users, size: 20, color: blueColor), // Icon for Tenants
                  ],
                  selectedSubtopic:
                      !widget.dropdown ? null : widget.currentpage,
                ),
              // Only show Work Orders if staff has workorder permission (Vendor removed - shown in Settings)
              if (permissions != null && permissions.workorderView == true)
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
              // Web-aligned: nested inside the collapsible "Property
              // Maintenance" group below. Old direct tiles kept (commented)
              // for future use — re-enable by uncommenting and removing the
              // buildPropertyMaintenanceSection call. Bid Room stays
              // always-visible; Vendors stays gated on vendorView.
              // buildListTile(
              //   context,
              //   FaIcon(
              //     FontAwesomeIcons.buildingUser,
              //     size: 20,
              //     color: widget.currentpage == "Bid Room"
              //         ? Colors.white
              //         : blueColor,
              //   ),
              //   "Bid Room",
              //   widget.currentpage == "Bid Room",
              // ),
              // if (permissions != null && permissions.vendorView == true)
              //   buildListTile(
              //     context,
              //     FaIcon(
              //       FontAwesomeIcons.solidCircleUser,
              //       size: 20,
              //       color: widget.currentpage == "Vendors"
              //           ? Colors.white
              //           : blueColor,
              //     ),
              //     "Vendors",
              //     widget.currentpage == "Vendors",
              //   ),
              buildPropertyMaintenanceSection(
                context,
                currentpage: widget.currentpage,
                dropdown: widget.dropdown,
                showBidRoom: true,
                showVendors: permissions != null && permissions.vendorView == true,
              ),
              // Commented out Maintenance dropdown - Vendor removed (shown in Settings)
              // Uncomment below if you need to show Maintenance dropdown with Vendor and Work Orders in future
              // if (permissions != null &&
              //     (permissions.vendorView == true ||
              //         permissions.workorderView == true))
              //   buildDropdownListTile(
              //     context,
              //     FaIcon(
              //       FontAwesomeIcons.screwdriverWrench,
              //       size: 20,
              //       color: blueColor,
              //     ),
              //     "Maintenance",
              //     [
              //       if (permissions.vendorView == true) "Vendor",
              //       if (permissions.workorderView == true) "Work Orders",
              //     ],
              //     [
              //       if (permissions.vendorView ?? false)
              //         FaIcon(
              //           FontAwesomeIcons.solidCircleUser,
              //           size: 20,
              //           color: widget.currentpage == "Vendor"
              //               ? Colors.white
              //               : blueColor,
              //         ), // Icon for Vendor
              //       if (permissions.workorderView ?? false)
              //         FaIcon(
              //           FontAwesomeIcons.bookBookmark,
              //           size: 20,
              //           color: widget.currentpage == "Work Orders"
              //               ? Colors.white
              //               : blueColor,
              //         ), // Icon for Work Orders
              //     ],
              //     selectedSubtopic:
              //     !widget.dropdown ? null : widget.currentpage,
              //   ),
              buildCommunicationsSection(
                context,
                currentpage: widget.currentpage,
                dropdown: widget.dropdown,
              ),
              buildListTile(
                context,
                FaIcon(
                  FontAwesomeIcons.folderOpen,
                  color: widget.currentpage == "Reports"
                      ? Colors.white
                      : blueColor,
                ),
                "Reports",
                widget.currentpage == "Reports",
              ),
              // Only show Settings if staff has settings permission
              if (permissions != null && permissions.settingView == true)
                buildListTile(
                  context,
                  FaIcon(
                    FontAwesomeIcons.cog,
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

    /*return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Image.asset("assets/images/logo.png"),
            ),
            const SizedBox(height: 40),
            buildListTile(
              context,
              SvgPicture.asset(
                "assets/images/tenants/dashboard.svg",
                fit: BoxFit.cover,
                height: 20,
                width: 20,
              ),
              "Dashboard",
              widget.currentpage == "Dashboard",
            ),
            buildListTile(
              context,
              SvgPicture.asset(
                "assets/images/tenants/Admin.svg",
                fit: BoxFit.cover,
                height: 20,
                width: 20,
              ),
              "Profile",
              widget.currentpage == "Profile",
            ),

              buildListTile(
                context,
                SvgPicture.asset(
                  "assets/images/tenants/Property.svg",
                  fit: BoxFit.cover,
                  height: 20,
                  width: 20,
                ),
                "Properties",
                widget.currentpage == "Properties",
              ),

              buildListTile(
                context,
                SvgPicture.asset(
                  "assets/images/tenants/Financial.svg",
                  fit: BoxFit.cover,
                  height: 20,
                  width: 20,
                ),
                "Financial",
                widget.currentpage == "Financial",
              ),

              buildListTile(
                context,
                SvgPicture.asset(
                  "assets/images/tenants/Work.svg",
                  fit: BoxFit.cover,
                  height: 20,
                  width: 20,
                ),
                "Work Orders",
                widget.currentpage == "Work Orders",
              ),

              buildListTile(
                context,
                SvgPicture.asset(
                  "assets/images/tenants/tenantdoc1.svg",
                  fit: BoxFit.cover,
                  height: 20,
                  width: 20,
                ),
                "Documents",
                widget.currentpage == "Documents",
              ),
          ],
        ),
      ),
    );*/
  }
}
