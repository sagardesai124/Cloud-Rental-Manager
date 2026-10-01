import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:three_zero_two_property/screens/Dashboard/RentPastDueReport.dart';
import '../../widgets/appbar.dart';
import '../../constant/constant.dart';
import '../../widgets/barchart.dart';
import '../../widgets/fl_chart.dart';
import 'cronjob_payment_table.dart';
import 'dashboard_leaseExpiring.dart';
import 'dashbordpolices_table.dart';
import 'dashboard_delinquent_tenants.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Properties_table.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/Tenants_table.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/Applicants_table.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Workorder_table.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

class DashboardAdminSample extends StatefulWidget {
  List<int> countList = [];
  double currentMonthRentDue = 0.0;
  double lastMonthRentDue = 0.0;
  double currentMonthRentPaid = 0.0;
  double lastMonthRentPaid = 0.0;
  double totalRentPastDue = 0.0;
  // Called after a card's list closes, so the dashboard can reload its counts.
  final VoidCallback? onReturn;
  DashboardAdminSample(
      {super.key,
      required this.countList,
      required this.currentMonthRentDue,
      required this.lastMonthRentDue,
      required this.currentMonthRentPaid,
      required this.lastMonthRentPaid,
      required this.totalRentPastDue,
      this.onReturn});
  @override
  State<DashboardAdminSample> createState() => _DashboardAdminSampleState();
}

class _DashboardAdminSampleState extends State<DashboardAdminSample> {
  String selectedRentType = 'Rent Due';

  // Anything added or removed in a card's list changes that card's number,
  // so ask the dashboard to reload its counts once the list closes.
  void _afterCardReturn() {
    if (!mounted) return;
    widget.onReturn?.call();
  }

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

  final GlobalKey _dropdownKey = GlobalKey();

