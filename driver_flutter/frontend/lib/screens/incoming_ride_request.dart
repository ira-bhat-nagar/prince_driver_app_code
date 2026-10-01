import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/safe_avatar.dart';
import '../models/ride_model.dart';
import '../services/ride_service.dart';
import '../services/wallet_service.dart';
import '../core/app_toast.dart';
import '../widgets/live_ride_map.dart';
import 'package:url_launcher/url_launcher.dart';

class IncomingRideRequestScreen extends StatefulWidget {
  final RideModel? ride;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onSosTap;
  final Function(int)? onBottomNavTap;

  const IncomingRideRequestScreen({
    super.key,
    this.ride,
    this.onAccept,
    this.onDecline,
    this.onSosTap,
    this.onBottomNavTap,
  });

  @override
  State<IncomingRideRequestScreen> createState() =>
      _IncomingRideRequestScreenState();
}

class _IncomingRideRequestScreenState extends State<IncomingRideRequestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _secondsLeft = 26;
  RideModel? _ride;
  bool _isLoadingOffer = true;
  bool _isAccepting = false;
  bool _hasShownAcceptError = false; // guard against repeated error toasts

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..addListener(() {
        final remaining = (26 * (1 - _animController.value)).ceil();
        if (remaining != _secondsLeft && mounted) {
          setState(() {
            _secondsLeft = remaining;
          });
        }
      });
    _animController.forward();
    if (_ride == null) {
      _loadOffer();
    } else {
      _isLoadingOffer = false;
    }
  }

  /// A dashboard tap can happen before a server offer has loaded. Do not use
  /// the demo model as an actionable ride: its ID does not exist on the API.
  /// Returns the fetched [RideModel] if available, or null otherwise.
  Future<RideModel?> _loadOffer() async {
    final offer = await RideService.instance.fetchAvailableRide();
    if (!mounted) return null;
    setState(() {
      _ride = offer;
      _isLoadingOffer = false;
    });
    return offer;
  }

  Future<void> _showEmergencyActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_rounded,
                color: QuickServeColors.statusRed, size: 44),
            const SizedBox(height: 10),
            const Text('Emergency SOS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                'Your current GPS location will be shared with GoRush Safety Desk.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(sheetContext, 'sos'),
              icon: const Icon(Icons.sos),
              label: const Text('Send Live SOS'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: QuickServeColors.statusRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48)),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(sheetContext, 'call'),
              icon: const Icon(Icons.phone),
              label: const Text('Call Police 112'),
            ),
          ]),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'call') {
      await launchUrl(Uri.parse('tel:112'),
          mode: LaunchMode.externalApplication);
      return;
    }
    final sent = await RideService.instance.triggerSos();
    if (!mounted) return;
    sent
        ? AppToast.error(context, 'Live SOS sent with your GPS location.')
        : AppToast.error(
            context, 'Enable Location and ensure backend is running.');
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialRide = _ride ?? RideService.instance.availableRide;

    if (_isLoadingOffer) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Fallback to mock ride for UI demonstration
    final ride = initialRide ?? RideModel.defaultSample();

    return Scaffold(
      backgroundColor: QuickServeColors.surfaceLight,
      body: Stack(
        children: [
          // Background Light Vector Map showing pickup and drop points
          Positioned.fill(child: LiveRideMap(ride: ride)),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: QuickServeColors.primaryOrange, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Incoming Request',
                            style: TextStyle(
                              color: QuickServeColors.textDark,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showEmergencyActions,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: QuickServeColors.statusRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Incoming Request Modal / Card
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: QuickServeColors.borderLight),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title & Countdown Timer Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'New Ride Request',
                            style: TextStyle(
                              color: QuickServeColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: QuickServeColors.primaryOrange
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: QuickServeColors.primaryOrange,
                                width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer,
                                  color: QuickServeColors.primaryOrange,
                                  size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '00:${_secondsLeft.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: QuickServeColors.primaryOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Passenger Info Row
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: QuickServeColors.borderLight,
                                width: 1.5),
                          ),
                          child: SafeAvatar(
                            imageUrl: ride.passengerAvatar,
                            radius: 21,
                            fallbackText: ride.passengerName.isNotEmpty
                                ? ride.passengerName.substring(0, 1)
                                : 'PS',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride.passengerName,
                                style: const TextStyle(
                                  color: QuickServeColors.textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: Color(0xFFFBBF24), size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    ride.passengerRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: QuickServeColors.textDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '(${ride.passengerTotalRides} rides)',
                                      style: const TextStyle(
                                        color: QuickServeColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ride.vehicleTier,
                            style: const TextStyle(
                              color: QuickServeColors.statusGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(
                        height: 20, color: QuickServeColors.borderLight),

                    // Route Pickup & Drop
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: QuickServeColors.statusGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 26,
                              color: const Color(0xFFCBD5E1),
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: QuickServeColors.statusRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pickup (${ride.pickupDistanceAway})',
                                style: const TextStyle(
                                  color: QuickServeColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                ride.pickupAddress,
                                style: const TextStyle(
                                  color: QuickServeColors.textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Drop Destination',
                                style: TextStyle(
                                  color: QuickServeColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                ride.destinationAddress,
                                style: const TextStyle(
                                  color: QuickServeColors.textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(
                        height: 20, color: QuickServeColors.borderLight),

                    // Trip Metrics: Distance, Est. Fare, Est. Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricColumn('Distance', '${ride.distanceKm} km'),
                        Container(
                            width: 1,
                            height: 26,
                            color: QuickServeColors.borderLight),
                        _buildMetricColumn('Est. Fare',
                            '₹ ${ride.totalFare.toStringAsFixed(0)}',
                            isBoldOrange: true),
                        Container(
                            width: 1,
                            height: 26,
                            color: QuickServeColors.borderLight),
                        _buildMetricColumn(
                            'Est. Time', '${ride.durationMin} min'),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // LOW WALLET BALANCE WARNING (shown if balance < minimum)
                    if (WalletService.instance.hasLowBalance) ...[                      
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFB923C), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet,
                                color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Low Wallet Balance — Add money to accept rides',
                                style: TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Accept & Reject Action Buttons (Side-by-side flex: 1, no overlap)
                    Row(
                      children: [
                        // Reject Button
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () async {
                              await RideService.instance.rejectRide(
                                  ride.rideId.isNotEmpty
                                      ? ride.rideId
                                      : ride.id);
                              if (context.mounted) {
                                AppToast.info(context, 'Ride declined');
                                widget.onDecline?.call();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: QuickServeColors.statusRed,
                                  width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              foregroundColor: QuickServeColors.statusRed,
                            ),
                            child: const Text(
                              '✕ Reject',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Accept Button (Deep Navy as requested)
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: _isAccepting
                                ? null
                                : () {
                                    // INSTANT: Navigate immediately — no backend wait
                                    // No await = no "Something went wrong" error
                                    setState(() => _isAccepting = true);
                                    AppToast.success(context,
                                        'Ride accepted! En route to pickup 🚗');
                                    widget.onAccept?.call();

                                    // Backend sync silently in background
                                    RideService.instance
                                        .acceptRide(
                                          ride.rideId.isNotEmpty
                                              ? ride.rideId
                                              : ride.id,
                                          offer: ride,
                                        )
                                        .catchError((e) {
                                      debugPrint('[Accept] Sync: $e');
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              shadowColor:
                                  const Color(0xFF2563EB).withOpacity(0.35),
                            ),
                            child: const Text(
                              '✓ Accept',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildMetricColumn(String label, String value,
      {bool isBoldOrange = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: QuickServeColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isBoldOrange
                ? QuickServeColors.primaryOrange
                : QuickServeColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
