import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../domain/doctor.dart';

/// Doctor result card.
///
/// Follows the prototype: an initials tile on `--brand-soft` rather than a
/// photo, name in Manrope w700, two muted meta lines, then a rating pill with
/// the fee right-aligned in Sora. Radius 18.
class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor});

  final Doctor doctor;

  /// Initials from the API when present, else derived from the display name.
  String get _initials {
    final given = doctor.initials?.trim();
    if (given != null && given.isNotEmpty) return given.toUpperCase();

    final words = doctor.displayName
        .replaceAll(RegExp(r'^(Dr\.?|Prof\.?)\s+', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words.first.characters.first + words[1].characters.first)
        .toUpperCase();
  }

  /// "General Physician · Navrangpura" — whichever parts exist.
  String? get _metaLine {
    final parts = [doctor.specLabel, doctor.locationLine]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/doctors/${doctor.id}'),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Ink(
            decoration: t.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontFamily: kFontHeading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: t.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              doctor.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kFontBody,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                          ),
                          if (doctor.verified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 15, color: t.sub),
                          ],
                        ],
                      ),
                      if (_metaLine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _metaLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kFontBody,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.sub,
                          ),
                        ),
                      ],
                      if (doctor.clinicName != null &&
                          doctor.clinicName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctor.clinicName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kFontBody,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.sub,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _MetaRow(doctor: doctor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rating pill, review count, and the fee pushed right.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final fee = doctor.feeLabel;

    return Row(
      children: [
        if (doctor.rating != null) ...[
          Container(
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppGlyph.star, color: t.brand, size: 9),
                const SizedBox(width: 3),
                Text(
                  doctor.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: kFontBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: t.brand,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (doctor.reviews != null)
          Flexible(
            child: Text(
              '${doctor.reviews} reviews',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ),
        const Spacer(),
        if (fee.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            // Manrope, not Sora: Sora has no rupee glyph and renders ? here.
            fee,
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
        ],
      ],
    );
  }
}
