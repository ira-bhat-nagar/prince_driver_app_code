import 'dart:async';

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/app_toast.dart';
import '../models/ride_model.dart';
import '../services/notification_service.dart';
import '../services/ride_service.dart';

class NotificationCenterAlertsScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  final VoidCallback? onRideRequestTap;
  final VoidCallback? onRideAccepted;
  final VoidCallback? onTripCompletedTap;
  final VoidCallback? onIncentivesTap;
  final VoidCallback? onRatingsTap;
  final VoidCallback? onPayoutTap;
  final VoidCallback? onSosTap;
  final Function(int)? onBottomNavTap;

  const NotificationCenterAlertsScreen({
    super.key,
    this.onBackTap,
    this.onRideRequestTap,
    this.onRideAccepted,
    this.onTripCompletedTap,
    this.onIncentivesTap,
    this.onRatingsTap,
    this.onPayoutTap,
    this.onSosTap,
    this.onBottomNavTap,
  });

  @override
  State<NotificationCenterAlertsScreen> createState() =>
      _NotificationCenterAlertsScreenState();
}

class _NotificationItemModel {
  final String id;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String message;
  final String time;
  bool isUnread;
  final String category; // 'payments', 'trips', 'alerts'
  final VoidCallback? onTap;

  _NotificationItemModel({
    required this.id,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.category,
    this.onTap,
  });
}

