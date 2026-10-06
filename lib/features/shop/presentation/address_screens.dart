import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';

/// Add or edit a delivery address — `address_add` / `address_update`.
///
/// State is a dropdown of the server's `states`: it decides the GST type on
/// the invoice, so free text is not accepted. Typing a 6-digit pincode looks
/// it up (`?action=pincode`) to prefill city and state and show delivery
/// info; an unknown pincode never blocks the form. Pops the saved [Address].
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});

  /// Null adds a new address.
  final Address? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  ApiResult<AddressBook>? _book;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  final _city = TextEditingController();
  String? _state;
  String? _label = 'Home';
  bool _saving = false;
  String? _error;

  /// Last pincode looked up, so the same pin is not fetched twice.
  String? _lookedUp;
  bool _looking = false;

  /// Delivery note under the pincode, with its tone.
  (String, AppTone)? _pinNote;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _name.text = a.name;
      // The server stores +91…; the field takes the 10 digits.
      final digits = a.phone.replaceAll(RegExp(r'\D'), '');
      _phone.text = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      _line1.text = a.line1;
      _line2.text = a.line2 ?? '';
      _landmark.text = a.landmark ?? '';
      _pincode.text = a.pincode;
      _city.text = a.city;
      _state = a.state;
      _label = a.label;
      _lookedUp = a.pincode;
    }
    _pincode.addListener(_onPincodeChanged);
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _landmark, _pincode, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).addresses();
    if (mounted) setState(() => _book = r);
  }

  void _onPincodeChanged() {
    final pin = _pincode.text;
    if (pin.length != 6) {
      if (_pinNote != null) setState(() => _pinNote = null);
      return;
    }
    if (pin != _lookedUp) _lookupPin(pin);
  }

  Future<void> _lookupPin(String pin) async {
    _lookedUp = pin;
    setState(() {
      _looking = true;
      _pinNote = null;
    });
    final r = await ref.read(storeRepositoryProvider).pincode(pin);
    // Ignore an answer for a pin the customer has since changed.
    if (!mounted || _pincode.text != pin) return;
    final states = switch (_book) {
      ApiSuccess(:final value) => value.states,
      _ => const <String>[],
    };
    setState(() {
      _looking = false;
      switch (r) {
        case ApiSuccess(:final value):
          if (value.city != null) _city.text = value.city!;
          if (value.state != null && states.contains(value.state)) {
            _state = value.state;
          }
          _pinNote = !value.serviceable
              ? ('Sorry, no courier delivers to this pincode yet.', AppTone.err)
              : value.etaDays != null
                  ? (
                      'Delivery in about ${value.etaDays} day${value.etaDays == 1 ? '' : 's'}',
                      AppTone.brand,
                    )
                  : null;
        case ApiFailure(:final error):
          // Not found or rate-limited: the customer fills city/state in.
          _pinNote = error == 'pin_not_found' || error == 'invalid_pin'
              ? (friendlyMessage(r), AppTone.warn)
              : null;
      }
    });
  }

  Map<String, String> _fields() => {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'line1': _line1.text.trim(),
        'line2': _line2.text.trim(),
        'landmark': _landmark.text.trim(),
        'pincode': _pincode.text.trim(),
        'city': _city.text.trim(),
        'state': _state ?? '',
        'label': _label ?? '',
      };

  Future<void> _save() async {
    final missing = [
      if (_name.text.trim().isEmpty) 'name',
      if (_phone.text.trim().length < 10) 'a 10-digit phone',
      if (_line1.text.trim().isEmpty) 'the address',
      if (_pincode.text.trim().length != 6) 'a 6-digit pincode',
      if (_city.text.trim().isEmpty) 'city',
      if (_state == null) 'state',
    ];
    if (missing.isNotEmpty) {
      setState(() => _error = 'Please enter ${missing.join(', ')}.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(storeRepositoryProvider);
    final r = _isEdit
        ? await repo.updateAddress(widget.existing!.id, _fields())
        : await repo.addAddress(_fields()..removeWhere((k, v) => k == 'label' && v.isEmpty));
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case ApiSuccess(:final value):
        context.pop(value);
      case ApiFailure():
        setState(() => _error = friendlyMessage(r));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _book;
    return AppSubPage(
      title: _isEdit ? 'Edit address' : 'New address',
      fallbackRoute: '/shop',
      bottomBar: r is ApiSuccess<AddressBook>
          ? AppPrimaryButton(
              label: _isEdit ? 'Save changes' : 'Save address',
              busy: _saving,
              onPressed: _save,
            )
          : null,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value)
            when !_isEdit && value.addresses.length >= value.max =>
          [
            AppNote(
              'You have ${value.max} saved addresses, the most allowed. '
              'Remove one under Saved addresses to add another.',
            ),
          ],
        ApiSuccess(:final value) => _form(value.states),
      },
    );
  }

  List<Widget> _form(List<String> states) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return [
      const AppSectionLabel('Save as'),
      AppChoiceChips<String>(
        options: const ['Home', 'Work', 'Other'],
        selected: _label,
        onSelected: (v) => setState(() => _label = v),
        labelOf: (v) => v,
      ),
      AppLabeledField(
        label: 'Full name',
        controller: _name,
        textCapitalization: TextCapitalization.words,
      ),
      const AppSectionLabel('Phone'),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        inputFormatters: [...digits, LengthLimitingTextInputFormatter(10)],
        decoration: const InputDecoration(prefixText: '+91  '),
      ),
      // Pincode first, so city and state can fill themselves in.
      const AppSectionLabel('Pincode'),
      TextField(
        controller: _pincode,
        keyboardType: TextInputType.number,
        inputFormatters: [...digits, LengthLimitingTextInputFormatter(6)],
        decoration: InputDecoration(
          hintText: '6-digit pincode',
          suffixIcon: _looking
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
      ),
      if (_pinNote != null) ...[
        const SizedBox(height: 8),
        AppNote(_pinNote!.$1, tone: _pinNote!.$2),
      ],
      AppLabeledField(
        label: 'House / flat, street',
        controller: _line1,
        textCapitalization: TextCapitalization.words,
      ),
      AppLabeledField(
        label: 'Area · optional',
        controller: _line2,
        textCapitalization: TextCapitalization.words,
      ),
      AppLabeledField(
        label: 'Landmark · optional',
        controller: _landmark,
        textCapitalization: TextCapitalization.words,
      ),
      AppLabeledField(
        label: 'City',
        controller: _city,
        textCapitalization: TextCapitalization.words,
      ),
      const AppSectionLabel('State'),
      DropdownButtonFormField<String>(
        // Keyed so a pincode lookup can change the selection.
        key: ValueKey(_state),
        initialValue: states.contains(_state) ? _state : null,
        isExpanded: true,
        hint: const Text('Select state'),
        items: [
          for (final s in states) DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) => setState(() => _state = v),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        AppNote(_error!, tone: AppTone.err),
      ],
    ];
  }
}

