import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small on-device settings: which bookings the user wants a reminder for, and whether alerts are shown.
class LocalKit {
  const LocalKit({this.reminders = const {}, this.alertsOn = true});
  final Set<String> reminders;
  final bool alertsOn;

  LocalKit copyWith({Set<String>? reminders, bool? alertsOn}) =>
      LocalKit(reminders: reminders ?? this.reminders, alertsOn: alertsOn ?? this.alertsOn);
}

class LocalKitController extends Notifier<LocalKit> {
  static const _remindersKey = 'reminders';
  static const _alertsKey = 'alerts_on';

  @override
  LocalKit build() {
    _load();
    return const LocalKit();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = LocalKit(
      reminders: (prefs.getStringList(_remindersKey) ?? const <String>[]).toSet(),
      alertsOn: prefs.getBool(_alertsKey) ?? true,
    );
  }

  Future<void> toggleReminder(String bookingId) async {
    final next = {...state.reminders};
    if (!next.remove(bookingId)) next.add(bookingId);
    state = state.copyWith(reminders: next);
    await (await SharedPreferences.getInstance()).setStringList(_remindersKey, next.toList());
  }

  Future<void> setAlerts(bool on) async {
    state = state.copyWith(alertsOn: on);
    await (await SharedPreferences.getInstance()).setBool(_alertsKey, on);
  }
}

final localKitProvider = NotifierProvider<LocalKitController, LocalKit>(LocalKitController.new);
