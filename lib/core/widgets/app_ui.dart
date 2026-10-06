import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/api_config.dart';
import '../network/api_result.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';
import 'app_scaffold.dart';

/// Building blocks shared by the detail screens, transcribed from the
/// prototype's recurring patterns (back square + title header, eyebrow
/// section labels, grouped rows with hairlines, outlined pick chips).

/// Full-screen page pushed above the tabs: chevron back, Sora title, an
/// optional bottom bar, and pull-to-refresh when [onRefresh] is given.
class AppSubPage extends StatelessWidget {
  const AppSubPage({
    super.key,
    required this.title,
    this.children,
    this.body,
    this.actions,
    this.bottomBar,
    this.onRefresh,
    this.fallbackRoute = '/home',
  }) : assert(children != null || body != null);

  final String title;

  /// Scrolling content, laid out with the standard 20px gutter.
  final List<Widget>? children;

  /// Use instead of [children] for a custom body.
  final Widget? body;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;

  /// Where back goes when there is nothing to pop (deep link, cold start).
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    Widget content =
        body ??
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + (bottomBar == null ? MediaQuery.paddingOf(context).bottom : 0),
          ),
          children: children!,
        );
    if (onRefresh != null) {
      content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppGlyph.chevronLeft, color: t.ink, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(fallbackRoute),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [...?actions, const SizedBox(width: 8)],
      ),
      body: content,
      bottomNavigationBar: bottomBar == null
          ? null
          : AppBottomBar(child: bottomBar!),
    );
  }
}

/// The prototype's sticky action bar: translucent `--navbg` over a hairline.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.navBg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, inset > 0 ? inset : 16),
        // A bottom bar is offered the full screen height; the Column makes
        // its content size to itself instead of stretching to fill it.
        child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );
  }
}

/// "FAMILY MEMBERS" — `font:800 11px; letter-spacing:.12em; --sub`.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final label = Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: kFontBody,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.12 * 11,
        color: t.sub,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                trailing!,
              ],
            ),
    );
  }
}

/// Card that groups rows with hairline separators.
class AppGroup extends StatelessWidget {
  const AppGroup({super.key, required this.children});

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

class AppGroupRow extends StatelessWidget {
  const AppGroupRow({
    super.key,
    required this.label,
    this.sub,
    this.leading,
    this.trailing,
    this.onTap,
    this.emphasised = false,
    this.last = false,
  });

  final String label;
  final String? sub;
  final Widget? leading;
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
          border: last ? null : Border(bottom: BorderSide(color: t.line)),
        ),
        padding: EdgeInsets.symmetric(vertical: sub == null ? 13 : 11),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emphasised ? '+ $label' : label,
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: emphasised ? t.brand : t.ink,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: TextStyle(
                        fontFamily: kFontBody,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: t.sub,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null && !emphasised)
              AppIcon(AppGlyph.chevronRight, color: t.sub, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Label/value line used in summaries ("Delivery … ₹49").
class AppKeyValue extends StatelessWidget {
  const AppKeyValue(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: strong ? 13 : 12.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: strong ? t.ink : t.sub,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: strong
                  ? TextStyle(
                      fontFamily: kFontHeading,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? t.ink,
                    )
                  : TextStyle(
                      // Manrope, not Sora: Sora has no ₹ glyph.
                      fontFamily: kFontBody,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? t.ink,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined pick chips (relationship, blood group, sort…). Selected chips
/// fill with `--brand`.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.scroll = false,
  });

  final List<T> options;
  final T? selected;

  /// Called with null when the selected chip is tapped again.
  final ValueChanged<T?> onSelected;
  final String Function(T) labelOf;

  /// Single scrolling row instead of wrapping.
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final chips = [
      for (final o in options)
        GestureDetector(
          onTap: () => onSelected(o == selected ? null : o),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: o == selected ? t.brand : t.card,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: o == selected ? t.brand : t.line),
            ),
            child: Text(
              labelOf(o),
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: o == selected ? t.onAccent : t.ink,
              ),
            ),
          ),
        ),
    ];
    if (scroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in chips)
              Padding(padding: const EdgeInsets.only(right: 8), child: c),
          ],
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

/// The prototype's pill segmented control: a `--chip` track with the active
/// segment raised on `--bg`.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    required this.labelOf,
  });

  final List<T> values;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: v == value ? t.bg : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labelOf(v),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: v == value ? t.ink : t.sub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Eyebrow label above an input, as in the prototype's forms.
class AppLabeledField extends StatelessWidget {
  const AppLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.prefixText,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final String? prefixText;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Field-styled tap target for pickers (date, file). [onClear] adds a ×.
class AppPickerTile extends StatelessWidget {
  const AppPickerTile({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.onClear,
  });

