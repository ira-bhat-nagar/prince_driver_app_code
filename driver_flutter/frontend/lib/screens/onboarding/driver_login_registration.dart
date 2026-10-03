import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_toast.dart';
import '../../services/auth_api_service.dart';

// Global OTP session — shared between registration and OTP screens
class OtpSession {
  static String generatedOtp = '';
  static String phoneNumber = '';

  static String generate() {
    final rng = Random();
    generatedOtp = List.generate(6, (_) => rng.nextInt(10)).join();
    return generatedOtp;
  }
}

class DriverLoginRegistrationScreen extends StatefulWidget {
  final VoidCallback? onGetOtp;
  final VoidCallback? onBackTap;
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onRegistrationSuccess;
  final bool otpVerified;

  const DriverLoginRegistrationScreen({
    super.key,
    this.onGetOtp,
    this.onBackTap,
    this.onLoginSuccess,
    this.onRegistrationSuccess,
    this.otpVerified = false,
  });

  @override
  State<DriverLoginRegistrationScreen> createState() =>
      _DriverLoginRegistrationScreenState();
}

class _DriverLoginRegistrationScreenState
    extends State<DriverLoginRegistrationScreen> {
  // Mode: true = Register (matching FINAL UI reference), false = Login
  bool _isRegisterMode = true;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();

  // Controllers for Login Mode
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  bool _isPhoneInput = false;

  @override
  void initState() {
    super.initState();
    if (widget.otpVerified) {
      _phoneController.text = OtpSession.phoneNumber;
    }
    _loginEmailController.addListener(_onLoginEmailChanged);
  }

  void _onLoginEmailChanged() {
    final text = _loginEmailController.text.trim();
    final isPhone = RegExp(r'^\+?[0-9]{5,}$').hasMatch(text);
    if (_isPhoneInput != isPhone) {
      setState(() {
        _isPhoneInput = isPhone;
      });
    }
  }

  @override
  void dispose() {
    _loginEmailController.removeListener(_onLoginEmailChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dateOfBirthController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    if (widget.otpVerified) {
      await _completeRegistration();
      return;
    }

    final phone = _phoneController.text.trim();
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phoneDigits.length < 10) {
      AppToast.error(context, 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);

    // Generate OTP locally (works without SMS gateway)
    OtpSession.generate();
    OtpSession.phoneNumber = phoneDigits;

    if (mounted) setState(() => _isLoading = false);

    if (mounted) {
      if (widget.onGetOtp != null) {
        widget.onGetOtp!();
      } else if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      }
    }

    AuthApiService.instance
        .sendOtp(phone: phoneDigits)
        .catchError((e) => debugPrint('[OTP] Send: $e'));
  }

  Future<void> _completeRegistration() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final dob = _dateOfBirthController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty || dob.isEmpty) {
      AppToast.error(context, 'Please complete all required account details');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      AppToast.error(context, 'Please enter a valid email address');
      return;
    }
    if (password.length < 4) {
      AppToast.error(context, 'Password must be at least 4 characters');
      return;
    }
    final dateOfBirth = DateTime.tryParse(dob);
    if (dateOfBirth == null || !_isAtLeast18(dateOfBirth)) {
      AppToast.error(context, 'Driver must be at least 18 years old');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthApiService.instance.register(
        name: name,
        phone: OtpSession.phoneNumber,
        email: email,
        password: password,
        dateOfBirth: dateOfBirth.toIso8601String(),
      );
      if (!result.success || result.token == null || result.driver == null) {
        throw Exception(result.message.isNotEmpty
            ? result.message
            : 'Unable to create your account. Please try again.');
      }
      if (!mounted) return;
      OtpSession.generatedOtp = '';
      widget.onRegistrationSuccess?.call();
    } catch (error) {
      if (mounted) AppToast.error(context, error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final identifier = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (identifier.isEmpty) {
      AppToast.error(context, 'Please enter your email or phone number');
      return;
    }

    if (password.isEmpty) {
      AppToast.error(context, 'Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthApiService.instance.login(
        email: identifier,
        password: password,
      );

      if (result.success && result.token != null) {
        if (mounted) {
          AppToast.success(context,
              result.message.isNotEmpty ? result.message : 'Login successful!');
        }

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
          return;
        }
      } else if (mounted) {
        AppToast.error(context,
            result.success
                ? 'Login response did not include a session token.'
                : (result.message.isNotEmpty
                    ? result.message
                    : 'Invalid credentials'));
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Login error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back Button (if provided)
              if (widget.onBackTap != null)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Color(0xFF0F172A), size: 20),
                      onPressed: widget.onBackTap,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),

              // 1. Top Brand Logo & App Name
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border:
                        Border.all(color: const Color(0xFFD1FAE5), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.alt_route, color: Colors.white, size: 30),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // GoRush Brand Title
              const Center(
                child: Text(
                  'GoRush',
                  style: TextStyle(
                    color: Color(0xFF1E5AE6),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Driver App Subtitle
              const Center(
                child: Text(
                  'Captain App',
                  style: TextStyle(
                    color: Color(0xFF1E5AE6),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Headline & Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRegisterMode ? 'Create Your Account' : 'Welcome Back',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRegisterMode
                          ? 'Join GoRush and start earning today!'
                          : 'Sign in to access your GoRush driver dashboard.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13.5,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Form Fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _isRegisterMode
                    ? _buildRegisterFields()
                    : _buildLoginFields(),
              ),

              const SizedBox(height: 14),

              // 4. Register / Login Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isRegisterMode ? _handleRegister : _handleLogin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5AE6),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0xFF1E5AE6).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isRegisterMode
                                ? (widget.otpVerified ? 'Register' : 'Get OTP')
                                : 'Login',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 5. Toggle between Register and Login
              if (!widget.otpVerified) Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRegisterMode
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRegisterMode = !_isRegisterMode;
                        });
                      },
                      child: Text(
                        _isRegisterMode ? 'Login' : 'Register',
                        style: const TextStyle(
                          color: Color(0xFF1E5AE6),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 6. Crisp HD Highway & Car Footer Illustration
              Image.asset(
                'assets/create_account_footer.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(height: 80);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterFields() {
    if (widget.otpVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField(
            controller: _nameController,
            hintText: 'Full Name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 8),
          _buildDateOfBirthField(),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _phoneController,
            hintText: 'Mobile Number',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            readOnly: true,
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _emailController,
            hintText: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _passwordController,
            hintText: 'Create Password',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phone Number — only field needed for OTP registration
        _buildInputField(
          controller: _phoneController,
          hintText: 'Enter Mobile Number',
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 6),
        Text(
          'We\'ll send an OTP to verify your number',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  bool _isAtLeast18(DateTime dateOfBirth) {
    final today = DateTime.now();
    final eighteenthBirthday =
        DateTime(dateOfBirth.year + 18, dateOfBirth.month, dateOfBirth.day);
    return !today.isBefore(eighteenthBirthday);
  }

  Widget _buildDateOfBirthField() {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: DateTime(DateTime.now().year - 18),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (selected != null) {
          setState(() {
            _dateOfBirthController.text =
                selected.toIso8601String().split('T').first;
          });
        }
      },
      child: IgnorePointer(
        child: _buildInputField(
          controller: _dateOfBirthController,
          hintText: 'Date of Birth (18+ required)',
          icon: Icons.cake_outlined,
        ),
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      children: [
        _buildInputField(
          controller: _loginEmailController,
          hintText: 'Email or Phone Number',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          controller: _loginPasswordController,
          hintText: 'Password',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                if (widget.onGetOtp != null) {
                  widget.onGetOtp!();
                } else {
                  AppToast.success(context, 'OTP Sent successfully!');
                }
              },
              child: const Text(
                'Login with OTP',
                style: TextStyle(
                  color: Color(0xFF1E5AE6),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                 AppToast.info(context, 'Forgot password feature coming soon');
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              readOnly: readOnly,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
