import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/records_providers.dart';
import '../domain/medical_record.dart';

/// Route segment for each vault: `/records/rx/…`, `/records/lab/…`.
extension RecordKindRoute on RecordKind {
  String get slug => this == RecordKind.prescription ? 'rx' : 'lab';

  static RecordKind fromSlug(String? s) =>
      s == 'lab' ? RecordKind.labReport : RecordKind.prescription;
}

/// Records tab — prescriptions and the patient's own lab-report vault.
///
/// The prototype also shows a Bills segment; there is no billing endpoint in
/// the mobile contract, so it is left out rather than stubbed.
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  RecordKind _tab = RecordKind.prescription;
  final _results = <RecordKind, ApiResult<List<MedicalRecord>>>{};

  @override
  void initState() {
    super.initState();
    _load(_tab);
  }

  Future<void> _load(RecordKind kind) async {
    final r = await ref.read(recordsRepositoryProvider).list(kind);
    if (!mounted) return;
    setState(() => _results[kind] = r);
  }

  void _select(RecordKind kind) {
    setState(() => _tab = kind);
    if (!_results.containsKey(kind)) _load(kind);
  }

  Future<void> _add() async {
    final changed = await context.push<bool>('/records/${_tab.slug}/new');
    if (changed == true) _load(_tab);
  }

  Future<void> _open(MedicalRecord r) async {
    final changed = await context.push<bool>('/records/${r.kind.slug}/${r.id}');
    if (changed == true) _load(r.kind);
  }

  @override
  Widget build(BuildContext context) {
    final r = _results[_tab];
    return RefreshIndicator(
      onRefresh: () => _load(_tab),
      child: AppTabPage(
        title: 'My records',
        actions: [
          if (r is ApiSuccess)
            TextButton(onPressed: _add, child: const Text('+ Add')),
        ],
        children: [
          AppSegmented<RecordKind>(
            values: RecordKind.values,
            value: _tab,
            onChanged: _select,
            labelOf: (k) =>
                k == RecordKind.prescription ? 'Prescriptions' : 'Lab reports',
          ),
          const SizedBox(height: 14),
          ...switch (r) {
            null => const [AppLoadingView()],
            ApiFailure() => [
                AppFailureView(
                  failure: r,
                  onRetry: () => _load(_tab),
                  signInMessage:
                      'Your prescriptions and reports are private to your '
                      'account. Sign in to see them.',
                ),
              ],
            ApiSuccess(:final value) when value.isEmpty => [
                AppPlaceholder(
                  icon: _tab == RecordKind.prescription
                      ? AppGlyph.prescription
                      : AppGlyph.document,
                  title: _tab == RecordKind.prescription
                      ? 'No prescriptions yet'
                      : 'No lab reports yet',
                  message: _tab == RecordKind.prescription
                      ? 'Prescriptions shared by your doctor will appear '
                          'here. You can also upload your own.'
                      : 'Upload a report to keep it in one place and share it '
                          'at your next visit.',
                  action: FilledButton(
                    onPressed: _add,
                    child: Text(_tab == RecordKind.prescription
                        ? 'Upload a prescription'
                        : 'Upload a report'),
                  ),
                ),
              ],
            ApiSuccess(:final value) => [
                for (final rec in value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecordCard(record: rec, onTap: () => _open(rec)),
                  ),
              ],
          },
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final MedicalRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final isRx = record.kind == RecordKind.prescription;
    final meta = [
      if (record.subtitle != null) record.subtitle!,
      if (record.dateIso != null) formatDate(record.dateIso),
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          decoration: t.cardDecoration,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRx ? t.brandSoft : t.amberSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcon(
                  isRx ? AppGlyph.prescription : AppGlyph.document,
                  color: isRx ? t.brand : t.amber,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.label, style: text.labelLarge),
                    if (meta.isNotEmpty) Text(meta, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppStatusPill(
                record.isClinic ? 'From clinic' : 'Uploaded',
                tone: record.isClinic ? AppTone.brand : AppTone.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
