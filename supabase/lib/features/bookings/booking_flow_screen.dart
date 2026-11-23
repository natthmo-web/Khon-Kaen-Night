import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/actions.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/validators.dart';
import '../../core/widgets/glass.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../venues/presentation/floor_plan_view.dart';
import '../saved/local_kit.dart';
import 'booking.dart';
import 'booking_rules.dart';

class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key, required this.venueId, this.initialTableId});
  final String venueId;
  final String? initialTableId;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  int _step = 0;
  late DateTime _day;
  DateTime? _start;
  int _guests = 2;
  String? _tableId;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _done = false;
  bool _ofAge = false;
  BookingRecord? _made;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    _day = DateTime.utc(now.year, now.month, now.day);
    _tableId = widget.initialTableId;
    final user = ref.read(authControllerProvider);
    _name.text = user?.fullName ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  String _message(AppLocalizations l, String code) => switch (code) {
        'table_unavailable' => l.errTableUnavailable,
        'venue_closed' => l.errVenueClosed,
        'guest_count_exceeds_capacity' => l.errCapacity,
        'invalid_interval' => l.errInvalidInterval,
        'not_authenticated' => l.errNotAuthenticated,
        'not_cancellable' => l.errNotCancellable,
        'cancellation_window_closed' => l.errCancelWindow,
        'rejection_reason_required' => l.errRequired,
        'trial_expired' => l.errTrialExpired,
        'booking_expired' => l.errBookingExpired,
        'forbidden' => l.errForbidden,
        'venue_not_available' => l.errVenueNotAvailable,
        'invalid_contact' => l.errInvalidContact,
        'invalid_status_transition' => l.errInvalidTransition,
        _ => l.errorLoading,
      };

  Future<void> _submit(AppLocalizations l) async {
    final venue = ref.read(venueProvider(widget.venueId)).valueOrNull;
    final plan = ref.read(floorPlanProvider(widget.venueId)).valueOrNull;
    final repo = ref.read(bookingRepositoryProvider);
    final table = plan?.tables.where((t) => t.id == _tableId).firstOrNull;
    if (venue != null && !venue.acceptsBookings) {
      setState(() => _error = l.errTrialExpired);
      return;
    }
    if (venue == null || table == null || _start == null || repo == null) {
      setState(() => _error = l.pickTableFirst);
      return;
    }
    if (requiredField(l, _name.text) != null || phoneField(l, _phone.text) != null) {
      setState(() => _error = l.errRequired);
      return;
    }
    if (!_ofAge) {
      setState(() => _error = l.ageRequired);
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final made = await repo.create(venue: venue, table: table, start: _start!, guests: _guests, name: _name.text.trim(), phone: _phone.text.trim(), note: _note.text.trim());
      if (mounted) setState(() { _done = true; _made = made; });
    } on BookingException catch (e) {
      if (mounted) setState(() => _error = _message(l, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final venue = ref.watch(venueProvider(widget.venueId));
    final v = venue.valueOrNull;
    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Text(l.pendingTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(l.pendingBody, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
              if (ref.watch(demoModeProvider)) ...[
                const SizedBox(height: 12),
                Text(l.demoSubmitted, style: const TextStyle(color: AppColors.gold, height: 1.45)),
              ],
              if (_made != null) ...[
                const SizedBox(height: 16),
                Text('${_made!.venueName} · ${l.tableLabel} ${_made!.tableNumber}', style: const TextStyle(height: 1.45)),
                Text('${l.bookingRef} ${_made!.reference}', style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                Text(l.guestsCount(_made!.guests), style: const TextStyle(height: 1.45)),
              ],
              const Spacer(),
              if (_made != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassButton(
                    label: ref.watch(localKitProvider).reminders.contains(_made!.id) ? l.reminderSet : l.reminder,
                    secondary: true,
                    onPressed: () => ref.read(localKitProvider.notifier).toggleReminder(_made!.id),
                  ),
                ),
              GlassButton(label: l.viewBookings, onPressed: () => context.go('/bookings')),
            ]),
          ),
        ),
      );
    }
    final slots = v == null ? <DateTime>[] : BookingRules.slotsFor(v, _day);
    if (_start != null && !slots.contains(_start)) _start = slots.isEmpty ? null : slots.first;
    _start ??= slots.isEmpty ? null : slots.first;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.stepOf(_step + 1)),
        leading: GlassIconButton(icon: Icons.arrow_back, label: l.backLabel, onPressed: () => _step == 0 ? context.pop() : setState(() => _step--)),
      ),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              Text(v.name(Localizations.localeOf(context).languageCode), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (_step == 0) _when(l, slots),
              if (_step == 1) _table(l, v.id),
              if (_step == 2) _details(l),
              if (_step == 3) _review(l, v),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
              const SizedBox(height: 20),
              GlassButton(
                label: _step == 3 ? l.submitRequest : l.next,
                loading: _busy,
                onPressed: () {
                  if (_step == 0 && _start == null) return setState(() => _error = l.errVenueClosed);
                  if (_step == 1 && _tableId == null) return setState(() => _error = l.pickTableFirst);
                  if (_step < 3) return setState(() { _step++; _error = null; });
                  _submit(l);
                },
              ),
            ]),
    );
  }

  Widget _when(AppLocalizations l, List<DateTime> slots) {
    final bkkToday = DateTime.now().toUtc().add(const Duration(hours: 7));
    final days = [for (var i = 0; i < 10; i++) DateTime.utc(bkkToday.year, bkkToday.month, bkkToday.day + i)];
    String hhmm(DateTime instant) {
      final b = instant.toUtc().add(const Duration(hours: 7));
      return '${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.date, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final day in days)
          GlassChip(
            label: '${day.day}/${day.month}',
            selected: day == _day,
            onTap: () => setState(() { _day = day; _start = null; _tableId = null; }),
          ),
      ]),
      const SizedBox(height: 16),
      Text(l.time, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(l.durationNote, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 8),
      if (slots.isEmpty) Text(l.errVenueClosed, style: const TextStyle(color: AppColors.error))
      else Wrap(spacing: 8, runSpacing: 8, children: [
        for (final slot in slots)
          GlassChip(label: hhmm(slot), selected: slot == _start, onTap: () => setState(() { _start = slot; _tableId = null; })),
      ]),
      const SizedBox(height: 16),
      Text(l.guests, style: const TextStyle(fontWeight: FontWeight.w600)),
      Row(children: [
        IconButton(onPressed: _guests > 1 ? () => setState(() { _guests--; _tableId = null; }) : null, icon: const Icon(Icons.remove)),
        Text('$_guests'),
        IconButton(onPressed: _guests < 12 ? () => setState(() { _guests++; _tableId = null; }) : null, icon: const Icon(Icons.add)),
        Text(l.guestsCount(_guests), style: const TextStyle(color: AppColors.textSecondary)),
      ]),
    ]);
  }

  Widget _table(AppLocalizations l, String venueId) {
    final plan = ref.watch(floorPlanProvider(venueId));
    final start = _start;
    final available = start == null ? null : ref.watch(availabilityWindowProvider((venueId, start, _guests))).valueOrNull;
    return plan.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Text(l.errorLoading),
      data: (p) {
        if (p == null) return Text(l.noFloorPlan);
        final free = available ?? {};
        if (available != null && free.isEmpty) {
          return Text(l.noTablesFree, style: const TextStyle(color: AppColors.textSecondary));
        }
        return FloorPlanView(plan: p, available: available, selectedId: _tableId, onSelect: (id) => setState(() => _tableId = id));
      },
    );
  }

  Widget _details(AppLocalizations l) => Column(children: [
        GlassTextField(controller: _name, label: l.customerName, validator: (v) => requiredField(l, v)),
        const SizedBox(height: 12),
        GlassTextField(controller: _phone, label: l.phone, keyboardType: TextInputType.phone, validator: (v) => phoneField(l, v)),
        const SizedBox(height: 12),
        GlassTextField(controller: _note, label: l.noteOptional, maxLines: 3),
      ]);

  Widget _review(AppLocalizations l, dynamic venue) {
    final lang = Localizations.localeOf(context).languageCode;
    final plan = ref.watch(floorPlanProvider(widget.venueId)).valueOrNull;
    final table = plan?.tables.where((t) => t.id == _tableId).firstOrNull;
    final b = _start?.toUtc().add(const Duration(hours: 7));
    final when = b == null ? '' : '${b.day}/${b.month} ${b.hour.toString().padLeft(2, '0')}:${b.minute.toString().padLeft(2, '0')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(venue.name(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('$when · ${l.guestsCount(_guests)}'),
      if (table != null) Text(l.selectedSummary(table.number, table.capacity)),
      const SizedBox(height: 8),
      Text(l.requestDisclaimer, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
      const SizedBox(height: 16),
      Text(l.ageNotice, style: const TextStyle(color: AppColors.gold, height: 1.5)),
      const SizedBox(height: 8),
      GlassChip(label: l.ageConfirm, selected: _ofAge, onTap: () => setState(() => _ofAge = !_ofAge)),
      const SizedBox(height: 8),
      GlassChip(
        label: l.shareBooking,
        onTap: () => shareText(context, '${venue.name(lang)}\n$when\n${l.guestsCount(_guests)}', l.copied),
      ),
    ]);
  }
}
