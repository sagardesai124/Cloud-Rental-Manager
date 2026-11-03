import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../../../widgets/titleBar.dart';
import '../../widgets/appbar.dart';
import '../../repository/workorder.dart';
import '../../model/workorder_summery_model.dart';

/// Full-screen "Update Work Order" form for the Vendor module.
/// Mirrors the Admin/Staff design: Assigned + Status + Due Date + Public/Private
/// notes (badged) + photo upload. Replaces the old AlertDialog popup.
class UpdateWorkOrderVendor extends StatefulWidget {
  final String workorderId;
  final WorkOrderData_summery summery;
  const UpdateWorkOrderVendor(
      {super.key, required this.workorderId, required this.summery});

  @override
  State<UpdateWorkOrderVendor> createState() => _UpdateWorkOrderVendorState();
}

class _UpdateWorkOrderVendorState extends State<UpdateWorkOrderVendor> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _publicNotes = TextEditingController();
  final TextEditingController _privateNotes = TextEditingController();
  final TextEditingController _dueDate = TextEditingController();
  String _dueDateApi = '';
  String? _selectedStatus;
  String? _selectedStaffId;

  Map<String, String> _staffs = {}; // staffmember_id -> name
  bool _loadingStaff = false;

  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];
  final List<String> _uploadedFileNames = [];
  bool _saving = false;

  String? _assignedError;
  String? _dueDateError;
  String? _statusError;

  // What the form opened with, so Save stays off until something changes.
  String? _initialStatus;
  String _initialDueDateApi = '';
  String? _initialStaffId;

  static const List<String> _statusOptions = [
    'New',
    'In Progress',
    'On Hold',
    'Completed',
    'Closed'
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.summery;
    _selectedStatus =
        (s.status != null && _statusOptions.contains(s.status)) ? s.status : null;
    if (s.date != null && s.date!.isNotEmpty) {
      _dueDate.text = s.date!;
      _dueDateApi = s.date!;
    }
    // Seed the Assigned dropdown with the work order's current assignee so the
    // existing staff member always shows (like web), even if the staff-list
    // endpoint isn't available to this role.
    final cid = s.staffmemberId;
    if (cid != null && cid.isNotEmpty) {
      final cname = s.staffData?.firstname;
      _staffs = {
        cid: (cname != null && cname.isNotEmpty && cname != 'N/A')
            ? cname
            : 'Assigned staff'
      };
      _selectedStaffId = cid;
    }
    _initialStatus = _selectedStatus;
    _initialDueDateApi = _dueDateApi;
    _initialStaffId = _selectedStaffId;
    // Typing a note changes whether Save is allowed, so redraw.
    _publicNotes.addListener(() => setState(() {}));
    _privateNotes.addListener(() => setState(() {}));
    _loadStaff();
  }

  @override
  void dispose() {
    _publicNotes.dispose();
    _privateNotes.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  // Web parity (WorkOrderDetails.jsx checkFormChanges): Update stays disabled
  // until the status, assignee or due date differs from what the form opened
  // with, a public or private note is typed or a photo is added. Saving an
  // untouched form used to add a duplicate Update History row and notify the
  // admin.
  bool get _hasChanges =>
      _selectedStatus != _initialStatus ||
      _dueDateApi != _initialDueDateApi ||
      (_selectedStaffId ?? '') != (_initialStaffId ?? '') ||
      _publicNotes.text.trim().isNotEmpty ||
      _privateNotes.text.trim().isNotEmpty ||
      _images.isNotEmpty;

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Staff belong to the ADMIN/account, so the endpoint path uses adminId.
      // The "id" header carries the logged-in vendor id (matches the rest of
      // the Vendor module's admin-scoped calls, e.g. vendor_permission_repo).
      final vendorId = prefs.getString("vendor_id");
      final adminId = prefs.getString("adminId");
      final token = prefs.getString('token');
      final res = await apiGet(
        Uri.parse('${Api_url}/api/staffmember/staff_member/$adminId'),
        headers: {"authorization": "CRM $token", "id": "CRM $vendorId"},
      );
      if (res.statusCode == 200) {
        final List data = json.decode(res.body)['data'];
        final Map<String, String> names = {};
        for (var d in data) {
          names[d['staffmember_id'].toString()] =
              d['staffmember_name'].toString();
        }
        // Always keep the work order's current assignee in the list.
        final cid = widget.summery.staffmemberId;
        if (cid != null && cid.isNotEmpty && !names.containsKey(cid)) {
          names[cid] = _staffs[cid] ??
              (widget.summery.staffData?.firstname ?? 'Assigned staff');
        }
        if (mounted) {
          setState(() {
            _staffs = names;
            if (cid != null && names.containsKey(cid)) {
              _selectedStaffId = cid;
            }
            _loadingStaff = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingStaff = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  Future<String?> _uploadImage(File file) async {
    final uploadUrl = '${image_upload_url}/api/images/upload';
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('files', file.path));
    final streamed = await apiSend(request);
    final resp = await http.Response.fromStream(streamed);
    final body = json.decode(resp.body);
    if (body['status'] == 'ok') {
      final List files = body['files'];
      return files.first['filename'];
    }
    return null;
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _images.add(file));
    try {
      final name = await _uploadImage(file);
      if (name != null && mounted) setState(() => _uploadedFileNames.add(name));
    } catch (_) {
      // keep the preview even if the upload fails
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: "Due Date",
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: blueColor,
            onPrimary: Colors.white,
            onSurface: blueColor,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: blueColor),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final api =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _dueDate.text = api;
        _dueDateApi = api;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _assignedError = null;
      _dueDateError = null;
      _statusError = null;
    });
    bool hasErrors = false;
    if (_selectedStaffId == null || _selectedStaffId!.isEmpty) {
      _assignedError = 'Please select an assigned staff member';
      hasErrors = true;
    }
    if (_dueDateApi.trim().isEmpty) {
      _dueDateError = 'Please select a due date';
      hasErrors = true;
    }
    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      _statusError = 'Please select a status';
      hasErrors = true;
    }
    if (hasErrors) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString("first_name");
    final lastName = prefs.getString("last_name");
    final values = <String, dynamic>{
      "date": _dueDateApi,
      "message": _publicNotes.text.trim(),
      "public_notes": _publicNotes.text.trim(),
      "private_notes": _privateNotes.text.trim(),
      "status": _selectedStatus,
      "statusUpdatedBy": "$firstName $lastName(Vendor)",
      "staffmember_name": _staffs[_selectedStaffId],
      "staffmember_id": _selectedStaffId,
      "workOrderUpdate_images": _uploadedFileNames,
    };
    try {
      await WorkOrderRepository.updateworkorderSummary(values, widget.workorderId);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      // Log failure but don't block the user
      print('Work order update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          titleBar(
            width: MediaQuery.of(context).size.width * .91,
            title: 'Update Work Order',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Assigned *'),
                              const SizedBox(height: 8),
                              _assignedField(),
                              if (_assignedError != null)
                                _errorText(_assignedError!),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Due Date *'),
                              const SizedBox(height: 8),
                              _dueDateField(),
                              if (_dueDateError != null)
                                _errorText(_dueDateError!),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label('Status *'),
                    const SizedBox(height: 8),
                    _statusField(),
                    if (_statusError != null) _errorText(_statusError!),
                    const SizedBox(height: 20),
                    _notesField(
                      label: 'Public Notes',
                      badgeText: 'VISIBLE TO ALL',
                      badgeBg: const Color(0xFFE7F6EC),
                      badgeFg: const Color(0xFF1F9D55),
                      controller: _publicNotes,
                      hint: 'Notes visible to all users',
                    ),
                    const SizedBox(height: 20),
                    _notesField(
                      label: 'Private Notes',
                      badgeText: 'ADMIN & STAFF ONLY',
                      badgeBg: const Color(0xFFFDF1DD),
                      badgeFg: const Color(0xFFB7791F),
                      controller: _privateNotes,
                      hint: 'Notes visible only to admin and staff',
                    ),
                    const SizedBox(height: 20),
                    _photoSection(),
                    const SizedBox(height: 24),
                    _buttons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            color: blueColor, fontWeight: FontWeight.bold, fontSize: 14),
      );

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: TextStyle(color: Colors.red[600], fontSize: 12)),
      );

  BoxDecoration get _boxDeco => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      );

  Widget _assignedField() {
    if (_loadingStaff) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _boxDeco,
        child: Row(
          children: [
            SpinKitFadingCircle(color: blueColor, size: 20),
            const SizedBox(width: 10),
            Text('Loading...',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }
    if (_staffs.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _boxDeco,
        child: Row(
          children: [
            Expanded(
              child: Text("Couldn't load staff",
                  style: TextStyle(color: Colors.red[400], fontSize: 13)),
            ),
            InkWell(
              onTap: _loadStaff,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: blueColor),
                  const SizedBox(width: 4),
                  Text('Retry',
                      style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: _boxDeco,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: const Text('Select here',
              style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3))),
          value: _selectedStaffId,
          items: _staffs.entries
              .map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedStaffId = v),
          buttonStyleData: const ButtonStyleData(
              height: 48, width: double.infinity, padding: EdgeInsets.zero),
          iconStyleData: const IconStyleData(
              icon: Icon(Icons.arrow_drop_down),
              iconEnabledColor: Color(0xFFb0b6c3)),
          dropdownStyleData: DropdownStyleData(
            width: MediaQuery.of(context).size.width * 0.82,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6), color: Colors.white),
          ),
          menuItemStyleData: const MenuItemStyleData(height: 40),
        ),
      ),
    );
  }

  Widget _statusField() {
    return Container(
      decoration: _boxDeco,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: const Text('Select Status',
              style: TextStyle(fontSize: 14, color: Color(0xFFb0b6c3))),
          value: _statusOptions.contains(_selectedStatus)
              ? _selectedStatus
              : null,
          items: _statusOptions
              .map((s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedStatus = v),
          buttonStyleData: const ButtonStyleData(
              height: 48, width: double.infinity, padding: EdgeInsets.zero),
          iconStyleData: const IconStyleData(
              icon: Icon(Icons.arrow_drop_down),
              iconEnabledColor: Color(0xFFb0b6c3)),
          dropdownStyleData: DropdownStyleData(
            width: MediaQuery.of(context).size.width * 0.82,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6), color: Colors.white),
          ),
          menuItemStyleData: const MenuItemStyleData(height: 40),
        ),
      ),
    );
  }

  Widget _dueDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _boxDeco,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dueDate.text.isEmpty ? 'yyyy-mm-dd' : _dueDate.text,
                style: TextStyle(
                  fontSize: 14,
                  color: _dueDate.text.isEmpty
                      ? const Color(0xFFb0b6c3)
                      : Colors.black87,
                ),
              ),
            ),
            Icon(Icons.calendar_today, color: blueColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _notesField({
    required String label,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: badgeBg, borderRadius: BorderRadius.circular(4)),
              child: Text(badgeText,
                  style: TextStyle(
                      color: badgeFg,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.4)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: _boxDeco,
          child: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoSection() {
    if (_images.isEmpty) {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Image.asset('assets/icons/Upload.png', height: 50, width: 50),
              const SizedBox(height: 8),
              Text('Upload your Photo here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 4),
              const Text('Maximum File Size is 20MB',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('Supported File Types are .png, .jpeg, .pdf, .csv',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                    color: blueColor, borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_images.length, (index) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_images[index], fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (index < _uploadedFileNames.length) {
                          _uploadedFileNames.removeAt(index);
                        }
                        _images.removeAt(index);
                      }),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buttons() {
    final bool canSave = _hasChanges;
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: blueColor),
              ),
            ),
            child: Text('Cancel',
                style: TextStyle(
                    color: blueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: (_saving || !canSave) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? blueColor : const Color(0xFFE5E8ED),
              disabledBackgroundColor: const Color(0xFFE5E8ED),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: SpinKitFadingCircle(color: Colors.white, size: 20),
                  )
                : Text('Save',
                    style: TextStyle(
                        color: canSave ? Colors.white : Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
