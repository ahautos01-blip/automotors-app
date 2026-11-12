import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/password_recovery_service.dart';
import 'l10n/ui_text.dart';

class PasswordRecoveryPage extends StatefulWidget {
  final String initialEmail;
  final PasswordRecoveryService Function() createService;
  const PasswordRecoveryPage({
    super.key,
    required this.createService,
    this.initialEmail = '',
  });
  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  PasswordRecoveryService? service;
  int step = 0;
  bool busy = false, hide = true;
  String? message;
  @override
  void initState() {
    super.initState();
    email.text = widget.initialEmail;
  }

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    confirmation.dispose();
    if (service != null) unawaited(service!.close());
    super.dispose();
  }

  Future<void> act({bool resend = false}) async {
    if (busy || (!resend && !form.currentState!.validate())) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      message = null;
    });
    try {
      service ??= widget.createService();
      if (step == 0 || resend) {
        await service!.request(email.text);
        if (mounted) {
          setState(() {
            step = 1;
            code.clear();
            message = 'Si existe una cuenta con ese correo, recibirás un código. Revisa también spam.';
          });
        }
      } else if (step == 1) {
        await service!.verify(code.text);
        if (mounted) {
          setState(() {
            step = 2;
            code.clear();
          });
        }
      } else {
        await service!.updatePassword(password.text);
        if (mounted) Navigator.pop(context, email.text.trim());
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          message =
              error is AuthException &&
                  error.code == 'over_email_send_rate_limit'
              ? 'Espera un minuto antes de solicitar otro correo.'
              : error is AuthException &&
                    error.message ==
                        'Espera un minuto antes de solicitar otro correo.'
              ? error.message
              : step == 0 || resend
              ? 'No se pudo enviar el correo. Comprueba la conexión e inténtalo de nuevo.'
              : step == 1
              ? 'El código no es válido o ha caducado. Compruébalo o solicita otro.'
              : 'No se pudo cambiar la contraseña. Prueba otra contraseña o inicia de nuevo la recuperación.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String value) => uiText(context, value);
    return Scaffold(
      appBar: AppBar(title: Text(t('Recuperar contraseña'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    t(
                      step == 0
                          ? 'Introduce tu correo para recuperar el acceso.'
                          : step == 1
                          ? 'Introduce el código recibido por correo. No lo compartas con nadie.'
                          : 'Elige una contraseña nueva de al menos 8 caracteres.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (step == 0)
                    TextFormField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: t('Correo electrónico'),
                      ),
                      validator: (v) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : t('Introduce un correo válido'),
                    ),
                  if (step == 1)
                    TextFormField(
                      controller: code,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: t('Código de recuperación'),
                      ),
                      validator: (v) => RegExp(r'^\d{6,10}$').hasMatch(v ?? '')
                          ? null
                          : t('Introduce el código recibido por correo.'),
                    ),
                  if (step == 2) ...[
                    TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: hide,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: t('Nueva contraseña'),
                        suffixIcon: IconButton(
                          tooltip: t(
                            hide ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          ),
                          onPressed: () => setState(() => hide = !hide),
                          icon: Icon(
                            hide ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) < 8
                          ? t('Usa al menos 8 caracteres.')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmation,
                      enabled: !busy,
                      obscureText: hide,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: t('Repetir contraseña'),
                      ),
                      validator: (v) => v != password.text
                          ? t('Las contraseñas no coinciden.')
                          : null,
                    ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(t(message!)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : () => act(),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            t(
                              step == 0
                                  ? 'Enviar código'
                                  : step == 1
                                  ? 'Comprobar código'
                                  : 'Guardar nueva contraseña',
                            ),
                          ),
                  ),
                  if (step == 1)
                    TextButton(
                      onPressed: busy ? null : () => act(resend: true),
                      child: Text(t('Reenviar código')),
                    ),
                  if (step > 0)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() {
                                busy = true;
                              });
                              await service?.close();
                              service = null;
                              if (mounted) {
                                setState(() {
                                  step = 0;
                                  busy = false;
                                  message = null;
                                  code.clear();
                                  password.clear();
                                  confirmation.clear();
                                });
                              }
                            },
                      child: Text(t('Iniciar otra recuperación')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
