/**
 * Supper App - Firebase Cloud Functions
 *
 * Push Notification System
 *
 * IMPORTANT: Notifications are sent ONLY to the recipient (User B),
 * never to the sender (User A).
 *
 * Triggers:
 * 1. onMessageCreated - When User A sends a message to User B
 * 2. onCallCreated - When User A calls User B
 * 3. onInquiryCreated - When a client sends an inquiry to a professional
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { getAuth } = require("firebase-admin/auth");

// Initialize Firebase Admin
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/**
 * Get user's FCM token from Firestore
 * @param {string} userId - The user's ID
 * @returns {Promise<string|null>} - FCM token or null if not found
 */
async function getUserFcmToken(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.fcmToken || null;
    }
    return null;
  } catch (error) {
    logger.error(`Error getting FCM token for user ${userId}:`, error);
    return null;
  }
}

/**
 * Get user's display name from Firestore
 * @param {string} userId - The user's ID
 * @returns {Promise<string>} - User's name or 'Someone'
 */
async function getUserName(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.name || userData.displayName || "Someone";
    }
    return "Someone";
  } catch (error) {
    logger.error(`Error getting user name for ${userId}:`, error);
    return "Someone";
  }
}

/**
 * Get user's photo URL from Firestore
 * @param {string} userId - The user's ID
 * @returns {Promise<string|null>} - Photo URL or null
 */
async function getUserPhotoUrl(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      return userData.photoUrl || userData.photoURL || null;
    }
    return null;
  } catch (error) {
    logger.error(`Error getting photo URL for ${userId}:`, error);
    return null;
  }
}

/**
 * Send FCM notification
 * @param {string} token - FCM token of recipient
 * @param {object} notification - Notification title and body
 * @param {object} data - Additional data payload
 * @returns {Promise<boolean>} - Success status
 */
