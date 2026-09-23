import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_providers.dart';
import '../../doctors/data/doctors_providers.dart';
import '../../doctors/domain/doctor.dart';
import '../../doctors/presentation/widgets/doctor_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  String? _error;
  List<Doctor> _featured = [];

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

    final result = await ref.read(doctorsRepositoryProvider).search(
          city: 'Ahmedabad',
          perPage: 5,
        );

    if (!mounted) return;
    switch (result) {
      case ApiSuccess(:final value):
        setState(() {
          _featured = value.items;
          _loading = false;
        });
      case ApiFailure(:final message, :final error):
        setState(() {
          _loading = false;
          _error = message ?? error;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Image.asset(AppAssets.logo, height: 28),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () async {
              await ref.read(authRepositoryProvider).clearLocalSession();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (kSkipWhatsAppOtp)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: const Text(
                  'TEST MODE: phone-only login. Doctor search works; booking needs WhatsApp OTP later.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A3412)),
                ),
              ),
            Text('Find care', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Search doctors and request an appointment.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.go('/doctors'),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Search doctors, specialty, city…',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_hospital_outlined,
                    label: 'Doctors',
                    onTap: () => context.go('/doctors'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.calendar_month_outlined,
                    label: 'Visits',
                    onTap: () => context.go('/appointments'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Featured near Ahmedabad', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/doctors'),
                  child: const Text('See all'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else
              ..._featured.map((d) => DoctorCard(doctor: d)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
