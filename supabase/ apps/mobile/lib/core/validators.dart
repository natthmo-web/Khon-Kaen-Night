import '../l10n/generated/app_localizations.dart';

String? requiredField(AppLocalizations l, String? value) =>
    (value == null || value.trim().isEmpty) ? l.errRequired : null;

String? phoneField(AppLocalizations l, String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
  return RegExp(r'^\+?\d{9,15}$').hasMatch(digits) ? null : l.errPhone;
}
