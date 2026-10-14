import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/User%20Permission/UserPermissionScreen.dart';
import 'package:three_zero_two_property/screens/Profile/ContactUsScreen.dart';
import 'package:three_zero_two_property/screens/Profile/Profile_screen.dart';
import 'package:three_zero_two_property/screens/Login/login_screen.dart';
import 'package:three_zero_two_property/screens/activity/activity_table.dart';
import '../constant/constant.dart';
import '../provider/notification_provider.dart';
import '../screens/notifications/notifications.dart';
import 'package:badges/badges.dart' as badges;
import 'package:package_info_plus/package_info_plus.dart';

class widget_302 {
  /// True for a Staff login. Staff reach this shared app bar from shared
  /// screens (e.g. Settings); the permission matrix is Admin-only, as on web.
  static bool _isStaffUser = false;

  static App_Bar({
    var suffixIcon,
    var leading,
    bool? isPlanPageActive = false,
    bool? isProfilePageActive = false,
    bool? isUserPermitePageActive = false,
    bool? isSettingPageActive = false,
    var fontweight,
    List<Widget>? actions,
    var arrowNearText,
    required BuildContext context,
    String? comname,
  }) {
    Provider.of<NotificationProvider>(context, listen: false)
        .fetchNotifications(context);
    return PreferredSize(
      preferredSize: Size.fromHeight(60),
      child: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 00,
        toolbarHeight: MediaQuery.of(context).size.width < 500
            ? 60
            : 80, // Adjust height for tablet
        title: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 350) {
              return Row(
                children: [
                  // Image.asset(
                  //   'assets/images/applogo.png',
                  //   height: 40,
                  //   width: 40,
                  // ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getCompanyNameFromSharedPreferences(),
                      builder: (context, snapshot) {
                        return Center(
                          child: Text(
                            snapshot.hasData ? snapshot.data! : "Company Name",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  // Image.asset(
                  //   'assets/images/logo.png',
                  //   width: 200,
                  //   fit: BoxFit.fill,
                  // ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getCompanyNameFromSharedPreferences(),
                      builder: (context, snapshot) {
                        return Center(
                          child: Text(
                            snapshot.hasData ? snapshot.data! : "Company Name",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
        actions: [
          // InkWell(
          //   // onTap: () {
          //   //   if (isPlanPageActive != true) {
          //   //     Navigator.of(context).push(MaterialPageRoute(
          //   //         builder: (context) => getPlanDetailScreen()));
          //   //   }
          //   // },
          //   child: Container(
          //     width: 150,
          //     margin: const EdgeInsets.symmetric(vertical: 12),
          //     decoration: BoxDecoration(
          //       color: blueColor,
          //       borderRadius: BorderRadius.circular(5),
          //     ),
          //     child: Consumer<checkPlanPurchaseProiver>(
          //       builder: (context, provider, child) {
          //         if (provider.isLoading) {
          //           return CircularProgressIndicator();
          //         } else {
          //           String planName = provider.checkplanpurchaseModel?.data
          //               ?.planDetail?.planName ??
          //               'No Plan';
          //           if (planName == 'Free Plan') {
          //             planName = 'Buy Now';
          //           }
          //           return Padding(
          //             padding: const EdgeInsets.symmetric(horizontal: 20),
          //             child: Center(
          //                 child: Text(
          //                   planName,
          //                   maxLines: 1,
          //                   overflow: TextOverflow.ellipsis,
          //                   softWrap: false,
          //                   style: TextStyle(
          //                     fontWeight: FontWeight.bold,
          //                     fontSize:
          //                     MediaQuery.of(context).size.width > 500 ? 18 : 14,
          //                   ),
          //                 )),
          //           );
          //         }
          //       },
          //     ),
          //   ),
          // ),
          const SizedBox(
            width: 10,
          ),
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              if (notificationProvider.isLoading) {
                return Center(
                  child: FaIcon(
                    FontAwesomeIcons.bell,
                    size: 20,
                    color: blueColor,
                  ),
                );
              } else if (notificationProvider.notifications.isNotEmpty) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const notifications(),
                    ));
                  },
                  child: Center(
                    child: badges.Badge(
                      position: badges.BadgePosition.topEnd(top: -4, end: -3),
                      badgeStyle: badges.BadgeStyle(
                        badgeColor: Colors.red,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.bell,
                        size: 20,
                        color: blueColor,
                      ),
                    ),
                  ),
                );
              } else {
                return Container();
              }
            },
          ),
          const SizedBox(
            width: 20,
          ),
          FutureBuilder<String>(
            future: _getNameFromSharedPreferences(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: blueColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: PopupMenuButton(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    position: PopupMenuPosition.under,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          _getDisplayName(context, snapshot.data!.trim()),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: MediaQuery.of(context).size.width > 500
                                  ? 16
                                  : 14),
                        ),
                      ),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8.0),
                        bottomRight: Radius.circular(8.0),
                        topLeft: Radius.circular(8.0),
                        topRight: Radius.circular(8.0),
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        child: Text(
                          "WELCOME",
                          style: TextStyle(color: blueColor),
                        ),
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: blueColor,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              "My Profile",
                              style: TextStyle(color: blueColor),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (isProfilePageActive != true) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => const Profile_screen()));
                          }
                        },
                      ),
                      // Admin only, like web: Staff can't change permissions.
                      if (!_isStaffUser)
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.note_alt_outlined, color: blueColor),
                            const SizedBox(
                              width: 10,
                            ),
                            Text(
                              "User Permission",
                              style: TextStyle(color: blueColor),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (isUserPermitePageActive != true) {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) =>
                                    const UserPermissionScreen()));
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 4,
                            ),
                            FaIcon(
                              FontAwesomeIcons.clipboardList,
                              size: 20,
                              color: blueColor,
                            ),
                            SizedBox(
                              width: 13,
                            ),
                            Text(
                              " Activities",
                              style: TextStyle(color: blueColor),
                            ),
                          ],
                        ),
                        onTap: () {
                          //    if (isSettingPageActive != true) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ActivityTable()));
                          //  }
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.contact_mail, color: blueColor),
                            SizedBox(width: 10),
                            Text("Contact Us",
                                style: TextStyle(color: blueColor)),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ContactUsScreen()));
                        },
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_run_rounded,
                              color: blueColor,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              "Logout",
                              style: TextStyle(color: blueColor),
                            ),
                          ],
                        ),
                        onTap: () async {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();

                          // Preserve Remember Me credentials
                          bool? rememberMe = prefs.getBool('rememberMe');
                          String? savedEmail = prefs.getString('savedEmail');
                          String? savedPassword =
                              prefs.getString('savedPassword');

                          // Clear all preferences
                          prefs.clear();

                          // Restore Remember Me credentials if they exist
                          if (rememberMe == true &&
                              savedEmail != null &&
                              savedPassword != null) {
                            await prefs.setBool('rememberMe', true);
                            await prefs.setString('savedEmail', savedEmail);
                            await prefs.setString(
                                'savedPassword', savedPassword);
                          }

                          Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Login_Screen()),
                              (route) => false);
                        },
                      ),
                      PopupMenuItem(
                        height: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FutureBuilder<PackageInfo>(
                              future: PackageInfo.fromPlatform(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    "v${snapshot.data!.version}",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  );
                                }
                                return Container();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Container();
              }
            },
          ),
          const SizedBox(
            width: 20,
          ),
        ],
      ),
    );
  }

  static Future<String> _getNameFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isStaffUser = prefs.getString('role') == 'Staffmember' ||
        (prefs.getString('staff_id') ?? '').isNotEmpty;
    String? firstName = prefs.getString("first_name");
    String? lastName = prefs.getString("last_name");
    String combinationName = '';

    if (firstName != null && firstName.isNotEmpty) {
      combinationName += firstName.trim();
    }

    if (lastName != null && lastName.isNotEmpty) {
      combinationName += ' ${lastName.trim()}';
    }
    return combinationName.isNotEmpty ? combinationName : "L";
  }

  static String _getDisplayName(BuildContext context, String fullName) {
    if (MediaQuery.of(context).size.width < 500) {
      List<String> nameParts = fullName.split(' ');
      String initials = '';
      if (nameParts.length > 1) {
        initials = nameParts[0][0] + nameParts[1][0];
      } else if (nameParts.isNotEmpty) {
        initials = nameParts[0][0];
      }
      return initials.toUpperCase();
    } else {
      return fullName;
    }
  }

  static Future<String> _getCompanyNameFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyName = prefs.getString("companyName");
    return companyName != null && companyName.isNotEmpty
        ? companyName
        : "Company Name";
  }
}
