import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'RentPastDueReport.dart';

import '../../StaffModule/model/staffpermission.dart';
import '../../StaffModule/repository/staffpermission_provider.dart';
import '../../StaffModule/screen/Dashboard/cronjob_payment_table.dart';
import '../../StaffModule/screen/Leasing/Applicants/Applicants_table.dart';
import '../../StaffModule/screen/Dashboard/Unpaid_Properties.dart';
import '../../StaffModule/screen/Maintenance/Workorder/Workorder_table.dart';
import '../../StaffModule/screen/Rental/Properties/Properties_table.dart';
import '../../StaffModule/screen/Rental/Tenants/Tenants_table.dart';
import '../../StaffModule/screen/Dashboard/dashboard_leaseExpiring_staff.dart';
import '../../screens/Profile/Settings_screen.dart';
import '../../constant/constant.dart';

// Add your StaffModule table screens here

class DashboardMobileSimple extends StatefulWidget {
  final int propertyCount;
  final int tenantCount;
  final int applicantCount;
  final int vendorCount;
  final int unpaidPropertiesCount;
  final int newWorkOrder;
  final int overdueWorkOrder;
  final int totalWorkOrders;
  final double currentMonthRentDue;
  final double lastMonthRentDue;
  final double currentMonthRentPaid;
  final double lastMonthRentPaid;
  final double totalRentPastDue;
  /// When true, rent-detail screens use staff app bar and staff drawer (Dashboard selected).
  final bool fromStaffModule;
  // Called after a card's list closes, so the dashboard can reload its counts.
  final VoidCallback? onReturn;

  const DashboardMobileSimple({
    Key? key,
    required this.propertyCount,
    required this.tenantCount,
    required this.applicantCount,
    required this.vendorCount,
    required this.unpaidPropertiesCount,
    required this.newWorkOrder,
    required this.overdueWorkOrder,
    required this.totalWorkOrders,
    this.currentMonthRentDue = 0.0,
    this.lastMonthRentDue = 0.0,
    this.currentMonthRentPaid = 0.0,
    this.lastMonthRentPaid = 0.0,
    this.totalRentPastDue = 0.0,
    this.fromStaffModule = false,
    this.onReturn,
  }) : super(key: key);

  @override
  State<DashboardMobileSimple> createState() => _DashboardMobileSimpleState();
}

class _DashboardMobileSimpleState extends State<DashboardMobileSimple> {
  String selectedRentType = 'Rent Due';
  final GlobalKey _dropdownKey = GlobalKey();

