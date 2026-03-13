## 5. Data Models & Database Schema

### Firestore Collection Structure

```
users/
├── {uid}/                          → UserProfile document
│   ├── (profile fields)
│   ├── businessProfile (nested)    → BusinessProfile
│   ├── verification (nested)       → VerificationData
│   ├── catalog/
│   │   └── {catalogId}             → CatalogItem
│   ├── bookings/
│   │   └── {bookingId}             → BookingModel
│   ├── reviews/
│   │   └── {reviewId}              → ReviewModel
│   ├── inquiries/
│   │   └── {inquiryId}             → InquiryModel
│   ├── menu_categories/
│   │   └── {categoryId}            → MenuCategoryModel
│   ├── menu_items/
│   │   └── {itemId}                → MenuItemModel
│   └── food_orders/
│       └── {orderId}               → FoodOrderModel

posts/
└── {postId}                        → PostModel (with 768-dim embedding)

conversations/
├── {conversationId}                → ConversationModel
│   └── messages/
│       └── {messageId}             → MessageModel

connection_requests/
└── {requestId}                     → Connection request data

voice_calls/
└── {callId}                        → WebRTC signaling data

video_calls/
└── {callId}                        → WebRTC signaling data

group_calls/
└── {callId}/
    └── participants/               → Group call participant data

notifications/
└── {notificationId}                → Notification records

bookings/
└── {bookingId}                     → BookingModel (top-level)

business_reviews/
└── {reviewId}                      → ReviewModel (top-level)
```

### Core Models

#### UserProfile (`users/{uid}`)

| Field | Type | Description |
|-------|------|-------------|
| uid | String | Firebase Auth UID |
| name | String | Display name |
| email | String | Email address |
| profileImageUrl | String? | Profile photo URL |
| phone | String? | Phone number |
| location | String? | Location name |
| latitude | double? | GPS latitude |
| longitude | double? | GPS longitude |
| bio | String | User bio |
| interests | List |<String> | User interests |
| isOnline | bool | Current online status |
| isVerified | bool | Verification status |
| showOnlineStatus | bool | Privacy toggle |
| accountType | AccountType | personal \| business |
| accountStatus | AccountStatus | active \| pendingVerification \| suspended |
| businessProfile | BusinessProfile? | Business data (if business account) |
| verification | VerificationData | Verification details |
| fcmToken | String? | FCM push token |
| activeDeviceToken | String? | Current device token |
| forceLogout | bool | Remote logout signal |
| createdAt | DateTime | Account creation |
| lastSeen | DateTime | Last activity |

#### BusinessProfile (nested in UserProfile)

| Field | Type | Description |
|-------|------|-------------|
| businessName | String? | Legal business name |
| description | String? | Business description |
| softLabel | String? | Industry label |
| contactPhone | String? | Business phone |
| contactEmail | String? | Business email |
| website | String? | Website URL |
| address | String? | Physical address |
| hours | BusinessHours? | Operating schedule |
| profileViews | int | View counter |
| catalogViews | int | Catalog view counter |
| averageRating | double | Review rating (0-5) |
| totalReviews | int | Number of reviews |
| coverImageUrl | String? | Cover photo |
| isLive | bool | Live status |
| socialLinks | Map\<String, String\>? | Social media |
| businessTypes | List\<String\> | products, services, bookings, events |

#### PostModel (`posts/{postId}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Post ID |
| userId | String | Creator's UID |
| originalPrompt | String | Raw user input |
| title | String | AI-generated title |
| description | String | AI-generated description |
| intentAnalysis | Map | Full AI analysis (see section 7) |
| embedding | List\<double\>? | 768-dim semantic vector |
| keywords | List\<String\>? | Extracted keywords |
| location | String? | Location name |
| latitude / longitude | double? | GPS coordinates |
| price / priceMin / priceMax | double? | Pricing |
| currency | String? | Currency code |
| images | List\<String\>? | Attached images |
| isActive | bool | Active status |
| expiresAt | DateTime? | Expiration (30 days) |
| similarityScore | double? | Match score (populated during matching) |
| matchedUserIds | List\<String\> | Matched user IDs |
| createdAt | DateTime | Creation time |

**Key Computed Properties:**
- `primaryIntent` → from `intentAnalysis['primary_intent']`
- `actionType` → from `intentAnalysis['action_type']` (offering/seeking/neutral)
- `searchKeywords` → from `intentAnalysis['search_keywords']`
- `needsClarification` → if `clarifications_needed` is not empty

