import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_providers.dart';

/// Login — WhatsApp OTP in production; phone-only when [kSkipWhatsAppOtp].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // TEST: phone only — do not call send_otp (avoids WhatsApp spam).
    if (kSkipWhatsAppOtp) {
      await ref.read(sessionStorageProvider).saveTestSession(phone);
      if (!mounted) return;
      setState(() => _loading = false);
      context.go('/home');
      return;
    }

    final result = await ref.read(authRepositoryProvider).sendOtp(phone: phone);

    if (!mounted) return;

    setState(() => _loading = false);

    switch (result) {
      case ApiSuccess(:final value):
        context.push('/otp', extra: {
          'phone': phone,
          'exists': value.exists,
          'nameHint': value.nameHint,
          'devCode': value.devCode,
        });
      case ApiFailure(:final error, :final message):
        setState(() {
          _error = _friendlyError(error, message);
        });
    }
  }

  String _friendlyError(String code, String? message) {
    return switch (code) {
      'invalid_phone' => 'That phone number looks invalid.',
      'account_not_found' => 'No account found for this number.',
      'account_exists' => 'An account already exists. Try signing in.',
      'resend_too_soon' => 'Please wait a moment before requesting another code.',
      'otp_locked' => 'Too many attempts. Try again later.',
      'network_error' => message ?? 'Check your internet connection.',
      _ => message ?? 'Could not send code. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(AppAssets.logo, height: 40),
              ),
              if (kSkipWhatsAppOtp) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: const Text(
                    'TEST MODE: WhatsApp OTP is off. Enter any 10-digit number to continue.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9A3412)),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text('Welcome', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                kSkipWhatsAppOtp
                    ? 'Enter your mobile number to continue (no WhatsApp code).'
                    : "We'll send a verification code to your WhatsApp.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91  ',
                  hintText: '9876543210',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _continue,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(kSkipWhatsAppOtp ? 'Continue (test)' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
