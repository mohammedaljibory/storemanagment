import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/models/request_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/break_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({Key? key}) : super(key: key);

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  RequestType _selectedType = RequestType.timeOff;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  bool _isMultiDay = false;
  bool _isBeforeShift = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _totalDays {
    if (_isMultiDay && _endDate != null) {
      return _endDate!.difference(_startDate).inDays + 1;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول')),
      );
    }

    final hasBalance = user.hasVacationBalance(_totalDays);
    final remainingBalance = user.remainingVacationDays;

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
              _buildHeader(context, isDarkMode),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request Type Selection
                      _buildRequestTypeSection(),

                      const SizedBox(height: 24),

                      // Break request info (check active attendance)
                      if (_selectedType == RequestType.breakRequest)
                        _buildBreakRequestSection(),

                      // Multi-day toggle (for vacation)
                      if (_selectedType == RequestType.fullDayOff)
                        _buildMultiDaySection(user, hasBalance, remainingBalance),

                      // Date Selection (not for break requests)
                      if (_selectedType != RequestType.breakRequest)
                        _buildDateSection(),

                      // End Date (for multi-day)
                      if (_isMultiDay) _buildEndDateSection(user, remainingBalance),

                      // Time Selection (for time-off)
                      if (_selectedType == RequestType.timeOff) ...[
                        _buildTimeSection(),
                        const SizedBox(height: 20),
                        _buildBeforeShiftSection(),
                      ],

                      const SizedBox(height: 24),

                      // Reason
                      _buildReasonSection(),

                      const SizedBox(height: 32),

                      // Submit Button
                      _buildSubmitButton(user, hasBalance),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTheme.primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_circle, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'طلب جديد',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTypeSection() {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'نوع الطلب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeCard(
                  type: RequestType.breakRequest,
                  icon: Icons.coffee,
                  label: 'استراحة',
                  description: 'طلب استراحة أثناء الدوام',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeCard(
                  type: RequestType.timeOff,
                  icon: Icons.timer_outlined,
                  label: 'زمنية',
                  description: 'استئذان لفترة محددة',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeCard(
                  type: RequestType.fullDayOff,
                  icon: Icons.calendar_today,
                  label: 'إجازة',
                  description: 'يوم كامل أو أكثر',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required RequestType type,
    required IconData icon,
    required String label,
    required String description,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (type == RequestType.timeOff || type == RequestType.breakRequest) {
            _isMultiDay = false;
            _endDate = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakRequestSection() {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final hasActiveAttendance = attendanceProvider.currentAttendance != null;

    return Column(
      children: [
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (hasActiveAttendance ? AppTheme.successColor : AppTheme.errorColor)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasActiveAttendance ? Icons.check_circle : Icons.warning_amber,
                      color: hasActiveAttendance ? AppTheme.successColor : AppTheme.errorColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasActiveAttendance ? 'حضور نشط' : 'لا يوجد حضور نشط',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasActiveAttendance ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                        Text(
                          hasActiveAttendance
                              ? 'يمكنك طلب استراحة الآن'
                              : 'يجب تسجيل الحضور أولاً لطلب استراحة',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasActiveAttendance) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'مدة الاستراحة المسموحة: 60 دقيقة\nسيتم إرسال الطلب للموافقة من المدير',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMultiDaySection(UserModel user, bool hasBalance, int remainingBalance) {
    return Column(
      children: [
        GlassContainer(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.date_range, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'إجازة متعددة الأيام',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: _isMultiDay,
                onChanged: (value) {
                  setState(() {
                    _isMultiDay = value;
                    if (!value) {
                      _endDate = null;
                    } else {
                      _endDate = _startDate.add(const Duration(days: 1));
                    }
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vacation balance info
        if (user.allowedVacationDays > 0)
          GlassContainer(
            child: Row(
              children: [
                Icon(
                  hasBalance ? Icons.account_balance_wallet : Icons.warning_amber,
                  color: hasBalance ? AppTheme.successColor : AppTheme.errorColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasBalance ? 'رصيد الإجازات' : 'رصيد غير كافٍ!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasBalance ? AppTheme.successColor : AppTheme.errorColor,
                        ),
                      ),
                      Text(
                        'المتبقي: $remainingBalance يوم ${_isMultiDay ? '(تطلب $_totalDays يوم)' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (hasBalance ? AppTheme.successColor : AppTheme.errorColor)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$remainingBalance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasBalance ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isMultiDay ? 'تاريخ البداية' : 'التاريخ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _startDate = date;
                      if (_endDate != null && _endDate!.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(_startDate),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getDayName(_startDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEndDateSection(UserModel user, int remainingBalance) {
    final maxDays = remainingBalance > 0 ? remainingBalance - 1 : 0;
    final maxEndDate = _startDate.add(Duration(days: maxDays));

    return Column(
      children: [
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'تاريخ النهاية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  if (_totalDays > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppTheme.primaryGradient),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_totalDays أيام',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _startDate.add(const Duration(days: 1)),
                    firstDate: _startDate.add(const Duration(days: 1)),
                    lastDate: user.allowedVacationDays > 0
                        ? maxEndDate
                        : DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _endDate = date;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.orange),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _endDate != null
                                ? _formatDate(_endDate!)
                                : 'اختر تاريخ النهاية',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _endDate == null ? Colors.grey : null,
                            ),
                          ),
                          if (_endDate != null)
                            Text(
                              _getDayName(_endDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_calendar, color: Colors.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      children: [
        GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time, color: AppTheme.secondaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'الوقت',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeCard(
                      label: 'من',
                      time: _startTime,
                      color: AppTheme.primaryColor,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (time != null) {
                          setState(() => _startTime = time);
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Expanded(
                    child: _buildTimeCard(
                      label: 'إلى',
                      time: _endTime,
                      color: AppTheme.secondaryColor,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (time != null) {
                          setState(() => _endTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Duration display
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'المدة: ${_calculateDuration()}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard({
    required String label,
    required TimeOfDay time,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeShiftSection() {
    return GlassContainer(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isBeforeShift ? Colors.orange : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isBeforeShift ? Icons.wb_sunny : Icons.work_history,
                  color: _isBeforeShift ? Colors.orange : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'زمنية قبل بداية الدوام',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'استئذان قبل موعد بدء العمل',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isBeforeShift,
                onChanged: (value) {
                  setState(() => _isBeforeShift = value);
                },
                activeColor: Colors.orange,
              ),
            ],
          ),
          if (_isBeforeShift) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'يجب العودة قبل الساعة ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}\nفترة السماح: 15 دقيقة',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonSection() {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'سبب الطلب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'اكتب سبب الطلب هنا...',
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(UserModel user, bool hasBalance) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : () => _submitRequest(user, hasBalance),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'إرسال الطلب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _submitRequest(UserModel user, bool hasBalance) async {
    // Validate reason
    if (_reasonController.text.trim().isEmpty) {
      _showSnackBar('يرجى كتابة سبب الطلب', isError: true);
      return;
    }

    // Handle break request separately
    if (_selectedType == RequestType.breakRequest) {
      await _submitBreakRequest(user);
      return;
    }

    // Validate multi-day vacation
    if (_selectedType == RequestType.fullDayOff && _isMultiDay && _endDate == null) {
      _showSnackBar('يرجى اختيار تاريخ النهاية', isError: true);
      return;
    }

    // Validate vacation balance
    if (_selectedType == RequestType.fullDayOff && user.allowedVacationDays > 0 && !hasBalance) {
      _showSnackBar('رصيد الإجازات غير كافٍ', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    int? durationMinutes;
    String? startTimeStr;
    String? endTimeStr;

    if (_selectedType == RequestType.timeOff) {
      startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      endTimeStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      durationMinutes = endMinutes - startMinutes;

      if (durationMinutes <= 0) {
        setState(() => _isSubmitting = false);
        _showSnackBar('وقت النهاية يجب أن يكون بعد وقت البداية', isError: true);
        return;
      }
    }

    final request = RequestModel(
      id: '',
      employeeId: user.id,
      employeeName: user.name,
      storeId: user.storeId ?? '',
      storeName: user.storeName ?? '',
      type: _selectedType,
      requestDate: DateTime.now(),
      targetDate: _startDate,
      endDate: _isMultiDay ? _endDate : null,
      totalDays: _selectedType == RequestType.fullDayOff ? _totalDays : null,
      startTime: startTimeStr,
      endTime: endTimeStr,
      durationMinutes: durationMinutes,
      reason: _reasonController.text.trim(),
      isBeforeShift: _selectedType == RequestType.timeOff ? _isBeforeShift : false,
      expectedReturnTime: _selectedType == RequestType.timeOff ? endTimeStr : null,
      graceMinutes: 15,
    );

    final requestProvider = context.read<RequestProvider>();
    final success = await requestProvider.createRequest(request);

    if (success) {
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        _showSnackBar('تم إرسال الطلب بنجاح');
      }
    } else {
      setState(() => _isSubmitting = false);
      _showSnackBar(requestProvider.errorMessage ?? 'فشل في إرسال الطلب', isError: true);
    }
  }

  Future<void> _submitBreakRequest(UserModel user) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final currentAttendance = attendanceProvider.currentAttendance;

    // Validate active attendance
    if (currentAttendance == null) {
      _showSnackBar('يجب تسجيل الحضور أولاً لطلب استراحة', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final breakService = BreakService();
      final success = await breakService.requestBreak(
        attendanceId: currentAttendance.id,
        userId: user.id,
        userName: user.name,
        storeId: user.storeId ?? '',
        storeName: user.storeName ?? '',
        reason: _reasonController.text.trim(),
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
          _showSnackBar('تم إرسال طلب الاستراحة بنجاح');
        }
      } else {
        setState(() => _isSubmitting = false);
        _showSnackBar('فشل في إرسال طلب الاستراحة', isError: true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('حدث خطأ: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getDayName(DateTime date) {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return days[date.weekday % 7];
  }

  String _calculateDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final duration = endMinutes - startMinutes;

    if (duration <= 0) return 'غير صالح';

    final hours = duration ~/ 60;
    final minutes = duration % 60;

    if (hours > 0 && minutes > 0) {
      return '$hours ساعة و $minutes دقيقة';
    } else if (hours > 0) {
      return '$hours ساعة';
    } else {
      return '$minutes دقيقة';
    }
  }
}
