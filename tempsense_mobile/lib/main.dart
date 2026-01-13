import 'package:flutter/material.dart';
import 'package:tempsense_mobile/app.dart';
import 'package:tempsense_mobile/core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  NotificationService().initialize();
  await NotificationService().requestPermissions();

  runApp(const App());
}