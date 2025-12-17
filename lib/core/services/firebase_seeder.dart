import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Data Seeder
/// Run this ONCE to create all test data
/// 
/// Usage:
/// ```dart
/// // In any screen or button:
/// await FirebaseSeeder.seedAll();
/// ```
class FirebaseSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Seed all data
  static Future<void> seedAll() async {
    print('🚀 Starting Firebase seeder...');
    
    try {
      // 1. Create users (admin + employees)
      await _seedUsers();
      
      // 2. Create stores
      await _seedStores();
      
      // 3. Create shifts
      await _seedShifts();
      
      // 4. Create tasks
      await _seedTasks();
      
      // 5. Create attendance records
      await _seedAttendance();
      
      print('✅ All data seeded successfully!');
    } catch (e) {
      print('❌ Error seeding data: $e');
    }
  }

  /// Clear all data (use carefully!)
  static Future<void> clearAll() async {
    print('🗑️ Clearing all data...');
    
    final collections = ['users', 'stores', 'shifts', 'tasks', 'attendance'];
    
    for (final collection in collections) {
      final snapshot = await _firestore.collection(collection).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('  Cleared: $collection');
    }
    
    print('✅ All data cleared!');
  }

  // ============================================================
  // USERS
  // ============================================================
  static Future<void> _seedUsers() async {
    print('👤 Seeding users...');

    final users = [
      // Admin
      {
        'id': 'admin1',
        'name': 'أحمد المدير',
        'email': 'admin@store.com',
        'phone': '07701234567',
        'role': 'admin',
        'storeId': null,
        'storeName': null,
        'shiftId': null,
        'shiftName': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      // Employees
      {
        'id': 'emp1',
        'name': 'محمد الموظف',
        'email': 'employee@store.com',
        'phone': '07709876543',
        'role': 'employee',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift1',
        'shiftName': 'الشفت الصباحي',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      {
        'id': 'emp2',
        'name': 'علي الكاظمي',
        'email': 'ali@store.com',
        'phone': '07705551234',
        'role': 'employee',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift2',
        'shiftName': 'الشفت المسائي',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      {
        'id': 'emp3',
        'name': 'حسين العامري',
        'email': 'hussein@store.com',
        'phone': '07708889999',
        'role': 'employee',
        'storeId': 'store2',
        'storeName': 'فرع الكوفة',
        'shiftId': 'shift3',
        'shiftName': 'الشفت الصباحي',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
    ];

    for (final user in users) {
      await _firestore.collection('users').doc(user['id'] as String).set(user);
    }

    // Create auth accounts
    await _createAuthAccount('admin@store.com', 'admin123');
    await _createAuthAccount('employee@store.com', 'emp123');
    await _createAuthAccount('ali@store.com', 'emp123');
    await _createAuthAccount('hussein@store.com', 'emp123');

    print('  ✓ Created ${users.length} users');
  }

  static Future<void> _createAuthAccount(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Sign out after creating
      await _auth.signOut();
    } catch (e) {
      // User might already exist
      print('  Note: $email might already exist');
    }
  }

  // ============================================================
  // STORES
  // ============================================================
  static Future<void> _seedStores() async {
    print('🏪 Seeding stores...');

    final stores = [
      {
        'id': 'store1',
        'name': 'فرع النجف الرئيسي',
        'address': 'شارع الصدر، النجف الأشرف',
        'adminId': 'admin1',
        'phone': '07801234567',
        'latitude': 31.9957, // Najaf coordinates
        'longitude': 44.3148,
        'allowedRadius': 100.0, // 100 meters
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      {
        'id': 'store2',
        'name': 'فرع الكوفة',
        'address': 'شارع الإمام علي، الكوفة',
        'adminId': 'admin1',
        'phone': '07801234568',
        'latitude': 32.0303, // Kufa coordinates
        'longitude': 44.4031,
        'allowedRadius': 150.0,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      {
        'id': 'store3',
        'name': 'فرع كربلاء',
        'address': 'قرب الحرم الحسيني، كربلاء',
        'adminId': 'admin1',
        'phone': '07801234569',
        'latitude': 32.6160, // Karbala coordinates
        'longitude': 44.0323,
        'allowedRadius': 120.0,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
    ];

    for (final store in stores) {
      await _firestore.collection('stores').doc(store['id'] as String).set(store);
    }

    print('  ✓ Created ${stores.length} stores');
  }

  // ============================================================
  // SHIFTS
  // ============================================================
  static Future<void> _seedShifts() async {
    print('⏰ Seeding shifts...');

    final shifts = [
      // Store 1 shifts
      {
        'id': 'shift1',
        'storeId': 'store1',
        'name': 'الشفت الصباحي',
        'startTime': '08:00',
        'endTime': '14:00',
        'workDays': [0, 1, 2, 3, 4, 5], // Sunday to Friday
        'lateToleranceMinutes': 15,
        'maxLateMinutes': 60,
        'checkInWindowMinutes': 30,
        'checkOutWindowMinutes': 15,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      {
        'id': 'shift2',
        'storeId': 'store1',
        'name': 'الشفت المسائي',
        'startTime': '14:00',
        'endTime': '22:00',
        'workDays': [0, 1, 2, 3, 4, 5],
        'lateToleranceMinutes': 15,
        'maxLateMinutes': 45,
        'checkInWindowMinutes': 30,
        'checkOutWindowMinutes': 15,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      // Store 2 shifts
      {
        'id': 'shift3',
        'storeId': 'store2',
        'name': 'الشفت الصباحي',
        'startTime': '09:00',
        'endTime': '17:00',
        'workDays': [0, 1, 2, 3, 4], // Sunday to Thursday
        'lateToleranceMinutes': 10,
        'maxLateMinutes': 30,
        'checkInWindowMinutes': 20,
        'checkOutWindowMinutes': 10,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      // Store 3 shifts
      {
        'id': 'shift4',
        'storeId': 'store3',
        'name': 'الشفت الكامل',
        'startTime': '10:00',
        'endTime': '20:00',
        'workDays': [0, 1, 2, 3, 4, 5, 6], // All week
        'lateToleranceMinutes': 20,
        'maxLateMinutes': 60,
        'checkInWindowMinutes': 30,
        'checkOutWindowMinutes': 20,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
    ];

    for (final shift in shifts) {
      await _firestore.collection('shifts').doc(shift['id'] as String).set(shift);
    }

    print('  ✓ Created ${shifts.length} shifts');
  }

  // ============================================================
  // TASKS
  // ============================================================
  static Future<void> _seedTasks() async {
    print('📋 Seeding tasks...');

    final now = DateTime.now();

    final tasks = [
      // Tasks for emp1
      {
        'id': 'task1',
        'title': 'ترتيب الرفوف',
        'description': 'ترتيب جميع المنتجات على الرفوف حسب الفئات',
        'storeId': 'store1',
        'assignedTo': 'emp1',
        'assignedToName': 'محمد الموظف',
        'assignedBy': 'admin1',
        'assignedByName': 'أحمد المدير',
        'status': 'pending',
        'priority': 'high',
        'maxDurationMinutes': 120,
        'deadline': Timestamp.fromDate(now.add(const Duration(hours: 4))),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'completionImage': null,
        'completionNote': null,
        'failureReason': null,
      },
      {
        'id': 'task2',
        'title': 'جرد المخزون',
        'description': 'جرد كامل لمخزون قسم المواد الغذائية',
        'storeId': 'store1',
        'assignedTo': 'emp1',
        'assignedToName': 'محمد الموظف',
        'assignedBy': 'admin1',
        'assignedByName': 'أحمد المدير',
        'status': 'inProgress',
        'priority': 'urgent',
        'maxDurationMinutes': 180,
        'deadline': Timestamp.fromDate(now.add(const Duration(hours: 2))),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'completionImage': null,
        'completionNote': null,
        'failureReason': null,
      },
      {
        'id': 'task3',
        'title': 'تنظيف الواجهة',
        'description': 'تنظيف واجهات العرض الزجاجية',
        'storeId': 'store1',
        'assignedTo': 'emp1',
        'assignedToName': 'محمد الموظف',
        'assignedBy': 'admin1',
        'assignedByName': 'أحمد المدير',
        'status': 'completed',
        'priority': 'medium',
        'maxDurationMinutes': 60,
        'deadline': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 5))),
        'completedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'completionImage': 'https://example.com/image1.jpg',
        'completionNote': 'تم التنظيف بالكامل',
        'failureReason': null,
      },
      // Tasks for emp2
      {
        'id': 'task4',
        'title': 'استلام الشحنة',
        'description': 'استلام شحنة البضائع الجديدة وفحصها',
        'storeId': 'store1',
        'assignedTo': 'emp2',
        'assignedToName': 'علي الكاظمي',
        'assignedBy': 'admin1',
        'assignedByName': 'أحمد المدير',
        'status': 'pending',
        'priority': 'high',
        'maxDurationMinutes': 90,
        'deadline': Timestamp.fromDate(now.add(const Duration(hours: 6))),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'completionImage': null,
        'completionNote': null,
        'failureReason': null,
      },
      // Tasks for emp3
      {
        'id': 'task5',
        'title': 'إعداد العروض',
        'description': 'تجهيز لافتات العروض الأسبوعية',
        'storeId': 'store2',
        'assignedTo': 'emp3',
        'assignedToName': 'حسين العامري',
        'assignedBy': 'admin1',
        'assignedByName': 'أحمد المدير',
        'status': 'pending',
        'priority': 'low',
        'maxDurationMinutes': 45,
        'deadline': Timestamp.fromDate(now.add(const Duration(days: 1))),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'completionImage': null,
        'completionNote': null,
        'failureReason': null,
      },
      // Failed task
      {
        'id': 'task6',
        'title': 'صيانة المكيف',
        'description': 'الاتصال بفني الصيانة لإصلاح المكيف',
        'storeId': 'store1',
        'assignedTo': 'emp1',
        'assignedToName': 'محمد الموظف',
        'assignedBy': 'admin1',
        'assignedByName': 'أحمد المدير',
        'status': 'failed',
        'priority': 'medium',
        'maxDurationMinutes': 30,
        'deadline': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
        'completedAt': null,
        'completionImage': null,
        'completionNote': null,
        'failureReason': 'لم يتوفر فني الصيانة',
      },
    ];

    for (final task in tasks) {
      await _firestore.collection('tasks').doc(task['id'] as String).set(task);
    }

    print('  ✓ Created ${tasks.length} tasks');
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================
  static Future<void> _seedAttendance() async {
    print('📊 Seeding attendance...');

    final now = DateTime.now();

    final attendance = [
      // Yesterday - on time
      {
        'id': 'att1',
        'userId': 'emp1',
        'userName': 'محمد الموظف',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift1',
        'shiftName': 'الشفت الصباحي',
        'expectedStartTime': '08:00',
        'expectedEndTime': '14:00',
        'checkIn': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 1, 7, 55)),
        'checkOut': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 1, 14, 5)),
        'checkInLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'checkOutLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'totalHours': 6.17,
        'isLate': false,
        'lateMinutes': 0,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
      },
      // 2 days ago - late
      {
        'id': 'att2',
        'userId': 'emp1',
        'userName': 'محمد الموظف',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift1',
        'shiftName': 'الشفت الصباحي',
        'expectedStartTime': '08:00',
        'expectedEndTime': '14:00',
        'checkIn': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 2, 8, 25)),
        'checkOut': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 2, 14, 0)),
        'checkInLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'checkOutLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'totalHours': 5.58,
        'isLate': true,
        'lateMinutes': 25,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
      },
      // 3 days ago - early leave
      {
        'id': 'att3',
        'userId': 'emp1',
        'userName': 'محمد الموظف',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift1',
        'shiftName': 'الشفت الصباحي',
        'expectedStartTime': '08:00',
        'expectedEndTime': '14:00',
        'checkIn': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 3, 8, 0)),
        'checkOut': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 3, 13, 30)),
        'checkInLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'checkOutLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'totalHours': 5.5,
        'isLate': false,
        'lateMinutes': 0,
        'isEarlyLeave': true,
        'earlyLeaveMinutes': 30,
      },
      // 4 days ago - late + early leave
      {
        'id': 'att4',
        'userId': 'emp1',
        'userName': 'محمد الموظف',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift1',
        'shiftName': 'الشفت الصباحي',
        'expectedStartTime': '08:00',
        'expectedEndTime': '14:00',
        'checkIn': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 4, 8, 45)),
        'checkOut': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 4, 13, 15)),
        'checkInLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'checkOutLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'totalHours': 4.5,
        'isLate': true,
        'lateMinutes': 45,
        'isEarlyLeave': true,
        'earlyLeaveMinutes': 45,
      },
      // 5 days ago - perfect
      {
        'id': 'att5',
        'userId': 'emp1',
        'userName': 'محمد الموظف',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift1',
        'shiftName': 'الشفت الصباحي',
        'expectedStartTime': '08:00',
        'expectedEndTime': '14:00',
        'checkIn': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 5, 7, 50)),
        'checkOut': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 5, 14, 10)),
        'checkInLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'checkOutLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'totalHours': 6.33,
        'isLate': false,
        'lateMinutes': 0,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
      },
      // emp2 attendance
      {
        'id': 'att6',
        'userId': 'emp2',
        'userName': 'علي الكاظمي',
        'storeId': 'store1',
        'storeName': 'فرع النجف الرئيسي',
        'shiftId': 'shift2',
        'shiftName': 'الشفت المسائي',
        'expectedStartTime': '14:00',
        'expectedEndTime': '22:00',
        'checkIn': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 1, 14, 0)),
        'checkOut': Timestamp.fromDate(DateTime(now.year, now.month, now.day - 1, 22, 0)),
        'checkInLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'checkOutLocation': {
          'latitude': 31.9957,
          'longitude': 44.3148,
          'address': 'فرع النجف الرئيسي',
        },
        'totalHours': 8.0,
        'isLate': false,
        'lateMinutes': 0,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
      },
    ];

    for (final att in attendance) {
      await _firestore.collection('attendance').doc(att['id'] as String).set(att);
    }

    print('  ✓ Created ${attendance.length} attendance records');
  }
}