/// Saved addresses — list and remove (More → Saved addresses).
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  ApiResult<AddressBook>? _result;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).addresses();
    if (mounted) setState(() => _result = r);
  }

  Future<void> _add() async {
    final a = await context.push<Address>('/shop/addresses/new');
    if (a != null) _load();
  }

  Future<void> _actions(Address a) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Edit'),
              onTap: () => Navigator.of(c).pop('edit'),
            ),
            if (!a.isDefault)
              ListTile(
                title: const Text('Make default'),
                onTap: () => Navigator.of(c).pop('default'),
              ),
            ListTile(
              title: Text('Remove', style: TextStyle(color: AppTokens.of(c).red)),
              onTap: () => Navigator.of(c).pop('remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        final saved = await context.push<Address>('/shop/addresses/edit', extra: a);
        if (saved != null) _load();
      case 'default':
        await _makeDefault(a);
      case 'remove':
        await _remove(a);
    }
  }

  Future<void> _makeDefault(Address a) async {
    setState(() => _busyId = a.id);
    final r = await ref.read(storeRepositoryProvider).setDefaultAddress(a.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (r is ApiFailure<List<Address>>) {
      showAppSnack(context, friendlyMessage(r));
    } else {
      _load();
    }
  }

  Future<void> _remove(Address a) async {
    final ok = await confirmAction(
      context,
      title: 'Remove this address?',
      message: a.oneLine,
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = a.id);
    final r = await ref.read(storeRepositoryProvider).removeAddress(a.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (r is ApiFailure<void>) {
      showAppSnack(context, friendlyMessage(r));
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final t = AppTokens.of(context);
    return AppSubPage(
      title: 'Saved addresses',
      fallbackRoute: '/more',
      onRefresh: _load,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => [
            if (value.addresses.isEmpty)
              const AppPlaceholder(
                icon: AppGlyph.pin,
                title: 'No saved addresses',
                message: 'Add one now, or at checkout.',
              ),
            for (final a in value.addresses)
              AddressCard(
                address: a,
                onTap: () => _actions(a),
                trailing: _busyId == a.id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (a.isDefault) const AppStatusPill('Default'),
                          const SizedBox(width: 6),
                          AppIcon(AppGlyph.chevronRight, color: t.sub, size: 18),
                        ],
                      ),
              ),
            if (value.addresses.length < value.max) ...[
              const SizedBox(height: 4),
              AppSoftButton(label: '+ Add new address', onTap: _add),
            ],
          ],
      },
    );
  }
}

/// Address summary card. [selected] draws the prototype's radio ring.
class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.address,
    this.selected,
    this.onTap,
    this.trailing,
  });

  final Address address;

  /// Null hides the radio.
  final bool? selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final a = address;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: t.cardDecoration.copyWith(
          border: Border.all(color: selected == true ? t.brand : t.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected != null) ...[
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected! ? t.brand : t.line,
                    width: 2,
                  ),
                ),
                child: selected!
                    ? Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [a.label, a.name].whereType<String>().join(' · '),
                    style: text.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(a.oneLine, style: text.bodySmall),
                  Text(a.phone, style: text.bodySmall),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
