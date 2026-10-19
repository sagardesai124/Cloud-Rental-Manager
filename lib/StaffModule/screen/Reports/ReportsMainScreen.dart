import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/AccountTotals.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CompletedWorkOrders.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/ConvenienceFee.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/CustomReportBuilder.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/DelinquentTenants.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/ExpiringLeases.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Expiring_Insurance.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Home_System_Report.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/InsurancePremiumReport.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/LoanSummaryReport.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/mortgage/mortgageTable.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/OpenWorkOrders.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Payment_Exception.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/PortfolioOverviewReport.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/PropertyRevenueReport.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/RentersInsurance.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ReopenWorkorder.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/dailytransaction.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/rentalownerreport.dart';
import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/LeaseRenewalReport.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/constant/constant.dart';


import 'package:three_zero_two_property/StaffModule/screen/Reports/ReportScreens/Rent_collection.dart';
import 'ReportScreens/OutstandingLeaseBalance.dart';
import '../../../widgets/titleBar.dart';
import 'ReportScreens/Recurring_Payments_Configuration_table.dart';
import 'ReportScreens/RentRollReport.dart';


class ReportsMainScreen extends StatefulWidget {
  @override
  State<ReportsMainScreen> createState() => _ReportsMainScreenState();
}

class _ReportsMainScreenState extends State<ReportsMainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Reports",
        dropdown: false,
      ),
      appBar: widget_302_Staff.App_Bar(context: context),
      body: NarrowScreenLayout(),
      // LayoutBuilder(
      //   builder: (context, constraints) {
      //     if (constraints.maxWidth > 500) {
      //       return WideScreenLayout();
      //     } else {
      //       return NarrowScreenLayout();
      //     }
      //   },
      // ),
    );
  }
}

class WideScreenLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          titleBar(
            title: 'Reports',
            width: MediaQuery.of(context).size.width * .91,
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: ReportCard(
                    title: "Renter's Insurance",
                    description: "Produces a list of all insured units",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RentersInsurance()),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ReportCard(
                    title: "Completed Work Orders",
                    description: "Report of all completed Work Orders",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CompletedWorkOrders()),
                      );
                      // Navigate to the appropriate screen
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: ReportCard(
                    title: "Delinquent Tenants",
                    description:
                        "Tenants with an outstanding ledger balance as of a specific date",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => DelinquentTenants()),
                      );
                      // Navigate to the appropriate screen
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ReportCard(
                    title: "Open Work Orders",
                    description:
                        "Report of all Work Orders not yet in a complete state",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => OpenWorkOrders()),
                      );
                      // Navigate to the appropriate screen
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: ReportCard(
                    title: "Expiring Leases",
                    description:
                        "Lists all leases that will end during a specified timeframe",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ExpiringLeases()),
                      );
                      // Navigate to the appropriate screen
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12.0),
                              topRight: Radius.circular(12.0),
                            ),
                          ),
                          padding: EdgeInsets.all(17.0),
                          child: Text(
                            'title',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: blueColor,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class NarrowScreenLayout extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: SingleChildScrollView(
//         child: Column(
//           children: [
//             titleBar(
//               title: 'Reports',
//               width: MediaQuery.of(context).size.width * .91,
//             ),
// ReportCard(
//   title: "Renter's Insurance",
//   description: "Produces a list of all insured units",
//   onTap: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => RentersInsurance()),
//     );
//   },
// ),
// SizedBox(height: 16),
// ReportCard(
//   title: "Expiring Leases",
//   description:
//       "Lists all leases that will end during a specified timeframe",
//   onTap: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => ExpiringLeases()),
//     );
//     // Navigate to the appropriate screen
//   },
// ),
// SizedBox(height: 16),
// ReportCard(
//   title: "Delinquent Tenants",
//   description:
//       "Tenants with an outstanding ledger balance as of a specific date",
//   onTap: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => DelinquentTenants()),
//     );
//     // Navigate to the appropriate screen
//   },
// ),
// SizedBox(height: 16),
// ReportCard(
//   title: "Open Work Orders",
//   description:
//       "Report of all Work Orders not yet in a complete state",
//   onTap: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => OpenWorkOrders()),
//     );
//     // Navigate to the appropriate screen
//   },
// ),
// SizedBox(height: 16),
// ReportCard(
//   title: "Completed Work Orders",
//   description: "Report of all completed Work Orders",
//   onTap: () {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//           builder: (context) => CompletedWorkOrders()),
//     );
//     // Navigate to the appropriate screen
//   },
// ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class NarrowScreenLayout extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     int crossAxisCount = screenWidth > 600 ? 3 : 2;
//     return Column(
//       children: [
//         Expanded(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: GridView(
//               scrollDirection: Axis.horizontal,
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: crossAxisCount,
//                 childAspectRatio: 0.7, // Adjust the aspect ratio as needed
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//               ),
//               children: [
//                 ReportCard(
//                   title: "Renter's Insurance",
//                   description: "Produces a list of all insured units",
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => RentersInsurance()),
//                     );
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 ReportCard(
//                   title: "Expiring Leases",
//                   description:
//                       "Lists all leases that will end during a specified timeframe",
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => ExpiringLeases()),
//                     );
//                     // Navigate to the appropriate screen
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 ReportCard(
//                   title: "Delinquent Tenants",
//                   description:
//                       "Tenants with an outstanding ledger balance as of a specific date",
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => DelinquentTenants()),
//                     );
//                     // Navigate to the appropriate screen
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 ReportCard(
//                   title: "Open Work Orders",
//                   description:
//                       "Report of all Work Orders not yet in a complete state",
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => OpenWorkOrders()),
//                     );
//                     // Navigate to the appropriate screen
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 ReportCard(
//                   title: "Completed Work Orders",
//                   description: "Report of all completed Work Orders",
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => CompletedWorkOrders()),
//                     );
//                     // Navigate to the appropriate screen
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class ReportCard extends StatelessWidget {
//   final String title;
//   final String description;
//   final VoidCallback onTap;

//   ReportCard(
//       {required this.title, required this.description, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       child: Card(
//         elevation: 2,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(15.0),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Container(
//               height: 50,
//               decoration: BoxDecoration(
//                 color: blueColor,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(12.0),
//                   topRight: Radius.circular(12.0),
//                 ),
//               ),
//               padding: EdgeInsets.all(17.0),
//               child: Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Text(
//                 description,
//                 style: TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w500,
//                     color: blueColor),
//                 textAlign: TextAlign.start,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class NarrowScreenLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 20,
            ),
            Padding(padding: EdgeInsets.only(left: 14, right: 14), child: titleBar(
              title: 'Reports',
              width: MediaQuery.of(context).size.width * .98,
            ),),
            SizedBox(height: 10,),
            // Expanded(
            //   child: Padding(
            //     padding: const EdgeInsets.only(left: 10, right: 10),
            //     child: GridView.builder(
            //       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            //         mainAxisExtent: 170,
            //         crossAxisCount: crossAxisCount,
            //         childAspectRatio: 1.0, // Adjust the aspect ratio as needed
            //         crossAxisSpacing: 8,
            //         mainAxisSpacing: 8,
            //       ),
            //       itemCount: reportCards.length,
            //       itemBuilder: (context, index) {
            //         return ReportCard(
            //           title: reportCards[index].title,
            //           description: reportCards[index].description,
            //           onTap: () {
            //             Navigator.push(
            //               context,
            //               MaterialPageRoute(
            //                 builder: (context) => reportCards[index].destination,
            //               ),
            //             );
            //           },
            //         );
            //       },
            //     ),
            //   ),
            // ),
            ReportScreen()
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  ReportCard(
      {required this.title, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: blueColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize:
                            MediaQuery.of(context).size.width < 500 ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 16.0, top: 16, right: 10, bottom: 6),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 500 ? 13 : 15,
                  fontWeight: FontWeight.w500,
                  color: blueColor,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCardModel {
  final String title;
  final String description;
  final Widget destination;

  ReportCardModel(
      {required this.title,
      required this.description,
      required this.destination});
}

List<ReportCardModel> reportCards = [
  ReportCardModel(
    title: "Renter's Insurance",
    description: "Produces a list of all insured units",
    destination: RentersInsurance(),
  ),
  ReportCardModel(
    title: "Expiring Insurance",
    description:
        "Report of Renter's Insurance expiring within the selected time period",
    destination: ExpiringInsurance(),
  ),
  ReportCardModel(
    title: "Expiring Leases",
    description: "Lists all leases that will end during a specified timeframe",
    destination: ExpiringLeases(),
  ),
  ReportCardModel(
    title: "Delinquent Tenants",
    description:
        "Tenants with an outstanding ledger balance as of a specific date",
    destination: DelinquentTenants(),
  ),
  ReportCardModel(
    title: "Open Work Orders",
    description: "Report of all Work Orders not yet in a complete state",
    destination: OpenWorkOrders(),
  ),
  ReportCardModel(
    title: "Completed Work Orders",
    description: "Report of all completed Work Orders",
    destination: CompletedWorkOrders(),
  ),
  ReportCardModel(
    title: "Daily Transaction Report",
    description: "Report of daily transaction",
    destination: DailyTransactions(),
  ),
  ReportCardModel(
    title: "Rental Owner Report",
    description: "Report of rental owner transaction",
    destination: RentalOwnerReports(),
  ),
  ReportCardModel(
    title: "Account Totals Report",
    description: "Report of account totals",
    destination: AccountTotalsReports(),
  ),
  ReportCardModel(
    title: "Payment Exception Report",
    description: "Report of payments that are not attached to tenant",
    destination: PaymentExceptionReports(),
  ),
  ReportCardModel(
    title: "Recurring Payments Configuration",
    description: "Report shows all leases recurring payments configured",
    destination: Recurring_Payments_Configuration_Report(),
  ),
  ReportCardModel(
    title: "Convenience Fee Override",
    description: "Report shows all leases with convenience fee override",
    destination: ConvenienceFeeReports(),
  ),
  ReportCardModel(
    title: "Rent Roll Report",
    description: "Report shows all leases with convenience fee override",
    destination: RentersInsurances(),
  ),
  ReportCardModel(
    title: "Lease Renewal",
    description: "Report of leases ending and month-to-month leases with renewal details",
    destination: LeaseRenewalReportScreen(),
  ),
];

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  Widget sectionTitle(String title, String svgPath, String subtitle) {
    return Column(
      children: [
        ListTile(
          visualDensity:
              const VisualDensity(vertical: -4), // Reduce vertical spacing
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          leading: Container(
            margin: EdgeInsets.only(left: 10, top: 5),
            child: SvgPicture.asset(
              svgPath,
              width: 25,
              height: 25,
              // colorFilter: const ColorFilter.mode(Colors.indigo, BlendMode.srcIn),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
                fontSize: 14, color: blueColor, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w200,
                  fontSize: 11)),
        ),
        Divider()
      ],
    );
  }

  Widget reportItem(String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const Divider(height: 16),
          ],
        ),
      ),
    );
  }

  Widget reportSection(String svgIconPath, String title,
      List<Map<String, dynamic>> items, String subtitle, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        //  color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(title, svgIconPath, subtitle),
          const SizedBox(height: 5),
          ...items
              .map((item) => reportItem(
                    item['title']!,
                    item['subtitle']!,
                    () {
                      // Handle navigation based on title or a new field like `route`
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => item["navigate"],
                        ),
                      );
                    },
                  ))
              .toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 10,
          ),
          reportSection(
              'assets/images/entypo_bar-graph.svg',
              'Financial Reports',
              [
                {
                  'title': 'Rent Collection Report',
                  'subtitle': 'Rent collection due by property',
                  "navigate": Rent_collection()
                },
                {
                  'title': 'Daily Transaction Report',
                  'subtitle': 'Listing of all transaction summarized by day',
                  "navigate": DailyTransactions()
                },
                {
                  'title': 'Rental Owner Report',
                  'subtitle':
                      'Listing of all transaction summarized by day owner',
                  "navigate": RentalOwnerReports()
                },
                {
                  'title': 'Account Totals Report',
                  'subtitle':
                      'Listing of all transactions summarized by account and rental owner',
                  "navigate": AccountTotalsReports()
                },
                {
                  'title': 'Payment Exception Report',
                  'subtitle': 'Transaction list not assigned to a tenant',
                  "navigate": PaymentExceptionReports()
                },
                {
                  'title': 'Recurring Payments Configuration',
                  'subtitle': 'All configured recurring payments by lease',
                  "navigate": Recurring_Payments_Configuration_Report()
                },
                {
                  'title': 'Rent Roll Report',
                  'subtitle': 'Rent balance due by property and tenants',
                  "navigate": RentersInsurances()
                },
                {
                  'title': 'Outstanding Lease Balance Report',
                  'subtitle':
                      'Detailed breakdown of outstanding lease balances with aging analysis',
                  "navigate": OutstandingLeaseBalance()
                },
                {
                  'title': 'Property Revenue Report',
                  'subtitle':
                      'Compare property revenue between current and previous periods',
                  "navigate": PropertyRevenueReport()
                },
                {
                  'title': 'Portfolio Overview',
                  'subtitle': 'KPI overview of your property portfolio',
                  "navigate": PortfolioOverviewReport(),
                },
                {
                  'title': 'Loan Summary Report',
                  'subtitle': 'Summary of all loans with balance and properties',
                  "navigate": Loansummaryreport()
                },
                {
                  'title': 'Mortgages',
                  'subtitle':
                      'Mortgages by property — balances, payoff history, and details',
                  "navigate": MortgageTable()
                },
              ],
              "Track payments, transactions, and owner accounts.",
              context),
          SizedBox(
            height: 10,
          ),
          reportSection(
              'assets/images/mingcute_clipboard-fill.svg',
              'Maintenance & Work Orders',
              [
                {
                  'title': 'Open Work Orders',
                  'subtitle': 'Work order not yet in complete state',
                  "navigate": OpenWorkOrders()
                },
                {
                  'title': 'Completed Work Orders',
                  'subtitle': 'All completed work orders',
                  "navigate": CompletedWorkOrders()
                },
                {
                  'title': 'Reopen Work Orders',
                  'subtitle': 'Work orders on hold with future reopen dates',
                  "navigate": ReopenWorkorder(isStaffMode: true)
                },
                {
                  'title': 'Home System Report',
                  'subtitle': 'Home system report',
                  "navigate": HomeSystemReportScreen()
                },
              ],
              "Fix it fast, document it all",
              context),
          SizedBox(
            height: 10,
          ),
          reportSection(
              'assets/images/solar_shield-up-bold.svg',
              'Insurance',
              [
                {
                  'title': 'Renter’s Insurance',
                  'subtitle':
                      'Detailed listing of all renter’s insurance policies',
                  "navigate": RentersInsurance()
                },
                {
                  'title': 'Expiring Insurance',
                  'subtitle':
                      'Renter’s insurance policies expiring within the selected time period',
                  "navigate": ExpiringInsurance()
                },
                {
                  'title': 'Insurance Premium Report',
                  'subtitle': 'Compare property insurance premiums across selected years/spans',
                  "navigate": InsurancePremiumReport()
                },
              ],
              "Coverage at a glance",
              context),
          SizedBox(
            height: 10,
          ),
          reportSection(
              'assets/images/fontisto_person.svg',
              'Lease & Tenant Management',
              [
                {
                  'title': 'Expiring Leases',
                  'subtitle':
                      'List of all leases that will end during a specified timeframe',
                  "navigate": ExpiringLeases()
                },
                {
                  'title': 'Delinquent Tenants',
                  'subtitle':
                      'Tenants with an outstanding ledger balance as of a specified date',
                  "navigate": DelinquentTenants()
                },
                // Web shows Lease Renewal to Staff too (Reports.jsx →
                // /staff/staffleaserenewalreport); same card as Admin.
                {
                  'title': 'Lease Renewal',
                  'subtitle':
                      'Report of leases ending and month-to-month leases with renewal details',
                  "navigate": LeaseRenewalReportScreen()
                },
                {
                  'title': 'Convenience Fee Override',
                  'subtitle':
                      'All leases with tenant that have convenience fee override',
                  "navigate": ConvenienceFeeReports()
                },
              ],
              "Active leases and tenant solutions.",
              context),
          SizedBox(
            height: 10,
          ),
          reportSection(
              'assets/images/graph - Copy.svg',
              'Custom Reports',
              [
                {
                  'title': 'Custom Report Builder',
                  'subtitle': 'Choose columns, historic values, and filters to build a custom lease report',
                  "navigate": CustomReportBuilder()
                },
              ],
              "",
              context),
              SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }
}
