import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS initialization
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    _initialized = true;
  }

  Future<bool> _isPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_push') ?? false;
  }

  Future<bool> _isAppointmentNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_appointment') ?? true; // default true
  }

  /// Show an immediate local notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await _isPushNotificationsEnabled()) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'gm_care_general',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Schedule appointment reminders (15 mins before)
  Future<void> scheduleAppointmentReminders({
    required int appointmentId,
    required String doctorName,
    required DateTime appointmentTime,
  }) async {
    if (!await _isPushNotificationsEnabled()) return;
    if (!await _isAppointmentNotificationsEnabled()) return;

    final now = DateTime.now();

    // 15 Minutes before
    final fifteenMinsBefore = appointmentTime.subtract(const Duration(minutes: 15));
    if (fifteenMinsBefore.isAfter(now)) {
      await _scheduleNotification(
        id: appointmentId * 10 + 1, // Unique ID
        title: 'Upcoming Appointment',
        body: 'Your appointment with $doctorName is in exactly 15 minutes!',
        scheduledDate: fifteenMinsBefore,
      );
    }
  }

  /// Show a Billing Alert notification
  Future<void> showBillingAlert({
    required String title,
    required String body,
  }) async {
    if (!await _isPushNotificationsEnabled()) return;
    
    final prefs = await SharedPreferences.getInstance();
    final billingEnabled = prefs.getBool('notifications_billing') ?? false;
    if (!billingEnabled) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'gm_care_billing',
      'Billing Alerts',
      channelDescription: 'Notifications for new bills and payment updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'gm_care_appointments',
      'Appointment Reminders',
      channelDescription: 'Scheduled reminders for upcoming appointments',
      importance: Importance.max,
      priority: Priority.high,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel all scheduled notifications for a specific appointment
  Future<void> cancelAppointmentReminders(int appointmentId) async {
    await flutterLocalNotificationsPlugin.cancel(id: appointmentId * 10 + 1);
    await flutterLocalNotificationsPlugin.cancel(id: appointmentId * 10 + 2);
  }
}
