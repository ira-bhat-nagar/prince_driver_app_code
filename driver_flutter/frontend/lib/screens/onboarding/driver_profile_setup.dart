import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/app_toast.dart';
import '../../services/app_language_service.dart';
import '../../services/token_storage_service.dart';
import '../../services/auth_api_service.dart';
import '../../services/driver_backend_service.dart';
import 'driver_login_registration.dart'; // for OtpSession

class DriverProfileSetupScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBackTap;
  final bool isEditing;
  final VoidCallback? onSave;

  const DriverProfileSetupScreen({
    super.key,
    this.onNext,
    this.onBackTap,
    this.isEditing = false,
    this.onSave,
  });

  @override
  State<DriverProfileSetupScreen> createState() =>
      _DriverProfileSetupScreenState();
}

class _DriverProfileSetupScreenState extends State<DriverProfileSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _dobController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;

  final ImagePicker _imagePicker = ImagePicker();

  // A local file path is retained so the selected image continues to show
  // when this screen is opened again on the same device.
  String? _photoSource; // 'camera' or 'document'
  String? _photoPath;
  String? _documentName;

  @override
  void initState() {
    super.initState();
    final savedProfile = TokenStorageService.instance.driverProfile ??
        DriverBackendService.instance.driverProfile;
    final defaultName = (savedProfile?['name'] as String?)?.trim() ?? '';
    // Auto-fill phone from OTP session (registration number)
    final sessionPhone = OtpSession.phoneNumber.isNotEmpty
        ? OtpSession.phoneNumber
        : (savedProfile?['phone'] as String?)?.trim() ?? '';
    final defaultEmail = (savedProfile?['email'] as String?)?.trim() ?? '';
    final defaultCity =
        (savedProfile?['city'] as String?)?.trim() ?? 'Noida & Delhi NCR';
    final defaultAddress = (savedProfile?['address'] as String?)?.trim() ??
        'Sector 62, Noida, Uttar Pradesh - 201309';

    _nameController = TextEditingController(text: defaultName);
    _phoneController = TextEditingController(text: sessionPhone);
    _emailController = TextEditingController(text: defaultEmail);
    _dobController = TextEditingController(text: '12-05-1995');
    _cityController = TextEditingController(text: defaultCity);
    _addressController = TextEditingController(text: defaultAddress);
    final savedPhoto = savedProfile?['profileImage'] as String?;
    if (savedPhoto != null &&
        savedPhoto.isNotEmpty &&
        (savedPhoto.startsWith('data:image/') ||
            File(savedPhoto).existsSync())) {
      _photoPath = savedPhoto;
      _photoSource = 'document';
    }
    _documentName = savedProfile?['profileDocumentName'] as String?;
    AppLanguageService.instance.addListener(_onLangChange);
    TokenStorageService.instance.addListener(_onSessionUpdated);

    if (widget.isEditing || TokenStorageService.instance.hasToken()) {
      _loadLiveDriverData();
    }
  }

  void _onSessionUpdated() {
    if (!mounted) return;
    final p = TokenStorageService.instance.driverProfile ??
        DriverBackendService.instance.driverProfile;
    if (p == null) return;
    final n = (p['name'] as String?)?.trim();
    final ph = (p['phone'] as String?)?.trim();
    final em = (p['email'] as String?)?.trim();
    final c = (p['city'] as String?)?.trim();
    final a = (p['address'] as String?)?.trim();

    if (n != null && n.isNotEmpty) _nameController.text = n;
    if (ph != null && ph.isNotEmpty) _phoneController.text = ph;
    if (em != null && em.isNotEmpty) _emailController.text = em;
    if (c != null && c.isNotEmpty) _cityController.text = c;
    if (a != null && a.isNotEmpty) _addressController.text = a;
    setState(() {});
  }

  Future<void> _loadLiveDriverData() async {
    try {
      final res = await AuthApiService.instance.getAuthenticatedProfile();
      if (res.isSuccess && res.driver != null && mounted) {
        final d = res.driver!;
        if ((d['name'] as String?)?.isNotEmpty == true) {
          _nameController.text = d['name'];
        }
        if ((d['phone'] as String?)?.isNotEmpty == true) {
          _phoneController.text = d['phone'];
        }
        if ((d['email'] as String?)?.isNotEmpty == true) {
          _emailController.text = d['email'];
        }
        if ((d['city'] as String?)?.isNotEmpty == true) {
          _cityController.text = d['city'];
        }
        if ((d['address'] as String?)?.isNotEmpty == true) {
          _addressController.text = d['address'];
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    AppLanguageService.instance.removeListener(_onLangChange);
    TokenStorageService.instance.removeListener(_onSessionUpdated);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onLangChange() {
    if (mounted) setState(() {});
  }

  void _showQuickFeedback(String message) {
    if (!mounted) return;
    AppToast.info(context, message);
  }

  Future<void> _saveSelectedMedia({
    required String path,
    required String source,
    String? documentName,
  }) async {
    if (!mounted) return;
    setState(() {
      _photoPath = path;
      _photoSource = source;
      _documentName = documentName;
    });
    await TokenStorageService.instance.updateProfile(
      profileImage: path,
      profileDocumentName: documentName,
    );
  }

  Future<String?> _profileImageUploadValue() async {
    final path = _photoPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    final extension = path.split('.').last.toLowerCase();
    final mimeType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Widget _selectedPhotoWidget() {
    final path = _photoPath;
    if (path == null || path.isEmpty) return const SizedBox.shrink();
    if (path.startsWith('data:image/')) {
      final comma = path.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(base64Decode(path.substring(comma + 1)),
              fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (photo == null) return;
      await _saveSelectedMedia(path: photo.path, source: 'camera');
      _showQuickFeedback(
          'Photo captured successfully. Tap Save Changes to finish.');
    } catch (_) {
      _showQuickFeedback(
          'Camera could not be opened. Please allow camera permission and try again.');
    }
  }

  Future<void> _pickDocumentOrPicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      final file = result?.files.single;
      if (file == null || file.path == null) return;

      final isImage = const ['jpg', 'jpeg', 'png', 'webp']
          .contains((file.extension ?? '').toLowerCase());
      if (!isImage) {
        if (!mounted) return;
        setState(() {
          _documentName = file.name;
          _photoSource = 'document';
        });
        await TokenStorageService.instance
            .updateProfile(profileDocumentName: file.name);
        _showQuickFeedback('Document "${file.name}" selected successfully.');
        return;
      }

      await _saveSelectedMedia(
        path: file.path!,
        source: 'document',
        documentName: file.name,
      );
      _showQuickFeedback(
          'Picture uploaded successfully. Tap Save Changes to finish.');
    } catch (_) {
      _showQuickFeedback('File picker could not be opened. Please try again.');
    }
  }

  Future<void> _selectDateOfBirth() async {
    DateTime initial = DateTime(1995, 5, 12);
    try {
      final parts = _dobController.text.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        initial = DateTime(y, m, d);
      }
    } catch (_) {}

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: QuickServeColors.primaryOrange,
              onPrimary: Colors.white,
              onSurface: QuickServeColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        _dobController.text = '$day-$month-$year';
      });
      _showQuickFeedback('Date of Birth updated: $day-$month-$year');
    }
  }

  void _handleChangePhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Change Profile Photo',
                      style: TextStyle(
                        color: QuickServeColors.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: QuickServeColors.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Option 1: Working Camera
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: QuickServeColors.primaryOrangeLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: QuickServeColors.primaryOrange, size: 22),
                  ),
                  title: const Text('Camera (Take Photo)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Capture a new live photo using camera',
                      style: TextStyle(
                          fontSize: 12, color: QuickServeColors.textSecondary)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _takePhoto();
                  },
                ),
                const Divider(height: 1, color: QuickServeColors.borderLight),

                // Option 2: Working Upload Document / Picture
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F8EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.upload_file_rounded,
                        color: QuickServeColors.statusGreen, size: 22),
                  ),
                  title: const Text('Upload Document / Picture',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text(
                      'Select photo document from device storage',
                      style: TextStyle(
                          fontSize: 12, color: QuickServeColors.textSecondary)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickDocumentOrPicture();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.isEditing ? tr('Edit Profile') : tr('Complete Your Profile'),
          style: const TextStyle(
              color: QuickServeColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: QuickServeColors.borderLight),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Centered Avatar matching Image 1 (Phone 4 / Share Profile)
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _photoSource != null
                                  ? QuickServeColors.statusGreen
                                  : QuickServeColors.primaryOrange,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _photoPath != null &&
                                    (_photoPath!.startsWith('data:image/') ||
                                        File(_photoPath!).existsSync())
                                ? _selectedPhotoWidget()
                                : _photoSource == 'document'
                                    ? Container(
                                        color: const Color(0xFFE8F8EE),
                                        child: Icon(
                                          _documentName != null
                                              ? Icons.description_rounded
                                              : Icons.account_box_rounded,
                                          color: QuickServeColors.statusGreen,
                                          size: 52,
                                        ),
                                      )
                                    : Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              QuickServeColors.primaryOrange,
                                              Color(0xFFFF8C00)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _nameController.text
                                                    .trim()
                                                    .isNotEmpty
                                                ? _nameController.text
                                                    .trim()
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'D',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _handleChangePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _photoSource != null
                                    ? QuickServeColors.statusGreen
                                    : QuickServeColors.primaryOrange,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                _photoSource != null
                                    ? Icons.check
                                    : Icons.camera_alt,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _handleChangePhoto,
                      child: Text(
                        _photoSource != null
                            ? tr('Photo Updated • Change')
                            : tr('Share Profile'),
                        style: TextStyle(
                          color: _photoSource != null
                              ? QuickServeColors.statusGreen
                              : QuickServeColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Strictly 1 single box per field, exactly identical to Bank Details (First Image)
              _buildField(
                tr('Full Name'),
                _nameController,
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 8),
              _buildField(
                tr('Phone Number'),
                _phoneController,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                readOnly: true, // auto-filled from registration
              ),
              const SizedBox(height: 8),
              _buildField(
                tr('Email Address'),
                _emailController,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              _buildField(
                tr('Date of Birth'),
                _dobController,
                prefixIcon: Icons.calendar_today_outlined,
                isDateOfBirth: true,
                onTap: _selectDateOfBirth,
              ),
              const SizedBox(height: 8),
              _buildField(
                tr('City / Operational Hub'),
                _cityController,
                prefixIcon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 8),
              _buildField(
                tr('Permanent Address'),
                _addressController,
                prefixIcon: Icons.home_outlined,
              ),

              const SizedBox(height: 14),

              ElevatedButton(
                onPressed: () async {
                  if (widget.isEditing) {
                    final name = _nameController.text.trim();
                    final phone = _phoneController.text.trim();
                    final email = _emailController.text.trim();
                    final city = _cityController.text.trim();
                    final address = _addressController.text.trim();

                    if (name.isEmpty) {
                      AppToast.error(
                          context, tr('Please enter your full name'));
                      return;
                    }

                    final profileImageUpload = await _profileImageUploadValue();

                    // INSTANT: Save locally first
                    await TokenStorageService.instance.updateProfile(
                      name: name,
                      phone: phone,
                      email: email,
                      city: city,
                      address: address,
                      profileImage: _photoPath,
                    );

                    // Show success toast — stay on same screen, no navigation
                    if (context.mounted) {
                      AppToast.success(
                          context, tr('Profile updated successfully!'));
                    }

                    // NO navigate away — user stays on profile screen

                    // Backend sync in background — non-blocking
                    DriverBackendService.instance.updateProfile(
                      name: name,
                      phone: phone,
                      email: email,
                      city: city,
                      address: address,
                      profileImage: profileImageUpload,
                    ).then((result) {
                      if (result.driver != null) {
                        TokenStorageService.instance
                            .setDriverProfile(result.driver!);
                      }
                    }).catchError((e) {
                      debugPrint('[Profile] Backend sync error: $e');
                    });
                  } else {
                    final name = _nameController.text.trim();
                    final phone = _phoneController.text.trim();
                    final email = _emailController.text.trim();
                    final city = _cityController.text.trim();
                    final address = _addressController.text.trim();
                    if (name.isEmpty) {
                      AppToast.error(context, tr('Please enter your full name'));
                      return;
                    }
                    // Update the in-memory profile synchronously, persist in the
                    // background, and let onboarding continue without waiting
                    // for disk I/O or a backend round trip.
                    TokenStorageService.instance
                        .updateProfile(
                          name: name,
                          phone: phone,
                          email: email,
                          city: city,
                          address: address,
                        )
                        .catchError((error) {
                      debugPrint('[Profile] Local profile save error: $error');
                      return false;
                    });
                    if (widget.onNext != null) {
                      widget.onNext!();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuickServeColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isEditing
                          ? tr('Save Changes')
                          : tr('Submit Documents'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.isEditing
                          ? Icons.check_circle_outline
                          : Icons.arrow_forward,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  /// ONE SINGLE BOX PER FIELD (ek hi box mein, jaise Bank Details me hai)
  /// Explicitly removes all inner OutlineInputBorder from Theme to guarantee zero double boxes
  Widget _buildField(
    String label,
    TextEditingController controller, {
    required IconData prefixIcon,
    bool isDateOfBirth = false,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: QuickServeColors.textDark,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: QuickServeColors.borderLight, width: 1),
            ),
            child: Row(
              children: [
                Icon(prefixIcon,
                    color: QuickServeColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: isDateOfBirth
                      ? Text(
                          controller.text,
                          style: const TextStyle(
                            color: QuickServeColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : TextField(
                          controller: controller,
                          keyboardType: keyboardType,
                          readOnly: readOnly,
                          style: TextStyle(
                            color: readOnly
                                ? QuickServeColors.textSecondary
                                : QuickServeColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                ),
                if (isDateOfBirth)
                  IconButton(
                    icon: const Icon(Icons.calendar_month_rounded,
                        color: QuickServeColors.primaryOrange, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onTap,
                  )
                else
                  const Icon(Icons.check_circle,
                      color: QuickServeColors.statusGreen, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
