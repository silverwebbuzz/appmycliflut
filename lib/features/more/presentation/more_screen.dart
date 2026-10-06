import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../../app_update/data/app_update_repository.dart';
import '../../auth/data/auth_providers.dart';
import '../../family/data/family_providers.dart';
import '../../family/data/family_repository.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_avatar.dart';
import '../../shop/data/cart_controller.dart';

/// More tab — profile, family, shop and health shortcuts, settings, sign-out.
///
/// Profile and family come from `profile.php` / `family.php`. Signed out (or
/// in test mode) the cards fall back to a sign-in prompt; the settings and
/// legal links still work.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  ApiResult<ProfileResult>? _profile;
  ApiResult<FamilyListResult>? _family;

  /// Switch value while a save is in flight (optimistic); null otherwise.
  bool? _waPending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profileFuture = ref.read(profileRepositoryProvider).get();
    final family = await ref.read(familyRepositoryProvider).list();
    final profile = await profileFuture;
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _family = family;
    });
  }

  Future<void> _push(String location) async {
    await context.push(location);
    // Edits happen on the pushed screen; refresh on return.
    if (mounted) _load();
  }

  /// Off stops every WhatsApp message to the login number (reminders,
  /// booking and order updates); the OTP still arrives.
  Future<void> _setWhatsApp(bool on) async {
    setState(() => _waPending = on);
    final r = await ref
        .read(profileRepositoryProvider)
        .save({ProfileFields.waOptIn: on});
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final value):
        setState(() {
          _waPending = null;
          if (_profile case ApiSuccess(value: final old)) {
            _profile = ApiSuccess(ProfileResult(profile: value, options: old.options));
          }
        });
        showAppSnack(
          context,
          on
              ? 'WhatsApp updates are on.'
              : 'WhatsApp updates are off. You will still get login codes.',
        );
      case ApiFailure():
        setState(() => _waPending = null);
        showAppSnack(context, friendlyMessage(r));
    }
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'Log out?',
      message: 'You will need your mobile number to sign back in.',
      confirmLabel: 'Log out',
    );
    if (!ok) return;

    // Revoke the server session first; local data is wiped either way.
    if (await ref.read(sessionStorageProvider).hasToken()) {
      await ref.read(authRepositoryProvider).logout();
    }
    await ref.read(sessionStorageProvider).clearAllSession();
    ProfileAvatar.evict();
    ref.invalidate(cartControllerProvider);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final family = _family;

    return RefreshIndicator(
      onRefresh: _load,
      child: AppTabPage(
        title: 'Profile',
        children: [
          _ProfileCard(
            result: _profile,
            onEdit: () => _push('/profile/edit'),
          ),

          if (family is ApiSuccess<FamilyListResult>) ...[
            const AppSectionLabel('Family members'),
            AppGroup(
              children: [
                for (final m in family.value.members.where((m) => !m.isSelf))
                  AppGroupRow(
                    label: m.name,
                    sub: m.subtitle,
                    leading: AppInitialsTile(
                      text: m.initials ?? m.name[0],
                      size: 38,
                      tone: AppTone.warn,
                    ),
                    onTap: () => _push('/family/${m.id}'),
                  ),
                if (family.value.canAdd)
                  AppGroupRow(
                    label: 'Add family member',
                    emphasised: true,
                    last: true,
                    onTap: () => _push('/family/new'),
                  )
                else
                  AppGroupRow(
                    label: 'Family is full (${family.value.maxMembers} max)',
                    last: true,
                  ),
              ],
            ),
          ],

          const AppSectionLabel('Health'),
          AppGroup(
            children: [
              AppGroupRow(
                label: 'My visits',
                onTap: () => context.push('/appointments'),
              ),
              AppGroupRow(
                label: 'Live queue',
                onTap: () => context.push('/queue'),
              ),
              AppGroupRow(
                label: 'Saved doctors',
                last: true,
                onTap: () => context.push('/saved-doctors'),
              ),
            ],
          ),

          const AppSectionLabel('Shop'),
          AppGroup(
            children: [
              AppGroupRow(
                label: 'My orders',
                onTap: () => context.push('/shop/orders'),
              ),
              AppGroupRow(
                label: 'Wishlist',
                onTap: () => context.push('/shop/wishlist'),
              ),
              AppGroupRow(
                label: 'Saved addresses',
                last: true,
                onTap: () => context.push('/shop/addresses'),
              ),
            ],
          ),

          const AppSectionLabel('Settings'),
          AppGroup(
            children: [
              AppGroupRow(
                label: 'Appearance',
                trailing: _ThemeModePicker(
                  value: mode,
                  onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                ),
                last: _profile is! ApiSuccess<ProfileResult>,
              ),
              if (_profile case ApiSuccess(:final value))
                AppGroupRow(
                  label: 'WhatsApp updates',
                  sub: 'Appointment reminders and order updates',
                  last: true,
                  trailing: Switch.adaptive(
                    value: _waPending ?? value.profile.waOptIn,
                    onChanged: _waPending == null ? _setWhatsApp : null,
                  ),
                ),
            ],
          ),

          const AppSectionLabel('Legal'),
          AppGroup(
            children: [
              for (final (label, path, last) in const [
                ('Privacy policy', 'privacy-policy', false),
                ('Terms of use', 'terms', false),
                ('Refund policy', 'refund-policy', true),
              ])
                AppGroupRow(
                  label: label,
                  last: last,
                  onTap: () => launchUrl(
                    Uri.parse('https://eclinicpro.com/$path'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Destructive action uses --red-soft / --red, per the prototype.
          AppSoftButton(label: 'Log out', tone: AppTone.err, onTap: _logout),
          const SizedBox(height: 14),
          Center(
            child: Text(
              switch (ref.watch(appVersionLabelProvider)) {
                AsyncData(:final value) => 'eClinicPro Patient · Version $value',
                _ => 'eClinicPro Patient',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.result, required this.onEdit});

  final ApiResult<ProfileResult>? result;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final r = result;

    final (Widget avatar, String title, String sub, bool canEdit) = switch (r) {
      ApiSuccess(:final value) => (
          ProfileAvatar(profile: value.profile),
          value.profile.name.isEmpty ? 'Your profile' : value.profile.name,
          value.profile.summary.isEmpty
              ? (value.profile.phone ?? 'Add your details')
              : value.profile.summary,
          true,
        ),
      ApiFailure(:final isLoginRequired) => (
          const ProfileAvatarPlaceholder(),
          'Your profile',
          isLoginRequired
              ? 'Sign in with WhatsApp to edit your profile'
              : friendlyMessage(r),
          false,
        ),
      null => (const ProfileAvatarPlaceholder(), 'Loading…', '', false),
    };

    return Container(
      decoration: t.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(sub, style: text.bodySmall),
              ],
            ),
          ),
          if (canEdit)
            TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
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
