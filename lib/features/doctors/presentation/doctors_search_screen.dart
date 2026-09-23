import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../data/doctors_providers.dart';
import '../domain/doctor.dart';
import 'widgets/doctor_card.dart';

class DoctorsSearchScreen extends ConsumerStatefulWidget {
  const DoctorsSearchScreen({super.key, this.initialQuery, this.initialCity});

  final String? initialQuery;
  final String? initialCity;

  @override
  ConsumerState<DoctorsSearchScreen> createState() => _DoctorsSearchScreenState();
}

class _DoctorsSearchScreenState extends ConsumerState<DoctorsSearchScreen> {
  final _qController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loading = true;
  String? _error;
  DoctorSearchResult? _result;

  @override
  void initState() {
    super.initState();
    _qController.text = widget.initialQuery ?? '';
    _cityController.text = widget.initialCity ?? 'Ahmedabad';
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _qController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _search({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(doctorsRepositoryProvider).search(
          q: _qController.text,
          city: _cityController.text,
          page: page,
        );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess(:final value):
        setState(() {
          _result = value;
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
    final t = AppTokens.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        110 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Find a doctor',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        _SearchField(
          controller: _qController,
          hint: 'Doctor, specialty or clinic',
          glyph: AppGlyph.search,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: _cityController,
          hint: 'City',
          glyph: AppGlyph.pin,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          AppPlaceholder(
            icon: AppGlyph.person,
            title: 'Could not load doctors',
            message: _error!,
            action: FilledButton(
              onPressed: _search,
              child: const Text('Try again'),
            ),
          )
        else ...[
          Text(
            '${_result?.total ?? 0} results',
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.sub,
            ),
          ),
          const SizedBox(height: 10),
          if ((_result?.items ?? []).isEmpty)
            const AppPlaceholder(
              icon: AppGlyph.person,
              title: 'No doctors found',
              message: 'Try another city or a different search term.',
            )
          else
            ...(_result!.items).map((d) => DoctorCard(doctor: d)),
        ],
      ],
    );
  }
}

/// Search input styled as the prototype's card field: a `--card` surface with
/// a `--line` border, a leading stroked glyph and no Material underline.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.glyph,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final AppGlyph glyph;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Container(
      decoration: t.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          AppIcon(glyph, color: t.sub, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: kFontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.sub,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
