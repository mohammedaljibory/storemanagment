/**
 * Firebase Cloud Functions for Store Management App
 *
 * These functions run on the server and monitor:
 * 1. Shift end times - auto checkout employees who forget
 * 2. Time-off grace periods - block employees who don't return
 * 3. Break overtime - notify admin of extended breaks
 *
 * Runs independently of the app - works even when app is closed
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============ CONFIGURATION ============
const CONFIG = {
  SHIFT_END_GRACE_MINUTES: 30,      // Minutes after shift end before auto checkout
  TIME_OFF_GRACE_MINUTES: 15,        // Minutes after time-off ends before blocking
  BREAK_MAX_MINUTES: 60,             // Maximum allowed break time
  CHECK_INTERVAL_MINUTES: 5,         // How often to run checks
};

// ============ SCHEDULED FUNCTIONS ============

/**
 * Check for employees who need auto checkout after shift ends
 * Runs every 5 minutes
 */
exports.checkShiftEndAutoCheckout = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    console.log('🕐 Running shift end auto checkout check...');

    const now = new Date();
    let autoCheckedOut = 0;

    try {
      // Get all active attendance records (not checked out)
      const activeAttendance = await db.collection('attendance')
        .where('isCheckedOut', '==', false)
        .get();

      for (const doc of activeAttendance.docs) {
        const data = doc.data();

        // Skip if already checked out or no expected end time
        if (data.checkOut || !data.expectedEndTime) continue;

        // Parse check-in time
        let checkIn;
        if (data.checkIn && data.checkIn.toDate) {
          checkIn = data.checkIn.toDate();
        } else if (data.checkIn) {
          checkIn = new Date(data.checkIn);
        }
        if (!checkIn) continue;

        // Parse expected end time (format: "HH:mm")
        const [endHour, endMinute] = data.expectedEndTime.split(':').map(Number);
        let expectedEnd = new Date(
          checkIn.getFullYear(),
          checkIn.getMonth(),
          checkIn.getDate(),
          endHour,
          endMinute
        );

        // Handle overnight shifts
        if (expectedEnd < checkIn) {
          expectedEnd.setDate(expectedEnd.getDate() + 1);
        }

        // Calculate deadline with grace period
        const deadline = new Date(expectedEnd.getTime() + CONFIG.SHIFT_END_GRACE_MINUTES * 60000);

        // Check if deadline has passed
        if (now > deadline) {
          await autoCheckoutEmployee(doc, data, checkIn, expectedEnd, now);
          autoCheckedOut++;
        }
      }

      console.log(`✅ Auto checkout complete: ${autoCheckedOut} employees`);
      return null;
    } catch (error) {
      console.error('❌ Error in shift end check:', error);
      return null;
    }
  });

/**
 * Check for employees who exceeded time-off grace period
 * Runs every minute for more precise timing
 */
exports.checkTimeOffGracePeriod = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    console.log('⏰ Running time-off grace period check...');

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);

    try {
      // Get active time-off requests for today
      const timeOffRequests = await db.collection('requests')
        .where('type', '==', 'timeOff')
        .where('status', '==', 'approved')
        .where('timeOffReturnStatus', '==', 'active')
        .get();

      for (const doc of timeOffRequests.docs) {
        const data = doc.data();

        // Parse target date
        let targetDate;
        if (data.targetDate && data.targetDate.toDate) {
          targetDate = data.targetDate.toDate();
        } else if (data.targetDate) {
          targetDate = new Date(data.targetDate);
        }

        // Check if this is today's request
        if (!targetDate || targetDate < todayStart || targetDate >= todayEnd) continue;

        // Parse expected return time
        if (!data.expectedReturnTime) continue;
        const [returnHour, returnMinute] = data.expectedReturnTime.split(':').map(Number);

        const expectedReturn = new Date(
          targetDate.getFullYear(),
          targetDate.getMonth(),
          targetDate.getDate(),
          returnHour,
          returnMinute
        );

        // Calculate deadline with grace period
        const graceMinutes = data.graceMinutes || CONFIG.TIME_OFF_GRACE_MINUTES;
        const deadline = new Date(expectedReturn.getTime() + graceMinutes * 60000);

        // Check if deadline has passed
        if (now > deadline) {
          await blockEmployeeForTimeOff(doc, data, expectedReturn, now);
        }
      }

      return null;
    } catch (error) {
      console.error('❌ Error in time-off check:', error);
      return null;
    }
  });

/**
 * Check for employees with extended breaks
 * Runs every 5 minutes
 */
