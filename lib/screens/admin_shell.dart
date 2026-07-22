import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import 'appointments_screen.dart';
import 'dashboard_screen.dart';
import 'qr_screen.dart';
import 'reviews_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';

enum AdminSection {
  dashboard('Resumen', Icons.dashboard_outlined),
  appointments('Citas', Icons.calendar_month_outlined),
  qr('Escáner QR', Icons.qr_code_scanner),
  services('Servicios y fotos', Icons.design_services_outlined),
  reviews('Reseñas', Icons.reviews_outlined),
  settings('Ajustes', Icons.settings_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.controller});

  final AdminController controller;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminSection _section = AdminSection.dashboard;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _body() => switch (_section) {
    AdminSection.dashboard => DashboardScreen(
      controller: widget.controller,
      openAppointments: () =>
          setState(() => _section = AdminSection.appointments),
    ),
    AdminSection.appointments => AppointmentsScreen(
      controller: widget.controller,
    ),
    AdminSection.qr => QrScreen(controller: widget.controller),
    AdminSection.services => ServicesScreen(controller: widget.controller),
    AdminSection.reviews => ReviewsScreen(controller: widget.controller),
    AdminSection.settings => SettingsScreen(controller: widget.controller),
  };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              leading: wide
                  ? null
                  : IconButton(
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
              automaticallyImplyLeading: false,
              title: Text(
                _section.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              actions: [
                IconButton(
                  tooltip: 'Actualizar datos',
                  onPressed: widget.controller.busy
                      ? null
                      : () async {
                          try {
                            await widget.controller.refresh();
                            if (context.mounted) {
                              showMessage(context, 'Datos actualizados.');
                            }
                          } catch (error) {
                            if (context.mounted) {
                              showMessage(
                                context,
                                error.toString(),
                                error: true,
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            drawer: wide
                ? null
                : Drawer(child: _drawerContents(closeOnSelect: true)),
            body: wide
                ? Row(
                    children: [
                      SizedBox(
                        width: 286,
                        child: _drawerContents(closeOnSelect: false),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _animatedBody()),
                    ],
                  )
                : _animatedBody(),
          ),
          if (widget.controller.busy)
            BusyOverlay(
              message: widget.controller.busyMessage,
              progress: widget.controller.updateProgress > 0
                  ? widget.controller.updateProgress
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _animatedBody() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    child: KeyedSubtree(key: ValueKey(_section), child: _body()),
  );

  Widget _drawerContents({required bool closeOnSelect}) => SafeArea(
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Row(
              children: [
                const AppLogo(),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EinnyadNails',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.controller.session?.name ?? 'Administración',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final item in AdminSection.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: item == _section,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(item.icon),
                      title: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () {
                        setState(() => _section = item);
                        if (closeOnSelect) Navigator.pop(context);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.controller.logout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
