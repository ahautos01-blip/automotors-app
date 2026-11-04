import 'package:flutter/widgets.dart';

import 'ui_messages.dart';

/// Translates app-owned copy and substitutes values without translating them.
String uiText(
  BuildContext context,
  String source, [
  List<Object?> values = const [],
]) => translateUiMessage(
  source,
  Localizations.localeOf(context).languageCode,
  values,
);

String translateUiMessage(
  String source,
  String language, [
  List<Object?> values = const [],
]) {
  final translations = uiMessages[source];
  final template = language == 'en'
      ? (translations?[0] ?? source)
      : language == 'ca'
      ? (translations?[1] ?? source)
      : source;
  return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
    final index = int.parse(match[1]!);
    return index < values.length ? values[index]?.toString() ?? '' : match[0]!;
  });
}