async function sendNotification(token, notification, data) {
  if (!token) {
    logger.warn("No FCM token provided, skipping notification");
    return false;
  }

  try {
    const message = {
      token: token,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: data,
      android: {
        priority: "high",
        notification: {
          channelId: "chat_messages",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.send(message);
    logger.info("Notification sent successfully:", response);
    return true;
  } catch (error) {
    // Handle invalid token - remove it from user's document
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      logger.warn(`Invalid FCM token, should be removed: ${token}`);
    } else {
      logger.error("Error sending notification:", error);
    }
    return false;
  }
}

/**
 * MESSAGE NOTIFICATION
 *
 * Triggers when a new message is created in a conversation.
 * Sends notification ONLY to the recipient (User B), NOT to the sender (User A).
 *
 * Path: conversations/{conversationId}/messages/{messageId}
 */
exports.onMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data.data();
    const conversationId = event.params.conversationId;

    logger.info(`New message in conversation ${conversationId}`);

    // Get sender and receiver IDs
    const senderId = messageData.senderId;
    const receiverId = messageData.receiverId;

    // CRITICAL: Only send notification to receiver (User B), NOT sender (User A)
    if (!receiverId || receiverId === senderId) {
      logger.warn("No valid receiver or sender is receiver, skipping");
      return null;
    }

    // Get receiver's FCM token
    const receiverToken = await getUserFcmToken(receiverId);
    if (!receiverToken) {
      logger.warn(`No FCM token for receiver ${receiverId}`);
      return null;
    }

    // Get sender's name for notification
    const senderName = await getUserName(senderId);

    // Prepare notification content
    const messageText = messageData.text || "";
    const hasImage = messageData.imageUrl ? true : false;

    let notificationBody = messageText;
    if (hasImage && !messageText) {
      notificationBody = "Sent you a photo";
    } else if (hasImage && messageText) {
      notificationBody = `[Photo] ${messageText}`;
    }

    // Truncate long messages
    if (notificationBody.length > 100) {
      notificationBody = notificationBody.substring(0, 97) + "...";
    }

    // Send notification to receiver ONLY
    await sendNotification(
      receiverToken,
      {
        title: senderName,
        body: notificationBody,
      },
      {
        type: "message",
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    logger.info(`Message notification sent to ${receiverId} from ${senderId}`);
    return null;
  }
);

/**
 * CALL NOTIFICATION
 *
 * Triggers when a new call document is created.
 * Sends notification ONLY to the receiver (User B), NOT to the caller (User A).
 *
 * Path: calls/{callId}
 */
exports.onCallCreated = onDocumentCreated("calls/{callId}", async (event) => {
  const callData = event.data.data();
  const callId = event.params.callId;

  logger.info(`New call created: ${callId}`);
  logger.info(`Call data:`, JSON.stringify(callData));

  // Get caller and receiver IDs (support both field names)
  const callerId = callData.callerId;
  const receiverId = callData.receiverId || callData.calleeId;

  // CRITICAL: Only send notification to receiver (User B), NOT caller (User A)
  if (!receiverId || receiverId === callerId) {
    logger.warn("No valid receiver or caller is receiver, skipping");
    return null;
  }

  // Only send notification for incoming calls (status: 'calling' or 'ringing')
  const status = callData.status;
  if (status !== "calling" && status !== "ringing" && status !== "pending") {
    logger.info(`Call status is ${status}, not a new call, skipping`);
    return null;
  }

  // Get receiver's FCM token
  const receiverToken = await getUserFcmToken(receiverId);
  if (!receiverToken) {
    logger.warn(`No FCM token for receiver ${receiverId}`);
    return null;
  }

  // Get caller's name and photo - use from call data or fetch from user doc
  const callerName = callData.callerName || await getUserName(callerId);
  const callerPhotoUrl = callData.callerPhoto || await getUserPhotoUrl(callerId);

  // Send HIGH PRIORITY notification with data to receiver
  // IMPORTANT: For Android killed app state, we need notification field for reliable delivery
  // The Flutter app will handle showing CallKit UI from onBackgroundMessage
  try {
    const message = {
      token: receiverToken,
      // Include notification for reliable delivery when app is killed
      notification: {
        title: "Incoming Call",
        body: `${callerName} is calling you`,
      },
      // Data payload - this triggers onBackgroundMessage in Flutter
      data: {
        type: "call",
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerPhoto: callerPhotoUrl || "",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        timestamp: Date.now().toString(),
      },
      android: {
        priority: "high",
        ttl: 60000, // 60 seconds
        notification: {
          channelId: "calls",
          priority: "max",
          visibility: "public",
          defaultSound: true,
          defaultVibrateTimings: true,
          // Full screen intent for incoming call
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: "Incoming Call",
              body: `${callerName} is calling you`,
            },
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
            category: "INCOMING_CALL",
          },
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerPhoto: callerPhotoUrl || "",
          type: "call",
        },
      },
    };

    const response = await messaging.send(message);
    logger.info(`Call notification sent successfully: ${response}`);
  } catch (error) {
    logger.error("Error sending call notification:", error);
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      logger.warn(`Invalid FCM token for receiver ${receiverId}`);
    }
  }

  logger.info(`Call notification sent to ${receiverId} from ${callerId}`);
  return null;
});

/**
 * INQUIRY NOTIFICATION (for Professional accounts)
 *
 * Triggers when a new inquiry is created for a professional.
 * Sends notification to the professional (service provider).
 *
 * Path: users/{professionalId}/inquiries/{inquiryId}
 */
