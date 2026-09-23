import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_states.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Find doctors'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _qController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Search name or specialty',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _search,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cityController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: 'City',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _search);
    }
    final items = _result?.items ?? [];
    if (items.isEmpty) {
      return AppEmptyState(
        title: 'No doctors found',
        subtitle: 'Try another city or search term.',
        icon: Icons.person_search_outlined,
        actionLabel: 'Search again',
        onAction: _search,
      );
    }

    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${_result!.total} results',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return DoctorCard(doctor: items[index - 1]);
        },
      ),
    );
  }
}
