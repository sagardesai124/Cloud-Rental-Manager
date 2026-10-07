import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../../constant/constant.dart';
import '../../../Model/All_categories_model.dart';
import '../../../repository/fetch_allcategories.dart';
import '../../../widgets/VideoPlayerWidget.dart';
import '../../../widgets/titleBar.dart';
import '../../widgets/appbar.dart';
import '../../repository/workorder.dart';
import '../../model/workorder_summery_model.dart';
import '../../widgets/custom_drawer.dart';
import '../../../screens/Maintenance/Vendor/add_vendor.dart';
import '../../../screens/Rental/Tenants/add_tenants.dart' as admin_fields;

class Edit_Workorder extends StatefulWidget {
  final String workorderId;

  const Edit_Workorder({Key? key, required this.workorderId}) : super(key: key);

  @override
  State<Edit_Workorder> createState() => _Edit_WorkorderState();
}

class _Edit_WorkorderState extends State<Edit_Workorder> {
  final TextEditingController subject = TextEditingController();
  final TextEditingController perform = TextEditingController();
  final TextEditingController other = TextEditingController();

  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  WorkOrderData_summery? summery;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingCategories = false;
  bool _showTextField = false;

  List<File> selectedImages = [];
  List<String?> uploaded_images = []; // existing + newly uploaded
  bool _isUploading = false;

  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  String? _selectedEntry;
  final List<String> _entry = ['Yes', 'No'];

  // Snapshot of the record as loaded, so "Update Work Order" can refuse a
  // no-op save. The server (PUT work-order/:id) mails the manager, staff and
  // vendor on EVERY successful update and has no no-op detection of its own,
  // so the client is the only place this can be stopped. Web parity:
  // TAddWork.jsx gates its submit button on `isFormChanged`.
  String? initialSubject;
  String? initialWorkPerformed;
  String? initialSelectedCategory;
  String? initialSelectedEntry;
  List<String?>? initialSelectedimage;
  bool _dirtySnapshotReady = false;
  bool _lastDirty = false;

  @override
  void initState() {
    super.initState();
    // Text fields do not rebuild the screen on keystroke, so the dirty flag
    // (and with it the Update button) has to be re-evaluated by hand.
    subject.addListener(_onDirtyFieldChanged);
    perform.addListener(_onDirtyFieldChanged);
    _loadData();
    _loadDropdownCategories();
  }