#### MessageModel (`conversations/{id}/messages/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Message ID |
| senderId | String | Sender UID |
| receiverId | String | Recipient UID |
| chatId | String | Conversation ID |
| text | String? | Message text |
| type | MessageType | text, image, video, audio, file, location, voiceCall, etc. |
| status | MessageStatus | sending, sent, delivered, read, failed |
| mediaUrl | String? | Media URL |
| thumbnailUrl | String? | Thumbnail |
| audioUrl | String? | Audio URL |
| audioDuration | int? | Audio duration (ms) |
| replyToMessageId | String? | Reply reference |
| reactions | List\<String\>? | Emoji reactions |
| isEdited | bool | Edit flag |
| isDeleted | bool | Soft delete flag |
| timestamp | DateTime | Send time |

#### ConversationModel (`conversations/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Conversation ID (deterministic: userId1_userId2) |
| participantIds | List\<String\> | User IDs |
| participantNames | Map\<String, String\> | ID → Name |
| participantPhotos | Map\<String, String?\> | ID → Photo URL |
| lastMessage | String? | Preview text |
| lastMessageTime | DateTime? | Last message timestamp |
| unreadCount | Map\<String, int\> | Per-user unread count |
| isTyping | Map\<String, bool\> | Per-user typing status |
| isGroup | bool | Group chat flag |
| groupName | String? | Group name |
| groupPhoto | String? | Group photo |
| metadata | Map? | Business chat info |
| createdAt | DateTime | Creation time |

#### CatalogItem (`users/{userId}/catalog/{catalogId}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Item ID |
| userId | String | Owner UID |
| name | String | Item name |
| description | String? | Description |
| price | double? | Price |
| currency | String | Currency (default: INR) |
| imageUrls | List\<String\> | Multiple images |
| type | CatalogItemType | product \| service |
| isAvailable | bool | Availability |
| isFeatured | bool | Featured flag |
| duration | int? | Service duration (minutes) |
| tags | List\<String\> | Search tags |
| category | String? | Category |
| viewCount | int | View counter |

#### BookingModel (`bookings/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Booking ID |
| customerId | String | Customer UID |
| customerName | String | Customer name |
| businessOwnerId | String | Business UID |
| businessName | String | Business name |
| serviceName | String? | Service booked |
| servicePrice | double? | Service price |
| status | BookingStatus | pending, confirmed, completed, cancelled |
| bookingDate | DateTime | Scheduled date |
| bookingTime | String? | Scheduled time (HH:mm) |
| duration | int? | Duration (minutes) |
| notes | String? | Customer notes |

#### ReviewModel (`business_reviews/{id}`)

| Field | Type | Description |
|-------|------|-------------|
| id | String | Review ID |
| reviewerId | String | Reviewer UID |
| businessId | String | Business UID |
| rating | double | Rating (1-5) |
| categoryRatings | Map\<String, double\>? | Per-category ratings |
| reviewText | String | Review content |
| images | List\<String\> | Review photos |
| isVerifiedPurchase | bool | Purchase verified |
| createdAt | DateTime | Review date |

### Enums

| Enum | Values |
|------|--------|
| AccountType | personal, business |
| AccountStatus | active, pendingVerification, suspended |
| VerificationStatus | none, pending, verified, rejected |
| CatalogItemType | product, service |
| MessageType | text, image, video, audio, file, location, sticker, gif, voiceCall, missedCall, videoCall |
| MessageStatus | sending, sent, delivered, read, failed |
| BookingStatus | pending, confirmed, completed, cancelled |
| InquiryStatus | pending, responded, negotiating, accepted, declined, completed, cancelled |
| FoodType | veg, nonVeg, egg, vegan |
| SpiceLevel | mild, medium, hot, extraHot |
| OrderType | dineIn, takeaway, delivery |
| FoodOrderStatus | pending, confirmed, preparing, ready, outForDelivery, delivered, completed, cancelled |

### Model Relationships

```
UserProfile ──1:0..1──→ BusinessProfile
UserProfile ──1:1─────→ VerificationData
UserProfile ──1:N─────→ CatalogItem
UserProfile ──1:N─────→ PostModel
UserProfile ──1:N─────→ BookingModel (as business)
UserProfile ──1:N─────→ ReviewModel (as business)
PostModel   ──M:N─────→ PostModel (matching)
ConversationModel ──1:N→ MessageModel
BusinessProfile ──1:1──→ BusinessHours ──1:7──→ DayHours
MenuCategoryModel ──1:N→ MenuItemModel
FoodOrderModel ──1:N───→ FoodOrderItem
```

---

