import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    sessionStorage: ref.watch(sessionStorageProvider),
  );
});
