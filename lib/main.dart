import 'dart:io';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/first_time_mobile_screen.dart';
import 'services/notification_service.dart';

// Override to bypass SSL certificate validation issues
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Set the global HttpOverrides to ignore SSL errors
  HttpOverrides.global = MyHttpOverrides();

  // Run the app immediately so the UI renders without blocking
  runApp(const GMCareApp());

  // Initialize notifications asynchronously in background
  NotificationService().init().catchError((e) {
    debugPrint('NotificationService init error: $e');
  });
}

class GMCareApp extends StatelessWidget {
  const GMCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GM Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const FirstTimeMobileScreen(),
    );
  }
}
