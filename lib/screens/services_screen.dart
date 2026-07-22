import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../app_controller.dart';
import '../core/value_helpers.dart';
import '../widgets/common.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.controller});

  final AdminController controller;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final items = widget.controller.services.where((item) {
      final text = '${item['category']} ${item['name']} ${item['nameFr']}'
          .toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionHeading(
            'Servicios activos',
            subtitle: 'Catálogo, fotos principales y resultados antes/después.',
            action: FilledButton.icon(
              onPressed: () => _showServiceForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Buscar servicio',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showStorage(context),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Revisar almacenamiento de fotos'),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Card(child: EmptyState('No hay servicios.'))
          else
            for (final item in items) ...[
              _ServiceCard(
                service: item,
                onEdit: () => _showServiceForm(context, service: item),
                onToggle: () => _toggle(item),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _toggle(JsonMap item) async {
    try {
      await widget.controller.action(
        'toggleService',
        payload: {'id': item['id']},
        message: 'Cambiando disponibilidad…',
      );
      if (mounted) showMessage(context, 'Disponibilidad actualizada.');
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _showServiceForm(BuildContext context, {JsonMap? service}) =>
      showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          child: ServiceForm(controller: widget.controller, service: service),
        ),
      );

  Future<void> _showStorage(BuildContext context) async {
    try {
      final data = await widget.controller.action(
        'getPhotoStorage',
        message: 'Analizando fotos…',
        refreshAfter: false,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _PhotoStorageDialog(
          controller: widget.controller,
          initialData: data,
        ),
      );
    } catch (error) {
      if (context.mounted) showMessage(context, error.toString(), error: true);
    }
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onToggle,
  });

  final JsonMap service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = yesOf(service['available']);
    final image = textOf(service['image']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: image.isEmpty
                  ? Container(
                      width: 92,
                      height: 92,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined),
                    )
                  : Image.network(
                      image,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 92,
                        height: 92,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          textOf(service['name']),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      StatusPill(
                        active ? 'Activo' : 'Oculto',
                        color: active ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                  Text(textOf(service['category'])),
                  const SizedBox(height: 5),
                  Text(
                    '${money(service['price'])} · ${intOf(service['durationMinutes'], 60)} min',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (textOf(service['beforeImage']).isNotEmpty ||
                      textOf(service['afterImage']).isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Incluye antes/después'),
                    ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: onToggle,
                        icon: Icon(
                          active ? Icons.visibility_off : Icons.visibility,
                        ),
                        label: Text(active ? 'Ocultar' : 'Activar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceForm extends StatefulWidget {
  const ServiceForm({super.key, required this.controller, this.service});

  final AdminController controller;
  final JsonMap? service;

  @override
  State<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  String _available = 'Yes';

  bool get _editing => widget.service != null;
  TextEditingController field(String name, [Object? initial]) => _fields
      .putIfAbsent(name, () => TextEditingController(text: textOf(initial)));

  @override
  void initState() {
    super.initState();
    final item = widget.service ?? <String, dynamic>{};
    _available = textOf(item['available'], 'Yes');
    for (final entry in {
      'id': item['id'],
      'category': item['category'],
      'name': item['name'],
      'nameFr': item['nameFr'],
      'description': item['description'],
      'descriptionFr': item['descriptionFr'],
      'price': item['price'] ?? 0,
      'duration': item['durationMinutes'] ?? 60,
      'order': item['order'] == 9999 ? '' : item['order'],
      'image': item['image'],
      'beforeImage': item['beforeImage'],
      'afterImage': item['afterImage'],
      'notes': item['notes'],
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

  Future<XFile?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return ImagePicker().pickImage(source: source, imageQuality: 95);
  }

  Future<void> _upload(String target, String contextName) async {
    final file = await _pickImage();
    if (file == null) return;
    try {
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1600,
        minHeight: 1200,
        quality: 84,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) throw Exception('No se pudo preparar la imagen.');
      final result = await widget.controller.uploadImage(
        compressed,
        fileName: 'einnyad-${DateTime.now().millisecondsSinceEpoch}.jpg',
        context: contextName,
      );
      field(target).text = textOf(result['url']);
      if (mounted) {
        setState(() {});
        showMessage(
          context,
          'Imagen subida. Guarda el servicio para aplicarla.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final service = <String, dynamic>{
      if (_editing) 'rowNumber': widget.service!['rowNumber'],
      'id': field('id').text,
      'category': field('category').text,
      'name': field('name').text,
      'nameFr': field('nameFr').text,
      'description': field('description').text,
      'descriptionFr': field('descriptionFr').text,
      'price': field('price').text,
      'durationMinutes': field('duration').text,
      'order': field('order').text,
      'image': field('image').text,
      'beforeImage': field('beforeImage').text,
      'afterImage': field('afterImage').text,
      'available': _available,
      'taxable': 'No',
      'notes': field('notes').text,
    };
    try {
      await widget.controller.action(
        'saveService',
        payload: {'service': service},
        message: 'Guardando servicio…',
      );
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Servicio guardado.');
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
      title: Text(_editing ? 'Editar servicio' : 'Nuevo servicio'),
      actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextFormField(
            controller: field('category'),
            decoration: const InputDecoration(labelText: 'Categoría *'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('name'),
            decoration: const InputDecoration(labelText: 'Nombre en español *'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('nameFr'),
            decoration: const InputDecoration(labelText: 'Nombre en francés'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('description'),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción en español',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field('descriptionFr'),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción en francés',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                _numberField('price', 'Precio', prefix: '\$ '),
                _numberField('duration', 'Minutos'),
                _numberField('order', 'Orden'),
              ];
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    for (final item in fields) ...[
                      item,
                      if (item != fields.last) const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (final item in fields) ...[
                    Expanded(child: item),
                    if (item != fields.last) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _available,
            decoration: const InputDecoration(labelText: 'Disponibilidad'),
            items: const [
              DropdownMenuItem(value: 'Yes', child: Text('Activo')),
              DropdownMenuItem(value: 'No', child: Text('Oculto')),
            ],
            onChanged: (value) => _available = value ?? _available,
          ),
          const SizedBox(height: 22),
          const SectionHeading(
            'Fotos',
            subtitle: 'Se comprimen antes de subir para ahorrar espacio.',
          ),
          const SizedBox(height: 12),
          _PhotoField(
            label: 'Foto principal',
            controller: field('image'),
            onUpload: () => _upload('image', 'service-main'),
          ),
          const SizedBox(height: 14),
          _PhotoField(
            label: 'Foto antes',
            controller: field('beforeImage'),
            onUpload: () => _upload('beforeImage', 'service-before'),
          ),
          const SizedBox(height: 14),
          _PhotoField(
            label: 'Foto después',
            controller: field('afterImage'),
            onUpload: () => _upload('afterImage', 'service-after'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: field('notes'),
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notas internas'),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar servicio'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Requerido' : null;

  Widget _numberField(String key, String label, {String? prefix}) =>
      TextFormField(
        controller: field(key),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: prefix),
      );
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.controller,
    required this.onUpload,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.text.trim().isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            controller.text,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 90,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      if (controller.text.trim().isNotEmpty) const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: '$label (URL)'),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload),
              label: Text('Subir $label'),
            ),
          ),
          if (controller.text.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Quitar foto',
              onPressed: () => controller.clear(),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
    ],
  );
}

class _PhotoStorageDialog extends StatefulWidget {
  const _PhotoStorageDialog({
    required this.controller,
    required this.initialData,
  });
  final AdminController controller;
  final JsonMap initialData;

  @override
  State<_PhotoStorageDialog> createState() => _PhotoStorageDialogState();
}

class _PhotoStorageDialogState extends State<_PhotoStorageDialog> {
  late JsonMap data = widget.initialData;

  Future<void> _clean() async {
    final count = intOf(data['unusedCount']);
    if (count == 0) return;
    final ok = await confirmAction(
      context,
      title: 'Borrar fotos sin usar',
      message:
          'Se moverán a la papelera de Drive $count foto(s) que ningún servicio utiliza.',
      confirmLabel: 'Borrar fotos',
      dangerous: true,
    );
    if (!ok) return;
    try {
      final result = await widget.controller.action(
        'deleteUnusedPhotos',
        message: 'Borrando fotos sin usar…',
        refreshAfter: false,
      );
      if (mounted) {
        setState(() => data = mapOf(result['storage']));
        showMessage(context, 'Fotos sin usar enviadas a la papelera.');
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = mapsOf(data['photos']);
    return AlertDialog(
      title: const Text('Almacenamiento de fotos'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: ${textOf(data['totalLabel'], '0 B')} · Sin usar: ${textOf(data['unusedLabel'], '0 B')} (${intOf(data['unusedCount'])})',
            ),
            const SizedBox(height: 12),
            Flexible(
              child: photos.isEmpty
                  ? const EmptyState('No hay fotos registradas.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              textOf(photo['url']),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 52,
                                height: 52,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          title: Text(textOf(photo['fileName'], 'Foto')),
                          subtitle: Text(
                            '${textOf(photo['sizeLabel'])} · ${textOf(photo['source'])}',
                          ),
                          trailing: StatusPill(
                            photo['used'] == true ? 'En uso' : 'Sin usar',
                            color: photo['used'] == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: intOf(data['unusedCount']) > 0 ? _clean : null,
          icon: const Icon(Icons.cleaning_services),
          label: const Text('Limpiar sin usar'),
        ),
      ],
    );
  }
}
