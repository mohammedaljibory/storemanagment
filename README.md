# Store Management App - تطبيق إدارة المتجر

A Flutter mobile application for store management with gaming-inspired UI design, featuring task management and location-based attendance tracking.

## Features - المميزات

### For Employees (للموظفين):
- ✅ Location-based check-in/check-out (تسجيل الحضور والانصراف بناءً على الموقع)
- 📋 View and manage assigned tasks (عرض وإدارة المهام المخصصة)
- 📸 Complete tasks with photo confirmation (إكمال المهام مع تأكيد بالصورة)
- 📊 Track working hours (تتبع ساعات العمل)
- 🌓 Dark/Light mode support (دعم الوضع الليلي/النهاري)

### For Admins (للمدراء):
- 👥 Employee management (إدارة الموظفين)
- 📝 Create and assign tasks (إنشاء وتخصيص المهام)
- 📈 View employee attendance reports (عرض تقارير حضور الموظفين)
- 📊 Dashboard with statistics (لوحة تحكم مع الإحصائيات)

## UI Design - تصميم الواجهة

The app features a gaming-inspired UI with:
- 🎮 Glass morphism effects (تأثيرات زجاجية)
- ✨ Smooth animations (حركات سلسة)
- 🎨 Gradient colors (ألوان متدرجة)
- 🌙 Dark and light themes (سمات داكنة وفاتحة)

## Demo Credentials - بيانات الدخول التجريبية

### Admin Account:
- Email: `admin@store.com`
- Password: `admin123`

### Employee Account:
- Email: `employee@store.com`
- Password: `emp123`

## Project Structure - هيكل المشروع

```
lib/
├── core/                      # Core functionality
│   ├── models/               # Data models
│   ├── providers/            # State management
│   ├── routes/              # Navigation
│   ├── theme/              # App themes
│   └── widgets/            # Reusable widgets
│
├── features/                  # Feature modules
│   ├── admin/              # Admin features
│   ├── attendance/         # Attendance tracking
│   ├── auth/              # Authentication
│   ├── home/              # Home screen
│   ├── profile/           # User profile
│   ├── splash/            # Splash screen
│   └── tasks/             # Task management
│
└── main.dart                 # App entry point
```

## Getting Started - البدء

### Prerequisites - المتطلبات الأساسية:
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code
- Android/iOS device or emulator

### Installation - التثبيت:

1. Clone the repository:
```bash
git clone https://github.com/yourusername/store_management_app.git
cd store_management_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Configuration - الإعدادات

### Location Settings - إعدادات الموقع:

The store location is configured in `lib/core/providers/attendance_provider.dart`:

```dart
static const double storeLatitude = 31.9946;  // Najaf coordinates
static const double storeLongitude = 44.3148;
static const double allowedRadius = 100; // meters
```

Update these values to match your store location.

### Firebase Integration - دمج Firebase:

To connect with Firebase:

1. Create a Firebase project
2. Add your app to Firebase
3. Download and add configuration files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
4. Update Firebase initialization in `main.dart`

## Permissions - الأذونات

The app requires the following permissions:

### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for attendance tracking</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location access for attendance tracking</string>
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos for task completion</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images</string>
```

## Building for Production - البناء للإنتاج

### Android:
```bash
flutter build apk --release
# OR for app bundle:
flutter build appbundle --release
```

### iOS:
```bash
flutter build ios --release
```

## Future Enhancements - التحسينات المستقبلية

- [ ] Push notifications for new tasks
- [ ] Offline mode with data sync
- [ ] Multi-language support (English/Arabic)
- [ ] Advanced analytics and reports
- [ ] Voice notes for task updates
- [ ] Biometric authentication
- [ ] Real-time chat between admin and employees
- [ ] Export reports to PDF/Excel

## Dependencies - المكتبات المستخدمة

Key packages used in this project:
- `provider` - State management
- `geolocator` - Location services
- `image_picker` - Camera/gallery access
- `glassmorphism` - Glass effect UI
- `flutter_animate` - Animations
- `fl_chart` - Charts and graphs
- `firebase_*` - Firebase integration

## License - الرخصة

This project is licensed under the MIT License.

## Support - الدعم

For support, email: support@storeapp.com

---

Made with ❤️ using Flutter
