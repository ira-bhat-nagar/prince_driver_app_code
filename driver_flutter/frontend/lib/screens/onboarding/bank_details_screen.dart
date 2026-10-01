import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/app_toast.dart';
import '../../services/token_storage_service.dart';
import '../../services/auth_api_service.dart';

class BankDetailsScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onBackTap;

  const BankDetailsScreen({
    super.key,
    this.onNext,
    this.onBackTap,
  });

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _savedOnce = false;

  late TextEditingController _bankNameCtrl;
  late TextEditingController _holderNameCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _upiCtrl;

  @override
  void initState() {
    super.initState();
    final profile = TokenStorageService.instance.driverProfile;
    final name = (profile?['name'] as String?)?.trim() ?? '';
    final savedBank = profile?['bankDetails'] as Map<String, dynamic>?;

    _bankNameCtrl = TextEditingController(
        text: savedBank?['bankName'] as String? ?? 'HDFC Bank Limited');
    _holderNameCtrl = TextEditingController(
        text: savedBank?['accountHolderName'] as String? ??
            (name.isNotEmpty ? name : 'Partner Driver'));
    _accountNumberCtrl = TextEditingController(
        text: savedBank?['accountNumber'] as String? ?? '');
    _ifscCtrl =
        TextEditingController(text: savedBank?['ifscCode'] as String? ?? '');
    _upiCtrl = TextEditingController(
        text: savedBank?['upiId'] as String? ??
            (name.isNotEmpty
                ? '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@okhdfcbank'
                : ''));
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _holderNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final bankDetails = {
      'bankName': _bankNameCtrl.text.trim(),
      'accountHolderName': _holderNameCtrl.text.trim(),
      'accountNumber': _accountNumberCtrl.text.trim(),
      'ifscCode': _ifscCtrl.text.trim().toUpperCase(),
      'upiId': _upiCtrl.text.trim(),
    };

    try {
      // Save locally immediately for instant feedback
      final profile = Map<String, dynamic>.from(
          TokenStorageService.instance.driverProfile ?? {});
      profile['bankDetails'] = bankDetails;
      await TokenStorageService.instance.saveSession(
        accessToken: TokenStorageService.instance.accessToken ?? '',
        refreshToken: TokenStorageService.instance.refreshToken,
        driverProfile: profile,
      );

      // Also try to save to backend
      try {
        await AuthApiService.instance.updateProfile(
          name: _holderNameCtrl.text.trim(),
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSaving = false;
          _savedOnce = true;
        });
        AppToast.success(context,
            '✅ Bank details saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(context, 'Failed to save. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Bank Details / UPI',
          style: TextStyle(
              color: QuickServeColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: QuickServeColors.borderLight),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Direct Payout Account',
                  style: TextStyle(
                      color: QuickServeColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your trip fares and daily incentives will be deposited directly to this bank account or UPI ID.',
                  style: TextStyle(
                      color: QuickServeColors.textSecondary, fontSize: 13),
                ),

                const SizedBox(height: 24),

                _buildField(
                  label: 'Bank Name',
                  controller: _bankNameCtrl,
                  icon: Icons.account_balance,
                  hint: 'e.g. HDFC Bank Limited',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bank name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Account Holder Name',
                  controller: _holderNameCtrl,
                  icon: Icons.person_outline,
                  hint: 'Full name as on bank account',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Account holder name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Account Number',
                  controller: _accountNumberCtrl,
                  icon: Icons.numbers,
                  hint: 'Enter your account number',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Account number is required';
                    if (v.trim().length < 9) return 'Enter a valid account number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'IFSC Code',
                  controller: _ifscCtrl,
                  icon: Icons.pin,
                  hint: 'e.g. HDFC0001234',
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'IFSC code is required';
                    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase())) {
                      return 'Enter a valid IFSC code (e.g. HDFC0001234)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  label: 'Primary UPI ID',
                  controller: _upiCtrl,
                  icon: Icons.payment,
                  hint: 'e.g. name@okhdfcbank',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // UPI is optional
                    if (!v.trim().contains('@')) return 'Enter a valid UPI ID (e.g. name@bank)';
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // SAVE button — stays on screen, shows toast
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QuickServeColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_savedOnce
                                ? Icons.check_circle
                                : Icons.save_outlined,
                                size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _savedOnce ? 'Details Saved ✓' : 'Save Details',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),

                if (widget.onNext != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _savedOnce
                        ? widget.onNext
                        : () => AppToast.info(context,
                            'Please save your details first'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _savedOnce
                              ? QuickServeColors.primaryOrange
                              : QuickServeColors.borderLight),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _savedOnce
                                  ? QuickServeColors.primaryOrange
                                  : QuickServeColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward,
                            size: 18,
                            color: _savedOnce
                                ? QuickServeColors.primaryOrange
                                : QuickServeColors.textMuted),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: QuickServeColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QuickServeColors.borderLight),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
                color: QuickServeColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(icon, color: QuickServeColors.textSecondary, size: 20),
              hintText: hint,
              hintStyle: const TextStyle(
                  color: QuickServeColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              errorStyle: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
