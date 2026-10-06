import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';
import 'shop_widgets.dart';

/// Wishlist — `store_wishlist.php`. Products no longer sold drop out
/// server-side.
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  ApiResult<List<ProductCard>>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).wishlist();
    if (mounted) setState(() => _result = r);
  }

  Future<void> _remove(ProductCard p) async {
    final r = await ref.read(storeRepositoryProvider).toggleWishlist(p.id);
    if (!mounted) return;
    if (r is ApiFailure<bool>) {
      showAppSnack(context, friendlyMessage(r));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final t = AppTokens.of(context);
    return AppSubPage(
      title: 'Wishlist',
      fallbackRoute: '/shop',
      onRefresh: _load,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [
            AppFailureView(
              failure: r,
              onRetry: _load,
              signInMessage: 'Sign in to see the products you saved.',
            ),
          ],
        ApiSuccess(:final value) when value.isEmpty => [
            AppPlaceholder(
              icon: AppGlyph.heart,
              title: 'Nothing saved yet',
              message: 'Tap the heart on a product to keep it here.',
              action: FilledButton(
                onPressed: () => context.go('/shop'),
                child: const Text('Browse the shop'),
              ),
            ),
          ],
        ApiSuccess(:final value) => [
            for (final p in value)
              ProductRowCard(
                product: p,
                trailing: GestureDetector(
                  onTap: () => _remove(p),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AppIcon(AppGlyph.heartFilled, color: t.ink, size: 20),
                  ),
                ),
              ),
          ],
      },
    );
  }
}
