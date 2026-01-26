/**
 * Firebase Cloud Functions for Store Management App
 * Sends push notifications via FCM when certain events occur
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================
// TASK NOTIFICATIONS
// ============================================

/**
 * Send push notification when a new task is created
 * Triggers when a document is added to the 'tasks' collection
 */
exports.onTaskCreated = functions.firestore
    .document("tasks/{taskId}")
    .onCreate(async (snapshot, context) => {
      const task = snapshot.data();
      const taskId = context.params.taskId;

      console.log(`New task created: ${taskId}`, task);

      // Get assigned employees - check both assignedToList (array) and assignedTo (string)
      let assignedEmployees = task.assignedToList || [];

      // If assignedToList is empty, try assignedTo (might be single user ID)
      if (assignedEmployees.length === 0 && task.assignedTo) {
        assignedEmployees = [task.assignedTo];
      }

      if (assignedEmployees.length === 0) {
        console.log("No employees assigned to task");
        return null;
      }

      console.log("Assigned employees:", assignedEmployees);

      // Get FCM tokens for all assigned employees
      const tokens = await getTokensForUsers(assignedEmployees);
      if (tokens.length === 0) {
        console.log("No FCM tokens found for assigned employees");
        return null;
      }

      // Build notification message
      const message = {
        notification: {
          title: "مهمة جديدة",
          body: `تم تعيين مهمة "${task.title}" لك`,
        },
        data: {
          type: "task",
          taskId: taskId,
          action: "new_task",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "task_channel",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens: tokens,
      };

      return sendMulticastNotification(message, "onTaskCreated");
    });

/**
 * Send push notification when task status changes
 * Notifies admin when task is waiting approval
 * Notifies employee when task is approved/rejected
 */
exports.onTaskUpdated = functions.firestore
    .document("tasks/{taskId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      const taskId = context.params.taskId;

      // Check if status changed
      if (before.status === after.status) {
        return null;
      }

      console.log(`Task status changed: ${before.status} -> ${after.status}`);

      // Task waiting approval -> notify admins
      if (after.status === "waitingApproval" || after.status === "waiting_approval") {
        return notifyAdminsTaskWaitingApproval(taskId, after);
      }

      // Task approved -> notify assigned employees
      if (after.status === "completed" && (before.status === "waitingApproval" || before.status === "waiting_approval")) {
        return notifyEmployeesTaskApproved(taskId, after);
      }

      // Task rejected -> notify assigned employees
      if (after.status === "rejected") {
        return notifyEmployeesTaskRejected(taskId, after);
      }

      return null;
    });

/**
 * Notify admins when task is waiting for approval
 */
async function notifyAdminsTaskWaitingApproval(taskId, task) {
  const adminTokens = await getAdminTokens();
  if (adminTokens.length === 0) {
    console.log("No admin tokens found");
    return null;
  }

  const message = {
    notification: {
      title: "مهمة تنتظر الموافقة",
      body: `الموظف أنجز مهمة "${task.title}" وتنتظر موافقتك`,
    },
    data: {
      type: "task",
      taskId: taskId,
      action: "waiting_approval",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "task_channel",
        priority: "high",
      },
    },
    tokens: adminTokens,
  };

  return sendMulticastNotification(message, "notifyAdminsTaskWaitingApproval");
}

/**
 * Notify employees when task is approved
 */