  @override
  void dispose() {
    // CustomTextField only disposes a controller it created itself
    // (add_vendor.dart:1161), so `subject` and `perform` outlive it and the
    // dirty listeners must be detached here. `other` goes to a plain
    // TextFormField, so it stays ours to release.
    subject.removeListener(_onDirtyFieldChanged);
    perform.removeListener(_onDirtyFieldChanged);
    other.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final s =
      await WorkOrderRepository.getworkorderSummary(widget.workorderId);
      if (mounted) {
        setState(() {
          summery = s;
          subject.text = s.workSubject ?? '';
          perform.text = s.workPerformed ?? '';
          if (s.workOrderImages != null) {
            uploaded_images =
                s.workOrderImages!.map((e) => e?.toString()).toList();
          }
          _selectedEntry = s.entryAllowed == true ? 'Yes' : 'No';
          _isLoading = false;
          // Same values the live fields were just seeded with, kept as plain
          // strings so the diff never compares object identity.
          initialSubject = s.workSubject ?? '';
          initialWorkPerformed = s.workPerformed ?? '';
          initialSelectedCategory = s.workCategory;
          initialSelectedEntry = s.entryAllowed == true ? 'Yes' : 'No';
          initialSelectedimage = List<String?>.from(uploaded_images);
          _dirtySnapshotReady = true;
        });
        _applyCategoryFromSummery();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load work order'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyCategoryFromSummery() {
    if (summery?.workCategory == null || _dropdownCategories.isEmpty) return;
    final name = summery!.workCategory!;
    for (var c in _dropdownCategories) {
      if (c.name == name) {
        setState(() {
          _selectedDropdownCategory = c;
          _showTextField = c.name == 'Other';
        });
        break;
      }
    }
  }

  Future<void> _loadDropdownCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      if (mounted) {
        setState(() {
          _dropdownCategories = cats;
          _isLoadingCategories = false;
        });
        _applyCategoryFromSummery();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> selectImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        selectedImages = result.paths.map((path) => File(path!)).toList();
      });
      uploadSelectedImages();
    }
  }

  Future<void> uploadSelectedImages() async {
    if (selectedImages.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      for (File image in selectedImages) {
        final name = await uploadImage(image);
        if (name != null) {
          setState(() => uploaded_images.add(name));
        }
      }
      setState(() => selectedImages = []);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload image');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    final uploadUrl = '$image_upload_url/api/images/upload';
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    // Every other authenticated call in this file sends these headers; this
    // upload never did. The server has since started requiring them here
    // (confirmed via a live 401 "session expired" — the token/id were never
    // actually being sent, not actually expired).
    final prefs = await SharedPreferences.getInstance();
    final _token = prefs.getString('token');
    final _tenantId = prefs.getString('tenant_id');
    request.headers.addAll({
      "authorization": "CRM $_token",
      "id": "CRM $_tenantId",
    });
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));
    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);
    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      // A success status with no file entries would otherwise crash on
      // .first (or on the null list itself).
      final List files = responseBody['files'] ?? [];
      if (files.isEmpty) return null;
      return files.first["filename"];
    }
    return null;
  }

  bool isVideo(String url) => url.toLowerCase().endsWith(".mp4");

  /// Web's `normalizeValue`: null and blank read the same, so a null that
  /// loads as "" is not mistaken for an edit.
  String _normDirty(dynamic v) => v == null ? '' : v.toString().trim();

  bool _imagesDiffer() {
    final cur = uploaded_images;
    final was = initialSelectedimage ?? const <String?>[];
    if (cur.length != was.length) return true;
    for (var i = 0; i < cur.length; i++) {
      if (_normDirty(cur[i]) != _normDirty(was[i])) return true;
    }
    return false;
  }

  /// Only the fields this screen can actually edit and that the payload
  /// sends. Property and Unit are read-only here, and status/priority/vendor/
  /// staff/billable/due date/parts are not on the tenant form at all.
  bool _hasWorkOrderChanges() {
    if (!_dirtySnapshotReady) return false; // nothing loaded yet => not dirty
    return _normDirty(subject.text) != _normDirty(initialSubject) ||
        _normDirty(_selectedDropdownCategory?.name ?? summery?.workCategory) !=
            _normDirty(initialSelectedCategory) ||
        _normDirty(_selectedEntry) != _normDirty(initialSelectedEntry) ||
        _normDirty(perform.text) != _normDirty(initialWorkPerformed) ||
        _imagesDiffer();
  }

  void _onDirtyFieldChanged() {
    final v = _hasWorkOrderChanges();
    if (v != _lastDirty) {
      _lastDirty = v;
      if (mounted) setState(() {});
    }
  }

  void _submitForm() async {
    if (summery == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    // Backstop for the disabled button (web parity, TAddWork.jsx): a save with
    // nothing changed would still fire the server's notification e-mails.
    if (!_hasWorkOrderChanges()) {
      setState(() => _isSaving = false);
      Fluttertoast.showToast(
        msg: 'Please change at least one field to update the Work Order',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString("first_name") ?? '';
      final lastName = prefs.getString("last_name") ?? '';
      final statusUpdatedBy = '$firstName $lastName (Tenant)';
      final notificationTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Send only fields the API allows; do NOT send workorder_updates (causes 500 conflict)
      final Map<String, dynamic> workOrderMap = {
        'work_subject': subject.text.trim(),
        'work_category': _selectedDropdownCategory?.name ?? summery!.workCategory,
        'entry_allowed': _selectedEntry == 'Yes',
        'work_performed': perform.text.trim(),
        'workOrder_images': uploaded_images,
        // Web parity (TAddWork.js): the tenant Edit payload omits `status` —
        // status changes belong to the Update flow, not Edit.
        'rental_id': summery!.rentalId,
        'unit_id': summery!.unitId,
        'rental_adress': summery!.propertyData?.rentaladress ?? summery!.rentalAddressDisplay ?? '',
        'rental_unit': summery!.unitData?.rental_unit ?? summery!.rentalUnitDisplay ?? '',
        'statusUpdatedBy': statusUpdatedBy,
        'admin_id': summery!.adminId,
      };
      final categoryId = _selectedDropdownCategory?.categoryId;

      await WorkOrderRepository.updateworkorderSummary(
        workOrderMap,
        widget.workorderId,
        notificationTime: notificationTime,
        categoryId: categoryId,
      );

      Fluttertoast.showToast(
        msg: 'Work order updated successfully',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update work order'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = _hasWorkOrderChanges();
    _lastDirty = canSave;
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () => key.currentState!.openDrawer(),
      ),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(currentpage: 'Work Orders'),
      body: _isLoading
          ? Center(child: SpinKitFadingCircle(color: blueColor, size: 50))
          : summery == null
          ? const Center(child: Text('Failed to load work order'))
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 25),
              titleBar(
                width: MediaQuery.of(context).size.width * .91,
                title: 'Edit Work Order',
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: const Color(0xFFCED4DA)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Subject *'),
                        // const SizedBox(height: 10),
                        // Same text field as Admin, so its error matches the others.
                        admin_fields.CustomTextField(
                          keyboardType: TextInputType.text,
                          hintText: 'Add subject',
                          controller: subject,

                          showElevation: false,
                          borderColor: const Color(0xFFCED4DA),
                          borderWidth: 1.5,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter the subject';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        _label('Property *'),
                        _readOnlyField(
                          summery!.propertyData?.rentaladress ??
                              summery!.rentalAddressDisplay ??
                              summery!.rentalId ??
                              '—',
                        ),
                        const SizedBox(height: 10),
                        // Web parity (TAddWork.js): the Unit field renders only
                        // when the property actually has a unit, rather than
                        // showing a placeholder row on single-unit properties.
                        if (_unitDisplay.isNotEmpty) ...[
                          _label('Unit *'),
                          _readOnlyField(_unitDisplay),
                          const SizedBox(height: 10),
                        ],
                        _label('Category *'), // same label as web (development 2.1 / 2.2)
                        DropdownButtonHideUnderline(
                          child: DropdownButton2<allcategories_model>(
                            isExpanded: true,
                            hint: Text(_isLoadingCategories
                                ? 'Loading...'
                                : 'Select here'),
                            value: _dropdownCategories.contains(
                                _selectedDropdownCategory)
                                ? _selectedDropdownCategory
                                : null,
                            items: _dropdownCategories.map((cat) {
                              return DropdownMenuItem<
                                  allcategories_model>(
                                value: cat,
                                child: Text(cat.name ?? '',style: TextStyle(fontSize: 14, color: Colors.black87),),
                              );
                            }).toList(),
                            onChanged: _isLoadingCategories
                                ? null
                                : (allcategories_model? newValue) {
                              setState(() {
                                _selectedDropdownCategory =
                                    newValue;
                                _showTextField =
                                    newValue?.name == 'Other';
                              });
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 1),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(6),
                                color: Colors.white,
                                border: Border.all(color: Color(0xFFb0b6c3)),

                              ),
                              elevation: 0,
                            ),
                            dropdownStyleData: DropdownStyleData(
                              decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(6),
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        if (_showTextField)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 10, bottom: 10),
                            child: buildTextField('Other Category',
                                'Enter Other Category', other),
                          ),
                        const SizedBox(height: 10),
                        _label('Entry Allowed'),
                        DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            isExpanded: true,
                            hint: const Text('Select here'),
                            value: _selectedEntry,
                            items: _entry
                                .map((e) => DropdownMenuItem<String>(
                                value: e, child: Text(e,style: TextStyle(fontSize: 14, color: Colors.black87),)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedEntry = v),
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 1),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(6),
                                color: Colors.white,
                                border: Border.all(color: Color(0xFFb0b6c3)),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        // Status is deliberately absent (web parity,
                        // TAddWork.js): tenants change status via the Update
                        // flow, never from Edit.
                        const SizedBox(height: 10),
                        _label('Work To Be Performed'),
                        // const SizedBox(height: 10),
                        CustomTextField(
                          keyboardType: TextInputType.text,
                          hintText: 'Enter here',
                          controller: perform,
                          showElevation: false,
                          borderColor: const Color(0xFFCED4DA),
                          borderWidth: 1.5,
                          optional: true,
                        ),
                        // Web parity (TAddWork.js): Photos sit after Work To Be
                        // Performed, as the last section before the buttons.
                        const SizedBox(height: 10),
                        _buildImageUploadSection(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              height: 45,
                              width: 170,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canSave
                                      ? blueColor
                                      : const Color(0xFFE5E8ED),
                                  disabledBackgroundColor:
                                  const Color(0xFFE5E8ED),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8.0)),
                                ),
                                onPressed: (_isSaving || !canSave)
                                    ? null
                                    : _submitForm,
                                child: _isSaving
                                    ? const Center(
                                    child: SpinKitFadingCircle(
                                        color: Colors.white,
                                        size: 30))
                                    : Text('Update Work Order',
                                    style: TextStyle(
                                        color: canSave
                                            ? const Color(0xFFf7f8f9)
                                            : Colors.grey[600], fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              height: 45,
                              width: 120,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8.0)),
                                ),
                                onPressed: () =>
                                    Navigator.pop(context),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: Colors.grey[700],fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 2),child: Text(text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: blueColor)),);
  }

  /// Image upload section: Maintenance-style (dashed-style box, upload icon, file size/types text)
  Widget _buildImageUploadSection() {
    const double thumbSize = 80;
    const int maxImages = 10;
    final totalImages = uploaded_images.where((e) => e != null && e.isNotEmpty).length;
    final canAdd = totalImages < maxImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos (Maximum of 10)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: blueColor)),

        if (totalImages == 0)
          GestureDetector(
            onTap: canAdd ? selectImages : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/icons/Upload.png',
                    height: 50,
                    width: 50,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your Photo here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Maximum File Size is 20MB',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                  const Text(
                    'Supported File Types are .png, .jpeg, .pdf, .csv',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),

                ],
              ),
            ),
          ),
        if (totalImages == 0) const SizedBox(height: 10),
        if (totalImages > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canAdd)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: selectImages,
                        child: Container(
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                if (canAdd) const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: uploaded_images
                      .where((e) => e != null && e.isNotEmpty)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final imageUrl = entry.value!;
                    final isMp4 = isVideo(imageUrl);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => uploaded_images.remove(imageUrl)),
                          child: Icon(Icons.close, color: Colors.grey[700], size: 22),
                        ),
                        Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: isMp4
                                ? GestureDetector(
                              onTap: () => showDialog(
                                context: context,
                                builder: (ctx) => VideoPlayerDialog(
                                  videoUrl: '$image_url$imageUrl',
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoItem(url: '$image_url$imageUrl'),
                                  const Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 40),
                                ],
                              ),
                            )
                                : Image.network(
                              '$image_url$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.error, size: 32),
                            ),
                          ),
                        ),

                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  /// Same look as dropdowns: border, rounded corners, padding
  /// Unit as shown on the form. Empty when the property has no unit, which is
  /// what hides the field (web guards on `unitData[0].rental_unit`).
  String get _unitDisplay =>
      (summery?.unitData?.rental_unit ?? summery?.rentalUnitDisplay ?? '')
          .trim();

  Widget _readOnlyField(String text) {
    return Container(
      height: 50,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
        border: Border.all(color: Color(0xFFb0b6c3)),

      ),
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: TextStyle(fontSize: 14, color: Colors.black87)),
    );
  }

  Widget buildTextField(
      String label, String hintText, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(5)),
            child: TextFormField(
              controller: controller,
              decoration:
              InputDecoration(border: InputBorder.none, hintText: hintText),
            ),
          ),
        ),
      ],
    );
  }
}