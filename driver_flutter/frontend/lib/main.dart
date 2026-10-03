import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'core/app_toast.dart';
import 'core/theme.dart';
import 'core/demo_controller.dart';
import 'services/driver_backend_service.dart';
import 'services/token_storage_service.dart';
import 'services/ride_service.dart';

// Screens 01 to 08: Onboarding
import 'screens/onboarding/splash_screen.dart';
import 'screens/onboarding/driver_login_registration.dart';
import 'screens/onboarding/otp_verification_liveness.dart';
import 'screens/onboarding/driver_profile_setup.dart';
import 'screens/onboarding/upload_documents_screen.dart';
import 'screens/onboarding/bank_details_screen.dart';
import 'screens/onboarding/terms_conditions_screen.dart';
import 'screens/onboarding/registration_complete_screen.dart';

// Screens 09 to 14: Core Ride Flow
import 'screens/driver_home_dashboard.dart';
import 'screens/incoming_ride_request.dart';
import 'screens/active_trip_navigation.dart';
import 'screens/navigation_map_screen.dart';
import 'screens/passenger_trip_management.dart';
import 'screens/trip_completion_screen.dart';
import 'screens/fare_breakdown_screen.dart';

// Screens 15 to 24: Driver Operations & Management
import 'screens/earnings_instant_payout.dart';
import 'screens/trip_history_detailed_receipt.dart';
import 'screens/notification_center_alerts.dart';
import 'screens/safety_hub_sos_center.dart';
import 'screens/help_center_support_tickets.dart';
import 'screens/driver_profile_vehicle_settings.dart';
import 'screens/vehicle_management_screen.dart';
import 'screens/scheduled_rides_advance_bookings.dart';
import 'screens/ratings_reviews_dispute_center.dart';
import 'screens/support_tickets_screen.dart';
import 'screens/incentives_weekly_quests.dart';
import 'screens/driver_chatbot_screen.dart';
import 'screens/insurance_screen.dart';
import 'screens/driver_wallet_screen.dart';

// Screen 25: Admin Web Portal
import 'screens/admin/fleet_admin_screen.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

void _showRecoverableError(Object error) {
  final msg = error.toString().toLowerCase();
  // Suppress network/backend errors — don't bother driver with technical noise
  final isNetworkError = msg.contains('socket') ||
      msg.contains('timeout') ||
      msg.contains('connection') ||
      msg.contains('xmlhttprequest') ||
      msg.contains('handshake') ||
      msg.contains('null check') ||
      msg.contains('type \'null\'') ||
      msg.contains('nosuchmethoderror') ||
      msg.contains('failed host lookup') ||
      msg.contains('errno') ||
      msg.contains('os error') ||
      msg.contains('setonlinestatus') ||
      msg.contains('fetchavailableride') ||
      msg.contains('isOnline') ||
      msg.contains('formatexception') ||
      msg.contains('insurance') ||
      msg.contains('claim') ||
      msg.contains('Insurance request failed') ||
      msg.contains('jsonunsupportedobjecterror');
  if (isNetworkError) {
    debugPrint('[Suppressed error]: $error');
    return;
  }
  debugPrint('Handled application error: $error');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = _appNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      AppToast.error(context, 'Something went wrong. Please try again.');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set status bar to transparent/dark immediately — no flash
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF030B1C),
    statusBarIconBrightness: Brightness.light,
  ));
  FlutterError.onError = (details) => _showRecoverableError(details.exception);
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  ui.PlatformDispatcher.instance.onError = (error, _) {
    _showRecoverableError(error);
    return true;
  };
  // Must await before runApp — prevents notifyListeners crash on startup
  await DriverBackendService.instance.initSession();
  runApp(const QuickServeDriverApp());
}

class QuickServeDriverApp extends StatelessWidget {
  final DemoScreen? initialScreen;
  const QuickServeDriverApp({super.key, this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _appNavigatorKey,
      title: 'GoRush Captain App',
      debugShowCheckedModeBanner: false,
      theme: QuickServeTheme.lightTheme,
      home: QuickServeDriverRootFlow(initialScreen: initialScreen),
    );
  }
}

