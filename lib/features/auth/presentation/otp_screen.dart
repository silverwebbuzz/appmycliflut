import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_providers.dart';

/// OTP — code arrives on WhatsApp.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.exists,
    this.nameHint,
    this.devCode,
  });

  final String phone;
  final bool exists;
  final String? nameHint;
  final String? devCode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.nameHint != null) {
      _nameController.text = widget.nameHint!;
    }
    if (widget.devCode != null) {
      _codeController.text = widget.devCode!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the 6-digit code from WhatsApp.');
      return;
    }

    final needsName = !widget.exists;
    final name = _nameController.text.trim();
    if (needsName && name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final referral = _referralController.text.trim();
    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(
          phone: widget.phone,
          code: code,
          name: needsName ? name : null,
          referralCode: needsName && referral.isNotEmpty ? referral : null,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case ApiSuccess():
        context.go('/home');
      case ApiFailure(:final error, :final message):
        setState(() => _error = _friendlyError(error, message));
    }
  }

  String _friendlyError(String code, String? message) {
    return switch (code) {
      'invalid_code' => 'That code is incorrect. Check WhatsApp and try again.',
      'expired' => 'Code expired. Go back and request a new one.',
      'no_code_issued' => 'No code was sent. Go back and try again.',
      'too_many_attempts' => 'Too many attempts. Please wait and try again.',
      'network_error' => message ?? 'Check your internet connection.',
      _ => message ?? 'Could not verify. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final needsName = !widget.exists;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        // Scrolls when the keyboard is up on a small phone; otherwise the
        // button still sits at the bottom.
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Verify WhatsApp',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit code from WhatsApp.\nSent to +91 ${widget.phone}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp code',
                        hintText: '••••••',
                      ),
                    ),
                    if (needsName) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          hintText: 'As on clinic records',
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Refer & Earn: new accounts only, never required.
                      TextField(
                        controller: _referralController,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          _UpperCaseFormatter(),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Referral code (optional)',
                          hintText: 'From a friend, e.g. ECP-…',
                        ),
                      ),
                    ],
                    if (widget.devCode != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Dev mode code prefilled: ${widget.devCode}',
                        style: TextStyle(
                          color: AppTokens.of(context).sub,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: AppTokens.of(context).red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Spacer(),
                    FilledButton(
                      onPressed: _loading ? null : _verify,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify & continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) => next.copyWith(text: next.text.toUpperCase());
}
