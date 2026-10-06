import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../shop/data/payment_flow.dart';
import '../data/app_update_repository.dart';
import '../domain/app_update.dart';

/// SharedPreferences key: the `latest_build` the user answered "Later" to.
const String kUpdateDismissedBuildKey = 'ecp_update_dismissed_build';

/// Checks `app_version.php` and prompts to update.
///
/// - Once after the first frame (in the background, never delaying startup),
///   then on return to the foreground when the last check is over 6 hours old.
/// - Waits for the splash to finish and for any open Razorpay sheet to close.
/// - `required`: full-screen, cannot be dismissed, shown again if anything
///   closes it. `optional`: Update / Later; "Later" hides it until a newer
///   `latest_build` is published.
/// - Any failure means no dialog: the check never blocks the app itself.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  static const _recheckAfter = Duration(hours: 6);

  DateTime? _lastCheck;
  bool _checking = false;
  bool _dialogOpen = false;

  /// A required update stays in force for the life of this process.
  AppUpdateInfo? _required;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_required != null) {
      // Back from the store without updating.
      _present(_required!);
      return;
    }
    final last = _lastCheck;
    if (last == null || DateTime.now().difference(last) > _recheckAfter) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final info = await ref.read(appUpdateRepositoryProvider).check();
      if (info == null || !info.actionable || !mounted) return;

      if (info.kind == UpdateKind.required) {
        _required = info;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getInt(kUpdateDismissedBuildKey);
        if (dismissed != null && dismissed == info.latestBuild) return;
      }
      await _present(info);
    } finally {
      _checking = false;
    }
  }

  /// Not over the splash, and never over an open payment sheet.
  bool get _canShowNow {
    if (paymentInProgress.value) return false;
    if (rootNavigatorKey.currentContext == null) return false;
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    return path.isNotEmpty && path != '/splash';
  }

  Future<void> _present(AppUpdateInfo info) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      while (mounted && !_canShowNow) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;

      final required = info.kind == UpdateKind.required;
      final result = await showDialog<String>(
        context: rootNavigatorKey.currentContext!,
        barrierDismissible: !required,
        useSafeArea: !required,
        builder: (_) => UpdateDialog(info: info),
      );

      if (result == 'later' && info.latestBuild != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(kUpdateDismissedBuildKey, info.latestBuild!);
      }
      // A required dialog cannot be closed by the user, but a navigation
      // (e.g. sign-in → home) replaces the route stack and drops it.
      if (required && mounted) {
        _dialogOpen = false;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _present(info);
      }
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The update prompt. Pops `'later'` when the optional one is postponed.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.info});

  final AppUpdateInfo info;

  bool get _required => info.kind == UpdateKind.required;

  Future<void> _openStore() async {
    final uri = Uri.tryParse(info.storeUrl ?? '');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    final body = Column(
      mainAxisSize: _required ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_required) const Spacer(),
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: AppIcon(AppGlyph.check, color: t.brand, size: 28),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          info.title ?? (_required ? 'Update required' : 'Update available'),
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        if (info.latestVersion != null) ...[
          const SizedBox(height: 4),
          Text(
            'Version ${info.latestVersion}',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
        if (info.message != null) ...[
          const SizedBox(height: 12),
          Text(info.message!, textAlign: TextAlign.center, style: text.bodyMedium),
        ],
        if (info.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            decoration: t.cardDecoration,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in info.notes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: text.bodyMedium),
                        Expanded(child: Text(n, style: text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_required) const Spacer(),
        const SizedBox(height: 22),
        FilledButton(onPressed: _openStore, child: const Text('Update')),
        if (!_required) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop('later'),
            child: const Text('Later'),
          ),
        ],
      ],
    );

    if (_required) {
      return PopScope(
        canPop: false,
        child: Dialog.fullscreen(
          backgroundColor: t.bg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: body,
            ),
          ),
        ),
      );
    }
    return Dialog(
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        child: SingleChildScrollView(child: body),
      ),
    );
  }
}