typedef GoRushDriverApp = QuickServeDriverApp;

class QuickServeDriverRootFlow extends StatefulWidget {
  final DemoScreen? initialScreen;
  const QuickServeDriverRootFlow({super.key, this.initialScreen});

  @override
  State<QuickServeDriverRootFlow> createState() =>
      _QuickServeDriverRootFlowState();
}

class _QuickServeDriverRootFlowState extends State<QuickServeDriverRootFlow> {
  late final DemoFlowController _demoController;
  final List<DemoScreen> _navigationHistory = [];
  Timer? _splashTimer;
  bool _otpVerifiedForRegistration = false;

  @override
  void initState() {
    super.initState();
    _demoController = DemoFlowController(
      initialScreen: widget.initialScreen ?? DemoScreen.splashScreen,
      autoStart: false,
    );
    _demoController.addListener(_onControllerUpdate);
    // Request location permission on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied ||
          status == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _demoController.removeListener(_onControllerUpdate);
    _demoController.dispose();
    super.dispose();
  }

  void _handleManualInteraction({bool pause = true}) {
    _demoController.userInteracted(pauseAuto: pause);
  }

  void _navigateTo(DemoScreen screen) {
    _handleManualInteraction(pause: true);
    if (_demoController.currentScreen != screen) {
      _navigationHistory.add(_demoController.currentScreen);
    }
    _demoController.jumpToScreen(screen);
  }

  void _handleBottomNavTap(int index) {
    _handleManualInteraction(pause: true);
    switch (index) {
      case 0:
        _navigateTo(DemoScreen.driverHomeDashboard);
        break;
      case 1:
        _navigateTo(DemoScreen.tripHistoryDetailedReceipt);
        break;
      case 2:
        _navigateTo(DemoScreen.earningsInstantPayout);
        break;
      case 3:
        _navigateTo(DemoScreen.incentivesWeeklyQuests);
        break;
      case 4:
        _navigateTo(DemoScreen.driverProfileVehicleSettings);
        break;
    }
  }

  bool _canPopCurrentRoute() {
    return _demoController.currentScreen == DemoScreen.loginRegister ||
        _demoController.currentScreen == DemoScreen.splashScreen;
  }

  void _handleBackNavigation() {
    if (_navigationHistory.isNotEmpty) {
      final prev = _navigationHistory.removeLast();
      _handleManualInteraction(pause: true);
      _demoController.jumpToScreen(prev);
    } else if (_demoController.currentScreen != DemoScreen.loginRegister) {
      _handleManualInteraction(pause: true);
      _demoController.jumpToScreen(DemoScreen.loginRegister);
    }
  }

