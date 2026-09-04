import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/biometric_access.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AdminController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _enableBiometrics = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _email.text = widget.controller.rememberedEmail;
    _enableBiometrics = widget.controller.biometricState.enabled;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = '');
    try {
      await widget.controller.login(
        _email.text,
        _password.text,
        enableBiometrics: _enableBiometrics,
      );
      _password.clear();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _quickLogin() async {
    setState(() => _error = '');
    try {
      await widget.controller.loginWithBiometrics();
    } on BiometricAccessException catch (error) {
      if (mounted && !error.cancelled) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _forgetQuickLogin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar el acceso rápido?'),
        content: const Text(
          'Se borrará el acceso guardado en este teléfono. Podrás seguir entrando con tu correo y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.forgetBiometrics();
      if (mounted) setState(() => _enableBiometrics = false);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                const AppLogo(size: 112),
                const SizedBox(height: 20),
                Text(
                  'EinnyadNails Admin',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Panel privado para manejar citas, servicios, QR y el negocio desde el teléfono.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 26),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Acceso de la dueña',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 18),
                          if (widget.controller.biometricState.enabled) ...[
                            FilledButton.icon(
                              onPressed: widget.controller.busy
                                  ? null
                                  : _quickLogin,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Entrar con huella o rostro'),
                            ),
                            TextButton(
                              onPressed: widget.controller.busy
                                  ? null
                                  : _forgetQuickLogin,
                              child: const Text(
                                'Quitar acceso rápido de este teléfono',
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'O entra con tu contraseña',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) =>
                                (value ?? '').trim().contains('@')
                                ? null
                                : 'Escribe el correo administrativo.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _hidePassword,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'Escribe la contraseña.'
                                : null,
                          ),
                          if (widget.controller.biometricState.available) ...[
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _enableBiometrics,
                              onChanged: widget.controller.busy
                                  ? null
                                  : (value) => setState(
                                      () => _enableBiometrics = value ?? false,
                                    ),
                              title: const Text(
                                'Activar acceso rápido en este teléfono',
                              ),
                              subtitle: const Text(
                                'Con huella o rostro compatible. Actívalo solo en tu teléfono personal.',
                              ),
                            ),
                          ],
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: widget.controller.busy ? null : _login,
                            icon: widget.controller.busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                widget.controller.busy
                                    ? widget.controller.busyMessage
                                    : 'Entrar al panel',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
