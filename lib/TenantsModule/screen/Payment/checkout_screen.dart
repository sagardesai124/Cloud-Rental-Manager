// lib/checkout_screen.dart

import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';
import 'dart:async';
import 'dart:io' show Platform, SocketException, HttpException;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_configurations.dart';
import 'nmi_keys_service.dart';
import '../../../../constant/constant.dart';
import '../financial/payment/payment_service.dart';

// Payment response model
class PaymentResponse {
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;
  final PaymentErrorType? errorType;
  final Map<String, dynamic>? data;

  PaymentResponse({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
    this.errorType,
    this.data,
  });
}

// Error types enum
enum PaymentErrorType {
  networkError,
  serverError,
  authenticationError,
  paymentFailed,
  validationError,
  timeoutError,
  unknownError,
  cancelledByUser,
}

class CheckoutScreen extends StatefulWidget {
  final double amount; // Dynamic amount from make_payment.dart
  final String tenantId;
  final String leaseId;
  final String paymentAmountType; // "full", "rent", "partial"
  final List<Map<String, dynamic>> entries;
  final double surchargeamount;

  const CheckoutScreen({
    Key? key,
    required this.amount,
    required this.tenantId,
    required this.leaseId,
    required this.paymentAmountType,
    required this.entries,
    required this.surchargeamount,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isPayPluginAvailable = false;
  bool _isCheckingPlugin = true;
  bool _isProcessingPayment = false;
  bool _isLoadingKeys = true; // Loading merchant ID
  PaymentErrorType? _currentError;
  String? _errorMessage;
  bool _showSuccessMessage = false;

  // NMI Keys
  String? _merchantId;
  String? _merchantName;

  // Dynamic payment items
  late List<PaymentItem> _paymentItems;

  // Payment configurations (will be generated dynamically)
  String? _googlePayConfigString;
  String? _applePayConfigString;

  @override
  void initState() {
    super.initState();
    // Initialize payment items with dynamic amount
    _paymentItems = [
      PaymentItem(
        label: 'Rent Payment',
        amount: widget.amount.toStringAsFixed(2),
        status: PaymentItemStatus.final_price,
      ),
    ];
    // First fetch merchant ID, then check plugin availability
    _initializePayment();
  }

  /// Initialize payment: Fetch merchant ID first, then setup payment
  Future<void> _initializePayment() async {
    try {
      // Step 1: Fetch merchant ID and terminal ID from API
      await _fetchNmiKeys();

      // Step 2: Generate dynamic payment configurations
      _generatePaymentConfigurations();

      // Step 3: Check plugin availability
      await _checkPayPluginAvailability();
    } catch (e) {
      setState(() {
        _isLoadingKeys = false;
        _currentError = PaymentErrorType.serverError;
        _errorMessage = 'Failed to load payment configuration: ${e.toString()}';
      });
    }
  }

  /// Fetch NMI keys (merchant ID and terminal ID) from API
  Future<void> _fetchNmiKeys() async {
    setState(() {
      _isLoadingKeys = true;
    });

    try {
      final nmiKeysService = NmiKeysService();
      final keysData = await nmiKeysService.fetchNmiKeys();

      // Extract merchant ID from response — the only key checkout needs.
      // API response structure: { "data": { "merchant_id": "...", ... } }
      // (the server never sends a tenant the secret keys).
      // Note: Some admin accounts may not have merchant_id set up yet
      _merchantId = keysData['merchant_id']?.toString();
      _merchantName = keysData['merchant_name']?.toString() ??
          keysData['merchantName']?.toString() ??
          'Cloud Rental Manager';

      // Check if merchant_id exists, if not, show helpful error
      if (_merchantId == null || _merchantId!.isEmpty) {
        throw Exception(
            'Merchant ID not configured. Please set up merchant ID in admin settings.');
      }

      setState(() {
        _isLoadingKeys = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingKeys = false;
      });
      rethrow;
    }
  }

  /// Generate dynamic payment configurations using fetched merchant ID
  void _generatePaymentConfigurations() {
    if (_merchantId == null) {
      throw Exception(
          'Merchant ID is required to generate payment configurations');
    }

    // Generate Google Pay configuration with dynamic merchant ID
    // Environment is controlled by PAYMENT_ENVIRONMENT constant in payment_configurations.dart
    // Set to 'TEST' for development, 'PRODUCTION' for live payments
    _googlePayConfigString = generateGooglePayConfig(
      merchantId: _merchantId!,
      amount: widget.amount.toStringAsFixed(2),
      merchantName: _merchantName ?? 'Cloud Rental Manager',
      // environment parameter is optional - defaults to PAYMENT_ENVIRONMENT constant
    );

    // Generate Apple Pay configuration
    // Note: Apple Pay uses Apple Merchant ID (from entitlements), not NMI merchant ID
    // This will be used when Apple Pay is set up (card added, etc.)
    // If not set up, the button will silently not show (allowing Google Pay to work)
    try {
      _applePayConfigString = generateApplePayConfig(
        amount: widget.amount.toStringAsFixed(2),
        merchantName: _merchantName ?? 'Cloud Rental Manager',
        // merchantIdentifier defaults to the one in entitlements file
        // merchant.com.hostmerchantservices.cloudrentalmanager
      );
    } catch (e) {
      // Silently handle error - don't prevent Google Pay from working
      _applePayConfigString = null;
    }
  }

  // Check if pay plugin is available
  Future<void> _checkPayPluginAvailability() async {
    try {
      // Try to check if the platform channel is available
      // Creating the MethodChannel to test availability
      const MethodChannel('plugins.flutter.io/pay/payment_result');

      // For testing, we'll assume plugin is available if we can create the channel
      // The actual availability will be checked when the button tries to render
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isPayPluginAvailable = true;
        _isCheckingPlugin = false;
      });
    } catch (e) {
      // Plugin not available
      setState(() {
        _isPayPluginAvailable = false;
        _isCheckingPlugin = false;
      });
    }
  }

