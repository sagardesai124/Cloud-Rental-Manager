import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import '../../constant/constant.dart';
import '../../repository/profile_repository.dart';
import '../widgets/drawer_tiles.dart';
import '../widgets/appbar.dart';
import '../widgets/custom_drawer.dart';
import '../../widgets/titleBar.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class Profile_screen extends StatefulWidget {
  const Profile_screen({Key? key}) : super(key: key);
  @override
  State<Profile_screen> createState() => _Profile_screenState();
}

class _Profile_screenState extends State<Profile_screen>
    with NetworkRetryState {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  profile? _profile;
  Map<String, dynamic> profiledata = {};

  // 2FA Variables
  bool enble2FA = false;
  bool disable2FA = false;
  bool sms2FA = false;
  bool email2FA = false;
  bool show2FASetup = false;
  bool backupCode = false;
  List<Map<String, dynamic>> codes = [];
  String selected2FAMethod = '';

  // Web parity (TwoFactorAuthComponent.js): the SMS radio is disabled when the
  // staff member has no phone number and the Email radio when there is no
  // e-mail, and the Enable button is additionally blocked when the *selected*
  // method has no destination. _pf() maps a missing key to '', but the stored
  // value can itself be an empty string, so trim-and-test covers null + ''.
  String get _phone2FA => _pf('staffmember_phoneNumber').trim();
  String get _email2FA => _pf('staffmember_email').trim();
  bool get _canUseSms2FA => _phone2FA.isNotEmpty;
  bool get _canUseEmail2FA => _email2FA.isNotEmpty;
  bool get _can2FAEnable =>
      selected2FAMethod.isNotEmpty &&
      !(selected2FAMethod == 'sms' && !_canUseSms2FA) &&
      !(selected2FAMethod == 'email' && !_canUseEmail2FA);
  TextEditingController verificationCodeController = TextEditingController();
  bool isVerifyingCode = false;
  bool showVerificationInput = false;
  bool showDisableVerification = false;
  bool showRegenerateVerification = false;
  TextEditingController disableVerificationController = TextEditingController();
  TextEditingController regenerateVerificationController =
      TextEditingController();

  // 10 minute countdown for a freshly issued 2FA code — the server stamps
  // expires_at at 600s, and the Admin profile and web show the same.
  Timer? _timer;
  ValueNotifier<int> seconds = ValueNotifier(600);

  // True only once the countdown actually ran out. Web disables the code field
  // and the submit button in that state rather than posting a dead code.
  bool is2FACodeExpired = false;

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
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

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
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
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

  Future<void> fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    //  String? token = prefs.getString('token');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("staff_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final String apiUrl = "${Api_url}/api/staffmember/staffmember_profile/$id";
    final response = await apiGet(
      Uri.parse('$apiUrl'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final response_Data = jsonDecode(response.body);
    if (response_Data["statusCode"] == 200) {
      setState(() {
        profiledata = response_Data["data"];
        _isLoading = false;
      });
      status2FA(); // Fetch 2FA status on screen load
      backupcodeapicall();
      // return profile.fromJson(jsonDecode(response.body)["data"]);
    } else {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to load profile');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      await fetchProfile();
      /* final profileData = await fetchProfile();
      setState(() {
        _profile = profileData;
        _firstNameController.text = profileData.firstName ?? '';
        _lastNameController.text = profileData.lastName ?? '';
        _emailController.text = profileData.email ?? '';
        _phoneNumberController.text = profileData.phoneNumber?.toString() ?? '';
        _companyNameController.text = profileData.companyName ?? '';
        _isLoading = false;
      });*/
    } catch (e, st) {
      logError('❌ [StaffProfile] load failed: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 2FA Status Check
  void status2FA() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString("token");

    setState(() {
      _isLoading = true;
    });

    final response = await apiGet(
      Uri.parse('${Api_url}/api/2fa/2fa-status/${id}?user_type=staff'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      if (jsonData["statusCode"] == 200 && jsonData["data"] != null) {
        final data = jsonData["data"];
        final bool enabled = data["enabled"] ?? false;
        final String method = data["method"] ?? "";

        setState(() {
          enble2FA = enabled;

          if (method.toLowerCase() == "email") {
            email2FA = true;
            sms2FA = false;
          } else if (method.toLowerCase() == "sms") {
            sms2FA = true;
            email2FA = false;
          } else {
            email2FA = false;
            sms2FA = false;
          }
        });
      } else {
        setState(() {
          enble2FA = false;
          email2FA = false;
          sms2FA = false;
        });
      }
    } else {
      setState(() {
        enble2FA = false;
        email2FA = false;
        sms2FA = false;
      });
    }
  }

  // Backup Codes API Call
  Future<void> backupcodeapicall() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString("token");
    String? userid = prefs.getString("userId");

    final response = await apiGet(
      Uri.parse(
          '${Api_url}/api/backup-codes/backup-codes/${userid}?user_type=staff'),
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

  // Initiate 2FA setup - send verification code
  @override
  void dispose() {
    _connectivitySub?.cancel();
    _timer?.cancel();
    seconds.dispose();
    super.dispose();
  }

  void startTimer() {
    // Cancel any existing timer first
    _timer?.cancel();

    // A fresh code is being issued, so drop any expired state. Callers run
    // setState right after this, which repaints the field and button.
    is2FACodeExpired = false;

    // 10 minutes timer for 2FA verification code
    seconds.value = 600;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds.value > 0) {
        seconds.value--;
      } else {
        _timer?.cancel();
        // The dead code is cleared and cannot be submitted until a new one is
        // requested. Both fields are cleared because one timer serves the
        // enable and disable flows, which are never on screen together.
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
  /// their own row to match the login screen and the Admin profile.
  Widget _build2FACodeTimerRow({required VoidCallback onResend}) {
    return ValueListenableBuilder<int>(
      valueListenable: seconds,
      builder: (context, value, child) {
        // Locked for the first 60s of the 10 minute window, and while a
        // request is already in flight — same gating as web and login.
        final bool canResend = value <= 540 && !isVerifyingCode;
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

  void _initiate2FASetup() async {
    if (selected2FAMethod.isEmpty) return;

    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
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
          "email": _pf('staffmember_email'),
          "phone_number": _pf('staffmember_phoneNumber'),
          "user_id": id,
          "user_type": "staff"
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          // The code carries a 10 minute server-side expiry, so start the
          // countdown. Resend re-enters this method.
          startTimer();
          setState(() {
            showVerificationInput = true;
            isVerifyingCode = false;
          });
        } else {
          setState(() {
            isVerifyingCode = false;
          });
        }
      } else {
        setState(() {
          isVerifyingCode = false;
        });
      }
    } catch (e) {
      setState(() {
        isVerifyingCode = false;
      });
    }
  }

  // Verify code and enable 2FA
// i want to add a toast message if the verification code is invalid  and if verification code is sent successfully and  if
  void _verifyAndEnable2FA() async {
    if (verificationCodeController.text.length != 6) {
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
      String? id = prefs.getString("staff_id");
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
          "user_id": id,
          "user_type": "staff"
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          // Code accepted — the countdown is no longer relevant.
          stopTimer();
          setState(() {
            enble2FA = true;
            show2FASetup = false;
            showVerificationInput = false;
            isVerifyingCode = false;

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
            msg: '${jsonData["message"]}',
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

  // Send disable 2FA code
  void _sendDisable2FACode() async {
    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/2fa/send-disable-2fa-code'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "user_id": id,
          "method": email2FA ? "email" : "sms",
          "user_type": "staff"
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          // Same 10 minute expiry as the enable code.
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
      return;
    }

    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
      String? token = prefs.getString("token");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/2fa/disable-2fa'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "code": disableVerificationController.text,
          "user_id": id,
          "user_type": "staff"
        }),
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
        } else {
          setState(() {
            isVerifyingCode = false;
          });
        }
        Fluttertoast.showToast(
          msg: '${jsonData["message"]}',
          backgroundColor: Colors.green,
        );
      } else {
        setState(() {
          isVerifyingCode = false;
        });
        Fluttertoast.showToast(
          msg: 'Invalid or expired verification code',
          backgroundColor: Colors.red,
        );
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

  // Send regenerate backup codes verification code
  void _sendRegenerateBackupCodesCode() async {
    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
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
            jsonEncode({"staff_id": id, "method": email2FA ? "email" : "sms"}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          setState(() {
            showRegenerateVerification = true;
            isVerifyingCode = false;
          });
          Fluttertoast.showToast(
            msg: '${jsonData["message"]}',
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
    setState(() {
      isVerifyingCode = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
      String? token = prefs.getString("token");
      String? userid = prefs.getString("userId");

      final response = await apiPost(
        Uri.parse('${Api_url}/api/backup-codes/generate-backup-codes'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"user_id": id, "user_type": "staff"}),
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
    // Clipboard ships with Flutter via services.dart (now imported).
    // Without this the copy icon only showed a toast and never copied.
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: 'Code copied to clipboard!',
      backgroundColor: Colors.green,
    );
  }

  // Download backup codes to file
  Future<void> _downloadBackupCodes() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();

      // Create the content for the text file
      String content = '';
      for (int i = 0; i < codes.length; i++) {
        content += '${i + 1}. ${codes[i]['code']}\n';
      }

      // Get the Downloads directory
      Directory directory;
      if (Platform.isAndroid) {
        directory = await getApplicationDocumentsDirectory();
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Create the file
      final file = File(
          // Web names the download backup-codes-YYYY-MM-DD.txt.
          '${directory.path}/backup-codes-${DateTime.now().toIso8601String().split('T').first}.txt');
      await file.writeAsString(content);

      // Show success toast
      Fluttertoast.showToast(
        msg: 'Backup codes saved to Downloads!',
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_SHORT,
      );

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Backup Codes for Cloud Rental Manager',
        subject: 'Backup Codes - Cloud Rental Manager',
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error generating backup codes file: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(currentpage: 'Dashboard', dropdown: false),
      body: !isOffline
          ? _isLoading
              ? Center(
                  child: SpinKitFadingCircle(
                    color: Colors.black,
                    size: 50.0,
                  ),
                )
              : _hasError
                  ? isNetworkError(_errorMessage)
                      ? NoInternetView(onRetry: retryNow)
                      : Center(
                          child: Text(friendlyErrorMessage(_errorMessage)),
                        )
                  : LayoutBuilder(builder: (context, constraints) {
                      if (constraints.maxWidth > 500) {
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(height: 30),
                              titleBar(
                                title: 'My Profile',
                                width: MediaQuery.of(context).size.width * 0.90,
                                radius: 12,
                              ),
                              SizedBox(height: 16),
                              _personalDetailsCard(),
                              SizedBox(height: 30),
                              // 2FA Section — the card below carries its own header
                              // (title + subtitle + toggle), matching web, so no separate
                              // navy title bar here.
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final double width = constraints.maxWidth;
                                  final double screenWidth =
                                      MediaQuery.of(context).size.width;

                                  // Responsive factors
                                  double horizontalPadding = screenWidth < 400
                                      ? 8
                                      : screenWidth < 600
                                          ? screenWidth * 0.04
                                          : screenWidth * 0.1;
                                  double contentPadding = screenWidth < 400
                                      ? 8
                                      : screenWidth < 600
                                          ? 12
                                          : 20;
                                  double rowSpacing =
                                      screenWidth < 400 ? 6 : 10;
                                  double fontSizeTitle =
                                      screenWidth < 400 ? 12 : 16;
                                  double fontSizeAction =
                                      screenWidth < 400 ? 12 : 16;
                                  double buttonHeight =
                                      screenWidth < 400 ? 38 : 48;
                                  double bigButtonHeight =
                                      screenWidth < 400 ? 48 : 60;
                                  double innerPadding =
                                      screenWidth < 400 ? 6 : 16;

                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding,
                                        vertical: 10),
                                    child: Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.all(contentPadding),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Two-Factor Authentication (2FA)",
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: rowSpacing),
                                                Switch(
                                                  activeColor: blueColor,
                                                  // Follows web's twoFactorToggle: on when
                                                  // 2FA is enabled OR while setting it up.
                                                  value:
                                                      enble2FA || show2FASetup,
                                                  onChanged: (value) {
                                                    if (isVerifyingCode) return;
                                                    if (value) {
                                                      if (enble2FA) return;
                                                      setState(() {
                                                        show2FASetup = true;
                                                        showVerificationInput =
                                                            false;
                                                        selected2FAMethod = '';
                                                      });
                                                    } else if (enble2FA) {
                                                      // Web keeps 2FA enabled and only asks
                                                      // for a code; the flag flips after the
                                                      // code is verified.
                                                      if (showDisableVerification)
                                                        return;
                                                      _sendDisable2FACode();
                                                    } else {
                                                      stopTimer();
                                                      setState(() {
                                                        show2FASetup = false;
                                                        showVerificationInput =
                                                            false;
                                                        showDisableVerification =
                                                            false;
                                                        selected2FAMethod = '';
                                                        verificationCodeController
                                                            .clear();
                                                        disableVerificationController
                                                            .clear();
                                                      });
                                                    }
                                                  },
                                                )
                                              ],
                                            ),

                                            // Show different content based on 2FA state
                                            if (!enble2FA && !show2FASetup)
                                              Padding(
                                                padding: EdgeInsets.zero,
                                                child: Text(
                                                  "Turn on the toggle above to enable Two-Factor Authentication for enhanced security.",
                                                  style: TextStyle(
                                                    color:
                                                        const Color(0xFF6B7A90),
                                                    fontSize: 13,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),

                                            // 2FA Setup Flow
                                            // Web renders the chooser only in its
                                            // `!twoFactorEnabled` arm, so it can never sit
                                            // beside the disable-code form.
                                            if (show2FASetup &&
                                                !showVerificationInput &&
                                                !enble2FA &&
                                                !showDisableVerification)
                                              Padding(
                                                // Card padding already sets the left edge; no extra inset,
                                                // so this block starts level with the title.
                                                padding: EdgeInsets.zero,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Choose your preferred method",
                                                      style: TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: fontSizeTitle,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        height:
                                                            rowSpacing * 2.0),
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
                                                    SizedBox(
                                                        height:
                                                            rowSpacing * 3.0),

                                                    // Enable 2FA Button
                                                    SizedBox(
                                                      width: double.infinity,
                                                      height: buttonHeight,
                                                      child: ElevatedButton(
                                                        onPressed: _can2FAEnable
                                                            ? () {
                                                                // isVerifyingCode is set
                                                                // synchronously by
                                                                // _initiate2FASetup, so a second
                                                                // fast tap cannot send a second
                                                                // code.
                                                                if (isVerifyingCode) {
                                                                  return;
                                                                }
                                                                _initiate2FASetup();
                                                              }
                                                            : null,
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              blueColor,
                                                          // Web design: disabled = light grey pill.
                                                          disabledBackgroundColor:
                                                              const Color(
                                                                  0xFFE5E8ED),
                                                          disabledForegroundColor:
                                                              const Color(
                                                                  0xFF9AA3B0),
                                                          elevation: 0,
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          "Enable 2FA",
                                                          style: TextStyle(
                                                            fontSize:
                                                                fontSizeAction,
                                                            fontWeight:
                                                                FontWeight.w600,
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
                                                // Card padding already sets the left edge; no extra inset,
                                                // so this block starts level with the title.
                                                padding: EdgeInsets.zero,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Enter verification code sent to your ${selected2FAMethod == 'email' ? 'email' : 'phone'}:",
                                                      style: TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: fontSizeTitle,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        height:
                                                            rowSpacing * 2.0),

                                                    // Verification Code Input Field
                                                    TextField(
                                                      controller:
                                                          verificationCodeController,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      maxLength: 6,
                                                      // Web greys the field out once the
                                                      // code has expired.
                                                      enabled:
                                                          !is2FACodeExpired,
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          letterSpacing: 1.5,
                                                          color: Color(
                                                              0xFF152B51)),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            "Enter 6-digit code",
                                                        hintStyle:
                                                            const TextStyle(
                                                                color: Color(
                                                                    0xFF94A1B4),
                                                                letterSpacing:
                                                                    0.5),
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                        focusedBorder:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          borderSide:
                                                              BorderSide(
                                                                  color:
                                                                      blueColor,
                                                                  width: 2),
                                                        ),
                                                        counterText: "",
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 14,
                                                                vertical: 16),
                                                      ),
                                                    ),

                                                    SizedBox(
                                                        height: rowSpacing),

                                                    // The code expires 10 minutes after it
                                                    // is issued, so show the countdown and
                                                    // a way to request a new one.
                                                    _build2FACodeTimerRow(
                                                      onResend: () {
                                                        // The previous code is dead once a
                                                        // new one is issued.
                                                        verificationCodeController
                                                            .clear();
                                                        _initiate2FASetup();
                                                      },
                                                    ),

                                                    SizedBox(
                                                        height:
                                                            rowSpacing * 3.0),

                                                    // Verify & Enable Button
                                                    // Web design: Cancel + solid Disable side by side.
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: SizedBox(
                                                            height:
                                                                buttonHeight,
                                                            child:
                                                                OutlinedButton(
                                                              onPressed: () {
                                                                // Leaving the flow must not leave a countdown ticking.
                                                                stopTimer();
                                                                setState(() {
                                                                  showDisableVerification =
                                                                      false;
                                                                  disableVerificationController
                                                                      .clear();
                                                                });
                                                              },
                                                              style:
                                                                  OutlinedButton
                                                                      .styleFrom(
                                                                side: const BorderSide(
                                                                    color: Color(
                                                                        0xFFE2E6EC)),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                "Cancel",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      blueColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: SizedBox(
                                                            height:
                                                                buttonHeight,
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: (isVerifyingCode ||
                                                                      is2FACodeExpired)
                                                                  ? null
                                                                  : () =>
                                                                      _disable2FAWithVerification(),
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFFDC3545),
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                elevation: 0,
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                              ),
                                                              child: isVerifyingCode
                                                                  ? const SizedBox(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        color: Colors
                                                                            .white,
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    )
                                                                  : const Text(
                                                                      "Disable 2FA",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                        fontWeight:
                                                                            FontWeight.bold,
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

                                            // 2FA Enabled Status
                                            if (enble2FA && !show2FASetup)
                                              Padding(
                                                // Card padding already sets the left edge; no extra inset,
                                                // so this block starts level with the title.
                                                padding: EdgeInsets.zero,
                                                child: Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 14,
                                                      vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFE7F7EE),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.check,
                                                          size: 18,
                                                          color: Color(
                                                              0xFF1F9D55)),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          email2FA
                                                              ? "2FA is enabled via Email"
                                                              : sms2FA
                                                                  ? "2FA is enabled via SMS"
                                                                  : "2FA is enabled",
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF1F9D55),
                                                            fontSize: 14.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            // Verification-method tile (web design). Main
                                            // enabled view only - the disable card names the
                                            // destination itself.
                                            if (enble2FA &&
                                                !show2FASetup &&
                                                !showDisableVerification &&
                                                !showRegenerateVerification)
                                              Padding(
                                                // Same horizontal inset as the status banner and the action
                                                // buttons, so the card's blocks line up down one edge.
                                                padding: const EdgeInsets.only(
                                                    top: 12),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFFE8ECF1)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        sms2FA && !email2FA
                                                            ? Icons.sms_outlined
                                                            : Icons
                                                                .mail_outline,
                                                        size: 22,
                                                        color: const Color(
                                                            0xFF2C72E0),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              "VERIFICATION METHOD",
                                                              style: TextStyle(
                                                                color: Color(
                                                                    0xFF6B7A90),
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                letterSpacing:
                                                                    0.8,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                              sms2FA &&
                                                                      !email2FA
                                                                  ? _phone2FA
                                                                  : _email2FA,
                                                              style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                            SizedBox(height: rowSpacing * 3.0),

                                            // Disable 2FA Verification Input
                                            // Web nests this inside the `twoFactorEnabled`
                                            // arm — it only makes sense while 2FA is on.
                                            if (showDisableVerification &&
                                                enble2FA)
                                              Padding(
                                                // Card padding already sets the left edge; no extra inset,
                                                // so this block starts level with the title.
                                                padding: EdgeInsets.zero,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: double.infinity,
                                                      padding:
                                                          const EdgeInsets.all(
                                                              14),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFFFFFFF),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFFE4E8EF)),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "Enter verification code to disable 2FA",
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontSize: 14.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            "Sent to ${email2FA ? _email2FA : (sms2FA ? _phone2FA : _email2FA)}",
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFF6B7A90),
                                                              fontSize: 12.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 12),

                                                          SizedBox(
                                                              height:
                                                                  rowSpacing *
                                                                      2.0),

                                                          // Verification Code Input Field
                                                          TextField(
                                                            style: const TextStyle(
                                                                fontSize: 15,
                                                                letterSpacing:
                                                                    1.5,
                                                                color: Color(
                                                                    0xFF152B51)),
                                                            controller:
                                                                disableVerificationController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            maxLength: 6,
                                                            // Web greys the field out once the
                                                            // code has expired.
                                                            enabled:
                                                                !is2FACodeExpired,
                                                            decoration:
                                                                InputDecoration(
                                                              contentPadding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          14,
                                                                      vertical:
                                                                          16),
                                                              hintText:
                                                                  "Enter 6-digit code",
                                                              hintStyle: const TextStyle(
                                                                  color: Color(
                                                                      0xFF94A1B4),
                                                                  letterSpacing:
                                                                      0.5),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                borderSide:
                                                                    const BorderSide(
                                                                        color: Colors
                                                                            .grey),
                                                              ),
                                                              focusedBorder:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                borderSide:
                                                                    const BorderSide(
                                                                        color: Colors
                                                                            .red,
                                                                        width:
                                                                            2),
                                                              ),
                                                              counterText: "",
                                                            ),
                                                          ),

                                                          SizedBox(
                                                              height:
                                                                  rowSpacing),

                                                          // Same 10 minute expiry as the enable
                                                          // code — countdown plus Resend.
                                                          _build2FACodeTimerRow(
                                                            onResend: () {
                                                              disableVerificationController
                                                                  .clear();
                                                              _sendDisable2FACode();
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    SizedBox(
                                                        height:
                                                            rowSpacing * 3.0),

                                                    // Disable 2FA Button
                                                    // Web design: Cancel + solid Disable side by side.
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: SizedBox(
                                                            height:
                                                                buttonHeight,
                                                            child:
                                                                OutlinedButton(
                                                              onPressed: () {
                                                                // Leaving the flow must not leave a countdown ticking.
                                                                stopTimer();
                                                                setState(() {
                                                                  showDisableVerification =
                                                                      false;
                                                                  disableVerificationController
                                                                      .clear();
                                                                });
                                                              },
                                                              style:
                                                                  OutlinedButton
                                                                      .styleFrom(
                                                                side: const BorderSide(
                                                                    color: Color(
                                                                        0xFFE2E6EC)),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                "Cancel",
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      blueColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: SizedBox(
                                                            height:
                                                                buttonHeight,
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: (isVerifyingCode ||
                                                                      is2FACodeExpired)
                                                                  ? null
                                                                  : () =>
                                                                      _disable2FAWithVerification(),
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFFDC3545),
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                elevation: 0,
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                              ),
                                                              child: isVerifyingCode
                                                                  ? const SizedBox(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        color: Colors
                                                                            .white,
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    )
                                                                  : const Text(
                                                                      "Disable 2FA",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                        fontWeight:
                                                                            FontWeight.bold,
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

                                            // 2FA Action Buttons
                                            // Also hidden during an enable flow, else
                                            // "Disable 2FA" stays tappable under the chooser
                                            // and re-creates the overlap from the other side.
                                            if (enble2FA &&
                                                !showDisableVerification &&
                                                !showRegenerateVerification &&
                                                !show2FASetup &&
                                                !showVerificationInput)
                                              Padding(
                                                // Card padding already sets the left edge; no extra inset,
                                                // so this block starts level with the title.
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                child: width > 420
                                                    ? Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          // Disable 2FA Button
                                                          Expanded(
                                                            flex: 1,
                                                            child: SizedBox(
                                                              height:
                                                                  bigButtonHeight,
                                                              child:
                                                                  ElevatedButton(
                                                                onPressed: () {
                                                                  // showDisableVerification only
                                                                  // flips after the 200, so it
                                                                  // cannot stop a double tap on
                                                                  // its own; isVerifyingCode is
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
                                                                      width:
                                                                          1.2),
                                                                  elevation: 0,
                                                                  padding: EdgeInsets
                                                                      .symmetric(
                                                                          horizontal:
                                                                              8),
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .security,
                                                                        size:
                                                                            18),
                                                                    SizedBox(
                                                                        width:
                                                                            rowSpacing),
                                                                    Flexible(
                                                                      child:
                                                                          Text(
                                                                        "Disable 2FA",
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              fontSizeAction - 2,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          if (width > 420)
                                                            SizedBox(
                                                                width:
                                                                    rowSpacing *
                                                                        2)
                                                          else
                                                            SizedBox(height: 8),
                                                          // Regenerate Backup Codes Button
                                                          Expanded(
                                                            flex: 1,
                                                            child: SizedBox(
                                                              height:
                                                                  bigButtonHeight,
                                                              child:
                                                                  ElevatedButton(
                                                                onPressed: () {
                                                                  // Blocks the second of two fast
                                                                  // taps generating a second set
                                                                  // of backup codes.
                                                                  if (isVerifyingCode) {
                                                                    return;
                                                                  }
                                                                  _regenerateBackupCodesWithVerification();
                                                                },
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .white,
                                                                  foregroundColor:
                                                                      blueColor,
                                                                  side: const BorderSide(
                                                                      color: Color(
                                                                          0xFFE2E6EC),
                                                                      width:
                                                                          1.2),
                                                                  elevation: 0,
                                                                  padding: EdgeInsets
                                                                      .symmetric(
                                                                          horizontal:
                                                                              8),
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const Icon(
                                                                        Icons
                                                                            .refresh,
                                                                        size:
                                                                            18),
                                                                    SizedBox(
                                                                        width:
                                                                            rowSpacing),
                                                                    Flexible(
                                                                      child: codes
                                                                              .isEmpty
                                                                          ? Text(
                                                                              "Backup Codes",
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                              textAlign: TextAlign.center,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              maxLines: 2,
                                                                            )
                                                                          : Text(
                                                                              "Regenerate Backup Codes",
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w600,
                                                                              ),
                                                                              textAlign: TextAlign.center,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              maxLines: 2,
                                                                            ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Column(
                                                        children: [
                                                          // Disable 2FA Button
                                                          SizedBox(
                                                            width:
                                                                double.infinity,
                                                            height:
                                                                bigButtonHeight,
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: () {
                                                                // showDisableVerification only
                                                                // flips after the 200;
                                                                // isVerifyingCode is set
                                                                // synchronously.
                                                                if (isVerifyingCode ||
                                                                    showDisableVerification) {
                                                                  return;
                                                                }
                                                                _sendDisable2FACode();
                                                              },
                                                              style:
                                                                  ElevatedButton
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
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .security,
                                                                      size: 18),
                                                                  SizedBox(
                                                                      width:
                                                                          rowSpacing),
                                                                  Flexible(
                                                                    child: Text(
                                                                      "Disable 2FA",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            fontSizeAction -
                                                                                2,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(height: 8),
                                                          // Regenerate Backup Codes Button
                                                          SizedBox(
                                                            width:
                                                                double.infinity,
                                                            height:
                                                                bigButtonHeight,
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: () {
                                                                // Blocks a double tap generating a
                                                                // second set of backup codes.
                                                                if (isVerifyingCode) {
                                                                  return;
                                                                }
                                                                _regenerateBackupCodesWithVerification();
                                                              },
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .white,
                                                                foregroundColor:
                                                                    blueColor,
                                                                side: const BorderSide(
                                                                    color: Color(
                                                                        0xFFE2E6EC),
                                                                    width: 1.2),
                                                                elevation: 0,
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                      Icons
                                                                          .refresh,
                                                                      size: 18),
                                                                  SizedBox(
                                                                      width:
                                                                          rowSpacing),
                                                                  Flexible(
                                                                    child: codes
                                                                            .isEmpty
                                                                        ? Text(
                                                                            "Backup Codes",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                            maxLines:
                                                                                2,
                                                                          )
                                                                        : Text(
                                                                            "Regenerate Backup Codes",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
                                                                            maxLines:
                                                                                2,
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
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 30),
                            ],
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            titleBar(
                              title: 'My Profile',
                              width: MediaQuery.of(context).size.width - 32,
                              radius: 12,
                            ),
                            const SizedBox(height: 12),
                            _personalDetailsCard(),
                            const SizedBox(height: 20),
                            // 2FA Section — the card below carries its own header
                            // (title + subtitle + toggle), matching web, so no separate
                            // navy title bar here.
                            LayoutBuilder(
                              builder: (context, constraints) {
                                double cardPadding =
                                    constraints.maxWidth < 500 ? 16 : 20;
                                double horizontalContentPadding =
                                    constraints.maxWidth < 400 ? 8 : 16;
                                double titleFontSize =
                                    constraints.maxWidth < 400 ? 14 : 16;
                                double inputFontSize =
                                    constraints.maxWidth < 400 ? 14 : 16;
                                double buttonFontSize =
                                    constraints.maxWidth < 400 ? 13 : 16;

                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: cardPadding),
                                  child: Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.all(
                                          constraints.maxWidth < 400 ? 8 : 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
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
                                                            FontWeight.bold,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                  width:
                                                      constraints.maxWidth < 360
                                                          ? 5
                                                          : 10),
                                              Switch(
                                                activeColor: blueColor,
                                                // Follows web's twoFactorToggle: on when 2FA
                                                // is enabled OR while setting it up.
                                                value: enble2FA || show2FASetup,
                                                onChanged: (value) {
                                                  if (isVerifyingCode) return;
                                                  if (value) {
                                                    if (enble2FA) return;
                                                    setState(() {
                                                      show2FASetup = true;
                                                      showVerificationInput =
                                                          false;
                                                      selected2FAMethod = '';
                                                    });
                                                  } else if (enble2FA) {
                                                    // Web keeps 2FA enabled and only asks for
                                                    // a code; the flag flips after the code
                                                    // is verified.
                                                    if (showDisableVerification)
                                                      return;
                                                    _sendDisable2FACode();
                                                  } else {
                                                    stopTimer();
                                                    setState(() {
                                                      show2FASetup = false;
                                                      showVerificationInput =
                                                          false;
                                                      showDisableVerification =
                                                          false;
                                                      selected2FAMethod = '';
                                                      verificationCodeController
                                                          .clear();
                                                      disableVerificationController
                                                          .clear();
                                                    });
                                                  }
                                                },
                                              )
                                            ],
                                          ),
                                          if (!enble2FA && !show2FASetup)
                                            Padding(
                                              padding: EdgeInsets.zero,
                                              child: Text(
                                                "Turn on the toggle above to enable Two-Factor Authentication for enhanced security.",
                                                style: TextStyle(
                                                  color:
                                                      const Color(0xFF6B7A90),
                                                  fontSize: 13,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          // Web renders the chooser only in its
                                          // `!twoFactorEnabled` arm, so it can never sit
                                          // beside the disable-code form.
                                          if (show2FASetup &&
                                              !showVerificationInput &&
                                              !enble2FA &&
                                              !showDisableVerification)
                                            Padding(
                                              // Card padding already sets the left edge; no extra inset,
                                              // so this block starts level with the title.
                                              padding: EdgeInsets.zero,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Choose your preferred method",
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: titleFontSize,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: 42,
                                                    child: ElevatedButton(
                                                      onPressed: _can2FAEnable
                                                          ? () {
                                                              // isVerifyingCode is set
                                                              // synchronously by
                                                              // _initiate2FASetup, so a second
                                                              // fast tap cannot send a second
                                                              // code.
                                                              if (isVerifyingCode) {
                                                                return;
                                                              }
                                                              _initiate2FASetup();
                                                            }
                                                          : null,
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            blueColor,
                                                        // Web design: disabled = light grey pill.
                                                        disabledBackgroundColor:
                                                            const Color(
                                                                0xFFE5E8ED),
                                                        disabledForegroundColor:
                                                            const Color(
                                                                0xFF9AA3B0),
                                                        elevation: 0,
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "Enable 2FA",
                                                        style: TextStyle(
                                                          fontSize:
                                                              buttonFontSize,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (showVerificationInput)
                                            Padding(
                                              // Card padding already sets the left edge; no extra inset,
                                              // so this block starts level with the title.
                                              padding: EdgeInsets.zero,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Enter verification code sent to your ${selected2FAMethod == 'email' ? 'email' : 'phone'}:",
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: titleFontSize,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 16),
                                                  TextField(
                                                    controller:
                                                        verificationCodeController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    maxLength: 6,
                                                    // Web greys the field out once the code
                                                    // has expired.
                                                    enabled: !is2FACodeExpired,
                                                    style: const TextStyle(
                                                        fontSize: 15,
                                                        letterSpacing: 1.5,
                                                        color:
                                                            Color(0xFF152B51)),
                                                    decoration: InputDecoration(
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 14,
                                                              vertical: 16),
                                                      hintText:
                                                          "Enter 6-digit code",
                                                      hintStyle:
                                                          const TextStyle(
                                                              color: Color(
                                                                  0xFF94A1B4),
                                                              letterSpacing:
                                                                  0.5),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        borderSide:
                                                            const BorderSide(
                                                                color: Color(
                                                                    0xFFD3DAE5),
                                                                width: 1.5),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        borderSide: BorderSide(
                                                            color: blueColor,
                                                            width: 2),
                                                      ),
                                                      counterText: "",
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),

                                                  // The code expires 10 minutes after it is
                                                  // issued, so show the countdown and a way
                                                  // to request a new one.
                                                  _build2FACodeTimerRow(
                                                    onResend: () {
                                                      verificationCodeController
                                                          .clear();
                                                      _initiate2FASetup();
                                                    },
                                                  ),

                                                  SizedBox(height: 20),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: 42,
                                                    child: ElevatedButton(
                                                      onPressed: (isVerifyingCode ||
                                                              is2FACodeExpired)
                                                          ? null
                                                          : () =>
                                                              _verifyAndEnable2FA(),
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            blueColor,
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                      child: isVerifyingCode
                                                          ? SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                color: Colors
                                                                    .white,
                                                                strokeWidth: 2,
                                                              ),
                                                            )
                                                          : Text(
                                                              "Verify & Enable",
                                                              style: TextStyle(
                                                                fontSize:
                                                                    buttonFontSize,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 12),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    height: 38,
                                                    child: OutlinedButton(
                                                      onPressed: () {
                                                        stopTimer();
                                                        setState(() {
                                                          show2FASetup = false;
                                                          showVerificationInput =
                                                              false;
                                                          selected2FAMethod =
                                                              '';
                                                          verificationCodeController
                                                              .clear();
                                                        });
                                                      },
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        side: BorderSide(
                                                            color: Colors.grey),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "Cancel",
                                                        style: TextStyle(
                                                          fontSize:
                                                              buttonFontSize,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (enble2FA && !show2FASetup)
                                            Padding(
                                              // Card padding already sets the left edge; no extra inset,
                                              // so this block starts level with the title.
                                              padding: EdgeInsets.zero,
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 12),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE7F7EE),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.check,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF1F9D55)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        email2FA
                                                            ? "2FA is enabled via Email"
                                                            : sms2FA
                                                                ? "2FA is enabled via SMS"
                                                                : "2FA is enabled",
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFF1F9D55),
                                                          fontSize: 14.5,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          // Verification-method tile (web design). Main
                                          // enabled view only - the disable card names the
                                          // destination itself.
                                          if (enble2FA &&
                                              !show2FASetup &&
                                              !showDisableVerification &&
                                              !showRegenerateVerification)
                                            Padding(
                                              // Same horizontal inset as the status banner and the action
                                              // buttons, so the card's blocks line up down one edge.
                                              padding: const EdgeInsets.only(
                                                  top: 12),
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFE8ECF1)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      sms2FA && !email2FA
                                                          ? Icons.sms_outlined
                                                          : Icons.mail_outline,
                                                      size: 22,
                                                      color: const Color(
                                                          0xFF2C72E0),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            "VERIFICATION METHOD",
                                                            style: TextStyle(
                                                              color: Color(
                                                                  0xFF6B7A90),
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              letterSpacing:
                                                                  0.8,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            sms2FA && !email2FA
                                                                ? _phone2FA
                                                                : _email2FA,
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                          SizedBox(height: 20),
                                          // Disable 2FA Verification Input
                                          // Web nests this inside the `twoFactorEnabled`
                                          // arm — it only makes sense while 2FA is on.
                                          if (showDisableVerification &&
                                              enble2FA)
                                            Padding(
                                              // Card padding already sets the left edge; no extra inset,
                                              // so this block starts level with the title.
                                              padding: EdgeInsets.zero,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                            14),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFFFFFFF),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFE4E8EF)),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Enter verification code to disable 2FA",
                                                          style: TextStyle(
                                                            color: blueColor,
                                                            fontSize: 14.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          "Sent to ${email2FA ? _email2FA : (sms2FA ? _phone2FA : _email2FA)}",
                                                          style:
                                                              const TextStyle(
                                                            color: Color(
                                                                0xFF6B7A90),
                                                            fontSize: 12.5,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 12),

                                                        SizedBox(height: 16),
                                                        // Verification Code Input Field
                                                        TextField(
                                                          style: const TextStyle(
                                                              fontSize: 15,
                                                              letterSpacing:
                                                                  1.5,
                                                              color: Color(
                                                                  0xFF152B51)),
                                                          controller:
                                                              disableVerificationController,
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          maxLength: 6,
                                                          // Web greys the field out once the code
                                                          // has expired.
                                                          enabled:
                                                              !is2FACodeExpired,
                                                          decoration:
                                                              InputDecoration(
                                                            contentPadding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        14,
                                                                    vertical:
                                                                        16),
                                                            hintText:
                                                                "Enter 6-digit code",
                                                            hintStyle: const TextStyle(
                                                                color: Color(
                                                                    0xFF94A1B4),
                                                                letterSpacing:
                                                                    0.5),
                                                            border:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFFD3DAE5),
                                                                      width:
                                                                          1.5),
                                                            ),
                                                            focusedBorder:
                                                                OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFF152B51),
                                                                      width:
                                                                          1.5),
                                                            ),
                                                            counterText: "",
                                                          ),
                                                        ),
                                                        SizedBox(height: 10),

                                                        // Same 10 minute expiry as the enable
                                                        // code — countdown plus Resend.
                                                        _build2FACodeTimerRow(
                                                          onResend: () {
                                                            disableVerificationController
                                                                .clear();
                                                            _sendDisable2FACode();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  SizedBox(height: 20),
                                                  // Cancel and the destructive action sit side by side, Cancel
                                                  // leading, so the pair reads as one decision rather than a
                                                  // stacked list. Equal heights keep them aligned.
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: SizedBox(
                                                          height: 44,
                                                          child: OutlinedButton(
                                                            onPressed: () {
                                                              stopTimer();
                                                              setState(() {
                                                                showDisableVerification =
                                                                    false;
                                                                disableVerificationController
                                                                    .clear();
                                                              });
                                                            },
                                                            style:
                                                                OutlinedButton
                                                                    .styleFrom(
                                                              side: const BorderSide(
                                                                  color: Color(
                                                                      0xFFD3DAE5)),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                            ),
                                                            child: const Text(
                                                              "Cancel",
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                    0xFF6B7A90),
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
                                                            onPressed: (isVerifyingCode ||
                                                                    is2FACodeExpired)
                                                                ? null
                                                                : () =>
                                                                    _disable2FAWithVerification(),
                                                            style:
                                                                ElevatedButton
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
                                                                        .circular(
                                                                            8),
                                                              ),
                                                            ),
                                                            child: isVerifyingCode
                                                                ? const SizedBox(
                                                                    width: 20,
                                                                    height: 20,
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                      color: Colors
                                                                          .white,
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                                  )
                                                                : const Text(
                                                                    "Disable 2FA",
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          14,
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
                                          // 2FA Action Buttons
                                          // Also hidden during an enable flow, else
                                          // "Disable 2FA" stays tappable under the chooser
                                          // and re-creates the overlap from the other side.
                                          if (enble2FA &&
                                              !showDisableVerification &&
                                              !showRegenerateVerification &&
                                              !show2FASetup &&
                                              !showVerificationInput)
                                            Padding(
                                              // Card padding already sets the left edge; no extra inset,
                                              // so this block starts level with the title.
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              child: constraints.maxWidth < 430
                                                  ? Column(
                                                      children: [
                                                        SizedBox(
                                                          width:
                                                              double.infinity,
                                                          height: 50,
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              // showDisableVerification only flips
                                                              // after the 200, so it cannot stop a
                                                              // double tap on its own;
                                                              // isVerifyingCode is set
                                                              // synchronously.
                                                              if (isVerifyingCode ||
                                                                  showDisableVerification) {
                                                                return;
                                                              }
                                                              _sendDisable2FACode();
                                                            },
                                                            style:
                                                                ElevatedButton
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
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .security,
                                                                    size: 18),
                                                                SizedBox(
                                                                    width: 6),
                                                                Flexible(
                                                                  child: Text(
                                                                    "Disable 2FA",
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          buttonFontSize -
                                                                              1,
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
                                                        SizedBox(height: 10),
                                                        SizedBox(
                                                          width:
                                                              double.infinity,
                                                          height: 50,
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              // Blocks the second of two fast taps
                                                              // generating a second set of backup
                                                              // codes.
                                                              if (isVerifyingCode) {
                                                                return;
                                                              }
                                                              _regenerateBackupCodesWithVerification();
                                                            },
                                                            style:
                                                                ElevatedButton
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
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .refresh,
                                                                    size: 18),
                                                                SizedBox(
                                                                    width: 6),
                                                                Flexible(
                                                                  child: codes
                                                                          .isEmpty
                                                                      ? Text(
                                                                          "Backup Codes",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          maxLines:
                                                                              2,
                                                                        )
                                                                      : Text(
                                                                          "Regenerate Backup Codes",
                                                                          style:
                                                                              TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                          maxLines:
                                                                              2,
                                                                        ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : Row(
                                                      children: [
                                                        // Disable 2FA Button
                                                        Expanded(
                                                          flex: 1,
                                                          child: SizedBox(
                                                            height: 60,
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: () {
                                                                // showDisableVerification only
                                                                // flips after the 200;
                                                                // isVerifyingCode is set
                                                                // synchronously.
                                                                if (isVerifyingCode ||
                                                                    showDisableVerification) {
                                                                  return;
                                                                }
                                                                _sendDisable2FACode();
                                                              },
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .white,
                                                                foregroundColor:
                                                                    Colors.red
                                                                        .shade700,
                                                                side: BorderSide(
                                                                    color: Colors
                                                                        .red
                                                                        .shade300,
                                                                    width: 1.5),
                                                                elevation: 0,
                                                                shadowColor: Colors
                                                                    .transparent,
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .security,
                                                                      size: 18),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Flexible(
                                                                    child: Text(
                                                                      "Disable 2FA",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            buttonFontSize -
                                                                                2,
                                                                        fontWeight:
                                                                            FontWeight.w600,
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
                                                            height: 60,
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: () {
                                                                // Blocks a double tap generating a
                                                                // second set of backup codes.
                                                                if (isVerifyingCode) {
                                                                  return;
                                                                }
                                                                _regenerateBackupCodesWithVerification();
                                                              },
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .white,
                                                                foregroundColor:
                                                                    greyColor,
                                                                side: BorderSide(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade400,
                                                                    width: 1.5),
                                                                elevation: 0,
                                                                shadowColor: Colors
                                                                    .transparent,
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .refresh,
                                                                      size: 18),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Flexible(
                                                                    child: codes
                                                                            .isEmpty
                                                                        ? Text(
                                                                            "Backup Codes",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                            maxLines:
                                                                                2,
                                                                          )
                                                                        : Text(
                                                                            "Regenerate Backup Codes",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                            maxLines:
                                                                                2,
                                                                          ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    })
          : NoInternetView(onRetry: retryNow),
    );
  }

  // Web renders staff fields with optional chaining (blank when the field is
  // absent), so a new staff member with no designation shows an empty value
  // instead of crashing. Mirror that here: read every profile field through
  // this helper so a missing/null key becomes "" rather than a null that
  // blows up a non-nullable String.
  String _pf(String key) => (profiledata[key] ?? '').toString();

  // Show "N/A" for any empty/missing field (consistent with the Phone field),
  // so a blank value can never fall through to a stray placeholder.
  String _orNA(String v) => v.trim().isEmpty ? 'N/A' : v.trim();

  // Initials for the avatar, derived from the staff member's name.
  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  // One icon + value row inside the profile card (phone / email).
  Widget _profileInfoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: greyColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 15, color: greyColor, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  // Web-aligned, VIEW-ONLY personal details card: avatar + name + designation
  // subtitle, then phone/email rows. Replaces the old read-only text fields so
  // an empty Designation shows "N/A" instead of a leftover date placeholder.
  Widget _personalDetailsCard() {
    final name = _orNA(_pf('staffmember_name'));
    final designation = _orNA(_pf('staffmember_designation'));
    final phone = formatPhoneNumber(_pf('staffmember_phoneNumber'));
    final email = _orNA(_pf('staffmember_email'));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: blueColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(_pf('staffmember_name')),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      designation,
                      style: TextStyle(fontSize: 14, color: greyColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Colors.grey.withOpacity(0.25)),
          ),
          _profileInfoRow(Icons.phone_outlined, phone),
          _profileInfoRow(Icons.email_outlined, email),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$label',
              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
            ),
          ),
          Text(":  "),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
              //overflow: TextOverflow.,
            ),
          ),
        ],
      ),
    );
  }
}