  final AppGlyph glyph;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            AppIcon(glyph, color: t.sub, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: AppIcon(AppGlyph.close, color: t.sub, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

/// Server-driven status tone. The store sends `ok|warn|err|muted`.
enum AppTone { ok, warn, err, muted, brand }

AppTone toneFrom(String? raw) => switch (raw) {
  'ok' => AppTone.ok,
  'warn' => AppTone.warn,
  'err' => AppTone.err,
  'muted' => AppTone.muted,
  _ => AppTone.brand,
};

/// (background, foreground) for a tone. The design is monochrome, so "ok"
/// is ink-on-soft rather than green.
(Color, Color) toneColors(AppTokens t, AppTone tone) => switch (tone) {
  AppTone.ok || AppTone.brand => (t.brandSoft, t.brand),
  AppTone.warn => (t.amberSoft, t.amber),
  AppTone.err => (t.redSoft, t.red),
  AppTone.muted => (t.chip, t.sub),
};

class AppStatusPill extends StatelessWidget {
  const AppStatusPill(this.text, {super.key, this.tone = AppTone.brand});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(AppTokens.of(context), tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.04 * 10,
          color: fg,
        ),
      ),
    );
  }
}

/// Tinted note block (`--amber-soft` notices, `--brand-soft` tips…).
class AppNote extends StatelessWidget {
  const AppNote(this.text, {super.key, this.tone = AppTone.warn});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(AppTokens.of(context), tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12.5,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Soft secondary button (`--brand-soft` fill, brand ink).
class AppSoftButton extends StatelessWidget {
  const AppSoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = AppTone.brand,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final AppTone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(AppTokens.of(context), tone);
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        // Centre horizontally but keep the button's own height: an
        // `alignment` here would stretch it to fill a tall parent.
        child: Center(
          heightFactor: 1,
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kFontBody,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: onTap == null ? fg.withValues(alpha: 0.5) : fg,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Primary filled button with an inline spinner while [busy].
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: t.sub),
            )
          : Text(label),
    );
  }
}

/// Initials (or glyph) on a soft tile — the app's stand-in for photos.
class AppInitialsTile extends StatelessWidget {
  const AppInitialsTile({
    super.key,
    required this.text,
    this.size = 40,
    this.tone = AppTone.brand,
  });

  final String text;
  final double size;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(AppTokens.of(context), tone);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kFontHeading,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

/// A public network image with the prototype's hatched placeholder. Store
/// images may be null; that renders the placeholder too.
class AppNetImage extends StatelessWidget {
  const AppNetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.radius = AppRadii.sm,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final placeholder = Container(
      width: width,
      height: height,
      color: t.chip,
      alignment: Alignment.center,
      child: AppIcon(
        AppGlyph.cart,
        color: t.sub.withValues(alpha: 0.5),
        size: 20,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: fit,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Centered spinner for a page that has nothing to show yet.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Failure state for a load. A `login_required` gets a sign-in prompt
/// rather than an error, since that is the normal signed-out case.
class AppFailureView extends StatelessWidget {
  const AppFailureView({
    super.key,
    required this.failure,
    this.onRetry,
    this.signInMessage = 'Sign in with your mobile number to see this.',
  });

  final ApiFailure<Object?> failure;
  final VoidCallback? onRetry;
  final String signInMessage;

  @override
  Widget build(BuildContext context) {
    if (failure.isLoginRequired) {
      return AppPlaceholder(
        icon: AppGlyph.person,
        title: 'Sign in required',
        message: kSkipWhatsAppOtp
            ? '$signInMessage\n\nTest mode is on, so there is no server '
                  'session. Set kSkipWhatsAppOtp to false and sign in with the '
                  'WhatsApp code to use this.'
            : signInMessage,
        action: kSkipWhatsAppOtp
            ? null
            : FilledButton(
                onPressed: () => context.push('/login'),
                child: const Text('Sign in'),
              ),
      );
    }
    return AppPlaceholder(
      icon: AppGlyph.close,
      title: 'Something went wrong',
      message: friendlyMessage(failure),
      action: onRetry == null
          ? null
          : FilledButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}

/// Text for a failure: the server's own `message` wins (the store writes
/// customer-facing copy there), then known codes, then a generic line.
String friendlyMessage(ApiFailure<Object?> f) {
  if (f.message != null &&
      f.message!.trim().isNotEmpty &&
      f.error != 'server_error') {
    return f.message!;
  }
  return switch (f.error) {
    'network_error' => 'Please check your internet connection.',
    'login_required' => 'Please sign in to continue.',
    'not_found' || 'item_not_found' || 'product_not_found' =>
      'This is no longer available. Please go back and refresh.',
    'store_unavailable' => 'The shop is not available right now.',
    'store_temporarily_unavailable' => 'Please try again shortly.',
    'too_many_attempts' ||
    'too_many_requests' => 'Too many attempts. Please wait a few minutes.',
    'file_too_large' => 'That file is too large.',
    'file_type_not_allowed' => 'That file type is not supported.',
    'name_required' => 'Please enter a name.',
    'label_required' => 'Please enter a title.',
    'email_in_use' => 'That email is already used by another account.',
    'member_limit_reached' => 'You can add up to 6 family members.',
    'cannot_remove_self' => 'You cannot remove your own profile.',
    _ => 'Something went wrong. Please try again.',
  };
}

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Explains why a signed-in action failed and offers the login screen.
Future<void> promptSignIn(BuildContext context, {String? reason}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Sign in to continue'),
      content: Text(
        kSkipWhatsAppOtp
            ? '${reason ?? 'This needs a signed-in account.'}\n\nTest mode is '
                  'on (kSkipWhatsAppOtp), so there is no server session. Turn '
                  'it off and sign in with the WhatsApp code.'
            : reason ?? 'This needs a signed-in account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Not now'),
        ),
        if (!kSkipWhatsAppOtp)
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Sign in'),
          ),
      ],
    ),
  );
  if (go == true && context.mounted) context.push('/login');
}

/// Yes/no confirmation. Returns true only on an explicit confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
