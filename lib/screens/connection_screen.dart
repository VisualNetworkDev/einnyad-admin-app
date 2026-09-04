import 'package:flutter/material.dart';
import '../app_controller.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 64),
                const SizedBox(height: 20),
                Text(
                  'No se pudo cargar el panel',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu acceso está guardado. Revisa la conexión y vuelve a intentar; no necesitas escribir la contraseña otra vez.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(controller.lastError, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: controller.busy
                      ? null
                      : controller.retryConnection,
                  icon: const Icon(Icons.refresh),
                  label: Text(controller.busy ? 'Conectando…' : 'Reintentar'),
                ),
                TextButton(
                  onPressed: controller.busy ? null : controller.logout,
                  child: const Text('Cerrar sesión y usar otro acceso'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
