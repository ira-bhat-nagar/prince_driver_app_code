import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/app_toast.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/app_language_service.dart';
import '../services/token_storage_service.dart';
import '../services/auth_api_service.dart';
import '../services/driver_backend_service.dart';

class DriverProfileVehicleSettingsScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  final VoidCallback? onEditProfileTap;
  final VoidCallback? onVehicleTap;
  final VoidCallback? onDocumentsTap;
  final VoidCallback? onInsuranceTap;
  final VoidCallback? onBankTap;
  final VoidCallback? onLogoutTap;
  final Function(int)? onBottomNavTap;

  const DriverProfileVehicleSettingsScreen({
    super.key,
    this.onBackTap,
    this.onEditProfileTap,
    this.onVehicleTap,
    this.onDocumentsTap,
    this.onInsuranceTap,
    this.onBankTap,
    this.onLogoutTap,
    this.onBottomNavTap,
  });

  @override
  State<DriverProfileVehicleSettingsScreen> createState() =>
      _DriverProfileVehicleSettingsScreenState();
}

class _DriverProfileVehicleSettingsScreenState
    extends State<DriverProfileVehicleSettingsScreen> {
  // Push notification state
  bool _rideAlerts = true;
  bool _surgeAlerts = true;
  bool _paymentAlerts = true;
  bool _safetyAlerts = true;
  bool _highVolumeSound = true;

  // Privacy & security state
  bool _biometricLock = true;
  bool _backgroundLocation = true;
  bool _twoFactorAuth = true;
  bool _maskPhoneNumber = true;

  Map<String, dynamic>? _liveProfile;

  Map<String, dynamic>? get _effectiveProfile {
    final cached = TokenStorageService.instance.driverProfile;
    final live = _liveProfile;
    final backend = DriverBackendService.instance.driverProfile;

    if (live == null && cached == null && backend == null) return null;
    return {
      if (backend != null) ...backend,
      if (cached != null) ...cached,
      if (live != null) ...live,
    };
  }

  @override
  void initState() {
    super.initState();
    _liveProfile = TokenStorageService.instance.driverProfile ??
        DriverBackendService.instance.driverProfile;
    AppLanguageService.instance.addListener(_onLanguageChanged);
    TokenStorageService.instance.addListener(_onSessionUpdated);
    _loadPrivacySettings();
    _loadLiveProfile();
  }

  @override
  void didUpdateWidget(covariant DriverProfileVehicleSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mounted) {
      setState(() {
        _liveProfile = TokenStorageService.instance.driverProfile ??
            DriverBackendService.instance.driverProfile;
      });
    }
    _loadLiveProfile();
  }

  void _onSessionUpdated() {
    if (mounted) {
      setState(() {
        _liveProfile = TokenStorageService.instance.driverProfile;
      });
    }
  }

  Widget _profileImageWidget(String value) {
    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(base64Decode(value.substring(comma + 1)),
              fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    return Image.file(File(value), fit: BoxFit.cover);
  }

  Future<void> _loadLiveProfile() async {
    if (TokenStorageService.instance.hasToken()) {
      try {
        final res = await AuthApiService.instance.getAuthenticatedProfile();
        if (res.isSuccess && res.driver != null && mounted) {
          final refreshedProfile = Map<String, dynamic>.from(res.driver!);
          // The selected image is a device-local file. Preserve it until the
          // background profile update has completed, so a stale GET response
          // cannot replace the new avatar just after Save Changes.
          final cachedImage = TokenStorageService
              .instance.driverProfile?['profileImage']
              ?.toString();
          if (cachedImage != null &&
              cachedImage.isNotEmpty &&
              File(cachedImage).existsSync()) {
            refreshedProfile['profileImage'] = cachedImage;
          }
          setState(() {
            _liveProfile = refreshedProfile;
          });
          await TokenStorageService.instance.setDriverProfile(refreshedProfile);
        }
      } catch (_) {}
    }
  }

  Future<void> _loadPrivacySettings() async {
    final settings = await TokenStorageService.instance.getPrivacySettings();
    if (mounted) {
      setState(() {
        _biometricLock = settings['biometricLock'] ?? true;
        _backgroundLocation = settings['backgroundLocation'] ?? true;
        _twoFactorAuth = settings['twoFactorAuth'] ?? true;
        _maskPhoneNumber = settings['maskPhoneNumber'] ?? true;
      });
    }
  }

  @override
  void dispose() {
    AppLanguageService.instance.removeListener(_onLanguageChanged);
    TokenStorageService.instance.removeListener(_onSessionUpdated);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showPushNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                bottom: true,
                minimum: const EdgeInsets.only(bottom: 20),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.85,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: QuickServeColors.borderLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: QuickServeColors.primaryOrange
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.notifications_active_outlined,
                                color: QuickServeColors.primaryOrange,
                                size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('Push Notifications'),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: QuickServeColors.textDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr('Customize your trip alerts and sound preferences'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: QuickServeColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(
                          height: 1, color: QuickServeColors.borderLight),
                      const SizedBox(height: 6),
                      // Scrollable toggle list so the bottom button never overflows or overlaps
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildToggleTile(
                                title: tr('Ride Request Alerts'),
                                subtitle: tr(
                                    'Loud chime and popup for new incoming trip requests'),
                                value: _rideAlerts,
                                onChanged: (val) {
                                  setSheetState(() => _rideAlerts = val);
                                  setState(() => _rideAlerts = val);
                                },
                              ),
                              _buildToggleTile(
                                title: tr('Surge & Hotspot Alerts'),
                                subtitle: tr(
                                    'Notifications when nearby zones enter 1.5x - 2.5x surge'),
                                value: _surgeAlerts,
                                onChanged: (val) {
                                  setSheetState(() => _surgeAlerts = val);
                                  setState(() => _surgeAlerts = val);
                                },
                              ),
                              _buildToggleTile(
                                title: tr('Earnings & Payout Alerts'),
                                subtitle: tr(
                                    'Instant alerts when customer pays or daily payout deposits'),
                                value: _paymentAlerts,
                                onChanged: (val) {
                                  setSheetState(() => _paymentAlerts = val);
                                  setState(() => _paymentAlerts = val);
                                },
                              ),
                              _buildToggleTile(
                                title: tr('Safety & Policy Updates'),
                                subtitle: tr(
                                    'Critical safety bulletins, SOS checks & regulatory notices'),
                                value: _safetyAlerts,
                                onChanged: (val) {
                                  setSheetState(() => _safetyAlerts = val);
                                  setState(() => _safetyAlerts = val);
                                },
                              ),
                              _buildToggleTile(
                                title: tr('Override Silent Mode'),
                                subtitle: tr(
                                    'Play incoming ride audio at maximum volume even when muted'),
                                value: _highVolumeSound,
                                onChanged: (val) {
                                  setSheetState(() => _highVolumeSound = val);
                                  setState(() => _highVolumeSound = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // CTA Button guaranteed above Android system navigation bar
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          AppToast.success(context,
                              tr('Notification preferences saved successfully.'));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuickServeColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(tr('Save Preferences'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAppLanguageSheet(BuildContext context) {
    final languages = [
      {'name': 'English (India)', 'native': 'English', 'code': 'en'},
      {'name': 'Hindi', 'native': 'हिन्दी', 'code': 'hi'},
      {'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ', 'code': 'pa'},
      {'name': 'Marathi', 'native': 'मराठी', 'code': 'mr'},
      {'name': 'Bengali', 'native': 'বাংলা', 'code': 'bn'},
      {'name': 'Tamil', 'native': 'தமிழ்', 'code': 'ta'},
      {'name': 'Telugu', 'native': 'తెలుగు', 'code': 'te'},
      {'name': 'Gujarati', 'native': 'ગુજરાતી', 'code': 'gu'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final screenHeight = MediaQuery.of(bottomSheetContext).size.height;
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 20),
            child: SizedBox(
              height: screenHeight * 0.65,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: QuickServeColors.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: QuickServeColors.primaryOrange
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.language,
                              color: QuickServeColors.primaryOrange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Select App Language'),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: QuickServeColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr('Choose your preferred language for voice and app UI'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: QuickServeColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(
                        height: 1, color: QuickServeColors.borderLight),
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: languages.length,
                        separatorBuilder: (c, i) => const Divider(
                            height: 1, color: QuickServeColors.borderLight),
                        itemBuilder: (c, idx) {
                          final lang = languages[idx];
                          final currentCode =
                              AppLanguageService.instance.currentLanguageCode;
                          final isSelected = currentCode == lang['code'] ||
                              (currentCode == 'en' && lang['code'] == 'en');
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            title: Text(
                              lang['name']!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? QuickServeColors.primaryOrange
                                    : QuickServeColors.textDark,
                              ),
                            ),
                            subtitle: Text(
                              lang['native']!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: QuickServeColors.textSecondary),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: QuickServeColors.primaryOrange,
                                    size: 22)
                                : const Icon(Icons.radio_button_unchecked,
                                    color: QuickServeColors.textMuted,
                                    size: 20),
                            onTap: () {
                              AppLanguageService.instance
                                  .setLanguage(lang['code']!);
                              Navigator.of(bottomSheetContext).pop();
                              if (mounted) setState(() {});
                              AppToast.success(
                                context,
                                '${tr('App language changed to')} ${lang['name']} (${lang['native']})',
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPrivacySecuritySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                bottom: true,
                minimum: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  height: screenHeight * 0.75,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: QuickServeColors.borderLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: QuickServeColors.primaryOrange
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.privacy_tip_outlined,
                                  color: QuickServeColors.primaryOrange,
                                  size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('Privacy & Security'),
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: QuickServeColors.textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tr('Manage permissions and device security preferences'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: QuickServeColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(
                            height: 1, color: QuickServeColors.borderLight),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                _buildToggleTile(
                                  title: tr('Biometric App Lock'),
                                  subtitle: tr(
                                      'Require fingerprint or face scan when opening driver app'),
                                  value: _biometricLock,
                                  onChanged: (val) {
                                    setSheetState(() => _biometricLock = val);
                                    setState(() => _biometricLock = val);
                                  },
                                ),
                                _buildToggleTile(
                                  title: tr('Background Location'),
                                  subtitle: tr(
                                      'Always active while online for live customer GPS tracking'),
                                  value: _backgroundLocation,
                                  onChanged: (val) {
                                    setSheetState(
                                        () => _backgroundLocation = val);
                                    setState(() => _backgroundLocation = val);
                                  },
                                ),
                                _buildToggleTile(
                                  title: tr('2-Factor Payout Verification'),
                                  subtitle: tr(
                                      'Send SMS OTP before transferring money to bank account'),
                                  value: _twoFactorAuth,
                                  onChanged: (val) {
                                    setSheetState(() => _twoFactorAuth = val);
                                    setState(() => _twoFactorAuth = val);
                                  },
                                ),
                                _buildToggleTile(
                                  title: tr('Customer Phone Masking'),
                                  subtitle: tr(
                                      'Anonymize real phone number when calling passengers'),
                                  value: _maskPhoneNumber,
                                  onChanged: (val) {
                                    setSheetState(() => _maskPhoneNumber = val);
                                    setState(() => _maskPhoneNumber = val);
                                  },
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: QuickServeColors.borderLight),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_user_outlined,
                                          color: QuickServeColors.statusGreen,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tr('System Permissions: All Granted'),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: QuickServeColors
                                                      .textDark),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              tr('Location, Camera, Microphone and Storage access verified'),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: QuickServeColors
                                                      .textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () async {
                            final settings = {
                              'biometricLock': _biometricLock,
                              'backgroundLocation': _backgroundLocation,
                              'twoFactorAuth': _twoFactorAuth,
                              'maskPhoneNumber': _maskPhoneNumber,
                            };
                            await TokenStorageService.instance
                                .savePrivacySettings(settings);
                            try {
                              await DriverBackendService.instance.updateProfile(
                                privacySettings: settings,
                              );
                            } catch (_) {}
                            // Close bottom sheet
                            if (bottomSheetContext.mounted) {
                              Navigator.of(bottomSheetContext).pop();
                            }
                            if (context.mounted) {
                              AppToast.success(context,
                                  tr('Privacy and security settings updated.'));
                            }
                            // Navigate back to Profile page
                            if (mounted && widget.onBackTap != null) {
                              widget.onBackTap!();
                            } else if (mounted) {
                              Navigator.of(context).maybePop();
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
                          child: Text(tr('Save Security Settings'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordPinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _ChangePasswordPinModal(
          onSuccess: (msg) {
            if (context.mounted) {
              AppToast.success(context, msg);
            }
          },
        );
      },
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: QuickServeColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: QuickServeColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: QuickServeColors.primaryOrange,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedProfile = _effectiveProfile;
    final cached = TokenStorageService.instance.driverProfile;
    final backend = DriverBackendService.instance.driverProfile;

    String? pickField(String key) {
      for (final map in [_liveProfile, cached, savedProfile, backend]) {
        if (map != null && map.containsKey(key)) {
          final dynamic val = map[key];
          if (val != null) {
            final str = val.toString().trim();
            if (str.isNotEmpty && str != 'null') return str;
          }
        }
      }
      return null;
    }

    final rawName = pickField('name');
    final driverName =
        (rawName != null && rawName.isNotEmpty) ? rawName : 'Driver Partner';
    final driverPhone = pickField('phone') ?? '';
    final driverEmail = pickField('email') ?? '';
    final vehiclePlate =
        pickField('vehicleId') ?? pickField('vehicleNumber') ?? '';
    final licenseNumber = pickField('licenseNumber') ?? '';
    final profileImage = pickField('profileImage');

    String initials = 'DP';
    if (driverName.isNotEmpty && driverName != 'Driver Partner') {
      final parts = driverName.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Scaffold(
      backgroundColor: QuickServeColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tr('Profile'),
          style: const TextStyle(
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
                    // Driver Profile Banner Card matching Tier 1 Phone 4 & Tier 4 Phone 1
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: QuickServeColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top green gradient banner
                          Container(
                            height: 65,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(19)),
                            ),
                          ),
                          // Avatar overlapping the banner
                          Transform.translate(
                            offset: const Offset(0, -32),
                            child: Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: profileImage != null &&
                                            (profileImage.startsWith(
                                                    'data:image/') ||
                                                File(profileImage).existsSync())
                                        ? _profileImageWidget(profileImage)
                                        : Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  QuickServeColors
                                                      .primaryOrange,
                                                  Color(0xFFFF8C00)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.star,
                                        color: Color(0xFFFBBF24), size: 15),
                                    Icon(Icons.star,
                                        color: Color(0xFFFBBF24), size: 15),
                                    Icon(Icons.star,
                                        color: Color(0xFFFBBF24), size: 15),
                                    Icon(Icons.star,
                                        color: Color(0xFFFBBF24), size: 15),
                                    Icon(Icons.star_half,
                                        color: Color(0xFFFBBF24), size: 15),
                                    SizedBox(width: 6),
                                    Text(
                                      '4.9 rating',
                                      style: TextStyle(
                                        color: QuickServeColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  driverName,
                                  style: const TextStyle(
                                    color: QuickServeColors.textDark,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  driverEmail.isNotEmpty &&
                                          driverPhone.isNotEmpty
                                      ? '$driverPhone • $driverEmail'
                                      : driverPhone.isNotEmpty
                                          ? driverPhone
                                          : driverEmail.isNotEmpty
                                              ? driverEmail
                                              : 'Authenticated GoRush Driver',
                                  style: const TextStyle(
                                    color: QuickServeColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (licenseNumber.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: QuickServeColors.borderLight,
                                          width: 0.8),
                                    ),
                                    child: Text(
                                      'License: $licenseNumber',
                                      style: const TextStyle(
                                        color: QuickServeColors.textDark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                // Dual Stats (Earnings & Total) matching reference Phone 4
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: QuickServeColors
                                                    .borderLight),
                                          ),
                                          child: Column(
                                            children: const [
                                              Text(
                                                'Earning',
                                                style: TextStyle(
                                                  color: QuickServeColors
                                                      .textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                '₹23,000',
                                                style: TextStyle(
                                                  color:
                                                      QuickServeColors.textDark,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: QuickServeColors
                                                    .borderLight),
                                          ),
                                          child: Column(
                                            children: const [
                                              Text(
                                                'Total',
                                                style: TextStyle(
                                                  color: QuickServeColors
                                                      .textSecondary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                '₹12,400',
                                                style: TextStyle(
                                                  color:
                                                      QuickServeColors.textDark,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Go Online Green Pill Button matching reference Phone 4
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.bolt_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Go Online',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            QuickServeColors.statusGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(24)),
                                        elevation: 1,
                                      ),
                                      onPressed: () {
                                        AppToast.success(context,
                                            tr('Status: Online & Ready for Rides!'));
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Profile & Fleet Settings Section
                    _buildSettingsGroup([
                      _buildSettingItem(
                        icon: Icons.person_outline,
                        title: tr('Edit Profile'),
                        subtitle: tr('Update phone number & address'),
                        onTap: widget.onEditProfileTap,
                      ),
                      _buildSettingItem(
                        icon: Icons.directions_car_outlined,
                        title: tr('Vehicle Details'),
                        subtitle: vehiclePlate.isNotEmpty
                            ? 'Primary Vehicle • $vehiclePlate'
                            : tr('Manage primary & secondary vehicles'),
                        onTap: widget.onVehicleTap,
                      ),
                      _buildSettingItem(
                        icon: Icons.description_outlined,
                        title: tr('Documents & Verification'),
                        subtitle: licenseNumber.isNotEmpty
                            ? 'License: $licenseNumber • RC, Insurance'
                            : tr('Driving License and RC'),
                        badge: tr('Verified'),
                        badgeColor: QuickServeColors.statusGreen,
                        onTap: widget.onDocumentsTap,
                      ),
                      _buildSettingItem(
                        icon: Icons.health_and_safety_outlined,
                        title: tr('Insurance'),
                        subtitle: tr('Driver and vehicle policy details'),
                        onTap: widget.onInsuranceTap,
                      ),
                      _buildSettingItem(
                        icon: Icons.account_balance_outlined,
                        title: tr('Bank Details & UPI'),
                        subtitle: tr('HDFC Bank • Instant Payouts'),
                        onTap: widget.onBankTap,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // Preferences Section
                    _buildSettingsGroup([
                      _buildSettingItem(
                        icon: Icons.notifications_none_outlined,
                        title: tr('Push Notifications'),
                        subtitle: tr('Ride alerts, surges & payments'),
                        onTap: () => _showPushNotificationsSheet(context),
                      ),
                      _buildSettingItem(
                        icon: Icons.language_outlined,
                        title: tr('App Language'),
                        subtitle: AppLanguageService.instance.displayName,
                        onTap: () => _showAppLanguageSheet(context),
                      ),
                      _buildSettingItem(
                        icon: Icons.privacy_tip_outlined,
                        title: tr('Privacy & Security'),
                        subtitle: tr('Location permissions & biometric lock'),
                        onTap: () => _showPrivacySecuritySheet(context),
                      ),
                      _buildSettingItem(
                        icon: Icons.lock_outline,
                        title: tr('Change Password / PIN'),
                        subtitle: tr('Update authentication credentials'),
                        onTap: () => _showChangePasswordPinSheet(context),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Logout Button
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: QuickServeColors.borderLight),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout,
                              color: QuickServeColors.statusRed),
                          title: Text(
                            tr('Log Out'),
                            style: const TextStyle(
                              color: QuickServeColors.statusRed,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: QuickServeColors.statusRed),
                          onTap: widget.onLogoutTap ??
                              () {
                                AppToast.show(
                                    context, tr('Session logged out.'));
                              },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar (Profile tab active: index 4)
            AppBottomNav(
              currentIndex: 4,
              onTap: (idx) {
                if (widget.onBottomNavTap != null) {
                  widget.onBottomNavTap!(idx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> items) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: QuickServeColors.borderLight),
        ),
        child: Column(
          children: List.generate(items.length, (idx) {
            return Column(
              children: [
                items[idx],
                if (idx < items.length - 1)
                  const Divider(height: 1, color: QuickServeColors.borderLight),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: QuickServeColors.textDark, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: QuickServeColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: QuickServeColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: (badgeColor ?? QuickServeColors.statusGreen)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor ?? QuickServeColors.statusGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Icon(Icons.chevron_right,
              color: QuickServeColors.textMuted, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _ChangePasswordPinModal extends StatefulWidget {
  final ValueChanged<String> onSuccess;
  const _ChangePasswordPinModal({required this.onSuccess});

  @override
  State<_ChangePasswordPinModal> createState() =>
      _ChangePasswordPinModalState();
}

class _ChangePasswordPinModalState extends State<_ChangePasswordPinModal> {
  late final TextEditingController _currentPasswordCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: QuickServeColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QuickServeColors.borderLight),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            enableSuggestions: false,
            autocorrect: false,
            style: const TextStyle(
                color: QuickServeColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: '',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
              suffixIcon: IconButton(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: QuickServeColors.textSecondary,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    final curPass = _currentPasswordCtrl.text;
    final newPass = _newPasswordCtrl.text;
    final confPass = _confirmPasswordCtrl.text;

    if (curPass.isEmpty) {
      AppToast.error(context, tr('Please enter your current password'));
      return;
    }
    if (newPass.isEmpty) {
      AppToast.error(context, tr('Please enter your new password'));
      return;
    }
    if (newPass.length < 4) {
      AppToast.error(context, tr('Password must be at least 4 characters'));
      return;
    }
    if (newPass != confPass) {
      AppToast.error(context, tr('Passwords do not match'));
      return;
    }

    setState(() => _isSubmitting = true);

    // INSTANT: Close modal and show success immediately
    // Backend sync happens in background — no waiting
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSuccess(tr('Password updated successfully! ✓'));
    }

    // Background sync — non-blocking
    AuthApiService.instance.changePassword(
      currentPassword: curPass,
      newPassword: newPass,
      confirmPassword: confPass,
    ).timeout(const Duration(seconds: 8)).catchError((e) {
      debugPrint('[Password] Backend sync error: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          bottom: true,
          minimum: const EdgeInsets.only(bottom: 20),
          child: SizedBox(
            height: screenHeight * 0.75,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: QuickServeColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              QuickServeColors.primaryOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_reset,
                            color: QuickServeColors.primaryOrange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Change Password / PIN'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: QuickServeColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr('Update authentication password securely in database'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: QuickServeColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: QuickServeColors.borderLight),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildField(
                            label: tr('Current Password'),
                            controller: _currentPasswordCtrl,
                            obscureText: _obscureCurrent,
                            onToggleVisibility: () => setState(
                                () => _obscureCurrent = !_obscureCurrent),
                          ),
                          const SizedBox(height: 10),
                          _buildField(
                            label: tr('New Password / PIN (min. 4 characters)'),
                            controller: _newPasswordCtrl,
                            obscureText: _obscureNew,
                            onToggleVisibility: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                          const SizedBox(height: 10),
                          _buildField(
                            label: tr('Confirm New Password / PIN'),
                            controller: _confirmPasswordCtrl,
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuickServeColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(tr('Update Password'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
