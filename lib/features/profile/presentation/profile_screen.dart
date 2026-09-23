import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(child: Image.asset(AppAssets.logoMark, height: 64)),
          const SizedBox(height: 12),
          const Center(
            child: Text('Patient profile', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Full profile & settings come in a later phase.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Saved doctors'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/doctors'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & support'),
            subtitle: const Text('eclinicpro.com'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
