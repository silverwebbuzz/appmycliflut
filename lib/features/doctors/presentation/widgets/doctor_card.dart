import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/doctor.dart';

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/doctors/${doctor.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: doctor.photoUrl != null && doctor.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: doctor.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _placeholder(),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doctor.verified)
                          const Icon(Icons.verified, size: 18, color: AppColors.primary),
                      ],
                    ),
                    if (doctor.specLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(doctor.specLabel!, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (doctor.clinicName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        doctor.clinicName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (doctor.rating != null) ...[
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            doctor.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (doctor.reviews != null)
                            Text(
                              ' (${doctor.reviews})',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            doctor.locationLine.isEmpty ? doctor.feeLabel : doctor.locationLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.primarySoft,
      child: Image.asset(AppAssets.doctorAvatar, fit: BoxFit.cover),
    );
  }
}