  // Helper function to format count as two digits with leading zero if needed
  String _formatCount(int count) {
    if (count >= 0 && count < 10) {
      return count.toString().padLeft(2, '');
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromRGBO(241, 244, 250, 1),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                double screenWidth = constraints.maxWidth;
                double titleFontSize = screenWidth < 600
                    ? 18
                    : (screenWidth < 900 ? 22 : (screenWidth < 1200 ? 26 : 30));
                return Text(' Dashboard',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: titleFontSize));
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                double screenWidth = constraints.maxWidth;
                int crossAxisCount;
                double childAspectRatio;
                double spacing;

                // Responsive grid configuration
                if (screenWidth < 600) {
                  // Mobile: 2 columns
                  crossAxisCount = 2;
                  childAspectRatio = 2.2;
                  spacing = 10;
                } else if (screenWidth < 900) {
                  // Small tablet: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 2.5;
                  spacing = 12;
                } else if (screenWidth < 1200) {
                  // Medium tablet: 4 columns
                  crossAxisCount = 4;
                  childAspectRatio = 2.8;
                  spacing = 15;
                } else {
                  // Large tablet/desktop: 5 columns
                  crossAxisCount = 5;
                  childAspectRatio = 3.0;
                  spacing = 18;
                }

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _dashboardCard(
                      "assets/icons/Group 1.svg",
                      _formatCount(widget.countList[0]),
                      'Properties  ->',
                      () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PropertiesTable()));
                        _afterCardReturn();
                      },
                    ),
                    _dashboardCard(
                      "assets/icons/Frame.svg",
                      _formatCount(widget.countList[1]),
                      'Tenants  ->',
                      () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Tenants_table()));
                        _afterCardReturn();
                      },
                    ),
                    _dashboardCard(
                      "assets/icons/Vector.svg",
                      _formatCount(widget.countList[2]),
                      'Applicants  ->',
                      () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Applicants_table()));
                        _afterCardReturn();
                      },
                    ),
                    _dashboardCard(
                      "assets/icons/Vector (1).svg",
                      _formatCount(widget.countList[3]),
                      'Vendors  ->',
                      () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const TabBarExample(initialTab: 'Vendors')));
                        _afterCardReturn();
                      },
                    ),
                    _dashboardCard(
                      "assets/icons/Frame1.svg",
                      _formatCount(widget.countList[4]),
                      'Work Orders ->',
                      () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Workorder_table()));
                        _afterCardReturn();
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 15),
            _rentDataSection(context),
            FlChartApp(
              data: data,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 0, right: 8),
              child: Barchart(),
            ),
            const SizedBox(height: 24),
            // Web order (dashboardConfig.js): Payments (Last 7 Days + Failed)
            // first, then Insurance, then Leases.
            // Sections sit 8dp apart (DashboardPaginationFooter.kSectionGap).
            // Each table's footer supplies its own 4dp of breathing room, so a
            // 20dp gap here stacked on top of that and left a visible hole.
            Cronjob_payment_table(),
            const SizedBox(height: 8),
            Dashboard_Policy_Table(),
            const SizedBox(height: 8),
            Dashboard_leaseExpiring(),
            const SizedBox(height: 8),
            // Web parity: DelinquentTenantsWidget (CRM-4501) is Admin-only —
            // the Staff dashboard does not carry it. Placed last so it closes
            // the table stack rather than splitting Payments from Insurance.
            const DashboardDelinquentTenants(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = constraints.maxWidth;
                    double imageHeight =
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
                          height: imageHeight,
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

  List<Map<String, dynamic>> data = [
    {"month": "Oct", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Nov", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Dec", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Jan", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Feb", "rentals": 3, "leases": 0, "occupiedPercentage": 0},
    {"month": "Mar", "rentals": 6, "leases": 0, "occupiedPercentage": 0},
    {"month": "Apr", "rentals": 6, "leases": 0, "occupiedPercentage": 0},
    {"month": "May", "rentals": 6, "leases": 0, "occupiedPercentage": 0},
    {"month": "Jun", "rentals": 7, "leases": 0, "occupiedPercentage": 0},
    {"month": "Jul", "rentals": 7, "leases": 0, "occupiedPercentage": 0},
    {"month": "Aug", "rentals": 8, "leases": 1, "occupiedPercentage": 12.5},
    {"month": "Sep", "rentals": 8, "leases": 9, "occupiedPercentage": 102.5},
  ];
  Widget _dashboardCard(
      String icon, String number, String label, VoidCallback onTap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;
        double numberFontSize;
        double labelFontSize;
        double horizontalPadding;
        double verticalPadding;
        double spacing;

        // Consistent responsive sizing for dashboard cards
        if (screenWidth < 600) {
          // Mobile - keep original sizing
          numberFontSize = 16;
          labelFontSize = screenWidth < 400 ? 13 : 14;
          horizontalPadding = 5;
          verticalPadding = 10;
          spacing = 12;
        } else if (screenWidth < 900) {
          // Small tablet - bigger text for better readability
          numberFontSize = 20;
          labelFontSize = 18;
          horizontalPadding = 8;
          verticalPadding = 12;
          spacing = 14;
        } else if (screenWidth < 1200) {
          // Medium tablet - bigger text for better readability
          numberFontSize = 22;
          labelFontSize = 20;
          horizontalPadding = 10;
          verticalPadding = 14;
          spacing = 16;
        } else {
          // Large tablet/desktop - bigger text for better readability
          numberFontSize = 24;
          labelFontSize = 22;
          horizontalPadding = 12;
          verticalPadding = 16;
          spacing = 18;
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
              ],
            ),
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: verticalPadding),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: SvgPicture.asset(icon, color: blueColor),
                ),
                SizedBox(width: spacing),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(number,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: numberFontSize,
                            color: blueColor)),
                    Text(label,
                        style: TextStyle(
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rentDataSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = constraints.maxWidth;

        // Consistent responsive font sizing across dashboard
        double titleFont = screenWidth < 600
            ? 18
            : (screenWidth < 900 ? 22 : (screenWidth < 1200 ? 26 : 30));
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
                              builder: (context) =>
                                  RentPastDueReports(title: 'Rent Past Due'),
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
                              style: TextStyle(
                                fontSize: 18,
                                color: const Color(0xFF7B7F87),
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
                            // Text(
                            //   selectedRentType == 'Rent Due'
                            //       ? '\$${widget.currentMonthRentDue}'
                            //       : selectedRentType == 'Rent Paid'
                            //           ? '\$${widget.currentMonthRentPaid}'
                            //           : '\$2000.00',
                            //   style: TextStyle(
                            //     fontSize: valueFont,
                            //     color: const Color(0xFF7B7F87),
                            //     fontWeight: FontWeight.w400,
                            //   ),
                            // ),
                            Text(
                              selectedRentType == 'Rent Due'
                                  ? formatCurrency(widget.currentMonthRentDue)
                                  : selectedRentType == 'Rent Paid'
                                      ? formatCurrency(
                                          widget.currentMonthRentPaid)
                                      : formatCurrency(2000.00),
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
                            // Text(
                            //   selectedRentType == 'Rent Due'
                            //       ? '\$${widget.lastMonthRentDue}'
                            //       : selectedRentType == 'Rent Paid'
                            //           ? '\$${widget.lastMonthRentPaid}'
                            //           : '\$250.00',
                            //   style: TextStyle(
                            //     fontSize: valueFont,
                            //     color: const Color(0xFF7B7F87),
                            //     fontWeight: FontWeight.w400,
                            //   ),
                            // ),
                            Text(
                              selectedRentType == 'Rent Due'
                                  ? formatCurrency(widget.lastMonthRentDue)
                                  : selectedRentType == 'Rent Paid'
                                      ? formatCurrency(widget.lastMonthRentPaid)
                                      : formatCurrency(250.00),
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

  static Widget _propertySummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Property Summary',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _propertyLineChart(),
            ),
          ),
          const SizedBox(height: 10),
          const Text('3 of 5 units currently occupied - 60%'),
        ],
      ),
    );
  }

  static Widget _propertyLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 2),
              FlSpot(1, 4),
              FlSpot(2, 3),
              FlSpot(3, 7),
              FlSpot(4, 6),
              FlSpot(5, 2),
              FlSpot(6, 3),
            ],
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  static Widget _totalRevenueSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Revenue',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _revenueBarChart(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dot(Colors.blue[900]!),
              const SizedBox(width: 4),
              const Text('Current Year'),
              const SizedBox(width: 16),
              _dot(Colors.blue[200]!),
              const SizedBox(width: 4),
              const Text('Last Year'),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _revenueBarChart() {
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
              x: 0, barRods: [BarChartRodData(toY: 8, color: Colors.blue)]),
          BarChartGroupData(
              x: 1, barRods: [BarChartRodData(toY: 12, color: Colors.blue)]),
          BarChartGroupData(
              x: 2, barRods: [BarChartRodData(toY: 6, color: Colors.blue)]),
          BarChartGroupData(
              x: 3, barRods: [BarChartRodData(toY: 14, color: Colors.blue)]),
          BarChartGroupData(
              x: 4, barRods: [BarChartRodData(toY: 10, color: Colors.blue)]),
          BarChartGroupData(
              x: 5, barRods: [BarChartRodData(toY: 5, color: Colors.blue)]),
          BarChartGroupData(
              x: 6, barRods: [BarChartRodData(toY: 7, color: Colors.blue)]),
        ],
      ),
    );
  }

  static Widget _leasesExpiringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leases Expiring In The Next 60 Days',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: blueColor, fontSize: 18)),
        const SizedBox(height: 10),
        _infoCard('742 Evergreen Terrace', 'Homer Simpson', '05/12/2024'),
      ],
    );
  }

  static Widget _insuranceExpiringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Renter's Insurance Policies Expiring Within 90 days",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: blueColor, fontSize: 18)),
        const SizedBox(height: 10),
        _infoCard('742 Evergreen Terrace', 'Homer Simpson', '05/12/2024'),
      ],
    );
  }

  static Widget _infoCard(String address, String name, String date) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(address, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tenant Name\n$name', style: const TextStyle(fontSize: 13)),
              Text('Expiration Date\n$date',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _paymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Last 7 days',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: blueColor, fontSize: 18)),
        const SizedBox(height: 10),
        _paymentCard('Zack Wheeler', '.76', '4 Main street'),
        _paymentCard('Zack Wheeler', '.76', '4 Main street'),
      ],
    );
  }

  static Widget _paymentCard(String name, String amount, String address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rental Address\n$address',
                  style: const TextStyle(fontSize: 13)),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue[900]),
                  const SizedBox(width: 8),
                  Icon(Icons.refresh, color: Colors.blue[900]),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today, color: Colors.blue[900]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
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
        ),
        settings: RouteSettings(
          arguments: {'monthType': monthType, 'chargeType': chargeType},
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(
                        color: const Color(0xFFE5E5E5),
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