async function notifyEmployeesTaskApproved(taskId, task) {
  // Notify the employee who completed the task
  const completedBy = task.completedBy;
  if (!completedBy) {
    console.log("No completedBy field, skipping notification");
    return null;
  }

  const tokens = await getTokensForUsers([completedBy]);
  if (tokens.length === 0) {
    console.log("No tokens found for employee who completed task");
    return null;
  }

  const message = {
    notification: {
      title: "تمت الموافقة على المهمة",
      body: `تمت الموافقة على مهمة "${task.title}"`,
    },
    data: {
      type: "task",
      taskId: taskId,
      action: "approved",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "task_channel",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    tokens: tokens,
  };

  return sendMulticastNotification(message, "notifyEmployeesTaskApproved");
}

/**
 * Notify employees when task is rejected
 */
async function notifyEmployeesTaskRejected(taskId, task) {
  // Notify the employee who completed the task
  const completedBy = task.completedBy;
  if (!completedBy) {
    console.log("No completedBy field, skipping notification");
    return null;
  }

  const tokens = await getTokensForUsers([completedBy]);
  if (tokens.length === 0) {
    console.log("No tokens found for employee who completed task");
    return null;
  }

  const rejectionReason = task.rejectionReason || "لم يتم تحديد السبب";

  const message = {
    notification: {
      title: "تم رفض المهمة",
      body: `تم رفض مهمة "${task.title}"\nالسبب: ${rejectionReason}`,
    },
    data: {
      type: "task",
      taskId: taskId,
      action: "rejected",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "task_channel",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    tokens: tokens,
  };

  return sendMulticastNotification(message, "notifyEmployeesTaskRejected");
}

// ============================================
// REQUEST NOTIFICATIONS
// ============================================

/**
 * Notify admins when new request is created
 */
exports.onRequestCreated = functions.firestore
    .document("requests/{requestId}")
    .onCreate(async (snapshot, context) => {
      const request = snapshot.data();
      const requestId = context.params.requestId;

      console.log(`New request created: ${requestId}`, request);

      const adminTokens = await getAdminTokens();
      if (adminTokens.length === 0) {
        console.log("No admin tokens found");
        return null;
      }

      const requestTypeArabic = getRequestTypeArabic(request.type);

      const message = {
        notification: {
          title: "طلب جديد",
          body: `${request.employeeName || "موظف"} قدم ${requestTypeArabic}`,
        },
        data: {
          type: "request",
          requestId: requestId,
          action: "new_request",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "request_channel",
            priority: "high",
          },
        },
        tokens: adminTokens,
      };

      return sendMulticastNotification(message, "onRequestCreated");
    });

/**
 * Notify employee when request status changes
 */
exports.onRequestUpdated = functions.firestore
    .document("requests/{requestId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();
      const requestId = context.params.requestId;

      // Check if status changed
      if (before.status === after.status) {
        return null;
      }

      console.log(`Request status changed: ${before.status} -> ${after.status}`);

      const employeeId = after.employeeId;
      if (!employeeId) {
        console.log("No employee ID in request");
        return null;
      }

      const tokens = await getTokensForUsers([employeeId]);
      if (tokens.length === 0) {
        console.log("No tokens found for employee");
        return null;
      }

      const requestTypeArabic = getRequestTypeArabic(after.type);

      let title;
      let body;

      if (after.status === "approved") {
        title = "تمت الموافقة على طلبك";
        body = `تمت الموافقة على ${requestTypeArabic}`;
      } else if (after.status === "rejected") {
        title = "تم رفض طلبك";
        const reason = after.adminNote || "لم يتم تحديد السبب";
        body = `تم رفض ${requestTypeArabic}\nالسبب: ${reason}`;
      } else {
        return null;
      }

      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: "request",
          requestId: requestId,
          action: after.status,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "request_channel",
            priority: "high",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens: tokens,
      };

      return sendMulticastNotification(message, "onRequestUpdated");
    });

// ============================================
// ATTENDANCE NOTIFICATIONS
// ============================================

/**
 * Notify admin when employee is late
 */
exports.onAttendanceCreated = functions.firestore
    .document("attendance/{attendanceId}")
    .onCreate(async (snapshot, context) => {
      const attendance = snapshot.data();

      // Only notify if employee is late
      if (!attendance.isLate || attendance.penaltyMinutes <= 0) {
        return null;
      }

      console.log(`Late attendance detected: ${attendance.employeeName}`);

      const adminTokens = await getAdminTokens();
      if (adminTokens.length === 0) {
        return null;
      }

      const message = {
        notification: {
          title: "تأخير في الحضور",
          body: `${attendance.employeeName || "موظف"} متأخر ${attendance.penaltyMinutes} دقيقة`,
        },
        data: {
          type: "attendance",
          action: "late_arrival",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "attendance_channel",
            priority: "default",
          },
        },
        tokens: adminTokens,
      };

      return sendMulticastNotification(message, "onAttendanceCreated");
    });

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Get FCM tokens for specific user IDs
 */
async function getTokensForUsers(userIds) {
  if (!userIds || userIds.length === 0) return [];

  const tokens = [];

  for (const userId of userIds) {
    try {
      const userDoc = await db.collection("users").doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        const userTokens = userData.fcmTokens || [];
        tokens.push(...userTokens);
      }
    } catch (error) {
      console.error(`Error getting tokens for user ${userId}:`, error);
    }
  }

  // Remove duplicates
  return [...new Set(tokens)];
}

