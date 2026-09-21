import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:camera/camera.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import 'package:three_zero_two_property/widgets/camera_capture_screen.dart';
import 'package:three_zero_two_property/widgets/file_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/lease.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/newModel.dart';

// import 'package:three_zero_two_property/repository/properties_summery.dart';
import '../../../../model/summery_workorder.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../widgets/VideoPlayerWidget.dart';
import '../../../repository/workorder.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../../widgets/titleBar.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'Edit_workorders.dart';

class Workorder_summery extends StatefulWidget {
  String? workorder_id;
  Workorder_summery({super.key, this.workorder_id});

  @override
  State<Workorder_summery> createState() => _Workorder_summeryState();
}

class _Workorder_summeryState extends State<Workorder_summery>
    with SingleTickerProviderStateMixin, NetworkRetryState {
  List<String> applicantCheckedChecklist = [
    "CreditCheck",
    "EmploymentVerification",
    "ApplicationFee",
    "IncomeVerification",
    "LandlordVerification"
  ];
  List<String> applicantChecklist = [];
  final Map<String, String> displayNames = {
    "CreditCheck": "Credit and background check",
    "EmploymentVerification": "Employment verification",
    "ApplicationFee": "Application fee collected",
    "IncomeVerification": "Income verification",
    "LandlordVerification": "Landlord verification",
  };

  bool addcheckbox = false;
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();
  TextEditingController checkvalue = TextEditingController();
  List formDataRecurringList = [];
  late Future<WorkOrderData_summery> futureworkorderSummary;
  String? _selectedValue;
  TabController? _tabController;
  List<String> items = ["Approved", "Rejected"];
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls from `initState` only — controllers, listeners and
  /// filter defaults are not repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureworkorderSummary = widget.workorder_id != null ? WorkOrderRepository.getworkorderSummary(widget.workorder_id!) : Future<WorkOrderData_summery>.error('No work order id provided');;
      _loadStaff();;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
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
    futureworkorderSummary = widget.workorder_id != null
        ? WorkOrderRepository.getworkorderSummary(widget.workorder_id!)
        : Future<WorkOrderData_summery>.error('No work order id provided');

    _tabController = TabController(length: 2, vsync: this);
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _tabController?.dispose();
    _partsPageCtrl.dispose();
    startdateController.dispose();
    enddateController.dispose();
    checkvalue.dispose();
    super.dispose();
  }

  void _reloadSummary() {
    if (!mounted) return;
    setState(() {
      futureworkorderSummary =
          WorkOrderRepository.getworkorderSummary(widget.workorder_id!);
    });
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  void checkInternet() async {
    var connectiondata;
    connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus can report a stale `none` after the
    // connection is back; confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  bool isChecked = false;
  //for Staffmember
  Map<String, String> staffs = {};
  String? _selectedstaffId;
  String? _selectedStaffs;
  bool _isLoadingstaff = false;

  Future<void> _loadStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? staffid = prefs.getString("staff_id");
    //  String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingstaff = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/staffmember/staff_member/$id'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $staffid",
          }).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> staffnames = {};
        jsonResponse.forEach((data) {
          staffnames[data['staffmember_id'].toString()] =
              data['staffmember_name'].toString();
        });

        if (!mounted) return;
        setState(() {
          staffs = staffnames;
          _isLoadingstaff = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingstaff = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  //for image
  File? _image;
  bool isLoading = false;
  List<File> _images = [];
  String? _uploadedFileName;
  List<String> _uploadedFileNames = [];
  // Added with the attachment dialog ported from the Admin Summary screen:
  // this screen previously had no camera or video path at all, so it needs the
  // same two lists the other work-order screens keep.
  List<File> videofiles = [];
  List<bool> isvideo = [];
  Future<String?> uploadImage(File imageFile) async {
    // Scoped work-order endpoint: the plain /api/images/upload rejects video
    // (allowVideo: false). See the note in Add_workorder.dart.
    final String uploadUrl = '${image_upload_url}/api/images/upload-workorder';
    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          uploadUrl,
        ));
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    // 413 = the file exceeded the endpoint's limit; checked before decoding
    // because an oversize rejection often has a non-JSON body.
    if (responseData.statusCode == 413) {
      throw Exception(kUploadTooLargeMessage);
    }

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      setState(() {
        _image = File(image.path);
        _images.add(File(image.path));
      });
      _uploadImage(File(image.path));
    }
  }

  // ---------------------------------------------------------------
  // Attachment picker, ported from the Admin work-order Summary screen
  // (lib/screens/Maintenance/Workorder/workorder_summery.dart). This
  // screen used to go straight to _picker.pickImage(), so Staff could
  // attach neither video nor documents here while Admin could. Same
  // dialog, same three sources.
  // ---------------------------------------------------------------
  Future<void> _showImageSourceDialog(
      void Function(void Function()) parentSetState) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Select Media From',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options Row
                    // Wrap, not Row: three tiles overflow a narrow phone.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildSourceOption(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _pickImageFromSource(ImageSource.gallery, () {
                              parentSetState(() {});
                            });
                          },
                        ),
                        _buildSourceOption(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _openCameraInterface(() {
                              parentSetState(() {});
                            });
                          },
                        ),
                        _buildSourceOption(
                          icon: Icons.insert_drive_file,
                          label: 'Document',
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _pickDocument(() {
                              parentSetState(() {});
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Build individual source option
  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: blueColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: blueColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pick image from specific source
  Future<void> _pickImageFromSource(ImageSource source,
      [VoidCallback? onImageAdded]) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickMedia();

    if (image != null) {
      final File file = File(image.path);
      // Lowercased: iPhone camera videos are .MOV (uppercase).
      bool isVideo = image.path.toLowerCase().endsWith('.mp4') ||
          image.path.toLowerCase().endsWith('.mov');
      if (isVideo) {
        String? thumbnailPath = await _generateVideoThumbnail(image.path);
        if (thumbnailPath != null) {
          setState(() {
            _images.add(File(thumbnailPath));
            isvideo.add(true);
            videofiles.add(file);
          });
        }
      } else {
        setState(() {
          _images.add(file);
          isvideo.add(false);
          videofiles.add(file);
        });
      }
      await _uploadImage(file);
      // Force dialog to refresh if it's open
      setState(() {});
      // Call callback to refresh dialog if provided
      onImageAdded?.call();
    }
  }

  // Open unified camera interface for both photos and videos
  Future<void> _openCameraInterface([VoidCallback? onImageAdded]) async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorDialog('No cameras found on this device');
        return;
      }

      // Use the first available camera (usually back camera)
      final camera = cameras.first;

      // Navigate to camera screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(
            camera: camera,
            onImageCaptured: (File imageFile) async {
              // Handle captured image
              setState(() {
                _images.add(imageFile);
                isvideo.add(false);
                videofiles.add(imageFile);
              });
              await _uploadImage(imageFile);
              // Force dialog to refresh if it's open
              setState(() {});
              // Call callback to refresh dialog if provided
              onImageAdded?.call();
            },
            onVideoCaptured: (File videoFile) async {
              // Handle captured video
              String? thumbnailPath =
                  await _generateVideoThumbnail(videoFile.path);
              if (thumbnailPath != null) {
                setState(() {
                  _images.add(File(thumbnailPath));
                  isvideo.add(true);
                  videofiles.add(videoFile);
                });
              }
              await _uploadImage(videoFile);
              // Force dialog to refresh if it's open
              setState(() {});
              // Call callback to refresh dialog if provided
              onImageAdded?.call();
            },
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to open camera: $e');
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    final String? thumbPath =
        await video_thumbnail.VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: video_thumbnail.ImageFormat.PNG,
      maxHeight: 80,
      quality: 50,
    );
    return thumbPath;
  }

  /// Document extensions the work-order endpoint accepts.
  static const List<String> _documentExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv',
  ];

  /// Pick a document. Separate from the photo picker: on iOS a file browser
  /// cannot show the camera roll, so each source needs its own native UI.
  Future<void> _pickDocument(VoidCallback onDone) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _documentExtensions,
    );
    final String? pickedPath = result?.files.single.path;
    if (pickedPath == null) return;
    final File file = File(pickedPath);
    // Refuse an obviously oversized file before spending minutes uploading
    // it, the way web does (AddWorkorder.jsx:1038-1050). The in-flight 413
    // check in uploadImage() is still the backstop, because the enforced
    // ceiling is currently lower than this one.
    if (await file.length() > kMaxAttachmentUploadMb * 1024 * 1024) {
      Fluttertoast.showToast(
        // Pre-check wording names the limit, as web's does
        // (AddWorkorder.jsx:1044); the in-flight 413 message deliberately
        // does not, matching web there too.
        msg: uploadTooLargeUpFrontMessage(attachmentDisplayName(pickedPath)),
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    setState(() {
      _images.add(file);
    });
    await _uploadImage(file);
    onDone();
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      String? fileName = await uploadImage(imageFile);
      if (!mounted || fileName == null) return;
      setState(() {
        _uploadedFileNames.add(fileName!);
        _uploadedFileName = fileName;
        _imageUrls.add(fileName!);
      });
    } catch (e) {
      // Was log-only: a failed upload on this screen told the user nothing at
      // all, so an oversize video simply never appeared with no explanation.
      if (mounted) {
        Fluttertoast.showToast(
          msg: friendlyErrorMessage(e, fallbackMessage: kUploadFailedMessage),
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
      logError('Image upload failed: $e');
    }
  }

  List<String> _imageUrls = [];
  int visibleCount = 5;
  int _partsVisibleCount = 5;
  final PageController _partsPageCtrl = PageController();
  int selectedTabIndex = 0;
  bool showAllImages = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: widget302.,
      key: key,
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Work Orders",
        dropdown: true,
      ),
      body: !isOffline
          ? Column(
              children: [
                const SizedBox(
                  height: 15,
                ),
                // Back control reuses the Settings screens' treatment
                // (Settings_screen.dart): a light rounded square with a
                // chevron, leading the row. Same markup in the Admin and
                // Staff copies of this screen so the two stay in step.
                Row(
                  children: [
                    const SizedBox(width: 20),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF1F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.chevron_left,
                              color: blueColor, size: 28),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Edit sits at the trailing end of the same row, styled
                    // like the Mortgage summary's header action
                    // (mortgage_summery.dart) so detail screens share one
                    // Back / Edit layout.
                    ElevatedButton.icon(
                      onPressed: _openEditWorkOrder,
                      icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                      label: const Text('Edit',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF152B51),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                titleBar(
                  width: MediaQuery.of(context).size.width * .91,
                  title: 'Work Order Details',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: FutureBuilder<WorkOrderData_summery>(
                        future: futureworkorderSummary,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: SpinKitFadingCircle(
                                color: Colors.black,
                                size: 55.0,
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return friendlyErrorState(snapshot.error);
                          } else if (!snapshot.hasData ||
                              snapshot.data == null) {
                            return const Center(child: Text('No data found.'));
                          } else {
                            // _selectedValue = snapshot.data!.applicantStatus!.last!.status;
                            return Column(
                              children: <Widget>[
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Text(
                                      "Work Order : #${snapshot.data!.ticketNumber ?? 'N/A'}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: AnimatedBuilder(
                                    animation: _tabController!,
                                    builder: (context, _) {
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _tabController!.animateTo(0),
                                              child: Container(
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: _tabController!.index == 0 ? blueColor : Colors.white,
                                                  border: Border.all(color: blueColor),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Summary',
                                                  style: TextStyle(
                                                    color: _tabController!.index == 0 ? Colors.white : blueColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _tabController!.animateTo(1),
                                              child: Container(
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: _tabController!.index == 1 ? blueColor : Colors.white,
                                                  border: Border.all(color: blueColor),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Task',
                                                  style: TextStyle(
                                                    color: _tabController!.index == 1 ? Colors.white : blueColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      Summery_page(snapshot.data!),
                                      Task(snapshot.data!),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        }),
                  ),
                ),
              ],
            )
          : NoInternetView(onRetry: retryNow),
    );
  }

  List<String> titles = [' Account', 'Qty', '  Price', 'Amount'];
  Map<int, TableColumnWidth> columnWidth = {
    0: const FlexColumnWidth(3.3),
    1: const FlexColumnWidth(1),
    2: const FlexColumnWidth(1.9),
    3: const FlexColumnWidth(1.81),
  };
  // int getTotalPrice() {
  //   //return products.fold(0, (sum, item) => sum + item.totalAmount);
  //   return 0;
  // }

  double getTotalPrice(List<PartsandchargeData>? partsList) {
    if (partsList == null || partsList.isEmpty) return 0.0;

    return partsList.fold(
        0.0,
        (sum, item) =>
            sum + ((item.partsQuantity ?? 0) * (item.partsPrice ?? 0)));
  }

  Widget tableView(
    bool isHeader,
  ) {
    return Table(
      columnWidths: columnWidth,
      children: [
        isHeader
            ? TableRow(
                decoration:
                    const BoxDecoration(color: Color.fromRGBO(21, 43, 83, 1)),
                children: titles
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(item,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                    .toList())
            : const TableRow(
                decoration: BoxDecoration(color: Color.fromRGBO(21, 43, 83, 1)),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Total',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(''),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(''),
                  ),
                  // Padding(
                  //   padding: EdgeInsets.all(8.0),
                  //   child: Text(
                  //     "\$${getTotalPrice()}",
                  //     style: TextStyle(
                  //         color: Colors.white,
                  //         fontWeight: FontWeight.bold,
                  //         fontSize: 13),
                  //   ),
                  // ),
                ],
              ),
      ],
    );
  }

  Summery_page(WorkOrderData_summery summery) {
    final dateProvider = Provider.of<DateProvider>(context);
    double grandTotal = 0;

    // applicantChecklist = List<String>.from(summery.applicantCheckedChecklist!);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * .48,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  border: Border.all(color: blueColor),
                                  // color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    '${summery.workSubject}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                      child: Text(
                                    '${summery.propertyData?.rentaladress}',
                                    style: TextStyle(color: blueColor),
                                  )),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    'Description',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                    '${summery.workPerformed}',
                                    style: TextStyle(color: blueColor),
                                  )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Status",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text('${summery.status}',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    'Permission to enter',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                    '${summery.entryAllowed}',
                                    style: TextStyle(color: blueColor),
                                  )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Due Date",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                        dateProvider
                                                .formatCurrentDate(
                                                    '${summery.workorderUpdates?.last.date}')
                                                .isEmpty
                                            ? 'N/A'
                                            : dateProvider.formatCurrentDate(
                                                '${summery.workorderUpdates?.last.date}'),
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    'Vendors Notes',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width > 500
                                            ? 200
                                            : 150,
                                    child: Text(
                                      '${summery.vendorNotes}',
                                      maxLines:
                                          4, // Set maximum number of lines
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign
                                          .justify, // Handle overflow with ellipsis
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 13
                                                : 18,
                                        color: blueColor,
                                      ),
                                    ),
                                  ),
                                  // Container(
                                  //     child: Text(
                                  //   '${summery.vendorNotes}',
                                  //   style: TextStyle(color: blueColor),
                                  // )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Assignees",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    summery.staffData != null
                                        ? Text(
                                            '${summery.staffData?.firstname}',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold))
                                        : Text('N/A',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .45,
                      child: Column(
                        children: [
                          if (summery.tenantData != null)
                            SizedBox(
                              height: 220,
                              child: Material(
                                borderOnForeground: true,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 2, // 40%
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            // color: Colors.blue,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            /*   boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // changes position of shadow
                                ),
                              ],*/
                                          ),
                                          child: Material(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Contacts',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 7, // 60%
                                        child: Column(
                                          children: [
                                            Container(
                                                decoration: const BoxDecoration(
                                                  //  color: Colors.green,
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                    bottom: Radius.circular(10),
                                                  ),
                                                ),
                                                child: ListTile(
                                                  title: Text(
                                                    "Vendor",
                                                    style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                  subtitle: summery
                                                              .vendorData !=
                                                          null
                                                      ? Text(
                                                          summery.vendorData!
                                                                  .companyName ??
                                                              "N/A",
                                                          style: TextStyle(
                                                              color: blueColor),
                                                        )
                                                      : Text(
                                                          "N/A",
                                                          style: TextStyle(
                                                              color: blueColor),
                                                        ),
                                                  leading: Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 3),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 30,
                                                    ),
                                                  ),
                                                )),
                                            const Divider(
                                              thickness: 3,
                                            ),
                                            Container(
                                                decoration: const BoxDecoration(
                                                  //  color: Colors.green,
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                    bottom: Radius.circular(10),
                                                  ),
                                                ),
                                                child: ListTile(
                                                  title: Text(
                                                    "Tenant",
                                                    style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                  subtitle: summery
                                                              .tenantData !=
                                                          null
                                                      ? Text(
                                                          "${summery.tenantData!.firstname ?? "N/A"} ${summery.tenantData!.lastname ?? "N/A"}",
                                                          style: TextStyle(
                                                              color: blueColor),
                                                        )
                                                      : Text(
                                                          "N/A",
                                                          style: TextStyle(
                                                              color: blueColor),
                                                        ),
                                                  leading: Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 3),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 30,
                                                    ),
                                                  ),
                                                )),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (summery.tenantData == null)
                            SizedBox(
                              height: 120,
                              child: Material(
                                borderOnForeground: true,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 3, // 40%
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            // color: Colors.blue,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            /*   boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // changes position of shadow
                                ),
                              ],*/
                                          ),
                                          child: Material(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Contacts',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        color: blueColor,
                                      ),
                                      Expanded(
                                        flex: 7, // 60%
                                        child: Container(
                                            decoration: const BoxDecoration(
                                              //  color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                bottom: Radius.circular(10),
                                              ),
                                            ),
                                            child: ListTile(
                                              title: Text(
                                                "Vendor",
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                              subtitle:
                                                  summery.vendorData != null
                                                      ? Text(
                                                          summery.vendorData!
                                                                  .companyName ??
                                                              "N/A",
                                                          style: TextStyle(
                                                              color: blueColor),
                                                        )
                                                      : Text(
                                                          "N/A",
                                                          style: TextStyle(
                                                              color: blueColor),
                                                        ),
                                              leading: Container(
                                                padding: const EdgeInsets.only(
                                                    top: 3),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 30,
                                                ),
                                              ),
                                            )),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(
                            height: 10,
                          ),
                          Material(
                            borderOnForeground: true,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Property',
                                            style: TextStyle(
                                              color: blueColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    color: blueColor,
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (summery.propertyData!.rental_image !=
                                          null)
                                        Column(
                                          children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            CachedNetworkImage(
                                              imageUrl:
                                                  "$image_url${summery.propertyData!.rental_image}",
                                              placeholder: (context, url) => Text(
                                                  "${summery.propertyData!.rental_image}"),
                                              errorWidget:
                                                  (context, url, error) => Icon(
                                                      Icons.error,
                                                      color: blueColor),
                                              /*  imageBuilder: (context, imageProvider) => Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),*/
                                            ),
                                          ],
                                        ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Text(
                                        "${summery.propertyData!.rentaladress} (${summery.unitData!.unitName})",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: blueColor),
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "${summery.propertyData!.rental_city}, ",
                                            style: TextStyle(color: blueColor),
                                          ),
                                          Text(
                                            "${summery.propertyData!.rental_state}, ",
                                            style: TextStyle(color: blueColor),
                                          ),
                                          Text(
                                            "${summery.propertyData!.rental_country}, ",
                                            style: TextStyle(color: blueColor),
                                          ),
                                          Text(
                                            "${summery.propertyData!.rental_postcode} ",
                                            style: TextStyle(color: blueColor),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                    ],
                                  )
                                  /*  ListTile(
                            title: Text(
                              "Vendor",
                              style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              "Vendor Company Name",
                              style: TextStyle(color: blueColor),
                            ),
                            leading: Container(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.person,
                                size: 30,
                              ),
                            )

                          ),*/
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                if (summery.partsandchargeData!.length > 0)
                  IntrinsicHeight(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFDBE0E5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                            ),
                            child: Text(
                              'Parts and Labor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          /*Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Column(
                                      children: summery.partsandchargeData!.map((part) {
                                        int partTotal =
                                        (part.partsPrice! * part.partsQuantity!);
                                        print(partTotal);
                                        grandTotal += partTotal;
                                        print(grandTotal);
                                        return PartWidget(part: part, total: 0.0);
                                      }).toList(),
                                    ),
                                    */ /*  Column(
                                  children: summery.partsandchargeData!.map((part) {
                                    int partTotal = (part.partsPrice! * part.partsQuantity!);
                                    print(partTotal);
                                    grandTotal += partTotal;
                                    print(grandTotal);
                                    return PartWidget(part: part, total:0.0);
                                  }).toList(),
                                ),*/ /*
                                    // Divider(color: Colors.grey),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          formatMoney(grandTotal),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),*/
                          Table(
                            border: TableBorder.all(width: 1),
                            columnWidths: const {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2),
                              4: FlexColumnWidth(2),
                            },
                            children: [
                              TableRow(children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('QTY',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Account',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Description',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Price',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Amount',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ]),
                              ...summery.partsandchargeData!
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                int index = entry.key;
                                PartsandchargeData row = entry.value;
                                grandTotal +=
                                    (row.partsQuantity! * row.partsPrice!);
                                return TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("${row.partsQuantity}"),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("${row.account}"),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("${row.description}"),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(formatMoney(row.partsPrice ?? 0)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        formatMoney(row.partsPrice! * row.partsQuantity!)),
                                  ),
                                ]);
                              }).toList(),
                              TableRow(children: [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(formatMoney(grandTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ]),
                            ],
                          ),
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2F8),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Update History', style: TextStyle(fontSize: 16, color: blueColor, fontWeight: FontWeight.bold)),
                            InkWell(
                              onTap: () { showUpdateDialog(context); },
                              child: Container(
                                height: 30,
                                width: 85,
                                decoration: BoxDecoration(color: blueColor, borderRadius: BorderRadius.circular(8)),
                                child: const Center(child: Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      ...summery.workorderUpdates!.reversed.take(visibleCount).map((update) {
                        const updLabel = TextStyle(
                          color: Color(0xFF6B7A90),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        );
                        final updValue = TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        );
                        Widget field(String label, String value, {Color? valueColor}) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: updLabel),
                              const SizedBox(height: 4),
                              Text(value, style: updValue.copyWith(color: valueColor ?? blueColor)),
                            ],
                          );
                        }
                        final dateStr = update.date?.isNotEmpty == true
                            ? dateProvider.formatCurrentDate('${update.date}')
                            : 'N/A';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2F8),
                            border: Border.all(color: const Color(0xFFDBE0E5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: field('Assignees', update.staffmemberName ?? 'N/A')),
                                  const SizedBox(width: 12),
                                  Expanded(child: field('Due Date', dateStr)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: const Color(0xFFDBE0E5)),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: field('Status', update.status ?? 'N/A', valueColor: const Color(0xFF1F9D55))),
                                  const SizedBox(width: 12),
                                  Expanded(child: field('Updated By', update.statusUpdatedBy ?? 'N/A')),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: const Color(0xFFDBE0E5)),
                              const SizedBox(height: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Message', style: updLabel), const SizedBox(height: 4), Text('${update.statusUpdatedBy ?? ""} updated this work order ($dateStr)', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14))]),
                              if ((update.publicNotes ?? '').trim().isNotEmpty)
                                _historyNoteBlock(
                                  label: 'Public Notes',
                                  badgeText: 'VISIBLE TO ALL',
                                  badgeBg: const Color(0xFFE7F6EC),
                                  badgeFg: const Color(0xFF1F9D55),
                                  value: update.publicNotes!,
                                ),
                              if ((update.privateNotes ?? '').trim().isNotEmpty)
                                _historyNoteBlock(
                                  label: 'Private Notes',
                                  badgeText: 'ADMIN & STAFF ONLY',
                                  badgeBg: const Color(0xFFFDF1DD),
                                  badgeFg: const Color(0xFFB7791F),
                                  value: update.privateNotes!,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (summery.workorderUpdates!.length > 5)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() { visibleCount = visibleCount == 5 ? summery.workorderUpdates!.length : 5; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFDBE0E5)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      visibleCount == 5 ? '+${summery.workorderUpdates!.length - 5} more' : 'View Less',
                                      style: TextStyle(color: blueColor, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      visibleCount == 5 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                      size: 16,
                                      color: blueColor,
                                    ),
                                  ],
                                ),
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
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        );
      } else {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Billing Information
                      Expanded(
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Container(
                                  height: 50,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2F8),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    'Billing Information',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  400
                                              ? 14
                                              : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                // Body
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 1,
                                    ),
                                    Checkbox(
                                      value: summery.isBillable ?? false,
                                      onChanged: (val) {
                                        setState(
                                            () => isChecked = val ?? false);
                                      },
                                      activeColor: blueColor,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Billable to Tenant',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 1,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Contacts
                      Expanded(
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Container(
                                  height: 50,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2F8),
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  400
                                              ? 14
                                              : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Body
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person, color: blueColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Vendor',
                                                  style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  summery.vendorData
                                                          ?.companyName ??
                                                      'N/A',
                                                  style: TextStyle(
                                                      color: blueColor,
                                                      fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (summery.tenantData != null) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.person,
                                                color: blueColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Tenant',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${summery.tenantData?.firstname ?? ''} ${summery.tenantData?.lastname ?? ''}',
                                                    style: TextStyle(
                                                        color: blueColor,
                                                        fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
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
                const SizedBox(
                  height: 10,
                ),
                Material(
                  borderOnForeground: true,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFFDBE0E5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
  decoration: const BoxDecoration(
    color: Color(0xFFEEF2F8),
    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
  ),
  child: Text(
    'Property',
    style: TextStyle(
      color: blueColor,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),
),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (summery.propertyData!.rental_image != null &&
                                summery.propertyData!.rental_image!.isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Container(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              "$image_url${summery.propertyData!.rental_image}",
                                          placeholder: (context, url) => Text(
                                              "${summery.propertyData!.rental_image}"),
                                          errorWidget: (context, url, error) =>
                                              Icon(
                                            Icons.error,
                                            color: blueColor,
                                          ),
                                          /*  imageBuilder: (context, imageProvider) => Container(
                                          width: 40.0,
                                          height: 40.0,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            image: DecorationImage(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),*/
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                ),
                                Text(
                                  "${summery.propertyData!.rentaladress} ",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      color: blueColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                ),
                                SizedBox(
                                  width: 300,
                                  child: Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 4.0,
                                    runSpacing: 4.0,
                                    children: [
                                      Text(
                                        "${summery.propertyData!.rental_city}, ",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData!.rental_state}, ",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData!.rental_country}, ",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData!.rental_postcode}",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Builder(builder: (context) {
                    const labelPill = TextStyle(
                      color: Color(0xFF6B7A90),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    );
                    final valuePill = TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    );
                    Widget pill({required String label, required String value, Color? valueColor, bool tinted = true}) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: tinted ? const Color(0xFFEEF2F8) : Colors.white,
                          border: tinted ? null : Border.all(color: const Color(0xFFDBE0E5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: labelPill),
                            const SizedBox(height: 6),
                            Text(value, style: valuePill.copyWith(color: valueColor ?? blueColor)),
                          ],
                        ),
                      );
                    }
                    final dueDate = () {
                      final last = summery.workorderUpdates?.isNotEmpty == true ? summery.workorderUpdates!.last.date : null;
                      return (last != null && last.isNotEmpty) ? dateProvider.formatCurrentDate(last) : 'N/A';
                    }();
                    final unitSuffix = (summery.unitData?.rental_unit != null &&
                            summery.unitData!.rental_unit.toString().trim().isNotEmpty)
                        ? ' (${summery.unitData?.rental_unit})'
                        : '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summery.workSubject ?? "N/A"}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, color: blueColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(text: '${summery.propertyData?.rentaladress ?? "N/A"}'),
                              if (unitSuffix.isNotEmpty)
                                TextSpan(
                                  text: unitSuffix,
                                  style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pill(label: 'Assignees', value: summery.staffData?.firstname ?? 'N/A')),
                            const SizedBox(width: 10),
                            Expanded(child: pill(label: 'Due Date', value: dueDate)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: pill(
                              label: 'Permission',
                              value: summery.entryAllowed == true ? 'Yes' : summery.entryAllowed == false ? 'No' : 'N/A',
                              valueColor: summery.entryAllowed == true ? const Color(0xFF1F9D55) : null,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: pill(
                              label: 'Status',
                              value: (summery.status != null && summery.status!.isNotEmpty) ? summery.status! : 'N/A',
                              valueColor: const Color(0xFF1F9D55),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Description',
                          value: (summery.workPerformed != null && summery.workPerformed!.isNotEmpty) ? summery.workPerformed! : 'N/A',
                          tinted: false,
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Vendor Notes',
                          value: (summery.vendorNotes != null && summery.vendorNotes!.isNotEmpty) ? summery.vendorNotes! : 'N/A',
                          tinted: false,
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (summery.partsandchargeData!.length > 0)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFFDBE0E5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2F8),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Parts and Labor',
                                style: TextStyle(fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE1E9F4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${summery.partsandchargeData?.length ?? 0}',
                                  style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Builder(
                            builder: (context) {
                              final parts = summery.partsandchargeData ?? [];
                              final showCount = _partsVisibleCount > parts.length ? parts.length : _partsVisibleCount;
                              final visibleItems = parts.take(showCount).toList();
                              final hiddenCount = parts.length - showCount;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: visibleItems.map((item) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Color(0xFFDBE0E5)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: const BoxDecoration(color: Color(0xFFE8F0FA), shape: BoxShape.circle),
                                              child: Icon(Icons.settings, size: 16, color: blueColor),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.account ?? '', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      const Text('Qty ', style: TextStyle(color: Color(0xFF6B7A90), fontSize: 12)),
                                                      Text('${item.partsQuantity ?? 0}', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                      const SizedBox(width: 14),
                                                      const Text('Price ', style: TextStyle(color: Color(0xFF6B7A90), fontSize: 12)),
                                                      Text(formatMoney(item.partsPrice ?? 0), style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              formatMoney((item.amount ?? ((item.partsPrice ?? 0) * (item.partsQuantity ?? 0)))),
                                              style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (parts.length > 5)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 8, top: 2),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => setState(() {
                                            _partsVisibleCount = _partsVisibleCount >= parts.length ? 5 : parts.length;
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: const Color(0xFFDBE0E5)),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  hiddenCount > 0 ? '+$hiddenCount more' : 'View Less',
                                                  style: TextStyle(color: blueColor, fontWeight: FontWeight.w600, fontSize: 12),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  hiddenCount > 0 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                                  size: 16,
                                                  color: blueColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                    decoration: BoxDecoration(color: blueColor, borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text(formatMoney(getTotalPrice(summery.partsandchargeData)), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (summery.partsandchargeData!.length > 0)
                  const SizedBox(
                    height: 10,
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with title and button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Update History',
                            style: TextStyle(
                              fontSize: 16,
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              showUpdateDialog(context);
                            },
                            child: Material(
                              elevation: 1,
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                              child: Container(
                                height: 30,
                                width: 85,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                    child: Text(
                                  "Update",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...summery.workorderUpdates!.reversed
                          .take(visibleCount)
                          .map((update) {
                        const updLabel = TextStyle(color: Color(0xFF6B7A90), fontWeight: FontWeight.w600, fontSize: 13);
                        final updValue = TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14);
                        Widget field(String label, String value, {Color? valueColor}) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: updLabel),
                              const SizedBox(height: 4),
                              Text(value, style: updValue.copyWith(color: valueColor ?? blueColor)),
                            ],
                          );
                        }
                        final dateStr = (update.date != null && update.date!.isNotEmpty)
                            ? dateProvider.formatCurrentDate(update.date!)
                            : 'N/A';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2F8),
                            border: Border.all(color: const Color(0xFFDBE0E5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: field('Assignees', update.staffmemberName ?? 'N/A')),
                                  const SizedBox(width: 12),
                                  Expanded(child: field('Due Date', dateStr)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: const Color(0xFFDBE0E5)),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: field('Status', update.status ?? 'N/A', valueColor: const Color(0xFF1F9D55))),
                                  const SizedBox(width: 12),
                                  Expanded(child: field('Updated By', update.statusUpdatedBy ?? 'N/A')),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: const Color(0xFFDBE0E5)),
                              const SizedBox(height: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Message', style: updLabel), const SizedBox(height: 4), Text('${update.statusUpdatedBy ?? ""} updated this work order ($dateStr)', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14))]),
                              if ((update.publicNotes ?? '').trim().isNotEmpty)
                                _historyNoteBlock(
                                  label: 'Public Notes',
                                  badgeText: 'VISIBLE TO ALL',
                                  badgeBg: const Color(0xFFE7F6EC),
                                  badgeFg: const Color(0xFF1F9D55),
                                  value: update.publicNotes!,
                                ),
                              if ((update.privateNotes ?? '').trim().isNotEmpty)
                                _historyNoteBlock(
                                  label: 'Private Notes',
                                  badgeText: 'ADMIN & STAFF ONLY',
                                  badgeBg: const Color(0xFFFDF1DD),
                                  badgeFg: const Color(0xFFB7791F),
                                  value: update.privateNotes!,
                                ),
                              if (update.workOrderUpdateimages != null &&
                                  update.workOrderUpdateimages!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: update.workOrderUpdateimages!
                                      .map((imageUrl) {
                                    return GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: Stack(
                                              children: [
                                                Positioned(
                                                  top: 10,
                                                  right: 10,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                        Icons.close,
                                                        size: 30,
                                                        color: Colors.black),
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                  ),
                                                ),
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20),
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          "$image_url$imageUrl",
                                                      placeholder: (context,
                                                              url) =>
                                                          const CircularProgressIndicator(),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          const Icon(
                                                              Icons.error),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width:
                                            (MediaQuery.of(context).size.width /
                                                    3) -
                                                16,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: "$image_url$imageUrl",
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                SpinKitFadingCircle(
                                              color: blueColor,
                                              size: 55.0,
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ] else ...[
                                const SizedBox(height: 10),
                                // Row(
                                //   mainAxisAlignment: MainAxisAlignment.center,
                                //   children:  [
                                //     Text(
                                //       "No Images Provided",
                                //       style: TextStyle(color: Colors.transparent),
                                //     ),
                                //   ],
                                // ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      if (summery.workorderUpdates!.length > 5)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() { visibleCount = visibleCount == 5 ? summery.workorderUpdates!.length : 5; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFDBE0E5)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      visibleCount == 5 ? '+${summery.workorderUpdates!.length - 5} more' : 'View Less',
                                      style: TextStyle(color: blueColor, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      visibleCount == 5 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                      size: 16,
                                      color: blueColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  Widget _buildLabelValue(String label, String value,
      {Color valueColor = Colors.black}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Task(WorkOrderData_summery summery) {
    final dateProvider = Provider.of<DateProvider>(context);
    double grandTotal = 0;
    // applicantChecklist = List<String>.from(summery.applicantCheckedChecklist!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .5,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        // color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  border: Border.all(color: blueColor),
                                  // color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      width: 150,
                                      child: Text(
                                        '${summery.workSubject}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                      child: Text(
                                    '${summery.propertyData?.rentaladress}',
                                    style: TextStyle(color: blueColor),
                                  )),
                                ],
                              ),
                              const Spacer(),
                              if (summery.priority == "High")
                                Container(
                                  height: 35,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.red, width: 3),
                                  ),
                                  child: const Center(
                                      child: Text("High",
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w400))),
                                ),
                              if (summery.priority == "Medium")
                                Container(
                                  height: 35,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: blueColor, width: 3),
                                  ),
                                  child: Center(
                                      child: Text("Medium",
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.w400))),
                                ),
                              if (summery.priority == "Normal")
                                Container(
                                  height: 35,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey, width: 3),
                                  ),
                                  child: const Center(
                                      child: Text("Normal",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w400))),
                                )
                            ],
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    'Description',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                    '${summery.workPerformed!.isNotEmpty ? summery.workPerformed : "N/A"}',
                                    style: TextStyle(color: blueColor),
                                  )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Status",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text('${summery.status}',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    'Permission to enter',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                    '${summery.entryAllowed}',
                                    style: TextStyle(color: blueColor),
                                  )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Due Date",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                        (summery.workorderUpdates == null ||
                                                summery.workorderUpdates!
                                                    .isEmpty ||
                                                summery.workorderUpdates!.last
                                                        .date ==
                                                    null ||
                                                summery.workorderUpdates!.last
                                                    .date!.isEmpty)
                                            ? "N/A"
                                            : dateProvider.formatCurrentDate(
                                                summery.workorderUpdates!.last
                                                    .date!),
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                    'Vendors Notes',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      width: 150,
                                      child: Text(
                                        '${summery.vendorNotes!.isNotEmpty ? summery.vendorNotes : "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Assignees",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    summery.staffData != null
                                        ? Text(
                                            '${summery.staffData?.firstname}',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold))
                                        : Text('N/A',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Material(
                      elevation: 7,
                      borderOnForeground: true,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.43,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                              ),
                              child: Material(
                                elevation: 4,
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Images',
                                      style: TextStyle(
                                        color: blueColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (summery.workorderUpdates != null)
                                  Column(
                                    children: [
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: summery.workOrderImages!.map((imageUrl) {
                                          // This row pushed every attachment through CachedNetworkImage, with an
                                          // errorWidget that returned an empty Container - so a video or a document
                                          // attached through the update dialog rendered as nothing at all: no tile,
                                          // no play control, no way to open it. Uses the same doc / video / photo
                                          // split the Images row further down already had.
                                          final bool isVid = isVideo(imageUrl);
                                          final bool isDoc =
                                              attachmentKindOf(imageUrl) == AttachmentKind.document;
                                          final double tileWidth = summery.workOrderImages!.length == 1
                                              ? MediaQuery.of(context).size.width / 3
                                              : (MediaQuery.of(context).size.width / 3) - 10;
                                          return GestureDetector(
                                            onTap: () {
                                              if (isDoc) {
                                                FileViewer.showReceiptDialog(
                                                  context,
                                                  attachmentDisplayName(imageUrl),
                                                  fileUrl: '$image_url$imageUrl',
                                                );
                                              } else if (isVid) {
                                                _showVideoDialog('$image_url$imageUrl');
                                              } else {
                                                _openImagePreview('$image_url$imageUrl');
                                              }
                                            },
                                            child: Container(
                                              width: tileWidth,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: isDoc
                                                    ? AspectRatio(
                                                        aspectRatio: 1,
                                                        child: Container(
                                                          color: const Color(0xFFF2F4F7),
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(Icons.insert_drive_file,
                                                                  color: blueColor, size: 40),
                                                              const SizedBox(height: 6),
                                                              Text(
                                                                attachmentExtensionLabel(imageUrl),
                                                                style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: blueColor),
                                                              ),
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(horizontal: 8),
                                                                child: Text(
                                                                  attachmentDisplayName(imageUrl),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  textAlign: TextAlign.center,
                                                                  style: const TextStyle(
                                                                      fontSize: 10, color: Colors.grey),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      )
                                                    : isVid
                                                        ? AspectRatio(
                                                            aspectRatio: 1,
                                                            child: Stack(
                                                              alignment: Alignment.center,
                                                              children: [
                                                                VideoItem(url: '$image_url$imageUrl'),
                                                                const Icon(Icons.play_circle_fill,
                                                                    color: Colors.white, size: 40),
                                                              ],
                                                            ),
                                                          )
                                                        : CachedNetworkImage(
                                                            imageUrl: "$image_url$imageUrl",
                                                            placeholder: (context, url) => const Center(
                                                                child: CircularProgressIndicator()),
                                                            errorWidget: (context, url, error) {
                                                              return Container();
                                                            },
                                                            fit: BoxFit.cover,
                                                          ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                if (summery.workOrderImages!.length == 0)
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("No Images Provided"),
                                      // Text("(${summery.unitData!.unitName})"),
                                    ],
                                  ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  "${summery.propertyData!.rentaladress} (${summery.unitData!.unitName})",
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                SizedBox(
                                  width: 300,
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing:
                                        4.0, // Space between texts horizontally
                                    runSpacing:
                                        4.0, // Space between lines when wrapping
                                    children: [
                                      Text(
                                          "${summery.propertyData!.rental_city}, "),
                                      Text(
                                          "${summery.propertyData!.rental_state}, "),
                                      Text(
                                          "${summery.propertyData!.rental_country}, "),
                                      Text(
                                          "${summery.propertyData!.rental_postcode}"),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                              ],
                            )
                            /*  ListTile(
                              title: Text(
                                "Vendor",
                              ),
                              subtitle: Text(
                                "Vendor Company Name",
                              ),
                              leading: Container(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                ),
                              )

                            ),*/
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Builder(builder: (context) {
                    const labelPill = TextStyle(
                      color: Color(0xFF6B7A90),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    );
                    final valuePill = TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    );
                    Widget pill({required String label, required String value, Color? valueColor, bool tinted = true}) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: tinted ? const Color(0xFFEEF2F8) : Colors.white,
                          border: tinted ? null : Border.all(color: const Color(0xFFDBE0E5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: labelPill),
                            const SizedBox(height: 6),
                            Text(value, style: valuePill.copyWith(color: valueColor ?? blueColor)),
                          ],
                        ),
                      );
                    }
                    final dueDate = (summery.workorderUpdates == null ||
                            summery.workorderUpdates!.isEmpty ||
                            summery.workorderUpdates!.last.date == null ||
                            summery.workorderUpdates!.last.date!.isEmpty)
                        ? 'N/A'
                        : dateProvider.formatCurrentDate(summery.workorderUpdates!.last.date!);
                    final unitSuffix = (summery.unitData?.rental_unit != null &&
                            summery.unitData!.rental_unit.toString().trim().isNotEmpty)
                        ? ' (${summery.unitData?.rental_unit})'
                        : '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summery.workSubject ?? "N/A"}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, color: blueColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(text: '${summery.propertyData?.rentaladress ?? "N/A"}'),
                              if (unitSuffix.isNotEmpty)
                                TextSpan(
                                  text: unitSuffix,
                                  style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pill(label: 'Assignees', value: summery.staffData?.firstname ?? 'N/A')),
                            const SizedBox(width: 10),
                            Expanded(child: pill(label: 'Due Date', value: dueDate)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: pill(
                              label: 'Permission',
                              value: (summery.entryAllowed ?? false) ? 'Yes' : 'No',
                              valueColor: (summery.entryAllowed ?? false) ? const Color(0xFF1F9D55) : null,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: pill(
                              label: 'Status',
                              value: (summery.status != null && summery.status!.isNotEmpty) ? summery.status! : 'N/A',
                              valueColor: const Color(0xFF1F9D55),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Description',
                          value: (summery.workPerformed != null && summery.workPerformed!.isNotEmpty) ? summery.workPerformed! : 'N/A',
                          tinted: false,
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Vendor Notes',
                          value: (summery.vendorNotes != null && summery.vendorNotes!.isNotEmpty) ? summery.vendorNotes! : 'N/A',
                          tinted: false,
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(
                  height: 10,
                ),
                IntrinsicHeight(
                  child: Material(
                    // elevation: 7,
                    borderOnForeground: true,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                            ),
                            child: Text(
                              'Images',
                              style: TextStyle(
                                color: blueColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Column(
                          //   crossAxisAlignment: CrossAxisAlignment.start,
                          //   children: [
                          //     if (summery.workorderUpdates != null)
                          //       Column(
                          //         children: [
                          //           SizedBox(height: 10),
                          //           Wrap(
                          //             spacing: 10,
                          //             runSpacing: 10,
                          //             alignment: WrapAlignment.start,
                          //             children: summery.workOrderImages!
                          //                 .map((fileUrl) {
                          //               bool isMp4 = isVideo(fileUrl);
                          //               return Container(
                          //                 width:
                          //                     summery.workOrderImages!
                          //                                 .length ==
                          //                             1
                          //                         ? MediaQuery.of(context)
                          //                                 .size
                          //                                 .width /
                          //                             3
                          //                         : (MediaQuery.of(context)
                          //                                     .size
                          //                                     .width /
                          //                                 3) -
                          //                             10,
                          //                 decoration: BoxDecoration(
                          //                   borderRadius:
                          //                       BorderRadius.circular(10),
                          //                 ),
                          //                 child: ClipRRect(
                          //                   borderRadius:
                          //                       BorderRadius.circular(10),
                          //                   child: isMp4
                          //                       ? Container(
                          //                           height: 80,
                          //                           width: 80,
                          //                           child: GestureDetector(
                          //                             onTap: () {
                          //                               _showVideoDialog(
                          //                                   '$image_url$fileUrl');
                          //                             },
                          //                             child: Stack(
                          //                               alignment:
                          //                                   Alignment.center,
                          //                               children: [
                          //                                 // Image.file(
                          //                                 //   File(snapshot.data!),
                          //                                 //   height: 100,
                          //                                 //   width: 100,
                          //                                 //   fit: BoxFit.cover,
                          //                                 // ),
                          //                                 VideoItem(
                          //                                   url:
                          //                                       '$image_url$fileUrl',
                          //                                 ),
                          //                                 Icon(
                          //                                     Icons
                          //                                         .play_circle_fill,
                          //                                     color:
                          //                                         Colors.white,
                          //                                     size: 40),
                          //                               ],
                          //                             ),
                          //                           ),
                          //                         )
                          //                       // FutureBuilder<String?>(
                          //                       //   future: generateNetworkVideoThumbnail("$image_url$fileUrl"),
                          //                       //   builder: (context, snapshot) {
                          //                       //     if (snapshot.connectionState == ConnectionState.waiting) {
                          //                       //       return Center(
                          //                       //           child: SpinKitFadingCircle(
                          //                       //             color: Colors.black,
                          //                       //             size: 40.0,
                          //                       //           ));
                          //                       //     } else if (snapshot.hasData && snapshot.data != null) {
                          //                       //       return
                          //                       //         GestureDetector(
                          //                       //         onTap: (){
                          //                       //           _showVideoDialog('$image_url$fileUrl');
                          //                       //         },
                          //                       //         child: Stack(
                          //                       //           alignment: Alignment.center,
                          //                       //           children: [
                          //                       //             Image.file(
                          //                       //               File(snapshot.data!),
                          //                       //               height: 100,
                          //                       //               width: 100,
                          //                       //               fit: BoxFit.cover,
                          //                       //             ),
                          //                       //             Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                          //                       //           ],
                          //                       //         ),
                          //                       //       );
                          //                       //
                          //                       //     } else {
                          //                       //       return Icon(Icons.error);
                          //                       //     }
                          //                       //   },
                          //                       // )
                          //                       : CachedNetworkImage(
                          //                           height: 140,
                          //                           imageUrl:
                          //                               "$image_url$fileUrl",
                          //                           placeholder: (context,
                          //                                   url) =>
                          //                               Center(
                          //                                   child:
                          //                                       SpinKitFadingCircle(
                          //                             color: Colors.black,
                          //                             size: 40.0,
                          //                           )),
                          //                           errorWidget:
                          //                               (context, url, error) =>
                          //                                   Icon(Icons.error),
                          //                           fit: BoxFit.cover,
                          //                         ),
                          //                 ),
                          //               );
                          //             }).toList(),
                          //           ),
                          //         ],
                          //       ),
                          //     if (summery.workOrderImages!.length == 0)
                          //       Row(
                          //         mainAxisAlignment: MainAxisAlignment.center,
                          //         children: [
                          //           Text("No Images Provided"),
                          //           // Text("(${summery.unitData!.unitName})"),
                          //         ],
                          //       ),
                          //     SizedBox(
                          //       height: 10,
                          //     ),
                          //   ],
                          // )
                          // Declare this in your state

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (summery.workOrderImages != null &&
                                  summery.workOrderImages!.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 18),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 13),
                                        child: SizedBox(
                                          height: 150,
                                          child: Row(
                                            children: summery.workOrderImages!
                                                .take(showAllImages
                                                    ? summery
                                                        .workOrderImages!.length
                                                    : 2)
                                                .map((fileUrl) {
                                              bool isMp4 = isVideo(fileUrl);
                                              // A document has no thumbnail, so
                                              // it used to fall through to
                                              // CachedNetworkImage and land on
                                              // its errorWidget - an error icon
                                              // for a perfectly good PDF
                                              // attached from web.
                                              final bool isDoc =
                                                  attachmentKindOf(fileUrl) ==
                                                      AttachmentKind.document;
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: Container(
                                                  width: 150,
                                                  height: 150,
                                                  // color: Colors.blue,
                                                  margin: const EdgeInsets.only(
                                                      right: 8),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    child: isDoc
                                                        ? GestureDetector(
                                                            onTap: () {
                                                              FileViewer
                                                                  .showReceiptDialog(
                                                                context,
                                                                attachmentDisplayName(
                                                                    fileUrl),
                                                                fileUrl:
                                                                    '$image_url$fileUrl',
                                                              );
                                                            },
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFFF2F4F7),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade300),
                                                              ),
                                                              child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .insert_drive_file,
                                                                      color:
                                                                          blueColor,
                                                                      size: 44),
                                                                  const SizedBox(
                                                                      height: 6),
                                                                  Text(
                                                                    attachmentExtensionLabel(
                                                                        fileUrl),
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color:
                                                                            blueColor),
                                                                  ),
                                                                  Padding(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            8),
                                                                    child: Text(
                                                                      attachmentDisplayName(
                                                                          fileUrl),
                                                                      maxLines: 2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          color: Colors
                                                                              .grey),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          )
                                                        : isMp4
                                                        ? GestureDetector(
                                                            onTap: () {
                                                              _showVideoDialog(
                                                                  '$image_url$fileUrl');
                                                            },
                                                            child: Stack(
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              children: [
                                                                VideoItem(
                                                                    url:
                                                                        '$image_url$fileUrl'),
                                                                const Icon(
                                                                  Icons
                                                                      .play_circle_fill,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 40,
                                                                ),
                                                              ],
                                                            ),
                                                          )
                                                        : GestureDetector(
                                                            // Same full-screen preview the wider layout uses; without
                                                            // this, tapping a photo on a phone did nothing while videos
                                                            // beside it already opened.
                                                            onTap: () => _openImagePreview('$image_url$fileUrl'),
                                                            child: CachedNetworkImage(
                                                                imageUrl:
                                                                    "$image_url$fileUrl",
                                                                fit: BoxFit.fill,
                                                                placeholder:
                                                                    (context,
                                                                            url) =>
                                                                        const Center(
                                                                  child:
                                                                      SpinKitFadingCircle(
                                                                    color: Colors
                                                                        .black,
                                                                    size: 30.0,
                                                                  ),
                                                                ),
                                                                errorWidget: (context,
                                                                        url,
                                                                        error) =>
                                                                    const Icon(Icons
                                                                        .error),
                                                              ),
                                                          ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (summery.workOrderImages!.length > 2)
                                      const SizedBox(height: 15),

                                    /// View More / View Less Button
                                    if (summery.workOrderImages!.length > 2)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 18),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              showAllImages = !showAllImages;
                                            });
                                          },
                                          child: Text(
                                            showAllImages
                                                ? "View Less"
                                                : "View More",
                                            style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 18),
                                  ],
                                ),

                              /// If no images
                              if (summery.workOrderImages == null ||
                                  summery.workOrderImages!.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      "No Images Provided",
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.black54),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                IntrinsicHeight(
                  child: Material(
                    // elevation: 7,
                    borderOnForeground: true,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            child: Text(
                              'Property',
                              style: TextStyle(
                                color: blueColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${summery.propertyData!.rentaladress}${(summery.unitData?.rental_unit != null && summery.unitData!.rental_unit.toString().trim().isNotEmpty) ? ' (${summery.unitData?.rental_unit})' : ''}",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(fontSize: 15, color: blueColor, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${summery.propertyData!.rental_city}, ${summery.propertyData!.rental_state}, ${summery.propertyData!.rental_country}, ${summery.propertyData!.rental_postcode}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        }
      }),
    );
  }

  String imageUrl = "";
  bool isVideo(String url) {
    // Was `.endsWith(".mp4")`, which missed .mov - the format every iPhone
    // records - so an iPhone clip attached to a work order was pushed through
    // an image widget and rendered as a broken tile. The shared classifier
    // covers .mp4/.mov/.webm/.m4v, matching the server's VIDEO_EXTENSIONS and
    // the Edit screens, which already handled .mov.
    return isAttachmentVideo(url);
  }

  // void showUpdateDialog(BuildContext context) {
  //   // Initialize variables to store user input
  //   String? selectedStatus;
  //   //  DateTime? selectedDate;
  //   //String? message;
  //   TextEditingController message = TextEditingController();
  //   TextEditingController selectedDate = TextEditingController();
  //
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder(
  //         builder: (BuildContext context, StateSetter setState) {
  //           return Dialog(
  //             child: Container(
  //               // width: double.maxFinite,
  //               child: Padding(
  //                 padding: const EdgeInsets.only(
  //                     left: 10, right: 10, top: 15, bottom: 10),
  //                 child: Column(
  //                   mainAxisSize: MainAxisSize.min,
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: <Widget>[
  //                     Row(
  //                       children: [
  //                         Text(
  //                           'Update Work Order',
  //                           style: TextStyle(
  //                               color: blueColor,
  //                               fontWeight: FontWeight.bold,
  //                               fontSize: 18),
  //                         ),
  //                         Spacer(),
  //                         GestureDetector(
  //                           onTap: (){
  //                             Navigator.pop(context);
  //                           },
  //                             child: Icon(Icons.close,)),
  //
  //                       ],
  //                     ),
  //                     SizedBox(height: 10.0),
  //                     Text('Status',
  //                         style: TextStyle(
  //                             color: blueColor, fontWeight: FontWeight.bold)),
  //                     DropdownButtonHideUnderline(
  //                       child: DropdownButtonFormField2<String>(
  //                         decoration: InputDecoration(border: InputBorder.none),
  //                         isExpanded: true,
  //                         hint: const Row(
  //                           children: [
  //                             Expanded(
  //                               child: Text(
  //                                 'Select Status',
  //                                 style: TextStyle(
  //                                   fontSize: 14,
  //                                   fontWeight: FontWeight.w400,
  //                                   color: Color(0xFFb0b6c3),
  //                                 ),
  //                                 overflow: TextOverflow.ellipsis,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         items: ['New', 'In Progress', 'On Hold', 'Completed']
  //                             .map((status) {
  //                           return DropdownMenuItem<String>(
  //                             value: status,
  //                             child: Text(
  //                               status,
  //                               style: const TextStyle(
  //                                 fontSize: 14,
  //                                 fontWeight: FontWeight.w400,
  //                                 color: Colors.black87,
  //                               ),
  //                               overflow: TextOverflow.ellipsis,
  //                             ),
  //                           );
  //                         }).toList(),
  //                         value: selectedStatus,
  //                         onChanged: (value) {
  //                           selectedStatus = value;
  //                         },
  //                         buttonStyleData: ButtonStyleData(
  //                           height: 45,
  //                           width: double.infinity,
  //                           padding: const EdgeInsets.only(left: 14, right: 14),
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.circular(6),
  //                             color: Colors.white,
  //                           ),
  //                           elevation: 2,
  //                         ),
  //                         iconStyleData: const IconStyleData(
  //                           icon: Icon(Icons.arrow_drop_down),
  //                           iconSize: 24,
  //                           iconEnabledColor: Color(0xFFb0b6c3),
  //                           iconDisabledColor: Colors.grey,
  //                         ),
  //                         dropdownStyleData: DropdownStyleData(
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.circular(6),
  //                             color: Colors.white,
  //                           ),
  //                           scrollbarTheme: ScrollbarThemeData(
  //                             radius: const Radius.circular(6),
  //                             thickness: MaterialStateProperty.all(6),
  //                             thumbVisibility: MaterialStateProperty.all(true),
  //                           ),
  //                         ),
  //                         menuItemStyleData: const MenuItemStyleData(
  //                           height: 40,
  //                           padding: EdgeInsets.only(left: 14, right: 14),
  //                         ),
  //                         validator: (value) {
  //                           if (value == null || value.isEmpty) {
  //                             return 'Please select an option';
  //                           }
  //                           return null;
  //                         },
  //                       ),
  //                     ),
  //                     Text('Due Date',
  //                         style: TextStyle(
  //                             color: blueColor, fontWeight: FontWeight.bold)),
  //                     SizedBox(height: 8.0),
  //                     Material(
  //                       elevation: 3,
  //                       borderRadius: BorderRadius.circular(8.0),
  //                       child: Container(
  //                         height: 45,
  //                         padding: EdgeInsets.symmetric(
  //                             horizontal: 16.0, vertical: 0),
  //                         decoration: BoxDecoration(
  //                           color: Colors.white,
  //                           borderRadius: BorderRadius.circular(8.0),
  //                         ),
  //                         child: TextFormField(
  //                           onTap: () async {
  //                             DateTime? pickedDate = await showDatePicker(
  //                               context: context,
  //                               initialDate: DateTime.now(),
  //                               firstDate: DateTime(2000),
  //                               lastDate: DateTime(2101),
  //                               helpText: "Due Date",
  //                               locale: const Locale('en', 'US'),
  //                               builder: (BuildContext context, Widget? child) {
  //                                 return Theme(
  //                                   data: ThemeData.light().copyWith(
  //                                     colorScheme: const ColorScheme.light(
  //                                       primary: Color.fromRGBO(21, 43, 83,
  //                                           1), // header background color
  //                                       onPrimary:
  //                                           Colors.white, // header text color
  //                                       onSurface: Color.fromRGBO(
  //                                           21, 43, 83, 1), // body text color
  //                                     ),
  //                                     textButtonTheme: TextButtonThemeData(
  //                                       style: TextButton.styleFrom(
  //                                         foregroundColor: Colors.white,
  //                                         backgroundColor: const Color.fromRGBO(
  //                                             21,
  //                                             43,
  //                                             83,
  //                                             1), // button text color
  //                                       ),
  //                                     ),
  //                                   ),
  //                                   child: child!,
  //                                 );
  //                               },
  //                             );
  //
  //                             if (pickedDate != null) {
  //                               String formattedDate =
  //                                   "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
  //                               setState(() {
  //                                 selectedDate.text = formattedDate;
  //                               });
  //                             }
  //                           },
  //                           //  obscureText: widget.obscureText,
  //                           readOnly: true,
  //                           controller: selectedDate,
  //                           decoration: InputDecoration(
  //                             suffixIcon:
  //                                 Icon(Icons.calendar_today, color: blueColor),
  //                             // hintStyle:
  //                             // TextStyle(fontSize: 13, color: blueColor),
  //                             border: InputBorder.none,
  //                             hintText: "dd-mm-yyyy",
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                     /* ElevatedButton(
  //                   onPressed: () async {
  //                     final DateTime? pickedDate = await showDatePicker(
  //                       context: context,
  //                       initialDate: DateTime.now(),
  //                       firstDate: DateTime(2000),
  //                       lastDate: DateTime(2100),
  //                     );
  //                     if (pickedDate != null) {
  //                       selectedDate = pickedDate;
  //                     }
  //                   },
  //                   child: Text(selectedDate == null
  //                       ? 'Select Date'
  //                       : '${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}'),
  //                 ),*/
  //                     SizedBox(height: 16.0),
  //                     Text('Assigned To',
  //                         style: TextStyle(
  //                             color: blueColor, fontWeight: FontWeight.bold)),
  //                     SizedBox(height: 8.0),
  //                     _isLoadingstaff
  //                         ? const Center(
  //                             child: SpinKitFadingCircle(
  //                               color: Colors.black,
  //                               size: 50.0,
  //                             ),
  //                           )
  //                         : Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               DropdownButtonHideUnderline(
  //                                 child: DropdownButtonFormField2<String>(
  //                                   decoration: InputDecoration(
  //                                       border: InputBorder.none),
  //                                   isExpanded: true,
  //                                   hint: const Row(
  //                                     children: [
  //                                       Expanded(
  //                                         child: Text(
  //                                           'Select here',
  //                                           style: TextStyle(
  //                                             fontSize: 14,
  //                                             fontWeight: FontWeight.w400,
  //                                             color: Color(0xFFb0b6c3),
  //                                           ),
  //                                           overflow: TextOverflow.ellipsis,
  //                                         ),
  //                                       ),
  //                                     ],
  //                                   ),
  //                                   items: staffs.keys.map((staffmember_id) {
  //                                     return DropdownMenuItem<String>(
  //                                       value: staffmember_id,
  //                                       child: Text(
  //                                         staffs[staffmember_id]!,
  //                                         style: const TextStyle(
  //                                           fontSize: 14,
  //                                           fontWeight: FontWeight.w400,
  //                                           color: Colors.black87,
  //                                         ),
  //                                         overflow: TextOverflow.ellipsis,
  //                                       ),
  //                                     );
  //                                   }).toList(),
  //                                   value: _selectedstaffId,
  //                                   onChanged: (value) {
  //                                     setState(() {
  //                                       // _selectedUnitId = null;
  //                                       _selectedstaffId = value;
  //                                       _selectedStaffs = staffs[
  //                                           value]; // Store selected rental_adress

  //                                       //StaffId = value.toString();
  //                                       print(
  //                                           'Selected Staffs: $_selectedStaffs');
  //                                       // Fetch units for the selected property
  //                                     });
  //                                   },
  //                                   buttonStyleData: ButtonStyleData(
  //                                     height: 45,
  //                                     width: 160,
  //                                     padding: const EdgeInsets.only(
  //                                         left: 14, right: 14),
  //                                     decoration: BoxDecoration(
  //                                       borderRadius: BorderRadius.circular(6),
  //                                       color: Colors.white,
  //                                     ),
  //                                     elevation: 2,
  //                                   ),
  //                                   iconStyleData: const IconStyleData(
  //                                     icon: Icon(
  //                                       Icons.arrow_drop_down,
  //                                     ),
  //                                     iconSize: 24,
  //                                     iconEnabledColor: Color(0xFFb0b6c3),
  //                                     iconDisabledColor: Colors.grey,
  //                                   ),
  //                                   dropdownStyleData: DropdownStyleData(
  //                                     decoration: BoxDecoration(
  //                                       borderRadius: BorderRadius.circular(6),
  //                                       color: Colors.white,
  //                                     ),
  //                                     scrollbarTheme: ScrollbarThemeData(
  //                                       radius: const Radius.circular(6),
  //                                       thickness: MaterialStateProperty.all(6),
  //                                       thumbVisibility:
  //                                           MaterialStateProperty.all(true),
  //                                     ),
  //                                   ),
  //                                   menuItemStyleData: const MenuItemStyleData(
  //                                     height: 40,
  //                                     padding:
  //                                         EdgeInsets.only(left: 14, right: 14),
  //                                   ),
  //                                   validator: (value) {
  //                                     if (value == null || value.isEmpty) {
  //                                       return 'Please select an option';
  //                                     }
  //                                     return null;
  //                                   },
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                     SizedBox(height: 8.0),
  //                     Text('Photo ',
  //                         style: TextStyle(
  //                             fontSize: 13,
  //                             fontWeight: FontWeight.bold,
  //                             color: blueColor)),
  //                     SizedBox(
  //                       height: 10,
  //                     ),
  //                     SizedBox(height: 8.0),
  //                     Row(
  //                       children: [
  //                         GestureDetector(
  //                           onTap: () {
  //                             _pickImage().then((_) {
  //                               setState(
  //                                   () {}); // Rebuild the widget after selecting the image
  //                             });
  //                           },
  //                           child: Text(
  //                             '+ Add',
  //                             style: TextStyle(color: Colors.green),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                     SizedBox(
  //                       height: 10,
  //                     ),
  //                     _images.isNotEmpty
  //                         ? Row(
  //                             children: [
  //                               Expanded(
  //                                 child: Container(
  //                                   //color: Colors.blue,
  //                                   child: Wrap(
  //                                     spacing:
  //                                         8.0, // Horizontal spacing between items
  //                                     runSpacing:
  //                                         8.0, // Vertical spacing between rows
  //                                     children: List.generate(
  //                                       _images.length,
  //                                       (index) {
  //                                         return Container(
  //                                           // color: Colors.green,
  //                                           width: 85,
  //                                           child: Column(
  //                                             mainAxisAlignment:
  //                                                 MainAxisAlignment.start,
  //                                             crossAxisAlignment:
  //                                                 CrossAxisAlignment.start,
  //                                             children: [
  //                                               Row(
  //                                                 children: [
  //                                                   SizedBox(
  //                                                     width: 60,
  //                                                   ),
  //                                                   GestureDetector(
  //                                                     onTap: () {
  //                                                       setState(() {
  //                                                         _images
  //                                                             .removeAt(index);
  //                                                       });
  //                                                     },
  //                                                     child: Icon(
  //                                                       Icons.close,
  //                                                       color: Colors.grey,
  //                                                     ),
  //                                                   ),
  //                                                 ],
  //                                               ),
  //                                               Row(
  //                                                 mainAxisAlignment:
  //                                                     MainAxisAlignment.start,
  //                                                 crossAxisAlignment:
  //                                                     CrossAxisAlignment.start,
  //                                                 children: [
  //                                                   Container(
  //                                                     // color:Colors.blue,
  //                                                     child: Image.file(
  //                                                       _images[index],
  //                                                       height: 80,
  //                                                       width: 80,
  //                                                       fit: BoxFit.cover,
  //                                                     ),
  //                                                   ),
  //                                                 ],
  //                                               ),
  //                                             ],
  //                                           ),
  //                                         );
  //                                       },
  //                                     ),
  //                                   ),
  //                                 ),
  //                               ),
  //                             ],
  //                           )
  //                         : Center(
  //                             child: Text("No images selected."),
  //                           ),
  //                     SizedBox(height: 16.0),
  //                     Text('Message',
  //                         style: TextStyle(
  //                             color: blueColor, fontWeight: FontWeight.bold)),
  //                     Material(
  //                       elevation: 3,
  //                       borderRadius: BorderRadius.circular(8.0),
  //                       child: Container(
  //                         height: 50,
  //                         padding: EdgeInsets.symmetric(
  //                             horizontal: 16.0, vertical: 0),
  //                         decoration: BoxDecoration(
  //                           color: Colors.white,
  //                           borderRadius: BorderRadius.circular(8.0),
  //                           //border: Border.all(color: blueColor),
  //                           // boxShadow: [
  //                           //   BoxShadow(
  //                           //     color: Colors.black.withOpacity(0.2),
  //                           //     offset: Offset(4, 4),
  //                           //     blurRadius: 3,
  //                           //   ),
  //                           // ],
  //                         ),
  //                         child: TextFormField(
  //                           /*    onTap: ()async{
  //                         final DateTime? pickedDate = await showDatePicker(
  //                           context: context,
  //                           initialDate: DateTime.now(),
  //                           firstDate: DateTime(2000),
  //                           lastDate: DateTime(2100),
  //                         );
  //                         if (pickedDate != null) {
  //                           selectedDate = pickedDate;
  //                         }
  //                       },*/
  //                           //  obscureText: widget.obscureText,
  //                           // readOnly: true,
  //                           //keyboardType: widget.keyboardType,
  //                           /* validator: (value) {
  //                         if (value == null || value.isEmpty) {
  //                           state.validate();
  //                         }
  //                         return null;
  //                       },*/
  //                           controller: message,
  //
  //                           decoration: InputDecoration(
  //                             //  suffixIcon: widget.suffixIcon,
  //                             hintStyle:
  //                                 TextStyle(fontSize: 13, color: blueColor),
  //                             border: InputBorder.none,
  //                             //   hintText: widget.hintText,
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                     SizedBox(height: 16.0),
  //                     Row(
  //                       children: [
  //                         ElevatedButton(
  //                           style: ElevatedButton.styleFrom(
  //                               backgroundColor: blueColor),
  //                           onPressed: () async {
  //                             setState(() {
  //                               isLoading = true;
  //                             });
  //                             SharedPreferences prefs =
  //                                 await SharedPreferences.getInstance();
  //                             String? firstName = prefs.getString("first_name");
  //                             String? lastName = prefs.getString("last_name");
  //                             final DateFormat formatter =
  //                                 DateFormat('yyyy-MM-dd HH:mm:ss');
  //                             String notificationTime =
  //                                 formatter.format(DateTime.now());
  //                             Map<String, dynamic> values = {
  //                               "date":
  //                                   reverseFormatDate(selectedDate.text.trim()),
  //                               "message": message.text.trim(),
  //                               "status": selectedStatus,
  //                               "statusUpdatedBy": "Admin",
  //                               "staffmember_name": _selectedStaffs,
  //                               "staffmember_id": _selectedstaffId,
  //                               "workOrderUpdate_images": _uploadedFileNames!,
  //                               'notificationTime': notificationTime,
  //                             };
  //                             print('normal date ${selectedDate.text.trim()}');
  //                             print(
  //                                 'revers date ${reverseFormatDate(selectedDate.text.trim())}');
  //                             await WorkOrderRepository.updateworkorderSummary(
  //                                     values, widget.workorder_id!)
  //                                 .then((value) {
  //                               setState(() {
  //                                 futureworkorderSummary =
  //                                     WorkOrderRepository.getworkorderSummary(
  //                                         widget.workorder_id!);
  //                               });
  //                             });
  //
  //                             // Save the data and close the dialog
  //                             /*  WorkorderUpdates update = WorkorderUpdates(
  //                                             status: selectedStatus,
  //                                             date: selectedDate,
  //                                             message: message,
  //                                           );*/
  //                             // Here you can handle saving the update data
  //                             // print('Status: ${update.status}');
  //                             // print('Date: ${update.date}');
  //                             // print('Message: ${update.message}');
  //                             Navigator.of(context).pop();
  //                             setState(() {
  //                               isLoading = false;
  //                             }); // Close the dialog
  //                           },
  //                           child: isLoading
  //                               ? Center(
  //                                   child: SpinKitFadingCircle(
  //                                     color: Colors.white,
  //                                     size: 25.0,
  //                                   ),
  //                                 )
  //                               : Text('Save'),
  //                         ),
  //                         TextButton(
  //                           onPressed: () {
  //                             Navigator.of(context).pop(); // Close the dialog
  //                           },
  //                           child: Text(
  //                             'Cancel',
  //                             style: TextStyle(color: blueColor),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }
  Widget _historyNoteBlock({
    required String label,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(height: 1, color: const Color(0xFFDBE0E5)),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7A90),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeFg,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: blueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void showUpdateDialog(BuildContext context) {
    String? selectedStatus;
    TextEditingController message = TextEditingController();
    TextEditingController privateNotes = TextEditingController();
    TextEditingController selectedDate = TextEditingController();
    String dueDateApi = '';
    bool loadingStaff = staffs.isEmpty;
    bool staffFetchStarted = false;

    Future<void> reloadStaff(StateSetter setLocal) async {
      setLocal(() => loadingStaff = true);
      await _loadStaff();
      setLocal(() => loadingStaff = false);
    }

    // Error state variables
    String? assignedError;
    String? dueDateError;
    String? statusError;

    Widget notesField({
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
              Text(
                label,
                style: TextStyle(
                  color: blueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeFg,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
          ),
        ],
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              if (!staffFetchStarted && staffs.isEmpty) {
                staffFetchStarted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  reloadStaff(setState);
                });
              }
              return Scaffold(
                backgroundColor: const Color(0xFFF4F6F9),
                appBar: widget_302_Staff.App_Bar(context: context),
                drawer: CustomDrawerStaff(
                  currentpage: "Work Orders",
                  dropdown: true,
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
                            border:
                                Border.all(color: const Color(0xFFDBE0E5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        //assined and Due date
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Assigned *',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  loadingStaff
                                      ? Container(
                                          height: 50,
                                          margin:
                                              const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              SpinKitFadingCircle(
                                                  color: blueColor, size: 20),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Loading...',
                                                style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        )
                                      : staffs.isEmpty
                                          ? Container(
                                              height: 50,
                                              margin: const EdgeInsets.only(
                                                  top: 8),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      "Couldn't load staff",
                                                      style: TextStyle(
                                                          color:
                                                              Colors.red[400],
                                                          fontSize: 13),
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () =>
                                                        reloadStaff(setState),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.refresh,
                                                            size: 16,
                                                            color: blueColor),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text('Retry',
                                                            style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            DropdownButtonHideUnderline(
                                              child: DropdownButtonFormField2<
                                                  String>(
                                                decoration:
                                                    const InputDecoration(
                                                        border:
                                                            InputBorder.none),
                                                isExpanded: true,
                                                hint: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Select here',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Color(0xFFb0b6c3),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                items: staffs.keys
                                                    .map((staffmember_id) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: staffmember_id,
                                                    child: Text(
                                                      staffs[staffmember_id]!,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Colors.black87,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                value: _selectedstaffId,
                                                onChanged: (value) {
                                                  setState(() {
                                                    // _selectedUnitId = null;
                                                    _selectedstaffId = value;
                                                    _selectedStaffs = staffs[
                                                        value]; // Store selected rental_adress

                                                    //StaffId = value.toString();
                                                    // Fetch units for the selected property
                                                  });
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 50,
                                                  width: 160,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                    color: Colors.white,
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please select an option';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            if (assignedError != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  assignedError!,
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due Date *',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextFormField(
                                      controller: selectedDate,
                                      readOnly: true,
                                      onTap: () async {
                                        DateTime? pickedDate =
                                            await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2101),
                                          locale: const Locale('en', 'US'),
                                          builder: (BuildContext context,
                                              Widget? child) {
                                            return Theme(
                                              data: ThemeData.light().copyWith(
                                                colorScheme: ColorScheme.light(
                                                  primary:
                                                      blueColor, // header background color
                                                  onPrimary: Colors
                                                      .white, // header text color
                                                  onSurface:
                                                      blueColor, // body text color
                                                ),
                                                textButtonTheme:
                                                    TextButtonThemeData(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.white,
                                                    backgroundColor:
                                                        blueColor, // button text color
                                                  ),
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            dueDateApi =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(pickedDate);
                                            selectedDate.text =
                                                Provider.of<DateProvider>(
                                                        context,
                                                        listen: false)
                                                    .formatCurrentDate(
                                                        dueDateApi);
                                          });
                                        }
                                      },
                                      style: TextStyle(
                                          fontSize: 14, color: blueColor),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 14),
                                        hintText: Provider.of<DateProvider>(
                                                context,
                                                listen: false)
                                            .dateFormat
                                            .toLowerCase(),
                                        hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14),
                                        suffixIcon: const Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: Colors.grey),
                                        suffixIconConstraints:
                                            const BoxConstraints(
                                                minWidth: 34, minHeight: 34),
                                      ),
                                    ),
                                  ),
                                  if (dueDateError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        dueDateError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status *',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButtonFormField2<String>(
                                      decoration: const InputDecoration(
                                          border: InputBorder.none),
                                      isExpanded: true,
                                      hint: const Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Select Status',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFFb0b6c3),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: [
                                        'New',
                                        'In Progress',
                                        'On Hold',
                                        'Completed'
                                      ].map((status) {
                                        return DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: selectedStatus,
                                      onChanged: (value) {
                                        selectedStatus = value;
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 50,
                                        width: 160,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          color: Colors.white,
                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData: const IconStyleData(
                                        icon: Icon(Icons.arrow_drop_down),
                                        iconSize: 24,
                                        iconEnabledColor: Color(0xFFb0b6c3),
                                        iconDisabledColor: Colors.grey,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(6),
                                          thickness:
                                              MaterialStateProperty.all(6),
                                          thumbVisibility:
                                              MaterialStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                          const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select an option';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  if (statusError != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        statusError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        notesField(
                          label: 'Public Notes',
                          badgeText: 'VISIBLE TO ALL',
                          badgeBg: const Color(0xFFE7F6EC),
                          badgeFg: const Color(0xFF1F9D55),
                          controller: message,
                          hint: 'Notes visible to all users',
                        ),
                        const SizedBox(height: 20),
                        notesField(
                          label: 'Private Notes',
                          badgeText: 'ADMIN & STAFF ONLY',
                          badgeBg: const Color(0xFFFDF1DD),
                          badgeFg: const Color(0xFFB7791F),
                          controller: privateNotes,
                          hint: 'Notes visible only to admin and staff',
                        ),
                        const SizedBox(height: 20),
                        // Upload Photo Section
                        if (_images.isEmpty)
                          GestureDetector(
                            onTap: () {
                              // Was _pickImage(), which went straight to the
                              // photo gallery - no camera, no video, no
                              // documents. Now the same three-source dialog the
                              // Admin Summary screen uses.
                              _showImageSourceDialog(setState);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300,
                                    style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Icon(Icons.upload,
                                  //     size: 40, color: Colors.grey[600]),
                                  Image.asset(
                                    'assets/icons/Upload.png',
                                    height: 50,
                                    width: 50,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Photos, Videos, or Documents',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Maximum 10 files, 250MB each',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  const Text(
                                    'Supported: .png, .jpg, .jpeg, .gif, .webp, .mp4, .mov, '
                                      '.webm, .m4v',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_images.isEmpty) const SizedBox(height: 16),
                        if (_images.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  // crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                        onTap: () {
                                          _showImageSourceDialog(setState);
                                        },
                                        child: Container(
                                            height: 20,
                                            width: 20,
                                            decoration: BoxDecoration(
                                              color: blueColor,
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              color: Colors.white,
                                              size: 15,
                                            ))),
                                  ],
                                ),
                                const SizedBox(
                                  height: 15,
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 10, right: 10),
                                    child: Wrap(
                                      alignment: WrapAlignment.start,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.start,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: List.generate(_images.length,
                                          (index) {
                                        return Stack(
                                          clipBehavior: Clip.none, //
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(4.0),
                                              child: GestureDetector(
                                                // A picked video showed its generated thumbnail as a flat
                                                // Image.file with no play control and no tap handler, so
                                                // there was no way to play back what had just been
                                                // attached - the Add and Edit screens already did both.
                                                // VideoPlayerDialog takes a local videoFile, so the player
                                                // was there all along, just never opened from here.
                                                onTap: () {
                                                  if (index < isvideo.length &&
                                                      isvideo[index] &&
                                                      index < videofiles.length) {
                                                    showDialog<void>(
                                                      context: context,
                                                      builder: (_) => VideoPlayerDialog(
                                                        videoFile: videofiles[index],
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    border: Border.all(
                                                        color:
                                                            Colors.grey.shade300),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    child: Stack(
                                                      alignment: Alignment.center,
                                                      fit: StackFit.expand,
                                                      children: [
                                                        Image.file(
                                                          _images[index],
                                                          fit: BoxFit.cover,
                                                        ),
                                                        if (index < isvideo.length &&
                                                            isvideo[index])
                                                          const Icon(
                                                            Icons.play_circle_fill,
                                                            color: Colors.white,
                                                            size: 28,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 0, //
                                              right: 0, //
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    // Removed from _images only, which left isvideo,
                                                    // videofiles and _uploadedFileNames one entry longer:
                                                    // later tiles played the wrong clip, and the removed
                                                    // file was still sent on Save, so "remove" did not
                                                    // actually remove anything.
                                                    _images.removeAt(index);
                                                    if (index < isvideo.length) {
                                                      isvideo.removeAt(index);
                                                    }
                                                    if (index < videofiles.length) {
                                                      videofiles.removeAt(index);
                                                    }
                                                    if (index < _uploadedFileNames.length) {
                                                      _uploadedFileNames.removeAt(index);
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black,
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 14,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: blueColor),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: blueColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Clear previous errors
                                  setState(() {
                                    assignedError = null;
                                    dueDateError = null;
                                    statusError = null;
                                  });

                                  // Validate required fields
                                  bool hasErrors = false;

                                  if (_selectedstaffId == null ||
                                      _selectedstaffId!.isEmpty) {
                                    setState(() {
                                      assignedError =
                                          'Please select an assigned staff member';
                                    });
                                    hasErrors = true;
                                  }

                                  if (selectedDate.text.trim().isEmpty) {
                                    setState(() {
                                      dueDateError = 'Please select a due date';
                                    });
                                    hasErrors = true;
                                  }

                                  if (selectedStatus == null ||
                                      selectedStatus!.isEmpty) {
                                    setState(() {
                                      statusError = 'Please select a status';
                                    });
                                    hasErrors = true;
                                  }

                                  if (hasErrors) {
                                    return;
                                  }

                                  setState(() {
                                    isLoading = true;
                                  });

                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();
                                  final DateFormat formatter =
                                      DateFormat('yyyy-MM-dd HH:mm:ss');
                                  String notificationTime =
                                      formatter.format(DateTime.now());

                                  Map<String, dynamic> values = {
                                    "date": dueDateApi,
                                    "message": message.text.trim(),
                                    "public_notes": message.text.trim(),
                                    "private_notes": privateNotes.text.trim(),
                                    "status": selectedStatus,
                                    "statusUpdatedBy": "Admin",
                                    "staffmember_name": _selectedStaffs,
                                    "staffmember_id": _selectedstaffId,
                                    "workOrderUpdate_images":
                                        _uploadedFileNames!,
                                    'notificationTime': notificationTime,
                                  };

                                  try {
                                    await WorkOrderRepository
                                        .updateworkorderSummary(
                                            values, widget.workorder_id!);
                                    _reloadSummary();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to update work order: ${friendlyErrorMessage(e)}')),
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() {
                                        isLoading = false;
                                      });
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: blueColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Save',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
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
                  ),
                ),
                ],
              ),
            );
          },
        );
      },
      ),
    ).then((_) {
      // The update form is a pushed route, so its fields live until it
      // closes; release them once it has.
      message.dispose();
      privateNotes.dispose();
      selectedDate.dispose();
    });
  }

  final labelStyle = const TextStyle(
    color: Colors.grey,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );

  final valueStyle = TextStyle(
    color: blueColor,
    fontWeight: FontWeight.bold,
    fontSize: 13,
  );
  void _showVideoDialog(String videoFile) {
    showDialog(
      context: context,
      builder: (context) {
        return Container(
          child: VideoPlayerDialog(
            videoUrl: videoFile,
          ),
        );
      },
    );
  }
  /// Full-screen, pinch-to-zoom preview for a work order image.
  ///
  /// Thumbnails in the Images section were display-only, so an attachment
  /// could not be read at the size it was uploaded. Mirrors the preview the
  /// Mortgage summary already uses (mortgage_summery.dart): dimmed backdrop,
  /// InteractiveViewer for zoom, and a round close control.
  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (context, u) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, u, error) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Could not load image',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -14,
              right: -14,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  /// Opens the Edit Work Order screen for this work order and reloads the
  /// summary when the edit was saved. Same destination and argument the
  /// work order table uses (Workorder_table.dart), so behaviour matches.
  Future<void> _openEditWorkOrder() async {
    final String? id = widget.workorder_id;
    if (id == null || id.isEmpty) return;
    final dynamic saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResponsiveEditWorkOrder(workorderId: id),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        futureworkorderSummary =
            WorkOrderRepository.getworkorderSummary(id);
      });
    }
  }
}

class PartWidget extends StatelessWidget {
  final PartsandchargeData part;
  final double total;

  PartWidget({required this.part, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            part.account!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatMoney(part.partsPrice ?? 0)} x ${part.partsQuantity}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                formatMoney(part.partsPrice! * part.partsQuantity!),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "${part.description}",
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const Divider(color: Colors.grey),
          /* Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                formatMoney(part.partsPrice! * part.partsQuantity!),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),*/
        ],
      ),
    );
  }

}
