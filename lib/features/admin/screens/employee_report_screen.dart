import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/attendance_model.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/request_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class EmployeeReportScreen extends StatefulWidget {
  const EmployeeReportScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeReportScreen> createState() => _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends State<EmployeeReportScreen> {
  String? _selectedEmployeeId;
  UserModel? _selectedEmployee;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _includeAttendance = true;
  bool _includeTasks = true;
  bool _includeDayOffs = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees();
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
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEmployeeSelector(context),
                      const SizedBox(height: 20),
                      _buildDateRangeSelector(context),
                      const SizedBox(height: 20),
                      _buildReportOptions(context),
                      const SizedBox(height: 30),
                      _buildGenerateButton(context),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقارير الموظفين',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إنشاء تقرير PDF للموظف',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTheme.primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf, color: Colors.white),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildEmployeeSelector(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final employees = employeeProvider.activeEmployees;

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'اختر الموظف',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedEmployeeId,
            decoration: InputDecoration(
              hintText: 'اختر موظف',
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: employees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee.id,
                child: Text(employee.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedEmployeeId = value;
                _selectedEmployee = employees.firstWhere((e) => e.id == value);
              });
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    final dateFormat = intl.DateFormat('yyyy/MM/dd');

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.date_range, color: AppTheme.secondaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'نطاق التاريخ',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'من',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          dateFormat.format(_startDate),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, color: Colors.grey),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إلى',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          dateFormat.format(_endDate),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Quick date selection
          Wrap(
            spacing: 10,
            children: [
              _buildQuickDateButton('آخر 7 أيام', 7),
              _buildQuickDateButton('آخر 30 يوم', 30),
              _buildQuickDateButton('آخر 90 يوم', 90),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildQuickDateButton(String label, int days) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _endDate = DateTime.now();
          _startDate = DateTime.now().subtract(Duration(days: days));
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildReportOptions(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.checklist, color: AppTheme.successColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'محتوى التقرير',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildCheckOption('سجل الحضور', _includeAttendance, (value) {
            setState(() => _includeAttendance = value ?? true);
          }),
          _buildCheckOption('المهام المكتملة', _includeTasks, (value) {
            setState(() => _includeTasks = value ?? true);
          }),
          _buildCheckOption('الإجازات المعتمدة', _includeDayOffs, (value) {
            setState(() => _includeDayOffs = value ?? true);
          }),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildCheckOption(String label, bool value, Function(bool?) onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
      activeColor: AppTheme.successColor,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildGenerateButton(BuildContext context) {
    final canGenerate = _selectedEmployeeId != null &&
        (_includeAttendance || _includeTasks || _includeDayOffs);

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: canGenerate && !_isGenerating ? _generateReport : null,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(
          _isGenerating ? 'جارِ إنشاء التقرير...' : 'إنشاء التقرير PDF',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canGenerate ? AppTheme.primaryColor : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedEmployee == null) return;

    setState(() => _isGenerating = true);

    try {
      // Fetch data
      final attendanceProvider = context.read<AttendanceProvider>();
      final taskProvider = context.read<TaskProvider>();
      final requestProvider = context.read<RequestProvider>();

      await attendanceProvider.fetchAttendanceHistory(_selectedEmployeeId!);
      await taskProvider.fetchTasks(userId: _selectedEmployeeId!, isAdmin: false);
      await requestProvider.fetchEmployeeRequests(_selectedEmployeeId!);

      // Filter data by date range
      final attendance = attendanceProvider.attendanceHistory.where((a) {
        return a.checkIn.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            a.checkIn.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      final tasks = taskProvider.completedTasks.where((t) {
        return t.deadline.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            t.deadline.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      final dayOffs = requestProvider.approvedRequests.where((r) {
        return r.type == RequestType.fullDayOff &&
            r.targetDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            r.targetDate.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      // Generate PDF
      final pdf = await _buildPdf(
        employee: _selectedEmployee!,
        attendance: _includeAttendance ? attendance : [],
        tasks: _includeTasks ? tasks : [],
        dayOffs: _includeDayOffs ? dayOffs : [],
      );

      // Share/Print PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'تقرير_${_selectedEmployee!.name}_${intl.DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<pw.Document> _buildPdf({
    required UserModel employee,
    required List<AttendanceModel> attendance,
    required List<TaskModel> tasks,
    required List<RequestModel> dayOffs,
  }) async {
    final pdf = pw.Document();
    final dateFormat = intl.DateFormat('yyyy/MM/dd');
    final timeFormat = intl.DateFormat('HH:mm');

    // Load Arabic font
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBoldFont = await PdfGoogleFonts.cairoBold();

    // Merge attendance and vacation days into a unified list sorted by date
    final List<_DayRecord> allDays = [];

    // Separate regular attendance from substitute attendance
    final regularAttendance = attendance.where((a) => !a.isSubstitute).toList();
    final substituteAttendance = attendance.where((a) => a.isSubstitute).toList();

    // Add regular attendance records
    for (final a in regularAttendance) {
      allDays.add(_DayRecord(
        date: DateTime(a.checkIn.year, a.checkIn.month, a.checkIn.day),
        type: _DayType.attendance,
        attendance: a,
      ));
    }

    // Add substitute attendance records
    for (final a in substituteAttendance) {
      allDays.add(_DayRecord(
        date: DateTime(a.checkIn.year, a.checkIn.month, a.checkIn.day),
        type: _DayType.substitute,
        attendance: a,
      ));
    }

    // Add vacation days
    for (final d in dayOffs) {
      allDays.add(_DayRecord(
        date: DateTime(d.targetDate.year, d.targetDate.month, d.targetDate.day),
        type: _DayType.vacation,
        vacation: d,
      ));
    }

    // Sort by date (newest first)
    allDays.sort((a, b) => b.date.compareTo(a.date));

    // Calculate substitute hours (overtime)
    final substituteHours = substituteAttendance.fold<double>(0, (sum, a) => sum + (a.totalHours ?? 0));

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBoldFont,
        ),
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(employee, dateFormat, arabicBoldFont),
        footer: (context) => _buildPdfFooter(context, arabicFont),
        build: (context) {
          final List<pw.Widget> widgets = [];

          // Combined Days Section (Attendance + Vacations)
          if (allDays.isNotEmpty) {
            widgets.add(_buildPdfSection('سجل الأيام', arabicBoldFont));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(_buildCombinedDaysTable(allDays, dateFormat, timeFormat, arabicFont));
            widgets.add(pw.SizedBox(height: 20));
            widgets.add(_buildCombinedSummary(regularAttendance, dayOffs, substituteHours, arabicFont, arabicBoldFont));
            widgets.add(pw.SizedBox(height: 30));
          }

          // Tasks Section
          if (tasks.isNotEmpty) {
            widgets.add(_buildPdfSection('المهام المكتملة', arabicBoldFont));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(_buildTasksTable(tasks, dateFormat, arabicFont));
            widgets.add(pw.SizedBox(height: 30));
          }

          if (widgets.isEmpty) {
            widgets.add(
              pw.Center(
                child: pw.Text(
                  'لا توجد بيانات للفترة المحددة',
                  style: pw.TextStyle(font: arabicFont, fontSize: 14),
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildCombinedDaysTable(
    List<_DayRecord> days,
    intl.DateFormat dateFormat,
    intl.DateFormat timeFormat,
    pw.Font font,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('التاريخ', font),
            _buildTableHeader('النوع', font),
            _buildTableHeader('الدخول', font),
            _buildTableHeader('الخروج', font),
            _buildTableHeader('الساعات', font),
            _buildTableHeader('الحالة', font),
          ],
        ),
        ...days.map((day) {
          if (day.type == _DayType.vacation) {
            return pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.orange50),
              children: [
                _buildTableCell(dateFormat.format(day.date), font),
                _buildTableCell('إجازة', font, color: PdfColors.orange),
                _buildTableCell('--', font),
                _buildTableCell('--', font),
                _buildTableCell('--', font),
                _buildTableCell(day.vacation?.reason ?? 'إجازة معتمدة', font, color: PdfColors.orange),
              ],
            );
          } else if (day.type == _DayType.substitute) {
            // Substitute shift (overtime)
            final a = day.attendance!;
            final isJustOvertime = a.substituteForUserName == null ||
                                   a.substituteForUserName == 'أوفرتايم' ||
                                   a.substituteForUserName!.isEmpty;
            return pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _buildTableCell(dateFormat.format(day.date), font),
                _buildTableCell(isJustOvertime ? 'أوفرتايم' : 'بديل', font, color: PdfColors.green800),
                _buildTableCell(timeFormat.format(a.checkIn), font),
                _buildTableCell(a.checkOut != null ? timeFormat.format(a.checkOut!) : '--', font),
                _buildTableCell(a.totalHours?.toStringAsFixed(1) ?? '--', font),
                _buildTableCell(
                  isJustOvertime ? 'ساعات إضافية' : 'بديل عن ${a.substituteForUserName}',
                  font,
                  color: PdfColors.green800,
                ),
              ],
            );
          } else {
            // Regular attendance
            final a = day.attendance!;
            return pw.TableRow(
              children: [
                _buildTableCell(dateFormat.format(day.date), font),
                _buildTableCell('حضور', font, color: PdfColors.blue),
                _buildTableCell(timeFormat.format(a.checkIn), font),
                _buildTableCell(a.checkOut != null ? timeFormat.format(a.checkOut!) : '--', font),
                _buildTableCell(a.totalHours?.toStringAsFixed(1) ?? '--', font),
                _buildTableCell(a.isLate ? 'متأخر' : 'منتظم', font,
                    color: a.isLate ? PdfColors.red : PdfColors.green),
              ],
            );
          }
        }),
      ],
    );
  }

  pw.Widget _buildCombinedSummary(
    List<AttendanceModel> attendance,
    List<RequestModel> dayOffs,
    double substituteHours,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final totalAttendanceDays = attendance.length;
    final totalVacationDays = dayOffs.length;
    final lateDays = attendance.where((a) => a.isLate).length;
    final totalHours = attendance.fold<double>(0, (sum, a) => sum + (a.totalHours ?? 0));
    final totalLateMinutes = attendance.fold<int>(0, (sum, a) => sum + a.lateMinutes);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('أيام الحضور', '$totalAttendanceDays', font, boldFont),
              _buildSummaryItem('أيام الإجازة', '$totalVacationDays', font, boldFont, color: PdfColors.orange),
              _buildSummaryItem('أيام التأخير', '$lateDays', font, boldFont, color: PdfColors.red),
              _buildSummaryItem('إجمالي الساعات', totalHours.toStringAsFixed(1), font, boldFont),
              _buildSummaryItem('دقائق التأخير', '$totalLateMinutes', font, boldFont),
            ],
          ),
          if (substituteHours > 0) ...[
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _buildSummaryItem('ساعات أوفرتايم (بديل)', substituteHours.toStringAsFixed(1), font, boldFont, color: PdfColors.green800),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeader(UserModel employee, intl.DateFormat dateFormat, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'تقرير الموظف',
                  style: pw.TextStyle(font: boldFont, fontSize: 24),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  employee.name,
                  style: pw.TextStyle(font: boldFont, fontSize: 16, color: PdfColors.blue),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('الفترة:', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                pw.Text(
                  '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 5),
                pw.Text('تاريخ الإنشاء:', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                pw.Text(
                  dateFormat.format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blue),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey),
            ),
            pw.Text(
              'نظام إدارة المتاجر',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfSection(String title, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.blue900),
      ),
    );
  }

  pw.Widget _buildAttendanceTable(
    List<AttendanceModel> attendance,
    intl.DateFormat dateFormat,
    intl.DateFormat timeFormat,
    pw.Font font,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('التاريخ', font),
            _buildTableHeader('الدخول', font),
            _buildTableHeader('الخروج', font),
            _buildTableHeader('الساعات', font),
            _buildTableHeader('الحالة', font),
          ],
        ),
        ...attendance.map((a) => pw.TableRow(
          children: [
            _buildTableCell(dateFormat.format(a.checkIn), font),
            _buildTableCell(timeFormat.format(a.checkIn), font),
            _buildTableCell(a.checkOut != null ? timeFormat.format(a.checkOut!) : '--', font),
            _buildTableCell(a.totalHours?.toStringAsFixed(1) ?? '--', font),
            _buildTableCell(a.isLate ? 'متأخر' : 'منتظم', font,
                color: a.isLate ? PdfColors.red : PdfColors.green),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildAttendanceSummary(
    List<AttendanceModel> attendance,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final totalDays = attendance.length;
    final lateDays = attendance.where((a) => a.isLate).length;
    final totalHours = attendance.fold<double>(0, (sum, a) => sum + (a.totalHours ?? 0));
    final totalLateMinutes = attendance.fold<int>(0, (sum, a) => sum + a.lateMinutes);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('إجمالي الأيام', '$totalDays', font, boldFont),
          _buildSummaryItem('أيام التأخير', '$lateDays', font, boldFont),
          _buildSummaryItem('إجمالي الساعات', totalHours.toStringAsFixed(1), font, boldFont),
          _buildSummaryItem('دقائق التأخير', '$totalLateMinutes', font, boldFont),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value, pw.Font font, pw.Font boldFont, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 16, color: color ?? PdfColors.blue)),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildTasksTable(
    List<TaskModel> tasks,
    intl.DateFormat dateFormat,
    pw.Font font,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('المهمة', font),
            _buildTableHeader('الموعد النهائي', font),
            _buildTableHeader('الأولوية', font),
          ],
        ),
        ...tasks.map((t) => pw.TableRow(
          children: [
            _buildTableCell(t.title, font),
            _buildTableCell(dateFormat.format(t.deadline), font),
            _buildTableCell(t.priorityText, font),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildDayOffsTable(
    List<RequestModel> dayOffs,
    intl.DateFormat dateFormat,
    pw.Font font,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeader('التاريخ', font),
            _buildTableHeader('السبب', font),
          ],
        ),
        ...dayOffs.map((d) => pw.TableRow(
          children: [
            _buildTableCell(dateFormat.format(d.targetDate), font),
            _buildTableCell(d.reason, font),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9, color: color),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}

/// Enum for day record type
enum _DayType { attendance, vacation, substitute }

/// Helper class to hold a day record (either attendance, vacation, or substitute)
class _DayRecord {
  final DateTime date;
  final _DayType type;
  final AttendanceModel? attendance;
  final RequestModel? vacation;

  _DayRecord({
    required this.date,
    required this.type,
    this.attendance,
    this.vacation,
  });

  bool get isSubstitute => type == _DayType.substitute;
}
