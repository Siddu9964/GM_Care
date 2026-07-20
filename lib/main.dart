import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart'; 
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const GMCareApp());
}

class GMCareApp extends StatelessWidget {
  const GMCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GM Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