/**
 * Get FCM tokens for all admin users
 */
async function getAdminTokens() {
  try {
    const adminsSnapshot = await db
        .collection("users")
        .where("role", "==", "admin")
        .get();

    const tokens = [];
    adminsSnapshot.forEach((doc) => {
      const userData = doc.data();
      const userTokens = userData.fcmTokens || [];
      tokens.push(...userTokens);
    });

    return [...new Set(tokens)];
  } catch (error) {
    console.error("Error getting admin tokens:", error);
    return [];
  }
}

/**
 * Send multicast notification and handle invalid tokens
 */
async function sendMulticastNotification(message, functionName) {
  try {
    const response = await messaging.sendEachForMulticast(message);

    console.log(
        `${functionName}: ${response.successCount} successful, ${response.failureCount} failed`,
    );

    // Handle failed tokens (remove invalid ones)
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          const errorMessage = resp.error?.message;
          // Log the actual error for debugging
          console.error(`Token ${idx} failed: ${errorCode} - ${errorMessage}`);

          // Remove invalid or unregistered tokens
          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            failedTokens.push(message.tokens[idx]);
          }
        }
      });

      if (failedTokens.length > 0) {
        console.log(`Removing ${failedTokens.length} invalid tokens`);
        await removeInvalidTokens(failedTokens);
      }
    }

    return response;
  } catch (error) {
    console.error(`${functionName} error:`, error);
    return null;
  }
}

/**
 * Remove invalid tokens from users
 */
async function removeInvalidTokens(tokens) {
  // Find and update users with these tokens
  const usersSnapshot = await db.collection("users").get();

  const batch = db.batch();
  let batchCount = 0;

  usersSnapshot.forEach((doc) => {
    const userData = doc.data();
    const userTokens = userData.fcmTokens || [];

    const tokensToRemove = userTokens.filter((t) => tokens.includes(t));
    if (tokensToRemove.length > 0) {
      batch.update(doc.ref, {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
      });
      batchCount++;
    }
  });

  if (batchCount > 0) {
    await batch.commit();
    console.log(`Removed invalid tokens from ${batchCount} users`);
  }
}

/**
 * Get Arabic translation for request type
 */
function getRequestTypeArabic(type) {
  const types = {
    time_off: "طلب إجازة زمنية",
    day_off: "طلب إجازة يوم كامل",
    shift_change: "طلب تغيير شفت",
    temporary_shift: "طلب شفت مؤقت",
  };
  return types[type] || "طلب";
}

// ============================================
// NOTIFICATIONS COLLECTION LISTENER
// ============================================

/**
 * Listen to notifications collection and send push notifications
 * This handles: check-in, check-out, location alerts, etc.
 */
exports.onNotificationCreated = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snapshot, context) => {
      const notification = snapshot.data();
      const notificationId = context.params.notificationId;

      console.log(`New notification created: ${notificationId}`, notification);

      // Skip push if another Cloud Function already handles it
      // (e.g., onRequestCreated, onRequestUpdated, onTaskUpdated)
      if (notification.skipPush === true) {
        console.log("skipPush=true, notification doc created for history only, skipping push");
        return null;
      }

      let tokens = [];

      // Determine target: admin or specific employee
      if (notification.forAdmin) {
        // Get admin tokens
        tokens = await getAdminTokens();
        if (tokens.length === 0) {
          console.log("No admin tokens found");
          return null;
        }
      } else if (notification.forEmployee && notification.targetUserId) {
        // Get specific employee tokens
        tokens = await getTokensForUsers([notification.targetUserId]);
        if (tokens.length === 0) {
          console.log("No tokens found for employee: " + notification.targetUserId);
          return null;
        }
      } else {
        console.log("No target specified (forAdmin or forEmployee), skipping");
        return null;
      }

      // Determine channel based on notification type
      let channelId = "store_channel";
      const type = notification.type || "";

      if (type.includes("checkin") || type.includes("checkout") || type === "employee_checkin" || type === "employee_checkout") {
        channelId = "attendance_channel";
      } else if (type.includes("location") || type === "location_alert") {
        channelId = "location_alert";
      } else if (type.includes("request")) {
        channelId = "request_channel";
      } else if (type.includes("task")) {
        channelId = "task_channel";
      } else if (type === "break_overtime") {
        channelId = "break_channel";
      }

      const message = {
        notification: {
          title: notification.title || "إشعار جديد",
          body: notification.body || "",
        },
        data: {
          type: type,
          notificationId: notificationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: channelId,
            priority: type === "location_alert" ? "max" : "high",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens: tokens,
      };

      return sendMulticastNotification(message, "onNotificationCreated");
    });

