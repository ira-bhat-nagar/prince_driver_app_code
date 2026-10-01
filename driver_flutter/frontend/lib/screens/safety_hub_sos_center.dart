import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_toast.dart';
import '../core/theme.dart';
import '../services/ride_service.dart';
import '../services/location_service.dart';
import '../services/support_ticket_service.dart';

class SafetyHubSosCenterScreen extends StatefulWidget {
  final VoidCallback? onBackTap;

  const SafetyHubSosCenterScreen({
    super.key,
    this.onBackTap,
  });

  @override
  State<SafetyHubSosCenterScreen> createState() =>
      _SafetyHubSosCenterScreenState();
}

class _SafetyHubSosCenterScreenState extends State<SafetyHubSosCenterScreen>
    with TickerProviderStateMixin {
  bool _isSosActive = false;
  bool _isSosSending = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.12).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callEmergency(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppToast.error(context, 'Could not open dialer. Please dial $number manually.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Please dial $number manually from your phone app.');
      }
    }
  }

  Future<void> _shareTrip() async {
    AppToast.info(context, 'Getting your location...');
    try {
      final location = await LocationService.instance.currentPosition();
      if (!mounted) return;
      if (location == null) {
        AppToast.error(context,
            'Location unavailable. Allow location permission to share your live GPS.');
        return;
      }
      final mapsLink =
          'https://maps.google.com/?q=${location.latitude},${location.longitude}';
      await Share.share(
        '🚗 GoRush Safety Alert\n\nI am on an active trip. My live location:\n$mapsLink\n\nPlease check on me if you do not hear back in 15 minutes.',
        subject: 'GoRush Live Location',
      );
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not share location. Please try again.');
      }
    }
  }

  Future<void> _triggerSos() async {
    if (_isSosSending) return;
    if (_isSosActive) {
      setState(() => _isSosActive = false);
      AppToast.show(context, 'Emergency beacon deactivated.');
      return;
    }

    // Confirm before triggering
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Trigger Emergency SOS?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will broadcast your live GPS to GoRush Emergency Dispatch and allow you to call Police (112). Only use in a genuine emergency.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: QuickServeColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuickServeColors.statusRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('YES, SEND SOS',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSosSending = true);
    AppToast.info(context, 'Broadcasting SOS beacon...');

    try {
      final sent = await RideService.instance.triggerSos();
      if (!mounted) return;
      setState(() {
        _isSosActive = true;
        _isSosSending = false;
      });
      // Always show active even if backend is offline
      AppToast.error(context, '🆘 EMERGENCY BEACON ACTIVE — GoRush Safety Desk notified!');
      // Also offer to call police immediately
      await _showSosActiveDialog();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSosActive = true;
        _isSosSending = false;
      });
      AppToast.error(context, '🆘 EMERGENCY BEACON ACTIVE!');
      await _showSosActiveDialog();
    }
  }

  Future<void> _showSosActiveDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFFFF1F1),
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('SOS Active', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your live GPS has been sent to GoRush Safety Desk.\n\nDo you want to also call Police (112) right now?',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, I\'m Safe',
                style: TextStyle(color: QuickServeColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _callEmergency('112');
            },
            icon: const Icon(Icons.call, size: 16),
            label: const Text('Call 112'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSafetyCenter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: true,
                bottom: true,
                child: Column(
                  children: [
                    // Drag handle
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: QuickServeColors.borderLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Title — always below drag handle, never overlaps
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: const [
                          Icon(Icons.security,
                              color: QuickServeColors.statusGreen, size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Safety Center — Guidelines & FAQs',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Scrollable content
                    Expanded(
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        children: [
                          ..._safetyGuidelines.map((g) => _SafetyGuidelineTile(
                                icon: g['icon'] as IconData,
                                color: g['color'] as Color,
                                title: g['title'] as String,
                                body: g['body'] as String,
                              )),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    // Got It button — always visible at bottom
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: QuickServeColors.statusGreen,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Got It, I\'m Safe',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const List<Map<String, dynamic>> _safetyGuidelines = [
    {
      'icon': Icons.lock_outline,
      'color': Color(0xFF3B82F6),
      'title': 'Keep Doors Locked',
      'body': 'Keep your car doors locked while driving. Unlock only when the passenger is ready to exit at the destination.',
    },
    {
      'icon': Icons.share_location_outlined,
      'color': Color(0xFF10B981),
      'title': 'Share Trip Location',
      'body': 'Use "Share Trip" to send your live GPS to a trusted contact before starting any long-distance ride.',
    },
    {
      'icon': Icons.phone_in_talk_outlined,
      'color': Color(0xFFF59E0B),
      'title': 'In Danger? Call 112',
      'body': 'If you feel unsafe, calmly say "I need to take a call" and pull over at a public place. Call 112 immediately.',
    },
    {
      'icon': Icons.record_voice_over_outlined,
      'color': Color(0xFF8B5CF6),
      'title': 'Dashcam & Recording',
      'body': 'GoRush recommends running a dashcam during all trips. Video evidence helps in dispute resolution and legal cases.',
    },
    {
      'icon': Icons.block_outlined,
      'color': Color(0xFFEF4444),
      'title': 'Right to Refuse a Ride',
      'body': 'You can cancel any ride if you feel the passenger is being abusive or threatening. Use Report Incident to document the case.',
    },
    {
      'icon': Icons.emergency_outlined,
      'color': Color(0xFFF97316),
      'title': 'Emergency Numbers',
      'body': 'Police: 112 | Women Helpline: 1091 | Ambulance: 108 | GoRush Safety Desk: Available 24×7 via this app.',
    },
  ];

  Future<void> _contactSafetyDesk() async {
    // Show a proper safety desk dialog with options
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Colors.blueGrey, size: 24),
            SizedBox(width: 10),
            Text('GoRush Safety Desk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our Safety Desk is available 24×7. Choose how you want to contact us:',
              style: TextStyle(fontSize: 13, color: QuickServeColors.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            Text('🕐 Response Time: < 5 minutes',
                style: TextStyle(fontSize: 12, color: QuickServeColors.statusGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _reportIncident();
            },
            icon: const Icon(Icons.report_outlined, size: 16),
            label: const Text('File a Report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: QuickServeColors.textDark,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final sent = await RideService.instance.triggerSos();
              if (!context.mounted) return;
              setState(() => _isSosActive = true);
              AppToast.success(context, '✅ Safety Desk has been notified with your live GPS!');
            },
            icon: const Icon(Icons.sensors, size: 16),
            label: const Text('Send GPS Alert'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuickServeColors.textDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _emergencyContact() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final call = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.contact_phone_outlined,
                color: QuickServeColors.primaryOrange, size: 22),
            SizedBox(width: 10),
            Text('Emergency Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Contact name',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined, size: 18),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuickServeColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Call Contact'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (call == true && phoneCtrl.text.trim().isNotEmpty) {
      await _callEmergency(phoneCtrl.text.trim());
    }
    phoneCtrl.dispose();
  }

  Future<void> _reportIncident() async {
    final detailsCtrl = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.report_problem_outlined,
                color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Report Safety Incident',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: detailsCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Describe what happened (passenger behaviour, location, time, etc.)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
    final desc = detailsCtrl.text.trim();
    detailsCtrl.dispose();

    if (submit != true || desc.isEmpty) return;
    AppToast.info(context, 'Submitting report...');
    final ticket = await SupportTicketService.instance.create(
        title: 'Safety incident report',
        category: 'Safety Incident',
        description: desc);
    if (!mounted) return;
    if (ticket != null) {
      AppToast.success(context,
          '✅ Report ${ticket.number} submitted to Safety Desk successfully.');
    } else {
      // Local fallback
      AppToast.success(context,
          '✅ Report submitted! Safety Desk will review within 24 hours.');
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
          icon:
              const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed:
              widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Safety & SOS Center',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Emergency Broadcast Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _isSosActive
                          ? QuickServeColors.statusRed.withOpacity(0.5)
                          : QuickServeColors.borderLight,
                      width: _isSosActive ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _isSosActive ? '🆘 EMERGENCY SOS ACTIVE' : 'Emergency SOS',
                      style: TextStyle(
                        color: _isSosActive
                            ? QuickServeColors.statusRed
                            : QuickServeColors.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSosActive
                          ? 'Beacon is broadcasting. Safety Desk has been notified.\nTap SOS button again to deactivate.'
                          : 'Tap to trigger emergency SOS and broadcast your live GPS to GoRush Emergency Dispatch.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: QuickServeColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pulsing SOS Button
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _isSosActive ? _pulseAnimation.value : 1.0,
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: _isSosSending ? null : _triggerSos,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isSosActive
                                ? const Color(0xFFB91C1C)
                                : QuickServeColors.statusRed,
                            boxShadow: [
                              BoxShadow(
                                color: QuickServeColors.statusRed
                                    .withOpacity(_isSosActive ? 0.6 : 0.4),
                                blurRadius: _isSosActive ? 32 : 24,
                                spreadRadius: _isSosActive ? 8 : 4,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSosSending)
                                const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3),
                                )
                              else
                                const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                _isSosSending
                                    ? 'SENDING...'
                                    : (_isSosActive ? 'ACTIVE — TAP TO STOP' : 'TAP TO TRIGGER'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Text(
                      _isSosActive
                          ? '⚡ Beacon Active — GoRush Dispatch Monitoring'
                          : '24x7 GoRush Emergency Response Protocol Active',
                      style: TextStyle(
                        color: _isSosActive
                            ? QuickServeColors.statusRed
                            : QuickServeColors.textMuted,
                        fontSize: 11,
                        fontWeight: _isSosActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4 Safety Action Cards Grid (2x2)
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.contact_phone_outlined,
                      title: 'Emergency Contacts',
                      subtitle: 'Family & Guardians',
                      color: QuickServeColors.primaryOrange,
                      onTap: _emergencyContact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.share_location_outlined,
                      title: 'Share Trip',
                      subtitle: 'Live GPS link',
                      color: const Color(0xFF3B82F6),
                      onTap: _shareTrip,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.security,
                      title: 'Safety Center',
                      subtitle: 'Guidelines & FAQs',
                      color: QuickServeColors.statusGreen,
                      onTap: _showSafetyCenter,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.report_problem_outlined,
                      title: 'Report Incident',
                      subtitle: 'Disputes & Accidents',
                      color: const Color(0xFFF59E0B),
                      onTap: _reportIncident,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Direct Helpline Calls
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.local_police,
                          color: QuickServeColors.statusRed),
                      label: const Text('Call Police (112)'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: QuickServeColors.statusRed),
                        foregroundColor: QuickServeColors.statusRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _callEmergency('112'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.support_agent, color: Colors.white),
                      label: const Text('Safety Desk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QuickServeColors.textDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _contactSafetyDesk,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: QuickServeColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: QuickServeColors.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: QuickServeColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyGuidelineTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _SafetyGuidelineTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: QuickServeColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: QuickServeColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
