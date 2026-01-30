import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/routes/app_routes.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({Key? key}) : super(key: key);

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stores = context.read<StoreProvider>().stores;
      if (stores.isNotEmpty) {
        setState(() {
          _selectedStoreId = stores.first.id;
        });
        context.read<ShiftProvider>().fetchShifts(stores.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF0F0F1E)]
                : [const Color(0xFFE3F2FD), const Color(0xFFF5F5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'إدارة الشفتات',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),

              // Store Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Consumer<StoreProvider>(
                  builder: (context, storeProvider, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStoreId,
                          isExpanded: true,
                          hint: const Text('اختر المتجر'),
                          items: storeProvider.stores.map((store) {
                            return DropdownMenuItem(
                              value: store.id,
                              child: Text(store.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStoreId = value;
                            });
                            if (value != null) {
                              context.read<ShiftProvider>().fetchShifts(value);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Shift List
              Expanded(
                child: Consumer<ShiftProvider>(
                  builder: (context, shiftProvider, _) {
                    if (shiftProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final shifts = _selectedStoreId != null
                        ? shiftProvider.getShiftsByStore(_selectedStoreId!)
                        : <ShiftModel>[];

                    if (shifts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 80,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'لا توجد شفتات',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: shifts.length,
                      itemBuilder: (context, index) {
                        return _buildShiftCard(shifts[index], index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedStoreId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('يرجى اختيار المتجر أولاً')),
            );
            return;
          }
          Navigator.pushNamed(
            context,
            AppRoutes.createEditShift,
            arguments: {
              'storeId': _selectedStoreId,
              'shift': null,
            },
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة شفت'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildShiftCard(ShiftModel shift, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.secondaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${shift.startTime} - ${shift.endTime}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.createEditShift,
                      arguments: {
                        'storeId': _selectedStoreId,
                        'shift': shift,
                      },
                    );
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(context, shift);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 10),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                        SizedBox(width: 10),
                        Text('حذف', style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          // Time Info
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.login,
                'بداية: ${shift.startTime}',
                AppTheme.successColor,
              ),
              _buildInfoChip(
                Icons.logout,
                'نهاية: ${shift.endTime}',
                AppTheme.errorColor,
              ),
              _buildInfoChip(
                Icons.timer,
                shift.shiftDuration,
                AppTheme.secondaryColor,
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Work Days
          Text(
            'أيام العمل: ${shift.workDaysText}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          
          const Divider(height: 20),
          
          // Time Rules
          Text(
            'قواعد الوقت',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRuleChip(
                'سماحية التأخير',
                '${shift.lateToleranceMinutes} دقيقة',
                AppTheme.warningColor,
              ),
              _buildRuleChip(
                'حد التأخير الأقصى',
                '${shift.maxLateMinutes} دقيقة',
                AppTheme.errorColor,
              ),
              _buildRuleChip(
                'نافذة الدخول',
                '${shift.checkInWindowMinutes} دقيقة قبل',
                AppTheme.primaryColor,
              ),
              _buildRuleChip(
                'حد الخروج المبكر',
                '${shift.checkOutWindowMinutes} دقيقة قبل النهاية',
                AppTheme.secondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ShiftModel shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            SizedBox(width: 10),
            Text('حذف الشفت'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف "${shift.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ShiftProvider>().deleteShift(shift.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
