import 'package:flutter/services.dart';

String formatEmail(String value) {
  final cleaned = value.replaceAll(RegExp(r'\s'), '');
  final at = cleaned.indexOf('@');
  return at < 0
      ? cleaned
      : '${cleaned.substring(0, at)}${cleaned.substring(at).toLowerCase()}';
}

bool isValidEmail(String value) {
  if (value.length > 254 || value.contains(RegExp(r'\s'))) return false;
  final parts = value.split('@');
  if (parts.length != 2) return false;
  final local = parts[0];
  if (local.isEmpty ||
      local.length > 64 ||
      local.startsWith('.') ||
      local.endsWith('.') ||
      local.contains('..') ||
      !RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
    return false;
  }
  final labels = parts[1].split('.');
  return labels.length >= 2 &&
      labels.every(
        (label) =>
            label.length <= 63 &&
            RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$')
                .hasMatch(label),
      ) &&
      RegExp(r'^[a-zA-Z]{2,63}$').hasMatch(labels.last);
}

class EmailInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    int offset(int position) => position < 0
        ? position
        : newValue.text
              .substring(0, position)
              .replaceAll(RegExp(r'\s'), '')
              .length;
    return TextEditingValue(
      text: formatEmail(newValue.text),
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
      ),
    );
  }
}
