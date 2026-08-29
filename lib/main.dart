import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(notificationCallbackDispatcher);
  runApp(const EinnyadAdminApp());
}
