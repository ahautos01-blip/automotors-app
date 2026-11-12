import 'package:flutter/material.dart';

import 'l10n/ui_text.dart';
import 'support_page.dart';

/// Consent is deliberate and required for each login/registration submission.
class TermsAcceptanceField extends StatelessWidget {
  const TermsAcceptanceField({super.key});
  @override
  Widget build(BuildContext context) => FormField<bool>(
    initialValue: false,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (accepted) => accepted == true
        ? null
        : uiText(
            context,
            'Debes aceptar las condiciones de uso para continuar.',
          ),
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: field.value ?? false,
          onChanged: field.didChange,
          title: Text(
            uiText(
              context,
              'Acepto las condiciones de uso y las normas de la comunidad.',
            ),
          ),
          subtitle: Text(
            uiText(
              context,
              'Tolerancia cero con el contenido inapropiado, el fraude y los usuarios abusivos.',
            ),
          ),
        ),
        TextButton(
          onPressed: () => openAutomotorsSupport(context, section: 'terms'),
          child: Text(uiText(context, 'Leer condiciones de uso')),
        ),
        if (field.errorText != null)
          Semantics(
            liveRegion: true,
            child: Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );
}
