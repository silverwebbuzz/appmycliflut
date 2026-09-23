import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_icon.dart';

/// Standard scroll layout for a tab root.
///
/// The prototype gives every tab screen `padding:64px 20px 110px` — 64 top to
/// clear the status bar, 110 bottom so content clears the translucent nav
/// bar. Here the top comes from the real safe area and the bottom from the
/// nav bar height, so it adapts to the device instead of assuming iPhone
/// chrome.
class AppTabPage extends StatelessWidget {
  const AppTabPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.controller,
  });

  /// Large Sora screen title, e.g. "My records".
  final String title;
  final List<Widget> children;

  /// Optional trailing controls rendered on the title row.
  final List<Widget>? actions;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        // Clears the ~86px nav bar plus breathing room.
        110 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: text.headlineLarge)),
            ...?actions,
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

/// Neutral empty/placeholder state: an outlined glyph tile, a Sora line and
/// a muted Manrope explanation.
class AppPlaceholder extends StatelessWidget {
  const AppPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final AppGlyph icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: t.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Center(child: AppIcon(icon, color: t.ink, size: 24)),
          ),
          const SizedBox(height: 14),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
