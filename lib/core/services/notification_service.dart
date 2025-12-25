import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Notification channels
  static const String _defaultChannelId = 'store_channel';
  static const String _alarmChannelId = 'alarm_channel';
  static const String _taskChannelId = 'task_channel';
  static const String _attendanceChannelId = 'attendance_channel';
  static const String _requestChannelId = 'request_channel';

  static Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    _initialized = true;
  }

  /// Create Android notification channels
  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Default channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _defaultChannelId,
          'Store Notifications',
          description: 'General store notifications',
          importance: Importance.high,
        ),
      );

      // Alarm channel (with alarm sound)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _alarmChannelId,
          'Alarm Notifications',
          description: 'Important alerts with alarm sound',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alarm_sound'),
          enableVibration: true,
          enableLights: true,
        ),
      );

      // Task channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _taskChannelId,
          'Task Notifications',
          description: 'Task related notifications',
          importance: Importance.high,
        ),
      );

      // Attendance channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _attendanceChannelId,
          'Attendance Notifications',
          description: 'Attendance and shift notifications',
          importance: Importance.max,
          playSound: true,
        ),
      );

      // Request channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _requestChannelId,
          'Request Notifications',
          description: 'Leave request notifications',
          importance: Importance.high,
        ),
      );

      // Location monitoring channel (low priority - ongoing status)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'location_monitoring',
          'Location Monitoring',
          description: 'Shows when location tracking is active',
          importance: Importance.low,
        ),
      );

      // Location alert channel (high priority - when employee leaves area)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'location_alert',
          'Location Alerts',
          description: 'Alerts when employee leaves work area',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - can navigate to specific screen
    print('Notification tapped: ${response.payload}');
  }

  // ============ BASIC NOTIFICATIONS ============

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
    String? channelId,
    String? channelName,
    Importance importance = Importance.high,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? _defaultChannelId,
      channelName ?? 'Store Notifications',
      importance: importance,
      priority: importance == Importance.max ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notifications.show(id, title, body, details, payload: payload);
  }

  // ============ ALARM NOTIFICATIONS (with sound) ============

  static Future<void> showAlarmNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'Alarm Notifications',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alarm_sound.aiff',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notifications.show(id, title, body, details, payload: payload);
  }

  // ============ SCHEDULED NOTIFICATIONS ============

  /// Schedule a notification at a specific time
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    bool useAlarmSound = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      useAlarmSound ? _alarmChannelId : _attendanceChannelId,
      useAlarmSound ? 'Alarm Notifications' : 'Attendance Notifications',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      sound: useAlarmSound 
          ? const RawResourceAndroidNotificationSound('alarm_sound')
          : null,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: useAlarmSound,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule sign-out reminder notification
  static Future<void> scheduleSignOutReminder({
    required DateTime shiftEndTime,
    int minutesBefore = 15,
    required String employeeName,
  }) async {
    final reminderTime = shiftEndTime.subtract(Duration(minutes: minutesBefore));
    
    // Don't schedule if reminder time is in the past
    if (reminderTime.isBefore(DateTime.now())) return;

    await scheduleNotification(
      id: 1001, // Fixed ID for sign-out reminder
      title: '⏰ تذكير بتسجيل الخروج',
      body: 'متبقي $minutesBefore دقيقة على نهاية الشفت\nلا تنسى تسجيل الخروج!',
      scheduledTime: reminderTime,
      useAlarmSound: true,
      payload: 'signout_reminder',
    );
  }

  /// Schedule multiple reminders (15 min, 5 min, at end time)
  static Future<void> scheduleSignOutReminders({
    required DateTime shiftEndTime,
    required String employeeName,
  }) async {
    // Cancel previous reminders
    await cancelSignOutReminders();

    final now = DateTime.now();

    // 15 minutes before
    final reminder15 = shiftEndTime.subtract(const Duration(minutes: 15));
    if (reminder15.isAfter(now)) {
      await scheduleNotification(
        id: 1001,
        title: '⏰ تذكير بتسجيل الخروج',
        body: 'متبقي 15 دقيقة على نهاية الشفت',
        scheduledTime: reminder15,
        useAlarmSound: false,
      );
    }

    // 5 minutes before
    final reminder5 = shiftEndTime.subtract(const Duration(minutes: 5));
    if (reminder5.isAfter(now)) {
      await scheduleNotification(
        id: 1002,
        title: '🔔 قارب الشفت على الانتهاء!',
        body: 'متبقي 5 دقائق فقط - جهز نفسك لتسجيل الخروج',
        scheduledTime: reminder5,
        useAlarmSound: true,
      );
    }

    // At end time
    if (shiftEndTime.isAfter(now)) {
      await scheduleNotification(
        id: 1003,
        title: '🚨 انتهى وقت الشفت!',
        body: 'يرجى تسجيل الخروج الآن',
        scheduledTime: shiftEndTime,
        useAlarmSound: true,
      );
    }
  }

  /// Cancel sign-out reminder notifications
  static Future<void> cancelSignOutReminders() async {
    await _notifications.cancel(1001);
    await _notifications.cancel(1002);
    await _notifications.cancel(1003);
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllScheduled() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  // ============ TASK NOTIFICATIONS ============

  /// Task assigned to employee
  static Future<void> notifyTaskAssigned(String taskTitle, String employeeName) async {
    await showNotification(
      title: '📋 مهمة جديدة',
      body: 'تم تعيين مهمة "$taskTitle" لـ $employeeName',
      id: DateTime.now().millisecond,
      payload: 'task_assigned',
    );
  }

  /// Task completed - notify admin
  static Future<void> notifyTaskCompleted(String taskTitle, String employeeName) async {
    await showNotification(
      title: '✅ مهمة مكتملة',
      body: '$employeeName أكمل مهمة "$taskTitle"',
      id: DateTime.now().millisecond,
      payload: 'task_completed',
    );
  }

  /// Task waiting approval - notify admin
  static Future<void> notifyTaskWaitingApproval(String taskTitle, String employeeName) async {
    await showNotification(
      title: '⏳ مهمة تنتظر الموافقة',
      body: '$employeeName أنجز مهمة "$taskTitle" وتنتظر موافقتك',
      id: DateTime.now().millisecond,
      payload: 'task_waiting_approval',
    );
  }

  /// Task approved - notify employee
  static Future<void> notifyTaskApproved(String taskTitle) async {
    await showNotification(
      title: '✅ تمت الموافقة على المهمة',
      body: 'تمت الموافقة على مهمة "$taskTitle"',
      id: DateTime.now().millisecond,
      payload: 'task_approved',
    );
  }

  /// Task rejected - notify employee
  static Future<void> notifyTaskRejected(String taskTitle, String reason) async {
    await showNotification(
      title: '❌ تم رفض المهمة',
      body: 'تم رفض مهمة "$taskTitle"\nالسبب: $reason',
      id: DateTime.now().millisecond,
      payload: 'task_rejected',
    );
  }

  // ============ ATTENDANCE NOTIFICATIONS ============

  /// Late attendance - notify admin
  static Future<void> notifyLateAttendance(String employeeName, int lateMinutes) async {
    await showNotification(
      title: '⚠️ تأخير في الحضور',
      body: '$employeeName متأخر $lateMinutes دقيقة',
      id: DateTime.now().millisecond,
      payload: 'late_attendance',
    );
  }

  /// Check-in success
  static Future<void> notifyCheckInSuccess(String shiftName, DateTime expectedEnd) async {
    final endFormatted = '${expectedEnd.hour.toString().padLeft(2, '0')}:${expectedEnd.minute.toString().padLeft(2, '0')}';
    await showNotification(
      title: '✅ تم تسجيل الحضور',
      body: 'شفت: $shiftName\nوقت الانتهاء المتوقع: $endFormatted',
      id: DateTime.now().millisecond,
      payload: 'checkin_success',
    );
  }

  /// Check-out success
  static Future<void> notifyCheckOutSuccess(double totalHours) async {
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();
    await showNotification(
      title: '✅ تم تسجيل الخروج',
      body: 'إجمالي ساعات العمل: $hours ساعة و $minutes دقيقة',
      id: DateTime.now().millisecond,
      payload: 'checkout_success',
    );
  }

  // ============ REQUEST NOTIFICATIONS ============

  /// New request - notify admin
  static Future<void> notifyNewRequest(String employeeName, String requestType) async {
    await showNotification(
      title: '📝 طلب جديد',
      body: '$employeeName قدم طلب $requestType',
      id: DateTime.now().millisecond,
      payload: 'new_request',
    );
  }

  /// Request approved - notify employee
  static Future<void> notifyRequestApproved(String requestType) async {
    await showNotification(
      title: '✅ تمت الموافقة على طلبك',
      body: 'تمت الموافقة على طلب $requestType',
      id: DateTime.now().millisecond,
      payload: 'request_approved',
    );
  }

  /// Request rejected - notify employee
  static Future<void> notifyRequestRejected(String requestType, String reason) async {
    await showNotification(
      title: '❌ تم رفض طلبك',
      body: 'تم رفض طلب $requestType\nالسبب: $reason',
      id: DateTime.now().millisecond,
      payload: 'request_rejected',
    );
  }

  // ============ UTILITY ============

  /// Get pending notification requests
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    
    return true; // Assume enabled for iOS
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }
    
    return false;
  }
}