class _NotificationCenterAlertsScreenState
    extends State<NotificationCenterAlertsScreen> {
  int _selectedCategory = 0; // 0: All, 1: Payments, 2: Trips, 3: Alerts
  String? _lastAutoShownRideId; // avoid double-showing dialog

  late List<_NotificationItemModel> _notifications;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    RideService.instance.addListener(_onRideChanged);
    // If ride already available when screen opens — show dialog immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ride = RideService.instance.availableRide;
      if (ride != null && mounted) _maybeShowRideDialog(ride);
    });
  }

  @override
  void dispose() {
    RideService.instance.removeListener(_onRideChanged);
    super.dispose();
  }

  void _onRideChanged() {
    if (!mounted) return;
    setState(_initNotifications);
    // Auto-show dialog when new ride arrives while user is on this screen
    final ride = RideService.instance.availableRide;
    if (ride != null) _maybeShowRideDialog(ride);
  }

  void _maybeShowRideDialog(RideModel ride) {
    if (_lastAutoShownRideId == ride.rideId) return; // already shown
    _lastAutoShownRideId = ride.rideId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showRideAlertDialog(ride);
    });
  }

  void _initNotifications() {
    final available = RideService.instance.availableRide;
    final lastComp = RideService.instance.lastCompletedRide;

    _notifications = [
      _NotificationItemModel(
        id: 'notif_1',
        icon: Icons.directions_car,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: QuickServeColors.primaryBlue,
        title: available != null
            ? 'New Ride Request Available (${available.rideId})'
            : 'No new ride requests',
        message: available != null
            ? 'Pickup at ${available.pickupArea} ➔ Drop at ${available.destinationArea} • ₹${available.totalFare.toStringAsFixed(0)}'
            : 'New ride offers will appear here when available.',
        time: available != null ? 'Just now' : '—',
        isUnread: true,
        category: 'trips',
        onTap: widget.onRideRequestTap,
      ),
      _NotificationItemModel(
        id: 'notif_2',
        icon: Icons.check_circle,
        iconBg: const Color(0xFFE8F8EE),
        iconColor: QuickServeColors.statusGreen,
        title: lastComp != null
            ? 'Trip Completed - ₹${lastComp.totalFare.toStringAsFixed(0)} added'
            : 'Trip Completed - ₹320 added',
        message: lastComp != null
            ? 'Trip fare for passenger ${lastComp.passengerName} credited to your wallet via UPI.'
            : 'Trip fare successfully credited to your wallet via UPI.',
        time: '25m ago',
        isUnread: true,
        category: 'payments',
        onTap: widget.onTripCompletedTap,
      ),
      _NotificationItemModel(
        id: 'notif_3',
        icon: Icons.emoji_events,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        title: 'Incentive Unlocked: Weekly Quest',
        message:
            'Congratulations! You completed 15 trips this week. ₹1,000 bonus unlocked!',
        time: '2h ago',
        isUnread: false,
        category: 'alerts',
        onTap: widget.onIncentivesTap,
      ),
      _NotificationItemModel(
        id: 'notif_4',
        icon: Icons.star,
        iconBg: const Color(0xFFFEF9C3),
        iconColor: const Color(0xFFCA8A04),
        title: 'Rating Updated: You received 5 Stars',
        message:
            'Passenger Rahul Sharma rated your ride 5.0 with great driving compliment!',
        time: '1d ago',
        isUnread: false,
        category: 'alerts',
        onTap: widget.onRatingsTap,
      ),
      _NotificationItemModel(
        id: 'notif_5',
        icon: Icons.account_balance_wallet,
        iconBg: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF9333EA),
        title: 'Payout Received: ₹12,400 to HDFC Bank',
        message: 'Instant payout transaction #TXN99201 settled successfully.',
        time: '2d ago',
        isUnread: false,
        category: 'payments',
        onTap: widget.onPayoutTap,
      ),
    ];
  }

  List<_NotificationItemModel> get _filteredNotifications {
    switch (_selectedCategory) {
      case 1: // Payments
        return _notifications.where((n) => n.category == 'payments').toList();
      case 2: // Trips
        return _notifications
            .where((n) => n.category == 'trips' || n.id == 'notif_2')
            .toList();
      case 3: // Alerts
        return _notifications
            .where((n) => n.category == 'alerts' || n.id == 'notif_1')
            .toList();
      case 0:
      default:
        return _notifications;
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n.isUnread = false;
      }
    });
    AppToast.info(context, 'All notifications marked as read');
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredNotifications;

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
          'Notifications',
          style: TextStyle(
            color: QuickServeColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark All Read',
              style: TextStyle(
                color: QuickServeColors.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: QuickServeColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildChip('All (5)', 0),
                    const SizedBox(width: 8),
                    _buildChip('Payments', 1),
                    const SizedBox(width: 8),
                    _buildChip('Trips', 2),
                    const SizedBox(width: 8),
                    _buildChip('Alerts', 3),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: QuickServeColors.borderLight),

            // Notifications List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.notifications_off_outlined,
                              size: 48, color: QuickServeColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No notifications in this category',
                            style: TextStyle(
                                color: QuickServeColors.textSecondary,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final item = filteredList[idx];
                        return _buildNotificationCard(item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int index) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? QuickServeColors.primaryBlue
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : QuickServeColors.textDark,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItemModel item) {
    final ride =
        item.id == 'notif_1' ? RideService.instance.availableRide : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            item.isUnread = false;
          });
          // For ride request notifications — show an immediate alert popup
          if (item.id == 'notif_1') {
            final ride = RideService.instance.availableRide;
            if (ride != null) {
              _showRideAlertDialog(ride);
            } else if (item.onTap != null) {
              item.onTap!();
            } else {
              AppToast.info(context, 'No active ride request at the moment.');
            }
            return;
          }
          if (item.onTap != null) {
            item.onTap!();
          } else {
            AppToast.info(context, item.title);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isUnread
                  ? QuickServeColors.primaryBlue.withOpacity(0.35)
                  : QuickServeColors.borderLight,
              width: item.isUnread ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: QuickServeColors.textDark,
                              fontSize: 14,
                              fontWeight: item.isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: QuickServeColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: const TextStyle(
                        color: QuickServeColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.time,
                      style: const TextStyle(
                        color: QuickServeColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    if (ride != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _respondToRide(ride, accept: false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: QuickServeColors.statusRed,
                                side: const BorderSide(
                                    color: QuickServeColors.statusRed),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: RideService.instance.isProcessingAction
                                  ? null
                                  : () => _respondToRide(ride, accept: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: QuickServeColors.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept Ride'),
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
    );
  }

  Future<void> _showRideAlertDialog(RideModel ride) async {
    unawaited(NotificationService.instance.playRideRequestRing());
    Timer? countdownTimer;
    var secondsLeft = 30;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          countdownTimer ??=
              Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!dialogContext.mounted) {
              timer.cancel();
              return;
            }
            setDialogState(() => secondsLeft--);
            if (secondsLeft <= 0) {
              timer.cancel();
              unawaited(_respondToRide(ride, accept: false));
              Navigator.of(dialogContext).pop();
            }
          });

          final timerColor = secondsLeft > 20
              ? const Color(0xFF10B981)
              : secondsLeft > 10
                  ? const Color(0xFFF59E0B)
                  : Colors.red;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${ride.totalFare.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: timerColor, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$secondsLeft',
                          style: TextStyle(
                            color: timerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _alertRow(Icons.circle, 'Pickup', ride.pickupAddress),
                      const SizedBox(height: 8),
                      _alertRow(
                          Icons.location_on, 'Drop', ride.destinationAddress),
                      const SizedBox(height: 8),
                      _alertRow(
                        Icons.straighten,
                        'Distance',
                        '${ride.distanceKm} km • ${ride.durationMin} min',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            countdownTimer?.cancel();
                            Navigator.of(dialogContext).pop();
                            unawaited(_respondToRide(ride, accept: false));
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('REJECT',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            countdownTimer?.cancel();
                            Navigator.of(dialogContext).pop();
                            unawaited(_respondToRide(ride, accept: true));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('ACCEPT',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      countdownTimer?.cancel();
      unawaited(NotificationService.instance.stopRideRing());
    });
  }

  Widget _alertRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: QuickServeColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 12.5, color: QuickServeColors.textSecondary),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: QuickServeColors.textDark)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _respondToRide(RideModel ride, {required bool accept}) async {
    final succeeded = accept
        ? await RideService.instance.acceptRide(ride.rideId)
        : await RideService.instance.rejectRide(ride.rideId);
    if (!mounted) return;
    if (!succeeded) {
      AppToast.error(
          context,
          accept
              ? 'Failed to accept ride. Please retry.'
              : 'Failed to reject ride. Please retry.');
      return;
    }
    AppToast.success(context,
        accept ? 'Ride accepted! En route to pickup' : 'Ride declined');
    if (accept) widget.onRideAccepted?.call();
  }
}
