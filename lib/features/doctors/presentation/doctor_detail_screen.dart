import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/doctors_providers.dart';
import '../domain/doctor.dart';

class DoctorDetailScreen extends ConsumerStatefulWidget {
  const DoctorDetailScreen({super.key, required this.doctorId});

  final int doctorId;

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  bool _loading = true;
  String? _error;
  Doctor? _doctor;

  /// Null until known (signed out, or the saved list has not loaded).
  bool? _saved;
  bool _savingToggle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(doctorsRepositoryProvider).detail(widget.doctorId);
    if (!mounted) return;
    switch (result) {
      case ApiSuccess(:final value):
        setState(() {
          _doctor = value;
          _loading = false;
        });
        // Fire-and-forget analytics
        ref.read(doctorsRepositoryProvider).trackView(widget.doctorId);
        _loadSaved();
      case ApiFailure(:final message, :final error):
        setState(() {
          _loading = false;
          _error = message ?? error;
        });
    }
  }

  /// `detail` has no saved flag, so look the doctor up in the saved list.
  Future<void> _loadSaved() async {
    final r = await ref.read(doctorsRepositoryProvider).saved();
    if (!mounted) return;
    if (r case ApiSuccess(:final value)) {
      setState(() => _saved = value.items.any((d) => d.id == widget.doctorId));
    }
  }

  Future<void> _toggleSaved() async {
    final next = !(_saved ?? false);
    setState(() => _savingToggle = true);
    final r = await ref
        .read(doctorsRepositoryProvider)
        .setSaved(widget.doctorId, saved: next);
    if (!mounted) return;
    setState(() => _savingToggle = false);
    switch (r) {
      case ApiSuccess(:final value):
        setState(() => _saved = value);
        showAppSnack(context, value ? 'Saved to your doctors' : 'Removed');
      case ApiFailure(:final isLoginRequired, :final error):
        if (isLoginRequired) {
          promptSignIn(context, reason: 'Sign in to save doctors.');
        } else {
          showAppSnack(
            context,
            error == 'limit_reached'
                ? 'You can save up to 5 doctors. Remove one first.'
                : friendlyMessage(r),
          );
        }
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppGlyph.chevronLeft, color: t.ink, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/doctors'),
        ),
        title: const Text('Doctor'),
        actions: [
          if (_doctor != null)
            IconButton(
              tooltip: _saved == true ? 'Remove from saved' : 'Save doctor',
              onPressed: _savingToggle ? null : _toggleSaved,
              icon: AppIcon(
                _saved == true ? AppGlyph.heartFilled : AppGlyph.heart,
                color: t.ink,
                size: 21,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _doctor == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _doctor!.canRequestAppointment
                      ? () => context.push('/book/${_doctor!.id}', extra: _doctor)
                      : null,
                  child: const Text('Request appointment'),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppPlaceholder(
            icon: AppGlyph.person,
            title: 'Could not load this doctor',
            message: _error!,
            action: FilledButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    final d = _doctor!;
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Initials tile, matching DoctorCard and the prototype, rather
            // than a photo: the directory has no reliable doctor imagery.
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.brandSoft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Text(
                _initialsFor(d),
                style: TextStyle(
                  fontFamily: kFontHeading,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: t.brand,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.displayName, style: text.headlineMedium),
                  if (d.specLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(d.specLabel!, style: text.bodySmall),
                  ],
                  if (d.clinicName != null) ...[
                    const SizedBox(height: 4),
                    Text(d.clinicName!, style: text.labelLarge),
                  ],
                  if (d.rating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AppIcon(AppGlyph.star, color: t.ink, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          d.rating!.toStringAsFixed(1),
                          style: text.labelLarge,
                        ),
                        if (d.reviews != null)
                          Text(' · ${d.reviews} reviews',
                              style: text.bodySmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: t.cardDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              _InfoRow(title: 'Consultation fee', value: d.feeLabel),
              if (d.locationLine.isNotEmpty)
                _InfoRow(title: 'Location', value: d.locationLine),
              if (d.address != null && d.address!.isNotEmpty)
                _InfoRow(title: 'Address', value: d.address!),
              if (d.nextLabel != null)
                _InfoRow(title: 'Availability', value: d.nextLabel!, last: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: d.phone == null ? null : () => _call(d.phone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: d.gmapsUrl == null ? null : () => _openUrl(d.gmapsUrl),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Directions'),
              ),
            ),
          ],
        ),
        if (d.openingHours.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Opening hours', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...d.openingHours.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(h, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

/// One labelled value inside the details card, with a hairline separator.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    this.last = false,
  });

  final String title;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials from the API when present, else derived from the display name.
String _initialsFor(Doctor d) {
  final given = d.initials?.trim();
  if (given != null && given.isNotEmpty) return given.toUpperCase();

  final words = d.displayName
      .replaceAll(RegExp(r'^(Dr\.?|Prof\.?)\s+', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return (words.first.characters.first + words[1].characters.first)
      .toUpperCase();
}
