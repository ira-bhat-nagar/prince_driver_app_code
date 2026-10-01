import 'package:flutter/foundation.dart';

/// Centralized API Configuration for GoRush Driver Partner Application
class ApiConfig {
  /// Build-time override for a physical device or a deployed API, for example:
  /// --dart-define=API_BASE_URL=https://api.example.com
  ///
  /// A phone cannot use the development machine's localhost address. Supplying
  /// the machine's current Wi-Fi address here keeps the API target explicit
  /// and avoids shipping a stale, hard-coded LAN address.
  static const String _buildBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Primary LAN IP of the host machine running the backend (Windows PC)
  static const String currentLanHost = '192.168.1.15';

  /// Optional custom base URL override for staging, testing, or custom deployments
  static String? customBaseUrl;

  /// Default port for Node.js / Express backend
  static const int defaultPort = 5000;

  /// Candidates used during app execution.
  ///
  /// A temporary tunnel URL must never be shipped as a fallback: it expires and
  /// makes every registration wait for a request timeout.  For a deployed API,
  /// pass API_BASE_URL at build time.  During local development, a physical
  /// device on the same Wi-Fi reaches the backend through [currentLanHost].
  /// USB connected devices reach localhost / ADB.
  /// Emulators reach 10.0.2.2.
  static List<String> get candidateBaseUrls {
    if (kIsWeb) {
      return _buildBaseUrl.isNotEmpty
          ? [_buildBaseUrl, 'http://localhost:$defaultPort']
          : ['http://localhost:$defaultPort'];
    }

    // Physical device priority: LAN → build-time override → emulator fallbacks
    return [
      if (customBaseUrl != null && customBaseUrl!.isNotEmpty) customBaseUrl!,
      'http://$currentLanHost:$defaultPort',
      if (_buildBaseUrl.isNotEmpty) _buildBaseUrl,
      'http://10.0.2.2:$defaultPort',
      'http://localhost:$defaultPort',
      'http://127.0.0.1:$defaultPort',
    ];
  }

  /// Primary base URL for Android physical-device development.
  ///
  /// Release/remote builds should supply API_BASE_URL. Physical phones cannot
  /// use localhost; on local Wi-Fi they use [currentLanHost].
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    if (_buildBaseUrl.isNotEmpty) return _buildBaseUrl;
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    return 'http://$currentLanHost:$defaultPort';
  }

  // Endpoints
  static const String healthEndpoint = '/api/health';
  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
  static const String meEndpoint = '/api/auth/me';
  static const String changePasswordEndpoint = '/api/auth/change-password';
  static const String updateProfileEndpoint = '/api/auth/profile';
  static const String vehiclesEndpoint = '/api/auth/vehicles';

  // Phase 5: Core Ride & Driver endpoints
  static const String driverStatusEndpoint = '/api/driver/status';
  static const String driverIncentivesEndpoint = '/api/driver/incentives';
  static const String ridesAvailableEndpoint = '/api/rides/available';
  static const String ridesActiveEndpoint = '/api/rides/active';
  static const String ridesHistoryEndpoint = '/api/rides/history';
  static const String ridesEarningsEndpoint = '/api/rides/earnings';

  // Request timeouts
  static const Duration requestTimeout = Duration(seconds: 2);
  static const Duration healthCheckTimeout = Duration(seconds: 2);

  /// Standard HTTP Headers
  static Map<String, String> getHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