exports.onInquiryCreated = onDocumentCreated(
  "users/{professionalId}/inquiries/{inquiryId}",
  async (event) => {
    const inquiryData = event.data.data();
    const professionalId = event.params.professionalId;
    const inquiryId = event.params.inquiryId;

    logger.info(`New inquiry ${inquiryId} for professional ${professionalId}`);

    // Get client who sent the inquiry
    const clientId = inquiryData.clientId || inquiryData.userId;
    if (!clientId) {
      logger.warn("No client ID in inquiry, skipping");
      return null;
    }

    // Don't notify if professional is sending inquiry to themselves
    if (clientId === professionalId) {
      logger.warn("Client is the professional, skipping");
      return null;
    }

    // Get professional's FCM token
    const professionalToken = await getUserFcmToken(professionalId);
    if (!professionalToken) {
      logger.warn(`No FCM token for professional ${professionalId}`);
      return null;
    }

    // Get client's name
    const clientName = await getUserName(clientId);

    // Prepare notification
    const serviceName = inquiryData.serviceName || "your service";
    const message = inquiryData.message || "";

    let notificationBody = `${clientName} sent an inquiry for ${serviceName}`;
    if (message) {
      const truncatedMessage =
        message.length > 50 ? message.substring(0, 47) + "..." : message;
      notificationBody = `${clientName}: "${truncatedMessage}"`;
    }

    // Send notification to professional ONLY
    await sendNotification(
      professionalToken,
      {
        title: "New Inquiry",
        body: notificationBody,
      },
      {
        type: "inquiry",
        inquiryId: inquiryId,
        clientId: clientId,
        clientName: clientName,
        serviceName: serviceName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    logger.info(
      `Inquiry notification sent to professional ${professionalId} from client ${clientId}`
    );
    return null;
  }
);

/**
 * CONNECTION REQUEST NOTIFICATION
 *
 * Triggers when someone sends a connection request.
 * Sends notification to the recipient of the request.
 *
 * Path: users/{userId}/connection_requests/{requestId}
 */
exports.onConnectionRequestCreated = onDocumentCreated(
  "users/{userId}/connection_requests/{requestId}",
  async (event) => {
    const requestData = event.data.data();
    const recipientId = event.params.userId;
    const requestId = event.params.requestId;

    logger.info(`New connection request ${requestId} for user ${recipientId}`);

    // Get sender ID
    const senderId = requestData.fromUserId || requestData.senderId;
    if (!senderId) {
      logger.warn("No sender ID in connection request, skipping");
      return null;
    }

    // Don't notify if sending to self
    if (senderId === recipientId) {
      logger.warn("Sender is recipient, skipping");
      return null;
    }

    // Get recipient's FCM token
    const recipientToken = await getUserFcmToken(recipientId);
    if (!recipientToken) {
      logger.warn(`No FCM token for recipient ${recipientId}`);
      return null;
    }

    // Get sender's name
    const senderName = await getUserName(senderId);

    // Send notification to recipient ONLY
    await sendNotification(
      recipientToken,
      {
        title: "Connection Request",
        body: `${senderName} wants to connect with you`,
      },
      {
        type: "connection_request",
        requestId: requestId,
        senderId: senderId,
        senderName: senderName,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      }
    );

    logger.info(
      `Connection request notification sent to ${recipientId} from ${senderId}`
    );
    return null;
  }
);

/**
 * FORCE LOGOUT FUNCTION - Device Login Collision Handler
 *
 * Handles the WhatsApp-style single device login by triggering force logout
 * on other devices when a new device logs in with the same account.
 *
 * Called from: lib/services/auth_service.dart logoutFromOtherDevices()
 *
 * Security:
 * - Only authenticated users can call this
 * - A user can only logout from their own account
 * - Cloud Function runs with admin privileges for secure Firestore writes
 */
exports.forceLogoutOtherDevices = onCall(
  { enforceAppCheck: false, requiresAuthentication: true },
  async (request) => {
    const userId = request.auth.uid;
    const data = request.data;

    // Verify user is authenticated
    if (!userId) {
      throw new Error("Unauthorized: User not authenticated");
    }

    // Get parameters
    const localToken = data.localToken;
    const deviceInfo = data.deviceInfo;

    if (!localToken) {
      throw new Error("Missing required parameter: localToken");
    }

    logger.info(
      `Force logout called for user ${userId} with token ${localToken.substring(0, 8)}...`
    );

    try {
      // STEP 1: Set force logout flag + clear token (INSTANT logout for other devices)
      logger.info(
        `Step 1: Setting forceLogout=true for user ${userId} to trigger instant logout on old devices...`
      );
      await db.collection("users").doc(userId).set(
        {
          forceLogout: true, // Signal to other devices: LOGOUT NOW!
          activeDeviceToken: "", // Clear token so old device sees mismatch
          lastSessionUpdate: new (require("firebase-admin/firestore").FieldValue).serverTimestamp(),
        },
        { merge: true }
      );

      logger.info(`forceLogout signal sent for user ${userId}`);

      // Wait to ensure old device receives and processes logout signal
      await new Promise((resolve) => setTimeout(resolve, 500));

      // STEP 2: Set new device as the active device and clear logout flag
      logger.info(
        `Step 2: Setting new device as active for user ${userId}...`
      );
      await db.collection("users").doc(userId).set(
        {
          activeDeviceToken: localToken,
          deviceInfo: deviceInfo || {},
          forceLogout: false, // Clear the logout flag now that old device should be logged out
          lastSessionUpdate: new (require("firebase-admin/firestore").FieldValue).serverTimestamp(),
        },
        { merge: true }
      );

      logger.info(
        `Successfully forced logout on other devices for user ${userId}`
      );

      return {
        success: true,
        message: "Force logout completed",
      };
    } catch (error) {
      logger.error(
        `Error during force logout for user ${userId}:`,
        error
      );
      throw new Error(`Force logout failed: ${error.message}`);
    }
  }
);