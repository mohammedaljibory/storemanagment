import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // ============ GETTERS ============
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isEmployee => _user?.role == UserRole.employee;

  /// Login with email and password using Firebase Auth
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Get user data from Firestore
        final userDoc = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (userDoc.docs.isNotEmpty) {
          final data = userDoc.docs.first.data();
          data['id'] = userDoc.docs.first.id;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          _user = UserModel.fromJson(data);

          // Register FCM token for push notifications
          await _registerFCMToken();

          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _isLoading = false;
      _errorMessage = 'لم يتم العثور على بيانات المستخدم';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      notifyListeners();
      print('Login error: $e');
      return false;
    }
  }

  /// Register new user
  Future<bool> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
    UserRole role = UserRole.employee,
    String? storeId,
    String? storeName,
    String? shiftId,
    String? shiftName,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document in Firestore
        final newUser = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          phone: phone,
          role: role,
          storeId: storeId,
          storeName: storeName,
          shiftId: shiftId,
          shiftName: shiftName,
          createdAt: DateTime.now(),
          isActive: true,
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(newUser.toJson());

        _user = newUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = 'فشل في إنشاء الحساب';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ في إنشاء الحساب: $e';
      notifyListeners();
      print('Signup error: $e');
      return false;
    }
  }

  /// Create employee (admin only) - without requiring Firebase Auth password

  Future<bool> createEmployee({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String storeId,
    required String storeName,
    required String shiftId,
    required String shiftName,
    int daysOffPerMonth = 0,  // Add this


  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document in Firestore
        final newEmployee = UserModel(
          id: credential.user!.uid,
          name: name,
          email: email,
          phone: phone,
          role: UserRole.employee,
          storeId: storeId,
          storeName: storeName,
          shiftId: shiftId,
          shiftName: shiftName,
          createdAt: DateTime.now(),
          isActive: true,
          daysOffPerMonth: daysOffPerMonth,

        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(newEmployee.toJson());

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = 'فشل في إنشاء حساب الموظف';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ في إنشاء الموظف: $e';
      notifyListeners();
      print('Create employee error: $e');
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile(UserModel updatedUser) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore
          .collection('users')
          .doc(updatedUser.id)
          .update(updatedUser.toJson());

      if (_user?.id == updatedUser.id) {
        _user = updatedUser;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث البيانات: $e';
      notifyListeners();
      print('Update profile error: $e');
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    // Unregister FCM token before logout
    if (_user != null) {
      await FCMService.unregisterToken(_user!.id);
    }
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// Register FCM token for push notifications
  Future<void> _registerFCMToken() async {
    if (_user == null) return;

    try {
      // Register device token
      await FCMService.registerToken(_user!.id);

      // Subscribe to relevant topics based on role
      if (_user!.isAdmin) {
        await FCMService.subscribeToAdminNotifications();
      }

      // Subscribe to store notifications if user has a store
      if (_user!.storeId != null) {
        await FCMService.subscribeToStore(_user!.storeId!);
      }
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }

  /// Get route based on user role
  String getHomeRoute() {
    if (_user?.role == UserRole.admin) {
      return '/admin-dashboard';
    }
    return '/home';
  }

  /// Check if user is logged in on app start
  Future<bool> checkAuthStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get user data from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          data['id'] = userDoc.id;
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          _user = UserModel.fromJson(data);

          // Register FCM token for push notifications
          await _registerFCMToken();

          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Check auth status error: $e');
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get Arabic error message for Firebase Auth errors
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        return 'حدث خطأ في المصادقة: $code';
    }
  }
}
