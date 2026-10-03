import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/app_toast.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/driver_backend_service.dart';
import '../services/token_storage_service.dart';
import '../services/ride_service.dart';
import '../services/notification_service.dart';
import '../services/wallet_service.dart';
import '../models/ride_model.dart';

class DriverHomeDashboardScreen extends StatefulWidget {
  final VoidCallback? onSosTap;
  final VoidCallback? onIncomingRequestTap;
  final VoidCallback? onNavigationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onEarningsTap;
  final VoidCallback? onTripsTap;
  final VoidCallback? onIncentivesTap;
  final VoidCallback? onRatingsTap;
  final VoidCallback? onSaathiAiTap;
  final VoidCallback? onChatbotTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onInstantCashOutTap;
  final VoidCallback? onWalletTap;
  final Function(int)? onBottomNavTap;
  final VoidCallback? onLogoutTap;

  const DriverHomeDashboardScreen({
    super.key,
    this.onSosTap,
    this.onIncomingRequestTap,
    this.onNavigationTap,
    this.onProfileTap,
    this.onEarningsTap,
    this.onTripsTap,
    this.onIncentivesTap,
    this.onRatingsTap,
    this.onSaathiAiTap,
    this.onChatbotTap,
    this.onNotificationTap,
    this.onInstantCashOutTap,
    this.onWalletTap,
    this.onBottomNavTap,
    this.onLogoutTap,
  });

  @override
  State<DriverHomeDashboardScreen> createState() =>
      _DriverHomeDashboardScreenState();
}

class _DriverHomeDashboardScreenState extends State<DriverHomeDashboardScreen> {
  // Static variable persists online state across widget rebuilds/navigation
  static bool _persistedOnline = false;
  bool _isOnline = false;
  String? _shownRideId;
  final Set<String> _autoAlertedRideIds = {};