exports.checkBreakOvertime = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    console.log('☕ Running break overtime check...');

    const now = new Date();

    try {
      // Get active breaks
      const activeBreaks = await db.collection('attendance')
        .where('isOnBreak', '==', true)
        .get();

      for (const doc of activeBreaks.docs) {
        const data = doc.data();

        if (!data.breakStartTime) continue;

        // Parse break start time
        let breakStart;
        if (data.breakStartTime.toDate) {
          breakStart = data.breakStartTime.toDate();
        } else {
          breakStart = new Date(data.breakStartTime);
        }

        const breakMinutes = Math.floor((now - breakStart) / 60000);

        // Check if break exceeded maximum allowed time
        if (breakMinutes > CONFIG.BREAK_MAX_MINUTES) {
          const overtimeMinutes = breakMinutes - CONFIG.BREAK_MAX_MINUTES;
          await notifyAdminBreakOvertime(data, overtimeMinutes);
        }
      }

      return null;
    } catch (error) {
      console.error('❌ Error in break check:', error);
      return null;
    }
  });

// ============ HELPER FUNCTIONS ============

/**
 * Auto checkout an employee
 */
async function autoCheckoutEmployee(doc, data, checkIn, expectedEnd, now) {
  try {
    // Calculate total hours
    let totalHours = (now - checkIn) / (1000 * 60 * 60);

    // Subtract break time
    const breakMinutes = data.totalBreakMinutes || 0;
    totalHours -= breakMinutes / 60;
    if (totalHours < 0) totalHours = 0;

    // Calculate late minutes
    const lateMinutes = Math.floor((now - expectedEnd) / 60000);

    // Update attendance record
    await doc.ref.update({
      checkOut: now.toISOString(),
      totalHours: totalHours,
      isCheckedOut: true,
      isEarlyLeave: false,
      autoCheckout: true,
      autoCheckoutReason: `تسجيل خروج تلقائي من السيرفر - تجاوز وقت الشفت بـ ${lateMinutes} دقيقة`,
      autoCheckoutSource: 'cloud_function',
    });

    console.log(`📤 Auto checkout: ${data.userName} from ${data.storeName}`);

    // Send notification to employee
    await sendNotificationToUser(data.userId, {
      title: 'تم تسجيل خروجك تلقائياً',
      body: `تم تسجيل خروجك من ${data.storeName} بعد انتهاء وقت الشفت\nإجمالي الساعات: ${totalHours.toFixed(1)}`,
    });

    // Notify admin
    await db.collection('notifications').add({
      type: 'auto_checkout_shift_end',
      title: 'تسجيل خروج تلقائي - انتهاء الشفت',
      body: `${data.userName} تم تسجيل خروجه تلقائياً من ${data.storeName}\nتأخر ${lateMinutes} دقيقة عن تسجيل الخروج`,
      userId: data.userId,
      userName: data.userName,
      storeId: data.storeId,
      storeName: data.storeName,
      totalHours: totalHours,
      lateCheckoutMinutes: lateMinutes,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      forAdmin: true,
      source: 'cloud_function',
    });

  } catch (error) {
    console.error(`❌ Error auto checkout ${data.userName}:`, error);
  }
}

/**
 * Block employee who exceeded time-off grace period
 */