  // Function called after the user authorizes the payment in the Google Pay sheet
  //
  // ============================================================================
  // HOW TOKEN GENERATION WORKS:
  // ============================================================================
  // 1. User clicks Google Pay button → Google Pay SDK opens payment sheet
  // 2. User selects card and authorizes (fingerprint/Face ID/PIN)
  // 3. Google Pay servers GENERATE an encrypted token (NOT your app!)
  // 4. Google Pay returns the token to this callback function
  // 5. Your app receives the token and sends it to your backend API
  // 6. Your backend API decrypts the token and processes the payment
  //
  void onGooglePayResult(Map<String, dynamic> paymentResult) async {

    // Extract and print full token for Postman testing (even if backend is offline)
    if (paymentResult.containsKey('paymentMethodData')) {
      final pmData =
          paymentResult['paymentMethodData'] as Map<String, dynamic>?;
      if (pmData?.containsKey('tokenizationData') == true) {
        final tokenData = pmData!['tokenizationData'] as Map<String, dynamic>?;
        if (tokenData?.containsKey('token') == true) {
          final innerToken = tokenData!['token'] as String?;
          if (innerToken != null) {

            // Print token for Postman testing
          }
        }
      }
    }

    setState(() {
      _isProcessingPayment = true;
      _currentError = null;
      _errorMessage = null;
      _showSuccessMessage = false;
    });

    try {
      final response = await sendPaymentTokenToServer(
        wallet: 'googlepay',
        paymentData: paymentResult,
        amount: widget.amount.toStringAsFixed(2),
      );

      if (response.isSuccess) {
        setState(() {
          _isProcessingPayment = false;
          _showSuccessMessage = true;
          _currentError = null;
          _errorMessage = null;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment processed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Handle different error types
        setState(() {
          _isProcessingPayment = false;
          _currentError = response.errorType ?? PaymentErrorType.unknownError;
          _errorMessage =
              response.errorMessage ?? 'Payment failed. Please try again.';
        });

        _showErrorSnackBar(_currentError!, _errorMessage!);
      }
    } catch (e) {

      // If backend is offline, token is still available for Postman testing

      setState(() {
        _isProcessingPayment = false;
        _currentError =
            PaymentErrorType.networkError; // Change to networkError for offline
        _errorMessage =
            'Backend API is offline. Token generated successfully - check logs for Postman testing.';
      });

      _showErrorSnackBar(PaymentErrorType.networkError, _errorMessage!);
    }
  }

  void onApplePayResult(Map<String, dynamic> paymentResult) async {

    setState(() {
      _isProcessingPayment = true;
      _currentError = null;
      _errorMessage = null;
      _showSuccessMessage = false;
    });

    try {
      final response = await sendPaymentTokenToServer(
        wallet: 'applepay',
        paymentData: paymentResult,
        amount: widget.amount.toStringAsFixed(2),
      );

      // Handle server response
      if (response.isSuccess) {
        setState(() {
          _isProcessingPayment = false;
          _showSuccessMessage = true;
          _currentError = null;
          _errorMessage = null;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment processed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isProcessingPayment = false;
          _currentError = response.errorType ?? PaymentErrorType.unknownError;
          _errorMessage =
              response.errorMessage ?? 'Payment failed. Please try again.';
        });

        _showErrorSnackBar(_currentError!, _errorMessage!);
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
        _currentError = PaymentErrorType.unknownError;
        _errorMessage = friendlyErrorMessage(e);
      });

      _showErrorSnackBar(PaymentErrorType.unknownError, _errorMessage!);
    }
  }

  Future<bool> _isGooglePayAvailable() async {
    try {
      // Use dynamic configuration if available, otherwise use default
      if (_googlePayConfigString != null) {
        PaymentConfiguration.fromJsonString(_googlePayConfigString!);
        return true;
      }
      // Fallback to default config
      PaymentConfiguration.fromJsonString(defaultGooglePayConfigString);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if Apple Pay is available on the device
  // Returns false silently if not available (no card, not configured, etc.)
  // This allows Google Pay to work independently
  Future<bool> _isApplePayAvailable() async {
    // Only check on iOS devices
    if (!Platform.isIOS) {
      return false;
    }

    try {
      // Use dynamic configuration if available, otherwise use default
      if (_applePayConfigString != null) {
        PaymentConfiguration.fromJsonString(_applePayConfigString!);
        // Configuration is valid, but actual availability depends on:
        // - Apple Pay being set up in device settings
        // - Card being added to Apple Pay
        // - Proper app signing
        // The button itself will handle these checks
        return true;
      }
      // Fallback to default config
      PaymentConfiguration.fromJsonString(defaultApplePayConfigString);
      return true;
    } catch (e) {
      // Silently return false - don't log errors
      // This allows Google Pay to work even if Apple Pay config fails
      return false;
    }
  }

  // Function for sending data to your server with comprehensive error handling
  // TODO: Uncomment and implement the actual API call when ready
  //
  // ============================================================================
  // API DEVELOPER - READ THIS!
  // ============================================================================
  // This function sends payment data to your backend API.
  //
  // REQUEST BODY STRUCTURE:
  // {
  //   "wallet": "googlepay" | "applepay",
  //   "paymentData": { ... encrypted token from Google/Apple Pay ... },
  //   "amount": "100.00",
  //   "tenantId": "...",
  //   "leaseId": "...",
  //   "paymentAmountType": "full" | "rent" | "partial",
  //   "entries": [...],
  //   "surchargeamount": "0.00"
  // }
  //
  // See API_PAYMENT_ENDPOINT_DOCUMENTATION.md for complete details!
  // ============================================================================
  Future<PaymentResponse> sendPaymentTokenToServer({
    required String wallet,
    required Map<String, dynamic> paymentData,
    required String amount,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("tenant_id");
      String? token = prefs.getString('token');
      String? adminId = prefs.getString("adminId");

      if (token == null || id == null || adminId == null) {
        return PaymentResponse(
          isSuccess: false,
          errorType: PaymentErrorType.authenticationError,
          errorMessage: 'Authentication failed. Please log in again.',
        );
      }

      String? tenantFirstName = prefs.getString('first_name');
      String? tenantLastName = prefs.getString('last_name');
      String? tenantEmail = prefs.getString('email');

      Map<String, dynamic>? leaseData;
      try {
        final leaseResponse = await apiGet(
          Uri.parse('$Api_url/api/leases/get_leases/$id'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          },
        ).timeout(const Duration(seconds: 5));

        if (leaseResponse.statusCode == 200) {
          final leaseJson = jsonDecode(leaseResponse.body);
          final leases = leaseJson['data']['leases'] as List?;
          if (leases != null && leases.isNotEmpty) {
            leaseData = leases.firstWhere(
              (lease) => lease['lease_id'] == widget.leaseId,
              orElse: () => null,
            ) as Map<String, dynamic>?;
          }
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Could not load lease details for this payment.');
      }

      dynamic paymentTokenForNmi = paymentData;

      if (wallet == 'googlepay' &&
          paymentData.containsKey('paymentMethodData')) {
        try {
          final pmData =
              paymentData['paymentMethodData'] as Map<String, dynamic>?;
          if (pmData?.containsKey('tokenizationData') == true) {
            final tokenData =
                pmData!['tokenizationData'] as Map<String, dynamic>?;
            if (tokenData?.containsKey('token') == true) {
              final innerToken = tokenData!['token'] as String?;
              if (innerToken != null) {
                paymentTokenForNmi = innerToken;

                // Print token only
              }
            }
          }
        } catch (e) {
          Fluttertoast.showToast(
              msg: 'Could not read the wallet payment token. Please try again.');
        }
      }

      final paymentDetails = {
        'admin_id': adminId,
        'lease_id': widget.leaseId,
        'tenant_firstName': tenantFirstName ?? '',
        'tenant_lastName': tenantLastName ?? '',
        'tenant_email': tenantEmail ?? '',
        'tenant_id': widget.tenantId,
        'payment_token': paymentTokenForNmi,
        'payment_method': wallet,
        'amount': amount,
        'processor_id': leaseData?['processor_id']?.toString() ?? '',
        'rentalAddress': leaseData?['rental_adress']?.toString() ??
            leaseData?['rental_address']?.toString() ??
            '',
        'entry': widget.entries,
      };

      final requestBody = {
        'paymentDetails': paymentDetails,
      };

      final apiStartTime = DateTime.now();
      final url = Uri.parse('$Api_url/api/nmipayment/wallet-payment');
      final response = await http
          .post(
        url,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          final elapsed = DateTime.now().difference(apiStartTime);
          throw TimeoutException(
              'Wallet payment API request timed out after 30 seconds');
        },
      );

      // Parse response
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      // Handle different HTTP status codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check for statusCode 100 (success) like in payment_service.dart
        if (responseData['statusCode'] == 100) {
          // Payment successful - now store the payment record
          try {
            // Get transaction ID from response
            String transactionId =
                responseData['data']?['transactionid']?.toString() ??
                    responseData['transactionId']?.toString() ??
                    responseData['transaction_id']?.toString() ??
                    '';

            // Get response text
            String responseText =
                responseData['data']?['responsetext']?.toString() ??
                    responseData['responseText']?.toString() ??
                    'SUCCESS';

            // Get current date
            String currentDate = DateTime.now()
                .toIso8601String()
                .split('T')[0]; // yyyy-MM-dd format

            // Fetch company name
            String companyName = '';
            try {
              // Import TenantsRepository if needed - for now use merchant name as fallback
              companyName = _merchantName ?? 'Cloud Rental Manager';
              // You can uncomment below to fetch actual company name
              // companyName = await TenantsRepository().fetchCompanyName(adminId);
            } catch (e) {
              companyName = _merchantName ?? 'Cloud Rental Manager';
            }

            // Store payment record using PaymentService
            final paymentService = PaymentService();
            await paymentService.storePayment(
              companyName: companyName,
              adminId: adminId,
              tenantId: widget.tenantId,
              leaseId: widget.leaseId,
              paymentAmountType: widget.paymentAmountType,
              paymentType: wallet == 'googlepay' ? 'Google Pay' : 'Apple Pay',
              customerVaultId: '', // Wallet payments don't use vault
              billingId: '', // Wallet payments don't use billing ID
              totalAmount: amount,
              isLeaseAdded: false,
              uploadedFile: "",
              date: currentDate,
              transactionId: transactionId,
              responseText: responseText,
              scheduledPayment: false,
              surcharge: widget.surchargeamount.toString(),
              notificationTime: null, // Add if needed
            );

          } catch (e) {
            // Continue even if storing fails - payment was successful
          }

          // Payment successful
          return PaymentResponse(
            isSuccess: true,
            data: responseData,
          );
        } else if (responseData['success'] == true ||
            responseData['status'] == 'success' ||
            responseData['status'] == 'approved') {
          // Alternative success formats - also store payment
          try {
            String transactionId = responseData['transactionId']?.toString() ??
                responseData['transaction_id']?.toString() ??
                '';
            String responseText =
                responseData['responseText']?.toString() ?? 'SUCCESS';
            String currentDate = DateTime.now().toIso8601String().split('T')[0];
            String companyName = _merchantName ?? 'Cloud Rental Manager';

            final paymentService = PaymentService();
            await paymentService.storePayment(
              companyName: companyName,
              adminId: adminId,
              tenantId: widget.tenantId,
              leaseId: widget.leaseId,
              scheduledPayment: false,
              paymentAmountType: widget.paymentAmountType,
              paymentType: wallet == 'googlepay' ? 'Google Pay' : 'Apple Pay',
              customerVaultId: '',
              billingId: '',
              totalAmount: amount,
              isLeaseAdded: false,
              uploadedFile: "",
              date: currentDate,
              transactionId: transactionId,
              responseText: responseText,
              surcharge: widget.surchargeamount.toString(),
              notificationTime: null,
            );
          } catch (e) {
          }

          // Alternative success formats
          return PaymentResponse(
            isSuccess: true,
            data: responseData,
          );
        } else {
          // Payment was processed but failed (e.g., declined card or auth error)
          final responseCode =
              responseData['data']?['response_code']?.toString() ??
                  responseData['response_code']?.toString();
          final responseText =
              responseData['data']?['responsetext']?.toString() ??
                  responseData['responsetext']?.toString() ??
                  '';

          // Check if this is an NMI authentication error
          if (responseCode == '300' ||
              responseText.toLowerCase().contains('authentication failed')) {

            return PaymentResponse(
              isSuccess: false,
              errorType: PaymentErrorType.authenticationError,
              errorMessage:
                  'Payment authentication failed. Please contact support. (NMI Auth Error)',
              errorCode: responseCode ?? responseData['statusCode']?.toString(),
              data: responseData,
            );
          }

          // Regular payment failure (declined card, etc.)
          return PaymentResponse(
            isSuccess: false,
            errorType: PaymentErrorType.paymentFailed,
            errorMessage: responseData['message'] ??
                    responseData['error'] ??
                    responseText.isNotEmpty
                ? responseText
                : 'Payment was declined. Please check your payment method.',
            errorCode: responseCode ??
                responseData['error_code']?.toString() ??
                responseData['statusCode']?.toString(),
            data: responseData,
          );
        }
      } else if (response.statusCode == 400) {
        // Bad Request - Validation error
        return PaymentResponse(
          isSuccess: false,
          errorType: PaymentErrorType.validationError,
          errorMessage: responseData['message'] ??
              responseData['error'] ??
              'Invalid payment information. Please check your details.',
          errorCode: responseData['error_code']?.toString(),
          data: responseData,
        );
      } else if (response.statusCode == 401) {
        // Unauthorized - Authentication error

        return PaymentResponse(
          isSuccess: false,
          errorType: PaymentErrorType.authenticationError,
          errorMessage: 'Authentication failed. Please log in again.',
          errorCode: '401',
          data: responseData,
        );
      } else if (response.statusCode == 403) {
        // Forbidden - Authorization error
        return PaymentResponse(
          isSuccess: false,
          errorType: PaymentErrorType.authenticationError,
          errorMessage: 'You do not have permission to perform this action.',
          errorCode: '403',
          data: responseData,
        );
      } else if (response.statusCode >= 500) {
        // Server error
        return PaymentResponse(
          isSuccess: false,
          errorType: PaymentErrorType.serverError,
          errorMessage: responseData['message'] ??
              'Server error occurred. Please try again later.',
          errorCode: response.statusCode.toString(),
          data: responseData,
        );
      } else {
        // Other client errors (404, etc.)
        return PaymentResponse(
          isSuccess: false,
          errorType: PaymentErrorType.serverError,
          errorMessage:
              responseData['message'] ?? 'An error occurred. Please try again.',
          errorCode: response.statusCode.toString(),
          data: responseData,
        );
      }
    } on SocketException {
      // Network error - no internet connection
      return PaymentResponse(
        isSuccess: false,
        errorType: PaymentErrorType.networkError,
        errorMessage:
            'No internet connection. Please check your network and try again.',
        errorCode: 'NETWORK_ERROR',
      );
    } on HttpException catch (e) {
      // HTTP error
      return PaymentResponse(
        isSuccess: false,
        errorType: PaymentErrorType.networkError,
        errorMessage: 'Network error: ${e.message}',
        errorCode: 'HTTP_ERROR',
      );
    } on TimeoutException {
      // Timeout error
      return PaymentResponse(
        isSuccess: false,
        errorType: PaymentErrorType.timeoutError,
        errorMessage:
            'Request timed out. Please check your connection and try again.',
        errorCode: 'TIMEOUT',
      );
    } on FormatException {
      // JSON parsing error
      return PaymentResponse(
        isSuccess: false,
        errorType: PaymentErrorType.serverError,
        errorMessage: 'Invalid response from server. Please try again.',
        errorCode: 'PARSE_ERROR',
      );
    } catch (e) {
      // Unknown error
      return PaymentResponse(
        isSuccess: false,
        errorType: PaymentErrorType.unknownError,
        errorMessage: friendlyErrorMessage(e),
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  // Helper function to show error snackbar with appropriate styling
  void _showErrorSnackBar(PaymentErrorType errorType, String message) {
    if (!mounted) return;

    Color backgroundColor;
    IconData icon;
    String title;

    switch (errorType) {
      case PaymentErrorType.networkError:
        backgroundColor = Colors.orange;
        icon = Icons.wifi_off;
        title = 'Network Error';
        break;
      case PaymentErrorType.serverError:
        backgroundColor = Colors.red;
        icon = Icons.error_outline;
        title = 'Server Error';
        break;
      case PaymentErrorType.authenticationError:
        backgroundColor = Colors.amber;
        icon = Icons.lock_outline;
        title = 'Authentication Error';
        break;
      case PaymentErrorType.paymentFailed:
        backgroundColor = Colors.red;
        icon = Icons.payment;
        title = 'Payment Failed';
        break;
      case PaymentErrorType.validationError:
        backgroundColor = Colors.orange;
        icon = Icons.info_outline;
        title = 'Validation Error';
        break;
      case PaymentErrorType.timeoutError:
        backgroundColor = Colors.orange;
        icon = Icons.timer_off;
        title = 'Timeout Error';
        break;
      case PaymentErrorType.cancelledByUser:
        backgroundColor = Colors.grey;
        icon = Icons.cancel_outlined;
        title = 'Cancelled';
        break;
      default:
        backgroundColor = Colors.red;
        icon = Icons.error;
        title = 'Error';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Build error display widget
  Widget _buildErrorDisplay() {
    if (_currentError == null) return const SizedBox.shrink();

    Color errorColor;
    IconData errorIcon;
    String errorTitle;

    switch (_currentError!) {
      case PaymentErrorType.networkError:
        errorColor = Colors.orange;
        errorIcon = Icons.wifi_off;
        errorTitle = 'Network Error';
        break;
      case PaymentErrorType.serverError:
        errorColor = Colors.red;
        errorIcon = Icons.error_outline;
        errorTitle = 'Server Error';
        break;
      case PaymentErrorType.authenticationError:
        errorColor = Colors.amber;
        errorIcon = Icons.lock_outline;
        errorTitle = 'Authentication Error';
        break;
      case PaymentErrorType.paymentFailed:
        errorColor = Colors.red;
        errorIcon = Icons.payment;
        errorTitle = 'Payment Failed';
        break;
      case PaymentErrorType.validationError:
        errorColor = Colors.orange;
        errorIcon = Icons.info_outline;
        errorTitle = 'Validation Error';
        break;
      case PaymentErrorType.timeoutError:
        errorColor = Colors.orange;
        errorIcon = Icons.timer_off;
        errorTitle = 'Timeout Error';
        break;
      case PaymentErrorType.cancelledByUser:
        errorColor = Colors.grey;
        errorIcon = Icons.cancel_outlined;
        errorTitle = 'Payment Cancelled';
        break;
      default:
        errorColor = Colors.red;
        errorIcon = Icons.error;
        errorTitle = 'Error';
    }

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        border: Border.all(color: errorColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(errorIcon, size: 48, color: errorColor),
          const SizedBox(height: 12),
          Text(
            errorTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: errorColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: errorColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _currentError = null;
                _errorMessage = null;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Build success display widget
  Widget _buildSuccessDisplay() {
    if (!_showSuccessMessage) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border.all(color: Colors.green, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          const Text(
            'Payment Successful!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your payment has been processed successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, true); // Return success
            },
            icon: const Icon(Icons.done),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Payment Checkout'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Amount Display Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      formatMoney(widget.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Show loading while fetching merchant ID
                  if (_isLoadingKeys)
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading payment configuration...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  // Show processing indicator
                  else if (_isProcessingPayment)
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Processing payment...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_isCheckingPlugin)
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (!_isPayPluginAvailable)
                    // Fallback UI when plugin is not available
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Payment Plugin Not Available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'Please rebuild the app to enable payment functionality.\n\n'
                              'Steps to fix:\n'
                              '1. Stop the app completely\n'
                              '2. Run: flutter clean\n'
                              '3. Run: flutter pub get\n'
                              '4. Rebuild and run the app',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Go Back'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Payment buttons section - shows both Google Pay and Apple Pay
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Choose Payment Method',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          // Google Pay Button
                          FutureBuilder<bool>(
                            future: _isGooglePayAvailable(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }

                              if (snapshot.hasError ||
                                  !(snapshot.data ?? false)) {
                                return const SizedBox.shrink();
                              }

                              // Show Google Pay Button with dynamic config
                              try {
                                if (_googlePayConfigString == null) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: GooglePayButton(
                                    paymentConfiguration:
                                        PaymentConfiguration.fromJsonString(
                                      _googlePayConfigString!,
                                    ),
                                    paymentItems: _paymentItems,
                                    type: GooglePayButtonType.pay,
                                    margin: EdgeInsets.zero,
                                    onPaymentResult: onGooglePayResult,
                                    loadingIndicator: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          // Apple Pay Button (iOS only)
                          // Silently hide if not available - don't show errors
                          // This allows Google Pay to work even if Apple Pay is not set up
                          if (Platform.isIOS)
                            FutureBuilder<bool>(
                              future: _isApplePayAvailable(),
                              builder: (context, snapshot) {
                                // Don't show anything while checking
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox.shrink();
                                }

                                // Only show Apple Pay button if available
                                // Silently hide if not available (no card, not configured, etc.)
                                if (snapshot.hasError ||
                                    !(snapshot.data ?? false)) {
                                  // Silently hide - don't show error message
                                  // This allows Google Pay to work independently
                                  return const SizedBox.shrink();
                                }

                                // Apple Pay is available, show the button
                                try {
                                  if (_applePayConfigString == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ApplePayButton(
                                      paymentConfiguration:
                                          PaymentConfiguration.fromJsonString(
                                        _applePayConfigString!,
                                      ),
                                      paymentItems: _paymentItems,
                                      type: ApplePayButtonType.buy,
                                      margin: EdgeInsets.zero,
                                      onPaymentResult: onApplePayResult,
                                      loadingIndicator: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  // Silently hide on error - don't show error message
                                  // This allows Google Pay to work independently
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                          // Show message if no payment methods are available
                          FutureBuilder<List<bool>>(
                            future: Future.wait([
                              _isGooglePayAvailable(),
                              _isApplePayAvailable(),
                            ]),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final googlePayAvailable =
                                  snapshot.data?[0] ?? false;
                              final applePayAvailable =
                                  snapshot.data?[1] ?? false;

                              if (!googlePayAvailable && !applePayAvailable) {
                                return Container(
                                  padding: const EdgeInsets.all(20.0),
                                  margin: const EdgeInsets.only(top: 12.0),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 40,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Payment Methods Not Available',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Text(
                                          Platform.isIOS
                                              ? 'No payment methods are available.\n\n'
                                                  'For Apple Pay, please check:\n'
                                                  '1. Apple Pay is set up in Settings > Wallet & Apple Pay\n'
                                                  '2. You have a card added to Apple Pay\n'
                                                  '3. Apple Pay capability is enabled in Xcode\n'
                                                  '4. Merchant identifier is configured in Xcode\n'
                                                  '5. App is signed with proper provisioning profile\n\n'
                                                  'For Google Pay, please check:\n'
                                                  '1. Google Pay is installed and set up\n'
                                                  '2. You have a card added to Google Pay\n'
                                                  '3. Testing on a real device'
                                              : 'Google Pay is not available on this device.\n'
                                                  'Make sure you are testing on a real Android device\n'
                                                  'with Google Pay installed and set up.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.arrow_back,
                                            size: 18),
                                        label: const Text('Go Back'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                          // Show error display if there's an error
                          _buildErrorDisplay(),
                          // Show success display if payment succeeded
                          _buildSuccessDisplay(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
