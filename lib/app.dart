import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

class EClinicProApp extends StatelessWidget {
  EClinicProApp({super.key});

  final _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _AppRoot(router: _router),
    );
  }
}

/// Split out so the theme mode can be watched inside the [ProviderScope].
class _AppRoot extends ConsumerWidget {
  const _AppRoot({required this.router});

  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'eClinicPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
