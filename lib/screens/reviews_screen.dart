import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/value_helpers.dart';
import '../widgets/common.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.controller});

  final AdminController controller;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  String _filter = '';

  Future<void> _setStatus(JsonMap review, String status) async {
    try {
      await widget.controller.action(
        'updateReviewStatus',
        payload: {'rowNumber': review['rowNumber'], 'status': status},
        message: 'Actualizando reseña…',
      );
      if (mounted) showMessage(context, 'Reseña actualizada.');
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.controller.reviews.where((item) {
      return _filter.isEmpty || textOf(item['status']) == _filter;
    }).toList();
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SectionHeading(
            'Reseñas de clientas',
            subtitle: 'Aprueba, deja pendiente u oculta cada comentario.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'Filtrar por estado'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Todas')),
              DropdownMenuItem(value: 'Pending', child: Text('Pendientes')),
              DropdownMenuItem(value: 'Approved', child: Text('Aprobadas')),
              DropdownMenuItem(value: 'Hidden', child: Text('Ocultas')),
            ],
            onChanged: (value) => setState(() => _filter = value ?? ''),
          ),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            const Card(child: EmptyState('No hay reseñas en este estado.'))
          else
            for (final review in reviews) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              textOf(review['name'], 'Anónima'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          StatusPill(
                            switch (textOf(review['status'])) {
                              'Approved' => 'Aprobada',
                              'Hidden' => 'Oculta',
                              _ => 'Pendiente',
                            },
                            color: switch (textOf(review['status'])) {
                              'Approved' => Colors.green,
                              'Hidden' => Colors.grey,
                              _ => Colors.orange,
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < 5; i++)
                            Icon(
                              i < intOf(review['rating'], 5)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber.shade700,
                              size: 21,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(textOf(review['text'])),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _setStatus(review, 'Approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('Aprobar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _setStatus(review, 'Pending'),
                            icon: const Icon(Icons.schedule),
                            label: const Text('Pendiente'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _setStatus(review, 'Hidden'),
                            icon: const Icon(Icons.visibility_off),
                            label: const Text('Ocultar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
