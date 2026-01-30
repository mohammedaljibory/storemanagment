import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class CreateEditShiftScreen extends StatefulWidget {
  final String storeId;
  final ShiftModel? shift;

  const CreateEditShiftScreen({
    Key? key,
    required this.storeId,
    this.shift,
  }) : super(key: key);

  @override
  State<CreateEditShiftScreen> createState() => _CreateEditShiftScreenState();
}

class _CreateEditShiftScreenState extends State<CreateEditShiftScreen> {
  late TextEditingController _nameController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<int> _selectedDays;
  late int _lateToleranceMinutes;
  late int _maxLateMinutes;
  late int _checkInWindowMinutes;
  late int _checkOutWindowMinutes;
  bool _isLoading = false;

  bool get isEdit => widget.shift != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shift?.name);

    _startTime = widget.shift != null
        ? TimeOfDay(
            hour: int.parse(widget.shift!.startTime.split(':')[0]),
            minute: int.parse(widget.shift!.startTime.split(':')[1]),
          )
        : const TimeOfDay(hour: 8, minute: 0);

    _endTime = widget.shift != null
        ? TimeOfDay(
            hour: int.parse(widget.shift!.endTime.split(':')[0]),
            minute: int.parse(widget.shift!.endTime.split(':')[1]),
          )
        : const TimeOfDay(hour: 14, minute: 0);

    _selectedDays = List<int>.from(widget.shift?.workDays ?? [0, 1, 2, 3, 4, 5]);
    _lateToleranceMinutes = widget.shift?.lateToleranceMinutes ?? 15;
    _maxLateMinutes = widget.shift?.maxLateMinutes ?? 60;
    _checkInWindowMinutes = widget.shift?.checkInWindowMinutes ?? 30;
    _checkOutWindowMinutes = widget.shift?.checkOutWindowMinutes ?? 15;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
                    Expanded(
                      child: Text(
                        isEdit ? 'تعديل الشفت' : 'إضافة شفت جديد',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift Name
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.label,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'اسم الشفت',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'مثال: الشفت الصباحي',
                                filled: true,
                                fillColor: isDarkMode
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Work Time
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.schedule,
                                    color: AppTheme.secondaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'وقت العمل',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTimePicker(
                                    'البداية',
                                    _startTime,
                                    AppTheme.successColor,
                                    (time) => setState(() => _startTime = time),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildTimePicker(
                                    'النهاية',
                                    _endTime,
                                    AppTheme.errorColor,
                                    (time) => setState(() => _endTime = time),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Work Days
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: AppTheme.warningColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'أيام العمل',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (index) {
                                const days = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
                                final isSelected = _selectedDays.contains(index);
                                return FilterChip(
                                  label: Text(days[index]),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedDays.add(index);
                                      } else {
                                        _selectedDays.remove(index);
                                      }
                                    });
                                  },
                                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                                  checkmarkColor: AppTheme.primaryColor,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Time Rules
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.rule,
                                    color: Colors.purple,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'قواعد الوقت',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Late Tolerance
                            _buildSliderSetting(
                              'سماحية التأخير',
                              'الوقت المسموح قبل احتساب تأخير',
                              _lateToleranceMinutes,
                              0,
                              60,
                              'دقيقة',
                              AppTheme.warningColor,
                              (value) => setState(() => _lateToleranceMinutes = value.toInt()),
                            ),

                            const Divider(height: 30),

                            // Max Late
                            _buildSliderSetting(
                              'الحد الأقصى للتأخير',
                              'بعده يُرفض تسجيل الدخول',
                              _maxLateMinutes,
                              15,
                              120,
                              'دقيقة',
                              AppTheme.errorColor,
                              (value) => setState(() => _maxLateMinutes = value.toInt()),
                            ),

                            const Divider(height: 30),

                            // Check-in Window
                            _buildSliderSetting(
                              'نافذة الدخول المبكر',
                              'كم دقيقة قبل بدء الشفت يمكن الدخول',
                              _checkInWindowMinutes,
                              0,
                              60,
                              'دقيقة',
                              AppTheme.primaryColor,
                              (value) => setState(() => _checkInWindowMinutes = value.toInt()),
                            ),

                            const Divider(height: 30),

                            // Check-out Window
                            _buildSliderSetting(
                              'حد الخروج المبكر',
                              'كم دقيقة قبل نهاية الشفت يمكن الخروج',
                              _checkOutWindowMinutes,
                              0,
                              60,
                              'دقيقة',
                              AppTheme.secondaryColor,
                              (value) => setState(() => _checkOutWindowMinutes = value.toInt()),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(
                      color: isDarkMode ? Colors.white30 : Colors.grey,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveShift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isEdit ? 'تحديث الشفت' : 'إضافة الشفت',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay time,
    Color color,
    Function(TimeOfDay) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  label == 'البداية' ? Icons.login : Icons.logout,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(
    String title,
    String subtitle,
    int value,
    double min,
    double max,
    String unit,
    Color color,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$value $unit',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _saveShift() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم الشفت'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار يوم عمل واحد على الأقل'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);

    final newShift = ShiftModel(
      id: widget.shift?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      storeId: widget.storeId,
      name: _nameController.text,
      startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      workDays: _selectedDays..sort(),
      lateToleranceMinutes: _lateToleranceMinutes,
      maxLateMinutes: _maxLateMinutes,
      checkInWindowMinutes: _checkInWindowMinutes,
      checkOutWindowMinutes: _checkOutWindowMinutes,
      createdAt: widget.shift?.createdAt ?? DateTime.now(),
    );

    try {
      if (isEdit) {
        shiftProvider.updateShift(newShift);
      } else {
        shiftProvider.createShift(newShift);
      }
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
