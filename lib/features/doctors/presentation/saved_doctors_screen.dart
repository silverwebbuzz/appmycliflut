import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/doctors_providers.dart';
import '../data/doctors_repository.dart';
import 'widgets/doctor_card.dart';

/// Saved doctors — `doctors.php?action=saved`.
class SavedDoctorsScreen extends ConsumerStatefulWidget {
  const SavedDoctorsScreen({super.key});

  @override
  ConsumerState<SavedDoctorsScreen> createState() => _SavedDoctorsScreenState();
}

class _SavedDoctorsScreenState extends ConsumerState<SavedDoctorsScreen> {
  ApiResult<SavedDoctors>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(doctorsRepositoryProvider).saved();
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AppSubPage(
      title: 'Saved doctors',
      fallbackRoute: '/more',
      onRefresh: _load,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) when value.items.isEmpty => [
            AppPlaceholder(
              icon: AppGlyph.heart,
              title: 'No saved doctors',
              message: 'Tap the heart on a doctor\'s page to keep them here '
                  '(up to ${value.max}).',
              action: FilledButton(
                onPressed: () => context.go('/doctors'),
                child: const Text('Find a doctor'),
              ),
            ),
          ],
        ApiSuccess(:final value) => [
            Text(
              '${value.items.length} of ${value.max} saved',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (final d in value.items) DoctorCard(doctor: d),
          ],
      },
    );
  }
}
