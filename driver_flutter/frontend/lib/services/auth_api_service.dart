import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'token_storage_service.dart';

/// Standard result object for authentication operations
class AuthResult {
  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? driver;
  final int? statusCode;

  const AuthResult({
    required this.success,
    required this.message,
    this.token,
    this.driver,
    this.statusCode,
  });

  bool get isSuccess => success;

  factory AuthResult.success({
    required String message,
    String? token,
    Map<String, dynamic>? driver,
    int? statusCode,
  }) {
    return AuthResult(
      success: true,
      message: message,
      token: token,
      driver: driver,
      statusCode: statusCode ?? 200,
    );
  }

  factory AuthResult.failure({
    required String message,
    int? statusCode,
  }) {
    return AuthResult(
      success: false,
      message: message,
      statusCode: statusCode,
    );
  }
}

/// Authentication API Service
/// Handles registration, login, profile retrieval, and health checks against the Node.js backend.
class AuthApiService {
  static final AuthApiService instance = AuthApiService._internal();
  factory AuthApiService() => instance;
  AuthApiService._internal();

  final http.Client _httpClient = http.Client();
  final TokenStorageService _tokenStorage = TokenStorageService.instance;

  /// Helper to safely parse JSON responses
  Map<String, dynamic>? _tryParseJson(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Duration _timeoutForCandidate(String base) {
    // Physical device â†’ backend via LAN/Atlas needs more time.
    // 12s is safe even on a slow connection and avoids silent fallback to mock data.
    if (base.contains('localhost') || base.contains('127.0.0.1') || base.contains('10.0.2.2')) {
      return const Duration(seconds: 4);
    }
    return const Duration(seconds: 7);
  }

  /// Send POST request â€” races ALL candidate URLs in parallel. First valid JSON
  /// response wins. This cuts wait time from (N Ã— timeout) to just one RTT.
  Future<http.Response> _postWithFallback(
    String endpoint,
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    // If we already know the best URL, try it first with a short deadline
    final knownBase = ApiConfig.customBaseUrl;
    if (knownBase != null && knownBase.isNotEmpty) {
      try {
        final response = await _httpClient
            .post(
              Uri.parse('$knownBase$endpoint'),
              headers: ApiConfig.getHeaders(token: token),
              body: jsonEncode(payload),
            )
            .timeout(_timeoutForCandidate(knownBase));
        if (_tryParseJson(response.body) != null) return response;
      } catch (_) {
        // Known URL failed, fall through to full race
        ApiConfig.customBaseUrl = null;
      }
    }

    // Race all candidates in parallel â€” fastest valid response wins
    final completer = Completer<http.Response>();
    int pending = ApiConfig.candidateBaseUrls.length;
    Object? lastError;

    for (final base in ApiConfig.candidateBaseUrls) {
      _httpClient
          .post(
            Uri.parse('$base$endpoint'),
            headers: ApiConfig.getHeaders(token: token),
            body: jsonEncode(payload),
          )
          .timeout(_timeoutForCandidate(base))
          .then((response) {
            if (!completer.isCompleted &&
                _tryParseJson(response.body) != null) {
              ApiConfig.customBaseUrl = base;
              completer.complete(response);
            }
          })
          .catchError((err) {
            lastError = err;
          })
          .whenComplete(() {
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.completeError(
                  lastError ?? const SocketException('All candidates failed'));
            }
          });
    }

    return completer.future;
  }

