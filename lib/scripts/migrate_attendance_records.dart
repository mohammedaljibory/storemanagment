// Migration Script: Add isCheckedOut field to old attendance records
// Run this once from admin dashboard or a dedicated button
//
// Usage: Call MigrationService.migrateAttendanceRecords() from your admin screen

import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrates all old attendance records to add isCheckedOut field
  /// Returns the number of records updated
  static Future<MigrationResult> migrateAttendanceRecords({
    Function(int current, int total)? onProgress,
  }) async {
    int updated = 0;
    int skipped = 0;
    int errors = 0;
    final List<String> errorIds = [];

    try {
      // Fetch all attendance records
      final snapshot = await _firestore.collection('attendance').get();
      final total = snapshot.docs.length;

      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();

        try {
          // Check if isCheckedOut field already exists
          if (data.containsKey('isCheckedOut')) {
            skipped++;
            onProgress?.call(i + 1, total);
            continue;
          }

          // Determine isCheckedOut value based on checkOut field
          final bool isCheckedOut = data['checkOut'] != null;

          // Update the document
          await _firestore.collection('attendance').doc(doc.id).update({
            'isCheckedOut': isCheckedOut,
          });

          updated++;
        } catch (e) {
          errors++;
          errorIds.add(doc.id);
        }

        onProgress?.call(i + 1, total);
      }

      return MigrationResult(
        totalRecords: total,
        updated: updated,
        skipped: skipped,
        errors: errors,
        errorIds: errorIds,
      );
    } catch (e) {
      return MigrationResult(
        totalRecords: 0,
        updated: updated,
        skipped: skipped,
        errors: errors + 1,
        errorIds: errorIds,
        fatalError: e.toString(),
      );
    }
  }

  /// Check how many records need migration (dry run)
  static Future<MigrationPreview> previewMigration() async {
    int needsMigration = 0;
    int alreadyMigrated = 0;
    int withCheckout = 0;
    int withoutCheckout = 0;

    try {
      final snapshot = await _firestore.collection('attendance').get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data.containsKey('isCheckedOut')) {
          alreadyMigrated++;
        } else {
          needsMigration++;
          if (data['checkOut'] != null) {
            withCheckout++;
          } else {
            withoutCheckout++;
          }
        }
      }

      return MigrationPreview(
        totalRecords: snapshot.docs.length,
        needsMigration: needsMigration,
        alreadyMigrated: alreadyMigrated,
        willSetCheckedOutTrue: withCheckout,
        willSetCheckedOutFalse: withoutCheckout,
      );
    } catch (e) {
      return MigrationPreview(
        totalRecords: 0,
        needsMigration: 0,
        alreadyMigrated: 0,
        willSetCheckedOutTrue: 0,
        willSetCheckedOutFalse: 0,
        error: e.toString(),
      );
    }
  }
}

class MigrationResult {
  final int totalRecords;
  final int updated;
  final int skipped;
  final int errors;
  final List<String> errorIds;
  final String? fatalError;

  MigrationResult({
    required this.totalRecords,
    required this.updated,
    required this.skipped,
    required this.errors,
    required this.errorIds,
    this.fatalError,
  });

  bool get isSuccess => fatalError == null && errors == 0;

  String get summary {
    if (fatalError != null) {
      return 'فشل التحديث: $fatalError';
    }
    return '''
تم التحديث بنجاح!
━━━━━━━━━━━━━━━━━━━━
📊 إجمالي السجلات: $totalRecords
✅ تم تحديثها: $updated
⏭️ تم تخطيها (محدثة مسبقاً): $skipped
❌ أخطاء: $errors
''';
  }
}

class MigrationPreview {
  final int totalRecords;
  final int needsMigration;
  final int alreadyMigrated;
  final int willSetCheckedOutTrue;
  final int willSetCheckedOutFalse;
  final String? error;

  MigrationPreview({
    required this.totalRecords,
    required this.needsMigration,
    required this.alreadyMigrated,
    required this.willSetCheckedOutTrue,
    required this.willSetCheckedOutFalse,
    this.error,
  });

  String get summary {
    if (error != null) {
      return 'خطأ: $error';
    }
    return '''
معاينة التحديث
━━━━━━━━━━━━━━━━━━━━
📊 إجمالي السجلات: $totalRecords
✅ محدثة مسبقاً: $alreadyMigrated
🔄 تحتاج تحديث: $needsMigration
   ├─ سيتم تعيين isCheckedOut=true: $willSetCheckedOutTrue
   └─ سيتم تعيين isCheckedOut=false: $willSetCheckedOutFalse
''';
  }
}
