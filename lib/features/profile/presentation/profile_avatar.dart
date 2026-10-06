import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/profile_providers.dart';
import '../domain/patient_profile.dart';

/// The patient's avatar, or their initials when there is no photo.
///
/// `profile.php?action=photo` is authed, so the bytes are fetched through
/// the API client and drawn from memory. They are cached per `photo_tag`
/// (the server's cache-buster), so a replaced photo refreshes and an
/// unchanged one is not refetched on every rebuild.
class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 56});

  final PatientProfile profile;
  final double size;

  static final _cache = <String, Uint8List>{};

  /// Drop cached bytes after an upload or removal.
  static void evict() => _cache.clear();

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  Uint8List? _bytes;

  String get _key => widget.profile.photoTag ?? 'photo';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(ProfileAvatar old) {
    super.didUpdateWidget(old);
    if (old.profile.hasPhoto != widget.profile.hasPhoto ||
        old.profile.photoTag != widget.profile.photoTag) {
      _bytes = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (!widget.profile.hasPhoto) return;
    final cached = ProfileAvatar._cache[_key];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    final r = await ref.read(profileRepositoryProvider).photo();
    if (!mounted) return;
    if (r case ApiSuccess(:final value)) {
      ProfileAvatar._cache[_key] = value;
      setState(() => _bytes = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    if (_bytes != null && p.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.32),
        child: Image.memory(
          _bytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        ),
      );
    }
    final initials = p.initials ?? (p.name.isEmpty ? '?' : p.name[0]);
    return AppInitialsTile(text: initials, size: widget.size);
  }
}

/// Signed-out / test-mode stand-in with the same footprint.
class ProfileAvatarPlaceholder extends StatelessWidget {
  const ProfileAvatarPlaceholder({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
    );
  }
}
