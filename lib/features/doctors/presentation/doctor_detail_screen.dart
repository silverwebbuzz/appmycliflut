import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_states.dart';
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
      case ApiFailure(:final message, :final error):
        setState(() {
          _loading = false;
          _error = message ?? error;
        });
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Doctor')),
      body: _buildBody(),
      bottomNavigationBar: _doctor == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
      return AppErrorState(message: _error!, onRetry: _load);
    }
    final d = _doctor!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 88,
                height: 88,
                child: d.photoUrl != null && d.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: d.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Image.asset(AppAssets.doctorAvatar),
                      )
                    : Image.asset(AppAssets.doctorAvatar, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.displayName, style: Theme.of(context).textTheme.headlineMedium),
                  if (d.specLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(d.specLabel!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (d.clinicName != null) ...[
                    const SizedBox(height: 4),
                    Text(d.clinicName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 8),
                  if (d.rating != null)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                        Text(' ${d.rating!.toStringAsFixed(1)}'),
                        if (d.reviews != null) Text(' · ${d.reviews} reviews'),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _InfoTile(icon: Icons.payments_outlined, title: 'Consultation fee', value: d.feeLabel),
        if (d.locationLine.isNotEmpty)
          _InfoTile(icon: Icons.place_outlined, title: 'Location', value: d.locationLine),
        if (d.address != null && d.address!.isNotEmpty)
          _InfoTile(icon: Icons.home_work_outlined, title: 'Address', value: d.address!),
        if (d.nextLabel != null)
          _InfoTile(icon: Icons.schedule, title: 'Availability', value: d.nextLabel!),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
    );
  }
}