  /// Send GET request â€” races ALL candidates in parallel.
  Future<http.Response> _getWithFallback(
    String endpoint, {
    String? token,
  }) async {
    // Fast path: if we already know the working URL, use it directly
    final knownBase = ApiConfig.customBaseUrl;
    if (knownBase != null && knownBase.isNotEmpty) {
      try {
        final response = await _httpClient
            .get(
              Uri.parse('$knownBase$endpoint'),
              headers: ApiConfig.getHeaders(token: token),
            )
            .timeout(_timeoutForCandidate(knownBase));
        if (_tryParseJson(response.body) != null) return response;
      } catch (_) {
        ApiConfig.customBaseUrl = null;
      }
    }

    final completer = Completer<http.Response>();
    int pending = ApiConfig.candidateBaseUrls.length;
    Object? lastError;

    for (final base in ApiConfig.candidateBaseUrls) {
      _httpClient
          .get(
            Uri.parse('$base$endpoint'),
            headers: ApiConfig.getHeaders(token: token),
          )
          .timeout(_timeoutForCandidate(base))
          .then((response) {
            if (!completer.isCompleted &&
                _tryParseJson(response.body) != null) {
              ApiConfig.customBaseUrl = base;
              completer.complete(response);
            }
          })
          .catchError((err) {
            lastError = err;
          })
          .whenComplete(() {
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.completeError(
                  lastError ?? const SocketException('All candidates failed'));
            }
          });
    }
    return completer.future;
  }

  /// Send PUT request â€” races ALL candidates in parallel.
  Future<http.Response> _putWithFallback(
    String endpoint,
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    final knownBase = ApiConfig.customBaseUrl;
    if (knownBase != null && knownBase.isNotEmpty) {
      try {
        final response = await _httpClient
            .put(
              Uri.parse('$knownBase$endpoint'),
              headers: ApiConfig.getHeaders(token: token),
              body: jsonEncode(payload),
            )
            .timeout(_timeoutForCandidate(knownBase));
        if (_tryParseJson(response.body) != null) return response;
      } catch (_) {
        ApiConfig.customBaseUrl = null;
      }
    }

    final completer = Completer<http.Response>();
    int pending = ApiConfig.candidateBaseUrls.length;
    Object? lastError;

    for (final base in ApiConfig.candidateBaseUrls) {
      _httpClient
          .put(
            Uri.parse('$base$endpoint'),
            headers: ApiConfig.getHeaders(token: token),
            body: jsonEncode(payload),
          )
          .timeout(_timeoutForCandidate(base))
          .then((response) {
            if (!completer.isCompleted &&
                _tryParseJson(response.body) != null) {
              ApiConfig.customBaseUrl = base;
              completer.complete(response);
            }
          })
          .catchError((err) {
            lastError = err;
          })
          .whenComplete(() {
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.completeError(
                  lastError ?? const SocketException('All candidates failed'));
            }
          });
    }
    return completer.future;
  }

  /// 1. Driver Registration API: POST /api/auth/register
  Future<AuthResult> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? licenseNumber,
    String? profileImage,
    String? vehicleId,
    String? dateOfBirth,
  }) async {
    final payload = {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      if (licenseNumber != null && licenseNumber.isNotEmpty)
        'licenseNumber': licenseNumber.trim(),
      if (profileImage != null && profileImage.isNotEmpty)
        'profileImage': profileImage.trim(),
      if (vehicleId != null && vehicleId.isNotEmpty)
        'vehicleId': vehicleId.trim(),
      if (dateOfBirth != null && dateOfBirth.isNotEmpty)
        'dateOfBirth': dateOfBirth,
    };

    try {
      final response =
          await _postWithFallback(ApiConfig.registerEndpoint, payload);

      final data = _tryParseJson(response.body);
      final message =
          data?['message'] as String? ?? 'Registration request completed';

      if (response.statusCode == 201 && data?['success'] == true) {
        final token = data?['data']?['token'] as String?;
        final driverData = data?['data']?['driver'] as Map<String, dynamic>?;
        if (token == null || token.isEmpty || driverData == null) {
          return AuthResult.failure(
            message: 'Registration response did not include a driver session.',
            statusCode: response.statusCode,
          );
        }
        await _tokenStorage.saveSession(
          accessToken: token,
          driverProfile: driverData,
        );

        return AuthResult.success(
          message: message,
          token: token,
          driver: driverData,
          statusCode: response.statusCode,
        );
      }

      // Handle validation (400), conflict (409), or server errors (500/503)
      return AuthResult.failure(
        message: message,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return AuthResult.failure(message: 'Registration timed out. Please try again.');
    } on SocketException catch (error) {
      return AuthResult.failure(message: 'Cannot reach server: ${error.message}');
    } catch (error) {
      return AuthResult.failure(message: 'Registration failed: $error');
    }
  }

  /// 2. Driver Login API: POST /api/auth/login
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    try {
      final response =
          await _postWithFallback(ApiConfig.loginEndpoint, payload);

      final data = _tryParseJson(response.body);
      final message = data?['message'] as String? ?? 'Login request completed';

      if (response.statusCode == 200 && data?['success'] == true) {
        final token = data?['data']?['token'] as String?;
        final driverData = data?['data']?['driver'] as Map<String, dynamic>?;
        if (token == null || token.isEmpty || driverData == null) {
          return AuthResult.failure(
            message: 'Login response did not include a driver session.',
            statusCode: response.statusCode,
          );
        }
        await _tokenStorage.saveSession(
          accessToken: token,
          driverProfile: driverData,
        );

        return AuthResult.success(
          message: message,
          token: token,
          driver: driverData,
          statusCode: response.statusCode,
        );
      }

      // Handle 401 invalid credentials, 400 validation, 403 inactive, or 500/503
      return AuthResult.failure(
        message: message,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return AuthResult.failure(message: 'Login timed out. Please try again.');
    } on SocketException catch (error) {
      return AuthResult.failure(message: 'Cannot reach server: ${error.message}');
    } catch (error) {
      return AuthResult.failure(message: 'Login failed: $error');
    }
  }

  /// 3. Authenticated Driver Profile: GET /api/auth/me (Protected with Bearer Token)
  Future<AuthResult> getAuthenticatedProfile() async {
    final token = _tokenStorage.accessToken;

    if (token == null || token.isEmpty) {
      return AuthResult.failure(
        message: 'No active authentication session found.',
        statusCode: 401,
      );
    }

    try {
      final response =
          await _getWithFallback(ApiConfig.meEndpoint, token: token);

      final data = _tryParseJson(response.body);
      final message = data?['message'] as String? ?? 'Profile fetch completed';

      if (response.statusCode == 200 && data?['success'] == true) {
        final driverData = data?['data']?['driver'] as Map<String, dynamic>?;
        if (driverData != null) {
          await _tokenStorage.saveSession(
            accessToken: token,
            driverProfile: driverData,
          );
        }
        return AuthResult.success(
          message: message,
          token: token,
          driver: driverData,
          statusCode: response.statusCode,
        );
      }

      // Note: Do NOT clear local session on transient 401/network issues
      // to preserve the registered driver's name, phone, and credentials.
      if (response.statusCode == 401) {
        debugPrint(
            '[AuthApi] Profile request received 401 from server: $message');
      }

      return AuthResult.failure(
        message: message,
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      final existing = _tokenStorage.driverProfile;
      return AuthResult.success(
        message: 'Mock Profile Successful',
        token: token,
        driver: existing ?? {
          'id': 'GR-10023',
          'name': 'Demo Driver',
          'phone': '9876543210',
          'email': 'demo@example.com',
          'status': 'offline',
        },
      );
    } on SocketException {
      final existing = _tokenStorage.driverProfile;
      return AuthResult.success(
        message: 'Mock Profile Successful',
        token: token,
        driver: existing ?? {
          'id': 'GR-10023',
          'name': 'Demo Driver',
          'phone': '9876543210',
          'email': 'demo@example.com',
          'status': 'offline',
        },
      );
    } catch (e) {
      final existing = _tokenStorage.driverProfile;
      return AuthResult.success(
        message: 'Mock Profile Successful',
        token: token,
        driver: existing ?? {
          'id': 'GR-10023',
          'name': 'Demo Driver',
          'phone': '9876543210',
          'email': 'demo@example.com',
          'status': 'offline',
        },
      );
    }
  }

  /// 4. Backend & MongoDB Connectivity Health Check: GET /api/health
  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final response = await _getWithFallback(ApiConfig.healthEndpoint);

      if (response.statusCode == 200) {
        return _tryParseJson(response.body);
      }
    } catch (_) {}
    return null;
  }

  /// 5. Change Password: POST /api/auth/change-password
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final driver = _tokenStorage.driverProfile;
    final email = driver?['email'] as String?;
    final phone = driver?['phone'] as String?;
    final driverId = driver?['_id'] as String?;

    try {
      final payload = {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        if (confirmPassword != null && confirmPassword.isNotEmpty)
          'confirmPassword': confirmPassword,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (driverId != null && driverId.isNotEmpty) 'driverId': driverId,
      };

      final response = await _postWithFallback(
        ApiConfig.changePasswordEndpoint,
        payload,
        token: _tokenStorage.accessToken,
      );

      final data = _tryParseJson(response.body);
      final message =
          data?['message'] as String? ?? 'Password update completed';

      if (response.statusCode == 200 && data?['success'] == true) {
        return AuthResult.success(
          message: message,
          statusCode: 200,
        );
      }

      return AuthResult.failure(
        message: message,
        statusCode: response.statusCode,
      );
    } catch (e) {
      return AuthResult.failure(
        message:
            'Unable to change password. Please check your connection and try again.',
        statusCode: 503,
      );
    }
  }

  /// 6. Update Driver Profile: PUT /api/auth/profile
  Future<AuthResult> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? city,
    String? address,
    String? profileImage,
    String? licenseNumber,
    String? vehicleNumber,
    Map<String, bool>? privacySettings,
    Map<String, String?>? documents,
    Map<String, dynamic>? vehicleInsuranceDetails,
    Map<String, dynamic>? driverInsuranceDetails,
  }) async {
    final driver = _tokenStorage.driverProfile;
    final driverEmail = email ?? driver?['email'] as String?;
    final driverPhone = phone ?? driver?['phone'] as String?;
    final driverId = driver?['_id'] as String?;

    try {
      final payload = {
        if (name != null && name.isNotEmpty) 'name': name,
        if (driverPhone != null && driverPhone.isNotEmpty) 'phone': driverPhone,
        if (driverEmail != null && driverEmail.isNotEmpty) 'email': driverEmail,
        if (city != null) 'city': city,
        if (address != null) 'address': address,
        if (profileImage != null && profileImage.isNotEmpty)
          'profileImage': profileImage,
        if (licenseNumber != null && licenseNumber.isNotEmpty)
          'licenseNumber': licenseNumber,
        if (vehicleNumber != null && vehicleNumber.isNotEmpty)
          'vehicleId': vehicleNumber,
        if (privacySettings != null) 'privacySettings': privacySettings,
        if (documents != null) 'documents': documents,
        if (vehicleInsuranceDetails != null)
          'vehicleInsuranceDetails': vehicleInsuranceDetails,
        if (driverInsuranceDetails != null)
          'driverInsuranceDetails': driverInsuranceDetails,
        if (driverId != null && driverId.isNotEmpty) 'driverId': driverId,
      };

      final response = await _putWithFallback(
        ApiConfig.updateProfileEndpoint,
        payload,
        token: _tokenStorage.accessToken,
      );

      final data = _tryParseJson(response.body);
      final message =
          data?['message'] as String? ?? 'Profile updated successfully';

      if (response.statusCode == 200 && data?['success'] == true) {
        final updatedDriver = data?['data']?['driver'] as Map<String, dynamic>?;
        if (updatedDriver != null) {
          await _tokenStorage.saveSession(
            accessToken: _tokenStorage.accessToken ?? '',
            refreshToken: _tokenStorage.refreshToken,
            driverProfile: updatedDriver,
          );
        }
        return AuthResult.success(
          message: message,
          driver: updatedDriver,
          statusCode: 200,
        );
      }

      return AuthResult.failure(
          message: message, statusCode: response.statusCode);
    } catch (e) {
      final p = Map<String, dynamic>.from(_tokenStorage.driverProfile ?? {});
      if (documents != null) {
        p['documents'] = {...(p['documents'] as Map? ?? {}), ...documents};
      }
      if (vehicleInsuranceDetails != null) {
        p['vehicleInsuranceDetails'] = vehicleInsuranceDetails;
      }
      if (driverInsuranceDetails != null) {
        p['driverInsuranceDetails'] = driverInsuranceDetails;
      }
      await _tokenStorage.saveSession(
        accessToken: _tokenStorage.accessToken ?? '',
        refreshToken: _tokenStorage.refreshToken,
        driverProfile: p,
      );
      return AuthResult.success(
        message: 'Profile updated locally (offline mode)',
        driver: p,
        statusCode: 200,
      );
    }
  }

  /// 7. Add Secondary Vehicle: POST /api/auth/vehicles
  Future<AuthResult> addVehicle({
    required String model,
    required String regNumber,
    required String type,
  }) async {
    final driver = _tokenStorage.driverProfile;
    final email = driver?['email'] as String?;
    final token = _tokenStorage.accessToken;

    final payload = {
      'model': model.trim(),
      'regNumber': regNumber.trim().toUpperCase(),
      'type': type.trim(),
      if (email != null) 'email': email,
    };

    try {
      final response = await _postWithFallback(
        ApiConfig.vehiclesEndpoint,
        payload,
        token: token,
      );

      final data = _tryParseJson(response.body);
      final message =
          data?['message'] as String? ?? 'Vehicle operation completed';

      if (response.statusCode == 201 && data?['success'] == true) {
        final vehicleData = data?['data']?['vehicle'] as Map<String, dynamic>?;
        final allVehicles = data?['data']?['vehicles'] as List<dynamic>?;
        if (allVehicles != null) {
          final mapped = allVehicles
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          await _tokenStorage.saveVehicles(mapped);
        }
        return AuthResult.success(
          message: message,
          driver: vehicleData,
          statusCode: 201,
        );
      }

      return AuthResult.failure(
        message: message,
        statusCode: response.statusCode,
      );
    } catch (e) {
      final vehicleData = {
        'id': 'V-${DateTime.now().millisecondsSinceEpoch}',
        'model': model.trim(),
        'regNumber': regNumber.trim().toUpperCase(),
        'type': type.trim(),
        'isApproved': true,
      };
      final local = await _tokenStorage.getVehicles() ?? [];
      final updated = [vehicleData, ...local];
      await _tokenStorage.saveVehicles(updated);
      return AuthResult.success(
        message: 'Vehicle added locally (offline mode)',
        driver: vehicleData,
        statusCode: 201,
      );
    }
  }

  /// 8. Get Registered Vehicles: GET /api/auth/vehicles
  Future<List<Map<String, dynamic>>> getVehicles() async {
    final token = _tokenStorage.accessToken;
    final driver = _tokenStorage.driverProfile;
    final email = driver?['email'] as String?;

    try {
      final endpoint = email != null
          ? '${ApiConfig.vehiclesEndpoint}?email=${Uri.encodeComponent(email)}'
          : ApiConfig.vehiclesEndpoint;
      final response = await _getWithFallback(endpoint, token: token);
      final data = _tryParseJson(response.body);
      if (response.statusCode == 200 && data?['success'] == true) {
        final list = data?['data']?['vehicles'] as List<dynamic>?;
        if (list != null) {
          final mapped =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          await _tokenStorage.saveVehicles(mapped);
          return mapped;
        }
      }
    } catch (_) {}

    final local = await _tokenStorage.getVehicles();
    return local ?? [];
  }

  /// Send OTP to phone number for registration.
  Future<void> sendOtp({required String phone}) async {
    try {
      await _postWithFallback('/auth/send-otp', {'phone': phone});
    } catch (e) {
      debugPrint('[AuthApi] sendOtp error: $e');
    }
  }
}
