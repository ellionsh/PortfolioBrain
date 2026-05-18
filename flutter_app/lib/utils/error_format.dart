import 'package:flutter/material.dart';

String formatApiError(Object error) {
  final msg = error.toString();
  return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
}

String formatErrorMessage(String? message) {
  if (message == null) return '';
  final msg = message.toString();
  return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
}

void showErrorSnackBar(BuildContext context, Object? error, {String? prefix}) {
  final msg = error == null
      ? ''
      : (error is String ? formatErrorMessage(error) : formatApiError(error));
  final text = (prefix ?? '').isEmpty ? msg : '${prefix!}$msg';
  if (text.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