// ============================================
// SHIFT END MONITORING (Scheduled Function)
// ============================================

/**
 * Check for employees who haven't logged out after shift end
 * Runs every 5 minutes
 * - At shift end: notify employee to logout
 * - 30 min after shift end: notify admin and auto-logout
 */
exports.checkShiftEndAttendance = functions.pubsub
    .schedule("every 5 minutes")
    .timeZone("Asia/Baghdad")
    .onRun(async (context) => {
      console.log("Running shift end check...");

      const now = new Date();
      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();

      // Get all active attendance (checkOut is null)
      const activeAttendanceSnapshot = await db
          .collection("attendance")
          .where("checkOut", "==", null)
          .get();

      if (activeAttendanceSnapshot.empty) {
        console.log("No active attendance records found");
        return null;
      }

      console.log(`Found ${activeAttendanceSnapshot.size} active attendance records`);

      const batch = db.batch();
      let batchCount = 0;

      for (const doc of activeAttendanceSnapshot.docs) {
        const attendance = doc.data();
        const attendanceId = doc.id;

        // Parse expected end time (e.g., "14:00" or "01:00")
        const expectedEndTime = attendance.expectedEndTime;
        if (!expectedEndTime) {
          console.log(`No expectedEndTime for attendance ${attendanceId}`);
          continue;
        }

        const [endHour, endMinute] = expectedEndTime.split(":").map(Number);

        // Get check-in time to determine if overnight shift
        const checkIn = attendance.checkIn ? new Date(attendance.checkIn) : null;
        if (!checkIn) continue;

        // Calculate expected end DateTime
        let expectedEndDateTime = new Date(checkIn);
        expectedEndDateTime.setHours(endHour, endMinute, 0, 0);

        // If end hour is less than check-in hour, it's overnight - add a day
        if (endHour < checkIn.getHours() || (endHour <= 6 && checkIn.getHours() >= 12)) {
          expectedEndDateTime.setDate(expectedEndDateTime.getDate() + 1);
        }

        // Calculate time difference in minutes
        const minutesSinceShiftEnd = Math.floor((now - expectedEndDateTime) / (1000 * 60));

        console.log(`Attendance ${attendanceId}: shiftEnd=${expectedEndTime}, minutesSince=${minutesSinceShiftEnd}, notified=${attendance.shiftEndNotified}, adminNotified=${attendance.adminNotifiedLateCheckout}`);

        // Shift hasn't ended yet
        if (minutesSinceShiftEnd < 0) {
          continue;
        }

        // Shift ended - check if we need to notify
        if (minutesSinceShiftEnd >= 0 && minutesSinceShiftEnd < 30 && !attendance.shiftEndNotified) {
          // Send notification to employee to logout
          console.log(`Notifying employee ${attendance.userId} to logout`);
          await notifyEmployeeShiftEnded(attendance, attendanceId);

          // Mark as notified
          batch.update(doc.ref, {shiftEndNotified: true, shiftEndNotifiedAt: now.toISOString()});
          batchCount++;
        }

        // 30+ minutes after shift end - notify admin and force logout
        if (minutesSinceShiftEnd >= 30 && !attendance.adminNotifiedLateCheckout) {
          console.log(`30+ min late checkout for ${attendance.userName}, notifying admin and auto-checkout`);

          // Notify admin
          await notifyAdminLateCheckout(attendance, attendanceId, minutesSinceShiftEnd);

          // Force checkout
          const checkOutTime = now.toISOString();
          const checkInTime = new Date(attendance.checkIn);
          const totalHours = (now - checkInTime) / (1000 * 60 * 60);

          batch.update(doc.ref, {
            checkOut: checkOutTime,
            checkOutLocation: attendance.checkInLocation, // Use same location
            totalHours: Math.round(totalHours * 100) / 100,
            adminNotifiedLateCheckout: true,
            autoCheckout: true,
            autoCheckoutReason: "تجاوز 30 دقيقة بعد انتهاء الشفت",
            notes: (attendance.notes || "") + " [خروج تلقائي]",
          });
          batchCount++;

          // Notify employee about auto-checkout
          await notifyEmployeeAutoCheckout(attendance, attendanceId);
        }
      }

      if (batchCount > 0) {
        await batch.commit();
        console.log(`Updated ${batchCount} attendance records`);
      }

      return null;
    });

