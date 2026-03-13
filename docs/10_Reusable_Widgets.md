## 10. Reusable Widgets & Components

### Widget Inventory (18 files)

#### Badge Widgets (`account_badges.dart`)

| Widget | Purpose | Parameters |
|--------|---------|-----------|
| VerifiedBadge | Blue verified checkmark | size, showBackground |
| BusinessBadge | Orange business indicator | size, showLabel, compact |
| PendingVerificationBadge | Yellow pending badge | size, showLabel |
| AccountTypeBadge | Smart badge selector | accountType, verificationStatus, size |
| UsernameBadge | Inline username badge | accountType, verificationStatus |
| AccountTypeCard | Glassmorphic account card | accountType, onUpgrade |

#### Background & Animation

| Widget | File | Purpose |
|--------|------|---------|
| AppBackground | app_background.dart | Background with particles + blur |
| FloatingParticles | floating_particles.dart | 60-second particle animation loop |
| AudioVisualizer | audio_visualizer.dart | 3-wave audio visualization (idle/active) |
| VoiceOrb | voice_orb.dart | 4-state voice indicator (idle/listening/processing/speaking) |
| ComingSoonWidget | coming_soon_widget.dart | Feature placeholder with progress animation |

#### Chat Components (`chat_common.dart`)

| Widget | Purpose |
|--------|---------|
| ChatMessageInput | Chat input bar (text, emoji, mic, attachment) |
| ChatMessageBubble | Message bubble with gradient, timestamps, read receipts |
| ChatEmojiPicker | Emoji selection panel (8 columns, searchable) |
| CatalogChatBubble | Rich catalog item preview in chat |
| MatchCardWithActions | Match result card with Chat/Profile buttons |

#### Input Components

| Widget | File | Purpose |
|--------|------|---------|
| GlassTextField | other widgets/glass_text_field.dart | Glassmorphic text field (34 params) |
| GlassSearchField | other widgets/glass_text_field.dart | Search with voice recording UI |
| CountryCodePickerSheet | country_code_picker_sheet.dart | Searchable country code selector |

#### Avatar Components

| Widget | File | Purpose |
|--------|------|---------|
| SafeCircleAvatar | safe_circle_avatar.dart | Rate-limit-aware network avatar with fallback |
| UserAvatar | other widgets/user_avatar.dart | Simple cached network avatar |

#### Dialog & Sheet Components

| Widget | File | Purpose |
|--------|------|---------|
| DeviceLoginDialog | device_login_dialog.dart | Multi-device login security dialog |
| SelectParticipantsDialog | select_participants_dialog.dart | Group call participant picker |
| ProfileDetailBottomSheet | profile widgets/profile_detail_bottom_sheet.dart | Premium draggable profile sheet |

#### Navigation

| Widget | File | Purpose |
|--------|------|---------|
| AppDrawer | app_drawer.dart | ChatGPT-style navigation drawer with conversation history |
| CatalogCardWidget | catalog_card_widget.dart | Product/service card (compact/normal) |

### Design Patterns

1. **Glassmorphism**: Used in 10+ widgets (BackdropFilter + gradient + border)
2. **Custom Painters**: 7 widgets (audio waves, particles, shimmer, arcs)
3. **Multi-State Animations**: VoiceOrb (3 controllers), ProfileDetailBottomSheet (2 controllers)
4. **Rate-Limit Protection**: SafeCircleAvatar tracks failed/rate-limited URLs
5. **Responsive Sizing**: Widgets adapt to screen dimensions

---

