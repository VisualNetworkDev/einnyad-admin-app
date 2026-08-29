import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'admin_api.dart';
import 'session_store.dart';
import 'update_service.dart';
import 'value_helpers.dart';

const notificationWorkerId =
    'com.visualnetworkdev.einnyad_admin_mobile.notification_check';

@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await NotificationService.runBackgroundCheck();
    return true;
  });
}

class NotificationService {
  NotificationService({
    SessionStore? store,
    FlutterLocalNotificationsPlugin? notifications,
  }) : _store = store ?? SessionStore(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _reservationChannelId = 'einnyad_new_reservations';
  static const _updateChannelId = 'einnyad_app_updates';
  static const _reservationNotificationId = 41001;
  static const _updateNotificationId = 41002;

  final SessionStore _store;
  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  bool _checking = false;

  Future<void> activate({required List<JsonMap> currentAppointments}) async {
    await _initialize(requestPermission: true);
    await seedAppointmentsIfNeeded(currentAppointments);
    await Workmanager().registerPeriodicTask(
      notificationWorkerId,
      notificationWorkerId,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    await checkNow();
  }

  Future<void> seedAppointmentsIfNeeded(List<JsonMap> appointments) async {
    final seen = await _store.readSeenAppointmentIds();
    if (seen != null) return;
    await _store.saveSeenAppointmentIds(appointmentIds(appointments));
  }

  Future<void> rememberVisibleAppointments(List<JsonMap> appointments) async {
    final seen = await _store.readSeenAppointmentIds() ?? <String>{};
    await _store.saveSeenAppointmentIds({
      ...seen,
      ...appointmentIds(appointments),
    });
  }

  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;
    try {
      await _initialize();
      await _checkReservations();
      await _checkForUpdate();
    } finally {
      _checking = false;
    }
  }

  Future<void> _initialize({bool requestPermission = false}) async {
    if (!_initialized) {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_einnyad'),
        ),
      );
      _initialized = true;
    }
    if (requestPermission) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _checkReservations() async {
    final session = await _store.read();
    if (session == null) return;
    final api = AdminApi()..sessionToken = session.token;
    try {
      final data = await api.call('getAdminData');
      final appointments = mapsOf(data['appointments']);
      final seen = await _store.readSeenAppointmentIds();
      final unseen = unseenAppointments(appointments, seen);
      final updatedSeen = {...?seen, ...appointmentIds(appointments)};
      await _store.saveSeenAppointmentIds(updatedSeen);
      if (seen == null || unseen.isEmpty) return;
      await _showReservationNotification(unseen);
    } catch (_) {
      // A temporary API or session error is retried on the next scheduled run.
    } finally {
      api.close();
    }
  }

  Future<void> _checkForUpdate() async {
    final updates = UpdateService(_store);
    try {
      final update = await updates.check();
      if (update == null) return;
      final updateKey = '${update.version}+${update.buildNumber}';
      if (await _store.readLastNotifiedUpdate() == updateKey) return;
      await _store.saveLastNotifiedUpdate(updateKey);
      await _notifications.show(
        id: _updateNotificationId,
        title: 'Actualización disponible',
        body:
            'EinnyadNails Admin ${update.version} ya está lista para instalar.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _updateChannelId,
            'Actualizaciones de la app',
            channelDescription: 'Avisa cuando hay una versión nueva de la app.',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_einnyad',
          ),
        ),
        payload: 'settings',
      );
    } catch (_) {
      // The manifest will be checked again on the next scheduled run.
    } finally {
      updates.close();
    }
  }

  Future<void> _showReservationNotification(List<JsonMap> unseen) async {
    final first = unseen.first;
    final single = unseen.length == 1;
    final customer = textOf(first['customerName'], 'Nueva clienta');
    final date = textOf(first['preferredDate']);
    final time = normalizeTime12(textOf(first['preferredTime']));
    final detail = [
      customer,
      if (date.isNotEmpty) date,
      if (time.isNotEmpty) time,
    ].join(' · ');
    await _notifications.show(
      id: _reservationNotificationId,
      title: single
          ? 'Nueva reservación'
          : '${unseen.length} reservaciones nuevas',
      body: single ? detail : 'Abre la app para revisar las citas nuevas.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _reservationChannelId,
          'Reservaciones nuevas',
          channelDescription: 'Avisa cuando entra una reservación nueva.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_stat_einnyad',
          enableVibration: true,
          playSound: true,
        ),
      ),
      payload: 'appointments',
    );
  }

  static Future<void> runBackgroundCheck() async {
    final service = NotificationService();
    await service.checkNow();
  }
}

Set<String> appointmentIds(Iterable<JsonMap> appointments) => appointments
    .map((item) => textOf(item['appointmentId']).trim())
    .where((id) => id.isNotEmpty)
    .toSet();

List<JsonMap> unseenAppointments(
  Iterable<JsonMap> appointments,
  Set<String>? seen,
) {
  if (seen == null) return const [];
  return appointments.where((item) {
    final id = textOf(item['appointmentId']).trim();
    return id.isNotEmpty && !seen.contains(id);
  }).toList();
}
