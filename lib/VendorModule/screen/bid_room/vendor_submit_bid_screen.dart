import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/bid_request.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/VendorModule/widgets/appbar.dart' as vendor_appbar;
import 'package:three_zero_two_property/widgets/titleBar.dart';

class VendorSubmitBidScreen extends StatefulWidget {
  final BidRequest bidRequest;

  const VendorSubmitBidScreen({super.key, required this.bidRequest});

  @override
  State<VendorSubmitBidScreen> createState() => _VendorSubmitBidScreenState();
}

class _VendorSubmitBidScreenState extends State<VendorSubmitBidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceBreakdownController = TextEditingController();
  final _totalPriceController = TextEditingController();

  File? _selectedFile;
  bool _isSubmitting = false;

  // Upper bound for the bid amount. Web puts no ceiling on this field, but a
  // value this large is junk either way, and an explicit limit lets the field
  // say what actually went wrong instead of blaming the characters typed.
  static const double _maxTotalPrice = 9999999999.99;

  @override
  void dispose() {
    _priceBreakdownController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  Future<String?> _uploadDocument(File file) async {
    final String uploadUrl = '$image_upload_url/api/images/upload';
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files
        .add(await http.MultipartFile.fromPath('files', file.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);
    var responseBody = json.decode(responseData.body);

    if (responseBody['status'] == 'ok') {
      List files = responseBody['files'];
      if (files.isNotEmpty) return files.first["filename"] as String?;
    }
    throw Exception(responseBody['message'] ?? 'Failed to upload file');
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  void _removeDocument() {
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _submitBid() async {
    if (!_formKey.currentState!.validate()) return;

    final priceBreakdown = _priceBreakdownController.text.trim();
    final totalPriceStr = _totalPriceController.text.trim();
    if (priceBreakdown.isEmpty) {
      Fluttertoast.showToast(msg: 'Price breakdown is required');
      return;
    }
    final totalPrice = double.tryParse(totalPriceStr);
    if (totalPrice == null || totalPrice < 0) {
      Fluttertoast.showToast(msg: 'Please enter a valid total price');
      return;
    }

    setState(() => _isSubmitting = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? vendorId = prefs.getString('vendor_id');
    String? token = prefs.getString('token');
    String? firstName = prefs.getString('first_name');
    String? lastName = prefs.getString('last_name');
    // Web parity: send the full vendor_name; first/last fallback for sessions saved before it existed.
    String vendorName = prefs.getString('vendor_name')?.trim() ??
        [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ').trim();
    if (vendorName.isEmpty) vendorName = 'Vendor';

    if (vendorId == null || token == null) {
      setState(() => _isSubmitting = false);
      Fluttertoast.showToast(msg: 'Session expired. Please log in again.');
      return;
    }

    String? submissionFile;
    if (_selectedFile != null) {
      try {
        submissionFile = await _uploadDocument(_selectedFile!);
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          Fluttertoast.showToast(msg: 'Failed to upload document: ${friendlyErrorMessage(e)}');
        }
        return;
      }
    }

    final bidRequestId = widget.bidRequest.bidRequestId;
    final adminId = widget.bidRequest.adminId;
    if (bidRequestId == null || bidRequestId.isEmpty) {
      setState(() => _isSubmitting = false);
      Fluttertoast.showToast(msg: 'Invalid bid request');
      return;
    }

    try {
      // Match web API: payload under "submission" + is_web
      final submission = <String, dynamic>{
        'bid_request_id': bidRequestId,
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'admin_id': adminId ?? '',
        'price_breakdown': priceBreakdown,
        'total_price': totalPrice,
        // Web parity (BidSubmissionModal.jsx): new Date().toISOString() — UTC, millisecond precision.
        'submitted_at': DateTime.fromMillisecondsSinceEpoch(
                DateTime.now().millisecondsSinceEpoch,
                isUtc: true)
            .toIso8601String(),
      };
      if (submissionFile != null && submissionFile.isNotEmpty) {
        submission['submission_file'] = submissionFile;
      }

      final body = <String, dynamic>{
        'submission': submission,
        'is_web': false,
        'user_active_recently': true,
      };

      final response = await apiPost(
        Uri.parse('$Api_url/api/bid-request/bid-submission'),
        headers: {
          'authorization': 'CRM $token',
          'id': 'CRM $vendorId',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      if (mounted) {
        setState(() => _isSubmitting   = false);
        final resp = json.decode(response.body);
        if (response.statusCode == 200 && resp['statusCode'] == 200) {
          Fluttertoast.showToast(msg: resp['message'] ?? 'Bid submitted successfully');
          Navigator.of(context).pop(true);
        } else {
          Fluttertoast.showToast(
              msg: resp['message'] ?? 'Failed to submit bid');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Fluttertoast.showToast(msg: 'Error submitting bid: ${friendlyErrorMessage(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.bidRequest;
    final category = request.workCategory ?? 'N/A';
    final description = request.description ?? 'N/A';
    final property = request.rental?.rentalAddress ?? 'N/A';
    final unit = request.unit?.rentalUnit ?? 'N/A';

    return Scaffold(
      appBar: vendor_appbar.widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {},
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     Text(
              //       'Submit Bid',
              //       style: TextStyle(
              //         fontSize: 22,
              //         fontWeight: FontWeight.bold,
              //         color: blueColor,
              //       ),
              //     ),
              //     IconButton(
              //       onPressed: () => Navigator.of(context).pop(),
              //       icon: const Icon(Icons.close),
              //       style: IconButton.styleFrom(
              //         backgroundColor: Colors.grey.shade200,
              //         shape: const CircleBorder(),
              //       ),
              //     ),
              //   ],
              // ),
             
titleBar(title: 'Submit Bid',width: MediaQuery.of(context).size.width > 500
                              ? MediaQuery.of(context).size.width * .88
                              : MediaQuery.of(context).size.width * .91,),             
             
              const SizedBox(height: 24),

              // Bid Room Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bid Room Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: blueColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailRow('Category', category),
                    _detailRow('Description', description),
                    _detailRow('Property', '$property, Unit: $unit'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Price Breakdown *
              Text(
                'Price Breakdown *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: blueColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceBreakdownController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Enter detailed price breakdown...',
                  hintStyle: TextStyle(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: blueColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Price breakdown is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Total Price ($) *
              Text(
                'Total Price (\$) *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: blueColor,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter total price',
                  hintStyle: TextStyle(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: blueColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                validator: (v) {
                  final String raw = (v ?? '').trim();
                  if (raw.isEmpty) {
                    return 'Total price is required';
                  }
                  // Parsed as a double, not an int: web submits this field
                  // with parseFloat and the server stores it as a Number, so
                  // decimal amounts are valid (BidSubmissionModal.jsx). The
                  // old int parse also overflowed past 19 digits and reported
                  // that as non-numeric input.
                  final double? amount = double.tryParse(raw);
                  if (amount == null) {
                    return 'Enter a valid amount';
                  }
                  // Same wording as web's min(0) rule. The formatter keeps the
                  // minus key out, so this only fires if that ever changes.
                  if (amount < 0) {
                    return 'Price must be positive';
                  }
                  if (amount > _maxTotalPrice) {
                    return 'Total price is too large';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Upload Document (PDF or Word)
              Text(
                'Upload Document (PDF or Word)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: blueColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedFile != null
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split(RegExp(r'[/\\]')).last,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            onPressed: _removeDocument,
                            icon: Icon(Icons.close, color: blueColor, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: blueColor.withOpacity(0.1),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: _pickDocument,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              color: blueColor,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Upload Document (Maximum of 1)',
                              style: TextStyle(
                                fontSize: 14,
                                color: blueColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                'Supported : .pdf, .doc, .docx',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Buttons - same space, proper expand
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: blueColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold,fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitBid,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? Center(child: SpinKitFadingCircle(
                                color: Colors.white,
                                size: 25.0,
                              ))  
                          : const Text(
                              'Submit Bid',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label :',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
