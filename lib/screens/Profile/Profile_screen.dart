import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Login/login_screen.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../provider/Plan Purchase/plancheckProvider.dart';
import '../../repository/profile_repository.dart';
import '../../widgets/drawer_tiles.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/custom_switch.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:email_validator/email_validator.dart';

class Profile_screen extends StatefulWidget {
  // final String email;
  // final String admin_id;
  // final String role;
  // const Profile_screen({super.key, required this.email,required this.admin_id, required this.role});
  const Profile_screen({super.key});

  @override
  State<Profile_screen> createState() => _Profile_screenState();
}

class _Profile_screenState extends State<Profile_screen>
    with NetworkRetryState {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _createdDate = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();
  final TextEditingController _companyPostalCodeController =
      TextEditingController();
  final TextEditingController _companyCityController = TextEditingController();
  final TextEditingController _companyStateController = TextEditingController();
  final TextEditingController _companyCountryController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  profile? _profile;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  String originalFirstName = '';
  String originalLastName = '';
  String originalEmail = '';
  String originalDate = '';
  String originalPhoneNumber = '';
  String originalCompanyName = '';
  String originalCompanyAddress = '';
  String originalCompanyPostalCode = '';
  String originalCompanyCity = '';
  String originalCompanyState = '';
  String originalCompanyCountry = '';

  /// Guards the Update button while a save is in flight — the handler awaits
  /// the API now, so without it a double tap would fire two writes.
  bool _isSavingProfile = false;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _fetchProfile();
      ;
      _loadOldPassword();
      ;
    });
  }

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    _fetchProfile();
    _loadOldPassword();
    status2FA(); // Fetch 2FA status on screen load
    backupcodeapicall();
  }

  @override
  void dispose() {
    // Timer first: its periodic callback writes `seconds`, so it must stop
    // before that notifier is disposed.
    _timer?.cancel();
    _connectivitySub?.cancel();
    seconds.dispose();
    // Profile fields
    _firstNameController.dispose();
    _lastNameController.dispose();
    _createdDate.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPostalCodeController.dispose();
    _companyCityController.dispose();
    _companyStateController.dispose();
    _companyCountryController.dispose();
    // Change password
    password.dispose();
    confirmpassword.dispose();
    // 2FA
    verificationCodeController.dispose();
    disableVerificationController.dispose();
    regenerateVerificationController.dispose();
    super.dispose();
  }

  void startTimer() {
    // Cancel any existing timer first
    _timer?.cancel();

    // A fresh code is being issued, so drop any expired state. The only caller
    // calls setState immediately after this, which repaints the field/button.
    is2FACodeExpired = false;

    // 10 minutes timer for 2FA verification code
    seconds.value = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds.value > 0) {
        seconds.value--;
      } else {
        _timer?.cancel();
        // Same as the login screen: the dead code is cleared and cannot be
        // submitted until a new one is requested. Both fields are cleared
        // because one timer serves the enable and disable flows, which are
        // never on screen at the same time.
        verificationCodeController.clear();
        disableVerificationController.clear();
        if (mounted) {
          setState(() {
            is2FACodeExpired = true;
          });
        }
        Fluttertoast.showToast(
          msg: 'Verification code expired',
          backgroundColor: Colors.red,
        );
      }
    });
  }

  /// Stops the countdown without marking the code expired — used once a code
  /// has been accepted or the flow is cancelled.
  void stopTimer() {
    _timer?.cancel();
    seconds.value = 0;
    is2FACodeExpired = false;
  }

  String getTimerString() {
    if (seconds.value <= 0) {
      return '0m 0s';
    }
    return '${seconds.value ~/ 60}m ${seconds.value % 60}s';
  }

  /// Countdown + Resend row for a 2FA code field.
  ///
  /// Web renders these two inside the field as a suffix; mobile keeps them on
  /// their own row to match the login screen and the enable-2FA section.
  Widget _build2FACodeTimerRow({required VoidCallback onResend}) {
    return ValueListenableBuilder<int>(
      valueListenable: seconds,
      builder: (context, value, child) {
        // Locked for the first 60s of the 10 minute window, and while a
        // request is already in flight — same gating as web and login.
        final bool canResend = value <= 540 && !isVerifyingCode;
        // Web design: clock + "Expires in Xm Xs" on the left, a plain blue
        // "Resend Code" link on the right.
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (value > 0)
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Expires in ",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: getTimerString(),
                          style: const TextStyle(
                            color: Color(0xFFDC3545),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (is2FACodeExpired)
              const Text(
                "Code expired",
                style: TextStyle(
                  color: Color(0xFFDC3545),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              const SizedBox.shrink(),
            GestureDetector(
              onTap: canResend ? onResend : null,
              child: Row(
                children: [
                  Icon(Icons.refresh,
                      color: canResend
                          ? const Color(0xFF2C72E0)
                          : Colors.grey.shade500,
                      size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "Resend Code",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: canResend
                          ? const Color(0xFF2C72E0)
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// One selectable 2FA method row (web design).
  ///
  /// Soft grey card that turns navy-bordered with a blue wash when picked;
  /// the method icon sits on the right and an unavailable destination is
  /// called out in salmon.
  Widget _build2FAOptionTile({
    required String label,
    required String value,
    String detail = '',
    bool enabled = true,
  }) {
    final bool isSelected = selected2FAMethod == value;
    return GestureDetector(
      onTap: enabled ? () => setState(() => selected2FAMethod = value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE9EFFB) : const Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? blueColor : const Color(0xFFEDF0F4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: selected2FAMethod,
              onChanged: enabled
                  ? (val) => setState(() => selected2FAMethod = val!)
                  : null,
              activeColor: blueColor,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: enabled ? blueColor : Colors.grey[500],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          enabled ? Colors.grey[600] : const Color(0xFFF08A76),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              value == 'sms' ? Icons.smartphone_outlined : Icons.mail_outline,
              size: 20,
              color:
                  enabled ? const Color(0xFF6B7A90) : const Color(0xFFC3C9D3),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  /// Avatar initials for the profile header.
  ///
  /// `firstName?[0]` throws a RangeError on an account saved with a blank
  /// name (Dart indexing an empty string), so build the initials from
  /// whichever names are actually present. Web's `?.slice(0, 1)` just yields
  /// an empty string there; this keeps that no-error behaviour and adds a
  /// neutral placeholder when neither name is available.
  String get _avatarInitials {
    final String first = (_profile?.firstName ?? '').trim();
    final String last = (_profile?.lastName ?? '').trim();
    final String initials = '${first.isNotEmpty ? first[0].toUpperCase() : ''}'
        '${last.isNotEmpty ? last[0].toUpperCase() : ''}';
    return initials.isNotEmpty ? initials : '-';
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back (reliably so on the
    // iOS simulator), which made this screen declare itself offline
    // while requests actually succeed. Confirm before believing it.
    if (connectiondata == ConnectivityResult.none && await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  Future<void> _fetchProfile() async {
    try {
      final profileData = await ProfileRepository().fetchProfile();
      // Web normalises the stored state once, on load, before it ever reaches
      // the form ("CA" -> "California") so the value matches a dropdown option.
      // Both the field and its original-value snapshot get the normalised form,
      // or the normalisation alone would register as an unsaved change.
      final normalizedState = canonicalUsStateName(profileData.companyState);
      setState(() {
        _profile = profileData;
        _firstNameController.text = profileData.firstName ?? '';
        _lastNameController.text = profileData.lastName ?? '';
        _emailController.text = profileData.email ?? '';
        _phoneNumberController.text =
            formatPhoneNumberedit(profileData.phoneNumber?.toString() ?? '');
        _companyNameController.text = profileData.companyName ?? '';
        _companyAddressController.text = profileData.companyAddress ?? '';
        _companyPostalCodeController.text = profileData.companyPostalCode ?? '';
        _companyCityController.text = profileData.companyCity ?? '';
        _createdDate.text = profileData.createdAt ?? "";
        _companyStateController.text = normalizedState;
        _companyCountryController.text = profileData.companyCountry ?? '';
        // Change Password starts empty, matching the Staff/Vendor/Tenant
        // screens, which never populate these fields. Seeding them from the
        // profile response put the account's password on screen in plaintext
        // on every load — and made "Change Password" submittable without the
        // user typing anything.

        // Store original values
        originalFirstName = profileData.firstName ?? '';
        originalLastName = profileData.lastName ?? '';
        originalEmail = profileData.email ?? '';
        originalPhoneNumber = profileData.phoneNumber?.toString() ?? '';
        originalCompanyName = profileData.companyName ?? '';
        originalCompanyAddress = profileData.companyAddress ?? '';
        originalCompanyPostalCode = profileData.companyPostalCode ?? '';
        originalCompanyCity = profileData.companyCity ?? '';
        originalCompanyState = normalizedState;
        originalCompanyCountry = profileData.companyCountry ?? '';
        originalDate = profileData.createdAt ?? "";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  //for change password

  TextEditingController password = TextEditingController();
  TextEditingController confirmpassword = TextEditingController();
  bool passworderror = false;
  bool passwordsameerror = false;
  bool confirmpassworderror = false;
  bool loading = false;

  bool enble2FA = false;

  bool disable2FA = false;

  // make a radio button for sms and email
  bool sms2FA = false;
  bool email2FA = false;

  // 2FA Setup Flow Variables
  bool show2FASetup = false;
  String selected2FAMethod = ''; // 'sms' or 'email'

  // Web parity (TwoFactorAuthComponent.js): the SMS radio is disabled when the
  // account has no phone number and the Email radio when it has no e-mail, and
  // the Enable button is additionally blocked when the *selected* method has no
  // destination. Both values can be null OR an empty string.
  String get _phone2FA => (_profile?.phoneNumber ?? '').trim();
  String get _email2FA => (_profile?.email ?? '').trim();
  bool get _canUseSms2FA => _phone2FA.isNotEmpty;
  bool get _canUseEmail2FA => _email2FA.isNotEmpty;
  bool get _can2FAEnable =>
      selected2FAMethod.isNotEmpty &&
      !(selected2FAMethod == 'sms' && !_canUseSms2FA) &&
      !(selected2FAMethod == 'email' && !_canUseEmail2FA);
  TextEditingController verificationCodeController = TextEditingController();
  bool isVerifyingCode = false;
  bool showVerificationInput = false;

  // True only once the enable-2FA countdown actually ran out. Web disables the
  // code field and the submit button in that state instead of letting a dead
  // code be posted, so mobile does the same.
  bool is2FACodeExpired = false;

  // 2FA Disable/Regenerate Flow Variables
  bool showDisableVerification = false;
  bool showRegenerateVerification = false;
  TextEditingController disableVerificationController = TextEditingController();
  TextEditingController regenerateVerificationController =
      TextEditingController();

  // Backup Codes Variables
  bool backupCode = false;
  List<Map<String, dynamic>> codes = [];

  // Timer for 2FA verification code
  Timer? _timer;
  ValueNotifier<int> seconds = ValueNotifier(600);
  final GlobalKey<FormState> _formKey2FA = GlobalKey<FormState>();

  String passwordmessage = "";
  String passwordsamemessage = "";
  String confirmpasswordmessage = "";
  bool visiable_password = true;
  bool visiable_password_confirm = true;

  final formKey = GlobalKey<FormState>();

  void changePassword() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? email = prefs.getString("email");
    String? role = prefs.getString("role");
    String? userid = prefs.getString("userId");

    setState(() {
      loading = true; // Set loading to true while changing password
    });

    final response = await apiPut(
      Uri.parse('${Api_url}/api/admin/app/reset_password'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'email': email,
        // Trim to match how login submits the password
        // (login_screen.dart: `password.text.trim()`) and to match the
        // trimmed value cached locally by _savePassword below — sending an
        // untrimmed value here stored a password that login could never match.
        'password': password.text.trim(),
        'admin_id': id,
        'role': "admin",
        'user_id': userid,
      }),
    );
    setState(() {
      loading = false; // Set loading to false after receiving response
    });
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData["message"] == "Password Updated Successfully") {
        // Navigator.push(
        //     context, MaterialPageRoute(builder: (context) => Login_Screen()));
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Password updated successfully")),
        // );
        await _savePassword(password.text.trim());
        Fluttertoast.showToast(msg: 'Password updated successfully');
        // Both fields are emptied so the new password is not left sitting on
        // screen in plaintext once it has been saved. The Staff/Vendor/Tenant
        // flows reach the same end state by popping their dedicated Change
        // Password screen; this section lives inline on the profile, so it has
        // to clear itself. Validation state is reset too, or a stale message
        // would sit under a now-empty field.
        if (mounted) {
          setState(() {
            password.clear();
            confirmpassword.clear();
            passworderror = false;
            passwordsameerror = false;
            confirmpassworderror = false;
            passwordmessage = "";
            confirmpasswordmessage = "";
          });
        }
      } else {
        // Handle other successful responses or display an error message
      }
    } else {
      // Handle HTTP error responses
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed to update password")),
      // );
      Fluttertoast.showToast(msg: 'Failed to update password');
    }
  }

  void status2FA() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? email = prefs.getString("email");
    String? role = prefs.getString("role");
    String? userid = prefs.getString("userId");
    String? token = prefs.getString("token");

    setState(() {
      loading = true; // Set loading to true while fetching 2FA status
    });

    final response = await apiGet(
      Uri.parse('${Api_url}/api/2fa/2fa-status/${id}'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    setState(() {
      loading = false; // Set loading to false after receiving response
    });

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      if (jsonData["statusCode"] == 200 && jsonData["data"] != null) {
        final data = jsonData["data"];
        final bool enabled = data["enabled"] ?? false;
        final String method = data["method"] ?? "";

        setState(() {
          enble2FA = enabled;

          // Set method-specific flags based on the method received
          if (method.toLowerCase() == "email") {
            email2FA = true;
            sms2FA = false;
          } else if (method.toLowerCase() == "sms") {
            sms2FA = true;
            email2FA = false;
          } else {
            // If no method or unknown method, reset both
            email2FA = false;
            sms2FA = false;
          }
        });
      } else {
        // Handle case where data is null or statusCode is not 200
        setState(() {
          enble2FA = false;
          email2FA = false;
          sms2FA = false;
        });
      }
    } else {
      // Handle HTTP error responses
      setState(() {
        enble2FA = false;
        email2FA = false;
        sms2FA = false;
      });
      Fluttertoast.showToast(msg: 'Failed to fetch 2FA status');
    }
  }

  // https://staging.cloudrentalmanager.com/api/backup-codes/backup-codes/1730957524276?user_type=admin  call the api for this

  Future<void> backupcodeapicall() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString("token");
    String? userid = prefs.getString("userId");

    final response = await apiGet(
      Uri.parse(
          '${Api_url}/api/backup-codes/backup-codes/${userid}?user_type=admin'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200) {
      setState(() {
        backupCode = true;
        codes = List<Map<String, dynamic>>.from(jsonData["data"]["codes"]);
      });
    } else {
      setState(() {
        backupCode = false;
      });
    }
  }

  //for save

  Future<void> _savePassword(String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("password", password); // Store the new password
  }

  String oldPassword = "";
  Future<void> _loadOldPassword() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? pass = prefs.getString("password");
    setState(() {
      oldPassword = pass!; // Fetch the old password
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isFreePlan = Provider.of<checkPlanPurchaseProiver>(context)
            .checkplanpurchaseModel
            ?.data
            ?.planDetail
            ?.planName ==
        'Free Plan';

    return Scaffold(
      appBar: widget_302.App_Bar(context: context, isProfilePageActive: true),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Profile",
        dropdown: false,
      ),
      body: !isOffline
          ? _isLoading
              ? const ProfileShimmer()
              : _hasError
                  ? isNetworkError(_errorMessage)
                      ? NoInternetView(onRetry: retryNow)
                      : Center(
                          child: Text(friendlyErrorMessage(_errorMessage)),
                        )
                  : SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(
                            MediaQuery.of(context).size.width < 500 ? 16 : 30),
                        child: Column(
                          children: [
                            // const SizedBox(height: 20),
                            Container(
                              height: 220,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE5E9F0)),
                                // color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Container(
                                        width: 70,
                                        height: 70,
                                        color: blueColor,
                                        child: Center(
                                          child: Text(
                                            _avatarInitials,
                                            style: const TextStyle(
                                              fontSize: 24.0,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      '${_profile?.firstName} ${_profile?.lastName}',
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 18
                                                : 22,
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      '${_profile?.email}',
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 16
                                                : 18,
                                        fontWeight: FontWeight.w400,
                                        color: blueColor,
                                      ),
                                    ),
                                    // Web's profile card shows the phone number
                                    // here, never the admin id. Dropped when
                                    // the account has no phone on file, so the
                                    // card doesn't render an empty line.
                                    if (_phone2FA.isNotEmpty) ...[
                                      const SizedBox(height: 8.0),
                                      Text(
                                        formatPhoneNumberedit(_phone2FA),
                                        style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 16
                                              : 18,
                                          fontWeight: FontWeight.w400,
                                          color: blueColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              //  height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE5E9F0)),
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 22),
                                    child: Row(
                                      children: [
                                        const Text(
                                          "Account Level :",
                                          style: TextStyle(
                                              color: Color(0xFF8A95A8),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Text(
                                          '${!isFreePlan ? 'Paid' : "Free"}',
                                          style: TextStyle(
                                              color: blueColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  if (isFreePlan)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 22),
                                      child: GestureDetector(
                                        onTap: () async {
                                          const url =
                                              'https://www.hostmerchantservices.com/signup/?leadsource=CloudRentalManager';
                                          final uri = Uri.parse(url);

                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication, // Ensures the system browser is used
                                            );
                                          } else {}
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              height: 35,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.4,
                                              decoration: BoxDecoration(
                                                color: blueColor,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Center(
                                                child: loading
                                                    ? const SpinKitFadingCircle(
                                                        color: Colors.white,
                                                        size: 40.0,
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            "Upgrade Account",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width <
                                                                      500
                                                                  ? 15
                                                                  : 20,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (isFreePlan)
                                    const SizedBox(
                                      height: 20,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              //  height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE5E9F0)),
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Web design: bold navy title, contextual
                                  // grey subtitle, toggle pinned to the right.
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 16, 16, 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Two-Factor Authentication (2FA)",
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        CustomSwitch(
                                            // The knob follows web's
                                            // twoFactorToggle: on when 2FA is
                                            // enabled OR while the user is
                                            // setting it up.
                                            initialValue:
                                                enble2FA || show2FASetup,
                                            onChanged: (value) {
                                              // Ignore taps while a 2FA
                                              // request is already in flight.
                                              if (isVerifyingCode) return;
                                              if (value) {
                                                // Turning ON. Nothing to set
                                                // up if it is already enabled.
                                                if (enble2FA) return;
                                                setState(() {
                                                  show2FASetup = true;
                                                  showVerificationInput = false;
                                                  selected2FAMethod = '';
                                                });
                                              } else if (enble2FA) {
                                                // Turning OFF a live 2FA does
                                                // NOT disable it locally — web
                                                // keeps it enabled and only
                                                // asks for a verification
                                                // code, flipping the flag once
                                                // the code is verified.
                                                if (showDisableVerification) {
                                                  return;
                                                }
                                                _sendDisable2FACode();
                                              } else {
                                                // Not enabled: plain reset of
                                                // whatever flow was open.
                                                stopTimer();
                                                setState(() {
                                                  show2FASetup = false;
                                                  showVerificationInput = false;
                                                  showDisableVerification =
                                                      false;
                                                  selected2FAMethod = '';
                                                  verificationCodeController
                                                      .clear();
                                                  disableVerificationController
                                                      .clear();
                                                });
                                              }
                                            })
                                      ],
                                    ),
                                  ),
                                  const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFEFF2F6)),
                                  const SizedBox(height: 14),
                                  // Show different content based on 2FA state
                                  if (!enble2FA && !show2FASetup)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Text(
                                        "Turn on the toggle above to enable Two-Factor Authentication for enhanced security.",
                                        style: TextStyle(
                                          color: const Color(0xFF6B7A90),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),

                                  // 2FA Setup Flow
                                  // Web renders the chooser only in the
                                  // `twoFactorToggle && !twoFactorEnabled`
                                  // arm, so it can never sit beside the
                                  // disable-code form. These extra terms
                                  // restore that exclusivity.
                                  if (show2FASetup &&
                                      !showVerificationInput &&
                                      !enble2FA &&
                                      !showDisableVerification)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Choose your preferred method",
                                            style: TextStyle(
                                              color: blueColor,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 16),

                                          _build2FAOptionTile(
                                            label: "SMS",
                                            value: 'sms',
                                            enabled: _canUseSms2FA,
                                            detail: _canUseSms2FA
                                                ? _phone2FA
                                                : "No phone number on file",
                                          ),
                                          _build2FAOptionTile(
                                            label: "Email",
                                            value: 'email',
                                            enabled: _canUseEmail2FA,
                                            detail: _canUseEmail2FA
                                                ? _email2FA
                                                : "No email on file",
                                          ),

                                          SizedBox(height: 20),

                                          // Enable 2FA Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              onPressed: _can2FAEnable
                                                  ? () {
                                                      // isVerifyingCode is set
                                                      // synchronously by
                                                      // _initiate2FASetup, so
                                                      // a second fast tap
                                                      // cannot send a second
                                                      // code.
                                                      if (isVerifyingCode) {
                                                        return;
                                                      }
                                                      _initiate2FASetup();
                                                    }
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: blueColor,
                                                foregroundColor: Colors.white,
                                                // Web design: disabled = light
                                                // grey pill with muted text.
                                                disabledBackgroundColor:
                                                    const Color(0xFFE5E8ED),
                                                disabledForegroundColor:
                                                    const Color(0xFF9AA3B0),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: Text(
                                                "Enable 2FA",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Verification Code Input
                                  if (showVerificationInput)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Enter verification code sent to your ${selected2FAMethod == 'email' ? 'email' : 'phone'}:",
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 16),

                                          // Verification Code Input Field
                                          Form(
                                            key: _formKey2FA,
                                            child: TextFormField(
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  letterSpacing: 1.5,
                                                  color: Color(0xFF152B51)),
                                              autovalidateMode: AutovalidateMode
                                                  .onUserInteraction,
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please enter a valid code';
                                                }
                                                if (value.length != 6) {
                                                  return 'Code must be 6 digits';
                                                }
                                                return null;
                                              },
                                              controller:
                                                  verificationCodeController,
                                              keyboardType:
                                                  TextInputType.number,
                                              maxLength: 6,
                                              // Web greys the field out once
                                              // the code has expired.
                                              enabled: !is2FACodeExpired,
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 16),
                                                hintText: "Enter 6-digit code",
                                                hintStyle: const TextStyle(
                                                    color: Color(0xFF94A1B4),
                                                    letterSpacing: 0.5),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFFD3DAE5),
                                                      width: 1.5),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: BorderSide(
                                                      color: blueColor,
                                                      width: 2),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFF152B51),
                                                      width: 1.5),
                                                ),
                                                focusedErrorBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                      color: Color(0xFF152B51),
                                                      width: 1.5),
                                                ),
                                                counterText: "",
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              ValueListenableBuilder<int>(
                                                valueListenable: seconds,
                                                builder:
                                                    (context, value, child) {
                                                  // Once the countdown runs
                                                  // out this reads "Code
                                                  // expired" instead of a
                                                  // stuck "0m 0s", matching
                                                  // the login screen.
                                                  if (value <= 0) {
                                                    return Text(
                                                      is2FACodeExpired
                                                          ? "Code expired"
                                                          : "",
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    );
                                                  }
                                                  return RichText(
                                                    textAlign: TextAlign.center,
                                                    text: TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text:
                                                              "Code will expire in ",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              "${getTimerString()}",
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  // Resend is locked for the
                                                  // first 60s. Bail before
                                                  // clearing, so a tap that
                                                  // sends nothing no longer
                                                  // wipes the typed code.
                                                  // isVerifyingCode is set
                                                  // synchronously by
                                                  // _initiate2FASetup, so it
                                                  // also stops a double tap
                                                  // sending two e-mails.
                                                  if (!showVerificationInput ||
                                                      seconds.value > 540 ||
                                                      isVerifyingCode) {
                                                    return;
                                                  }
                                                  verificationCodeController
                                                      .clear();
                                                  _initiate2FASetup();
                                                },
                                                child:
                                                    ValueListenableBuilder<int>(
                                                  valueListenable: seconds,
                                                  builder:
                                                      (context, value, child) {
                                                    return Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .grey.shade200,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.refresh,
                                                              color: value <=
                                                                      540
                                                                  ? blueColor
                                                                  : Colors.grey
                                                                      .shade600,
                                                              size: 16),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            "Resend Code",
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: value <=
                                                                      540
                                                                  ? blueColor
                                                                  : Colors.grey
                                                                      .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),

                                          SizedBox(height: 20),

                                          // Verify & Enable Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              // Expired codes are rejected by
                                              // the server, so the button is
                                              // disabled until a new code is
                                              // requested — as web does.
                                              onPressed: (isVerifyingCode ||
                                                      is2FACodeExpired)
                                                  ? null
                                                  : () => _formKey2FA
                                                          .currentState!
                                                          .validate()
                                                      ? _verifyAndEnable2FA()
                                                      : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: blueColor,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: isVerifyingCode
                                                  ? SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(
                                                      "Verify & Enable",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),

                                          SizedBox(height: 12),

                                          // Cancel Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                stopTimer();
                                                setState(() {
                                                  show2FASetup = false;
                                                  showVerificationInput = false;
                                                  selected2FAMethod = '';
                                                  verificationCodeController
                                                      .clear();
                                                });
                                              },
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                    color: Colors.grey),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // 2FA Enabled Status - web's green banner:
                                  // circled check + bold green text on a soft
                                  // green pill.
                                  if (enble2FA && !show2FASetup)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE7F7EE),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check,
                                                size: 18,
                                                color: Color(0xFF1F9D55)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                email2FA
                                                    ? "2FA is enabled via Email"
                                                    : sms2FA
                                                        ? "2FA is enabled via SMS"
                                                        : "2FA is enabled",
                                                style: const TextStyle(
                                                  color: Color(0xFF1F9D55),
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Verification-method tile (web design):
                                  // mail/phone icon in a soft blue square,
                                  // caps label, bold destination. Main
                                  // enabled view only - the disable card
                                  // shows "Sent to ..." itself.
                                  if (enble2FA &&
                                      !show2FASetup &&
                                      !showDisableVerification &&
                                      !showRegenerateVerification)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 0),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: const Color(0xFFE8ECF1)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              sms2FA && !email2FA
                                                  ? Icons.sms_outlined
                                                  : Icons.mail_outline,
                                              size: 22,
                                              color: const Color(0xFF2C72E0),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    "VERIFICATION METHOD",
                                                    style: TextStyle(
                                                      color: Color(0xFF6B7A90),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    sms2FA && !email2FA
                                                        ? _phone2FA
                                                        : _email2FA,
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 20),

                                  // Disable 2FA Verification Input
                                  // Web nests the disable-code form inside the
                                  // `twoFactorEnabled` arm — it is only
                                  // meaningful while 2FA is actually on.
                                  if (showDisableVerification && enble2FA)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 12),
                                          // Web design: the code entry lives
                                          // in its own soft card with the
                                          // destination under the title.
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFFFF),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFE4E8EF)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Enter verification code to disable 2FA",
                                                  style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "Sent to ${email2FA ? _email2FA : (sms2FA ? _phone2FA : _email2FA)}",
                                                  style: const TextStyle(
                                                    color: Color(0xFF6B7A90),
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),

                                                // Verification Code Input Field
                                                TextField(
                                                  controller:
                                                      disableVerificationController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  maxLength: 6,
                                                  // Web greys the field out once the
                                                  // code has expired.
                                                  enabled: !is2FACodeExpired,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      letterSpacing: 1.5,
                                                      color: Color(0xFF152B51)),
                                                  decoration: InputDecoration(
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 14,
                                                            vertical: 16),
                                                    hintText:
                                                        "Enter 6-digit code",
                                                    hintStyle: const TextStyle(
                                                        color:
                                                            Color(0xFF94A1B4),
                                                        letterSpacing: 0.5),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: Color(
                                                                  0xFFD3DAE5)),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: Color(
                                                                  0xFFD3DAE5)),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      borderSide: BorderSide(
                                                          color: blueColor,
                                                          width: 1.5),
                                                    ),
                                                    counterText: "",
                                                  ),
                                                ),

                                                const SizedBox(height: 10),

                                                // The disable code expires server
                                                // side after 10 minutes, so show the
                                                // countdown and a way to get a new
                                                // one — as web does here.
                                                _build2FACodeTimerRow(
                                                  onResend: () {
                                                    // The previous code is dead once
                                                    // a new one is issued, so drop
                                                    // the stale digits.
                                                    disableVerificationController
                                                        .clear();
                                                    _sendDisable2FACode();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // Web design: Cancel + solid Disable
                                          // side by side.
                                          Row(
                                            children: [
                                              Expanded(
                                                child: SizedBox(
                                                  height: 44,
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      // Leaving the flow must not
                                                      // leave a countdown ticking.
                                                      stopTimer();
                                                      setState(() {
                                                        showDisableVerification =
                                                            false;
                                                        disableVerificationController
                                                            .clear();
                                                      });
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFFE2E6EC)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Cancel",
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: SizedBox(
                                                  height: 44,
                                                  child: ElevatedButton(
                                                    // An expired code is rejected by
                                                    // the server, so block the tap
                                                    // until a new one is requested.
                                                    onPressed: (isVerifyingCode ||
                                                            is2FACodeExpired)
                                                        ? null
                                                        : () =>
                                                            _disable2FAWithVerification(),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFDC3545),
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 0,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                    ),
                                                    child: isVerifyingCode
                                                        ? SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child:
                                                                CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                              strokeWidth: 2,
                                                            ),
                                                          )
                                                        : Text(
                                                            "Disable 2FA",
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Regenerate Backup Codes Verification Input
                                  if (showRegenerateVerification)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Enter verification code to regenerate backup codes:",
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 16),

                                          // Verification Code Input Field
                                          TextField(
                                            controller:
                                                regenerateVerificationController,
                                            keyboardType: TextInputType.number,
                                            maxLength: 6,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                letterSpacing: 1.5,
                                                color: Color(0xFF152B51)),
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 16),
                                              hintText: "Enter 6-digit code",
                                              hintStyle: const TextStyle(
                                                  color: Color(0xFF94A1B4),
                                                  letterSpacing: 0.5),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFFD3DAE5),
                                                    width: 1.5),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                    color: blueColor, width: 2),
                                              ),
                                              counterText: "",
                                            ),
                                          ),

                                          SizedBox(height: 20),

                                          // Regenerate Backup Codes Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              onPressed: isVerifyingCode
                                                  ? null
                                                  : () =>
                                                      _regenerateBackupCodesWithVerification(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: blueColor,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: isVerifyingCode
                                                  ? SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : Text(
                                                      "Backup Codes",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                            ),
                                          ),

                                          SizedBox(height: 12),

                                          // Cancel Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                setState(() {
                                                  showRegenerateVerification =
                                                      false;
                                                  regenerateVerificationController
                                                      .clear();
                                                });
                                              },
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                    color: Colors.grey),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Responsive 2FA Action Buttons
                                  // Also hidden while an enable flow is open,
                                  // otherwise "Disable 2FA" stays tappable
                                  // underneath the chooser and re-creates the
                                  // same overlap from the other direction.
                                  if (enble2FA &&
                                      !showDisableVerification &&
                                      !showRegenerateVerification &&
                                      !show2FASetup &&
                                      !showVerificationInput)
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Determine if we should stack buttons vertically on small screens
                                        bool isSmallScreen =
                                            constraints.maxWidth < 300;

                                        return isSmallScreen
                                            ? Column(
                                                children: [
                                                  // Disable 2FA Button
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height:
                                                        60, // Fits a two-line action label (e.g. Regenerate Backup Codes)
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        // showDisableVerification
                                                        // only flips after the
                                                        // 200, so it cannot
                                                        // stop a double tap on
                                                        // its own;
                                                        // isVerifyingCode is
                                                        // set synchronously.
                                                        if (isVerifyingCode ||
                                                            showDisableVerification) {
                                                          return;
                                                        }
                                                        _sendDisable2FACode();
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                                0xFFFDF0EA),
                                                        foregroundColor:
                                                            const Color(
                                                                0xFFD2603C),
                                                        side: const BorderSide(
                                                            color: Color(
                                                                0xFFF2C7B5),
                                                            width: 1.2),
                                                        elevation: 0,
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 16),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .shield_outlined,
                                                              size: 18),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            "Disable 2FA",
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 12),
                                                  // Regenerate Backup Codes Button
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height:
                                                        60, // Fits a two-line action label (e.g. Regenerate Backup Codes)
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        // Blocks the second of
                                                        // two fast taps
                                                        // generating a second
                                                        // set of backup codes.
                                                        if (isVerifyingCode) {
                                                          return;
                                                        }
                                                        _regenerateBackupCodesWithVerification();
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.white,
                                                        foregroundColor:
                                                            blueColor,
                                                        side: const BorderSide(
                                                            color: Color(
                                                                0xFFE2E6EC),
                                                            width: 1.2),
                                                        elevation: 0,
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 16),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(Icons.refresh,
                                                              size: 18),
                                                          SizedBox(width: 8),
                                                          Flexible(
                                                            child: Text(
                                                              codes.isEmpty
                                                                  ? "Backup Codes"
                                                                  : "Regenerate Backup Codes",
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              maxLines: 2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 8),
                                                child: Row(
                                                  children: [
                                                    // Disable 2FA Button
                                                    Expanded(
                                                      flex: 1,
                                                      child: SizedBox(
                                                        height:
                                                            60, // Fits a two-line action label (e.g. Regenerate Backup Codes)
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            // showDisableVerification
                                                            // only flips after
                                                            // the 200;
                                                            // isVerifyingCode
                                                            // is set
                                                            // synchronously.
                                                            if (isVerifyingCode ||
                                                                showDisableVerification) {
                                                              return;
                                                            }
                                                            _sendDisable2FACode();
                                                          },
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                    0xFFFDF0EA),
                                                            foregroundColor:
                                                                const Color(
                                                                    0xFFD2603C),
                                                            side: const BorderSide(
                                                                color: Color(
                                                                    0xFFF2C7B5),
                                                                width: 1.2),
                                                            elevation: 0,
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        16),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                  Icons
                                                                      .shield_outlined,
                                                                  size: 18),
                                                              SizedBox(
                                                                  width: 8),
                                                              Flexible(
                                                                child: Text(
                                                                  "Disable 2FA",
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    // Regenerate Backup Codes Button
                                                    Expanded(
                                                      flex: 1,
                                                      child: SizedBox(
                                                        height:
                                                            60, // Fits a two-line action label (e.g. Regenerate Backup Codes)
                                                        child: ElevatedButton(
                                                          onPressed: () {
                                                            // Blocks a double
                                                            // tap generating a
                                                            // second set of
                                                            // backup codes.
                                                            if (isVerifyingCode) {
                                                              return;
                                                            }
                                                            _regenerateBackupCodesWithVerification();
                                                          },
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors.white,
                                                            foregroundColor:
                                                                blueColor,
                                                            side: const BorderSide(
                                                                color: Color(
                                                                    0xFFE2E6EC),
                                                                width: 1.2),
                                                            elevation: 0,
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        16),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                  Icons.refresh,
                                                                  size: 18),
                                                              SizedBox(
                                                                  width: 8),
                                                              Flexible(
                                                                child: Text(
                                                                  codes.isEmpty
                                                                      ? "Backup Codes"
                                                                      : "Regenerate Backup Codes",
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  maxLines: 2,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // White card with a hairline border, matching the
                            // house form shell (add_tenants.dart `_sectionCard`).
                            Container(
                              decoration: BoxDecoration(
                                // Same shell as the Change Password card
                                // below, so the two sections read as one
                                // consistent page.
                                color: Colors.grey.shade100,
                                border:
                                    Border.all(color: const Color(0xFFE5E9F0)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // "My Account" banner removed — the card
                                      // leads with its own section heading,
                                      // so the extra bar was a second title
                                      // for the same block.
                                      Text(
                                        "User information",
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 17
                                                : 20,
                                            color: blueColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'First Name *',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'First Name',
                                        _firstNameController,
                                        (v) => _validateRequired(
                                            v, 'a first name'),
                                        isRequired: true,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Last Name *',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'Last Name',
                                        _lastNameController,
                                        (v) =>
                                            _validateRequired(v, 'a last name'),
                                        isRequired: true,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Email *',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'Email Address',
                                        _emailController,
                                        _validateEmailAddress,
                                        isEnabled: false,
                                        isRequired: true,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Phone Number *',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'Phone Number',
                                        _phoneNumberController,
                                        _validatePhoneNumber,
                                        isRequired: true,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Company Name *',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'Company Name',
                                        _companyNameController,
                                        (v) => _validateRequired(
                                            v, 'a company name'),
                                        isRequired: true,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Created Date *',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'Created Date',
                                        _createdDate,
                                        _validateFirstName,
                                        isEnabled: false,
                                        isRequired: true,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Company Address',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                        'Company Address',
                                        _companyAddressController,
                                        (v) => _validateRequired(
                                            v, 'a company address'),
                                        isRequired: false,
                                      ),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Postal Code',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                          'Postal Code',
                                          _companyPostalCodeController,
                                          (v) => _validateRequired(
                                              v, 'a postal code')),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'City',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                          'City',
                                          _companyCityController,
                                          (v) =>
                                              _validateRequired(v, 'a city')),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'State',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildStateDropdown(),
                                      const SizedBox(height: 16.0),
                                      const Text(
                                        'Country',
                                        style: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      buildTextField(
                                          'Country',
                                          _companyCountryController,
                                          (v) => _validateRequired(
                                              v, 'a country')),
                                      const SizedBox(height: 16.0),

                                      // ElevatedButton(
                                      //   onPressed: () {
                                      //     if (_formKey.currentState!.validate()) {
                                      //       // If the form is valid, proceed with form submission
                                      //       _formKey.currentState!.save();
                                      //       ProfileRepository().Edit_profile({
                                      //         "first_name": _firstNameController.text,
                                      //         "last_name": _lastNameController.text,
                                      //         "email": _emailController.text,
                                      //         "company_name": _companyNameController.text,
                                      //         "phone_number": int.parse(_phoneNumberController.text),
                                      //       });
                                      //     }
                                      //     // Implement save functionality
                                      //   },
                                      //   child: Text('Update'),
                                      // ),
                                      Row(
                                        // Reversed so Back sits on the left
                                        // and Update on the right, matching
                                        // the agreed layout. The two button
                                        // blocks are left in place rather
                                        // than moved, so their handlers stay
                                        // untouched.
                                        children: <Widget>[
                                          Expanded(
                                              child: GestureDetector(
                                            // onTap: () {
                                            //   if (_formKey.currentState!
                                            //       .validate()) {
                                            //     // If the form is valid, proceed with form submission
                                            //
                                            //     _formKey.currentState!.save();
                                            //     ProfileRepository()
                                            //         .Edit_profile({
                                            //       "first_name":
                                            //           _firstNameController
                                            //               .text,
                                            //       "last_name":
                                            //           _lastNameController
                                            //               .text,
                                            //       "email":
                                            //           _emailController.text,
                                            //       "company_name":
                                            //           _companyNameController
                                            //               .text,
                                            //       "phone_number":
                                            //           _phoneNumberController
                                            //               .text,
                                            //       "company_address":
                                            //           _companyAddressController
                                            //               .text,
                                            //       "postal_code":
                                            //           _companyPostalCodeController
                                            //               .text,
                                            //       "city":
                                            //           _companyCityController
                                            //               .text,
                                            //       "state":
                                            //           _companyStateController
                                            //               .text,
                                            //       "country":
                                            //           _companyCountryController
                                            //               .text,
                                            //     });
                                            //   }
                                            // },
                                            onTap: () async {
                                              if (_isSavingProfile) return;
                                              if (_formKey.currentState!
                                                  .validate()) {
                                                // Check if any field has changed
                                                if (_firstNameController.text !=
                                                        originalFirstName ||
                                                    _lastNameController.text !=
                                                        originalLastName ||
                                                    _emailController.text !=
                                                        originalEmail ||
                                                    _companyNameController
                                                            .text !=
                                                        originalCompanyName ||
                                                    // Compared digits-only,
                                                    // like web's `phoneNorm`:
                                                    // the field displays
                                                    // "(555) 123-4567" while
                                                    // the API returns
                                                    // "5551234567", so a raw
                                                    // string compare marked
                                                    // the phone changed on
                                                    // every load.
                                                    phoneDigitsOnly(
                                                            _phoneNumberController
                                                                .text) !=
                                                        phoneDigitsOnly(
                                                            originalPhoneNumber) ||
                                                    _companyAddressController
                                                            .text !=
                                                        originalCompanyAddress ||
                                                    _companyPostalCodeController
                                                            .text !=
                                                        originalCompanyPostalCode ||
                                                    _companyCityController
                                                            .text !=
                                                        originalCompanyCity ||
                                                    _companyStateController
                                                            .text !=
                                                        originalCompanyState ||
                                                    _companyCountryController
                                                            .text !=
                                                        originalCompanyCountry) {
                                                  // If any field has changed, call the API
                                                  _formKey.currentState!.save();
                                                  setState(() =>
                                                      _isSavingProfile = true);
                                                  try {
                                                    await ProfileRepository()
                                                        .Edit_profile({
                                                      "first_name":
                                                          _firstNameController
                                                              .text
                                                              .trim(),
                                                      "last_name":
                                                          _lastNameController
                                                              .text
                                                              .trim(),
                                                      "email": _emailController
                                                          .text
                                                          .trim(),
                                                      "company_name":
                                                          _companyNameController
                                                              .text
                                                              .trim(),
                                                      // Digits only. The field
                                                      // holds the display form
                                                      // "(555) 123-4567", and
                                                      // saving that back made
                                                      // the stored number stop
                                                      // matching what the API
                                                      // had returned (and what
                                                      // 2FA texts).
                                                      "phone_number":
                                                          phoneDigitsOnly(
                                                              _phoneNumberController
                                                                  .text),
                                                      "company_address":
                                                          _companyAddressController
                                                              .text
                                                              .trim(),
                                                      "postal_code":
                                                          _companyPostalCodeController
                                                              .text
                                                              .trim(),
                                                      "city":
                                                          _companyCityController
                                                              .text
                                                              .trim(),
                                                      "state":
                                                          _companyStateController
                                                              .text
                                                              .trim(),
                                                      "country":
                                                          _companyCountryController
                                                              .text
                                                              .trim(),
                                                    });
                                                    if (!mounted) return;
                                                    // Re-read the saved
                                                    // record: the header now
                                                    // renders the phone
                                                    // number, and the
                                                    // original* snapshots
                                                    // behind the no-changes
                                                    // guard must match what
                                                    // was actually stored.
                                                    await _fetchProfile();
                                                  } catch (_) {
                                                    // Edit_profile already
                                                    // toasts the failure.
                                                  } finally {
                                                    if (mounted) {
                                                      setState(() =>
                                                          _isSavingProfile =
                                                              false);
                                                    }
                                                  }
                                                } else {
                                                  // Optionally, show a message that no changes were made
                                                }
                                              }
                                            },
                                            child: Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: navyClr,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  "Update",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              ),
                                            ),
                                          )),
                                          const SizedBox(
                                            width: 12,
                                          ),
                                          Expanded(
                                              child: GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                            },
                                            child: Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: outlineClr),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  "Back",
                                                  style: TextStyle(
                                                      color: navyClr,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              ),
                                            ),
                                          )),
                                        ].reversed.toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              // height: 220,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE5E9F0)),
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Form(
                                key: formKey,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // const SizedBox(height: 20),
                                      // Login text
                                      Row(
                                        children: [
                                          Text(
                                            "Change Password ",
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.045),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.03,
                                      ),
                                      const Row(
                                        children: [
                                          Text(
                                            'Password',
                                            style: TextStyle(
                                                color: Color(0xFF8A95A8),
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Material(
                                              // Flat, matching the form fields
                                              // above: hairline outline, no
                                              // drop shadow.
                                              elevation: 0,
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: outlineClr),
                                                  color: Colors.white,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: Padding(
                                                        padding: EdgeInsets.symmetric(
                                                            horizontal:
                                                                MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    0.00),
                                                        child: Center(
                                                          child: TextField(
                                                            onChanged: (value) {
                                                              setState(() {
                                                                passworderror =
                                                                    false;
                                                                passwordsameerror =
                                                                    false;
                                                              });
                                                            },
                                                            obscureText:
                                                                visiable_password,
                                                            controller:
                                                                password,
                                                            cursorColor:
                                                                blueColor,
                                                            decoration:
                                                                InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              contentPadding:
                                                                  const EdgeInsets
                                                                      .all(14),
                                                              enabledBorder:
                                                                  passworderror
                                                                      ? OutlineInputBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(MediaQuery.of(context).size.width * 0.013),
                                                                          borderSide:
                                                                              const BorderSide(color: Colors.red), // Set border color here
                                                                        )
                                                                      : InputBorder
                                                                          .none,
                                                              prefixIcon:
                                                                  Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        15.0),
                                                                child: Image.asset(
                                                                    'assets/icons/pasword.png'),
                                                              ),
                                                              hintText:
                                                                  "Password",
                                                              suffixIcon:
                                                                  InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    visiable_password =
                                                                        !visiable_password;
                                                                  });
                                                                },
                                                                child: Icon(
                                                                  visiable_password
                                                                      ? Icons
                                                                          .remove_red_eye_outlined
                                                                      : Icons
                                                                          .visibility_off_outlined,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      passworderror
                                          ? Text(
                                              passwordmessage,
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            )
                                          : Container(),
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.02,
                                      ),
                                      const Row(
                                        children: [
                                          Text(
                                            'Confirm Password',
                                            style: TextStyle(
                                                color: Color(0xFF8A95A8),
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Row(
                                        children: [
                                          // SizedBox(
                                          //   width: MediaQuery.of(context).size.width * 0.099,
                                          // ),
                                          Expanded(
                                            child: Material(
                                              // Flat, matching the form fields
                                              // above: hairline outline, no
                                              // drop shadow.
                                              elevation: 0,
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: outlineClr),
                                                  color: Colors.white,
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: Padding(
                                                        padding: EdgeInsets.symmetric(
                                                            horizontal:
                                                                MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    0.00),
                                                        child: Center(
                                                          child: TextField(
                                                            onChanged: (value) {
                                                              setState(() {
                                                                confirmpassworderror =
                                                                    false;
                                                              });
                                                            },
                                                            obscureText:
                                                                visiable_password_confirm,
                                                            controller:
                                                                confirmpassword,
                                                            cursorColor:
                                                                blueColor,
                                                            decoration:
                                                                InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              contentPadding:
                                                                  const EdgeInsets
                                                                      .all(14),
                                                              enabledBorder:
                                                                  confirmpassworderror
                                                                      ? OutlineInputBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(MediaQuery.of(context).size.width * 0.013),
                                                                          borderSide:
                                                                              const BorderSide(color: Colors.red), // Set border color here
                                                                        )
                                                                      : InputBorder
                                                                          .none,
                                                              prefixIcon:
                                                                  Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        15.0),
                                                                child: Image.asset(
                                                                    'assets/icons/pasword.png'),
                                                              ),
                                                              hintText:
                                                                  "Confirm password",
                                                              suffixIcon:
                                                                  InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    visiable_password_confirm =
                                                                        !visiable_password_confirm;
                                                                  });
                                                                },
                                                                child: Icon(
                                                                  visiable_password_confirm
                                                                      ? Icons
                                                                          .remove_red_eye_outlined
                                                                      : Icons
                                                                          .visibility_off_outlined,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // SizedBox(
                                          //   width: MediaQuery.of(context).size.width * 0.099,
                                          // ),
                                        ],
                                      ),
                                      confirmpassworderror
                                          ? Text(
                                              confirmpasswordmessage,
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            )
                                          : Container(),

                                      // Spacer(),
                                      // Login button
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.04,
                                      ),
                                      // GestureDetector(
                                      //   onTap: () {
                                      //     if (password.text.isEmpty) {
                                      //       setState(() {
                                      //         passworderror = true;
                                      //         passwordmessage =
                                      //             "Password is required";
                                      //       });
                                      //     } else if (password.text.length < 8) {
                                      //       setState(() {
                                      //         passworderror = true;
                                      //         passwordmessage =
                                      //             "Password must have 8 Characters";
                                      //       });
                                      //     } else if (!RegExp(
                                      //             r'^(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                                      //         .hasMatch(password.text)) {
                                      //       setState(() {
                                      //         passworderror = true;
                                      //         passwordmessage =
                                      //             'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character';
                                      //       });
                                      //     } else if (password.text == oldPassword) { // Check if new password is the same as old
                                      //       Fluttertoast.showToast(msg: "New password cannot be the same as the old password");
                                      //       return;
                                      //     } else {
                                      //       setState(() {
                                      //         passworderror = false;
                                      //       });
                                      //     }
                                      //     if (confirmpassword.text.isEmpty) {
                                      //       setState(() {
                                      //         confirmpassworderror = true;
                                      //         confirmpasswordmessage =
                                      //             "Confirm password is required";
                                      //       });
                                      //     } else if (confirmpassword.text !=
                                      //         password.text) {
                                      //       setState(() {
                                      //         confirmpassworderror = true;
                                      //         confirmpasswordmessage =
                                      //             "Both password is not match";
                                      //       });
                                      //     } else {
                                      //       setState(() {
                                      //         confirmpassworderror = false;
                                      //       });
                                      //     }
                                      //     if (!passworderror &&
                                      //         !confirmpassworderror) {
                                      //       changePassword();
                                      //     }
                                      //   },
                                      //   child: Row(
                                      //     children: [
                                      //       Container(
                                      //         // height: MediaQuery.of(context)
                                      //         //         .size
                                      //         //         .height *
                                      //         //     0.05,
                                      //         height:40,
                                      //          width: MediaQuery.of(context).size.width * 0.45,
                                      //         decoration: BoxDecoration(
                                      //           color: blueColor,
                                      //           borderRadius:
                                      //               BorderRadius.circular(5),
                                      //         ),
                                      //         child: Center(
                                      //           child: loading
                                      //               ? SpinKitFadingCircle(
                                      //                   color: Colors.white,
                                      //                   size: 40.0,
                                      //                 )
                                      //               : Row(
                                      //                   mainAxisAlignment:
                                      //                       MainAxisAlignment
                                      //                           .center,
                                      //                   children: [
                                      //                     // SizedBox(
                                      //                     //   width: 8,
                                      //                     // ),
                                      //                     Text(
                                      //                       "Change password",
                                      //                       style: TextStyle(
                                      //                           color: Colors
                                      //                               .white,
                                      //                           fontWeight:
                                      //                               FontWeight
                                      //                                   .bold,
                                      //                           fontSize: MediaQuery.of(
                                      //                               context)
                                      //                               .size
                                      //                               .width <
                                      //                               500
                                      //                               ? 15
                                      //                               : 20),
                                      //                     ),
                                      //                     // SizedBox(
                                      //                     //   width: 8,
                                      //                     // ),
                                      //                   ],
                                      //                 ),
                                      //         ),
                                      //       ),
                                      //     ],
                                      //   ),
                                      // ),
                                      GestureDetector(
                                        onTap: () async {
                                          SharedPreferences prefs =
                                              await SharedPreferences
                                                  .getInstance();
                                          String? pass =
                                              prefs.getString("password");
                                          // Validate the new password
                                          if (password.text.trim().isEmpty) {
                                            setState(() {
                                              passworderror = true;
                                              passwordmessage =
                                                  "Password is required";
                                            });
                                          } else if (password.text
                                                  .trim()
                                                  .length <
                                              12) {
                                            setState(() {
                                              passworderror = true;
                                              passwordmessage =
                                                  "Password must have at least 8 characters";
                                            });
                                          } else if (!RegExp(
                                                  r'^(?=.*?[a-z])(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                                              .hasMatch(password.text.trim())) {
                                            setState(() {
                                              passworderror = true;
                                              passwordmessage =
                                                  'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character';
                                            });
                                          } else if (password.text.trim() ==
                                              pass) {
                                            setState(() {
                                              passworderror = true;
                                              passwordmessage =
                                                  'New password cannot be the same as the old password';
                                            });
                                          } else {
                                            setState(() {
                                              passworderror =
                                                  false; // Clear the password error
                                            });
                                          }

                                          // Validate the confirmation password
                                          if (confirmpassword.text
                                              .trim()
                                              .isEmpty) {
                                            setState(() {
                                              confirmpassworderror = true;
                                              confirmpasswordmessage =
                                                  "Confirm password is required";
                                            });
                                          } else if (confirmpassword.text
                                                  .trim() !=
                                              password.text.trim()) {
                                            setState(() {
                                              confirmpassworderror = true;
                                              confirmpasswordmessage =
                                                  "Both passwords do not match";
                                            });
                                          } else {
                                            setState(() {
                                              confirmpassworderror =
                                                  false; // Clear the confirmation password error
                                            });
                                          }

                                          // If there are no errors, proceed to change the password
                                          if (!passworderror &&
                                              !confirmpassworderror) {
                                            //await _savePassword(password.text);
                                            changePassword(); // Call the function to change the password
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            // Full-width primary action, same
                                            // as the Staff/Tenant/Vendor
                                            // Change Password screens.
                                            Expanded(
                                                child: Container(
                                              height: 54,
                                              decoration: BoxDecoration(
                                                color: navyClr,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: loading
                                                    ? const SpinKitFadingCircle(
                                                        color: Colors.white,
                                                        size: 40.0,
                                                      )
                                                    : Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            "Change Password",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width <
                                                                      500
                                                                  ? 15
                                                                  : 20,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            )),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.02,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () async {
                                _deactivateAccount(context);
                              },
                              child: Container(
                                // Destructive action, styled as a soft tinted
                                // panel rather than a solid red block: full
                                // width, pale red fill, red outline, and a
                                // trash icon beside the label.
                                height: 56,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDECEC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFF5C2C2)),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFDC2626),
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "Delete Account",
                                        style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Bottom breathing room so the destructive button
                            // does not sit flush against the page edge.
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    )
          : NoInternetView(onRetry: retryNow),
    );
  }

  void _deactivateAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                const Text(
                  "Delete Account",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                // Content
                const Text(
                  "Are you sure you want to do this ?  This cannot be undone.  All of your data will be permanently removed.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons Row
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text(
                                "No, Keep My Account ",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Delete Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.of(context).pop(); // Close dialog first
                          await _callDeactivateAPI();
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text(
                                "Yes, Delete It",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _callDeactivateAPI() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");

      if (id == null || token == null) {
        Fluttertoast.showToast(
          msg: 'Unable to get user information',
          backgroundColor: Colors.red,
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Deactivate account..."),
              ],
            ),
          );
        },
      );

      final response = await apiPut(
        Uri.parse('${Api_url}/api/admin/togglestatus/$id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"status": "deactivate"}),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["success"] == true) {
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Account deactivated successfully',
            backgroundColor: Colors.green,
          );

          // Clear shared preferences and navigate to login screen
          // Note: For account deactivation, we clear all data including Remember Me
          prefs.clear();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => Login_Screen()),
            (route) => false, // Remove all previous routes
          );
        } else {
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Failed to deactivate account',
            backgroundColor: Colors.red,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to deactivate account. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      Fluttertoast.showToast(
        msg: 'Error: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  /// State picker for the company address — web renders this field as a select
  /// over the 50 US states (`US_STATES_OPTIONS`), not a free-text input, and
  /// stores the full state name. The chosen value is written straight back into
  /// [_companyStateController] so the save payload and the change-detection
  /// comparison below keep reading the same field they always did.
  Widget buildStateDropdown() {
    final current = _companyStateController.text.trim();
    final isKnown = kUsStateNames.contains(current);

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outlineClr, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: isKnown ? current : null,
          // A value that doesn't match any option — free text typed before this
          // was a dropdown — is still shown rather than blanked, matching web's
          // `renderValue`. Picking from the list then replaces it.
          hint: Text(
            current.isEmpty ? 'Select State' : current,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: current.isEmpty ? mutedClr : Colors.black87,
            ),
          ),
          // The popup rows carry their own inset (see menuItemStyleData below
          // for why it can't come from the package's own padding).
          items: kUsStateNames
              .map((state) => DropdownMenuItem<String>(
                    value: state,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        state,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                      ),
                    ),
                  ))
              .toList(),
          // Without this the closed button would reuse the padded item widgets
          // above and sit 14px further right than the neighbouring inputs.
          // The Align is required: the package stretches each entry to
          // `menuItemStyleData.height`, and a bare Text would paint at the top
          // of that box instead of centred like DropdownMenuItem's own child.
          selectedItemBuilder: (context) => kUsStateNames
              .map((state) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      state,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _companyStateController.text = value);
          },
          buttonStyleData: const ButtonStyleData(
            padding: EdgeInsets.zero,
            height: 50,
          ),
          iconStyleData: IconStyleData(
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: blueColor, size: 22),
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight:
                (MediaQuery.sizeOf(context).height * 0.35).clamp(200.0, 320.0),
            elevation: 3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outlineClr),
            ),
          ),
          // Must stay zero. DropdownButton2 pads the closed button's text by
          // `menuItemStyleData.padding.horizontal / 2` whenever no explicit
          // button/dropdown width is set, so a padding of 12 here pushed
          // "Select State" 12px right of City and Country. The rows get their
          // inset from the Padding inside each item instead.
          menuItemStyleData: const MenuItemStyleData(
            height: 42,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller,
    String? Function(String?)? validator, {
    bool isEnabled = true,
    bool isRequired = false,
  }) {
    // Flat field, matching the house form style (add_tenants.dart `_input`):
    // a hairline outline instead of a drop shadow.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outlineClr, width: 1),
      ),
      child: Center(
        child: TextFormField(
          controller: controller,
          // validator: validator,
          validator: (value) {
            // Only validate if the field is required
            if (isRequired) {
              return validator != null ? validator(value) : null;
            }
            return null; // No validation for non-required fields
          },
          enabled: isEnabled,
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            hintText: label,
            hintStyle: const TextStyle(color: mutedClr),
          ),
        ),
      ),
    );
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a valid name';
    }
    return null;
  }

  /// Every field on this form — including Email and Phone Number — was wired
  /// to _validateFirstName, which only checks for emptiness. So `abc` saved as
  /// the admin's email address and `12` as the phone number, and a blank
  /// Email reported "Please enter a valid name". Same shape as the vendor
  /// profile's validators (VendorModule/screen/profile.dart).
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  String? _validateEmailAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an email address';
    }
    if (!EmailValidator.validate(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a phone number';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  // Initiate 2FA setup - send verification code
  void _initiate2FASetup() async {
    if (selected2FAMethod.isEmpty) return;

    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/2fa/enable-2fa'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "method": selected2FAMethod,
          "email": _emailController.text,
          "phone_number": _phoneNumberController.text,
          "admin_id": id
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          startTimer();
          setState(() {
            showVerificationInput = true;
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: 'Verification code sent to your ${selected2FAMethod}',
            backgroundColor: Colors.green,
          );
        } else {
          _timer?.cancel();
          setState(() {
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Failed to send verification code',
            backgroundColor: Colors.red,
          );
        }
      } else {
        _timer?.cancel();
        setState(() {
          isVerifyingCode = false;
        });
        Fluttertoast.showToast(
          msg: 'Failed to send verification code',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      _timer?.cancel();
      setState(() {
        isVerifyingCode = false;
      });
      Fluttertoast.showToast(
        msg: 'Error: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  // Verify code and enable 2FA
  void _verifyAndEnable2FA() async {
    if (verificationCodeController.text.length != 6) {
      return;
    }

    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/2fa/verify-2fa'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "method": selected2FAMethod,
          "code": verificationCodeController.text,
          "admin_id": id
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          stopTimer();
          setState(() {
            enble2FA = true;
            show2FASetup = false;
            showVerificationInput = false;
            isVerifyingCode = false;

            // Set the method flags
            if (selected2FAMethod == 'email') {
              email2FA = true;
              sms2FA = false;
            } else if (selected2FAMethod == 'sms') {
              sms2FA = true;
              email2FA = false;
            }

            selected2FAMethod = '';
            verificationCodeController.clear();
          });

          Fluttertoast.showToast(
            msg: '2FA enabled successfully!',
            backgroundColor: Colors.green,
          );
        } else {
          _timer?.cancel();
          setState(() {
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Invalid verification code',
            backgroundColor: Colors.red,
          );
        }
      } else {
        _timer?.cancel();
        Fluttertoast.showToast(
          msg: 'Invalid or expired verification code',
          backgroundColor: Colors.red,
        );
        setState(() {
          isVerifyingCode = false;
        });
      }
    } catch (e) {
      _timer?.cancel();
      setState(() {
        isVerifyingCode = false;
      });
    }
  }

  // Send disable 2FA code
  void _sendDisable2FACode() async {
    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/2fa/send-disable-2fa-code'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body:
            jsonEncode({"admin_id": id, "method": email2FA ? "email" : "sms"}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          // The server stamps this code with a 10 minute expiry, so start the
          // same countdown the enable flow uses. Also covers Resend, which
          // re-enters this method.
          startTimer();
          setState(() {
            showDisableVerification = true;
            isVerifyingCode = false;
          });

          Fluttertoast.showToast(
            msg:
                'Verification code sent to your ${email2FA ? "email" : "phone"}',
            backgroundColor: Colors.green,
          );
        } else {
          setState(() {
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Failed to send verification code',
            backgroundColor: Colors.red,
          );
        }
      } else {
        setState(() {
          isVerifyingCode = false;
        });
        Fluttertoast.showToast(
          msg: 'Failed to send verification code',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      setState(() {
        isVerifyingCode = false;
      });
      Fluttertoast.showToast(
        msg: 'Error: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  // Disable 2FA with verification code
  void _disable2FAWithVerification() async {
    if (disableVerificationController.text.length != 6) {
      Fluttertoast.showToast(
        msg: 'Please enter a valid 6-digit code',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/2fa/disable-2fa'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode(
            {"code": disableVerificationController.text, "admin_id": id}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          // 2FA is off now, so the countdown must not keep running and fire an
          // "expired" toast minutes later.
          stopTimer();
          setState(() {
            enble2FA = false;
            showDisableVerification = false;
            isVerifyingCode = false;
            email2FA = false;
            sms2FA = false;
            disableVerificationController.clear();
          });

          Fluttertoast.showToast(
            msg: '2FA disabled successfully!',
            backgroundColor: Colors.green,
          );
        } else {
          setState(() {
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Invalid verification code',
            backgroundColor: Colors.red,
          );
        }
      } else {
        setState(() {
          isVerifyingCode = false;
        });
        Fluttertoast.showToast(
          msg: 'Failed to disable 2FA',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      setState(() {
        isVerifyingCode = false;
      });
      Fluttertoast.showToast(
        msg: 'Error: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  // Send regenerate backup codes verification code
  void _sendRegenerateBackupCodesCode() async {
    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse(
            '${Api_url}/api/backup-codes/send-regenerate-backup-codes-code'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body:
            jsonEncode({"admin_id": id, "method": email2FA ? "email" : "sms"}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          setState(() {
            showRegenerateVerification = true;
            isVerifyingCode = false;
          });

          Fluttertoast.showToast(
            msg:
                'Verification code sent to your ${email2FA ? "email" : "phone"}',
            backgroundColor: Colors.green,
          );
        } else {
          setState(() {
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Failed to send verification code',
            backgroundColor: Colors.red,
          );
        }
      } else {
        setState(() {
          isVerifyingCode = false;
        });
        Fluttertoast.showToast(
          msg: 'Failed to send verification code',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      setState(() {
        isVerifyingCode = false;
      });
      Fluttertoast.showToast(
        msg: 'Error: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  // Regenerate backup codes with verification code
  void _regenerateBackupCodesWithVerification() async {
    // if (regenerateVerificationController.text.length != 6) {
    //   Fluttertoast.showToast(
    //     msg: 'Please enter a valid 6-digit code',
    //     backgroundColor: Colors.orange,
    //   );
    //   return;
    // }

    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString("token");
      String? userid = prefs.getString("userId");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/backup-codes/generate-backup-codes'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"user_id": id, "user_type": "admin"}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          setState(() {
            showRegenerateVerification = false;
            isVerifyingCode = false;
            regenerateVerificationController.clear();
            // Update the codes with the new generated codes
            codes = List<Map<String, dynamic>>.from(jsonData["data"]["codes"]);
            backupCode = true;
          });
          // Show the backup codes modal
          _showBackupCodesModal();
        } else {
          setState(() {
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: jsonData["message"] ?? 'Invalid verification code',
            backgroundColor: Colors.red,
          );
        }
      } else {
        setState(() {
          isVerifyingCode = false;
        });
        Fluttertoast.showToast(
          msg: 'Failed to regenerate backup codes',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      setState(() {
        isVerifyingCode = false;
      });
      Fluttertoast.showToast(
        msg: 'Error: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  // Show backup codes modal
  void _showBackupCodesModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Backup Codes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Important banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Important: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'These backup codes can be used to access your account if you lose access to your 2FA device. Each code can only be used once. Store them in a safe place and don\'t share them with anyone.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Remaining count + Download, the way web shows them. The list
                // endpoint filters used codes out, so codes.length IS the
                // number still valid.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your Backup Codes (${codes.length} remaining)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _downloadBackupCodes,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Backup codes list
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: codes.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> codeData = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: blueColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                codeData['code'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _copyToClipboard(codeData['code'] ?? ''),
                              icon: const Icon(Icons.copy, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Note box — web shows this under the list.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1ECF1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBEE5EB)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: const [
                        TextSpan(
                          text: 'Note: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0C5460),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text:
                              'When you generate new backup codes, all previous codes will be invalidated. Make sure to save these new codes in a secure location.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0C5460),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Close',
                style: TextStyle(
                  color: blueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Copy to clipboard function
  void _copyToClipboard(String text) {
    // Clipboard ships with Flutter via services.dart (now imported) —
    // the old comment claiming a package was needed was wrong, so the copy
    // icon only ever showed a toast. Web writes the code to the clipboard and
    // says "Code copied to clipboard!", without echoing the code itself.
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: 'Code copied to clipboard!',
      backgroundColor: Colors.green,
    );
  }

  // Download backup codes to file
  void _downloadBackupCodes() async {
    try {
      // Create the content for the text file
      String content = '';

      content += '';

      for (int i = 0; i < codes.length; i++) {
        content += '${i + 1}. ${codes[i]['code']}\n';
      }

      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      final file = File(
          // Web names the download backup-codes-YYYY-MM-DD.txt.
          '${directory.path}/backup-codes-${DateTime.now().toIso8601String().split('T').first}.txt');

      // Write the content to the file
      await file.writeAsString(content);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Backup Codes for Cloud Rental Manager',
        subject: 'Backup Codes - Cloud Rental Manager',
      );

      Fluttertoast.showToast(
        msg: 'Backup codes file created and ready to share!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error generating backup codes file: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
      );
    }
  }

  // Dialog for disabling 2FA
  void _showDisable2FADialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600, size: 24),
              SizedBox(width: 8),
              Text(
                'Disable 2FA',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to disable Two-Factor Authentication?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.red.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will make your account less secure. We recommend keeping 2FA enabled.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement actual disable 2FA functionality
                Fluttertoast.showToast(
                  msg: '2FA disable functionality will be implemented',
                  backgroundColor: Colors.orange,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Disable 2FA'),
            ),
          ],
        );
      },
    );
  }

  // Dialog for regenerating backup codes
  void _showRegenerateBackupCodesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.refresh, color: blueColor, size: 24),
              SizedBox(width: 8),
              Text(
                'Regenerate Backup Codes',
                style: TextStyle(
                  color: blueColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will generate new backup codes for your account. Your old backup codes will no longer work.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: blueColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: blueColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: blueColor, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Make sure to save the new backup codes in a secure location.',
                        style: TextStyle(
                          color: blueColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement actual regenerate backup codes functionality
                Fluttertoast.showToast(
                  msg:
                      'Backup codes regeneration functionality will be implemented',
                  backgroundColor: blueColor,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Generate New Codes'),
            ),
          ],
        );
      },
    );
  }
}

class ProfileShimmer extends StatefulWidget {
  const ProfileShimmer({super.key});

  @override
  State<ProfileShimmer> createState() => _ProfileShimmerState();
}

class _ProfileShimmerState extends State<ProfileShimmer> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Skeleton cards carry the same shell as the loaded page —
            // hairline grey border, radius 16 — so nothing flashes from a
            // borderless/blue frame to the real card once data lands.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E9F0)),
                  borderRadius: BorderRadius.circular(16.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(
                    decoration: BoxDecoration(
                        color: blueColor,
                        borderRadius: BorderRadius.circular(10.0)),
                    height: 190,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E9F0)),
                  borderRadius: BorderRadius.circular(16.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 50,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 20,
                        width: 180,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 15,
                        width: 120,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 50,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 15,
                        width: 120,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 50,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 15,
                        width: 120,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 50,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 15,
                        width: 120,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 50,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(8.0)),
                        height: 30,
                        width: 140,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
