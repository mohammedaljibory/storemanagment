import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_model.dart';

class StoreProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<StoreModel> _stores = [];
  StoreModel? _selectedStore;
  bool _isLoading = false;
  String? _errorMessage;

  // ============ GETTERS ============
  List<StoreModel> get stores => [..._stores];
  List<StoreModel> get activeStores => _stores.where((s) => s.isActive).toList();
  StoreModel? get selectedStore => _selectedStore;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get storeCount => _stores.length;
  int get activeStoreCount => activeStores.length;

  /// Fetch all stores for an admin from Firebase
  Future<void> fetchStores(String adminId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('stores')
          .where('adminId', isEqualTo: adminId)
          .get();

      _stores = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Handle Timestamp
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return StoreModel.fromJson(data);
      }).where((s) => s.isActive).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب المتاجر: $e';
      notifyListeners();
      print('Error fetching stores: $e');
    }
  }
  /// Fetch single store by ID (for employees)
  Future<StoreModel?> fetchStoreById(String storeId) async {
    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        final store = StoreModel.fromJson(data);

        // Add to local list if not exists
        if (!_stores.any((s) => s.id == store.id)) {
          _stores.add(store);
        }

        return store;
      }
      return null;
    } catch (e) {
      print('Error fetching store by ID: $e');
      return null;
    }
  }

  /// Create new store in Firebase
  Future<bool> createStore(StoreModel store) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Add to Firestore
      final docRef = await _firestore.collection('stores').add(store.toJson());
      
      // Create store with the new ID
      final newStore = store.copyWith(id: docRef.id);
      
      // Update Firestore with the ID
      await docRef.update({'id': docRef.id});
      
      // Add to local list
      _stores.insert(0, newStore);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إنشاء المتجر: $e';
      notifyListeners();
      print('Error creating store: $e');
      return false;
    }
  }

  /// Update store in Firebase
  Future<bool> updateStore(StoreModel store) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update in Firestore
      await _firestore.collection('stores').doc(store.id).update(store.toJson());

      // Update local list
      final index = _stores.indexWhere((s) => s.id == store.id);
      if (index != -1) {
        _stores[index] = store;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث المتجر: $e';
      notifyListeners();
      print('Error updating store: $e');
      return false;
    }
  }

  /// Soft delete store in Firebase
  Future<bool> deleteStore(String storeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Soft delete in Firestore
      await _firestore.collection('stores').doc(storeId).update({
        'isActive': false,
      });

      // Remove from local list
      _stores.removeWhere((s) => s.id == storeId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في حذف المتجر: $e';
      notifyListeners();
      print('Error deleting store: $e');
      return false;
    }
  }

  /// Get store by ID
  StoreModel? getStoreById(String id) {
    try {
      return _stores.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Select a store
  void selectStore(StoreModel? store) {
    _selectedStore = store;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch multiple stores by IDs
  Future<List<StoreModel>> fetchStoresByIds(List<String> storeIds) async {
    try {
      if (storeIds.isEmpty) return [];

      final List<StoreModel> result = [];

      // Check cache first
      for (final id in storeIds) {
        final cached = getStoreById(id);
        if (cached != null) {
          result.add(cached);
        }
      }

      // Fetch missing stores
      final missingIds = storeIds.where(
        (id) => !result.any((s) => s.id == id)
      ).toList();

      if (missingIds.isNotEmpty) {
        for (final id in missingIds) {
          final store = await fetchStoreById(id);
          if (store != null) {
            result.add(store);
          }
        }
      }

      return result;
    } catch (e) {
      print('Error fetching stores by IDs: $e');
      return [];
    }
  }

  /// Find stores within radius of given coordinates
  List<StoreModel> findStoresWithinRadius(double lat, double lng, {List<String>? filterStoreIds}) {
    var stores = _stores.where((s) => s.isActive).toList();

    if (filterStoreIds != null) {
      stores = stores.where((s) => filterStoreIds.contains(s.id)).toList();
    }

    return stores.where((s) => s.isWithinRadius(lat, lng)).toList();
  }

  /// Listen to stores in real-time
  Stream<List<StoreModel>> storesStream(String adminId) {
    return _firestore
        .collection('stores')
        .where('adminId', isEqualTo: adminId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return StoreModel.fromJson(data);
            }).toList());
  }
}
