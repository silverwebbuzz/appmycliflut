import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../doctors/domain/doctor.dart';

/// Request appointment (lead flow) — matches website book behaviour.
class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key, required this.doctorId, this.doctor});

  final int doctorId;
  final Doctor? doctor;

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  final _reasonController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 30);
  bool _loading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _dateStr =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  String get _timeStr =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (kSkipWhatsAppOtp) {
      setState(() {
        _error =
            'Test mode is on (no WhatsApp login). Turn off kSkipWhatsAppOtp and verify OTP to request a real appointment.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    final api = ref.read(apiClientProvider);
    final result = await api.post(
      '/appointments.php',
      queryParameters: {'action': 'book'},
      data: {
        'doctor_id': widget.doctorId,
        'preferred_date': _dateStr,
        'preferred_time': _timeStr,
        'reason': _reasonController.text.trim(),
      },
    );

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case ApiSuccess(:final value):
        setState(() {
          _successMessage = (value['message'] ??
                  "We've notified the clinic. They'll call you within 24 hours.")
              .toString();
        });
      case ApiFailure(:final error, :final message):
        setState(() {
          _error = _friendly(error, message);
        });
    }
  }

  String _friendly(String code, String? message) {
    return switch (code) {
      'login_required' => 'Please sign in with WhatsApp OTP to book.',
      'date_in_past' => 'Please choose a future date.',
      'date_out_of_window' => 'Date must be within the next 7 days.',
      'too_many_requests' => 'Too many requests. Try again later.',
      'date_required' || 'time_required' || 'doctor_id_required' =>
        'Please complete all fields.',
      _ => message ?? 'Could not submit request. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.doctor?.displayName ?? 'Doctor #${widget.doctorId}';

    if (_successMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request sent')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.check_circle,
                  color: AppTokens.of(context).ink, size: 72),
              const SizedBox(height: 16),
              Text('Request submitted', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(_successMessage!, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/appointments'),
                child: const Text('View appointments'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTokens.of(context).bg,
      appBar: AppBar(title: const Text('Request appointment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'We’ll notify the clinic. They’ll confirm with you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (kSkipWhatsAppOtp) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: const Text(
                'TEST MODE: you can fill the form, but booking needs real WhatsApp login.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9A3412)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Preferred date'),
            subtitle: Text(formatDay(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Preferred time'),
            subtitle: Text(formatTime(DateTime(0, 1, 1, _time.hour, _time.minute))),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. Follow-up for fever',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: AppTokens.of(context).red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit request'),
          ),
        ],
      ),
    );
  }
}