/**
 * Notify employee that their shift has ended
 */
async function notifyEmployeeShiftEnded(attendance, attendanceId) {
  const tokens = await getTokensForUsers([attendance.userId]);
  if (tokens.length === 0) {
    console.log("No tokens for employee shift end notification");
    return;
  }

  const message = {
    notification: {
      title: "انتهى وقت الشفت",
      body: `يرجى تسجيل الخروج الآن. سيتم تسجيل الخروج تلقائياً بعد 30 دقيقة`,
    },
    data: {
      type: "shift_end_reminder",
      attendanceId: attendanceId,
      action: "checkout_reminder",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "attendance_channel",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    tokens: tokens,
  };

  await sendMulticastNotification(message, "notifyEmployeeShiftEnded");

  // Also create notification document for history
  await db.collection("notifications").add({
    title: "انتهى وقت الشفت",
    body: "يرجى تسجيل الخروج الآن. سيتم تسجيل الخروج تلقائياً بعد 30 دقيقة",
    type: "shift_end_reminder",
    forEmployee: true,
    targetUserId: attendance.userId,
    createdAt: new Date().toISOString(),
    read: false,
    skipPush: true, // Already sent push above
  });
}

/**
 * Notify admin about late checkout
 */
async function notifyAdminLateCheckout(attendance, attendanceId, minutesLate) {
  const adminTokens = await getAdminTokens();
  if (adminTokens.length === 0) {
    console.log("No admin tokens for late checkout notification");
    return;
  }

  const message = {
    notification: {
      title: "موظف لم يسجل خروج",
      body: `${attendance.userName} لم يسجل خروج منذ ${minutesLate} دقيقة بعد انتهاء الشفت - سيتم تسجيل الخروج تلقائياً`,
    },
    data: {
      type: "late_checkout_admin",
      attendanceId: attendanceId,
      employeeId: attendance.userId,
      action: "late_checkout",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "attendance_channel",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    tokens: adminTokens,
  };

  await sendMulticastNotification(message, "notifyAdminLateCheckout");

  // Also create notification document for history
  await db.collection("notifications").add({
    title: "موظف لم يسجل خروج",
    body: `${attendance.userName} لم يسجل خروج منذ ${minutesLate} دقيقة بعد انتهاء الشفت`,
    type: "late_checkout_admin",
    forAdmin: true,
    employeeId: attendance.userId,
    employeeName: attendance.userName,
    createdAt: new Date().toISOString(),
    read: false,
    skipPush: true,
  });
}

/**
 * Notify employee about auto-checkout
 */
async function notifyEmployeeAutoCheckout(attendance, attendanceId) {
  const tokens = await getTokensForUsers([attendance.userId]);
  if (tokens.length === 0) {
    return;
  }

  const message = {
    notification: {
      title: "تسجيل خروج تلقائي",
      body: "تم تسجيل خروجك تلقائياً بعد تجاوز 30 دقيقة من انتهاء الشفت",
    },
    data: {
      type: "auto_checkout",
      attendanceId: attendanceId,
      action: "auto_checkout",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "attendance_channel",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
    tokens: tokens,
  };

  await sendMulticastNotification(message, "notifyEmployeeAutoCheckout");

  // Also create notification document
  await db.collection("notifications").add({
    title: "تسجيل خروج تلقائي",
    body: "تم تسجيل خروجك تلقائياً بعد تجاوز 30 دقيقة من انتهاء الشفت",
    type: "auto_checkout",
    forEmployee: true,
    targetUserId: attendance.userId,
    createdAt: new Date().toISOString(),
    read: false,
    skipPush: true,
  });
}

// ============================================
// MANUAL NOTIFICATION FUNCTION (HTTP callable)
// ============================================

/**
 * Send notification to specific users (can be called from app)
 * Usage: admin can send custom notifications
 */
exports.sendNotification = functions.https.onCall(async (data, context) => {
  // Verify caller is authenticated and is admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated",
    );
  }

  const {userIds, title, body, dataPayload} = data;

  if (!userIds || !title || !body) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: userIds, title, body",
    );
  }

  const tokens = await getTokensForUsers(userIds);
  if (tokens.length === 0) {
    return {success: false, message: "No valid tokens found"};
  }

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      ...dataPayload,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      notification: {
        channelId: "store_channel",
        priority: "high",
      },
    },
    tokens: tokens,
  };

  const response = await sendMulticastNotification(message, "sendNotification");

  return {
    success: true,
    successCount: response?.successCount || 0,
    failureCount: response?.failureCount || 0,
  };
});

