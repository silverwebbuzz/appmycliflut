import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';

/// The two record vaults the API backs.
///
/// The prototype also shows a Bills segment; there is no billing endpoint in
/// the mobile contract, so it is left out rather than stubbed.
enum RecordsTab { prescriptions('Prescriptions'), reports('Lab reports');

  const RecordsTab(this.label);

  final String label;
}

/// Records tab — prescriptions and the patient's own lab report vault.
///
/// Structure only at this stage: the segmented control and empty states are
/// real, and the lists are wired to prescriptions.php / lab_reports.php in a
/// later step.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  RecordsTab _tab = RecordsTab.prescriptions;

  @override
  Widget build(BuildContext context) {
    return AppTabPage(
      title: 'My records',
      children: [
        _RecordsSegmented(
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 14),
        switch (_tab) {
          RecordsTab.prescriptions => const AppPlaceholder(
              icon: AppGlyph.prescription,
              title: 'No prescriptions yet',
              message:
                  'Prescriptions shared by your doctor will appear here. You '
                  'can also upload your own.',
            ),
          RecordsTab.reports => const AppPlaceholder(
              icon: AppGlyph.document,
              title: 'No lab reports yet',
              message:
                  'Upload a report to keep it in one place and share it at '
                  'your next visit.',
            ),
        },
      ],
    );
  }
}

/// The prototype's pill segmented control: a `--chip` track with the active
/// segment raised on `--bg`.
class _RecordsSegmented extends StatelessWidget {
  const _RecordsSegmented({required this.value, required this.onChanged});

  final RecordsTab value;
  final ValueChanged<RecordsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final tab in RecordsTab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(tab),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: tab == value ? t.bg : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: tab == value ? t.ink : t.sub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
