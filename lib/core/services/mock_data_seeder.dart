import '../models/user_model.dart';
import '../models/store_model.dart';
import '../models/shift_model.dart';
import '../models/task_model.dart';
import '../models/attendance_model.dart';

/// Local Mock Data Seeder
/// Use this for testing WITHOUT Firebase
class MockDataSeeder {
  
  // ============================================================
  // USERS
  // ============================================================
  static List<UserModel> getUsers() {
    return [
      UserModel(
        id: 'admin1',
        name: 'أحمد المدير',
        email: 'admin@store.com',
        phone: '07701234567',
        role: UserRole.admin,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
      UserModel(
        id: 'emp1',
        name: 'محمد الموظف',
        email: 'employee@store.com',
        phone: '07709876543',
        role: UserRole.employee,
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift1',
        shiftName: 'الشفت الصباحي',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        isActive: true,
      ),
      UserModel(
        id: 'emp2',
        name: 'علي الكاظمي',
        email: 'ali@store.com',
        phone: '07705551234',
        role: UserRole.employee,
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift2',
        shiftName: 'الشفت المسائي',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isActive: true,
      ),
      UserModel(
        id: 'emp3',
        name: 'حسين العامري',
        email: 'hussein@store.com',
        phone: '07708889999',
        role: UserRole.employee,
        storeId: 'store2',
        storeName: 'فرع الكوفة',
        shiftId: 'shift3',
        shiftName: 'الشفت الصباحي',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        isActive: true,
      ),
    ];
  }

  /// Get user by email and password (for mock login)
  static UserModel? login(String email, String password) {
    final credentials = {
      'admin@store.com': 'admin123',
      'employee@store.com': 'emp123',
      'ali@store.com': 'emp123',
      'hussein@store.com': 'emp123',
    };

    if (credentials[email] == password) {
      return getUsers().firstWhere(
        (u) => u.email == email,
        orElse: () => getUsers().first,
      );
    }
    return null;
  }

  // ============================================================
  // STORES
  // ============================================================
  static List<StoreModel> getStores() {
    return [
      StoreModel(
        id: 'store1',
        name: 'فرع النجف الرئيسي',
        address: 'شارع الصدر، النجف الأشرف',
        adminId: 'admin1',
        phone: '07801234567',
        latitude: 31.9957,
        longitude: 44.3148,
        allowedRadius: 100,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        isActive: true,
      ),
      StoreModel(
        id: 'store2',
        name: 'فرع الكوفة',
        address: 'شارع الإمام علي، الكوفة',
        adminId: 'admin1',
        phone: '07801234568',
        latitude: 32.0303,
        longitude: 44.4031,
        allowedRadius: 150,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        isActive: true,
      ),
      StoreModel(
        id: 'store3',
        name: 'فرع كربلاء',
        address: 'قرب الحرم الحسيني، كربلاء',
        adminId: 'admin1',
        phone: '07801234569',
        latitude: 32.6160,
        longitude: 44.0323,
        allowedRadius: 120,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
    ];
  }

  // ============================================================
  // SHIFTS
  // ============================================================
  static List<ShiftModel> getShifts() {
    return [
      ShiftModel(
        id: 'shift1',
        storeId: 'store1',
        name: 'الشفت الصباحي',
        startTime: '08:00',
        endTime: '14:00',
        workDays: [0, 1, 2, 3, 4, 5],
        lateToleranceMinutes: 15,
        maxLateMinutes: 60,
        checkInWindowMinutes: 30,
        checkOutWindowMinutes: 15,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        isActive: true,
      ),
      ShiftModel(
        id: 'shift2',
        storeId: 'store1',
        name: 'الشفت المسائي',
        startTime: '14:00',
        endTime: '22:00',
        workDays: [0, 1, 2, 3, 4, 5],
        lateToleranceMinutes: 15,
        maxLateMinutes: 45,
        checkInWindowMinutes: 30,
        checkOutWindowMinutes: 15,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        isActive: true,
      ),
      ShiftModel(
        id: 'shift3',
        storeId: 'store2',
        name: 'الشفت الصباحي',
        startTime: '09:00',
        endTime: '17:00',
        workDays: [0, 1, 2, 3, 4],
        lateToleranceMinutes: 10,
        maxLateMinutes: 30,
        checkInWindowMinutes: 20,
        checkOutWindowMinutes: 10,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        isActive: true,
      ),
      ShiftModel(
        id: 'shift4',
        storeId: 'store3',
        name: 'الشفت الكامل',
        startTime: '10:00',
        endTime: '20:00',
        workDays: [0, 1, 2, 3, 4, 5, 6],
        lateToleranceMinutes: 20,
        maxLateMinutes: 60,
        checkInWindowMinutes: 30,
        checkOutWindowMinutes: 20,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
    ];
  }

  // ============================================================
  // TASKS
  // ============================================================
  static List<TaskModel> getTasks() {
    final now = DateTime.now();
    
    return [
      TaskModel(
        id: 'task1',
        title: 'ترتيب الرفوف',
        description: 'ترتيب جميع المنتجات على الرفوف حسب الفئات',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        assignedTo: 'emp1',
        assignedToName: 'محمد الموظف',
        assignedBy: 'admin1',
        assignedByName: 'أحمد المدير',
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        maxDurationMinutes: 120,
        deadline: now.add(const Duration(hours: 4)),
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      TaskModel(
        id: 'task2',
        title: 'جرد المخزون',
        description: 'جرد كامل لمخزون قسم المواد الغذائية',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        assignedTo: 'emp1',
        assignedToName: 'محمد الموظف',
        assignedBy: 'admin1',
        assignedByName: 'أحمد المدير',
        status: TaskStatus.inProgress,
        priority: TaskPriority.urgent,
        maxDurationMinutes: 180,
        deadline: now.add(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      TaskModel(
        id: 'task3',
        title: 'تنظيف الواجهة',
        description: 'تنظيف واجهات العرض الزجاجية',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        assignedTo: 'emp1',
        assignedToName: 'محمد الموظف',
        assignedBy: 'admin1',
        assignedByName: 'أحمد المدير',
        status: TaskStatus.completed,
        priority: TaskPriority.medium,
        maxDurationMinutes: 60,
        deadline: now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 5)),
        completedAt: now.subtract(const Duration(hours: 3)),
        completionImage: 'https://example.com/image1.jpg',
        completionNote: 'تم التنظيف بالكامل',
      ),
      TaskModel(
        id: 'task4',
        title: 'استلام الشحنة',
        description: 'استلام شحنة البضائع الجديدة وفحصها',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        assignedTo: 'emp2',
        assignedToName: 'علي الكاظمي',
        assignedBy: 'admin1',
        assignedByName: 'أحمد المدير',
        status: TaskStatus.pending,
        priority: TaskPriority.high,
        maxDurationMinutes: 90,
        deadline: now.add(const Duration(hours: 6)),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      TaskModel(
        id: 'task5',
        title: 'إعداد العروض',
        description: 'تجهيز لافتات العروض الأسبوعية',
        storeId: 'store2',
        storeName: 'فرع الكوفة',
        assignedTo: 'emp3',
        assignedToName: 'حسين العامري',
        assignedBy: 'admin1',
        assignedByName: 'أحمد المدير',
        status: TaskStatus.pending,
        priority: TaskPriority.low,
        maxDurationMinutes: 45,
        deadline: now.add(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      TaskModel(
        id: 'task6',
        title: 'صيانة المكيف',
        description: 'الاتصال بفني الصيانة لإصلاح المكيف',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        assignedTo: 'emp1',
        assignedToName: 'محمد الموظف',
        assignedBy: 'admin1',
        assignedByName: 'أحمد المدير',
        status: TaskStatus.failed,
        priority: TaskPriority.medium,
        maxDurationMinutes: 30,
        deadline: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 2)),
        failureReason: 'لم يتوفر فني الصيانة',
      ),
    ];
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================
  static List<AttendanceModel> getAttendance() {
    final now = DateTime.now();
    
    return [
      AttendanceModel(
        id: 'att1',
        userId: 'emp1',
        userName: 'محمد الموظف',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift1',
        shiftName: 'الشفت الصباحي',
        expectedStartTime: '08:00',
        expectedEndTime: '14:00',
        checkIn: DateTime(now.year, now.month, now.day - 1, 7, 55),
        checkOut: DateTime(now.year, now.month, now.day - 1, 14, 5),
        checkInLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        checkOutLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        totalHours: 6.17,
        isLate: false,
        lateMinutes: 0,
        isEarlyLeave: false,
        earlyLeaveMinutes: 0,
      ),
      AttendanceModel(
        id: 'att2',
        userId: 'emp1',
        userName: 'محمد الموظف',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift1',
        shiftName: 'الشفت الصباحي',
        expectedStartTime: '08:00',
        expectedEndTime: '14:00',
        checkIn: DateTime(now.year, now.month, now.day - 2, 8, 25),
        checkOut: DateTime(now.year, now.month, now.day - 2, 14, 0),
        checkInLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        checkOutLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        totalHours: 5.58,
        isLate: true,
        lateMinutes: 25,
        isEarlyLeave: false,
        earlyLeaveMinutes: 0,
      ),
      AttendanceModel(
        id: 'att3',
        userId: 'emp1',
        userName: 'محمد الموظف',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift1',
        shiftName: 'الشفت الصباحي',
        expectedStartTime: '08:00',
        expectedEndTime: '14:00',
        checkIn: DateTime(now.year, now.month, now.day - 3, 8, 0),
        checkOut: DateTime(now.year, now.month, now.day - 3, 13, 30),
        checkInLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        checkOutLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        totalHours: 5.5,
        isLate: false,
        lateMinutes: 0,
        isEarlyLeave: true,
        earlyLeaveMinutes: 30,
      ),
      AttendanceModel(
        id: 'att4',
        userId: 'emp1',
        userName: 'محمد الموظف',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift1',
        shiftName: 'الشفت الصباحي',
        expectedStartTime: '08:00',
        expectedEndTime: '14:00',
        checkIn: DateTime(now.year, now.month, now.day - 4, 8, 45),
        checkOut: DateTime(now.year, now.month, now.day - 4, 13, 15),
        checkInLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        checkOutLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        totalHours: 4.5,
        isLate: true,
        lateMinutes: 45,
        isEarlyLeave: true,
        earlyLeaveMinutes: 45,
      ),
      AttendanceModel(
        id: 'att5',
        userId: 'emp1',
        userName: 'محمد الموظف',
        storeId: 'store1',
        storeName: 'فرع النجف الرئيسي',
        shiftId: 'shift1',
        shiftName: 'الشفت الصباحي',
        expectedStartTime: '08:00',
        expectedEndTime: '14:00',
        checkIn: DateTime(now.year, now.month, now.day - 5, 7, 50),
        checkOut: DateTime(now.year, now.month, now.day - 5, 14, 10),
        checkInLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        checkOutLocation: const LocationData(
          latitude: 31.9957,
          longitude: 44.3148,
          address: 'فرع النجف الرئيسي',
        ),
        totalHours: 6.33,
        isLate: false,
        lateMinutes: 0,
        isEarlyLeave: false,
        earlyLeaveMinutes: 0,
      ),
    ];
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================
  static List<TaskModel> getTasksForUser(String userId) {
    return getTasks().where((t) => t.assignedTo == userId).toList();
  }

  static List<ShiftModel> getShiftsForStore(String storeId) {
    return getShifts().where((s) => s.storeId == storeId).toList();
  }

  static List<AttendanceModel> getAttendanceForUser(String userId) {
    return getAttendance().where((a) => a.userId == userId).toList();
  }

  static List<UserModel> getEmployeesForStore(String storeId) {
    return getUsers().where((u) => u.storeId == storeId && u.role == UserRole.employee).toList();
  }

  static List<UserModel> getEmployees() {
    return getUsers().where((u) => u.role == UserRole.employee).toList();
  }
}
