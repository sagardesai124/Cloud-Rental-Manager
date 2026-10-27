import 'dart:async';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/provider/NetworkProvider.dart';
import 'package:three_zero_two_property/provider/Plan%20Purchase/plancheckProvider.dart';
import 'package:three_zero_two_property/provider/add_property.dart';
import 'package:three_zero_two_property/provider/color_theme.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/editapplicationsummaryForm.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/provider/properties_workorders.dart';
import 'package:three_zero_two_property/provider/property_summery.dart';
import 'package:three_zero_two_property/repository/properties_summery.dart';
import 'package:three_zero_two_property/screens/Splash_Screen/splash_screen.dart';
import 'package:three_zero_two_property/services/api_client.dart';
import 'package:three_zero_two_property/services/app_headers.dart';
import 'package:three_zero_two_property/services/stored_password_cleanup.dart';
import 'StaffModule/repository/staffpermission_provider.dart';
import 'TenantsModule/repository/permission_provider.dart';
import 'VendorModule/repository/vendor_permission.dart';
import 'constant/constant.dart';
import 'provider/edit_applicant.dart';
import 'package:credit_card_validator/credit_card_validator.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'provider/notification_provider.dart';
import 'widgets/keyboard_background_guard.dart';
// void main() {
//   runApp(
//     MultiProvider(providers: [
// ChangeNotifierProvider(
//       create: (context) => OwnerDetailsProvider(),
//       // child: MyApp(),
//     ),
//       ChangeNotifierProvider(
//         create: (context) => Tenants_counts(),
//       ),
//     ],
//       child: MyApp(),
//     ),
//     // DevicePreview(
//     //   enabled: true,
//   tools: [/
// //     ...DevicePreview.defaultTools,
//     //   ],
//     //   builder: (context) => MyApp(),
//     // ),
//   );
// }

// void main() {
//   runApp(
//    /* DevicePreview(
//       enabled: true,
//       tools: [
//         ...DevicePreview.defaultTools,
//       ],
//       builder: (context) => MultiProvider(
//         providers: [
//           ChangeNotifierProvider(
//             create: (context) => OwnerDetailsProvider(),
//           ),
//           ChangeNotifierProvider(
//             create: (context) => Tenants_counts(),
//           ),
//         ],
//         child: MyApp(),
//       ),
//     ),*/
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(
//           create: (context) => OwnerDetailsProvider(),
//         ),
//         ChangeNotifierProvider(
//           create: (context) => Tenants_counts(),
//         ),
//         ChangeNotifierProvider(
//           create: (context) => SelectedTenantsProvider(),
//         ),
//         ChangeNotifierProvider(
//           create: (context) => SelectedCosignersProvider(),
//         ),
//         ChangeNotifierProvider(
//           create: (context) => NameProvider(),
//         ),
//       ],
//       child: MyApp(),
//     ),
//   );
// }

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppHeaders.init();
    await purgeStoredSessionPasswords();
    timeago.setLocaleMessages('en_custom', CustomTimeAgo());
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    runApp(/*  */
      DevicePreview(
        enabled: kDebugMode ? false : false,
        tools: kDebugMode
            ? [
                ...DevicePreview.defaultTools,
              ]
            : const [ 
                ...DevicePreview.defaultTools,
              ],
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => OwnerDetailsProvider()),
            ChangeNotifierProvider(create: (context) => Tenants_counts()),
            ChangeNotifierProvider(
                create: (context) => SelectedTenantsProvider()),
            ChangeNotifierProvider(
                create: (context) => SelectedCosignersProvider()),
            ChangeNotifierProvider(
                create: (context) => SelectedApplicantProvider()),
            ChangeNotifierProvider(create: (context) => NameProvider()),
            ChangeNotifierProvider(create: (context) => LeaseLedgerProvider()),
            ChangeNotifierProvider(create: (context) => EditFormState()),
            ChangeNotifierProvider(
                create: (context) => WorkOrderCountProvider()),
            ChangeNotifierProvider(
                create: (context) => ApplicantDetailsProvider()),
            ChangeNotifierProvider(
                create: (context) => checkPlanPurchaseProiver()),
            ChangeNotifierProvider(create: (context) => PermissionProvider()),
            ChangeNotifierProvider(
                create: (context) => StaffPermissionProvider()),
            ChangeNotifierProvider(
                create: (context) => WorkOrderCountProvider()),
            ChangeNotifierProvider(create: (context) => ProfileProvider()),
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => DropdownProvider()),
            // lazy: false is REQUIRED, not a preference. Provider builds a
            // lazy entry only when something reads it, and the HTTP wrappers
            // reach this class through CheckConnection.instance — a static set
            // in its constructor — never through the context. With the app-wide
            // NetworkGuard no longer reading it, nothing constructed it, so
            // instance stayed null, every reportNetworkFailure() call was a
            // null-safe no-op, and no screen outside the Admin dashboard (the
            // one place that reads it) could ever show its offline state.
            ChangeNotifierProvider(
                create: (_) => CheckConnection(), lazy: false),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => VendorPermission()),
          ],
          child: MyApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    // Handle uncaught errors here if needed
  }, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      if (kDebugMode) {
        parent.print(zone, line); // Show prints only in debug mode
      }
      // Do nothing in release/profile mode
    },
  ));
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: ApiClient.navigatorKey,
      // Lets a screen know when it becomes visible again, which is the only
      // moment NetworkRetryState allows a silent reload — so stacked screens
      // cannot all fire their requests at once.
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        fontFamily: "Poppins",
        iconTheme: IconThemeData(color: blueColor),
        colorScheme: ColorScheme.fromSeed(seedColor: blueColor),
        useMaterial3: false,
      ),
      // home: DashboardAdminSample(),
      home: SplashScreen(),
      builder: (context, child) {
        // Mounted once, above every route, so the offline state and its Retry
        // live in one place instead of being re-implemented per screen. The
        // blocked screen stays mounted underneath, so recovery returns the
        // user to the same page, filters and scroll position.
        // PILOT: the app-wide blocker is bypassed on purpose. It is the one
        // thing that can lock all ~300 screens on a single wrong verdict, and
        // the design being trialled replaces it with a per-screen offline
        // state that can only be triggered by that screen's own failed
        // request. To undo: re-add `import 'widgets/network_guard.dart';`
        // and wrap the ScrollConfiguration below in NetworkGuard(child: ...).
        // KeyboardBackgroundGuard: on Android, closes the keyboard when the
        // app goes to the background, so it doesn't come back with the
        // keyboard's space still reserved (blank area, cut-off text).
        return KeyboardBackgroundGuard(
          child: ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: child!,
          ),
        );
      },
    );
  }
}

