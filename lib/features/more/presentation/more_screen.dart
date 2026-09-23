import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';

/// More tab — profile summary, family, settings and sign-out.
///
/// Replaces the old 47-line Profile placeholder. The profile card and the
/// family list are rendered from local state here; profile.php and family.php
/// are wired in a later step, at which point the hardcoded shell below is
/// replaced by real data rather than extended.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need your mobile number to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(sessionStorageProvider).clearAllSession();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final mode = ref.watch(themeModeProvider);
    return AppTabPage(
      title: 'More',
      children: [
        const _ProfileCard(),
        const SizedBox(height: 20),

        _SectionLabel('Family members'),
        const SizedBox(height: 8),
        _Group(
          children: [
            _Row(
              label: 'Add family member',
              emphasised: true,
              onTap: () => _notYet(context, 'Family members'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _SectionLabel('Settings'),
        const SizedBox(height: 8),
        _Group(
          children: [
            _Row(
              label: 'Appearance',
              trailing: _ThemeModePicker(
                value: mode,
                onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
              ),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Destructive action uses --red-soft / --red, per the prototype.
        GestureDetector(
          onTap: () => _logout(context, ref),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: t.redSoft,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'Log out',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: t.red,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'eClinicPro Patient',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _notYet(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming in the next update.')),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: t.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: AppIcon(AppGlyph.person, color: t.ink, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your profile', style: text.titleLarge),
                const SizedBox(height: 2),
                Text('Tap edit to add your details', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: kFontBody,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.12 * 11,
        color: t.sub,
      ),
    );
  }
}

/// Card that groups rows with hairline separators, as in the prototype.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTokens.of(context).cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.trailing,
    this.onTap,
    this.emphasised = false,
    this.last = false,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Renders the label in brand ink, for affordances like "+ Add member".
  final bool emphasised;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: t.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                emphasised ? '+ $label' : label,
                style: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: emphasised ? t.brand : t.ink,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              AppIcon(AppGlyph.chevronRight, color: t.sub, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Three-way appearance control (System / Light / Dark).
///
/// The prototype shows a plain dark-mode switch, but a binary switch cannot
/// express "follow the OS", which is the sensible default and what the app
/// starts in. A segmented picker keeps that state reachable.
class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = <(ThemeMode, String)>[
    (ThemeMode.system, 'Auto'),
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, label) in _options)
            GestureDetector(
              onTap: () => onChanged(mode),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: mode == value ? t.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kFontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: mode == value ? t.ink : t.sub,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
