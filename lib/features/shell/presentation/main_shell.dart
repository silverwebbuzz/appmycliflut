import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../shop/data/cart_controller.dart';
import '../../shop/presentation/shop_widgets.dart';

/// The five primary destinations, in tab order.
///
/// Matches the design prototype's six-tab bottom nav. The Profile tab is
/// still routed at `/more`: it holds profile, family, settings and links.
enum ShellTab {
  home('Home', '/home'),
  doctors('Doctors', '/doctors'),
  labs('Labs', '/labs'),
  shop('Shop', '/shop'),
  records('Records', '/records'),
  more('Profile', '/more');

  const ShellTab(this.label, this.path);

  final String label;
  final String path;

  /// Tabs actually shown, in order. The router builds one branch per entry,
  /// so branch index == position in this list.
  static List<ShellTab> get visible => [
        for (final t in values)
          if (t != ShellTab.labs || kLabsEnabled) t,
      ];
}

/// Bottom tab scaffold for the signed-in app.
///
/// The bar is drawn by hand rather than with [NavigationBar] so it can match
/// the prototype exactly: a translucent blurred `--navbg` surface, a 1px
/// `--line` top border, 21px stroked icons and 10px/w700 Manrope labels,
/// with no Material selection pill.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // Tapping the active tab pops that branch back to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The nav bar is translucent, so content scrolls underneath it.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _ShellNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

class _ShellNavBar extends ConsumerWidget {
  const _ShellNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cartCount = ref.watch(cartCountProvider);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.navBg,
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: Padding(
            // Prototype pads 10px top / 28px bottom; on hardware the home
            // indicator supplies that bottom space instead.
            padding: EdgeInsets.fromLTRB(
              8,
              10,
              8,
              bottomInset > 0 ? bottomInset : 16,
            ),
            child: Row(
              children: [
                for (final (i, tab) in ShellTab.visible.indexed)
                  Expanded(
                    child: _NavItem(
                      tab: tab,
                      selected: i == currentIndex,
                      badge: tab == ShellTab.shop ? cartCount : 0,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  /// Cart count on the Shop tab; 0 hides it.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = selected ? t.ink : t.sub;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: 21,
                    width: 21,
                    child: CustomPaint(
                      painter: _TabIconPainter(tab: tab, color: color),
                    ),
                  ),
                  if (badge > 0)
                    Positioned(top: -6, right: -12, child: CountBadge(badge)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the prototype's stroked 24x24 tab glyphs.
///
/// These are transcribed from the SVG paths in the prototype's nav bar so the
/// icon set matches the design rather than approximating it with Material
/// icons, whose weights and corner radii read noticeably heavier.
class _TabIconPainter extends CustomPainter {
  const _TabIconPainter({required this.tab, required this.color});

  final ShellTab tab;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (tab) {
      case ShellTab.home:
        // M4 11l8-7 8 7v9h-5.5v-5.5h-5V20H4z
        canvas.drawPath(
          Path()
            ..moveTo(4, 11)
            ..lineTo(12, 4)
            ..lineTo(20, 11)
            ..lineTo(20, 20)
            ..lineTo(14.5, 20)
            ..lineTo(14.5, 14.5)
            ..lineTo(9.5, 14.5)
            ..lineTo(9.5, 20)
            ..lineTo(4, 20)
            ..close(),
          stroke,
        );

      case ShellTab.doctors:
        // circle(11,11,6.5) + M16 16l5 5
        canvas.drawCircle(const Offset(11, 11), 6.5, stroke);
        canvas.drawLine(const Offset(16, 16), const Offset(21, 21), stroke);

      case ShellTab.labs:
        // Flask: M9.5 3v6L4.8 17.6A2 2 0 006.6 20.5h10.8a2 2 0 001.8-2.9L14.5 9V3
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 3)
            ..lineTo(9.5, 9)
            ..lineTo(4.8, 17.6)
            ..cubicTo(4.1, 18.9, 5.1, 20.5, 6.6, 20.5)
            ..lineTo(17.4, 20.5)
            ..cubicTo(18.9, 20.5, 19.9, 18.9, 19.2, 17.6)
            ..lineTo(14.5, 9)
            ..lineTo(14.5, 3),
          stroke,
        );
        canvas.drawLine(const Offset(8, 3), const Offset(16, 3), stroke);

      case ShellTab.shop:
        // Prototype cart: M4 5h2.2l2.2 10.5h9.1L20 8H7 + two wheels.
        canvas.drawPath(
          Path()
            ..moveTo(4, 5)
            ..lineTo(6.2, 5)
            ..lineTo(8.4, 15.5)
            ..lineTo(17.5, 15.5)
            ..lineTo(20, 8)
            ..lineTo(7, 8),
          stroke,
        );
        canvas.drawCircle(const Offset(10, 19.2), 1.4, fill);
        canvas.drawCircle(const Offset(17, 19.2), 1.4, fill);

      case ShellTab.records:
        // rect(5,3,14,18,r2.5) + three rules
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 3, 14, 18),
            const Radius.circular(2.5),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(9, 8), const Offset(15, 8), stroke);
        canvas.drawLine(const Offset(9, 12), const Offset(15, 12), stroke);
        canvas.drawLine(const Offset(9, 16), const Offset(13, 16), stroke);

      case ShellTab.more:
        // Prototype Profile glyph: circle(12,8,4) + shoulders.
        canvas.drawCircle(const Offset(12, 8), 4, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 20.5)
            ..cubicTo(6, 16.5, 9, 15, 12, 15)
            ..cubicTo(15, 15, 18, 16.5, 19.5, 20.5),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.color != color || old.tab != tab;
}