  void _showRentTypeMenu(BuildContext context) async {
    final RenderBox button =
        _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position =
        button.localToGlobal(Offset.zero, ancestor: overlay);

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy + 8,
              child: Material(
                color: Colors.transparent,
                child: _RentTypePopup(
                  selected: selectedRentType,
                  onSelect: (val) {
                    Navigator.of(context).pop(val);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    if (result != null && result != selectedRentType) {
      setState(() {
        selectedRentType = result;
      });
    }
  }

  void _navigateToRespectiveScreen(
      BuildContext context, String rentType, String monthType) {
    String chargeType = 'Charges';
    bool isRentdue = false;
    String title = rentType;
    if (rentType == 'Rent Paid') {
      chargeType = 'Payment';
      isRentdue = true;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentPastDueReports(
          isRentdue: isRentdue,
          title: title,
          fromStaffModule: widget.fromStaffModule,
        ),
        settings: RouteSettings(
          arguments: {'monthType': monthType, 'chargeType': chargeType},
        ),
      ),
    );
  }

  // Anything added or removed in a card's list changes that card's number,
  // so ask the dashboard to reload its counts once the list closes.
  void _afterCardReturn() {
    if (!mounted) return;
    widget.onReturn?.call();
  }

  Future<void> _navigateToTable(BuildContext context, String label) async {
    // Add navigation logic for each table
    if (label == 'Properties') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PropertiesTable()),
      );
    } else if (label == 'Tenants') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Tenants_table()),
      );
    } else if (label == 'Applicants') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Applicants_table()),
      );
    } else if (label == 'Vendors') {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const TabBarExample(initialTab: 'Vendors')),
      );
    } else if (label == 'Unpaid Properties') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Unpaid_Properties()),
      );
    } else {
      // Add more navigation as needed
      return;
    }
    _afterCardReturn();
  }

  Future<void> _navigateToWorkOrderTable(BuildContext context,
      {String? filter}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Workorder_table(filter: filter),
      ),
    );
    _afterCardReturn();
  }

  Widget workOrderCard(BuildContext context, String title, int total) {
    Color cardColor = Colors.white;
    Color iconBgColor = blueColor;
    Color iconColor = Colors.white;
    Color arrowBgColor = blueColor;
    Color arrowIconColor = blueColor;
    if (title.toLowerCase().contains('overdue')) {
      iconBgColor = const Color.fromRGBO(90, 134, 213, 1);
      arrowBgColor = const Color.fromRGBO(90, 134, 213, 0.1);
      arrowIconColor = const Color.fromRGBO(90, 134, 213, 1);
    } else if (title.toLowerCase().contains('new')) {
      arrowBgColor = blueColor.withOpacity(0.1);
    }
    final cardTextStyle =
        TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: blueColor);
    final subTextStyle = TextStyle(
        color: Color.fromRGBO(16, 24, 40, 0.7),
        fontWeight: FontWeight.bold,
        fontSize: 14);
    return InkWell(
      onTap: () {
        if (title.toLowerCase().contains('overdue')) {
          _navigateToWorkOrderTable(context, filter: 'Over Due');
        } else if (title.toLowerCase().contains('new')) {
          _navigateToWorkOrderTable(context, filter: 'New');
        } else {
          _navigateToWorkOrderTable(context);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: iconBgColor.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.add, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: cardTextStyle.copyWith(
                      fontSize: 18,
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total : ${total.toString()}',
                    style: subTextStyle.copyWith(
                      color: blueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: arrowBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.arrow_forward_ios,
                  size: 16, color: arrowIconColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rentDataSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;

        // Consistent responsive font sizing across dashboard
        double dropdownFont = screenWidth < 600
            ? 16
            : (screenWidth < 900 ? 18 : (screenWidth < 1200 ? 20 : 22));
        double sectionFont = screenWidth < 600
            ? 16
            : (screenWidth < 900 ? 18 : (screenWidth < 1200 ? 20 : 22));
        double valueFont = screenWidth < 600
            ? 16
            : (screenWidth < 900 ? 18 : (screenWidth < 1200 ? 20 : 22));

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      key: _dropdownKey,
                      onTap: () => _showRentTypeMenu(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFE5E5E5), width: 2),
                          borderRadius: BorderRadius.circular(32),
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Text(
                              selectedRentType,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: dropdownFont,
                                color: const Color(0xFF3B4256),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1A2746), size: 28),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Divider(thickness: 2, color: Color(0xFFE5E5E5)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedRentType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: sectionFont,
                        color: const Color(0xFF1A2746),
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (selectedRentType == 'Rent Past Due')
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RentPastDueReports(
                                title: 'Rent Past Due',
                                fromStaffModule: widget.fromStaffModule,
                              ),
                              settings: RouteSettings(
                                arguments: {
                                  'monthType': 'All',
                                  'chargeType': 'Charges'
                                },
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              formatCurrency(widget.totalRentPastDue),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFF7B7F87),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      GestureDetector(
                        onTap: () {
                          _navigateToRespectiveScreen(
                              context, selectedRentType, "Current Month");
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Current Month',
                                style: TextStyle(
                                  fontSize: valueFont,
                                  color: const Color(0xFF7B7F87),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Text(
                              selectedRentType == 'Rent Due'
                                  ? formatCurrency(widget.currentMonthRentDue)
                                  : selectedRentType == 'Rent Paid'
                                      ? formatCurrency(
                                          widget.currentMonthRentPaid)
                                      : formatCurrency(0.0),
                              style: TextStyle(
                                fontSize: valueFont,
                                color: const Color(0xFF7B7F87),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          _navigateToRespectiveScreen(
                              context, selectedRentType, "Last Month");
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Last Month',
                                style: TextStyle(
                                  fontSize: valueFont,
                                  color: const Color(0xFF7B7F87),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Text(
                              selectedRentType == 'Rent Due'
                                  ? formatCurrency(widget.lastMonthRentDue)
                                  : selectedRentType == 'Rent Paid'
                                      ? formatCurrency(widget.lastMonthRentPaid)
                                      : formatCurrency(0.0),
                              style: TextStyle(
                                fontSize: valueFont,
                                color: const Color(0xFF7B7F87),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // Bottom bar
              Container(
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2746),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardTextStyle =
        TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: blueColor);
    final subTextStyle = TextStyle(
        color: Color.fromRGBO(16, 24, 40, 0.7),
        fontWeight: FontWeight.bold,
        fontSize: 14);

    Widget dashboardCard(IconData icon, String count, String label) {
      final staff = widget.fromStaffModule;
      final labelStyle = staff
          ? subTextStyle.copyWith(fontSize: 12, height: 1.2)
          : subTextStyle;
      final avatarRadius = staff ? 17.0 : 20.0;
      final iconSize = staff ? 20.0 : 24.0;
      final chevronSize = staff ? 12.0 : 16.0;
      final hPad = staff ? 6.0 : 10.0;
      final vPad = staff ? 12.0 : 18.0;
      final labelMinH = staff ? 30.0 : 36.0;

      return Expanded(
        child: InkWell(
          onTap: () => _navigateToTable(context, label),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: staff ? 1 : 2),
            padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: blueColor.withOpacity(.1),
                    child: Icon(icon, color: blueColor, size: iconSize),
                  ),
                ),
                SizedBox(width: staff ? 4 : 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(count, style: cardTextStyle),
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: labelMinH),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            style: labelStyle,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: staff ? 2 : 4),
                Padding(
                  padding: EdgeInsets.only(top: staff ? 10 : 12),
                  child: Icon(Icons.arrow_forward_ios,
                      size: chevronSize, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget paymentCard(String name, String address, String amount) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(name, style: cardTextStyle),
                const Spacer(),
                Text('$amount', style: cardTextStyle),
              ],
            ),
            Divider(
              thickness: 2,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rental Address',
                    style: subTextStyle.copyWith(
                        color: blueColor, fontWeight: FontWeight.bold)),
                Text('Action',
                    style: subTextStyle.copyWith(
                        color: blueColor, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(address, style: subTextStyle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      height: 30,
                      width: 30,
                      child: Icon(Icons.check, color: blueColor),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      height: 30,
                      width: 30,
                      child: Icon(Icons.recycling_outlined, color: blueColor),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      height: 30,
                      width: 30,
                      child:
                          Icon(Icons.calendar_month_outlined, color: blueColor),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    StaffPermission? permissions;
    final permissionProvider = Provider.of<StaffPermissionProvider>(context);
    permissions = permissionProvider.permissions;
    return Container(
      color: Color.fromRGBO(241, 244, 250, 1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(' Dashboard',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: blueColor)),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final List<Widget> cards = [];

                // Show cards based on permissions, but if no permissions are set, show all cards
                bool showAllCards = permissions == null ||
                    (permissions.propertyView != true &&
                        permissions.tenantView != true &&
                        permissions.applicantView != true &&
                        permissions.vendorView != true &&
                        permissions.workorderView != true);

                if (showAllCards || permissions.propertyView == true) {
                  cards.add(dashboardCard(
                      Icons.home, widget.propertyCount.toString(), 'Properties'));
                }
                if (showAllCards || permissions.tenantView == true) {
                  cards.add(dashboardCard(
                      Icons.people, widget.tenantCount.toString(), 'Tenants'));
                }
                if (showAllCards || permissions.applicantView == true) {
                  cards.add(dashboardCard(Icons.assignment_ind,
                      widget.applicantCount.toString(), 'Applicants'));
                }
                // if (showAllCards || permissions.vendorView == true) {
                //   cards.add(dashboardCard(
                //       Icons.store, widget.vendorCount.toString(), 'Vendors'));
                // }
                if (showAllCards || permissions.workorderView == true) {
                  cards.add(dashboardCard(Icons.layers_outlined,
                      widget.unpaidPropertiesCount.toString(), 'Unpaid Properties'));
                }

                List<Widget> rows = [];
                for (int i = 0; i < cards.length; i += 2) {
                  if (i + 1 < cards.length) {
                    rows.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cards[i],
                            SizedBox(width: 8),
                            cards[i + 1],
                          ],
                        ),
                      ),
                    );
                  } else {
                    rows.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cards[i],
                          ],
                        ),
                      ),
                    );
                  }
                }
                return Column(
                  children: rows,
                );
              },
            ),
            const SizedBox(height: 15),
            _rentDataSection(context),
            const SizedBox(height: 15),
            workOrderCard(context, 'New Work Orders', widget.newWorkOrder),
            workOrderCard(context, 'Overdue Work Orders', widget.overdueWorkOrder),
            UnpaidRentChartCard(),
            const SizedBox(height: 16),
            Cronjob_payment_table(),
            // const SizedBox(height: 15),
           Dashboard_leaseExpiringStaff(),
            SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = constraints.maxWidth;
                    double imageSize =
                        screenWidth < 400 ? 32 : (screenWidth < 600 ? 40 : 48);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Powered By",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Image.asset(
                          "assets/images/logo.png",
                          height: imageSize,
                          fit: BoxFit.contain,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        ),
      );
  }
}

