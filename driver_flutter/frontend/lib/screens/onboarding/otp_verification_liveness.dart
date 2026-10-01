import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/app_toast.dart';
import 'driver_login_registration.dart'; // for OtpSession

class OtpVerificationLivenessScreen extends StatefulWidget {
  final VoidCallback? onVerifySuccess;
  final VoidCallback? onBackTap;

  const OtpVerificationLivenessScreen({
    super.key,
    this.onVerifySuccess,
    this.onBackTap,
  });

  @override
  State<OtpVerificationLivenessScreen> createState() =>
      _OtpVerificationLivenessScreenState();
}

class _OtpVerificationLivenessScreenState
    extends State<OtpVerificationLivenessScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  int _resendSeconds = 59;
  Timer? _resendTimer;
  Timer? _clipboardTimer;
  // Show the generated OTP prominently at top
  String _displayedOtp = '';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    if (OtpSession.generatedOtp.isNotEmpty) {
      _displayedOtp = OtpSession.generatedOtp;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fillOtp(OtpSession.generatedOtp);
      });
    } else {
      _startClipboardWatcher();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _resendTimer?.cancel();
    _clipboardTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 59);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds <= 0) { t.cancel(); return; }
      setState(() => _resendSeconds--);
    });
  }

  void _startClipboardWatcher() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        final match = RegExp(r'\b(\d{6})\b').firstMatch(text);
        if (match != null) {
          final otp = match.group(1)!;
          if (_controllers.any((c) => c.text.isEmpty)) {
            _fillOtp(otp);
            _clipboardTimer?.cancel();
          }
        }
      } catch (_) {}
    });
  }

  void _fillOtp(String otp) {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < 6 && i < otp.length; i++) {
        _controllers[i].text = otp[i];
      }
    });
    _focusNodes[5].requestFocus();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(String value, int index) {
    if (value.length == 6) {
      _fillOtp(value);
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyDown(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  void _handleVerify() {
    final otp = _currentOtp;
    if (otp.length < 6) {
      AppToast.error(context, 'Please enter the complete 6-digit OTP');
      return;
    }
    setState(() => _isVerifying = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isVerifying = false);
        widget.onVerifySuccess?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: QuickServeColors.textDark, size: 20),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: QuickServeColors.primaryBlue.withOpacity(0.25),
                        width: 2),
                  ),
                  child: const Icon(Icons.sms_outlined,
                      size: 38, color: QuickServeColors.primaryBlue),
                ),
              ),

              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'OTP Verification',
                  style: TextStyle(
                    color: QuickServeColors.textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Enter the 6-digit code sent to your number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: QuickServeColors.textSecondary, fontSize: 13),
                ),
              ),

              // ── BIG OTP DISPLAY BOX ──────────────────────────────────
              if (_displayedOtp.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR OTP',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Giant OTP digits side by side
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _displayedOtp.split('').map((d) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 38,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // Copy button
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: _displayedOtp));
                          AppToast.success(context, 'OTP copied!');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('Copy OTP',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── 6 LARGE OTP INPUT BOXES ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final filled = _controllers[index].text.isNotEmpty;
                  return SizedBox(
                    width: 48,
                    height: 60,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyDown(event, index),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: filled
                              ? QuickServeColors.primaryBlue
                              : QuickServeColors.textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: filled
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: QuickServeColors.primaryBlue
                                  .withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: QuickServeColors.primaryBlue,
                              width: 2.2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: filled
                                  ? QuickServeColors.primaryBlue
                                  : QuickServeColors.primaryBlue
                                      .withOpacity(0.25),
                              width: filled ? 2 : 1.2,
                            ),
                          ),
                        ),
                        onChanged: (v) => _onDigitChanged(v, index),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 18),

              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive code? ",
                      style: TextStyle(
                          color: QuickServeColors.textSecondary, fontSize: 13)),
                  GestureDetector(
                    onTap: _resendSeconds == 0
                        ? () {
                            _startResendTimer();
                            _startClipboardWatcher();
                            AppToast.success(context, 'OTP resent!');
                          }
                        : null,
                    child: Text(
                      _resendSeconds > 0
                          ? 'Resend in 00:${_resendSeconds.toString().padLeft(2, '0')}'
                          : 'Resend OTP',
                      style: TextStyle(
                        color: _resendSeconds > 0
                            ? QuickServeColors.textSecondary
                            : QuickServeColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Verify button
              ElevatedButton(
                onPressed: _isVerifying ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuickServeColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  shadowColor: QuickServeColors.primaryBlue.withOpacity(0.4),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Verify OTP',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  'GoRush 100% Secure Verification • Encrypted',
                  style: TextStyle(
                      color: QuickServeColors.textMuted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
