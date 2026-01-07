import 'package:flutter/material.dart';
import '../../../core/models/attendance_model.dart';
import '../../../core/models/request_model.dart';
import '../../../core/theme/app_theme.dart';

/// Attendance status for a day
enum AttendanceDayStatus {
  regular,    // Green - On time attendance
  late,       // Orange - Late attendance
  earlyLeave, // Yellow - Early leave
  vacation,   // Blue - On vacation
  absent,     // Red - Absent (no attendance when expected)
  noData,     // Gray - No data or not a work day
}

class AttendanceCalendarWidget extends StatefulWidget {
  final List<AttendanceModel> attendanceRecords;
  final List<RequestModel> vacationRequests;
  final Function(DateTime)? onDaySelected;

  const AttendanceCalendarWidget({
    Key? key,
    required this.attendanceRecords,
    this.vacationRequests = const [],
    this.onDaySelected,
  }) : super(key: key);

  @override
  State<AttendanceCalendarWidget> createState() => _AttendanceCalendarWidgetState();
}

class _AttendanceCalendarWidgetState extends State<AttendanceCalendarWidget> {
  late DateTime _selectedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Month navigation
        _buildMonthHeader(),
        const SizedBox(height: 16),
        // Weekday headers
        _buildWeekdayHeaders(),
        const SizedBox(height: 8),
        // Calendar grid
        _buildCalendarGrid(),
        const SizedBox(height: 16),
        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildMonthHeader() {
    final monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
        Text(
          '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // Saturday is 6 in Dart (Sunday=0, Monday=1, ..., Saturday=6)
    // We want Saturday first, so shift by 1
    int startWeekday = (firstDayOfMonth.weekday % 7); // Sunday = 0

    // Calculate total cells needed (including empty cells for padding)
    final totalCells = startWeekday + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(totalRows, (rowIndex) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            final dayNumber = cellIndex - startWeekday + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 40));
            }

            final date = DateTime(
              _selectedMonth.year,
              _selectedMonth.month,
              dayNumber,
            );

            return Expanded(
              child: _buildDayCell(date, dayNumber),
            );
          }),
        );
      }),
    );
  }

  Widget _buildDayCell(DateTime date, int dayNumber) {
    final status = _getDayStatus(date);
    final isToday = _isToday(date);
    final isSelected = _selectedDay != null &&
        _selectedDay!.year == date.year &&
        _selectedDay!.month == date.month &&
        _selectedDay!.day == date.day;
    final isFuture = date.isAfter(DateTime.now());

    Color? backgroundColor;
    Color textColor = Colors.black87;

    if (isFuture) {
      backgroundColor = null;
      textColor = Colors.grey.shade400;
    } else {
      switch (status) {
        case AttendanceDayStatus.regular:
          backgroundColor = AppTheme.successColor.withOpacity(0.3);
          textColor = AppTheme.successColor;
          break;
        case AttendanceDayStatus.late:
          backgroundColor = Colors.orange.withOpacity(0.3);
          textColor = Colors.orange.shade800;
          break;
        case AttendanceDayStatus.earlyLeave:
          backgroundColor = Colors.amber.withOpacity(0.3);
          textColor = Colors.amber.shade800;
          break;
        case AttendanceDayStatus.vacation:
          backgroundColor = Colors.blue.withOpacity(0.3);
          textColor = Colors.blue.shade800;
          break;
        case AttendanceDayStatus.absent:
          backgroundColor = AppTheme.errorColor.withOpacity(0.3);
          textColor = AppTheme.errorColor;
          break;
        case AttendanceDayStatus.noData:
          backgroundColor = null;
          textColor = Colors.grey.shade600;
          break;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = date;
        });
        widget.onDaySelected?.call(date);
      },
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: AppTheme.primaryColor, width: 2)
              : isSelected
                  ? Border.all(color: AppTheme.secondaryColor, width: 2)
                  : null,
        ),
        child: Center(
          child: Text(
            '$dayNumber',
            style: TextStyle(
              color: textColor,
              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  AttendanceDayStatus _getDayStatus(DateTime date) {
    // Check if on vacation
    for (final vacation in widget.vacationRequests) {
      if (vacation.status == RequestStatus.approved &&
          vacation.type == RequestType.fullDayOff &&
          vacation.coversDate(date)) {
        return AttendanceDayStatus.vacation;
      }
    }

    // Find attendance record for this date
    final record = widget.attendanceRecords.where((r) {
      return r.checkIn.year == date.year &&
          r.checkIn.month == date.month &&
          r.checkIn.day == date.day;
    }).firstOrNull;

    if (record != null) {
      if (record.isLate && record.isEarlyLeave) {
        return AttendanceDayStatus.late; // Show late color for both
      } else if (record.isLate) {
        return AttendanceDayStatus.late;
      } else if (record.isEarlyLeave) {
        return AttendanceDayStatus.earlyLeave;
      } else {
        return AttendanceDayStatus.regular;
      }
    }

    return AttendanceDayStatus.noData;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildLegend() {
    final legends = [
      {'color': AppTheme.successColor, 'label': 'منتظم'},
      {'color': Colors.orange, 'label': 'متأخر'},
      {'color': Colors.amber, 'label': 'خروج مبكر'},
      {'color': Colors.blue, 'label': 'إجازة'},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: legends.map((legend) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: (legend['color'] as Color).withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              legend['label'] as String,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Extension to get first matching element or null
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    for (E element in this) {
      return element;
    }
    return null;
  }
}
