import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import 'queue_repository.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepository(ref.watch(apiClientProvider));
});
