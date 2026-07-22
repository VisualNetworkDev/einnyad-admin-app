import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_controller.dart';
import '../core/value_helpers.dart';
import '../widgets/common.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, required this.controller});

  final AdminController controller;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final _raw = TextEditingController();

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  Future<void> _scanCamera() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (value == null || value.isEmpty || !mounted) return;
    _raw.text = value;
    await _verify();
  }

  Future<void> _scanImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final scanner = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
    try {
      final capture = await scanner.analyzeImage(file.path);
      final value = capture?.barcodes.firstOrNull?.rawValue?.trim() ?? '';
      if (value.isEmpty) throw Exception('No pude leer un QR en esa imagen.');
      _raw.text = value;
      if (mounted) await _verify();
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    } finally {
      await scanner.dispose();
    }
  }

  Future<void> _verify() async {
    final raw = _raw.text.trim();
    if (raw.isEmpty) {
      showMessage(context, 'Escanea o pega el contenido del QR.', error: true);
      return;
    }
    await showQrAppointmentSheet(
      context,
      controller: widget.controller,
      raw: raw,
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const SectionHeading(
        'QR de cita',
        subtitle:
            'Marca llegada, inicia el servicio, agrega extras y finaliza con recibo actualizado.',
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _raw,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Token o contenido del QR',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _scanCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Escanear con cámara'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _scanImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Leer QR desde una foto'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _verify,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Verificar texto pegado'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Una cita completada queda en modo solo lectura. Para evitar duplicar recibos, la app pide confirmación antes de finalizar.',
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim() ?? '';
    if (value.isEmpty) return;
    _handled = true;
    await _controller.stop();
    if (mounted) Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.all(20),
            child: Card(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .94),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Mantén el código centrado dentro del cuadro.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showQrAppointmentSheet(
  BuildContext context, {
  required AdminController controller,
  required String raw,
}) async {
  if (raw.trim().isEmpty) {
    showMessage(context, 'Esta cita no tiene token QR.', error: true);
    return;
  }
  try {
    final result = await controller.action(
      'verifyAppointmentQr',
      payload: {'raw': raw.trim()},
      message: 'Verificando QR…',
      refreshAfter: false,
    );
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => QrAppointmentView(
        controller: controller,
        initialAppointment: mapOf(result['appointment']),
        receiptOnly: result['receiptOnly'] == true,
      ),
    );
  } catch (error) {
    if (context.mounted) showMessage(context, error.toString(), error: true);
  }
}

class QrAppointmentView extends StatefulWidget {
  const QrAppointmentView({
    super.key,
    required this.controller,
    required this.initialAppointment,
    required this.receiptOnly,
  });

  final AdminController controller;
  final JsonMap initialAppointment;
  final bool receiptOnly;

  @override
  State<QrAppointmentView> createState() => _QrAppointmentViewState();
}

class _QrAppointmentViewState extends State<QrAppointmentView> {
  late JsonMap _appointment;
  late bool _receiptOnly;
  final _extraName = TextEditingController();
  final _extraPrice = TextEditingController(text: '0');
  final _extraNotes = TextEditingController();
  String _serviceId = 'manual';

  @override
  void initState() {
    super.initState();
    _appointment = {...widget.initialAppointment};
    _receiptOnly = widget.receiptOnly;
  }

  @override
  void dispose() {
    _extraName.dispose();
    _extraPrice.dispose();
    _extraNotes.dispose();
    super.dispose();
  }

  Future<void> _action(String action, JsonMap payload, String success) async {
    try {
      final result = await widget.controller.action(
        action,
        payload: payload,
        refreshAfter: true,
      );
      if (!mounted) return;
      setState(() {
        _appointment = mapOf(result['appointment']).isNotEmpty
            ? mapOf(result['appointment'])
            : result;
        _receiptOnly =
            textOf(_appointment['status']) == 'Completed' ||
            textOf(_appointment['qrStatus']) == 'Completed';
      });
      showMessage(context, success);
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  void _selectService(String id) {
    setState(() => _serviceId = id);
    if (id == 'manual') return;
    final service = widget.controller.services.firstWhere(
      (item) => textOf(item['id']) == id,
      orElse: () => {},
    );
    _extraName.text = textOf(service['name']);
    _extraPrice.text = numberOf(service['price']).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final id = textOf(_appointment['appointmentId']);
    final extras = mapsOf(_appointment['extras']);
    final logs = mapsOf(_appointment['qrLogs']);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .65,
      maxChildSize: .98,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  id,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StatusPill(
            _receiptOnly ? 'Solo lectura' : statusEs(_appointment['status']),
          ),
          const SizedBox(height: 16),
          Text(
            textOf(_appointment['customerName']),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(textOf(_appointment['customerPhone'])),
          Text(textOf(_appointment['customerAddress'])),
          const SizedBox(height: 7),
          Text(
            '${textOf(_appointment['preferredDate'])} · ${normalizeTime12(textOf(_appointment['preferredTime']))}',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _QrMetric(
                  'Total actual',
                  money(_appointment['totalUpdated'] ?? _appointment['total']),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QrMetric('Extras', money(_appointment['extraTotal'])),
              ),
            ],
          ),
          if (!_receiptOnly) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _action('updateQrStage', {
                    'appointmentId': id,
                    'stage': 'Client arrived',
                  }, 'Llegada registrada.'),
                  icon: const Icon(Icons.person_pin_circle_outlined),
                  label: const Text('Marcar llegada'),
                ),
                FilledButton.icon(
                  onPressed: () => _action('updateQrStage', {
                    'appointmentId': id,
                    'stage': 'In service',
                  }, 'Servicio iniciado.'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar servicio'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Finalizar cita',
                      message:
                          'Se cerrará el QR y se enviará el recibo final actualizado.',
                    );
                    if (ok && context.mounted) {
                      await _action('finishAppointment', {
                        'appointmentId': id,
                      }, 'Cita finalizada y recibo enviado.');
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar'),
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          Text(
            'Servicios extras',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (extras.isEmpty) const Text('No hay extras agregados.'),
          for (final extra in extras)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(textOf(extra['name'])),
              subtitle: Text(
                textOf(extra['notes'], textOf(extra['paymentMethod'])),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(money(extra['price'])),
                  if (!_receiptOnly)
                    IconButton(
                      onPressed: () => _action('removeAppointmentExtra', {
                        'appointmentId': id,
                        'extraId': extra['extraId'],
                      }, 'Extra removido.'),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          if (!_receiptOnly) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _serviceId,
                      decoration: const InputDecoration(
                        labelText: 'Servicio extra',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'manual',
                          child: Text('Manual'),
                        ),
                        for (final service in widget.controller.services.where(
                          (item) => yesOf(item['available']),
                        ))
                          DropdownMenuItem(
                            value: textOf(service['id']),
                            child: Text(
                              '${textOf(service['name'])} · ${money(service['price'])}',
                            ),
                          ),
                      ],
                      onChanged: (value) => _selectService(value ?? 'manual'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _extraName,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _extraPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio',
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _extraNotes,
                      decoration: const InputDecoration(labelText: 'Notas'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        if (_extraName.text.trim().isEmpty) {
                          showMessage(
                            context,
                            'Escribe el nombre del extra.',
                            error: true,
                          );
                          return;
                        }
                        await _action('saveAppointmentExtra', {
                          'appointmentId': id,
                          'serviceId': _serviceId,
                          'name': _extraName.text,
                          'price': _extraPrice.text,
                          'notes': _extraNotes.text,
                        }, 'Extra agregado.');
                        _extraName.clear();
                        _extraPrice.text = '0';
                        _extraNotes.clear();
                        setState(() => _serviceId = 'manual');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar al recibo'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 32),
          Text(
            'Historial QR',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty) const Text('Sin historial QR todavía.'),
          for (final log in logs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(textOf(log['action'])),
              subtitle: Text(
                '${textOf(log['timestamp'])}\n${textOf(log['notes'])}',
              ),
              isThreeLine: true,
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _QrMetric extends StatelessWidget {
  const _QrMetric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}
