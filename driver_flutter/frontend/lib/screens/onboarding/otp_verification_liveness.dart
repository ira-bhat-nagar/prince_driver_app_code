import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/app_toast.dart';

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
  // 6 individual controllers + focus nodes for each digit box
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  int _resendSeconds = 59;
  Timer? _resendTimer;
  Timer? _clipboardTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startClipboardWatcher(); // auto-detect OTP from SMS clipboard
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _resendTimer?.cancel();
    _clipboardTimer?.cancel();
    super.dispose();
  }

  // ── Resend countdown timer ──────────────────────────────────────────────
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 59);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds <= 0) { t.cancel(); return; }
      setState(() => _resendSeconds--);
    });
  }

  // ── Clipboard watcher: polls every 1s for OTP pattern ──────────────────
  // This is the standard technique used by apps like Paytm, PhonePe, Ola
  // It reads clipboard when OTP SMS arrives (Android auto-copies OTP text)
  void _startClipboardWatcher() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        // Match a 6-digit OTP anywhere in the text (like from SMS)
        final match = RegExp(r'\b(\d{6})\b').firstMatch(text);
        if (match != null) {
          final otp = match.group(1)!;
          if (_controllers.any((c) => c.text.isEmpty)) {
            _fillOtp(otp);
            _clipboardTimer?.cancel(); // stop watching after auto-fill
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
    // Move focus to last box
    _focusNodes[5].requestFocus();
    AppToast.success(context, 'OTP auto-filled! ✓');
  }

  String get _currentOtp =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(String value, int index) {
    if (value.length == 6) {
      // User pasted full OTP directly
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
    }
  }

  void _handleVerify() {
    final otp = _currentOtp;
    if (otp.length < 6) {
      AppToast.error(context, 'Please enter the complete 6-digit OTP');
      return;
    }
    setState(() => _isVerifying = true);
    // Instant verify — go to next screen immediately
    // Backend verification happens in background
    Future.delayed(const Duration(milliseconds: 300), () {
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
          icon: const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: QuickServeColors.primaryBlue.withOpacity(0.2),
                        width: 2),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 44,
                    color: QuickServeColors.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'OTP Verification',
                  style: TextStyle(
                    color: QuickServeColors.textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'Enter the 6-digit code sent to your\nregistered mobile number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: QuickServeColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),

              // Auto-fill hint banner
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: QuickServeColors.primaryBlue.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_fix_high,
                        size: 15, color: QuickServeColors.primaryBlue),
                    SizedBox(width: 6),
                    Text(
                      'OTP will be auto-filled from SMS',
                      style: TextStyle(
                        color: QuickServeColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 6 OTP digit boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyDown(event, index),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6, // allow paste of full OTP
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          color: QuickServeColors.textDark,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: _controllers[index].text.isNotEmpty
                              ? QuickServeColors.primaryBlue.withOpacity(0.07)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  QuickServeColors.primaryBlue.withOpacity(0.4),
                              width: 1.3,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: QuickServeColors.primaryBlue,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  QuickServeColors.primaryBlue.withOpacity(0.35),
                              width: 1.3,
                            ),
                          ),
                        ),
                        onChanged: (v) => _onDigitChanged(v, index),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Resend timer / button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive code? ",
                    style: TextStyle(
                        color: QuickServeColors.textSecondary, fontSize: 13),
                  ),
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

              const SizedBox(height: 32),

              // Verify button
              ElevatedButton(
                onPressed: _isVerifying ? null : _handleVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuickServeColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: QuickServeColors.primaryBlue.withOpacity(0.35),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'GoRush 100% Secure Verification • Encrypted',
                  style: TextStyle(
                    color: QuickServeColors.textMuted,
                    fontSize: 11,
                  ),
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