// ============================================
// TIME-OFF GRACE PERIOD MONITORING
// ============================================

/**
 * Check for employees who exceeded time-off grace period
 * Runs every 1 minute for precise timing
 * - Blocks employee who doesn't return within grace period
 * - Auto-checkouts and notifies admin
 */
exports.checkTimeOffGracePeriod = functions.pubsub
    .schedule("every 1 minutes")
    .timeZone("Asia/Baghdad")
    .onRun(async (context) => {
      console.log("Running time-off grace period check...");

      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);

      try {
        // Get active time-off requests for today
        const timeOffSnapshot = await db.collection("requests")
            .where("type", "==", "timeOff")
            .where("status", "==", "approved")
            .where("timeOffReturnStatus", "==", "active")
            .get();

        if (timeOffSnapshot.empty) {
          console.log("No active time-off requests found");
          return null;
        }

        console.log(`Found ${timeOffSnapshot.size} active time-off requests`);

        for (const doc of timeOffSnapshot.docs) {
          const data = doc.data();
          const requestId = doc.id;

          // Parse target date
          let targetDate;
          if (data.targetDate && data.targetDate.toDate) {
            targetDate = data.targetDate.toDate();
          } else if (data.targetDate) {
            targetDate = new Date(data.targetDate);
          }

          // Check if this is today's request
          if (!targetDate || targetDate < todayStart || targetDate >= todayEnd) {
            continue;
          }

          // Parse expected return time
          if (!data.expectedReturnTime) continue;
          const [returnHour, returnMinute] = data.expectedReturnTime.split(":").map(Number);

          const expectedReturn = new Date(
              targetDate.getFullYear(),
              targetDate.getMonth(),
              targetDate.getDate(),
              returnHour,
              returnMinute,
          );

          // Calculate deadline with grace period (default 15 minutes)
          const graceMinutes = data.graceMinutes || 15;
          const deadline = new Date(expectedReturn.getTime() + graceMinutes * 60000);

          // Check if deadline has passed
          if (now > deadline) {
            console.log(`Time-off grace period exceeded for ${data.employeeName}`);
            await blockEmployeeForTimeOff(doc, data, expectedReturn, now);
          }
        }

        return null;
      } catch (error) {
        console.error("Error in time-off grace check:", error);
        return null;
      }
    });

/**
 * Block employee who exceeded time-off grace period
 */
async function blockEmployeeForTimeOff(doc, data, expectedReturn, now) {
  try {
    // Update time-off status to blocked
    await doc.ref.update({
      timeOffReturnStatus: "blocked",
      blockedAt: now.toISOString(),
      blockedBy: "cloud_function",
    });

    console.log(`Blocked: ${data.employeeName} - exceeded time-off grace period`);

    // Find and auto checkout active attendance
    const attendanceSnapshot = await db.collection("attendance")
        .where("userId", "==", data.employeeId)
        .where("checkOut", "==", null)
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
          totalHours: Math.round(adjustedHours * 100) / 100,
          totalTimeOffMinutes: data.durationMinutes || 0,
          isCheckedOut: true,
          isEarlyLeave: true,
          autoCheckout: true,
          autoCheckoutReason: "تسجيل خروج تلقائي - تجاوز فترة السماح للزمنية",
          autoCheckoutSource: "cloud_function",
        });

        console.log(`Auto checkout for blocked employee: ${data.employeeName}`);
      }
    }

    // Send notification to employee
    const employeeTokens = await getTokensForUsers([data.employeeId]);
    if (employeeTokens.length > 0) {
      const employeeMessage = {
        notification: {
          title: "⛔ تم تسجيل خروجك تلقائياً",
          body: "تأخرت عن العودة من الزمنية أكثر من 15 دقيقة.\nلا يمكنك الدخول مجدداً اليوم.",
        },
        data: {
          type: "time_off_blocked",
          action: "blocked",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "attendance_channel",
            priority: "max",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens: employeeTokens,
      };
      await sendMulticastNotification(employeeMessage, "notifyEmployeeTimeOffBlocked");
    }

    // Notify admin
    const adminTokens = await getAdminTokens();
    if (adminTokens.length > 0) {
      const adminMessage = {
        notification: {
          title: "⛔ تسجيل خروج تلقائي - تجاوز زمنية",
          body: `${data.employeeName} تجاوز فترة السماح ولم يعد من الزمنية.\nتم تسجيل خروجه تلقائياً.`,
        },
        data: {
          type: "time_off_blocked_admin",
          employeeId: data.employeeId,
          employeeName: data.employeeName,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          notification: {
            channelId: "attendance_channel",
            priority: "high",
            defaultSound: true,
          },
        },
        tokens: adminTokens,
      };
      await sendMulticastNotification(adminMessage, "notifyAdminTimeOffBlocked");
    }

    // Create notification document for history
    await db.collection("notifications").add({
      title: "⛔ تسجيل خروج تلقائي - تجاوز زمنية",
      body: `${data.employeeName} تجاوز فترة السماح ولم يعد من الزمنية. تم تسجيل خروجه تلقائياً.`,
      type: "time_off_blocked",
      forAdmin: true,
      employeeId: data.employeeId,
      employeeName: data.employeeName,
      storeId: data.storeId,
      storeName: data.storeName,
      requestId: doc.id,
      createdAt: now.toISOString(),
      read: false,
      skipPush: true,
      source: "cloud_function",
    });
  } catch (error) {
    console.error(`Error blocking employee ${data.employeeName}:`, error);
  }
}