class _RentTypePopup extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _RentTypePopup({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = ['Rent Due', 'Rent Paid', 'Rent Past Due'];
    final screenWidth = MediaQuery.of(context).size.width;
    final double popupWidth = screenWidth < 450
        ? screenWidth * 0.45
        : (screenWidth < 500 ? screenWidth * 0.20 : 320);
    // Consistent responsive font sizing
    final double fontSize = screenWidth < 600
        ? 16
        : (screenWidth < 900 ? 18 : (screenWidth < 1200 ? 20 : 22));
    final double verticalPad = screenWidth < 600
        ? 16
        : (screenWidth < 900 ? 18 : (screenWidth < 1200 ? 20 : 22));
    final double horizontalPad = screenWidth < 600
        ? 10
        : (screenWidth < 900 ? 12 : (screenWidth < 1200 ? 14 : 18));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pointer
        Container(
          // color: Colors.redAccent,
          padding: EdgeInsets.only(left: popupWidth * 0.45),
          child: CustomPaint(
            size: const Size(20, 10),
            painter: _TrianglePainter(),
          ),
        ),
        Container(
          width: popupWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: horizontalPad),
          child: Column(
            children: List.generate(items.length, (i) {
              final isSelected = items[i] == selected;
              return Column(
                children: [
                  if (i != 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(
                        color: Color(0xFFE5E5E5),
                        thickness: 1,
                        height: 1,
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(items[i]),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: EdgeInsets.symmetric(
                        vertical: verticalPad,
                        horizontal: 0,
                      ),
                      decoration: isSelected
                          ? BoxDecoration(
                              color: const Color(0xFFE6EEF8),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: Center(
                        child: Text(
                          items[i],
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: fontSize,
                            color: const Color(0xFF1A2746),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFAAA5A5);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black.withOpacity(0.18), 6, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fetches admin_balance + rentals APIs and shows "Percentage of Unpaid Rent" pie chart and legend.
class UnpaidRentChartCard extends StatefulWidget {
  const UnpaidRentChartCard({Key? key}) : super(key: key);

  @override
  State<UnpaidRentChartCard> createState() => _UnpaidRentChartCardState();
}

class _UnpaidRentChartCardState extends State<UnpaidRentChartCard>
    with NetworkRetryState {
  bool _loading = true;
  int _totalProperties = 0;
  double _totalUnpaidAmount = 0;
  int _totalUnpaidRentLeases = 0;
  double _percentage = 0;

  /// Section index when user taps pie: 0 = Unpaid, 1 = Paid. Null when not touching.
  int? _touchedSectionIndex;

  /// Dashboard unpaid rent — data sources and summary lines:
  ///
  /// 1) Balance API (GET /api/payment/admin_balance/{adminId})
  ///    - totalRentPastDue: fallback for Total Unpaid if late-letters API fails
  ///    - totalUnpaidRentLeases: count of leases with unpaid rent → "Total Properties with Unpaid Rent"
  ///    - totalActiveLeases: count of active leases → "Total Active Leases" and percentage denominator
  ///
  /// 2) Preview late letters API (GET /api/leases/preview-late-letters/{adminId})
  ///    - total_past_due_amount: source of truth for past-due $ → "Total Unpaid"
  ///    - data[]: list of late letter previews (tenant_name, rental_address, total_amount per lease)
  ///
  /// Summary lines on chart:
  /// - Unpaid Rent: (totalUnpaidRentLeases / totalActiveLeases) * 100
  /// - Total Unpaid: total_past_due_amount (from preview-late-letters)
  /// - Total Properties with Unpaid Rent: totalUnpaidRentLeases
  /// - Total Active Leases: totalActiveLeases
  Future<void> _fetchUnpaidRentData() async {
    // 1. Admin identifier required
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? staffId = prefs.getString('staff_id');
    String? token = prefs.getString('token');
    if (adminId == null || adminId.isEmpty) return;

    try {
      setState(() => _loading = true);
      final headers = {
        'authorization': 'CRM $token',
        'id': 'CRM ${staffId ?? adminId}',
        'Content-Type': 'application/json',
      };

      // 2. Call balance API + preview-late-letters API (Total Unpaid = total_past_due_amount)
      final balanceFuture = apiGet(
        Uri.parse('${Api_url}/api/payment/admin_balance/$adminId'),
        headers: headers,
      );
      final lateLettersFuture = apiGet(
        Uri.parse('${Api_url}/api/leases/preview-late-letters/$adminId'),
        headers: headers,
      );
      final results = await Future.wait([balanceFuture, lateLettersFuture]);
      final balanceResponse = results[0];
      final lateLettersResponse = results[1];

      if (balanceResponse.statusCode == 200) {
        final balanceJson = json.decode(balanceResponse.body);
        if (balanceJson['statusCode'] == 200) {
          final balanceData =
              balanceJson['data'] as Map<String, dynamic>? ?? {};
          final totalRentPastDue = (balanceData['totalRentPastDue'] is num)
              ? (balanceData['totalRentPastDue'] as num).toDouble()
              : 0.0;
          final totalUnpaidRentLeases =
              balanceData['totalUnpaidRentLeases'] as int? ?? 0;
          final totalActiveLeases =
              balanceData['totalActiveLeases'] as int? ?? 0;

          // Total Unpaid: use preview-late-letters API total_past_due_amount (source of truth for past-due $)
          double totalUnpaidAmount = totalRentPastDue;
          if (lateLettersResponse.statusCode == 200) {
            try {
              final lateJson = json.decode(lateLettersResponse.body);
              if (lateJson['statusCode'] == 200 &&
                  lateJson['total_past_due_amount'] != null) {
                final t = lateJson['total_past_due_amount'];
                if (t is num) {
                  totalUnpaidAmount = t.toDouble();
                } else if (t is String) {
                  totalUnpaidAmount = double.tryParse(t) ?? totalRentPastDue;
                }
              }
            } catch (_) {}
          }

          final percentage = totalActiveLeases > 0
              ? ((totalUnpaidRentLeases / totalActiveLeases) * 100)
              : 0.0;

          final totalRentalPropertyForChart = totalActiveLeases;

          // Summary for logs

          if (mounted) {
            setState(() {
              _totalProperties = totalRentalPropertyForChart;
              _totalUnpaidAmount = totalUnpaidAmount;
              _totalUnpaidRentLeases = totalUnpaidRentLeases;
              _percentage = percentage;
              _loading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      logError('Error fetching unpaid rent data: $e');
    }
    if (mounted) {
      setState(() {
        _totalProperties = 0;
        _totalUnpaidAmount = 0;
        _totalUnpaidRentLeases = 0;
        _percentage = 0;
        _loading = false;
      });
    }
  }

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The one fetch initState makes.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    await _fetchUnpaidRentData();
  }

  @override
  void initState() {
    super.initState();
    _fetchUnpaidRentData();
  }

  Widget _legendRow(Color bulletColor, String text, TextStyle subTextStyle) {
    final isNarrow = MediaQuery.of(context).size.width < 400;
    final fontSize = isNarrow ? 11.0 : 14.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
       // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 5, backgroundColor: bulletColor),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                text,
                style: subTextStyle.copyWith(fontSize: fontSize),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lives inside a dashboard card, so the compact offline state is
    // what fits here — the page around it stays usable.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    final cardTextStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: blueColor,
    );
    final subTextStyle = TextStyle(
      color: const Color.fromRGBO(16, 24, 40, 0.7),
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    if (_loading) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child:  SizedBox(
          height: 120,
          child: Center(child: SpinKitFadingCircle(
            color: blueColor,
            size: 30,
          )),
        ),
      );
    }

    // Match web: unpaid (large) drawn first from top, then paid (small). Colors: unpaid = dark blue, paid = light blue.
    final unpaidValue = _percentage.clamp(0.0, 100.0);
    final paidValue = (100.0 - _percentage).clamp(0.0, 100.0);
    final List<PieChartSectionData> pieChartData = [
      PieChartSectionData(
        color: const Color.fromRGBO(40, 60, 95, 1),
        value: unpaidValue > 0 ? unpaidValue : 1,
        title: '',
        radius: 50,
      ),
      PieChartSectionData(
        color: const Color.fromRGBO(90, 134, 213, 1),
        value: paidValue > 0 ? paidValue : 1,
        title: '',
        radius: 50,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: pieChartData,
                    centerSpaceRadius: 0,
                    sectionsSpace: 2,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(
                      touchCallback:
                          (FlTouchEvent event, PieTouchResponse? response) {
                        setState(() {
                          if (event.isInterestedForInteractions &&
                              response?.touchedSection != null) {
                            _touchedSectionIndex =
                                response!.touchedSection!.touchedSectionIndex;
                          } else {
                            _touchedSectionIndex = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
                if (_touchedSectionIndex != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(40, 60, 95, 0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _touchedSectionIndex == 0
                          ? 'Unpaid Rent: ${_percentage.toStringAsFixed(1)}%'
                          : 'Paid: ${(100.0 - _percentage).clamp(0.0, 100.0).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Percentage of Unpaid Rent',
                  style: cardTextStyle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 8),
                _legendRow(
                    const Color.fromRGBO(40, 60, 95, 1),
                    'Unpaid Rent: ${_percentage.toStringAsFixed(1)}%',
                    subTextStyle),
                _legendRow(
                    const Color.fromRGBO(40, 60, 95, 1),
                    'Total Unpaid: ${formatMoney(_totalUnpaidAmount)}',
                    subTextStyle),
                _legendRow(
                    Colors.grey.shade700,
                    'Properties with Unpaid Rent: $_totalUnpaidRentLeases',
                    subTextStyle),
                _legendRow(Colors.grey.shade400,
                    'Total Active Leases: $_totalProperties', subTextStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = blueColor.withOpacity(.9)
      ..style = PaintingStyle.fill;
    final paint2 = Paint()
      ..color = blueColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height), -0.5, 2, true, paint1);
    canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height), 1.5, 1, true, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ExpandablePaymentCard extends StatefulWidget {
  final String name;
  final String address;
  final String amount;

  const ExpandablePaymentCard({
    Key? key,
    required this.name,
    required this.address,
    required this.amount,
  }) : super(key: key);

  @override
  State<ExpandablePaymentCard> createState() => _ExpandablePaymentCardState();
}

class _ExpandablePaymentCardState extends State<ExpandablePaymentCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final cardTextStyle =
        TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: blueColor);
    final subTextStyle = TextStyle(
        color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14);

    return GestureDetector(
      onTap: () => setState(() => expanded = !expanded),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: expanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: blueColor,
                      ),
                      const SizedBox(width: 8),
                      Text(widget.name, style: cardTextStyle),
                      const Spacer(),
                      Text('${widget.amount}', style: cardTextStyle),
                    ],
                  ),
                  Divider(thickness: 2),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rental Address',
                          style: subTextStyle.copyWith(
                              color: blueColor, fontWeight: FontWeight.bold)),
                      Text('Action',
                          style: subTextStyle.copyWith(
                              color: blueColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.address, style: subTextStyle),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            height: 30,
                            width: 30,
                            child: Icon(Icons.check, color: blueColor),
                          ),
                          SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            height: 30,
                            width: 30,
                            child: Icon(Icons.recycling_outlined,
                                color: blueColor),
                          ),
                          SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            height: 30,
                            width: 30,
                            child: Icon(Icons.calendar_month_outlined,
                                color: blueColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              )
            : Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: blueColor,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.name, style: cardTextStyle),
                  const Spacer(),
                  Text('${widget.amount}', style: cardTextStyle),
                ],
              ),
      ),
    );
  }
}
