import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/value_helpers.dart';
import '../widgets/common.dart';
import 'qr_screen.dart';

const appointmentStatuses = [
  'Pending',
  'Confirmed',
  'Client arrived',
  'In service',
  'Completed',
  'Cancelled',
];

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.controller});

  final AdminController controller;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _query = TextEditingController();
  String _status = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<JsonMap> get _filtered {
    final query = _query.text.trim().toLowerCase();
    return widget.controller.appointments.where((item) {
      if (_status.isNotEmpty && textOf(item['status']) != _status) return false;
      if (query.isEmpty) return true;
      final haystack = [
        item['appointmentId'],
        item['customerName'],
        item['customerPhone'],
        item['customerEmail'],
        item['customerAddress'],
        item['preferredDate'],
      ].map(textOf).join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionHeading(
            'Todas las citas',
            subtitle: '${items.length} resultado(s).',
            action: FilledButton.icon(
              onPressed: () =>
                  showAppointmentForm(context, controller: widget.controller),
              icon: const Icon(Icons.add),
              label: const Text('Crear'),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: constraints.maxWidth >= 650
                      ? constraints.maxWidth * .64
                      : constraints.maxWidth,
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar nombre, teléfono, ID o fecha',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth >= 650
                      ? constraints.maxWidth * .30
                      : constraints.maxWidth,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos')),
                      for (final status in appointmentStatuses)
                        DropdownMenuItem(
                          value: status,
                          child: Text(statusEs(status)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _status = value ?? ''),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Card(child: EmptyState('No hay citas con esos filtros.'))
          else
            for (final item in items) ...[
              _AppointmentCard(
                appointment: item,
                controller: widget.controller,
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.controller});

  final JsonMap appointment;
  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    final items = mapsOf(appointment['items']);
    final status = textOf(appointment['status']);
    final color = switch (status) {
      'Completed' => Colors.green,
      'Cancelled' => Theme.of(context).colorScheme.error,
      'In service' => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textOf(appointment['customerName'], 'Sin nombre'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(textOf(appointment['appointmentId'])),
                      ],
                    ),
                  ),
                  StatusPill(statusEs(status), color: color),
                ],
              ),
              const SizedBox(height: 13),
              _InfoLine(
                icon: Icons.schedule,
                text:
                    '${textOf(appointment['preferredDate'])} · ${normalizeTime12(textOf(appointment['preferredTime']))}',
              ),
              _InfoLine(
                icon: Icons.phone_outlined,
                text: textOf(appointment['customerPhone'], 'Sin teléfono'),
              ),
              if (items.isNotEmpty)
                _InfoLine(
                  icon: Icons.design_services_outlined,
                  text: items
                      .map(
                        (item) => textOf(item['nameEs'], textOf(item['name'])),
                      )
                      .where((name) => name.isNotEmpty)
                      .join(', '),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    money(appointment['totalUpdated'] ?? appointment['total']),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          _AppointmentDetails(appointment: appointment, controller: controller),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _AppointmentDetails extends StatelessWidget {
  const _AppointmentDetails({
    required this.appointment,
    required this.controller,
  });

  final JsonMap appointment;
  final AdminController controller;

  Future<void> _run(
    BuildContext context,
    String action,
    JsonMap payload,
    String success, {
    bool close = true,
  }) async {
    try {
      await controller.action(action, payload: payload);
      if (context.mounted) {
        if (close) Navigator.pop(context);
        showMessage(context, success);
      }
    } catch (error) {
      if (context.mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = textOf(appointment['appointmentId']);
    final items = mapsOf(appointment['items']);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  textOf(appointment['customerName']),
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
          Text(id),
          const SizedBox(height: 16),
          StatusPill(statusEs(appointment['status'])),
          const SizedBox(height: 16),
          _InfoLine(
            icon: Icons.schedule,
            text:
                '${textOf(appointment['preferredDate'])} · ${normalizeTime12(textOf(appointment['preferredTime']))}',
          ),
          _InfoLine(
            icon: Icons.phone_outlined,
            text: textOf(appointment['customerPhone']),
          ),
          _InfoLine(
            icon: Icons.email_outlined,
            text: textOf(appointment['customerEmail'], 'Sin correo'),
          ),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text: textOf(appointment['customerAddress']),
          ),
          const Divider(height: 28),
          Text(
            'Servicios',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(textOf(item['nameEs'], textOf(item['name']))),
              subtitle: Text(
                '${intOf(item['quantity'], 1)} × ${money(item['price'])}',
              ),
              trailing: Text(
                money(
                  item['lineTotal'] ??
                      numberOf(item['price']) * intOf(item['quantity'], 1),
                ),
              ),
            ),
          const Divider(height: 28),
          _TotalLine('Subtotal', appointment['subtotal']),
          _TotalLine('Descuento', -numberOf(appointment['discount'])),
          _TotalLine('Cargo domicilio', appointment['travelFee']),
          _TotalLine('Propina', appointment['tip']),
          _TotalLine(
            'Total',
            appointment['totalUpdated'] ?? appointment['total'],
            strong: true,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue:
                appointmentStatuses.contains(textOf(appointment['status']))
                ? textOf(appointment['status'])
                : 'Pending',
            decoration: const InputDecoration(labelText: 'Cambiar estado'),
            items: [
              for (final status in appointmentStatuses)
                DropdownMenuItem(value: status, child: Text(statusEs(status))),
            ],
            onChanged: (value) async {
              if (value == null || value == appointment['status']) return;
              if (value == 'Completed') {
                final ok = await confirmAction(
                  context,
                  title: 'Completar cita',
                  message: 'Se cerrará el QR y se enviará el recibo final.',
                );
                if (!ok) return;
              }
              if (context.mounted) {
                await _run(context, 'updateAppointmentStatus', {
                  'appointmentId': id,
                  'status': value,
                }, 'Estado actualizado.');
              }
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await showAppointmentForm(
                    context,
                    controller: controller,
                    appointment: appointment,
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await showQrAppointmentSheet(
                    context,
                    controller: controller,
                    raw: textOf(appointment['qrToken']),
                  );
                },
                icon: const Icon(Icons.qr_code),
                label: const Text('Abrir QR'),
              ),
              OutlinedButton.icon(
                onPressed: () => _run(context, 'resendAppointmentReceipt', {
                  'appointmentId': id,
                }, 'Recibo reenviado.'),
                icon: const Icon(Icons.forward_to_inbox),
                label: const Text('Reenviar recibo'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Cancelar cita',
                    message: 'La cita quedará cancelada y su QR desactivado.',
                  );
                  if (ok && context.mounted) {
                    await _run(context, 'cancelAppointment', {
                      'appointmentId': id,
                      'reason': 'Cancelada desde app móvil',
                    }, 'Cita cancelada.');
                  }
                },
                icon: const Icon(Icons.event_busy),
                label: const Text('Cancelar'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Borrar cita por completo',
                    message:
                        'Se eliminarán la cita, extras y registros relacionados. Esta acción no se puede deshacer.',
                    confirmLabel: 'Borrar definitivamente',
                    dangerous: true,
                  );
                  if (ok && context.mounted) {
                    await _run(context, 'deleteAppointment', {
                      'appointmentId': id,
                      'confirm': 'DELETE',
                    }, 'Cita borrada.');
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Borrar'),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.strong = false});
  final String label;
  final Object? value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? const TextStyle(fontWeight: FontWeight.w900) : null,
          ),
        ),
        Text(
          money(value),
          style: strong
              ? Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)
              : null,
        ),
      ],
    ),
  );
}

Future<void> showAppointmentForm(
  BuildContext context, {
  required AdminController controller,
  JsonMap? appointment,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: AppointmentForm(controller: controller, appointment: appointment),
    ),
  );
}

class AppointmentForm extends StatefulWidget {
  const AppointmentForm({
    super.key,
    required this.controller,
    this.appointment,
  });

  final AdminController controller;
  final JsonMap? appointment;

  @override
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  final List<JsonMap> _selectedServices = [];
  String _status = 'Confirmed';
  String _language = 'es';
  String _paymentMethod = 'Pago en persona';
  String _paymentStatus = 'Pendiente';

  bool get _editing => widget.appointment != null;

  TextEditingController field(String name, [Object? initial]) => _fields
      .putIfAbsent(name, () => TextEditingController(text: textOf(initial)));

  @override
  void initState() {
    super.initState();
    final item = widget.appointment ?? <String, dynamic>{};
    _status = textOf(item['status'], 'Confirmed');
    _language = textOf(item['language'], 'es');
    _paymentMethod = textOf(item['paymentMethod'], 'Pago en persona');
    _paymentStatus = textOf(item['paymentStatus'], 'Pendiente');
    _selectedServices.addAll(mapsOf(item['items']));
    for (final entry in {
      'name': item['customerName'],
      'phone': item['customerPhone'],
      'email': item['customerEmail'],
      'address': item['customerAddress'],
      'date': item['preferredDate'],
      'time': normalizeTime12(textOf(item['preferredTime'])),
      'travelFee':
          item['travelFee'] ?? widget.controller.config['travelFee'] ?? 0,
      'tip': item['tip'] ?? 0,
      'discount': item['discount'] ?? 0,
      'adminNotes': item['adminNotes'],
      'customerNotes': item['customerNotes'],
    }.entries) {
      field(entry.key, entry.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(field('date').text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) {
      field('date').text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selected != null) {
      var hour = selected.hourOfPeriod;
      if (hour == 0) hour = 12;
      field('time').text =
          '$hour:${selected.minute.toString().padLeft(2, '0')} ${selected.period == DayPeriod.am ? 'AM' : 'PM'}';
    }
  }

  void _addService(JsonMap service) {
    final existing = _selectedServices.indexWhere(
      (item) => textOf(item['id']) == textOf(service['id']),
    );
    setState(() {
      if (existing >= 0) {
        final current = _selectedServices[existing];
        current['quantity'] = intOf(current['quantity'], 1) + 1;
        current['lineTotal'] =
            numberOf(current['price']) * intOf(current['quantity']);
      } else {
        _selectedServices.add({
          'id': service['id'],
          'category': service['category'],
          'name': service['name'],
          'nameEs': service['name'],
          'nameFr': service['nameFr'],
          'price': service['price'],
          'quantity': 1,
          'durationMinutes': service['durationMinutes'],
          'lineTotal': service['price'],
        });
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_editing && _selectedServices.isEmpty) {
      showMessage(context, 'Agrega al menos un servicio.', error: true);
      return;
    }
    final payload = <String, dynamic>{
      'customerName': field('name').text,
      'customerPhone': field('phone').text,
      'customerEmail': field('email').text,
      'customerAddress': field('address').text,
      'preferredDate': field('date').text,
      'preferredTime': normalizeTime12(field('time').text),
      'status': _status,
      'language': _language,
      'paymentMethod': _paymentMethod,
      'paymentStatus': _paymentStatus,
      'travelFee': field('travelFee').text,
      'tip': field('tip').text,
      'discount': field('discount').text,
      'adminNotes': field('adminNotes').text,
      'customerNotes': field('customerNotes').text,
      'items': _selectedServices,
      'overrideAvailability': 'Yes',
    };
    try {
      await widget.controller.action(
        _editing ? 'updateAppointment' : 'createManualAppointment',
        payload: _editing
            ? {
                'appointmentId': widget.appointment!['appointmentId'],
                'appointment': payload,
              }
            : {'appointment': payload},
        message: _editing ? 'Actualizando cita…' : 'Creando cita…',
      );
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, _editing ? 'Cita actualizada.' : 'Cita creada.');
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
      title: Text(_editing ? 'Editar cita' : 'Crear cita'),
      actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeading('Clienta'),
          const SizedBox(height: 14),
          TextFormField(
            controller: field('name'),
            decoration: const InputDecoration(labelText: 'Nombre *'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('phone'),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono *'),
            validator: (value) =>
                (value ?? '').replaceAll(RegExp(r'\D'), '').length < 7
                ? 'Teléfono no válido'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('email'),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('address'),
            decoration: const InputDecoration(labelText: 'Dirección *'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 22),
          const SectionHeading('Fecha y estado'),
          const SizedBox(height: 14),
          TextFormField(
            controller: field('date'),
            readOnly: true,
            onTap: _pickDate,
            decoration: const InputDecoration(
              labelText: 'Fecha *',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            validator: (value) => (value ?? '').isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('time'),
            readOnly: true,
            onTap: _pickTime,
            decoration: const InputDecoration(
              labelText: 'Hora *',
              suffixIcon: Icon(Icons.schedule),
            ),
            validator: (value) => (value ?? '').isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              for (final status in appointmentStatuses)
                DropdownMenuItem(value: status, child: Text(statusEs(status))),
            ],
            onChanged: (value) => _status = value ?? _status,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Idioma de recibos'),
            items: const [
              DropdownMenuItem(value: 'es', child: Text('Español')),
              DropdownMenuItem(value: 'fr', child: Text('Français')),
            ],
            onChanged: (value) => _language = value ?? _language,
          ),
          if (!_editing) ...[
            const SizedBox(height: 22),
            const SectionHeading('Servicios'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Agregar servicio'),
              items: [
                for (final service in widget.controller.services.where(
                  (s) => yesOf(s['available']),
                ))
                  DropdownMenuItem(
                    value: textOf(service['id']),
                    child: Text(
                      '${textOf(service['name'])} · ${money(service['price'])}',
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                final service = widget.controller.services.firstWhere(
                  (item) => textOf(item['id']) == id,
                );
                _addService(service);
              },
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < _selectedServices.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(textOf(_selectedServices[index]['name'])),
                subtitle: Text(
                  'Cantidad: ${intOf(_selectedServices[index]['quantity'], 1)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(money(_selectedServices[index]['lineTotal'])),
                    IconButton(
                      onPressed: () =>
                          setState(() => _selectedServices.removeAt(index)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 22),
          const SectionHeading('Pago y totales'),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Método de pago'),
            onChanged: (value) => _paymentMethod = value,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _paymentStatus,
            decoration: const InputDecoration(labelText: 'Estado del pago'),
            onChanged: (value) => _paymentStatus = value,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final moneyFields = <Widget>[
                _moneyField('travelFee', 'Domicilio'),
                _moneyField('tip', 'Propina'),
                if (!_editing) _moneyField('discount', 'Descuento'),
              ];
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    for (final item in moneyFields) ...[
                      item,
                      if (item != moneyFields.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (final item in moneyFields) ...[
                    Expanded(child: item),
                    if (item != moneyFields.last) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('adminNotes'),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas administrativas',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('customerNotes'),
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notas de la clienta'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(
              _editing ? 'Guardar cambios' : 'Crear y enviar recibos',
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );

  Widget _moneyField(String key, String label) => TextFormField(
    controller: field(key),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, prefixText: '\$ '),
  );
}
