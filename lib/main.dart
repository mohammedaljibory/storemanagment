import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/services/firebase_seeder.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/task_provider.dart';
import 'core/providers/attendance_provider.dart';
import 'core/providers/store_provider.dart';
import 'core/providers/shift_provider.dart';
import 'core/providers/employee_provider.dart';
import 'core/providers/request_provider.dart';
import 'core/routes/app_routes.dart';
import 'features/splash/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/offline_sync_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize local notifications
  await NotificationService.init();

  // Request notification permissions
  await NotificationService.requestPermissions();

  // Initialize FCM for push notifications
  await FCMService.init();

  // Initialize offline sync manager
  await OfflineSyncManager.initialize();

  // await FirebaseSeeder.seedAll();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  /// Setup connectivity listener to sync offline data
  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      // Handle both single result (old API) and list (new API)
      final isConnected = result is List
          ? !result.contains(ConnectivityResult.none)
          : result != ConnectivityResult.none;

      if (isConnected) {
        // Connection restored - sync all offline data
        OfflineSyncManager.syncAllPendingData();
        // Also sync attendance-specific offline data
        final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
        attendanceProvider.syncOfflineData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(widget.prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'إدارة المتجر',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}
