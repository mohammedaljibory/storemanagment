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

      // Get assigned employees
      const assignedTo = task.assignedTo || [];
      if (assignedTo.length === 0) {
        console.log("No employees assigned to task");
        return null;
      }

      // Get FCM tokens for all assigned employees
      const tokens = await getTokensForUsers(assignedTo);
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
