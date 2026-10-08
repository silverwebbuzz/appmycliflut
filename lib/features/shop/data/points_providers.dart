import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../domain/points_models.dart';
import 'store_repository.dart';

/// The signed-in customer's points summary, shared by the Points screen and
/// the entry rows on Profile and Shop.
///
/// Invalidate it after anything that can move points: a successful payment,
/// a cancellation or a return.
final pointsSummaryProvider = FutureProvider<ApiResult<PointsSummary>>((ref) {
  return ref.read(storeRepositoryProvider).pointsSummary();
});

/// Whether to show "Points & Refer" entry points. False while loading, when
/// signed out, when the store is unavailable (404) or points are off, so the
/// row never flashes in and out.
final pointsEntryVisibleProvider = Provider<bool>((ref) {
  return switch (ref.watch(pointsSummaryProvider)) {
    AsyncData(value: ApiSuccess(:final value)) => value.enabled,
    _ => false,
  };
});