async function blockEmployeeForTimeOff(doc, data, expectedReturn, now) {
  try {
    // Update time-off status to blocked
    await doc.ref.update({
      timeOffReturnStatus: 'blocked',
      blockedAt: now.toISOString(),
      blockedBy: 'cloud_function',
    });

    console.log(`⛔ Blocked: ${data.employeeName} - exceeded time-off grace period`);

    // Find and auto checkout active attendance
    const attendanceSnapshot = await db.collection('attendance')
      .where('userId', '==', data.employeeId)
      .where('isCheckedOut', '==', false)
      .get();

    for (const attendanceDoc of attendanceSnapshot.docs) {
      const attendanceData = attendanceDoc.data();

      // Parse check-in time
      let checkIn;
      if (attendanceData.checkIn && attendanceData.checkIn.toDate) {
        checkIn = attendanceData.checkIn.toDate();
      } else if (attendanceData.checkIn) {
        checkIn = new Date(attendanceData.checkIn);
      }

      if (checkIn) {
        const totalHours = (now - checkIn) / (1000 * 60 * 60);
        const breakMinutes = attendanceData.totalBreakMinutes || 0;
        const adjustedHours = Math.max(0, totalHours - breakMinutes / 60);

        await attendanceDoc.ref.update({
          checkOut: now.toISOString(),
          totalHours: adjustedHours,
          totalTimeOffMinutes: data.durationMinutes || 0,
          isCheckedOut: true,
          isEarlyLeave: true,
          autoCheckout: true,
          autoCheckoutReason: 'تسجيل خروج تلقائي - تجاوز فترة السماح للزمنية',
          autoCheckoutSource: 'cloud_function',
        });

        console.log(`📤 Auto checkout for blocked employee: ${data.employeeName}`);
      }
    }

    // Send notification to employee
    await sendNotificationToUser(data.employeeId, {
      title: '⛔ تم تسجيل خروجك تلقائياً',
      body: 'تأخرت عن العودة من الزمنية أكثر من 15 دقيقة.\nلا يمكنك الدخول مجدداً اليوم.',
    });

    // Notify admin
    await db.collection('notifications').add({
      type: 'time_off_blocked',
      title: '⛔ تسجيل خروج تلقائي - تجاوز زمنية',
      body: `${data.employeeName} تجاوز فترة السماح ولم يعد من الزمنية.\nتم تسجيل خروجه تلقائياً وحظر دخوله لبقية اليوم.`,
      employeeId: data.employeeId,
      employeeName: data.employeeName,
      storeId: data.storeId,
      storeName: data.storeName,
      requestId: doc.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      forAdmin: true,
      source: 'cloud_function',
    });

  } catch (error) {
    console.error(`❌ Error blocking employee ${data.employeeName}:`, error);
  }
}

/**
 * Notify admin about break overtime
 */
async function notifyAdminBreakOvertime(data, overtimeMinutes) {
  try {
    // Check if we already notified recently (prevent spam)
    const recentNotifications = await db.collection('notifications')
      .where('type', '==', 'break_overtime_server')
      .where('userId', '==', data.userId)
      .where('createdAt', '>', new Date(Date.now() - 10 * 60000)) // Last 10 minutes
      .get();

    if (!recentNotifications.empty) {
      return; // Already notified recently
    }

    await db.collection('notifications').add({
      type: 'break_overtime_server',
      title: 'تجاوز وقت الاستراحة',
      body: `${data.userName} تجاوز وقت الاستراحة بـ ${overtimeMinutes} دقيقة`,
      userId: data.userId,
      userName: data.userName,
      attendanceId: data.id,
      overtimeMinutes: overtimeMinutes,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      forAdmin: true,
      source: 'cloud_function',
    });

    console.log(`☕ Break overtime notification: ${data.userName} - ${overtimeMinutes} minutes`);

  } catch (error) {
    console.error('❌ Error notifying break overtime:', error);
  }
}

/**
 * Send push notification to a specific user
 */
async function sendNotificationToUser(userId, notification) {
  try {
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`📱 No FCM token for user ${userId}`);
      return;
    }

    await messaging.send({
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    console.log(`📱 Push notification sent to ${userId}`);

  } catch (error) {
    console.error(`❌ Error sending push notification to ${userId}:`, error);
  }
}

// ============ HTTP TRIGGERS (FOR TESTING) ============

/**
 * Manual trigger for testing shift end check
 */
exports.manualShiftEndCheck = functions.https.onRequest(async (req, res) => {
  console.log('🔧 Manual shift end check triggered');

  // Run the check
  const result = await exports.checkShiftEndAutoCheckout.run();

  res.json({ success: true, message: 'Shift end check completed' });
});

/**
 * Manual trigger for testing time-off check
 */
exports.manualTimeOffCheck = functions.https.onRequest(async (req, res) => {
  console.log('🔧 Manual time-off check triggered');

  // Run the check
  const result = await exports.checkTimeOffGracePeriod.run();

  res.json({ success: true, message: 'Time-off check completed' });
});

/**
 * Get monitoring status
 */
exports.getMonitoringStatus = functions.https.onRequest(async (req, res) => {
  try {
    const now = new Date();

    // Count active attendance
    const activeAttendance = await db.collection('attendance')
      .where('isCheckedOut', '==', false)
      .get();

    // Count active time-offs
    const activeTimeOffs = await db.collection('requests')
      .where('type', '==', 'timeOff')
      .where('status', '==', 'approved')
      .where('timeOffReturnStatus', '==', 'active')
      .get();

    // Count active breaks
    const activeBreaks = await db.collection('attendance')
      .where('isOnBreak', '==', true)
      .get();

    res.json({
      success: true,
      timestamp: now.toISOString(),
      stats: {
        activeAttendance: activeAttendance.size,
        activeTimeOffs: activeTimeOffs.size,
        activeBreaks: activeBreaks.size,
      },
      config: CONFIG,
    });

  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});