  @override
  void initState() {
    super.initState();
    // Use persisted static state — survives back navigation without backend roundtrip
    _isOnline = _persistedOnline;
    TokenStorageService.instance.addListener(_onProfileChanged);
    RideService.instance.addListener(_onRideServiceChanged);
    WalletService.instance.addListener(_onWalletChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RideService.instance.init();
      WalletService.instance.fetchWallet();
    });
  }

  @override
  void didUpdateWidget(covariant DriverHomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TokenStorageService.instance.removeListener(_onProfileChanged);
    RideService.instance.removeListener(_onRideServiceChanged);
    WalletService.instance.removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onRideServiceChanged() {
    if (!mounted) return;
    setState(() {});
    final ride = RideService.instance.availableRide;
    if (_isOnline &&
        ride != null &&
        ride.rideId != _shownRideId &&
        _autoAlertedRideIds.add(ride.rideId)) {
      unawaited(_showIncomingRideSheet(ride));
    }
  }

  void _onWalletChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setOnlineStatus(bool online) async {
    // INSTANT: update UI immediately — no blocking API wait
    _persistedOnline = online;
    setState(() => _isOnline = online);

    if (online) {
      AppToast.success(context, 'You are Online! Looking for rides...');
      // Backend sync in background (non-blocking)
      RideService.instance.setOnlineStatus(true).catchError((_) {});
      unawaited(NotificationService.instance.showOnlineStatusNotification(isOnline: true));
      // Demo ride arrives automatically after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isOnline) {
          _triggerDemoRideRequest();
        }
      });
    } else {
      AppToast.info(context, 'You are now Offline.');
      RideService.instance.setOnlineStatus(false).catchError((_) {});
      unawaited(NotificationService.instance.stopRideRing());
      unawaited(NotificationService.instance.showOnlineStatusNotification(isOnline: false));
    }
  }

  /// Creates a realistic demo ride and shows it instantly on dashboard
  void _triggerDemoRideRequest() {
    final demoRide = RideModel(
      id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      rideId: 'RIDE_DEMO_${DateTime.now().millisecondsSinceEpoch}',
      status: 'requested',
      passengerName: 'Rahul Sharma',
      passengerPhone: '9876543210',
      passengerRating: 4.8,
      passengerTotalRides: 47,
      passengerAvatar: '',
      vehicleTier: 'Standard',
      pickupAddress: 'Sector 62, Noida, UP',
      pickupArea: 'Sector 62, Noida',
      pickupDistanceAway: '0.8 km away',
      pickupLat: 28.6270,
      pickupLng: 77.3680,
      destinationAddress: 'Connaught Place, New Delhi',
      destinationArea: 'Connaught Place, Delhi',
      destinationLat: 28.6315,
      destinationLng: 77.2167,
      distanceKm: 14.2,
      durationMin: 42,
      otp: '7291',
      baseFare: 60.0,
      distanceFare: 220.0,
      taxes: 40.0,
      totalFare: 320.0,
      driverEarnings: 288.0,
      paymentMethod: 'Cash',
      requestedAt: DateTime.now(),
    );
    unawaited(_showIncomingRideSheet(demoRide));
  }

  Future<void> _fetchAndShowIncomingRide(
      {bool showUnavailableMessage = false}) async {
    try {
      final ride = await RideService.instance
          .fetchAvailableRide()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (ride == null) {
        if (showUnavailableMessage) {
          AppToast.info(context, 'No ride request is available right now.');
        }
        return;
      }
      if (!_autoAlertedRideIds.add(ride.rideId)) return;
      await _showIncomingRideSheet(ride);
    } catch (error) {
      debugPrint('[Dashboard] Ride request check failed: $error');
    }
  }

  Future<void> _showIncomingRideSheet(RideModel ride) async {
    if (_shownRideId == ride.rideId) return;
    _shownRideId = ride.rideId;
    unawaited(NotificationService.instance.playRideRequestRing());
    unawaited(
        NotificationService.instance.showNewRideRequestNotification(ride));

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int secondsLeft = 30;
        bool isAccepting = false;
        Timer? countdownTimer;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (!dialogCtx.mounted) {
                t.cancel();
                return;
              }
              setDialogState(() => secondsLeft--);
              if (secondsLeft <= 0) {
                t.cancel();
                NotificationService.instance.stopRideRing();
                unawaited(RideService.instance.rejectRide(
                  ride.rideId,
                  reason: 'Request timed out',
                ));
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              }
            });

            // Countdown color: green→orange→red
            final timerColor = secondsLeft > 20
                ? const Color(0xFF10B981)
                : secondsLeft > 10
                    ? const Color(0xFFF59E0B)
                    : Colors.red;

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ColoredBox(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'New Ride — ${ride.passengerName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            // Fare chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${ride.totalFare.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 30-second countdown timer circle
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: timerColor.withOpacity(0.15),
                                border:
                                    Border.all(color: timerColor, width: 2.5),
                              ),
                              child: Center(
                                child: Text(
                                  '$secondsLeft',
                                  style: TextStyle(
                                    color: timerColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _rideDetailRow(Icons.circle, Colors.green, 'Pickup',
                                ride.pickupAddress),
                            const SizedBox(height: 8),
                            _rideDetailRow(Icons.location_on, Colors.red,
                                'Drop', ride.destinationAddress),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _chipInfo(
                                    '${ride.distanceKm.toStringAsFixed(1)} km',
                                    Icons.straighten),
                                const SizedBox(width: 10),
                                _chipInfo('~${ride.durationMin} min',
                                    Icons.timer_outlined),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  countdownTimer?.cancel();
                                  NotificationService.instance.stopRideRing();
                                  unawaited(RideService.instance.rejectRide(
                                    ride.rideId,
                                    reason: 'Driver rejected',
                                  ));
                                  Navigator.pop(dialogCtx);
                                  AppToast.info(context, 'Ride declined.');
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('REJECT',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: isAccepting
                                    ? null
                                    : () async {
                                        setDialogState(
                                            () => isAccepting = true);
                                        countdownTimer?.cancel();
                                        NotificationService.instance
                                            .stopRideRing();

                                        // Demo ride: bypass API, navigate directly
                                        if (ride.rideId
                                            .startsWith('RIDE_DEMO_')) {
                                          if (dialogCtx.mounted) {
                                            Navigator.pop(dialogCtx);
                                          }
                                          widget.onIncomingRequestTap?.call();
                                          return;
                                        }

                                        // Real ride: call API
                                        final accepted = await RideService
                                            .instance
                                            .acceptRide(
                                          ride.rideId,
                                          offer: ride,
                                        );
                                        if (!dialogCtx.mounted) return;
                                        if (!accepted) {
                                          setDialogState(
                                              () => isAccepting = false);
                                          AppToast.error(
                                            dialogCtx,
                                            RideService.instance
                                                    .lastActionError ??
                                                'Could not accept ride. Please retry.',
                                          );
                                          return;
                                        }
                                        Navigator.pop(dialogCtx);
                                        widget.onIncomingRequestTap?.call();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: isAccepting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('ACCEPT RIDE',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
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
        );
      },
    ).whenComplete(() {
      if (_shownRideId == ride.rideId) _shownRideId = null;
    });
  }

  Widget _rideDetailRow(
      IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _chipInfo(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuickServeColors.surfaceLight,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. Header: Greeting, Driver ID, Verified Badge, Bell icon
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: widget.onProfileTap,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (ctx) {
                                                  final profile =
                                                      TokenStorageService
                                                              .instance
                                                              .driverProfile ??
                                                          DriverBackendService
                                                              .instance
                                                              .driverProfile;
                                                  final dynamic nameVal =
                                                      profile?['name'];
                                                  final rawName = nameVal
                                                      ?.toString()
                                                      .trim();
                                                  final driverName = (rawName !=
                                                              null &&
                                                          rawName.isNotEmpty &&
                                                          rawName != 'null')
                                                      ? rawName
                                                      : 'Driver Partner';
                                                  final dynamic phoneVal =
                                                      profile?['phone'];
                                                  final rawPhone = phoneVal
                                                      ?.toString()
                                                      .trim();
                                                  final driverId = (rawPhone !=
                                                              null &&
                                                          rawPhone.isNotEmpty &&
                                                          rawPhone != 'null')
                                                      ? rawPhone
                                                      : '81224367641';
                                                  final hour =
                                                      DateTime.now().hour;
                                                  final greeting = hour < 12
                                                      ? 'Good Morning'
                                                      : hour < 17
                                                          ? 'Good Afternoon'
                                                          : 'Good Evening';

                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '$greeting, ',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  QuickServeColors
                                                                      .textDark,
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          Flexible(
                                                            child: Text(
                                                              driverName,
                                                              style:
                                                                  const TextStyle(
                                                                color: QuickServeColors
                                                                    .primaryBlue,
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Wrap(
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        spacing: 6,
                                                        runSpacing: 4,
                                                        children: [
                                                          Text(
                                                            'ID: $driverId',
                                                            style:
                                                                const TextStyle(
                                                              color: QuickServeColors
                                                                  .textSecondary,
                                                              fontSize: 11.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        7,
                                                                    vertical:
                                                                        2),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: QuickServeColors
                                                                  .statusGreenLight,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              border: Border.all(
                                                                  color: QuickServeColors
                                                                      .statusGreen,
                                                                  width: 0.8),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: const [
                                                                Icon(
                                                                    Icons
                                                                        .check_circle,
                                                                    color: QuickServeColors
                                                                        .statusGreen,
                                                                    size: 11),
                                                                SizedBox(
                                                                    width: 3),
                                                                Text(
                                                                  'Verified',
                                                                  style:
                                                                      TextStyle(
                                                                    color: QuickServeColors
                                                                        .statusGreen,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Notification Bell
                                      GestureDetector(
                                        onTap: widget.onNotificationTap,
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: QuickServeColors
                                                        .borderLight),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.04),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                  Icons.notifications_none,
                                                  color:
                                                      QuickServeColors.textDark,
                                                  size: 22),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: QuickServeColors
                                                      .statusRed,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // 2. Blue Hero Earnings Card (Today's Earnings ₹12,400 | Total Rides 18)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2563EB),
                                          Color(0xFF1D4ED8)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB)
                                              .withOpacity(0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Today's Earnings",
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  '₹12,400',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: const [
                                                      Icon(Icons.trending_up,
                                                          color:
                                                              Color(0xFF86EFAC),
                                                          size: 13),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        '+12% vs yesterday',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFF86EFAC),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.15),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                      Icons.directions_car,
                                                      color: Colors.white,
                                                      size: 24),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  '${RideService.instance.earnings.totalRides}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text(
                                                  'Total Rides',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3. 3 Action Quick Circles: Go Online, Navigation, Support
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildActionCircle(
                                        label:
                                            _isOnline ? 'Online' : 'Go Online',
                                        icon: _isOnline
                                            ? Icons.power_settings_new
                                            : Icons.power_off,
                                        bgColor: _isOnline
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFF94A3B8),
                                        onTap: () async {
                                          final target = !_isOnline;
                                          await _setOnlineStatus(target);
                                        },
                                      ),
                                      _buildActionCircle(
                                        label: 'Navigation',
                                        icon: Icons.navigation_rounded,
                                        bgColor: const Color(0xFF2563EB),
                                        onTap: widget.onNavigationTap,
                                      ),
                                      _buildActionCircle(
                                        label: 'Support',
                                        icon: Icons.headset_mic_rounded,
                                        bgColor: const Color(0xFF8B5CF6),
                                        onTap: widget.onSaathiAiTap,
                                      ),
                                    ],
                                  ),

                                  // 4. Verification Successful Card Banner
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDCFCE7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.verified_user,
                                              color: Color(0xFF15803D),
                                              size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'Verification Successful!',
                                                style: TextStyle(
                                                  color: Color(0xFF15803D),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 1),
                                              Text(
                                                'Your account has been verified and you are ready to accept rides.',
                                                style: TextStyle(
                                                  color: Color(0xFF166534),
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right,
                                            color: Color(0xFF15803D), size: 18),
                                      ],
                                    ),
                                  ),

                                  // 5. 4 Metrics Grid (2x2) — all clickable
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: widget.onTripsTap,
                                              child: _buildMetricTile(
                                                title: 'Total Rides',
                                                value: '18',
                                                icon: Icons.local_taxi_outlined,
                                                iconColor:
                                                    const Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: widget.onEarningsTap,
                                              child: _buildMetricTile(
                                                title: 'Online Time',
                                                value: '6h 24m',
                                                icon: Icons.access_time_rounded,
                                                iconColor:
                                                    const Color(0xFF10B981),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: widget.onEarningsTap,
                                              child: _buildMetricTile(
                                                title: 'Avg. Rating',
                                                value: '4.8 ★',
                                                icon:
                                                    Icons.star_outline_rounded,
                                                iconColor:
                                                    const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: widget.onWalletTap,
                                              child: _buildMetricTile(
                                                title: 'Total Earnings',
                                                value: '₹23,600',
                                                icon: Icons
                                                    .account_balance_wallet_outlined,
                                                iconColor:
                                                    const Color(0xFF6366F1),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // 5.5 Wallet Balance Card
                                  Builder(builder: (ctx) {
                                    final wallet =
                                        WalletService.instance.wallet;
                                    final hasLowBalance =
                                        WalletService.instance.hasLowBalance;
                                    final balance = wallet?.balance ?? 0.0;
                                    final minBal = WalletService
                                        .instance.minimumWalletBalance;
                                    return GestureDetector(
                                      onTap: widget.onWalletTap,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: hasLowBalance
                                              ? const Color(0xFFFFF7ED)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: hasLowBalance
                                                  ? const Color(0xFFFB923C)
                                                  : QuickServeColors
                                                      .borderLight,
                                              width: hasLowBalance ? 1.5 : 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.02),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: hasLowBalance
                                                    ? const Color(0xFFFFF3CD)
                                                    : const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                hasLowBalance
                                                    ? Icons.warning_rounded
                                                    : Icons
                                                        .account_balance_wallet_outlined,
                                                color: hasLowBalance
                                                    ? const Color(0xFFF59E0B)
                                                    : QuickServeColors
                                                        .primaryBlue,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    hasLowBalance
                                                        ? 'Low Wallet Balance!'
                                                        : 'My Wallet',
                                                    style: TextStyle(
                                                      color: hasLowBalance
                                                          ? const Color(
                                                              0xFFD97706)
                                                          : QuickServeColors
                                                              .textDark,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    hasLowBalance
                                                        ? 'Balance ₹${balance.toStringAsFixed(0)} · Min ₹${minBal.toStringAsFixed(0)} required'
                                                        : '₹${balance.toStringAsFixed(0)} available',
                                                    style: TextStyle(
                                                      color: hasLowBalance
                                                          ? const Color(
                                                              0xFFD97706)
                                                          : QuickServeColors
                                                              .textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: hasLowBalance
                                                    ? const Color(0xFFF59E0B)
                                                    : QuickServeColors
                                                        .primaryBlue,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                hasLowBalance
                                                    ? 'Add Money'
                                                    : 'View >',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  // 6. Instant Cash Out Card
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: QuickServeColors.borderLight),
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
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                              Icons.payments_outlined,
                                              color:
                                                  QuickServeColors.primaryBlue,
                                              size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'Instant Cash Out',
                                                style: TextStyle(
                                                  color:
                                                      QuickServeColors.textDark,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 1),
                                              Text(
                                                'Get your earnings instantly',
                                                style: TextStyle(
                                                  color: QuickServeColors
                                                      .textSecondary,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              widget.onInstantCashOutTap ??
                                                  widget.onEarningsTap,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                QuickServeColors.primaryBlue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 7),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          child: const Text('Withdraw >',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 7. Compatibility quick actions (Emergency SOS & Support Hub)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: widget.onSosTap,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 7, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFFECACA)),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.shield_outlined,
                                                    color: QuickServeColors
                                                        .statusRed,
                                                    size: 15),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Emergency SOS',
                                                  style: TextStyle(
                                                    color: QuickServeColors
                                                        .statusRed,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: widget.onSaathiAiTap,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 7, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: QuickServeColors
                                                      .borderLight),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.support_agent,
                                                    color: QuickServeColors
                                                        .primaryBlue,
                                                    size: 15),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Support Hub',
                                                  style: TextStyle(
                                                    color: QuickServeColors
                                                        .textDark,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // 8. Bottom Status Banner — tap to re-show sheet (no re-ring)
                                  InkWell(
                                    onTap: _isOnline
                                        ? () => _fetchAndShowIncomingRide(
                                              showUnavailableMessage: true,
                                            )
                                        : () async {
                                            await _setOnlineStatus(true);
                                          },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: _isOnline
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: _isOnline
                                                ? const Color(0xFFBFDBFE)
                                                : QuickServeColors.borderLight),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isOnline &&
                                                    RideService.instance
                                                            .availableRide !=
                                                        null
                                                ? Icons.notifications_active
                                                : (_isOnline
                                                    ? Icons.search
                                                    : Icons.power_off),
                                            color: _isOnline
                                                ? QuickServeColors.primaryBlue
                                                : QuickServeColors
                                                    .textSecondary,
                                            size: 17,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _isOnline
                                                  ? (RideService.instance
                                                              .availableRide !=
                                                          null
                                                      ? 'Ride Request Available! Tap to view'
                                                      : 'You are online • Searching for rides')
                                                  : 'You are Offline • Tap Go Online to receive ride requests',
                                              style: TextStyle(
                                                color: _isOnline
                                                    ? QuickServeColors
                                                        .primaryBlue
                                                    : QuickServeColors
                                                        .textSecondary,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            color: _isOnline
                                                ? QuickServeColors.primaryBlue
                                                : QuickServeColors
                                                    .textSecondary,
                                            size: 11,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Navigation (Home Tab Active: Index 0)
                AppBottomNav(
                  currentIndex: 0,
                  onTap: (idx) {
                    if (widget.onBottomNavTap != null) {
                      widget.onBottomNavTap!(idx);
                    }
                  },
                ),
              ],
            ),
            // Modern Floating Chatbot Button at Bottom-Right
            Positioned(
              bottom: 74,
              right: 16,
              child: _buildFloatingChatbotButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingChatbotButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onChatbotTap ?? widget.onSaathiAiTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.40),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 25,
              ),
              Positioned(
                top: 13,
                right: 13,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle({
    required String label,
    required IconData icon,
    required Color bgColor,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(0.25),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: QuickServeColors.textDark,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuickServeColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: QuickServeColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: const TextStyle(
                    color: QuickServeColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
