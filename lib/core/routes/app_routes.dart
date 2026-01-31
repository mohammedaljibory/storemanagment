import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
import '../../features/tasks/screens/create_task_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/store_management_screen.dart';
import '../../features/admin/screens/shift_management_screen.dart';
import '../../features/admin/screens/employees_screen.dart';
import '../../features/admin/screens/employee_detail_screen.dart';
import '../../features/admin/screens/free_employee_location_screen.dart';
import '../../features/requests/screens/requests_screen.dart' as req_screen;
import '../../features/requests/screens/create_request_screen.dart';
import '../../features/admin/screens/admin_requests_screen.dart';
import '../../features/admin/screens/active_employees_by_store_screen.dart';
import '../../features/admin/screens/vacation_employees_by_store_screen.dart';
import '../../features/admin/screens/tasks_by_employee_screen.dart';
import '../../features/admin/screens/employee_report_screen.dart';
import '../../features/admin/screens/create_edit_shift_screen.dart';
import '../../features/admin/screens/create_edit_employee_screen.dart';
import '../../features/admin/screens/create_edit_store_screen.dart';
import '../../features/admin/screens/add_overtime_screen.dart';
import '../../features/tasks/screens/edit_task_screen.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/store_model.dart';
import '../models/shift_model.dart';
import '../models/request_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String tasks = '/tasks';
  static const String taskDetail = '/task-detail';
  static const String createTask = '/create-task';
  static const String attendance = '/attendance';
  static const String profile = '/profile';
  static const String adminDashboard = '/admin-dashboard';
  static const String storeManagement = '/store-management';
  static const String shiftManagement = '/shift-management';
  static const String employees = '/employees';
  static const String employeeDetail = '/employee-detail';
  static const String requests = '/requests';
  static const String createRequest = '/create-request';
  static const String adminRequests = '/admin-requests';
  static const String activeEmployeesByStore = '/active-employees-by-store';
  static const String vacationEmployeesByStore = '/vacation-employees-by-store';
  static const String tasksByEmployee = '/tasks-by-employee';
  static const String employeeReport = '/employee-report';
  static const String freeEmployeeLocation = '/free-employee-location';
  static const String createEditShift = '/create-edit-shift';
  static const String createEditEmployee = '/create-edit-employee';
  static const String createEditStore = '/create-edit-store';
  static const String addOvertime = '/add-overtime';
  static const String editTask = '/edit-task';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _buildRoute(const LoginScreen());
      case signup:
        return _buildRoute(const SignupScreen());
      case home:
        return _buildRoute(const HomeScreen());
      case tasks:
        return _buildRoute(const TasksScreen());
      case taskDetail:
        final taskId = settings.arguments as String;
        return _buildRoute(TaskDetailScreen(taskId: taskId));
      case createTask:
        return _buildRoute(const CreateTaskScreen());
      case attendance:
        return _buildRoute(const AttendanceScreen());
      case profile:
        return _buildRoute(const ProfileScreen());
      case adminDashboard:
        return _buildRoute(const AdminDashboardScreen());
      case storeManagement:
        return _buildRoute(const StoreManagementScreen());
      case shiftManagement:
        return _buildRoute(const ShiftManagementScreen());
      case employees:
        return _buildRoute(const EmployeesScreen());
      case employeeDetail:
        final employeeId = settings.arguments as String;
        return _buildRoute(EmployeeDetailScreen(employeeId: employeeId));
      case requests:
        return _buildRoute(const req_screen.RequestsScreen());
      case createRequest:
        final initialType = settings.arguments as RequestType?;
        return _buildRoute(CreateRequestScreen(initialType: initialType));
      case adminRequests:
        return _buildRoute(const AdminRequestsScreen());
      case activeEmployeesByStore:
        return _buildRoute(const ActiveEmployeesByStoreScreen());
      case vacationEmployeesByStore:
        return _buildRoute(const VacationEmployeesByStoreScreen());
      case tasksByEmployee:
        return _buildRoute(const TasksByEmployeeScreen());
      case employeeReport:
        return _buildRoute(const EmployeeReportScreen());
      case freeEmployeeLocation:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(FreeEmployeeLocationScreen(
          employee: args['employee'] as UserModel,
          attendanceId: args['attendanceId'] as String?,
        ));
      case createEditShift:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(CreateEditShiftScreen(
          storeId: args['storeId'] as String,
          shift: args['shift'] as ShiftModel?,
        ));
      case createEditEmployee:
        final employee = settings.arguments as UserModel?;
        return _buildRoute(CreateEditEmployeeScreen(employee: employee));
      case createEditStore:
        final store = settings.arguments as StoreModel?;
        return _buildRoute(CreateEditStoreScreen(store: store));
      case addOvertime:
        return _buildRoute(const AddOvertimeScreen());
      case editTask:
        final task = settings.arguments as TaskModel;
        return _buildRoute(EditTaskScreen(task: task));
      default:
        return _buildRoute(
          Scaffold(
            body: Center(
              child: Text('لا توجد صفحة للمسار ${settings.name}'),
            ),
          ),
        );
    }
  }

  static Route<dynamic> _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}
