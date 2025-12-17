import 'package:flutter/material.dart';
import '../../../core/services/firebase_seeder.dart';
import '../../../core/theme/app_theme.dart';

/// Admin screen to seed test data
/// Add this to your admin menu
class DataSeederScreen extends StatefulWidget {
  const DataSeederScreen({Key? key}) : super(key: key);

  @override
  State<DataSeederScreen> createState() => _DataSeederScreenState();
}

class _DataSeederScreenState extends State<DataSeederScreen> {
  bool _isLoading = false;
  String _status = '';
  List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إعداد البيانات التجريبية'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 10),
                      Text(
                        'معلومات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'سيتم إنشاء البيانات التالية:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text('• 1 مدير + 3 موظفين'),
                  Text('• 3 متاجر (النجف، الكوفة، كربلاء)'),
                  Text('• 4 شفتات'),
                  Text('• 6 مهام متنوعة'),
                  Text('• 6 سجلات حضور'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Test Accounts Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Text(
                        'حسابات الاختبار',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildAccountInfo('المدير', 'admin@store.com', 'admin123'),
                  const Divider(),
                  _buildAccountInfo('موظف 1', 'employee@store.com', 'emp123'),
                  const Divider(),
                  _buildAccountInfo('موظف 2', 'ali@store.com', 'emp123'),
                  const Divider(),
                  _buildAccountInfo('موظف 3', 'hussein@store.com', 'emp123'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _seedData,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle),
                    label: Text(_isLoading ? 'جاري الإنشاء...' : 'إنشاء البيانات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearData,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('مسح الكل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status.contains('✅')
                      ? Colors.green.shade100
                      : _status.contains('❌')
                          ? Colors.red.shade100
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _status.contains('✅')
                        ? Colors.green.shade700
                        : _status.contains('❌')
                            ? Colors.red.shade700
                            : Colors.grey.shade700,
                  ),
                ),
              ),

            // Logs
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'السجل:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.green,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfo(String role, String email, String password) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            role,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            email,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            password,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _seedData() async {
    setState(() {
      _isLoading = true;
      _status = 'جاري إنشاء البيانات...';
      _logs = [];
    });

    try {
      _addLog('🚀 بدء إنشاء البيانات...');
      
      await FirebaseSeeder.seedAll();
      
      _addLog('✅ تم إنشاء جميع البيانات بنجاح!');
      
      setState(() {
        _status = '✅ تم إنشاء البيانات بنجاح!';
      });
    } catch (e) {
      _addLog('❌ خطأ: $e');
      setState(() {
        _status = '❌ حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف جميع البيانات؟\nهذا الإجراء لا يمكن التراجع عنه!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _status = 'جاري حذف البيانات...';
      _logs = [];
    });

    try {
      _addLog('🗑️ بدء حذف البيانات...');
      
      await FirebaseSeeder.clearAll();
      
      _addLog('✅ تم حذف جميع البيانات!');
      
      setState(() {
        _status = '✅ تم حذف جميع البيانات!';
      });
    } catch (e) {
      _addLog('❌ خطأ: $e');
      setState(() {
        _status = '❌ حدث خطأ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }
}