// ============================================
// BREAK OVERTIME MONITORING
// ============================================

/**
 * Check for employees with extended breaks
 * Runs every 5 minutes
 * - Notifies admin when break exceeds 60 minutes
 */
exports.checkBreakOvertime = functions.pubsub
    .schedule("every 5 minutes")
    .timeZone("Asia/Baghdad")
    .onRun(async (context) => {
      console.log("Running break overtime check...");

      const now = new Date();
      const BREAK_MAX_MINUTES = 60;

      try {
        // Get active breaks
        const activeBreaksSnapshot = await db.collection("attendance")
            .where("isOnBreak", "==", true)
            .get();

        if (activeBreaksSnapshot.empty) {
          console.log("No active breaks found");
          return null;
        }

        console.log(`Found ${activeBreaksSnapshot.size} active breaks`);

        for (const doc of activeBreaksSnapshot.docs) {
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

          // Check if break exceeded maximum
          if (breakMinutes > BREAK_MAX_MINUTES) {
            const overtimeMinutes = breakMinutes - BREAK_MAX_MINUTES;

            // Check if we already notified recently (prevent spam)
            const recentNotificationsSnapshot = await db.collection("notifications")
                .where("type", "==", "break_overtime_server")
                .where("userId", "==", data.userId)
                .where("createdAt", ">", new Date(now.getTime() - 10 * 60000).toISOString())
                .get();

            if (!recentNotificationsSnapshot.empty) {
              console.log(`Already notified about break overtime for ${data.userName}`);
              continue;
            }

            console.log(`Break overtime for ${data.userName}: ${overtimeMinutes} minutes`);

            // Notify admin
            const adminTokens = await getAdminTokens();
            if (adminTokens.length > 0) {
              const message = {
                notification: {
                  title: "تجاوز وقت الاستراحة",
                  body: `${data.userName} تجاوز وقت الاستراحة بـ ${overtimeMinutes} دقيقة`,
                },
                data: {
                  type: "break_overtime_server",
                  userId: data.userId,
                  userName: data.userName,
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                  notification: {
                    channelId: "break_channel",
                    priority: "high",
                    defaultSound: true,
                  },
                },
                tokens: adminTokens,
              };
              await sendMulticastNotification(message, "notifyAdminBreakOvertime");
            }

            // Create notification document
            await db.collection("notifications").add({
              title: "تجاوز وقت الاستراحة",
              body: `${data.userName} تجاوز وقت الاستراحة بـ ${overtimeMinutes} دقيقة`,
              type: "break_overtime_server",
              forAdmin: true,
              userId: data.userId,
              userName: data.userName,
              attendanceId: doc.id,
              overtimeMinutes: overtimeMinutes,
              createdAt: now.toISOString(),
              read: false,
              skipPush: true,
              source: "cloud_function",
            });
          }
        }

        return null;
      } catch (error) {
        console.error("Error in break overtime check:", error);
        return null;
      }
    });