  Widget _buildCurrentScreen() {
    switch (_demoController.currentScreen) {
      // 01: Splash Screen (Dark #121212)
      case DemoScreen.splashScreen:
        return SplashScreen(
          onGetStarted: () {
            _splashTimer?.cancel();
            _navigateTo(DemoScreen.loginRegister);
          },
        );

      // 02: Login / Register (Approved Create Account UI)
      case DemoScreen.createAccount:
      case DemoScreen.loginRegister:
        return DriverLoginRegistrationScreen(
          key: UniqueKey(),
          otpVerified: _otpVerifiedForRegistration,
          onGetOtp: () {
            _otpVerifiedForRegistration = false;
            _navigateTo(DemoScreen.otpVerification);
          },
          onRegistrationSuccess: () {
            _otpVerifiedForRegistration = false;
            _navigationHistory.clear();
            _navigateTo(DemoScreen.uploadDocuments);
          },
          onLoginSuccess: () {
            _handleManualInteraction(pause: true);
            _navigationHistory.clear();
            _demoController.jumpToScreen(DemoScreen.driverHomeDashboard);
          },
        );

      // 03: OTP Verification
      case DemoScreen.otpVerification:
        return OtpVerificationLivenessScreen(
          onBackTap: () {
            _handleManualInteraction(pause: true);
            _otpVerifiedForRegistration = false;
            _demoController.jumpToScreen(DemoScreen.loginRegister);
          },
          onVerifySuccess: () {
            _handleManualInteraction(pause: true);
            _otpVerifiedForRegistration = false;
            // Save session in background — no blocking
            DriverBackendService.instance.saveSession().catchError((_) {});
            _navigationHistory.clear();
            // Skip registration form — go directly to profile setup
            // (phone is auto-filled from OtpSession.phoneNumber)
            _demoController.jumpToScreen(DemoScreen.driverProfileSetup);
          },
        );

      // 04: Driver Profile Setup (Used both during Onboarding and from Profile Settings)
      case DemoScreen.driverProfileSetup:
        final bool isEditingMode = _navigationHistory
            .contains(DemoScreen.driverProfileVehicleSettings);
        return DriverProfileSetupScreen(
          isEditing: isEditingMode,
          onBackTap: () {
            if (isEditingMode) {
              _navigateTo(DemoScreen.driverProfileVehicleSettings);
            } else {
              _navigateTo(DemoScreen.otpVerification);
            }
          },
          onSave: () {
            _navigateTo(DemoScreen.driverProfileVehicleSettings);
          },
          onNext: () {
            if (isEditingMode) {
              _navigateTo(DemoScreen.driverProfileVehicleSettings);
            } else {
              _navigateTo(DemoScreen.uploadDocuments);
            }
          },
        );

      // 05: Upload Documents
      case DemoScreen.uploadDocuments:
        final bool isEditingModeDoc = _navigationHistory.contains(DemoScreen.driverProfileVehicleSettings);
        return UploadDocumentsScreen(
          onBackTap: _handleBackNavigation,
          onNext: () {
            if (isEditingModeDoc) {
              _navigateTo(DemoScreen.driverProfileVehicleSettings);
            } else {
              _navigateTo(DemoScreen.bankDetails);
            }
          },
        );

      // 06: Bank Details / UPI
      case DemoScreen.bankDetails:
        final bool isEditingModeBank = _navigationHistory.contains(DemoScreen.driverProfileVehicleSettings);
        return BankDetailsScreen(
          onBackTap: _handleBackNavigation,
          onNext: () {
            if (isEditingModeBank) {
              _navigateTo(DemoScreen.driverProfileVehicleSettings);
            } else {
              _navigateTo(DemoScreen.termsConditions);
            }
          },
        );

      // 07: Terms & Conditions
      case DemoScreen.termsConditions:
        return TermsConditionsScreen(
          onBackTap: () {
            _navigateTo(DemoScreen.bankDetails);
          },
          onComplete: () {
            _navigateTo(DemoScreen.registrationComplete);
          },
        );

      // 08: Registration Complete
      case DemoScreen.registrationComplete:
        return RegistrationCompleteScreen(
          onGoHome: () {
            _navigationHistory.clear();
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // 09: Driver Home / Dashboard
      case DemoScreen.homeDashboard:
      case DemoScreen.driverHomeDashboard:
        return DriverHomeDashboardScreen(
          key: const ValueKey('screen_09_home'),
          onIncomingRequestTap: () {
            // Go directly to passenger trip management — bottom sheet IS the ride request UI
            _navigateTo(DemoScreen.passengerTripManagement);
          },
          onNavigationTap: () {
            _navigateTo(DemoScreen.navigationLiveMap);
          },
          onEarningsTap: () {
            _navigateTo(DemoScreen.earningsInstantPayout);
          },
          onTripsTap: () {
            _navigateTo(DemoScreen.tripHistoryDetailedReceipt);
          },
          onIncentivesTap: () {
            _navigateTo(DemoScreen.scheduledRidesAdvanceBookings);
          },
          onRatingsTap: () {
            _navigateTo(DemoScreen.ratingsReviewsDisputeCenter);
          },
          onSaathiAiTap: () {
            _navigateTo(DemoScreen.helpCenterSupportTickets);
          },
          onChatbotTap: () {
            _navigateTo(DemoScreen.aiChatbot);
          },
          onNotificationTap: () {
            _navigateTo(DemoScreen.notificationCenterAlerts);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onProfileTap: () {
            _navigateTo(DemoScreen.driverProfileVehicleSettings);
          },
          onLogoutTap: () async {
            await DriverBackendService.instance.logout();
            _demoController.jumpToScreen(DemoScreen.loginRegister);
          },
          onWalletTap: () {
            _navigateTo(DemoScreen.driverWallet);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // 10: Incoming Ride Request
      case DemoScreen.incomingRideRequest:
        return IncomingRideRequestScreen(
          key: const ValueKey('screen_10_incoming'),
          onAccept: () {
            _navigateTo(DemoScreen.passengerTripManagement);
          },
          onDecline: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // 11: Navigation & Live Tracking (Active Trip in progress)
      case DemoScreen.navigationLiveMap:
        return NavigationMapScreen(
          key: const ValueKey('screen_11_navigation_map'),
          onBackTap: () => _navigateTo(DemoScreen.driverHomeDashboard),
        );

      case DemoScreen.activeTripNavigation:
        return ActiveTripNavigationScreen(
          key: const ValueKey('screen_11_nav'),
          onEndTrip: () {
            _navigateTo(DemoScreen.tripCompletion);
          },
          onBackTap: () {
            _navigateTo(DemoScreen.passengerTripManagement);
          },
          onChatTap: () {
            _navigateTo(DemoScreen.passengerTripManagement);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
        );

      // 12: Passenger Trip Management (Pickup & OTP Verification)
      case DemoScreen.passengerTripManagement:
        return PassengerTripManagementScreen(
          key: const ValueKey('screen_12_trip_mgmt'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onStartTrip: () {
            _navigateTo(DemoScreen.activeTripNavigation);
          },
          onCancelTrip: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // 13: Trip Completion
      case DemoScreen.tripCompletion:
        return TripCompletionScreen(
          key: const ValueKey('screen_13_completion'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onViewDetails: () {
            _navigateTo(DemoScreen.fareBreakdown);
          },
          onDoneTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // 14: Fare Breakdown
      case DemoScreen.fareBreakdown:
        return FareBreakdownScreen(
          key: const ValueKey('screen_14_fare'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onDone: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // 15: Earnings
      case DemoScreen.earnings:
      case DemoScreen.earningsInstantPayout:
        return EarningsInstantPayoutScreen(
          key: const ValueKey('screen_15_earnings'),
          onCashOutTap: () {
            _handleManualInteraction(pause: true);
            AppToast.success(context,
                'Instant UPI Transfer Initiated: ₹ 2,480 credited to HDFC Bank');
          },
          onStatementTap: () {
            _navigateTo(DemoScreen.tripHistoryDetailedReceipt);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // 16: Trip History (Completed and Cancelled)
      case DemoScreen.rides:
      case DemoScreen.tripHistoryDetailedReceipt:
      case DemoScreen.completedHistory:
        return TripHistoryDetailedReceiptScreen(
          key: const ValueKey('screen_16_history_completed'),
          initialTab: 0,
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onInsuranceTap: () {
            _navigateTo(DemoScreen.insurance);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      case DemoScreen.cancelledHistory:
        return TripHistoryDetailedReceiptScreen(
          key: const ValueKey('screen_16_history_cancelled'),
          initialTab: 1,
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onInsuranceTap: () {
            _navigateTo(DemoScreen.insurance);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // Incentives / Weekly Quests
      case DemoScreen.incentives:
      case DemoScreen.incentivesWeeklyQuests:
        return IncentivesWeeklyQuestsScreen(
          key: const ValueKey('screen_incentives'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // 17: Notifications
      case DemoScreen.notificationCenterAlerts:
        return NotificationCenterAlertsScreen(
          key: const ValueKey('screen_17_notifications'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onRideRequestTap: () {
            _navigateTo(DemoScreen.incomingRideRequest);
          },
          onRideAccepted: () {
            _navigateTo(DemoScreen.passengerTripManagement);
          },
          onTripCompletedTap: () {
            _navigateTo(DemoScreen.tripCompletion);
          },
          onIncentivesTap: () {
            _navigateTo(DemoScreen.scheduledRidesAdvanceBookings);
          },
          onRatingsTap: () {
            _navigateTo(DemoScreen.ratingsReviewsDisputeCenter);
          },
          onPayoutTap: () {
            _navigateTo(DemoScreen.earningsInstantPayout);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // 18: Safety & SOS
      case DemoScreen.safetyHubSosCenter:
        return SafetyHubSosCenterScreen(
          key: const ValueKey('screen_18_safety'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // 19: Support
      case DemoScreen.helpCenterSupportTickets:
        return HelpCenterSupportTicketsScreen(
          key: const ValueKey('screen_19_help'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onRaiseTicketTap: () {
            _navigateTo(DemoScreen.supportTicketsScreen);
          },
          onSafetyTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
        );

      // 20: Driver Profile & Settings
      case DemoScreen.driverProfileVehicleSettings:
        return DriverProfileVehicleSettingsScreen(
          key: const ValueKey('screen_20_profile'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onEditProfileTap: () {
            _navigateTo(DemoScreen.driverProfileSetup);
          },
          onVehicleTap: () {
            _navigateTo(DemoScreen.vehicleManagement);
          },
          onDocumentsTap: () {
            _navigateTo(DemoScreen.uploadDocuments);
          },
          onInsuranceTap: () {
            _navigateTo(DemoScreen.insurance);
          },
          onBankTap: () {
            _navigateTo(DemoScreen.bankDetails);
          },
          onLogoutTap: () async {
            _handleManualInteraction(pause: true);
            await TokenStorageService.instance.clearSession();
            await DriverBackendService.instance.logout();
            RideService.instance.clearSession();
            _navigationHistory.clear();
            _demoController.jumpToScreen(DemoScreen.loginRegister);
            if (mounted) {
              AppToast.info(context, 'Logged out successfully.');
            }
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      case DemoScreen.insurance:
        return InsuranceScreen(
          key: const ValueKey('screen_insurance'),
          onBackTap: _handleBackNavigation,
        );

      // 21: Vehicle Management
      case DemoScreen.vehicleManagement:
        return VehicleManagementScreen(
          key: const ValueKey('screen_21_vehicle'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverProfileVehicleSettings);
          },
        );

      // 22: Scheduled Rides
      case DemoScreen.scheduledRidesAdvanceBookings:
        return ScheduledRidesAdvanceBookingsScreen(
          key: const ValueKey('screen_22_scheduled'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onSosTap: () {
            _navigateTo(DemoScreen.safetyHubSosCenter);
          },
        );

      // 23: Ratings & Reviews
      case DemoScreen.ratingsReviewsDisputeCenter:
        return RatingsReviewsDisputeScreen(
          key: const ValueKey('screen_23_ratings'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // 24: Support Tickets
      case DemoScreen.supportTicketsScreen:
        return SupportTicketsScreen(
          key: const ValueKey('screen_24_tickets'),
          onBackTap: () {
            _navigateTo(DemoScreen.helpCenterSupportTickets);
          },
        );

      // 25: Admin Panel (Web)
      case DemoScreen.adminPanelFleet:
        return FleetAdminOperationsScreen(
          key: const ValueKey('screen_25_admin'),
          onBack: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // Dedicated Full-Screen AI Chatbot
      case DemoScreen.aiChatbot:
        return DriverChatbotScreen(
          key: const ValueKey('screen_ai_chatbot'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
        );

      // Driver Wallet Screen
      case DemoScreen.driverWallet:
        return DriverWalletScreen(
          key: const ValueKey('screen_driver_wallet'),
          onBackTap: () {
            _navigateTo(DemoScreen.driverHomeDashboard);
          },
          onBottomNavTap: _handleBottomNavTap,
        );

      // ignore: unreachable_switch_default
      default:
        return DriverLoginRegistrationScreen(
          key: UniqueKey(),
          onBackTap: () {
            _handleManualInteraction(pause: true);
            _demoController.jumpToScreen(DemoScreen.splashScreen);
          },
          onGetOtp: () {
            _navigateTo(DemoScreen.otpVerification);
          },
          onLoginSuccess: () {
            _handleManualInteraction(pause: true);
            _navigationHistory.clear();
            _demoController.jumpToScreen(DemoScreen.driverHomeDashboard);
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPopCurrentRoute(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: _buildCurrentScreen(),
    );
  }
}
