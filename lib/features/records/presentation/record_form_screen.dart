import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/file_actions.dart';
import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_ui.dart';
import '../../family/data/family_providers.dart';
import '../../family/domain/family_member.dart';
import '../data/records_providers.dart';
import '../domain/medical_record.dart';

/// Upload a prescription or lab report — multipart `?action=add`.
///
/// Only the title is required; the file is optional (PDF/JPEG/PNG/WebP, up
/// to 10 MB). Pops `true` on success so the list refreshes.
class RecordFormScreen extends ConsumerStatefulWidget {
  const RecordFormScreen({super.key, required this.kind});

  final RecordKind kind;

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _label = TextEditingController();
  final _doctor = TextEditingController();
  final _clinic = TextEditingController();
  final _lab = TextEditingController();
  final _testType = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date;
  PickedFile? _file;
  List<FamilyMember> _members = const [];
  FamilyMember? _member;
  bool _saving = false;
  String? _error;

  bool get _isRx => widget.kind == RecordKind.prescription;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    for (final c in [_label, _doctor, _clinic, _lab, _testType, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Optional: lets a record be filed under a family member. A failure here
  /// just hides the picker.
  Future<void> _loadFamily() async {
    final r = await ref.read(familyRepositoryProvider).list();
    if (!mounted) return;
    if (r case ApiSuccess(:final value)) {
      setState(() => _members = value.members.where((m) => !m.isSelf).toList());
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickFile() async {
    final f = await pickDocumentOrPhoto(context);
    if (f != null) setState(() => _file = f);
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await ref.read(recordsRepositoryProvider).add(
          widget.kind,
          label: _label.text.trim(),
          doctorName: _doctor.text.trim(),
          clinicName: _isRx ? _clinic.text.trim() : null,
          labName: _isRx ? null : _lab.text.trim(),
          testType: _isRx ? null : _testType.text.trim(),
          notes: _notes.text.trim(),
          dateIso: _date == null ? null : toIsoDate(_date!),
          familyMemberId: _member?.id,
          filePath: _file?.path,
          fileName: _file?.name,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case ApiSuccess():
        showAppSnack(context, '${widget.kind.label} saved');
        context.pop(true);
      case ApiFailure(:final error):
        setState(() => _error = switch (error) {
              'file_too_large' => 'That file is over 10 MB. Try a smaller one.',
              'file_type_not_allowed' => 'Only PDF, JPEG, PNG or WebP files.',
              _ => friendlyMessage(r),
            });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppSubPage(
      title: _isRx ? 'Add prescription' : 'Add lab report',
      fallbackRoute: '/records',
      bottomBar: AppPrimaryButton(
        label: 'Save',
        busy: _saving,
        onPressed: _save,
      ),
      children: [
        AppLabeledField(
          label: 'Title',
          controller: _label,
          hint: _isRx ? 'e.g. Dr. Shah — Diabetes review' : 'e.g. HbA1c — Aug 2026',
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_isRx) ...[
          AppLabeledField(
            label: 'Doctor · optional',
            controller: _doctor,
            textCapitalization: TextCapitalization.words,
          ),
          AppLabeledField(
            label: 'Clinic · optional',
            controller: _clinic,
            textCapitalization: TextCapitalization.words,
          ),
        ] else ...[
          AppLabeledField(
            label: 'Test type · optional',
            controller: _testType,
            hint: 'Blood, urine, imaging…',
            textCapitalization: TextCapitalization.sentences,
          ),
          AppLabeledField(
            label: 'Lab · optional',
            controller: _lab,
            textCapitalization: TextCapitalization.words,
          ),
          AppLabeledField(
            label: 'Referring doctor · optional',
            controller: _doctor,
            textCapitalization: TextCapitalization.words,
          ),
        ],
        AppSectionLabel(_isRx ? 'Issued on · optional' : 'Report date · optional'),
        AppPickerTile(
          glyph: AppGlyph.calendar,
          label: _date == null ? 'Pick a date' : formatDate(toIsoDate(_date!)),
          onTap: _pickDate,
        ),
        if (_members.isNotEmpty) ...[
          const AppSectionLabel('For'),
          AppChoiceChips<FamilyMember?>(
            options: [null, ..._members],
            selected: _member,
            onSelected: (m) => setState(() => _member = m),
            labelOf: (m) => m == null ? 'Me' : m.name,
          ),
        ],
        const AppSectionLabel('File · optional'),
        AppPickerTile(
          glyph: AppGlyph.attach,
          label: _file?.name ?? 'Attach a photo or PDF',
          onTap: _pickFile,
          onClear: _file == null ? null : () => setState(() => _file = null),
        ),
        const SizedBox(height: 4),
        Text('PDF, JPEG, PNG or WebP · up to 10 MB', style: text.bodySmall),
        AppLabeledField(
          label: 'Notes · optional',
          controller: _notes,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AppNote(_error!, tone: AppTone.err),
        ],
      ],
    );
  }
}