class NameProvider extends ChangeNotifier {
  String _firstName = '';
  String _lastName = '';
  String _phoneNumber = '';
  String _workNumber = '';
  String _email = '';
  String _alterEmail = '';
  String _streetAddress = '';
  String _city = '';
  String _country = '';
  String _postalCode = '';

  String get firstName => _firstName;
  String get lastName => _lastName;
  String get phoneNumber => _phoneNumber;
  String get workNumber => _workNumber;
  String get email => _email;
  String get alterEmail => _alterEmail;
  String get streetAddress => _streetAddress;
  String get city => _city;
  String get country => _country;
  String get postalCode => _postalCode;

  void setDetails({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String workNumber,
    required String email,
    required String alterEmail,
    required String streetAddress,
    required String city,
    required String country,
    required String postalCode,
  }) {
    _firstName = firstName;
    _lastName = lastName;
    _phoneNumber = phoneNumber;
    _workNumber = workNumber;
    _email = email;
    _alterEmail = alterEmail;
    _streetAddress = streetAddress;
    _city = city;
    _country = country;
    _postalCode = postalCode;
    notifyListeners();
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    // Remove the glow effect
    return child;
  }
}

class MyHomePage extends StatefulWidget {
  // const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

//  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    final validator = CreditCardValidator();
    //ONchange for card number

    // Validate card number for credit card and debit card
    final numberValidation = validator.validateCCNum('55555 55555 55444 4');
    if (numberValidation.isValid == true) {
      Fluttertoast.showToast(msg: "Card is valid");
    } else {
      Fluttertoast.showToast(msg: "Card not valid");
    }
    // Validate CVV

    // print(cvvValidation.isValid);

    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("widget.title"),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class CustomTimeAgo extends timeago.EnMessages {
  @override
  String lessThanOneMinute(int seconds) => 'just now';
  @override
  String aboutAMinute(int minutes) => 'a minute';
  @override
  String minutes(int minutes) => '$minutes minutes';
  @override
  String aboutAnHour(int minutes) => 'an hour';
  @override
  String hours(int hours) => '$hours hours';
  @override
  String aDay(int hours) => '1 day';
  @override
  String days(int days) {
    if (days >= 28) {
      return 'a month'; // Match Moment.js rounding
    }
    return '$days days';
  }

  @override
  String aboutAMonth(int days) => 'a month';
  @override
  String months(int months) => '$months months';
  @override
  String aboutAYear(int year) => 'a year';
  @override
  String years(int years) => '$years years';
}
