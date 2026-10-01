import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/app_toast.dart';
import '../../services/auth_api_service.dart';
import 'package:file_picker/file_picker.dart';

class UploadDocumentsScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBackTap;

  const UploadDocumentsScreen({
    super.key,
    this.onNext,
    this.onBackTap,
  });

  @override
  State<UploadDocumentsScreen> createState() => _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState extends State<UploadDocumentsScreen> {
  Map<String, dynamic>? _vehicleInsuranceDetails;
  // Document states
  final List<Map<String, dynamic>> _documents = [
    {
      'title': 'Profile Photo',
      'key': 'profilePhoto',
      'subtitle': 'Passport size clear photo',
      'status': 'Pending',
      'icon': Icons.account_box_outlined,
    },
    {
      'title': 'Driving License',
      'key': 'drivingLicense',
      'subtitle': 'DL-142011001234 • Front & Back',
      'status': 'Pending',
      'icon': Icons.badge_outlined,
    },
    {
      'title': 'Vehicle RC',
      'key': 'vehicleRc',
      'subtitle': 'Registration Certificate DL 01 AB 1234',
      'status': 'Pending',
      'icon': Icons.directions_car_outlined,
    },
    {
      'title': 'Police Verification',
      'key': 'policeVerification',
      'subtitle': 'Character verification certificate',
      'status': 'Pending',
      'icon': Icons.security_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickOrEditDocument(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.single.name.isEmpty || !mounted) return;

    final document = _documents[index];
    setState(() {
      document['fileName'] = result.files.single.name;
    });
    final saveResult = await AuthApiService.instance.updateProfile(
      documents: {document['key'] as String: result.files.single.name},
    );
    if (!mounted) return;
    if (saveResult.success) {
      AppToast.success(
          context, '${document['title']} saved. You can edit it anytime.');
    } else {
      AppToast.error(context,
          'Selected locally. It will sync when the backend is reachable.');
    }
  }

  Future<void> _editVehicleInsurance() async {
    final details = _vehicleInsuranceDetails ?? {};
    final policyController =
        TextEditingController(text: details['policyNumber'] as String? ?? '');
    final companyController = TextEditingController(
        text: details['insuranceCompany'] as String? ?? '');
    String? fileName = details['documentName'] as String?;
    Uint8List? documentBytes;
    DateTime? startDate = _dateFromValue(details['startDate']);
    DateTime? expiryDate = _dateFromValue(details['expiryDate']);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Vehicle Insurance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
                      withData: true,
                    );
                    final selected = result?.files.single;
                    if (selected != null && selected.name.isNotEmpty) {
                      if (selected.bytes == null ||
                          selected.bytes!.lengthInBytes > 7 * 1024 * 1024) {
                        if (context.mounted) {
                          AppToast.error(context,
                              'Choose an insurance document smaller than 7 MB.');
                        }
                        return;
                      }
                      setDialogState(() {
                        fileName = selected.name;
                        documentBytes = selected.bytes;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(fileName == null
                      ? 'Upload Insurance Document'
                      : fileName!),
                ),
                TextField(
                    controller: policyController,
                    decoration:
                        const InputDecoration(labelText: 'Policy Number')),
                TextField(
                    controller: companyController,
                    decoration:
                        const InputDecoration(labelText: 'Insurance Company')),
                _insuranceDateButton('Start Date', startDate,
                    (date) => setDialogState(() => startDate = date)),
                _insuranceDateButton('Expiry Date', expiryDate,
                    (date) => setDialogState(() => expiryDate = date)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (fileName == null ||
                    policyController.text.trim().isEmpty ||
                    companyController.text.trim().isEmpty ||
                    startDate == null ||
                    expiryDate == null) {
                  AppToast.error(context,
                      'Complete all insurance details and upload the document.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    final updatedDetails = <String, dynamic>{
      'documentName': fileName,
      'policyNumber': policyController.text.trim(),
      'insuranceCompany': companyController.text.trim(),
      'startDate': _dateOnly(startDate!),
      'expiryDate': _dateOnly(expiryDate!),
      // Retain the previous stored document when editing only its details.
      if (documentBytes != null) 'documentData': base64Encode(documentBytes!),
    };
    final result = await AuthApiService.instance.updateProfile(
      documents: {'vehicleInsurance': fileName},
      vehicleInsuranceDetails: updatedDetails,
    );
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _vehicleInsuranceDetails = {
          ...updatedDetails,
          'status':
              expiryDate!.isBefore(DateTime.now()) ? 'Expired' : 'Pending',
        };
        _documents.firstWhere(
            (doc) => doc['key'] == 'vehicleInsurance')['fileName'] = fileName;
      });
      AppToast.success(context,
          'Vehicle Insurance saved. Status: ${_vehicleInsuranceDetails!['status']}.');
    } else {
      AppToast.error(context, result.message);
    }
  }

  DateTime? _dateFromValue(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;

  Widget _insuranceDateButton(
      String label, DateTime? value, ValueChanged<DateTime> onSelected) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (selected != null) onSelected(selected);
        },
        child: Text('$label: ${value == null ? 'Select' : _dateOnly(value)}'),
      ),
    );
  }

  void _handleSubmitDocuments() {
    AppToast.success(
        context, 'Documents submitted for verification. Status: Pending.');
    if (widget.onNext != null) {
      widget.onNext!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuickServeColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Document upload',
          style: TextStyle(
            color: QuickServeColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: QuickServeColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Upload your documents for verification',
                      style: TextStyle(
                        color: QuickServeColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5 Document Cards (Phone 4)
                    ...List.generate(_documents.length, (idx) {
                      final doc = _documents[idx];
                      final isInsurance = doc['key'] == 'vehicleInsurance';
                      final insuranceStatus =
                          _vehicleInsuranceDetails?['status'] as String?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: QuickServeColors.borderLight,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                doc['icon'] as IconData,
                                color: QuickServeColors.textSecondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc['title'] as String,
                                    style: const TextStyle(
                                      color: QuickServeColors.textDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    (doc['fileName'] as String?) ??
                                        doc['subtitle'] as String,
                                    style: const TextStyle(
                                      color: QuickServeColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        insuranceStatus == 'Verified'
                                            ? Icons.verified_outlined
                                            : insuranceStatus == 'Expired'
                                                ? Icons.error_outline
                                                : Icons.pending_outlined,
                                        size: 16,
                                        color: QuickServeColors.textSecondary),
                                    SizedBox(width: 4),
                                    Text(
                                      isInsurance
                                          ? (insuranceStatus ?? 'Pending')
                                          : 'Pending',
                                      style: TextStyle(
                                        color: QuickServeColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: isInsurance
                                      ? _editVehicleInsurance
                                      : () => _pickOrEditDocument(idx),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Edit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSubmitDocuments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuickServeColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Documents',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
