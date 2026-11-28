import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [text] to the clipboard and confirms with a snackbar. Works on web, iOS and Android without a plugin.
Future<void> shareText(BuildContext context, String text, String copiedLabel) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copiedLabel)));
  }
}
