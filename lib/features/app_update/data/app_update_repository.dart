import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../domain/app_update.dart';

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository(ref.watch(apiClientProvider));
});

/// `app_version.php?platform=…&build=…` (public).
///
/// Fails open: a timeout (5 s), network error, non-`ok` answer or an
/// unreadable build number all come back as `null`, meaning "do nothing".
/// The update check must never stop someone using the app.
class AppUpdateRepository {
  AppUpdateRepository(this._api);

  final ApiClient _api;

  static String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  Future<AppUpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber);
      if (build == null || build <= 0) return null;

      final r = await _api
          .get('/app_version.php',
              queryParameters: {'platform': platform, 'build': build})
          .timeout(const Duration(seconds: 5));
      return switch (r) {
        ApiSuccess(:final value) => AppUpdateInfo.fromJson(value),
        ApiFailure() => null,
      };
    } on Object {
      // TimeoutException, missing plugin, anything else: stay out of the way.
      return null;
    }
  }
}

/// "1.2.0 (7)" for the Profile footer.
final appVersionLabelProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});
