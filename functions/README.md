# Supper App - Firebase Cloud Functions

Push notification system for the Supper app. These functions automatically send notifications to User B when User A performs actions (messages, calls, etc.).

## How It Works

### Notification Flow

```
User A sends message → Message created in Firestore → Cloud Function triggers
                                                              ↓
                                                    Get User B's FCM token
                                                              ↓
                                                    Send push notification to User B ONLY
```

**Key principle**: Notifications are sent ONLY to the recipient (User B), never to the sender (User A).

### Cloud Functions

| Function | Trigger | Description |
|----------|---------|-------------|
| `onMessageCreated` | `conversations/{conversationId}/messages/{messageId}` | Sends notification when a new message is created |
| `onCallCreated` | `calls/{callId}` | Sends notification when a voice call is initiated |
| `onInquiryCreated` | `users/{professionalId}/inquiries/{inquiryId}` | Sends notification to professionals for new service inquiries |
| `onConnectionRequestCreated` | `users/{userId}/connection_requests/{requestId}` | Sends notification for new connection requests |

## Deployment

### Prerequisites

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Select your Firebase project:
   ```bash
   firebase use <your-project-id>
   ```

### Deploy Functions

1. Navigate to the functions directory:
   ```bash
   cd functions
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Deploy to Firebase:
   ```bash
   npm run deploy
   ```

   Or from the project root:
   ```bash
   firebase deploy --only functions
   ```

### View Logs

```bash
firebase functions:log
```

Or view in the Firebase Console under Functions > Logs.

## Testing

### Local Testing with Emulators

1. Start the Firebase emulator:
   ```bash
   npm run serve
   ```

2. Send test messages through the app connected to the emulator.

### Testing in Production

1. Deploy functions
2. Send a message from User A to User B
3. User B should receive a push notification
4. Check Firebase Console > Functions > Logs for any errors

## Notification Channels (Android)

The app has these notification channels:

| Channel ID | Description |
|------------|-------------|
| `chat_messages` | Chat message notifications |
| `calls` | Incoming call notifications (high priority) |
| `inquiries` | Service inquiry notifications |
| `connections` | Connection request notifications |

## FCM Token Management

- FCM tokens are stored in `users/{userId}/fcmToken`
- Tokens are automatically updated when they refresh
- Invalid tokens are logged (but not removed automatically)

## Troubleshooting

### Notifications not being sent

1. Check if the recipient has an `fcmToken` in their user document
2. Verify the message has both `senderId` and `receiverId` fields
3. Check Firebase Functions logs for errors

### Common Errors

| Error | Solution |
|-------|----------|
| `messaging/invalid-registration-token` | User's FCM token is invalid - they need to re-login |
| `messaging/registration-token-not-registered` | Token expired - app will refresh on next launch |
| `Permission denied` | Check Firestore rules allow function service account access |

## Security Notes

- Cloud Functions use the Admin SDK which bypasses Firestore security rules
- Only the notification content is sent - no sensitive data
- FCM tokens should be treated as sensitive (stored securely in Firestore)