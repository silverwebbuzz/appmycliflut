import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/file_actions.dart';
import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/profile_providers.dart';
import '../data/profile_repository.dart';
import '../domain/patient_profile.dart';
import 'profile_avatar.dart';

/// Edit profile — `profile.php?action=save`.
///
/// Sends only the fields that changed (the server does partial writes), so
/// an edit never clobbers a column this form does not show. The login phone
/// is display-only: changing it needs the OTP flow, which v1 does not have.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  ApiResult<ProfileResult>? _result;
  PatientProfile? _original;

  /// Text fields keyed by their [ProfileFields] save key.
  final _text = <String, TextEditingController>{
    for (final k in const [
      ProfileFields.name,
      ProfileFields.email,
      ProfileFields.phoneAlt,
      ProfileFields.addressLine1,
      ProfileFields.addressLine2,
      ProfileFields.city,
      ProfileFields.state,
      ProfileFields.pincode,
      ProfileFields.emergencyName,
      ProfileFields.emergencyPhone,
      ProfileFields.emergencyRelation,
      ProfileFields.allergies,
      ProfileFields.chronicConditions,
      ProfileFields.abhaId,
    ])
      k: TextEditingController(),
  };
  String? _dob;
  String? _gender;
  String? _blood;
  String? _veg;
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(profileRepositoryProvider).get();
    if (!mounted) return;
    setState(() => _result = r);
    if (r case ApiSuccess(:final value)) _fill(value.profile);
  }

  void _fill(PatientProfile p) {
    _original = p;
    final values = _values(p);
    for (final e in _text.entries) {
      e.value.text = values[e.key] ?? '';
    }
    _dob = p.dob;
    _gender = p.gender;
    _blood = p.bloodGroup;
    _veg = p.vegType;
  }

  /// The profile's current value for every editable key.
  static Map<String, String?> _values(PatientProfile p) => {
        ProfileFields.name: p.name,
        ProfileFields.email: p.email,
        ProfileFields.phoneAlt: p.phoneAlt,
        ProfileFields.addressLine1: p.addressLine1,
        ProfileFields.addressLine2: p.addressLine2,
        ProfileFields.city: p.city,
        ProfileFields.state: p.state,
        ProfileFields.pincode: p.pincode,
        ProfileFields.emergencyName: p.emergencyName,
        ProfileFields.emergencyPhone: p.emergencyPhone,
        ProfileFields.emergencyRelation: p.emergencyRelation,
        ProfileFields.allergies: p.allergies,
        ProfileFields.chronicConditions: p.chronicConditions,
        ProfileFields.abhaId: p.abhaId,
        ProfileFields.dob: p.dob,
        ProfileFields.gender: p.gender,
        ProfileFields.bloodGroup: p.bloodGroup,
        ProfileFields.vegType: p.vegType,
      };

  Map<String, String> _changes() {
    final now = <String, String?>{
      for (final e in _text.entries) e.key: e.value.text.trim(),
      ProfileFields.dob: _dob,
      ProfileFields.gender: _gender,
      ProfileFields.bloodGroup: _blood,
      ProfileFields.vegType: _veg,
    };
    final before = _values(_original!);
    return {
      for (final e in now.entries)
        if ((e.value ?? '') != (before[e.key] ?? '')) e.key: e.value ?? '',
    };
  }

  Future<void> _save() async {
    if (_text[ProfileFields.name]!.text.trim().isEmpty) {
      setState(() => _error = 'Your name cannot be empty.');
      return;
    }
    final changes = _changes();
    if (changes.isEmpty) {
      context.pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await ref.read(profileRepositoryProvider).save(changes);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case ApiSuccess():
        showAppSnack(context, 'Profile saved');
        context.pop(true);
      case ApiFailure():
        setState(() => _error = friendlyMessage(r));
    }
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

  Future<void> _changePhoto(PatientProfile p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Choose a photo'),
              onTap: () => Navigator.of(c).pop('pick'),
            ),
            if (p.hasPhoto)
              ListTile(
                title: const Text('Remove photo'),
                onTap: () => Navigator.of(c).pop('remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final repo = ref.read(profileRepositoryProvider);
    ApiResult<Object?> r;
    if (action == 'pick') {
      final file = await pickPhoto();
      if (file == null || !mounted) return;
      setState(() => _photoBusy = true);
      r = await repo.uploadPhoto(file.path, fileName: file.name);
    } else {
      setState(() => _photoBusy = true);
      r = await repo.removePhoto();
    }
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (r is ApiFailure<Object?>) {
      showAppSnack(
        context,
        r.error == 'file_too_large'
            ? 'That photo is over 4 MB.'
            : friendlyMessage(r),
      );
      return;
    }
    ProfileAvatar.evict();
    // Reload so has_photo / photo_tag are current, keeping unsaved edits.
    final pending = _changes();
    await _load();
    if (!mounted) return;
    setState(() {
      for (final e in pending.entries) {
        if (_text.containsKey(e.key)) _text[e.key]!.text = e.value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AppSubPage(
      title: 'Edit profile',
      fallbackRoute: '/more',
      bottomBar: r is ApiSuccess
          ? AppPrimaryButton(label: 'Save changes', busy: _saving, onPressed: _save)
          : null,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _form(context, value),
      },
    );
  }

  List<Widget> _form(BuildContext context, ProfileResult value) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final p = value.profile;
    final o = value.options;
    TextEditingController c(String k) => _text[k]!;

    return [
      Center(
        child: GestureDetector(
          onTap: _photoBusy ? null : () => _changePhoto(p),
          child: Column(
            children: [
              _photoBusy
                  ? const SizedBox(
                      width: 76,
                      height: 76,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ProfileAvatar(profile: p, size: 76),
              const SizedBox(height: 6),
              Text(
                p.hasPhoto ? 'Change photo' : 'Add photo',
                style: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.brand,
                ),
              ),
            ],
          ),
        ),
      ),
      AppLabeledField(
        label: 'Full name',
        controller: c(ProfileFields.name),
        textCapitalization: TextCapitalization.words,
      ),
      AppLabeledField(
        label: 'Email · for reports',
        controller: c(ProfileFields.email),
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
      ),

      const AppSectionLabel('Login number'),
      Container(
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.phone ?? '—', style: text.labelLarge),
                  Text('Verified via OTP · cannot be changed here',
                      style: text.bodySmall),
                ],
              ),
            ),
            if (p.phoneVerified) const AppStatusPill('Verified'),
          ],
        ),
      ),
      AppLabeledField(
        label: 'Alternate phone · optional',
        controller: c(ProfileFields.phoneAlt),
        keyboardType: TextInputType.phone,
      ),

      const AppSectionLabel('Date of birth'),
      AppPickerTile(
        glyph: AppGlyph.calendar,
        label: _dob == null ? 'Pick a date' : formatDate(_dob),
        onTap: _pickDob,
        onClear: _dob == null ? null : () => setState(() => _dob = null),
      ),
      if (o.genders.isNotEmpty) ...[
        const AppSectionLabel('Gender'),
        AppChoiceChips<String>(
          options: o.genders,
          selected: _gender,
          onSelected: (v) => setState(() => _gender = v),
          labelOf: genderLabel,
        ),
      ],
      if (o.bloodGroups.isNotEmpty) ...[
        const AppSectionLabel('Blood group'),
        AppChoiceChips<String>(
          options: o.bloodGroups,
          selected: _blood,
          onSelected: (v) => setState(() => _blood = v),
          labelOf: (v) => v,
        ),
      ],
      if (o.vegTypes.isNotEmpty) ...[
        const AppSectionLabel('Diet'),
        AppChoiceChips<String>(
          options: o.vegTypes,
          selected: _veg,
          onSelected: (v) => setState(() => _veg = v),
          labelOf: vegLabel,
        ),
      ],

      AppLabeledField(
        label: 'Allergies',
        controller: c(ProfileFields.allergies),
        hint: 'e.g. Penicillin, peanuts',
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      AppLabeledField(
        label: 'Ongoing conditions',
        controller: c(ProfileFields.chronicConditions),
        hint: 'e.g. Type 2 diabetes',
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),

      AppLabeledField(
        label: 'Address',
        controller: c(ProfileFields.addressLine1),
        hint: 'House, street',
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 8),
      TextField(
        controller: c(ProfileFields.addressLine2),
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Area, landmark'),
      ),
      Row(
        children: [
          Expanded(
            child: AppLabeledField(
              label: 'City',
              controller: c(ProfileFields.city),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: AppLabeledField(
              label: 'Pincode',
              controller: c(ProfileFields.pincode),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ),
        ],
      ),
      AppLabeledField(
        label: 'State',
        controller: c(ProfileFields.state),
        textCapitalization: TextCapitalization.words,
      ),

      AppLabeledField(
        label: 'Emergency contact',
        controller: c(ProfileFields.emergencyName),
        hint: 'Name',
        textCapitalization: TextCapitalization.words,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: c(ProfileFields.emergencyPhone),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c(ProfileFields.emergencyRelation),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Relation'),
            ),
          ),
        ],
      ),
      AppLabeledField(
        label: 'ABHA ID · optional',
        controller: c(ProfileFields.abhaId),
        hint: '14-digit health ID',
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        AppNote(_error!, tone: AppTone.err),
      ],
    ];
  }
}
