import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/value_helpers.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.openAppointments,
  });

  final AdminController controller;
  final VoidCallback openAppointments;

  @override
  Widget build(BuildContext context) {
    final dashboard = controller.dashboard;
    final appointments = controller.appointments;
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final week =
        appointments.where((item) {
          final date = DateTime.tryParse(textOf(item['preferredDate']));
          return date != null && !date.isBefore(start) && date.isBefore(end);
        }).toList()..sort((a, b) {
          final date = textOf(
            a['preferredDate'],
          ).compareTo(textOf(b['preferredDate']));
          return date != 0
              ? date
              : textOf(
                  a['preferredTime'],
                ).compareTo(textOf(b['preferredTime']));
        });
    final metrics = <_Metric>[
      _Metric('Activas', dashboard['activeCount'], Icons.event_available),
      _Metric('Hoy', dashboard['todayCount'], Icons.today),
      _Metric(
        'Completadas',
        dashboard['completedCount'],
        Icons.check_circle_outline,
      ),
      _Metric(
        'Canceladas',
        dashboard['cancelledCount'],
        Icons.event_busy_outlined,
      ),
      _Metric(
        'Ventas totales',
        money(dashboard['totalSold']),
        Icons.payments_outlined,
      ),
      _Metric(
        'Ventas del mes',
        money(dashboard['monthSold']),
        Icons.calendar_view_month,
      ),
      _Metric(
        'Por cobrar',
        money(dashboard['pendingMoney']),
        Icons.pending_actions,
      ),
      _Metric(
        'Ticket promedio',
        money(dashboard['averageTicket']),
        Icons.receipt_long,
      ),
    ];
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SectionHeading(
            'Estado del negocio',
            subtitle: 'Información sincronizada con el panel web.',
            action: FilledButton.icon(
              onPressed: openAppointments,
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: _MetricCard(metric: metric),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            'Agenda de esta semana',
            subtitle: 'De lunes a domingo.',
          ),
          const SizedBox(height: 12),
          Card(
            child: week.isEmpty
                ? const EmptyState(
                    'No hay citas esta semana.',
                    icon: Icons.event,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: week.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = week[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            textOf(item['preferredDate']).split('-').last,
                          ),
                        ),
                        title: Text(
                          textOf(item['customerName'], 'Sin nombre'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${textOf(item['preferredDate'])} · ${normalizeTime12(textOf(item['preferredTime']))}\n${mapsOf(item['items']).map((x) => textOf(x['nameEs'], textOf(x['name']))).where((x) => x.isNotEmpty).join(', ')}',
                        ),
                        isThreeLine: true,
                        trailing: StatusPill(statusEs(item['status'])),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          _Highlights(dashboard: dashboard),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object? value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(radius: 23, child: Icon(metric.icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value?.toString() ?? '0',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  metric.label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.dashboard});
  final JsonMap dashboard;

  @override
  Widget build(BuildContext context) {
    final next = mapOf(dashboard['nextAppointment']);
    final last = mapOf(dashboard['lastAppointment']);
    final top = mapsOf(dashboard['topServices']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _HighlightCard(
            title: 'Próxima cita',
            child: next.isEmpty
                ? const Text('No hay próxima cita.')
                : Text(
                    '${textOf(next['customerName'])}\n${textOf(next['preferredDate'])} · ${normalizeTime12(textOf(next['preferredTime']))}',
                  ),
          ),
          _HighlightCard(
            title: 'Última orden',
            child: last.isEmpty
                ? const Text('No hay órdenes.')
                : Text(
                    '${textOf(last['customerName'])}\n${money(last['totalUpdated'] ?? last['total'])}',
                  ),
          ),
          _HighlightCard(
            title: 'Servicios más pedidos',
            child: top.isEmpty
                ? const Text('Sin información todavía.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in top)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${textOf(item['name'])}: ${intOf(item['count'])}',
                          ),
                        ),
                    ],
                  ),
          ),
        ];
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 12)],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final card in cards) ...[
              Expanded(child: card),
              if (card != cards.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
