import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';
import 'package:three_zero_two_property/services/applicant_checklist_rules.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import '../../../../repository/applicant_summery_repo.dart';
import 'package:three_zero_two_property/widgets/file_viewer.dart';
import 'package:three_zero_two_property/widgets/CustomTextField.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import '../../../../../widgets/custom_history_table.dart';
import '../../../../../enums/history_type.dart';

class SummaryContent extends StatefulWidget {
  applicant_summery_details summery;
  String applicant_id;
  SummaryContent({required this.summery, required this.applicant_id});

  @override
  State<SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends State<SummaryContent> {
  bool _showAllNotes = false;
  bool _showAllStatus = false;
  List<String> newItems = [];

  List<String> applicantCheckedChecklist = [
    "CreditCheck",
    "EmploymentVerification",
    "ApplicationFee",
    "IncomeVerification",
    "LandlordVerification"
  ];
  // Web's labels for the five standard items.
  final Map<String, String> displayNames = kApplicantChecklistLabels;
  // The checked items as last saved; like web, Save Changes compares with it.
  late List<String> _savedChecklist;
  TextEditingController checkvalue = TextEditingController();
  List<String> applicantChecklist = [];
  bool addcheckbox = false;
  /// Collapsed: header + "Attach Notes / File". Expanded: full form + saved list.
  bool _notesExpanded = false;
  TextEditingController noteController = TextEditingController();
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  String? _uploadedFileName;
  List<File> _pdfFiles = [];

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'csv'],
      allowMultiple: false, // Web allows a maximum of 1 file.
    );

    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.first;
      // Enforce the 20MB limit shown in the UI.
      if (picked.size > 20 * 1024 * 1024) {
        Fluttertoast.showToast(msg: 'File size must be 20MB or less.');
        return;
      }
      if (picked.path == null) return;
      final file = File(picked.path!);
      setState(() {
        _pdfFiles = [file];
      });
      await _uploadPdf(file);
    }
  }

  Future<void> _uploadPdf(File pdfFile) async {
    try {
      String? fileName = await uploadPdf(pdfFile);
      setState(() {
        _uploadedFileName = fileName;
      });
    } catch (e) {
      logError('PDF upload failed: $e');
    }
  }

  Future<String?> uploadPdf(File pdfFile) async {
    final String uploadUrl = '${Api_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('files', pdfFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      Fluttertoast.showToast(msg: 'PDF added successfully');
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  late List<ApplicantNotesAndFile> notesAndFiles;

  @override
  void initState() {
    super.initState();
    notesAndFiles = widget.summery.applicantNotesAndFile!;
    _savedChecklist =
        List<String>.from(widget.summery.applicantCheckedChecklist ?? []);
  }

  @override
  void didUpdateWidget(covariant SummaryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A freshly loaded applicant: its checklist is the saved one.
    if (!identical(oldWidget.summery, widget.summery)) {
      _savedChecklist =
          List<String>.from(widget.summery.applicantCheckedChecklist ?? []);
    }
  }

  void addNoteAndFile(ApplicantNotesAndFile noteFile) {
    setState(() {
      notesAndFiles.add(noteFile);
    });
  }

  void deleteNoteAndFile(int index, String applicantId, String note__id) async {
    ApplicantSummeryRepository applicantSummeryRepository =
        ApplicantSummeryRepository();

    int response = await applicantSummeryRepository.deleteNoteAndFiles(
        applicantId, note__id);
    if (response == 200) {
      Fluttertoast.showToast(msg: 'Note Delete Successfully');
      setState(() {
        notesAndFiles.removeAt(index);
      });
    }
  }

  // Open an attached note file/image in an in-app popup viewer (matches web's
  // dialog — image/PDF shown inside the app, never the external browser).
  void _openFile(String fileName) {
    FileViewer.showReceiptDialog(context, fileName);
  }

  // Confirm before deleting a note (matches the web "Are you sure?" dialog).
  Future<void> _confirmDeleteNote(
      int index, String applicantId, String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange, width: 3),
              ),
              child: const Icon(Icons.priority_high,
                  color: Colors.orange, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Are you sure?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'You want to delete this note?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFFDECEC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD0D5DD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      deleteNoteAndFile(index, applicantId, noteId);
    }
  }

  Widget _notesHeadTxt(String t) => Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          t,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: blueColor),
        ),
      );

  // Saved notes rendered as a Note | File | Clear table (matches web).
  Widget _buildNotesTable() {
    final int count = _showAllNotes
        ? notesAndFiles.length
        : (notesAndFiles.length > 10 ? 10 : notesAndFiles.length);

    final List<TableRow> rows = [
      TableRow(
        decoration: const BoxDecoration(color: Color(0xFFEDF1F7)),
        children: [
          _notesHeadTxt('Note'),
          _notesHeadTxt('File'),
          _notesHeadTxt('Clear'),
        ],
      ),
    ];
    for (int i = 0; i < count && i < notesAndFiles.length; i++) {
      final status = notesAndFiles[i];
      final bool hasFile = status.applicantFile != null &&
          status.applicantFile!.trim().isNotEmpty &&
          status.applicantFile!.trim().toLowerCase() != 'null';
      rows.add(TableRow(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            (status.applicantNotes ?? '').trim().isEmpty
                ? '—'
                : status.applicantNotes!.trim(),
            style: TextStyle(fontSize: 13, color: blueColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: hasFile
              ? InkWell(
                  onTap: () => _openFile(status.applicantFile!),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.insert_drive_file_outlined,
                          size: 16, color: blueColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          status.applicantFile!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: blueColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Text('—', style: TextStyle(fontSize: 13, color: grey)),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Center(
            child: InkWell(
              onTap: () => _confirmDeleteNote(
                  i, widget.summery.applicantId!, status.sId!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
              ),
            ),
          ),
        ),
      ]));
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(4),
          2: FlexColumnWidth(1.1),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFE4E7EC)),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }

  bool isNotePost = false;

  static const Color _kPageBg = Color(0xFFF4F6F9);
  static const Color _kBorder = Color(0xFFDBE0E5);
  static const Color _kIconMuted = Color(0xFF98A2B3);

  String _displayOptionalPhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'N/A';
    return formatPhoneNumber(raw);
  }

  /// Returns 'N/A' for null, empty, or literal "null" values.
  String _orNA(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty || v.toLowerCase() == 'null') return 'N/A';
    return v;
  }

  Widget _sectionCard(
      {required String title,
      required List<Widget> children,
      Widget? trailing}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _checklistItemBox(Widget rowChild) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: rowChild,
    );
  }

  Widget _contactRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kIconMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: blueColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String? raw) {
    final s = (raw ?? '').toLowerCase();
    final isRejected = s.contains('reject');
    final bg = isRejected ? const Color(0xFFFFE8E8) : const Color(0xFFE8F5E9);
    final fg = isRejected ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final label = raw?.trim().isNotEmpty == true ? raw! : 'Update';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  List<Widget> _buildUpdateRows(List<ApplicantStatus> statuses, int maxItems) {
    final List<Widget> rows = [];
    for (int i = 0; i < maxItems && i < statuses.length; i++) {
      final status = statuses[i];
      final when = status.updateAt ?? '';
      final by = status.statusUpdatedBy ?? 'Admin';
      final body =
          'The New Rental Application Status — Updated By $by At $when';
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusBadge(status.status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  body,
                  style: TextStyle(
                    color: blueColor,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final statusList = widget.summery.applicantStatus;
    final int statusItemCount = statusList == null || statusList.isEmpty
        ? 0
        : (_showAllStatus
            ? statusList.length
            : (statusList.length < 5 ? statusList.length : 5));
    applicantChecklist =
        List<String>.from(widget.summery.applicantCheckedChecklist!);
    final List customChecklistItems = widget.summery.applicantChecklist ?? [];
    final int checklistTotal =
        applicantCheckedChecklist.length + customChecklistItems.length;
    final int checklistDone = applicantCheckedChecklist
            .where((item) => applicantChecklist.contains(item))
            .length +
        customChecklistItems
            .where((item) => applicantChecklist.contains(item))
            .length;

    return ColoredBox(
      color: _kPageBg,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionCard(
                title: 'Application Checklist',
                trailing: Text(
                  '$checklistDone/$checklistTotal done',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A95A8),
                  ),
                ),
                children: [
                  ...applicantCheckedChecklist.map((item) {
                    return _checklistItemBox(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 40,
                            child: Checkbox(
                              value: widget.summery.applicantCheckedChecklist!
                                  .contains(item),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value != false) {
                                    widget.summery.applicantCheckedChecklist!
                                        .add(item);
                                    applicantChecklist.add(item);
                                  } else {
                                    widget.summery.applicantCheckedChecklist!
                                        .remove(item);
                                    applicantChecklist.remove(item);
                                  }
                                });
                              },
                              activeColor: blueColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayNames[item].toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: blueColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ...widget.summery.applicantChecklist!.map((item) {
                    return _checklistItemBox(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 40,
                            child: Checkbox(
                              value: widget.summery.applicantCheckedChecklist!
                                  .contains(item),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value != false) {
                                    widget.summery.applicantCheckedChecklist!
                                        .add(item);
                                    applicantChecklist.add(item);
                                  } else {
                                    widget.summery.applicantCheckedChecklist!
                                        .remove(item);
                                    applicantChecklist.remove(item);
                                  }
                                });
                              },
                              activeColor: blueColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: blueColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                widget.summery.applicantChecklist!.remove(item);
                              });
                              updatecheckBoxnew(
                                  widget.summery.applicantChecklist!);
                            },
                            child: const Icon(Icons.close, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }),
            if (addcheckbox)
              Column(
                children: [
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          hintText: 'Enter Value',
                          controller: checkvalue,
                        ),
                      ),
                      SizedBox(
                        width: 15,
                      ),
                      InkWell(
                        onTap: () {
                          // Like web (handleAddItem), a blank item is not added.
                          if (isBlankChecklistItem(checkvalue.text)) return;
                          setState(() {
                            widget.summery.applicantChecklist!
                                .add(checkvalue.text);
                            //newItems.add(checkvalue.text);
                            checkvalue.text = "";

                            addcheckbox = false;
                          });
                          updatecheckBoxnew(widget.summery.applicantChecklist!);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.green)),
                          child: const Icon(
                            Icons.check,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            checkvalue.text = "";
                            addcheckbox = false;
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.red)),
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              addcheckbox = !addcheckbox;
                            });
                          },
                          icon: Icon(Icons.add, color: blueColor, size: 18),
                          label: Text(
                            'Add Checklist',
                            style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: blueColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updatecheckBox(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _sectionCard(
                title: 'Applicant Information',
                children: [
                  Text(
                    '${widget.summery.applicantFirstName} ${widget.summery.applicantLastName}',
                    style: TextStyle(
                      fontSize: 17,
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _contactRow(
                    icon: Icons.home_outlined,
                    text: _displayOptionalPhone(
                        widget.summery.applicantHomeNumber),
                  ),
                  _contactRow(
                    icon: Icons.business_center_outlined,
                    text: _displayOptionalPhone(
                        widget.summery.applicantBusinessNumber),
                  ),
                  _contactRow(
                    icon: Icons.phone_outlined,
                    text: widget.summery.applicantPhoneNumber == null ||
                            widget.summery.applicantPhoneNumber!.trim().isEmpty
                        ? 'N/A'
                        : formatPhoneNumber(
                            widget.summery.applicantPhoneNumber!),
                  ),
                  _contactRow(
                    icon: Icons.email_outlined,
                    text: widget.summery.applicantEmail ?? 'N/A',
                  ),
                ],
              ),
              _sectionCard(
                title: 'Property Detail',
                children: [
                  Text(
                    'Interest Property',
                    style: TextStyle(
                      color: grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _contactRow(
                    icon: Icons.location_on_outlined,
                    text: _orNA(widget.summery.leaseData?.rentalAdress),
                  ),
                  _contactRow(
                    icon: Icons.home_outlined,
                    text: _orNA(widget.summery.leaseData?.rentalUnit) == 'N/A'
                        ? 'N/A'
                        : 'Unit :  ${_orNA(widget.summery.leaseData?.rentalUnit)}',
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Notes & Files',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: blueColor,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _notesExpanded = !_notesExpanded;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            side: BorderSide(color: blueColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            _notesExpanded
                                ? 'Hide'
                                : '+ Attach Note/File',
                            style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_notesExpanded) ...[
                                const SizedBox(height: 14),
                                Form(
                                  key: formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: noteController,
                                        minLines: 5,
                                        maxLines: 8,
                                        style: TextStyle(
                                          color: blueColor,
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Enter notes',
                                          hintStyle: TextStyle(
                                            color: grey,
                                            fontSize: 14,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.all(14),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: _kBorder),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: _kBorder),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: blueColor, width: 1.2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      InkWell(
                                        onTap: _pickPdfFiles,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: _kBorder),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Icon(
                                              //   Icons.cloud_upload_outlined,
                                              //   size: 36,
                                              //   color: _kIconMuted,
                                              // ),
                                              Image.asset(
                                      'assets/icons/Upload.png',
                                      height: 50,
                                      width: 50,
                                    ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      'Attach your File here (Maximum of 1)',
                                                      style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Maximum File Size is 20MB',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: grey,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Supported: .png, .jpeg, .pdf, .csv',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_uploadedFileName != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 54,
                                                height: 54,
                                                clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: _kBorder),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Image.network(
                                                  '$image_url${_uploadedFileName!}',
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) => Icon(
                                                    Icons
                                                        .insert_drive_file_outlined,
                                                    color: blueColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _uploadedFileName!,
                                                  style: TextStyle(
                                                      color: blueColor,
                                                      fontSize: 13),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => setState(() =>
                                                    _uploadedFileName = null),
                                                child: const Icon(Icons.close,
                                                    size: 18,
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: blueColor,
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () async {
                                              if (formKey.currentState!
                                                  .validate()) {
                                                NoteFile noteFiles = NoteFile(
                                                    note: noteController.text
                                                        .trim(),
                                                    files: _uploadedFileName ??
                                                        '');
                                                setState(() {
                                                  isNotePost = true;
                                                });
                                                ApplicantSummeryRepository
                                                    applicantSummeryRepository =
                                                    ApplicantSummeryRepository();

                                                int response =
                                                    await applicantSummeryRepository
                                                        .noteAndFilePost(
                                                            noteFiles,
                                                            widget.summery
                                                                .applicantId!);
                                                if (response == 200) {
                                                  Fluttertoast.showToast(
                                                      msg:
                                                          'Note Added Successfully');
                                                  noteController.clear();
                                                  _uploadedFileName = null;
                                                  // Refresh the notes list in place so the
                                                  // saved note shows immediately (no navigation).
                                                  try {
                                                    final fresh =
                                                        await ApplicantSummeryRepository
                                                            .getApplicantSummary(
                                                                widget.summery
                                                                    .applicantId!);
                                                    if (mounted) {
                                                      setState(() {
                                                        notesAndFiles = fresh
                                                                .applicantNotesAndFile ??
                                                            notesAndFiles;
                                                        isNotePost = false;
                                                      });
                                                    }
                                                  } catch (_) {
                                                    if (mounted) {
                                                      setState(() {
                                                        isNotePost = false;
                                                      });
                                                    }
                                                  }
                                                } else {
                                                  if (mounted) {
                                                    Fluttertoast.showToast(
                                                        msg:
                                                            'Failed to save note');
                                                    setState(() {
                                                      isNotePost = false;
                                                    });
                                                  }
                                                }
                                              } else {
                                                setState(() {
                                                  isNotePost = false;
                                                });
                                              }
                                            },
                                            child: isNotePost
                                                ? const Center(
                                                    child:
                                                        SpinKitFadingCircle(
                                                      color: Colors.white,
                                                      size: 20.0,
                                                    ),
                                                  )
                                                : const Text(
                                                    'Save',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                            onPressed: () {
                                              setState(() {
                                                noteController.clear();
                                                _uploadedFileName = null;
                                                _notesExpanded = false;
                                              });
                                            },
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                              side: BorderSide(
                                                  color: blueColor),
                                              backgroundColor: Colors.white,
                                              elevation: 0,
                                            ),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            ),
                                          ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ],
                                if (notesAndFiles.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  _buildNotesTable(),
                                  if (notesAndFiles.length > 10)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _showAllNotes = !_showAllNotes;
                                            });
                                          },
                                          child: Text(
                                            _showAllNotes
                                                ? 'Show Less'
                                                : 'View More',
                                            style:
                                                TextStyle(color: blueColor),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),

            const SizedBox(
              height: 10,
            ),
            if (widget.summery.applicantStatus != null &&
                widget.summery.applicantStatus!.isNotEmpty) ...[
              _sectionCard(
                title: 'Updates',
                children: [
                  ..._buildUpdateRows(
                    widget.summery.applicantStatus!,
                    statusItemCount,
                  ),
                  if (widget.summery.applicantStatus!.length > 5)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showAllStatus = !_showAllStatus;
                          });
                        },
                        child: Text(
                          _showAllStatus ? 'Show Less' : 'View More',
                          style: TextStyle(color: blueColor),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            //Applicant History Table - Using CustomHistoryTable
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              child: CustomHistoryTable(
                historyType: HistoryType.applicant,
                entityId: widget.applicant_id,
                title: 'History',
                blueColor: blueColor,
                itemsPerPage: 10,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // updatecheckBox() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   String? id = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //   var checkvalue = {"applicant_checkedChecklist": applicantChecklist};
  //   final response = await apiPut(
  //     Uri.parse('$Api_url/api/applicant/applicant/${widget.applicant_id}'),
  //     headers: <String, String>{
  //       "id": "CRM ${prefs.getString('staff_id') ?? id}",
  //       "authorization": "CRM $token",
  //       'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: jsonEncode(checkvalue),
  //   );
  //   if (response.statusCode == 200) {
  //     // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');
  //
  //     setState(() {});
  //   } else {
  //     // Log the response body for debugging
  //     print('Failed to update data: ${response.body}');
  //     throw Exception('Failed to update applicant data');
  //   }
  // }
  //
  // updatecheckBoxnew(List applicant) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   String? id = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //   var checkvalue = {"applicant_checklist": applicant};
  //   final response = await apiPut(
  //     Uri.parse(
  //         '$Api_url/api/applicant/applicant/${widget.applicant_id}/checklist'),
  //     headers: <String, String>{
  //       "id": "CRM ${prefs.getString('staff_id') ?? id}",
  //       "authorization": "CRM $token",
  //       'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: jsonEncode(checkvalue),
  //   );
  //   if (response.statusCode == 200) {
  //     // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');
  //
  //     setState(() {});
  //   } else {
  //     // Log the response body for debugging
  //     print('Failed to update data: ${response.body}');
  //     throw Exception('Failed to update applicant data');
  //   }
  // }
  updatecheckBox() async {
    // Like web (ApplicantSummary.jsx handleSaveChecklist): with no checklist
    // change, say so and save nothing.
    if (!applicantChecklistChanged(applicantChecklist, _savedChecklist)) {
      Fluttertoast.showToast(msg: applicantChecklistNoChangesMessage);
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString("adminId");

    String? idstaff = prefs.getString("staff_id");
    String? token = prefs.getString('token');

    ///var checkvalue = {"applicant_checkedChecklist": applicantChecklist};

    var checkvalue = {
      "applicant": {
        "applicant_checkedChecklist": applicantChecklist,
        "applicant_id": widget.summery.applicantId,
        // Replace with appropriate ID
        "admin_id": id,
        " staff_id": idstaff,

        "applicant_firstName": widget.summery.applicantFirstName,
        "applicant_lastName": widget.summery.applicantLastName,
        "applicant_email": widget.summery.applicantEmail,
        "applicant_phoneNumber": widget.summery.applicantPhoneNumber,
        "applicant_homeNumber": widget.summery.applicantHomeNumber,
        "applicant_businessNumber": widget.summery.applicantBusinessNumber,
        "applicant_telephoneNumber": widget.summery.applicantTelephoneNumber,
        "isMovedin": widget.summery.isMovedin,
        "createdAt": widget.summery.createdAt,
        "updatedAt": widget.summery.updatedAt,
        "isApplicantDataEmpty": widget.summery.isApplicantDataEmpty,
        "applicant_emailsend_date": widget.summery.applicantEmailsendDate,
        "lease_data": widget.summery.leaseData?.toJson(),
        // Serialize nested object
        "applicant_NotesAndFile": widget.summery.applicantNotesAndFile
            ?.map((note) => note.toJson()) // Map notes to JSON
            .toList(),
        "applicant_status": widget.summery.applicantStatus
            ?.map((status) => status.toJson()) // Map status to JSON
            .toList(),
      }
    };
    // print(checkvalue);

    final response = await apiPut(
      Uri.parse('$Api_url/api/applicant/applicant/${widget.applicant_id}'),
      headers: <String, String>{
        "id": "CRM $idstaff",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(checkvalue),
    );
    if (response.statusCode == 200) {
      Fluttertoast.showToast(msg: applicantChecklistSavedMessage);
      // Later saves are compared with what was just saved, like web.
      _savedChecklist = List<String>.from(applicantChecklist);
      setState(() {});
    } else {
      // Log the response body for debugging
      throw Exception('Failed to update applicant data');
    }
  }

  updatecheckBoxnew(List applicant) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString("adminId");
    String? idstaff = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    var checkvalue = {"applicant_checklist": applicant};
    final response = await apiPut(
      Uri.parse(
          '$Api_url/api/applicant/applicant/${widget.applicant_id}/checklist'),
      headers: <String, String>{
        "id": "CRM $idstaff",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(checkvalue),
    );
    if (response.statusCode == 200) {
      // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');

      setState(() {});
    } else {
      // Log the response body for debugging
      throw Exception('Failed to update applicant data');
    }
  }
}
