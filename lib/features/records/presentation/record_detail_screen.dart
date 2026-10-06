import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/file_actions.dart';
import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/records_providers.dart';
import '../domain/medical_record.dart';

/// One prescription or lab report: its metadata plus the attached file.
///
/// The database stores a file and a label snapshot only — no medicine lines,
/// results or ranges — so the design's itemised Rx card and trend chart are
/// not rendered. Images show inline; PDFs open in the system viewer. Both
/// are fetched with the Bearer header, since `?action=file` is not public.
///
/// Pops `true` when the record was removed, so the list can refresh.
class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.kind, required this.id});

  final RecordKind kind;
  final int id;

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  ApiResult<MedicalRecord>? _result;
  Uint8List? _bytes;
  String? _fileError;
  bool _fileLoading = false;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(recordsRepositoryProvider).detail(widget.kind, widget.id);
    if (!mounted) return;
    setState(() => _result = r);
    if (r case ApiSuccess(:final value) when value.isImage) _fetchFile();
  }

  Future<Uint8List?> _fetchFile() async {
    if (_bytes != null) return _bytes;
    setState(() {
      _fileLoading = true;
      _fileError = null;
    });
    final r = await ref.read(recordsRepositoryProvider).file(widget.kind, widget.id);
    if (!mounted) return null;
    setState(() {
      _fileLoading = false;
      switch (r) {
        case ApiSuccess(:final value):
          _bytes = value;
        case ApiFailure():
          _fileError = friendlyMessage(r);
      }
    });
    return _bytes;
  }

  Future<void> _openExternally(MedicalRecord rec) async {
    final bytes = await _fetchFile();
    if (bytes == null || !mounted) return;
    final ext = rec.isPdf ? 'pdf' : (rec.fileMime?.split('/').last ?? 'jpg');
    final err = await openBytesExternally(bytes, '${rec.kind.name}-${rec.id}.$ext');
    if (err != null && mounted) showAppSnack(context, err);
  }

  Future<void> _remove(MedicalRecord rec) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this ${rec.kind.label.toLowerCase()}?',
      message: 'It will be removed from your records.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _removing = true);
    final r = await ref.read(recordsRepositoryProvider).remove(rec.kind, rec.id);
    if (!mounted) return;
    setState(() => _removing = false);
    switch (r) {
      case ApiSuccess():
        context.pop(true);
      case ApiFailure():
        showAppSnack(context, friendlyMessage(r));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AppSubPage(
      title: widget.kind.label,
      fallbackRoute: '/records',
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _content(context, value),
      },
    );
  }

  List<Widget> _content(BuildContext context, MedicalRecord rec) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final isRx = rec.kind == RecordKind.prescription;

    return [
      Container(
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.label, style: text.titleMedium),
            const SizedBox(height: 6),
            AppStatusPill(
              rec.isClinic ? 'Shared by clinic' : 'Uploaded by you',
              tone: rec.isClinic ? AppTone.brand : AppTone.muted,
            ),
          ],
        ),
      ),
      const AppSectionLabel('Details'),
      AppGroup(
        children: [
          if (rec.dateIso != null)
            AppGroupRow(
              label: isRx ? 'Issued on' : 'Reported on',
              trailing: Text(formatDate(rec.dateIso), style: text.bodyMedium),
            ),
          if (rec.testType != null)
            AppGroupRow(
              label: 'Test type',
              trailing: Text(rec.testType!, style: text.bodyMedium),
            ),
          if (rec.labName != null)
            AppGroupRow(
              label: 'Lab',
              trailing: Text(rec.labName!, style: text.bodyMedium),
            ),
          if (rec.doctorName != null)
            AppGroupRow(
              label: 'Doctor',
              trailing: Text(rec.doctorName!, style: text.bodyMedium),
            ),
          if (rec.clinicName != null)
            AppGroupRow(
              label: 'Clinic',
              trailing: Text(rec.clinicName!, style: text.bodyMedium),
            ),
          AppGroupRow(
            label: 'Attachment',
            last: true,
            trailing: Text(
              !rec.hasFile ? 'None' : (rec.isPdf ? 'PDF' : 'Image'),
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
      if (rec.notes != null) ...[
        const AppSectionLabel('Notes'),
        AppNote(rec.notes!, tone: AppTone.brand),
      ],
      if (rec.hasFile) ...[
        const AppSectionLabel('File'),
        if (_bytes != null && rec.isImage)
          GestureDetector(
            onTap: () => _openExternally(rec),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          )
        else if (_fileLoading)
          const AppLoadingView()
        else if (_fileError != null)
          AppNote(_fileError!, tone: AppTone.err),
        const SizedBox(height: 10),
        AppSoftButton(
          label: rec.isPdf ? 'Open PDF' : 'Open full size',
          busy: _fileLoading,
          onTap: () => _openExternally(rec),
        ),
      ],
      const SizedBox(height: 22),
      AppSoftButton(
        label: 'Delete',
        tone: AppTone.err,
        busy: _removing,
        onTap: () => _remove(rec),
      ),
    ];
  }
}
