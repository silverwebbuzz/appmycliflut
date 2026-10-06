import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_ui.dart';
import '../../profile/domain/patient_profile.dart';
import '../data/family_providers.dart';
import '../data/family_repository.dart';
import '../domain/family_member.dart';

/// Add or edit a family member — `family.php?action=save`.
///
/// [memberId] null creates. Choice lists come from the `list` call's
/// `options` rather than being hardcoded, since the DB's relation enum
/// (`spouse`) differs from the design's Husband/Wife chips.
class FamilyMemberScreen extends ConsumerStatefulWidget {
  const FamilyMemberScreen({super.key, this.memberId});

  final int? memberId;

  @override
  ConsumerState<FamilyMemberScreen> createState() => _FamilyMemberScreenState();
}

class _FamilyMemberScreenState extends ConsumerState<FamilyMemberScreen> {
  ApiResult<FamilyListResult>? _result;
  FamilyMember? _member;
  final _name = TextEditingController();
  final _abha = TextEditingController();
  String? _relation;
  String? _gender;
  String? _blood;
  String? _dob;
  bool _saving = false;
  bool _removing = false;
  String? _error;

  bool get _isNew => widget.memberId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _abha.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(familyRepositoryProvider).list();
    if (!mounted) return;
    setState(() {
      _result = r;
      if (r case ApiSuccess(:final value) when !_isNew) {
        _member = value.members.where((m) => m.id == widget.memberId).firstOrNull;
        final m = _member;
        if (m != null) {
          _name.text = m.name;
          _abha.text = m.abhaId ?? '';
          _relation = m.relation;
          _gender = m.gender;
          _blood = m.bloodGroup;
          _dob = m.dob;
        }
      }
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseServerDate(_dob) ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (d != null) setState(() => _dob = toIsoDate(d));
  }

  Future<void> _save(FamilyOptions options) async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await ref.read(familyRepositoryProvider).save(
          memberId: widget.memberId,
          name: _name.text.trim(),
          relation: _relation == null
              ? null
              : FamilyRelations.toApiValue(_relation!, options.relations),
          dob: _dob,
          gender: _gender,
          bloodGroup: _blood,
          abhaId: _abha.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case ApiSuccess():
        showAppSnack(context, _isNew ? 'Family member added' : 'Saved');
        context.pop(true);
      case ApiFailure():
        setState(() => _error = friendlyMessage(r));
    }
  }

  Future<void> _remove() async {
    final m = _member;
    if (m == null) return;
    final ok = await confirmAction(
      context,
      title: 'Remove ${m.name}?',
      message: 'Their profile will be removed from your family.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() => _removing = true);
    final r = await ref.read(familyRepositoryProvider).remove(m.id);
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
      title: _isNew ? 'Add family member' : 'Family member',
      fallbackRoute: '/more',
      bottomBar: r is ApiSuccess<FamilyListResult>
          ? AppPrimaryButton(
              label: _isNew ? 'Add member' : 'Save changes',
              busy: _saving,
              onPressed: () => _save(r.value.options),
            )
          : null,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess() when !_isNew && _member == null => [
            AppFailureView(
              failure: const ApiFailure(error: 'not_found'),
              onRetry: _load,
            ),
          ],
        ApiSuccess(:final value) when _isNew && !value.canAdd => [
            AppNote(
              'Your family already has ${value.maxMembers} members, the '
              'most allowed. Remove someone to add another.',
            ),
          ],
        ApiSuccess(:final value) => _form(value.options),
      },
    );
  }

  List<Widget> _form(FamilyOptions o) {
    final isSelf = _member?.isSelf ?? false;
    final relations = o.relations.where((r) => r != 'self').toList();
    return [
      AppLabeledField(
        label: 'Full name',
        controller: _name,
        hint: 'e.g. Meena Sharma',
        textCapitalization: TextCapitalization.words,
      ),
      if (!isSelf && relations.isNotEmpty) ...[
        const AppSectionLabel('Relationship'),
        AppChoiceChips<String>(
          options: relations,
          selected: _relation,
          onSelected: (v) => setState(() => _relation = v),
          labelOf: FamilyRelations.label,
        ),
      ],
      if (o.genders.isNotEmpty) ...[
        const AppSectionLabel('Gender'),
        AppChoiceChips<String>(
          options: o.genders,
          selected: _gender,
          onSelected: (v) => setState(() => _gender = v),
          labelOf: genderLabel,
        ),
      ],
      const AppSectionLabel('Date of birth · optional'),
      AppPickerTile(
        glyph: AppGlyph.calendar,
        label: _dob == null ? 'Pick a date' : formatDate(_dob),
        onTap: _pickDob,
        onClear: _dob == null ? null : () => setState(() => _dob = null),
      ),
      if (o.bloodGroups.isNotEmpty) ...[
        const AppSectionLabel('Blood group · optional'),
        AppChoiceChips<String>(
          options: o.bloodGroups,
          selected: _blood,
          onSelected: (v) => setState(() => _blood = v),
          labelOf: (v) => v,
        ),
      ],
      AppLabeledField(
        label: 'ABHA ID · optional',
        controller: _abha,
        hint: '14-digit health ID',
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        AppNote(_error!, tone: AppTone.err),
      ],
      if (!_isNew && !isSelf) ...[
        const SizedBox(height: 22),
        AppSoftButton(
          label: 'Remove member',
          tone: AppTone.err,
          busy: _removing,
          onTap: _remove,
        ),
      ],
    ];
  }
}
