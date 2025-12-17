import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_model.dart';

class ShiftProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<ShiftModel> _shifts = [];
  ShiftModel? _selectedShift;
  bool _isLoading = false;
  String? _errorMessage;

  // ============ GETTERS ============
  List<ShiftModel> get shifts => [..._shifts];
  List<ShiftModel> get activeShifts => _shifts.where((s) => s.isActive).toList();
  ShiftModel? get selectedShift => _selectedShift;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get shiftCount => _shifts.length;

  /// Fetch shifts - accepts nullable storeId
  Future<void> fetchShifts(String? storeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      Query<Map<String, dynamic>> query = _firestore.collection('shifts');

      if (storeId != null && storeId.isNotEmpty) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      _shifts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return ShiftModel.fromJson(data);
      }).where((s) => s.isActive).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الشفتات: $e';
      notifyListeners();
      print('Error fetching shifts: $e');
    }
  }

  Future<void> fetchAllShifts() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore.collection('shifts').get();

      _shifts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return ShiftModel.fromJson(data);
      }).where((s) => s.isActive).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الشفتات: $e';
      notifyListeners();
      print('Error fetching all shifts: $e');
    }
  }

  /// Fetch single shift by ID (for employees)
  Future<ShiftModel?> fetchShiftById(String shiftId) async {
    try {
      final doc = await _firestore.collection('shifts').doc(shiftId).get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        final shift = ShiftModel.fromJson(data);

        // Add to local list if not exists
        if (!_shifts.any((s) => s.id == shift.id)) {
          _shifts.add(shift);
        }

        return shift;
      }
      return null;
    } catch (e) {
      print('Error fetching shift by ID: $e');
      return null;
    }
  }
  /// Get shifts by store
  List<ShiftModel> getShiftsByStore(String storeId) {
    return _shifts.where((s) => s.storeId == storeId).toList();
  }

  /// Create new shift in Firebase
  Future<bool> createShift(ShiftModel shift) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Add to Firestore
      final docRef = await _firestore.collection('shifts').add(shift.toJson());
      
      // Create shift with the new ID
      final newShift = shift.copyWith(id: docRef.id);
      
      // Update Firestore with the ID
      await docRef.update({'id': docRef.id});
      
      // Add to local list
      _shifts.insert(0, newShift);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إنشاء الشفت: $e';
      notifyListeners();
      print('Error creating shift: $e');
      return false;
    }
  }

  /// Update shift in Firebase
  Future<bool> updateShift(ShiftModel shift) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update in Firestore
      await _firestore.collection('shifts').doc(shift.id).update(shift.toJson());

      // Update local list
      final index = _shifts.indexWhere((s) => s.id == shift.id);
      if (index != -1) {
        _shifts[index] = shift;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث الشفت: $e';
      notifyListeners();
      print('Error updating shift: $e');
      return false;
    }
  }

  /// Delete shift in Firebase
  Future<bool> deleteShift(String shiftId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Soft delete in Firestore
      await _firestore.collection('shifts').doc(shiftId).update({
        'isActive': false,
      });

      // Remove from local list
      _shifts.removeWhere((s) => s.id == shiftId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في حذف الشفت: $e';
      notifyListeners();
      print('Error deleting shift: $e');
      return false;
    }
  }

  /// Get shift by ID
  ShiftModel? getShiftById(String id) {
    try {
      return _shifts.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Select a shift
  void selectShift(ShiftModel? shift) {
    _selectedShift = shift;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Listen to shifts in real-time
  Stream<List<ShiftModel>> shiftsStream(String? storeId) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('shifts')
        .where('isActive', isEqualTo: true);

    if (storeId != null && storeId.isNotEmpty) {
      query = query.where('storeId', isEqualTo: storeId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ShiftModel.fromJson(data);
        }).toList());
  }
}
