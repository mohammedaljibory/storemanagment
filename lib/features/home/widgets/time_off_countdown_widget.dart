import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/models/request_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/services/time_off_monitor_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

/// Widget that displays a countdown timer during active time-off
/// Shows remaining time and handles auto check-in when in range
class TimeOffCountdownWidget extends StatefulWidget {
  final RequestModel timeOff;
  final String userId;
  final String userName;
  final VoidCallback? onAutoCheckIn;

  const TimeOffCountdownWidget({
    Key? key,
    required this.timeOff,
    required this.userId,
    required this.userName,
    this.onAutoCheckIn,
  }) : super(key: key);

  @override
  State<TimeOffCountdownWidget> createState() => _TimeOffCountdownWidgetState();
}

class _TimeOffCountdownWidgetState extends State<TimeOffCountdownWidget> {
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  Duration _graceRemaining = Duration.zero;
  bool _isInRange = false;
  bool _isCheckingLocation = false;
  bool _timeOffEnded = false;
  bool _gracePeriodExceeded = false;
  double _currentDistance = 0;
  StoreModel? _store;
  bool _locationCheckStarted = false; // Track if we started location monitoring
  bool _autoCheckInAttempted = false; // Prevent multiple auto check-in attempts

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startCountdown();
    _loadStore(); // Only load store info, don't check location yet
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final expectedReturn = widget.timeOff.expectedReturnDateTime;
    if (expectedReturn == null) return;

    final now = DateTime.now();
    final graceMinutes = widget.timeOff.graceMinutes;
    final deadline = expectedReturn.add(Duration(minutes: graceMinutes));

    if (now.isBefore(expectedReturn)) {
      _remainingTime = expectedReturn.difference(now);
      _graceRemaining = Duration(minutes: graceMinutes);
      _timeOffEnded = false;
      _gracePeriodExceeded = false;
    } else if (now.isBefore(deadline)) {
      _remainingTime = Duration.zero;
      _graceRemaining = deadline.difference(now);
      _timeOffEnded = true;
      _gracePeriodExceeded = false;
    } else {
      _remainingTime = Duration.zero;
      _graceRemaining = Duration.zero;
      _timeOffEnded = true;
      _gracePeriodExceeded = true;
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _calculateRemainingTime();
      });

      // Only start checking location AFTER time-off ends (but not if grace exceeded)
      if (_timeOffEnded && !_locationCheckStarted && !_gracePeriodExceeded) {
        _locationCheckStarted = true;
        _checkCurrentLocation();
      }

      // Continue checking location every 15 seconds after time-off ends
      if (_timeOffEnded && _locationCheckStarted && !_gracePeriodExceeded && timer.tick % 15 == 0) {
        _checkCurrentLocation();
      }

      // If time-off ended and in range, try auto check-in (only once, and not if grace exceeded)
      if (_timeOffEnded && _isInRange && !_autoCheckInAttempted && !_gracePeriodExceeded) {
        _autoCheckInAttempted = true;
        _attemptAutoCheckIn();
      }
    });
  }

  Future<void> _loadStore() async {
    final storeProvider = context.read<StoreProvider>();
    _store = storeProvider.getStoreById(widget.timeOff.storeId);
    if (_store == null) {
      _store = await storeProvider.fetchStoreById(widget.timeOff.storeId);
    }
  }

  Future<void> _checkCurrentLocation() async {
    if (_isCheckingLocation || _store == null) return;

    setState(() => _isCheckingLocation = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final distance = _store!.getDistanceFrom(position.latitude, position.longitude);
      final inRange = _store!.isWithinRadius(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentDistance = distance;
          _isInRange = inRange;
          _isCheckingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingLocation = false);
      }
      print('⏰ Error checking location: $e');
    }
  }

  Future<void> _attemptAutoCheckIn() async {
    if (!_timeOffEnded || !_isInRange || _store == null) return;

    // Get shift for this employee
    final shiftProvider = context.read<ShiftProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    // Find the employee's shift
    final shifts = shiftProvider.getShiftsByStore(_store!.id);
    if (shifts.isEmpty) return;

    // Use the first available shift or employee's assigned shift
    final shift = shifts.first;

    try {
      // Mark as returned from time-off
      await TimeOffMonitorService.markAsReturned();

      // Auto check-in
      final success = await attendanceProvider.checkIn(
        userId: widget.userId,
        userName: widget.userName,
        store: _store!,
        shift: shift,
        skipTimeValidation: true, // Skip time validation for auto check-in after time-off
      );

      if (success && mounted) {
        widget.onAutoCheckIn?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل دخولك تلقائياً بعد انتهاء الزمنية ✅'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      print('⏰ Error during auto check-in: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _timeOffEnded
                ? [Colors.orange.withOpacity(0.2), Colors.red.withOpacity(0.2)]
                : [AppTheme.primaryColor.withOpacity(0.15), AppTheme.secondaryColor.withOpacity(0.15)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _timeOffEnded
                          ? [Colors.orange, Colors.red]
                          : [AppTheme.primaryColor, AppTheme.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (_timeOffEnded ? Colors.orange : AppTheme.primaryColor).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _timeOffEnded ? Icons.warning_amber_rounded : Icons.timer,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _gracePeriodExceeded
                            ? '⛔ تم حظر الدخول'
                            : (_timeOffEnded ? 'انتهت الزمنية!' : 'زمنية نشطة'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _gracePeriodExceeded
                              ? Colors.red
                              : (_timeOffEnded ? Colors.orange : AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.timeOff.startTime} - ${widget.timeOff.expectedReturnTime}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Countdown Timer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _gracePeriodExceeded
                      ? Colors.red.withOpacity(0.5)
                      : (_timeOffEnded ? Colors.orange.withOpacity(0.5) : AppTheme.primaryColor.withOpacity(0.3)),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _gracePeriodExceeded
                        ? 'تم تجاوز فترة السماح'
                        : (_timeOffEnded ? 'فترة السماح المتبقية' : 'الوقت المتبقي'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _gracePeriodExceeded ? Colors.red : (isDarkMode ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _gracePeriodExceeded
                        ? '00:00'
                        : (_timeOffEnded ? _formatDuration(_graceRemaining) : _formatDuration(_remainingTime)),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: _gracePeriodExceeded ? Colors.red : (_timeOffEnded ? Colors.orange : null),
                      letterSpacing: 4,
                    ),
                  ),
                  if (_gracePeriodExceeded) ...[
                    const SizedBox(height: 8),
                    Text(
                      'لا يمكنك الدخول مجدداً اليوم',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else if (_timeOffEnded) ...[
                    const SizedBox(height: 8),
                    Text(
                      'سارع بالعودة للمتجر!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Location Status - Only show after time-off ends
            if (_timeOffEnded) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isInRange ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isInRange ? Colors.green : Colors.red).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isCheckingLocation)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _isInRange ? Icons.location_on : Icons.location_off,
                        color: _isInRange ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isInRange
                            ? 'أنت داخل نطاق المتجر ✓'
                            : 'خارج النطاق (${_currentDistance.toStringAsFixed(0)}م)',
                        style: TextStyle(
                          color: _isInRange ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Auto check-in hint
            if (_timeOffEnded && _isInRange) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'جارٍ تسجيل دخولك تلقائياً...',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_timeOffEnded && !_isInRange) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'توجه للمتجر للتسجيل تلقائياً',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
