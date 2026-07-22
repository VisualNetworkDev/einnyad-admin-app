import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_controller.dart';
import '../core/value_helpers.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AdminController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, TextEditingController> _fields = {};
  final List<_HourEditor> _hours = [];
  String _qrEnabled = 'Yes';
  String _remindersEnabled = 'Yes';
  String _paymentsEnabled = 'Yes';
  String _cashEnabled = 'Yes';
  String _promoType = 'percent';
  String _promoActive = 'Yes';
  String _updateUrl = '';

  TextEditingController field(String key, [Object? value]) => _fields
      .putIfAbsent(key, () => TextEditingController(text: textOf(value)));

  @override
  void initState() {
    super.initState();
    _loadFromController();
    widget.controller.updateManifestUrl().then((value) {
      if (mounted) {
        field('updateUrl').text = value;
        setState(() => _updateUrl = value);
      }
    });
  }

  void _loadFromController() {
    final config = widget.controller.config;
    final payments = widget.controller.payments;
    _qrEnabled = textOf(config['qrEnabled'], 'Yes');
    _remindersEnabled = textOf(config['remindersEnabled'], 'Yes');
    _paymentsEnabled = textOf(payments['enabled'], 'Yes');
    _cashEnabled = textOf(payments['cashEnabled'], 'Yes');
    final values = <String, Object?>{
      'name': config['name'],
      'ownerName': config['ownerName'],
      'phone': config['phone'],
      'email': config['ownerEmail'] ?? config['email'],
      'serviceArea': config['serviceArea'] ?? config['address'],
      'about': config['aboutText'],
      'travelFee': config['travelFee'] ?? 0,
      'instagram': config['instagramUrl'],
      'cancelEs': config['cancellationPolicyEs'],
      'cancelFr': config['cancellationPolicyFr'],
      'depositEs': config['depositPolicyEs'],
      'depositFr': config['depositPolicyFr'],
      'reminderHours': config['reminderHoursBefore'] ?? 24,
      'payProvider': payments['provider'] ?? 'Interac e-Transfer',
      'payLink': payments['interacRecipient'] ?? payments['link'],
      'payLabel': payments['buttonLabel'] ?? 'Ver datos de Interac',
      'payMessageEs': payments['redirectMessageEs'],
      'payMessageFr': payments['redirectMessageFr'],
      'blockDate': '',
      'blockStart': '',
      'blockEnd': '',
      'blockReason': '',
      'promoCode': '',
      'promoTitle': '',
      'promoTitleFr': '',
      'promoDescription': '',
      'promoDescriptionFr': '',
      'promoValue': '0',
      'promoMin': '0',
    };
    for (final entry in values.entries) {
      field(entry.key, entry.value);
    }
    final hours = mapsOf(widget.controller.availability['hours']);
    final defaults = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    _hours
      ..clear()
      ..addAll(
        defaults.map((day) {
          final found = hours.firstWhere(
            (item) => textOf(item['day']) == day,
            orElse: () => {
              'day': day,
              'open': '9:00 AM',
              'close': day == 'Domingo' ? '' : '6:00 PM',
              'active': day == 'Domingo' ? 'No' : 'Yes',
            },
          );
          return _HourEditor.from(found);
        }),
      );
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final hour in _hours) {
      hour.dispose();
    }
    super.dispose();
  }

  Future<void> _saveBusiness() async {
    final config = {
      'name': field('name').text,
      'ownerName': field('ownerName').text,
      'phone': field('phone').text,
      'email': field('email').text,
      'ownerEmail': field('email').text,
      'serviceArea': field('serviceArea').text,
      'address': field('serviceArea').text,
      'aboutText': field('about').text,
      'taxRate': 0,
      'travelFee': field('travelFee').text,
      'instagramUrl': field('instagram').text,
      'qrEnabled': _qrEnabled,
      'cancellationPolicyEs': field('cancelEs').text,
      'cancellationPolicyFr': field('cancelFr').text,
      'depositPolicyEs': field('depositEs').text,
      'depositPolicyFr': field('depositFr').text,
      'remindersEnabled': _remindersEnabled,
      'reminderHoursBefore': field('reminderHours').text,
    };
    await _run('saveSalonConfig', {
      'config': config,
    }, 'Ajustes del negocio guardados.');
  }

  Future<void> _savePayments() => _run('savePaymentsConfig', {
    'enabled': _paymentsEnabled,
    'provider': field('payProvider').text,
    'link': field('payLink').text,
    'buttonLabel': field('payLabel').text,
    'redirectMessageEs': field('payMessageEs').text,
    'redirectMessageFr': field('payMessageFr').text,
    'cashEnabled': _cashEnabled,
  }, 'Configuración de pagos guardada.');

  Future<void> _saveHours() => _run('saveBusinessHours', {
    'hours': [for (final hour in _hours) hour.payload],
  }, 'Horarios guardados.');

  Future<void> _saveBlock() async {
    await _run('saveBlockedSlot', {
      'date': field('blockDate').text,
      'startTime': normalizeTime12(field('blockStart').text),
      'endTime': normalizeTime12(field('blockEnd').text),
      'reason': field('blockReason').text,
    }, 'Bloqueo guardado.');
    field('blockDate').clear();
    field('blockStart').clear();
    field('blockEnd').clear();
    field('blockReason').clear();
  }

  Future<void> _savePromo() async {
    await _run('savePromotion', {
      'promotion': {
        'code': field('promoCode').text,
        'title': field('promoTitle').text,
        'titleFr': field('promoTitleFr').text,
        'description': field('promoDescription').text,
        'descriptionFr': field('promoDescriptionFr').text,
        'type': _promoType,
        'value': field('promoValue').text,
        'active': _promoActive,
        'minSubtotal': field('promoMin').text,
      },
    }, 'Promoción guardada.');
    for (final key in [
      'promoCode',
      'promoTitle',
      'promoTitleFr',
      'promoDescription',
      'promoDescriptionFr',
    ]) {
      field(key).clear();
    }
  }

  Future<void> _run(
    String action,
    JsonMap payload,
    String success, {
    bool refresh = true,
  }) async {
    try {
      await widget.controller.action(
        action,
        payload: payload,
        refreshAfter: refresh,
      );
      if (mounted) showMessage(context, success);
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) {
      controller.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selected != null) {
      var hour = selected.hourOfPeriod;
      if (hour == 0) hour = 12;
      controller.text =
          '$hour:${selected.minute.toString().padLeft(2, '0')} ${selected.period == DayPeriod.am ? 'AM' : 'PM'}';
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const SectionHeading(
        'Ajustes del negocio',
        subtitle:
            'Los mismos controles del panel web, organizados por sección.',
      ),
      const SizedBox(height: 14),
      _SettingsCard(
        title: 'Negocio y políticas',
        icon: Icons.storefront_outlined,
        initiallyExpanded: true,
        children: _businessFields(),
      ),
      _SettingsCard(
        title: 'Pagos / Interac',
        icon: Icons.payments_outlined,
        children: _paymentFields(),
      ),
      _SettingsCard(
        title: 'Horarios y bloqueos',
        icon: Icons.schedule,
        children: _availabilityFields(),
      ),
      _SettingsCard(
        title: 'Promociones',
        icon: Icons.local_offer_outlined,
        children: _promotionFields(),
      ),
      _SettingsCard(
        title: 'Recordatorios y registros',
        icon: Icons.notifications_active_outlined,
        children: _operationsFields(),
      ),
      _SettingsCard(
        title: 'Actualizaciones de la app',
        icon: Icons.system_update_alt,
        children: _updateFields(),
      ),
      const SizedBox(height: 30),
    ],
  );

  List<Widget> _businessFields() => [
    _text('name', 'Nombre del negocio'),
    _text('ownerName', 'Nombre de la dueña'),
    _text('phone', 'Teléfono', keyboard: TextInputType.phone),
    _text('email', 'Correo de la dueña', keyboard: TextInputType.emailAddress),
    _text('serviceArea', 'Área de servicio / dirección'),
    _text('about', 'Descripción', lines: 4),
    _text(
      'travelFee',
      'Cargo de domicilio',
      keyboard: const TextInputType.numberWithOptions(decimal: true),
      prefix: '\$ ',
    ),
    _text('instagram', 'Instagram URL', keyboard: TextInputType.url),
    _yesNo(
      'QR en las citas',
      _qrEnabled,
      (value) => setState(() => _qrEnabled = value),
    ),
    _text('cancelEs', 'Política de cancelación (ES)', lines: 3),
    _text('cancelFr', 'Politique d’annulation (FR)', lines: 3),
    _text('depositEs', 'Política de depósito (ES)', lines: 3),
    _text('depositFr', 'Politique de dépôt (FR)', lines: 3),
    _yesNo(
      'Recordatorios activos',
      _remindersEnabled,
      (value) => setState(() => _remindersEnabled = value),
    ),
    _text(
      'reminderHours',
      'Horas antes del recordatorio',
      keyboard: TextInputType.number,
    ),
    FilledButton.icon(
      onPressed: _saveBusiness,
      icon: const Icon(Icons.save),
      label: const Text('Guardar ajustes del negocio'),
    ),
  ];

  List<Widget> _paymentFields() => [
    _yesNo(
      'Pagos activos',
      _paymentsEnabled,
      (value) => setState(() => _paymentsEnabled = value),
    ),
    _text('payProvider', 'Proveedor'),
    _text('payLink', 'Correo, teléfono o enlace Interac'),
    _text('payLabel', 'Texto del botón'),
    _text('payMessageEs', 'Instrucciones (ES)', lines: 4),
    _text('payMessageFr', 'Instructions (FR)', lines: 4),
    _yesNo(
      'Pago en efectivo',
      _cashEnabled,
      (value) => setState(() => _cashEnabled = value),
    ),
    FilledButton.icon(
      onPressed: _savePayments,
      icon: const Icon(Icons.save),
      label: const Text('Guardar pagos'),
    ),
  ];

  List<Widget> _availabilityFields() => [
    Text(
      'Horarios semanales',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
    for (final hour in _hours)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  hour.day,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                value: hour.active,
                onChanged: (value) => setState(() => hour.active = value),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hour.open,
                      readOnly: true,
                      onTap: () => _pickTime(hour.open),
                      decoration: const InputDecoration(labelText: 'Abre'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: hour.close,
                      readOnly: true,
                      onTap: () => _pickTime(hour.close),
                      decoration: const InputDecoration(labelText: 'Cierra'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    FilledButton.icon(
      onPressed: _saveHours,
      icon: const Icon(Icons.save),
      label: const Text('Guardar horarios'),
    ),
    const Divider(height: 30),
    Text(
      'Bloquear día u hora',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
    TextField(
      controller: field('blockDate'),
      readOnly: true,
      onTap: () => _pickDate(field('blockDate')),
      decoration: const InputDecoration(labelText: 'Fecha'),
    ),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: field('blockStart'),
            readOnly: true,
            onTap: () => _pickTime(field('blockStart')),
            decoration: const InputDecoration(labelText: 'Inicio'),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: TextField(
            controller: field('blockEnd'),
            readOnly: true,
            onTap: () => _pickTime(field('blockEnd')),
            decoration: const InputDecoration(labelText: 'Fin'),
          ),
        ),
      ],
    ),
    _text('blockReason', 'Motivo'),
    FilledButton.icon(
      onPressed: _saveBlock,
      icon: const Icon(Icons.block),
      label: const Text('Guardar bloqueo'),
    ),
    Text(
      'Bloqueos activos',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
    if (mapsOf(
      widget.controller.availability['blocks'],
    ).where((b) => textOf(b['active']) != 'No').isEmpty)
      const Text('No hay bloqueos activos.'),
    for (final block in mapsOf(
      widget.controller.availability['blocks'],
    ).where((b) => textOf(b['active']) != 'No'))
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          '${textOf(block['date'])} · ${normalizeTime12(textOf(block['startTime']))}-${normalizeTime12(textOf(block['endTime']))}',
        ),
        subtitle: Text(textOf(block['reason'], 'Bloqueo manual')),
        trailing: IconButton(
          onPressed: () => _run('removeBlockedSlot', {
            'blockId': block['blockId'],
          }, 'Bloqueo removido.'),
          icon: const Icon(Icons.close),
        ),
      ),
  ];

  List<Widget> _promotionFields() => [
    if (widget.controller.promotions.isNotEmpty) ...[
      Text(
        'Promociones activas',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      for (final promo in widget.controller.promotions)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.local_offer_outlined),
          title: Text('${textOf(promo['code'])} · ${textOf(promo['title'])}'),
          subtitle: Text(
            '${textOf(promo['type'])} ${promo['value']} · ${yesOf(promo['active']) ? 'Activa' : 'Inactiva'}',
          ),
        ),
      const Divider(),
    ],
    _text('promoCode', 'Código'),
    _text('promoTitle', 'Título (ES)'),
    _text('promoTitleFr', 'Titre (FR)'),
    _text('promoDescription', 'Descripción (ES)', lines: 3),
    _text('promoDescriptionFr', 'Description (FR)', lines: 3),
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _promoType,
      decoration: const InputDecoration(labelText: 'Tipo'),
      items: const [
        DropdownMenuItem(value: 'percent', child: Text('Porcentaje')),
        DropdownMenuItem(value: 'fixed', child: Text('Monto fijo')),
      ],
      onChanged: (value) => setState(() => _promoType = value ?? _promoType),
    ),
    _text(
      'promoValue',
      'Valor',
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    ),
    _text(
      'promoMin',
      'Subtotal mínimo',
      keyboard: const TextInputType.numberWithOptions(decimal: true),
      prefix: '\$ ',
    ),
    _yesNo(
      'Promoción activa',
      _promoActive,
      (value) => setState(() => _promoActive = value),
    ),
    FilledButton.icon(
      onPressed: _savePromo,
      icon: const Icon(Icons.save),
      label: const Text('Guardar promoción'),
    ),
  ];

  List<Widget> _operationsFields() => [
    FilledButton.tonalIcon(
      onPressed: () async {
        try {
          final result = await widget.controller.action(
            'sendRemindersNow',
            payload: {'hoursBefore': field('reminderHours').text},
            refreshAfter: false,
          );
          if (mounted) {
            final sent = result['sent'];
            showMessage(
              context,
              'Recordatorios enviados: ${sent is List ? sent.length : 0}',
            );
          }
        } catch (error) {
          if (mounted) showMessage(context, error.toString(), error: true);
        }
      },
      icon: const Icon(Icons.send),
      label: const Text('Enviar recordatorios ahora'),
    ),
    OutlinedButton.icon(
      onPressed: () => _run(
        'setupReminderTrigger',
        {},
        'Trigger diario activado para las 8 AM.',
        refresh: false,
      ),
      icon: const Icon(Icons.alarm_add),
      label: const Text('Activar trigger diario'),
    ),
    const Divider(),
    Text(
      'Logs recientes',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
    if (widget.controller.logs.isEmpty) const Text('No hay logs.'),
    SizedBox(
      height: widget.controller.logs.isEmpty ? 20 : 360,
      child: widget.controller.logs.isEmpty
          ? null
          : ListView.separated(
              itemCount: widget.controller.logs.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final log = widget.controller.logs[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(textOf(log['action'])),
                  subtitle: Text(
                    '${textOf(log['timestamp'])}\n${textOf(log['details'])}',
                  ),
                  trailing: StatusPill(textOf(log['result'])),
                );
              },
            ),
    ),
    OutlinedButton.icon(
      onPressed: () async {
        final ok = await confirmAction(
          context,
          title: 'Borrar logs',
          message: 'Esto limpia logs técnicos y QR. No borra citas.',
          dangerous: true,
        );
        if (ok) await _run('clearLogs', {}, 'Logs borrados.');
      },
      icon: const Icon(Icons.delete_sweep_outlined),
      label: const Text('Borrar logs'),
    ),
    const Divider(),
    OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      onPressed: () async {
        final ok = await confirmAction(
          context,
          title: 'Limpiar datos de producción',
          message:
              'Borrará citas, extras, sesiones, logs, bloqueos, reseñas y promociones demo. Mantiene configuración, pagos, horarios, servicios, fotos y dueña.',
          confirmLabel: 'Limpiar datos',
          dangerous: true,
        );
        if (ok) {
          await _run('cleanProductionData', {
            'confirm': 'CLEAN',
          }, 'Limpieza completada.');
        }
      },
      icon: const Icon(Icons.warning_amber),
      label: const Text('Limpiar hojas para producción'),
    ),
  ];

  List<Widget> _updateFields() => [
    FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline),
        title: const Text('Versión instalada'),
        subtitle: Text(
          snapshot.hasData
              ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
              : 'Consultando…',
        ),
      ),
    ),
    TextFormField(
      controller: field('updateUrl'),
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'URL HTTPS del manifiesto de actualización',
        helperText: 'Se puede cambiar aquí sin recompilar la app.',
      ),
      onChanged: (value) => _updateUrl = value,
    ),
    OutlinedButton.icon(
      onPressed: () async {
        await widget.controller.saveUpdateManifestUrl(_updateUrl);
        if (mounted) showMessage(context, 'URL de actualización guardada.');
      },
      icon: const Icon(Icons.save_outlined),
      label: const Text('Guardar URL'),
    ),
    FilledButton.icon(
      onPressed: () async {
        try {
          await widget.controller.saveUpdateManifestUrl(_updateUrl);
          final update = await widget.controller.checkForUpdate();
          if (!mounted) return;
          showMessage(
            context,
            update == null
                ? 'Ya tienes la versión más reciente.'
                : 'Actualización ${update.version} (${update.buildNumber}) disponible.',
          );
          setState(() {});
        } catch (error) {
          if (mounted) showMessage(context, error.toString(), error: true);
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Buscar actualización'),
    ),
    if (widget.controller.availableUpdate case final update?)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva versión ${update.version} (${update.buildNumber})',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (update.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(update.releaseNotes),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    final result = await widget.controller.installUpdate(
                      update,
                    );
                    if (mounted) showMessage(context, result);
                  } catch (error) {
                    if (mounted) {
                      showMessage(context, error.toString(), error: true);
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Descargar e instalar'),
              ),
            ],
          ),
        ),
      ),
    const Text(
      'Android descarga el APK, verifica SHA-256 si está configurado y abre el instalador. En iPhone abre el Source de AltStore; iOS exige confirmar la instalación fuera de la app.',
    ),
  ];

  Widget _text(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
    String? prefix,
  }) => TextField(
    controller: field(key),
    maxLines: lines,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label, prefixText: prefix),
  );

  Widget _yesNo(String label, String value, ValueChanged<String> changed) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: 'Yes', child: Text('Sí')),
          DropdownMenuItem(value: 'No', child: Text('No')),
        ],
        onChanged: (next) {
          if (next != null) changed(next);
        },
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children) ...[child, const SizedBox(height: 12)],
        ],
      ),
    ),
  );
}

class _HourEditor {
  _HourEditor({
    required this.day,
    required String open,
    required String close,
    required this.active,
  }) : open = TextEditingController(text: normalizeTime12(open)),
       close = TextEditingController(text: normalizeTime12(close));

  factory _HourEditor.from(JsonMap value) => _HourEditor(
    day: textOf(value['day']),
    open: textOf(value['open']),
    close: textOf(value['close']),
    active: yesOf(value['active']),
  );

  final String day;
  final TextEditingController open;
  final TextEditingController close;
  bool active;

  JsonMap get payload => {
    'day': day,
    'open': normalizeTime12(open.text),
    'close': normalizeTime12(close.text),
    'active': active ? 'Yes' : 'No',
  };

  void dispose() {
    open.dispose();
    close.dispose();
  }
}
