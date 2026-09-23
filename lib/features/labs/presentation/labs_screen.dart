import 'package:flutter/material.dart';

import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';

/// Labs tab — intentionally a placeholder.
///
/// The lab catalog and booking/checkout flow are out of scope until Thyrocare
/// mobile support lands. This tab exists so the nav structure is final and
/// does not shift when that work arrives.
///
/// Note: the patient's own uploaded reports are a separate thing entirely and
/// live under Records (lab_reports.php), not here.
class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppTabPage(
      title: 'Labs',
      children: [
        AppPlaceholder(
          icon: AppGlyph.flask,
          title: 'Lab tests are coming soon',
          message:
              'Booking home sample collection and health checkup packages '
              'will appear here once our lab partner integration is live.\n\n'
              'Looking for a report you already have? Those live under '
              'Records.',
        ),
      ],
    );
  }
}
