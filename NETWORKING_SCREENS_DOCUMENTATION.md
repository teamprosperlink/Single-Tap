# Networking Module — Complete Screen Documentation

**App:** Supper
**Module:** Networking / Live Connect
**Total Screens:** 9 (8 standalone + 1 main container)
**Last Updated:** 10 Mar 2026

---

## Table of Contents

1. [Networking Screen (Main Container)](#1-networking-screen-main-container)
2. [Onboarding Networking Screen](#2-onboarding-networking-screen)
3. [Create Networking Profile Screen](#3-create-networking-profile-screen)
4. [Edit Networking Profile Screen](#4-edit-networking-profile-screen)
5. [My Networking Profile Screen](#5-my-networking-profile-screen)
6. [Networking Profiles Page Screen](#6-networking-profiles-page-screen)
7. [Live Connect Tab Screen](#7-live-connect-tab-screen)
8. [Pending Requests Screen](#8-pending-requests-screen)
9. [User Profile Detail Screen](#9-user-profile-detail-screen)

---

## 1. Networking Screen (Main Container)

**File:** `lib/screens/home/main_navigation_screen.dart` (Bottom Tab Index: 2)
**Purpose:** The parent container screen that houses the entire networking module. It appears as the 3rd tab in the app's bottom navigation bar. Conditionally shows onboarding (for new users) or the full 3-tab networking experience (for users with profiles).

### Entry Condition

| Condition | What Shows |
|-----------|-----------|
| `_networkingProfileCount == 0` (no profiles) | Onboarding Screen (`LiveConnectScreen`) |
| `_networkingProfileCount >= 1` (has profiles) | Full Networking Screen with AppBar + 3 Tabs |

**Profile count source:** Real-time stream on `networking_profiles/{uid}/profiles` subcollection.

### AppBar Layout

```
┌────────────────────────────────────────────────────┐
│ [Avatar]    "Networking"         [Requests] [Filter]│
│                                                    │
│  [Discover All]  [Smart Connect]  [My Network]     │
└────────────────────────────────────────────────────┘
```

| Element | Position | Behavior |
|---------|----------|----------|
| **Profile Avatar** | Leading (left) | 34x34 circular photo from `networking_profiles/{uid}` (real-time stream). Tap → opens `MyNetworkingProfileScreen` |
| **Title** | Center | "Networking" (Poppins, 17px, bold, white) |
| **Pending Requests Icon** | Right action 1 | Bell icon with red badge count (real-time stream via `ConnectionService.getPendingRequestsCountStream()`). Badge shows count (max "9+"). Tap → opens `PendingRequestsScreen` |
| **Filter Icon** | Right action 2 | Only visible on **Smart Connect** tab (`_networkingTabIndex == 1`). Tap → opens filter dialog on active `LiveConnectTabScreen` |

### AppBar Styling
- Background: Gradient `#282828` → `#404040` (top to bottom)
- Bottom border: White 0.5px
- Toolbar height: 56px
- Transparent elevation, no shadow

### Tab Bar (3 Tabs)

| Tab Index | Tab Name | Screen | Description |
|-----------|----------|--------|-------------|
| 0 | **Discover All** | `LiveConnectTabScreen(activateNetworkingFilter: false)` | Browse all profiles worldwide, no smart filters |
| 1 | **Smart Connect** | `LiveConnectTabScreen(activateNetworkingFilter: true)` | AI-based filtered discovery with category, location, etc. |
| 2 | **My Network** | `buildMyNetworkTab()` (inline) | Shows accepted connections grid |

### Tab Bar Styling
- Indicator: White, full-tab width, 2px weight
- Selected label: White, Poppins 13px, weight 600
- Unselected label: White 60% opacity, Poppins 13px, normal weight
- Bottom border: White 20% opacity, 1px

### Floating Action Button (FAB)

| Condition | FAB Visible |
|-----------|------------|
| On "My Network" tab (`_networkingTabIndex == 2`) | Hidden |
| Profile count >= 3 | Hidden |
| Otherwise | Visible |

- **Icon:** `+` (add), white, 28px
- **Color:** `#007AFF` (blue)
- **Shape:** Circle
- **Action:** Opens `CreateNetworkingProfileScreen(createdFrom: currentTabName)`
  - Tab 0 → `createdFrom: 'Discover All'`
  - Tab 1 → `createdFrom: 'Smart Connect'`
- **After save:** Refreshes both Discover All and Smart Connect tabs

### My Network Tab (Tab Index 2)

Shows all **accepted connections** in a 2-column mosaic grid with floating card animation.

#### Data Sources (Real-time Streams)
- `ConnectionService.getAcceptedAsReceiverStream()` — connections where current user is receiver
- `ConnectionService.getAcceptedAsSenderStream()` — connections where current user is sender
- Both streams merged + deduplicated by other user's ID
- **Self-connection filter:** Skips entries where `otherUserId == currentUid` (prevents self-cards)
- Sorted by `updatedAt` (or `createdAt`) descending

#### Location Protection (Mountain View / Null-Island Rejection)
When fetching other user's profile data for distance calculation:
- **Mountain View city check:** If `city.toLowerCase().contains('mountain view')` → coordinates set to `null`
- **Null-island check:** If `lat.abs() < 0.01 && lng.abs() < 0.01` → coordinates set to `null`
- **Distance filter:** If calculated distance `> 10,000 km` → distance not shown
- Applied to both stored connection request data AND fresh-fetched user data

#### Connection Card Information

| Field | Source | Display |
|-------|--------|---------|
| Name | Fresh fetch from `users/{otherUserId}`, fallback to stored name | Name + Age at bottom overlay |
| Photo | Fresh fetch, fallback to stored photo | Full-bleed image or gradient placeholder |
| Age | Fresh fetch, fallback to stored | After name (e.g., "John, 25") |
| Occupation | Fresh fetch, fallback to stored | Below name |
| Distance | Calculated from current user lat/lng vs other user lat/lng | With location icon (e.g., "2.5 km") |
| Online Status | `isOnline` from users collection | Green/grey dot |
| Networking Category | `networkingCategory` from users collection | Category badge |
| Time Ago | From `updatedAt` or `createdAt` | Badge (e.g., "2h ago") |

#### Card Actions

| Action | Behavior |
|--------|----------|
| **Tap card** | Opens `UserProfileDetailScreen` with `connectionStatus: 'connected'`. On return, refreshes both Discover tabs |
| **Message button** | Opens `EnhancedChatScreen` with other user's profile, `source: 'Networking'` |

#### Grid Layout
- 2 columns
- Cross-axis spacing: 12
- Main-axis spacing: 12
- Child aspect ratio: 0.85
- Padding: 15px horizontal, 12px top, 90px bottom
- Each card wrapped in `FloatingCard` animation

#### Empty State
- Icon: `people_outline_rounded` (72px, white 30% opacity)
- Title: "No connections yet" (18px, weight 600, white 50% opacity)
- Message: "Accepted connections will appear here" (14px, white 35% opacity)

#### Name Resolution Priority
`name` → `displayName` → `phone` → stored name from connection request → "Unknown"

### Access Points (How users reach Networking)

| Entry Point | Location | Navigation Target |
|-------------|----------|-------------------|
| **Bottom Navigation Tab** | 3rd tab (index 2) | Networking Screen (this screen) |
| **App Drawer** | "Networking Profile" card | `NetworkingProfilesPageScreen` (all profiles management) |
| **Drawer icon** | `hub_outlined`, color `#016CFF` | — |

### Body Background
```
Gradient: #404040 (top) → #000000 (bottom)
```

---

## 2. Onboarding Networking Screen

**File:** `lib/screens/networking/onboarding_networking_screen.dart`
**Purpose:** First-time user onboarding flow that introduces the networking feature through 3 animated walkthrough pages before redirecting to profile creation.

### Sub-Screens (3-page flow)

| Page | Class Name | Title | Button |
|------|-----------|-------|--------|
| 1 | `LiveConnectScreen` | Getting Started | "See Features" |
| 2 | `LiveConnectFeaturesScreen` | Features | "Find Your Vibe" |
| 3 | `SmartLiveConnect` | Explore Tabs | "Discover People" |

### Page 1 — Getting Started (`LiveConnectScreen`)

Explains the networking workflow in 5 animated steps:

| Step | Icon | Color | Title | Description |
|------|------|-------|-------|-------------|
| 1 | `person_add_alt_1_rounded` | `#007AFF` (Blue) | Create Profile | Create your networking profile to get started — visible in the Drawer under Networking Profiles |
| 2 | `send_rounded` | `#00B4D8` (Cyan) | Send Request | Find someone in Discover All or Smart Connect and send them a connection request |
| 3 | `notifications_active_rounded` | `#FFA502` (Orange) | Pending Request | The other user gets a pending request — they can choose to accept or delete it |
| 4 | `check_circle_rounded` | `#00E676` (Green) | Accept or Delete | If accepted, the connection card appears in My Networking — if deleted, the user reappears in Discover & Smart Connect |
| 5 | `account_circle_rounded` | `#7C4DFF` (Purple) | Your Profiles | All your created profiles are saved in the Drawer → Networking Profiles — manage or switch anytime |

### Page 2 — Features (`LiveConnectFeaturesScreen`)

Showcases 5 key features:

| Feature | Icon | Color | Title | Description |
|---------|------|-------|-------|-------------|
| 1 | `favorite_rounded` | `#FF6B8A` (Pink) | Vibe Match | Set your interests, preferences, and tastes to discover people who feel like your vibe |
| 2 | `public_rounded` | `#00B4D8` (Cyan) | Nearby & Global | Find people near you, in your city, or from cultures and countries you care about |
| 3 | `chat_bubble_rounded` | `#7C4DFF` (Purple) | Meaningful Intros | Every request comes with a short note: why they're reaching out and what they're interested in |
| 4 | `shield_rounded` | `#00E676` (Green) | Safe & Private | Your profile and chats stay fully protected with strong privacy controls and safe defaults |
| 5 | `call_rounded` | `#007AFF` (Blue) | Chat & Call | Move from matching to real-time chat or calls and build meaningful connections faster |

### Page 3 — Explore Tabs (`SmartLiveConnect`)

Explains the 4 main tabs:

| Tab | Icon | Color | Title | Description |
|-----|------|-------|-------|-------------|
| 1 | `explore_rounded` | `#00B4D8` (Cyan) | Discover All | Browse all profiles nearby or worldwide without any filters — just explore freely and find people who catch your eye |
| 2 | `auto_awesome_rounded` | `#FFA502` (Orange) | Smart Connect | Use filters like category, age, gender, location and more to find exactly the kind of people you want to connect with |
| 3 | `person_pin_rounded` | `#7C4DFF` (Purple) | My Networking | Manage your connections, pending requests, and conversations — your networking hub all in one place |
| 4 | `chat_rounded` | `#00E676` (Green) | Chat & Call | Once connected, chat or voice call directly from My Networking — all messages appear in your Messages screen |

**Final CTA:** "Discover People" → Navigates to `CreateNetworkingProfileScreen(createdFrom: 'Networking')`

### UI/UX Details
- **Animations:** Staggered entry animations (icon slides from left/right, text slides opposite direction)
- **Floating icons:** Each icon gently bobs up and down with a unique phase offset
- **Pulsing borders:** Text card borders softly pulse in opacity
- **Page dots:** 3 dots at bottom showing current page position
- **Navigation:** Sequential (Page 1 → Page 2 → Page 3 → Profile Creation)
- **Theme:** Dark glassmorphic (dark gradient background, translucent cards with white borders)

---

## 3. Create Networking Profile Screen

**File:** `lib/screens/networking/create_networking_profile_screen.dart`
**Purpose:** Create a brand new networking profile. Users can create multiple profiles for different purposes.

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `createdFrom` | `String?` | No | Tracks where the profile was created from (e.g., 'Networking', 'Discover All', 'Smart', 'My Profile', 'My Profiles') |

### Form Fields

| Field | Type | Required | Validation | Default |
|-------|------|----------|------------|---------|
| Name | `TextEditingController` | Yes | Must not be empty | Empty |
| Profile Photo | Image (Gallery/Camera) | Yes | Must select image | None |
| About Me | `TextEditingController` | No | Max length varies | Empty |
| Occupation | `TextEditingController` | No | None | Empty |
| Gender | Dropdown | Yes | Must select one | None |
| Age Range | `RangeSlider` | Yes | Must be explicitly set | 18–60 |
| Distance Range | `RangeSlider` | No | None | 1–500 km |
| Location/City | Auto-loaded | Yes | Must not be empty | From user's main profile |
| Networking Category | Dropdown | Yes | Must select one | None |
| Networking Subcategory | Dropdown | No | Depends on category | None |
| Category-Specific Filters | Dropdown(s) | No | Depends on category/subcategory | Empty |
| Connection Types | Multi-select chips | No | None | Empty |
| Activities | Multi-select chips | No | None | Empty |
| Interests | Multi-select chips | No | None | Empty |
| Discovery Mode | Toggle | No | None | `true` (visible) |
| Allow Calls | Toggle | No | None | `true` |

### Save Validation (`_canSave`)
All of the following must be true:
- Name is not empty
- Photo is selected (new image OR existing URL)
- Age range is explicitly set by user
- Location/city is not empty
- Gender is selected

### Category Validation (on Save)
- Networking Category must be selected
- Gender must be selected

### Gender Options
`Male`, `Female`, `Non-binary`, `Other`

### Networking Categories (12 total)

| Category | Icon | Gradient Colors | Subcategories Count |
|----------|------|-----------------|---------------------|
| Professional | `business_center_rounded` | `#6366F1` → `#818CF8` | 10 |
| Business | `storefront_rounded` | `#10B981` → `#34D399` | 10 |
| Social | `groups_rounded` | `#EC4899` → `#F472B6` | 10 |
| Educational | `school_rounded` | `#F59E0B` → `#FBBF24` | 10 |
| Creative | `palette_rounded` | `#A855F7` → `#C084FC` | 10 |
| Tech | `computer_rounded` | `#3B82F6` → `#60A5FA` | 10 |
| Industry | `factory_rounded` | `#F97316` → `#FB923C` | 10 |
| Investment & Finance | `account_balance_rounded` | `#14B8A6` → `#2DD4BF` | 10 |
| Event & Meetup | `event_rounded` | `#EF4444` → `#F87171` | 10 |
| Community | `volunteer_activism_rounded` | `#8B5CF6` → `#A78BFA` | 10 |
| Personal Development | `self_improvement_rounded` | `#06B6D4` → `#22D3EE` | 10 |
| Global / NRI | `public_rounded` | `#D946EF` → `#E879F9` | 10 |

### Complete Subcategory List (120 total)

**Professional:** Job Seekers, Recruiters, Freelancers, Consultants, Remote Workers, Career Changers, Interns, Mentors, Resume Review, Interview Prep

**Business:** Startup Founders, Investors, Retailers, Wholesalers, Importers & Exporters, Franchise, E-commerce, B2B Services, Small Business, Partnerships

**Social:** Dating, Friendship, Casual Hangout, Party Buddies, Travel Companions, Roommates, Pen Pals, Neighbors, Nightlife, Coffee Meetups

**Educational:** Tutoring, Study Groups, Online Courses, Skill Exchange, Workshops, Exam Prep, Language Learning, Research, Coding Bootcamp, Certifications

**Creative:** Photography, Graphic Design, Music Production, Film Making, Writing & Blogging, Animation, Fashion Design, Interior Design, Crafts & DIY, Content Creation

**Tech:** Software Development, Web Development, Mobile Apps, AI & Machine Learning, Cybersecurity, Cloud Computing, Data Science, Blockchain, DevOps, UI/UX Design

**Industry:** Manufacturing, Construction, Logistics & Supply Chain, Agriculture, Mining & Energy, Textiles, Automotive, Pharmaceuticals, Food Processing, Real Estate

**Investment & Finance:** Stock Market, Mutual Funds, Real Estate Investment, Cryptocurrency, Insurance, Banking, Fintech, Angel Investing, Venture Capital, Financial Planning

**Event & Meetup:** Conferences, Workshops & Seminars, Hackathons, Networking Events, Cultural Events, Sports Events, Concerts & Music, Webinars, Trade Shows, Community Gatherings

**Community:** NGO & Nonprofits, Volunteering, Social Causes, Environmental, Health Awareness, Education Outreach, Animal Welfare, Elder Care, Women Empowerment, Youth Development

**Personal Development:** Fitness & Gym, Meditation & Yoga, Public Speaking, Leadership Skills, Time Management, Emotional Intelligence, Goal Setting, Mindfulness, Life Coaching, Book Club

**Global / NRI:** Immigration, Visa Assistance, Cultural Exchange, Overseas Jobs, Study Abroad, Diaspora Connect, International Trade, Relocation Help, Foreign Investment, NRI Services

### Category-Specific Filters (shown when category is selected)

Each category has 2–4 dropdown filters. Full list:

| Category | Filter 1 | Filter 2 | Filter 3 | Filter 4 |
|----------|----------|----------|----------|----------|
| Professional | Experience Level (Entry Level, Mid Level, Senior, Executive, Intern) | Employment Type (Full-Time, Part-Time, Contract, Freelance, Internship) | Work Mode (On-Site, Remote, Hybrid) | Industry (Technology, Healthcare, Finance, Education, Marketing, Legal, Manufacturing, Retail, Media, Government, Other) |
| Business | Business Stage (Idea Stage, Pre-Revenue, Early Revenue, Growth Stage, Established, Scaling) | Company Size (Solo, 2-10, 11-50, 51-200, 201-1000, 1000+) | Business Model (B2B, B2C, D2C, Marketplace, SaaS, Subscription) | Industry Sector (Technology, Retail, F&B, Healthcare, Manufacturing, Real Estate, Agriculture, Services, Logistics, Finance, Other) |
| Social | Availability (Now, Today, This Week, This Weekend, Flexible) | Interests (Music, Sports, Travel, Food, Art, Tech, Fitness, Reading, Gaming, Movies, Photography, Cooking) | Vibe (Chill, Energetic, Intellectual, Creative, Adventurous) | — |
| Educational | Skill Level (Beginner, Intermediate, Advanced, Expert) | Format (In-Person, Online Live, Self-Paced, Hybrid) | Subject (Mathematics, Science, Languages, Programming, Business, Arts, Music, Test Prep, Other) | Language (English, Hindi, Spanish, French, Mandarin, Arabic, German, Japanese, Other) |
| Creative | Skill Level (Hobbyist, Beginner, Intermediate, Professional, Expert) | Collaboration (Hire Me, Looking to Hire, Collaborate, Learn Together, Mentor/Mentee) | Portfolio (Has Portfolio, No Portfolio) | — |
| Tech | Experience Level (Junior 0-2yr, Mid 2-5yr, Senior 5-10yr, Lead/Architect 10+yr) | Tech Stack (Python, JavaScript, TypeScript, Java, C++, Go, Rust, Swift, Kotlin, Dart, Flutter, React) | Purpose (Hire, Get Hired, Collaborate, Learn, Mentor, Open Source) | — |
| Industry | Business Role (Manufacturer, Supplier, Distributor, Buyer, Consultant, Service Provider) | Company Size (Micro 1-10, Small 11-50, Medium 51-200, Large 201-1000, Enterprise 1000+) | Trade Type (Local, National, International) | Certifications (ISO 9001, ISO 14001, GMP, HACCP, CE, FDA, BIS, Organic) |
| Investment & Finance | Experience (Beginner, Intermediate, Advanced, Professional) | Risk Appetite (Conservative, Moderate, Aggressive, Very Aggressive) | Investment Horizon (Short-Term <1yr, Medium 1-3yr, Long-Term 3-10yr, Very Long 10+yr) | Purpose (Invest, Raise Capital, Advise, Learn, Partner) |
| Event & Meetup | Event Format (In-Person, Online, Hybrid) | When (Today, This Week, This Weekend, This Month) | Time of Day (Morning, Afternoon, Evening, Night) | Price (Free, Paid) |
| Community | Involvement (Volunteer, Donate, Organize, Advocate, Mentor) | Commitment (One-Time, Weekly, Monthly, Ongoing, Seasonal) | Cause Area (Education, Health, Environment, Poverty, Human Rights, Animals, Arts & Culture, Technology) | Skills Offered (Teaching, Medical, Technical, Legal, Marketing, Fundraising, Counseling, Creative) |
| Personal Development | Level (Beginner, Intermediate, Advanced) | Format (In-Person, Online Live, Self-Paced, Group, 1-on-1) | Session Duration (15 min, 30 min, 45 min, 1 hr, 2 hr) | Goal (Weight Loss, Muscle Gain, Flexibility, Stress Relief, Focus, Confidence, Leadership) |
| Global / NRI | Destination (USA, Canada, UK, Australia, Germany, UAE, Singapore, New Zealand, Other) | Service Type (Consultation, Documentation, Representation, Guidance, Community) | Urgency (Immediate, Within 1 Month, Within 3 Months, Within 6 Months, Planning Ahead) | Language (English, Hindi, Gujarati, Punjabi, Tamil, Telugu, Bengali, Marathi) |

### Subcategory-Specific Filters (shown when subcategory is selected)

Over 50 subcategories have their own additional filters. Key examples:

| Subcategory | Filters |
|-------------|---------|
| Job Seekers | Education (High School, Associate, Bachelor's, Master's, PhD, Self-Taught) |
| Freelancers | Project Type (Hourly, Fixed-Price, Retainer, Equity) |
| Startup Founders | Funding Stage (Bootstrapped, Pre-Seed, Seed, Series A, Series B, Series C+) |
| Dating | Relationship Goal (Serious, Casual, Open to Anything), Lifestyle (Non-Smoker, Social Drinker, Vegetarian, Fitness Lover, Pet Lover) |
| Travel Companions | Travel Style (Budget, Mid-Range, Luxury, Backpacking), Trip Duration (Weekend, 1 Week, 2+ Weeks, Long-Term) |
| Exam Prep | Exam Type (SAT, GRE, GMAT, IELTS, TOEFL, UPSC, CAT, JEE, NEET, Other) |
| AI & Machine Learning | Subfield (NLP, Computer Vision, Deep Learning, Generative AI, MLOps, Reinforcement Learning) |
| Cryptocurrency | Token Type (Layer 1, Layer 2, DeFi, NFT, Stablecoin, Meme) |
| Hackathons | Theme (AI, Web3, FinTech, HealthTech, Social Good, Open), Team Size (Solo, 2-3, 4-5, Open) |
| Study Abroad | Degree Level (Undergraduate, Postgraduate, PhD, Diploma, Certificate, Short Course), Intake (Fall, Spring, Summer, Rolling) |
| Fitness & Gym | Workout Type (Strength, Cardio, CrossFit, HIIT, Calisthenics, Functional), Fitness Goal (Weight Loss, Muscle Gain, Endurance, Flexibility, General Fitness) |

*(Full list available in `networking_constants.dart` → `subcategoryFilters`)*

### Image Picker Options
- **Gallery:** Pick from device gallery (quality: 95%, max: 1920x1920)
- **Camera:** Take a new photo (quality: 95%, max: 1920x1920)
- Shown in a dialog with "Change Photo" title

### Data Flow (on Save)

1. Upload image to Firebase Storage → `networking_profile_images/{uid}_{timestamp}.jpg`
2. Save profile data to Firestore subcollection → `networking_profiles/{uid}/profiles/{auto-id}`
3. Also set as active top-level profile → `networking_profiles/{uid}` (merge)
4. Returns `true` to previous screen on success

### Firestore Document Structure (saved)

```json
{
  "userId": "string",
  "name": "string",
  "photoUrl": "string",
  "aboutMe": "string",
  "occupation": "string",
  "age": 25,
  "ageRangeStart": 18,
  "ageRangeEnd": 35,
  "gender": "Male",
  "discoveryModeEnabled": true,
  "allowCalls": true,
  "distanceRangeStart": 1,
  "distanceRangeEnd": 500,
  "city": "Mumbai",
  "location": "Mumbai",
  "latitude": 19.076,
  "longitude": 72.877,
  "networkingCategory": "Professional",
  "networkingSubcategory": "Job Seekers",
  "connectionTypes": ["Networking", "Mentorship"],
  "activities": ["Running", "Photography"],
  "interests": ["Technology", "Business"],
  "categoryFilters": {
    "Experience Level": "Mid Level",
    "Employment Type": "Full-Time"
  },
  "createdFrom": "Networking",
  "createdAt": "ServerTimestamp"
}
```

---

## 4. Edit Networking Profile Screen

**File:** `lib/screens/networking/edit_networking_profile_screen.dart`
**Purpose:** Edit the currently active networking profile. Pre-fills all fields from existing data.

### Key Differences from Create Screen

| Feature | Create Screen | Edit Screen |
|---------|--------------|-------------|
| Pre-fill data | Only location from main profile | All fields from `networking_profiles/{uid}` |
| Image upload path | `networking_profile_images/{uid}_{timestamp}.jpg` | `networking_profile_images/{uid}.jpg` |
| Photo migration | No | Yes — auto-migrates old photos from shared `profile_images/` to dedicated `networking_profile_images/` path |
| Save behavior | Creates new doc in subcollection + sets active | Updates only the top-level active doc (merge) |
| Loading state | No | Yes — shows loading indicator while fetching existing data |
| `_ageExplicitlySet` check | Yes (must explicitly interact) | No (loaded from existing data) |

### Data Loading Priority

1. First tries `networking_profiles/{uid}` (networking-specific data)
2. Falls back to `users/{uid}` for legacy data
3. Always fetches `users/{uid}` separately for lat/lon (kept current by location service)

### Form Fields (identical to Create)

Same fields as Create screen — Name, Photo, About Me, Occupation, Gender, Age Range, Distance Range, Location, Category, Subcategory, Category Filters, Connection Types, Activities, Interests, Discovery Mode, Allow Calls.

### Photo Migration Logic

If the current photo URL doesn't contain `networking_profile_images`, the system:
1. Downloads the old photo via HTTP
2. Re-uploads to `networking_profile_images/{uid}.jpg`
3. Updates the URL — prevents conflict with main account photo

### Data Flow (on Save)

1. Upload image (if changed) to Firebase Storage → `networking_profile_images/{uid}.jpg`
2. Update top-level active profile → `networking_profiles/{uid}` (merge)
3. Returns `true` to previous screen on success

---

## 5. My Networking Profile Screen

**File:** `lib/screens/networking/my_networking_profile_screen.dart`
**Purpose:** View-only screen showing the current user's active networking profile with all details.

### Data Loading Priority

1. First tries `networking_profiles/{uid}` (active profile)
2. Falls back to `users/{uid}` for legacy profiles

### Displayed Information

| Section | Fields Shown |
|---------|-------------|
| Profile Card | Photo (avatar), Name, Occupation (subtitle) |
| Discovery Status | Green dot + "Visible in Discovery" / Grey dot + "Hidden from Discovery" |
| About Me | Full text of aboutMe field |
| Networking Category | Category badge with subcategory (if set) |
| Profile Details | Category-specific filter key-value pairs (e.g., "Experience Level: Senior") |
| Basic Information | Gender, Age Range (e.g., "18 - 35"), Distance (e.g., "1 km - 500+ km"), City |

### Location Protection (Mountain View City Filter)
- **City display:** If `city.toLowerCase().contains('mountain view')` → city shown as empty string (not displayed)
- Reads `city` from `data['city']` or `data['location']` (whichever is available)

### Actions

| Action | Button Location | Behavior |
|--------|----------------|----------|
| Edit Profile | Bottom navigation bar | Navigates to `EditNetworkingProfileScreen` |
| Create Profile | Empty state button | Navigates to `CreateNetworkingProfileScreen(createdFrom: 'My Profile')` |
| Go Back | AppBar back button | `Navigator.pop(context)` |

### Empty State
- Icon: `person_outline_rounded`
- Title: "No Profile Yet"
- Message: "Create your networking profile to start connecting with people."
- Button: "Create Profile"

### UI Components Used
- `NetworkingWidgets.networkingAppBar` — Glassmorphic app bar
- `NetworkingWidgets.profileAvatarCard` — Profile photo + name card
- `NetworkingWidgets.infoCard` — Discovery status indicator
- `NetworkingWidgets.sectionTitle` — Section headers
- `NetworkingWidgets.textCard` — About me text card
- `NetworkingWidgets.categoryBadge` — Category + subcategory badge
- `NetworkingWidgets.detailRow` — Key-value detail rows
- `NetworkingWidgets.bottomActionButton` — Bottom "Edit Profile" button

---

## 6. Networking Profiles Page Screen

**File:** `lib/screens/networking/networking_profiles_page_screen.dart`
**Purpose:** View and manage ALL saved networking profiles. Supports multiple profiles, switching active profile, and deleting profiles.

### Data Loading

1. Loads all profiles from subcollection → `networking_profiles/{uid}/profiles/*`
2. Deduplicates by document ID
3. If subcollection is empty, migrates top-level doc to subcollection (one-time migration)
4. Falls back to top-level doc on error

### Profile Card Information

Each card displays:

| Field | Source Key | Display |
|-------|-----------|---------|
| Name | `name` | Bold title text |
| Photo | `photoUrl` | Circular avatar with online indicator |
| Occupation | `occupation` | Subtitle below name |
| Category | `networkingCategory` | Info chip with category icon |
| Subcategory | `networkingSubcategory` | Separate line with category icon |
| Age | `age` | Info chip (e.g., "25 yrs") |
| Gender | `gender` | Info chip |
| Distance | Calculated from lat/lng | Info chip (e.g., "2.5 km") |
| Interests | `interests` | Tag chip wrap (max 4 shown) |
| Discovery Status | `discoveryModeEnabled` | Green/grey dot on avatar |
| Created From | `createdFrom` | Badge at top-right (e.g., "Smart", "Discover All") |
| Created At | `createdAt` | Timestamp (e.g., "15 Jan 2026, 03:45 PM") |

### Location Protection (Mountain View City Filter)
- **City display:** If `city.toLowerCase().contains('mountain view')` → city shown as empty string (not displayed)
- Applied to each profile card's city/location info chip

### Created From Icons

| Source | Icon |
|--------|------|
| Discover All | `explore_outlined` |
| Smart | `auto_awesome_outlined` |
| My Profiles | `account_box_outlined` |
| My Profile | `person_outline_rounded` |
| Other | `add_circle_outline_rounded` |

### Actions per Profile Card

| Action | Button | Behavior |
|--------|--------|----------|
| Switch Profile | Blue button "Switch Profile" | Shows confirmation dialog → copies profile data to top-level `networking_profiles/{uid}` with `discoveryModeEnabled: true` |
| Delete Profile | Red button "Delete Profile" | Shows confirmation dialog → deletes from subcollection → if last profile, deletes top-level doc too → if other profiles remain, auto-switches to first remaining |

### Switch Profile Dialog
- Glassmorphic dialog with blur backdrop
- Shows category-colored strip at top
- Icon: `swap_horiz_rounded`
- Title: "Switch Profile"
- Message: 'Switch to "{name}" in the networking screen?'
- Buttons: Cancel / Switch (red gradient)

### Delete Profile Dialog
- Standard AlertDialog (dark background)
- Title: "Delete Profile"
- Message: 'Are you sure you want to delete "{name}"? This cannot be undone.'
- Buttons: Cancel / Delete (red background)

### Delete Behavior
- If more profiles remain → switches active to first remaining profile, shows success message
- If last profile → deletes top-level doc, navigates back to previous screen

---

## 7. Live Connect Tab Screen

**File:** `lib/screens/networking/live_connect_tab_screen.dart`
**Purpose:** The main discovery screen with 2 tabs (Discover All / Smart) for browsing and connecting with other users. Features mosaic card grid, advanced filters, search, voice search, and pagination.

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `activateNearMeFilter` | `bool` | `false` | Pre-activate "Near Me" location filter on init |
| `activateNetworkingFilter` | `bool` | `false` | Pre-activate Smart networking filter on init |

### Tabs

| Tab | Name | Behavior |
|-----|------|----------|
| 1 | Discover All | Shows all users worldwide, no interest filters |
| 2 | Smart | Shows filtered results based on Smart matching (category, location, etc.) |

### Filter System

#### Location Filter Options
- `Worldwide` — No location restriction
- `Near me` — Uses device GPS
- `City` — Matches user's city
- `Country` — Matches user's country
- `Smart` — AI-based smart matching

#### Available Filters

| Filter | Type | Options |
|--------|------|---------|
| Networking Category | Single-select chips | All, Professional, Business, Social, Educational, Creative, Tech, Industry, Investment & Finance, Event & Meetup, Community, Personal Development, Global / NRI |
| Subcategory | Single-select dropdown | Depends on selected category (10 per category) |
| Gender | Multi-select | Male, Female, Non-binary, Other |
| Age Range | Range slider | 18–60+ |
| Distance Range | Range slider | 1–500+ km |
| Online Only | Toggle | Show only online users |
| Interests | Multi-select chips | Dating, Friendship, Business, Roommate, Job Seeker, Hiring, Selling, Buying, Lost & Found, Events, Sports, Travel, Food, Music, Movies, Gaming, Fitness, Art, Technology, Photography, Fashion |
| Connection Types | Multi-select (grouped) | See below |
| Activities | Multi-select (grouped) | See below |
| Category-Specific Filters | Dropdowns | Depends on selected category (from `NetworkingConstants.categoryFilters`) |

#### Connection Type Groups

| Group | Options |
|-------|---------|
| Social | Dating, Friendship, Casual Hangout, Travel Buddy, Nightlife Partner |
| Professional | Networking, Mentorship, Business Partner, Career Advice, Freelancing |
| Educational | Study Group, Tutoring, Language Exchange, Skill Sharing, Exam Prep |
| Creative | Music Jam, Art Collaboration, Photography, Content Creation, Film Making |
| Community | Volunteering, Social Causes, Environmental, Community Service, Youth Development |
| Other | Roommate, Pet Playdate, Gaming, Online Friends, Event Companion |

#### Activity Groups

| Group | Options |
|-------|---------|
| Sports | Tennis, Badminton, Basketball, Football, Volleyball, Golf, Table Tennis, Squash |
| Fitness | Running, Gym, Yoga, Pilates, CrossFit, Cycling, Swimming, Dance |
| Outdoor | Hiking, Rock Climbing, Camping, Kayaking, Surfing, Mountain Biking, Trail Running |
| Creative | Photography, Painting, Music, Writing, Cooking, Crafts, Gaming |

### User Card (Mosaic Grid)

Each card displays:
- **Full-bleed profile photo** (or gradient placeholder with initial)
- **Name + Age** (bottom glassmorphic overlay)
- **Occupation** (below name)
- **Distance** (with location icon)
- **Online indicator** (green/grey dot)
- **Category badge** (if available)

### Search
- Text search bar with voice search capability (via `VoiceSearchMixin`)
- Filters users by name match

### Pagination
- Loads 20 users per page
- Infinite scroll with "load more" on scroll end
- `_lastDocument` for Firestore cursor-based pagination

### Connection Status Caching
- Caches connection status per userId → `Map<String, bool>`
- Caches request status per userId → `Map<String, String?>` ('sent', 'received', null)
- **Static class-level caches** (`_globalConnectionStatusCache`, `_globalRequestStatusCache`) survive widget rebuilds
- Filters out already-connected and pending-request users from discovery
- `updateConnectionCache()` method for real-time updates

### Static Cache System (Performance Optimization)
All caches are **static class-level variables** tied to the current user UID, surviving widget rebuilds:
- `_cachedUserId` — Current user ID (cache invalidation key)
- `_cachedNearbyPeople` — List of discovered profiles
- `_cachedUserProfile` — Current user's networking profile data
- `_cachedMyConnections` — Set of connected user IDs
- `_cachedPendingRequestUserIds` — Set of pending request user IDs
- `_cachedSelectedInterests` — Selected interests list
- `_cachedUserLat/Lon` — Cached coordinates
- `_cachedTimestamp` — When cache was last populated
- `_hasEverLoaded` — Prevents showing loading spinner on revisit

### Location Strategy (Non-blocking GPS)
1. **Immediate:** Uses profile lat/lng from `users/{uid}` — shows results instantly
2. **Background:** Kicks off `_refreshLocationInBackground()` to get fresh GPS (via `IpLocationService.detectLocation()`)
3. **GPS cache:** `IpLocationService` caches GPS results for 2 minutes (avoids repeated GPS calls)
4. **Debounce:** Location refresh suppressed if last refresh was < 90 seconds ago
5. **On GPS complete:** Silently reloads nearby people with updated coordinates (`silent: true` — no spinner)
6. **Firestore fallback:** If GPS fails, reads location from `users/{uid}` document

### Location Protection (Mountain View / Null-Island Rejection)
For **other users' profiles** displayed in the grid:
- **Mountain View city check:** If `city.toLowerCase().contains('mountain view')` → lat/lng set to `null`
- **Null-island check:** If `lat.abs() < 0.01 && lng.abs() < 0.01` → lat/lng set to `null`
- **Distance filter:** If calculated distance `> 10,000 km` → distance not displayed
- Applied when reading from `networking_profiles` collection

For **current user's location:**
- Same Mountain View + null-island rejection when reading from Firestore
- Stale coordinates discarded, fresh GPS detection triggered

### Card Animation
- `FloatingCard` widget — each card gently bobs up and down
- Different animation phase per card index for organic feel

### Data Sources
- User profile: `users/{uid}` (for location)
- Networking interests: `networking_profiles/{uid}` (for interests)
- People list: `networking_profiles` collection (discovery) + `users` collection (fallback)

---

## 8. Pending Requests Screen

**File:** `lib/screens/networking/pending_requests_screen.dart`
**Purpose:** Shows all pending connection requests (both sent and received) in a 2-column mosaic grid with real-time updates.

### Data Source
- Real-time stream via `ConnectionService.getPendingRequestsStream()`
- Deduplicates by sender ID
- Sorted by `createdAt` (newest first)

### Card Information

Each request card shows:

| Field | Source | Display |
|-------|--------|---------|
| Name | Fresh fetch from `networking_profiles/{userId}` or `users/{userId}`, fallback to stored name | Name + Age at bottom |
| Photo | Fresh fetch, fallback to stored photo | Full-bleed image or gradient placeholder |
| Age | Fresh fetch or calculated from DOB | After name (e.g., "John, 25") |
| Occupation | Fresh fetch, fallback to stored | Below name |
| Distance | Calculated from user lat/lng | With location icon |
| Online status | `isOnline` field | Green/grey dot |
| Request Type | 'sent' or 'received' | Glass badge at top-left ("Sent" / "Received") |
| Time Ago | Calculated from `createdAt` | Glass badge at top-right (e.g., "2h ago") |

### Time Ago Format
- `< 1 min` → "Just now"
- `< 60 min` → "{n}m ago"
- `< 24 hours` → "{n}h ago"
- `< 7 days` → "{n}d ago"
- `>= 7 days` → "{n}w ago"

### Actions per Card

| Action | For Received Requests | For Sent Requests |
|--------|----------------------|-------------------|
| Confirm Button | Accept connection request | Cancel connection request |
| Delete Button | Reject connection request | Cancel connection request |
| Tap Card | Open `UserProfileDetailScreen` with full profile | Open `UserProfileDetailScreen` with full profile |

### Profile Data Resolution (for each request)

1. Tries `networking_profiles/{userId}` first
2. Falls back to `users/{userId}`
3. Falls back to stored data from connection request document
4. Name resolution: `name` → `displayName` → `phone` → stored name → "Unknown"

### Location Protection (Mountain View / Null-Island Rejection)

**For current user's coordinates (distance base):**
- Reads `city`, `latitude`, `longitude` from `users/{uid}`
- **Mountain View check:** If `city.toLowerCase().contains('mountain view')` → lat/lng set to `null`
- **Null-island check:** If `lat.abs() < 0.01 && lng.abs() < 0.01` → lat/lng set to `null`
- If coordinates rejected → distance calculation skipped for all cards

**For other user's fetched coordinates:**
- Same Mountain View + null-island rejection applied to fetched profile data
- **Distance filter:** If calculated distance `> 10,000 km` → distance not displayed
- Applied to both stored connection request data AND fresh-fetched user data

### Profile Caching
- `_profileCache` — Maps userId → profile data (avoids N+1 Firestore reads on stream re-emissions)
- `_fetchingProfiles` — Set of userIds currently being fetched (prevents duplicate concurrent fetches)

### Empty State
- Icon: `person_add_disabled_rounded`
- Title: "No pending requests"
- Message: "When someone sends you a connect request, it will appear here"

### Grid Layout
- 2 columns
- Cross-axis spacing: 12
- Main-axis spacing: 12
- Child aspect ratio: 0.85
- Padding: 15px horizontal, 12px top, 90px bottom
- Each card wrapped in `FloatingCard` animation

---

## 9. User Profile Detail Screen

**File:** `lib/screens/networking/user_profile_detail_screen.dart`
**Purpose:** Full-screen detailed view of another user's profile with connection, chat, and call actions.

### Constructor Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `user` | `ExtendedUserProfile` | Yes | The user profile to display |
| `connectionStatus` | `String?` | No | 'connected', 'sent', 'received', or null |
| `onConnect` | `Future<void> Function()?` | No | Callback when connect button is tapped (for received requests — accepts the request) |
| `selectedCategory` | `String?` | No | Category filter context from calling screen |
| `selectedSubcategory` | `String?` | No | Subcategory filter context from calling screen |

### Data Loading

- Fetches full profile from `networking_profiles/{uid}` first
- Falls back to `users/{uid}`
- Preserves distance value passed from previous screen
- Shows loading shimmer while fetching

### Location Protection (via ExtendedUserProfile Model)
- User data is passed as `ExtendedUserProfile` object
- **Mountain View rejection** is handled centrally in `ExtendedUserProfile.fromMap()`:
  - City containing "mountain view" → city set to `null`, coordinates set to `null`
  - Null-island (lat/lng < 0.01 abs) → coordinates set to `null`
- **Display helpers:**
  - `displayLocation` getter → rejects Mountain View, returns "Location not set" if empty
  - `formattedDistance` getter → returns `null` if distance > 10,000 km

### Screen Layout

#### Hero Image Section (45% of screen height)
- Full-width profile photo (or gradient placeholder with initial)
- Gradient overlay at bottom for readability
- Name + info overlay at bottom of image

#### Name Section
- Full name (bold, large)
- Age (if available)
- Online status dot (green/grey with glow)
- Occupation
- City/Location with location icon

#### Quick Info Row
- Category badge (gradient colored)
- Subcategory chip
- Distance chip (e.g., "2.5 km")

#### Networking Sections (from category data)
- Category-specific filter values displayed as detail rows
- Subcategory-specific filter values

#### About Section
- "About" header
- Full about me text in glassmorphic card

#### Connection Types
- "Looking For" header
- Chip list of connection types (e.g., "Networking", "Mentorship")

#### Activities
- "Activities" header
- Chip list of activities (e.g., "Running", "Photography")

#### Interests
- "Interests" header
- Chip list of interests (e.g., "Technology", "Business")

### Bottom Action Buttons (based on connection status)

| Status | Button 1 | Button 2 |
|--------|----------|----------|
| `null` (no connection) | "Connect" (blue) — sends connection request | — |
| `'sent'` | "Request Sent" (disabled/grey) | — |
| `'received'` | "Accept" (calls `onConnect`) | — |
| `'connected'` | "Message" (blue) → opens chat | "Call" (green) → starts voice call |

### AppBar Actions
- Back button (always)
- "Disconnect" button (red, only when `connectionStatus == 'connected'`)

### Disconnect Dialog
- Confirmation dialog before disconnecting
- Removes connection via `ConnectionService`

### Connection Request Flow
1. Sends connection request via `ConnectionService.sendConnectionRequest()`
2. Sends notification to receiver via `NotificationService`
3. Updates local state to show "Request Sent"
4. Updates parent screen's connection cache

### Chat Navigation
- Opens `EnhancedChatScreen` with:
  - `conversationId` (generated from sorted user IDs)
  - Receiver's profile data (name, photo, uid)

### Voice Call Navigation
- Opens `VoiceCallScreen` with:
  - Caller profile data
  - Receiver profile data
  - `isIncoming: false`

### Animations
- Fade-in animation on content load
- Shimmer animation on loading state
- Scroll-aware AppBar title (shows/hides based on scroll offset > 250)

---

## Shared Components

### networking_constants.dart
**File:** `lib/widgets/networking/networking_constants.dart`

Single source of truth for:
- Gender options (4)
- Category → Subcategory mapping (12 categories × 10 subcategories = 120)
- Category icons (rounded + flat variants)
- Category gradient colors (2-color gradients)
- Category flat colors (single color for chips)
- Category → Connection type group mapping
- Category → Activity group mapping
- Category-specific filters (dropdown options per category)
- Subcategory-specific filters (dropdown options per subcategory)
- Helper methods: `getCategoryColors()`, `getCategoryIcon()`, `getCategoryFlatColor()`

### networking_helpers.dart
**File:** `lib/widgets/networking/networking_helpers.dart`

Utility functions:
- `formatTimeAgo(DateTime)` — Human-readable time (e.g., "2h ago")
- `calcDistance(lat1, lon1, lat2, lon2)` — Haversine distance in km
- `resolveUserName(Map data)` — Resolves name from multiple fields (name → displayName → phone)
- `resolveOccupation(Map data)` — Resolves occupation from multiple fields (occupation → profession → category)
- `calcAgeFromDob(dynamic dob)` — Calculates age from Timestamp or String date
- `getAvatarGradient(String name)` — Returns unique gradient pair based on name hash (5 color combos: Pink, Blue, Orange, Purple, Green)
- `showSuccessSnackBar()` — Glassmorphic green snackbar
- `showErrorSnackBar()` — Glassmorphic red snackbar
- `showWarningSnackBar()` — Glassmorphic orange snackbar
- `showSnackBar()` — Backward-compatible wrapper

### networking_widgets.dart
**File:** `lib/widgets/networking/networking_widgets.dart`

Reusable UI components:
- `networkingAppBar()` — Glassmorphic AppBar
- `bodyGradient()` — Standard dark gradient background
- `loadingIndicator()` — Centered loading spinner
- `emptyState()` — Empty state with icon, title, message, optional button
- `profileAvatarCard()` — Profile photo + name glassmorphic card
- `infoCard()` — Icon + label info card
- `sectionTitle()` — Section header text
- `textCard()` — Text content glassmorphic card
- `categoryBadge()` — Category + subcategory badge
- `detailRow()` — Key-value detail row
- `bottomActionButton()` — Bottom fixed action button
- `infoChip()` — Small info chip with icon
- `tagChipWrap()` — Wrap of tag chips
- `glassBadge()` — Small glassmorphic badge (for "Sent", "Received", time ago)

---

## Firestore Collections Used

| Collection | Usage |
|------------|-------|
| `networking_profiles/{uid}` | Active networking profile (top-level doc) |
| `networking_profiles/{uid}/profiles/*` | All saved networking profiles (subcollection) |
| `users/{uid}` | Main user profile (for location, fallback data) |
| `connection_requests/*` | Connection requests between users |
| `conversations/*` | Chat conversations |
| `notifications/*` | Push notification records |

---

## Navigation Flow

```
Bottom Navigation Bar (Tab Index 2)
  └── Networking Screen (Main Container)
        │
        ├── [No Profile] → Onboarding Networking Screen (3 pages)
        │     └── Page 1: Getting Started → Page 2: Features → Page 3: Explore Tabs
        │           └── "Discover People" → Create Networking Profile Screen
        │
        └── [Has Profile] → Full Networking Screen
              │
              ├── AppBar:
              │     ├── [Avatar] → My Networking Profile Screen
              │     │     ├── Edit Profile → Edit Networking Profile Screen
              │     │     └── Create Profile → Create Networking Profile Screen
              │     ├── [Pending Badge] → Pending Requests Screen
              │     │     └── Tap card → User Profile Detail Screen
              │     └── [Filter] → Filter Dialog (Smart Connect tab only)
              │
              ├── Tab 1: Discover All (LiveConnectTabScreen)
              │     ├── Search bar (text + voice)
              │     └── Tap user card → User Profile Detail Screen
              │           ├── Connect → sends request
              │           ├── Message → Enhanced Chat Screen
              │           └── Call → Voice Call Screen
              │
              ├── Tab 2: Smart Connect (LiveConnectTabScreen)
              │     ├── Search bar (text + voice)
              │     ├── Category/Subcategory filters
              │     └── Tap user card → User Profile Detail Screen
              │
              ├── Tab 3: My Network (inline)
              │     └── Tap connection card → User Profile Detail Screen
              │           ├── Message → Enhanced Chat Screen
              │           ├── Call → Voice Call Screen
              │           └── Disconnect → removes connection
              │
              └── FAB (+) → Create Networking Profile Screen
                    (hidden on My Network tab or if 3+ profiles)

App Drawer:
  └── "Networking Profile" → Networking Profiles Page Screen
        ├── Switch Profile → sets as active
        └── Delete Profile → removes
```

---

## Design System

### Color Theme
- **Background:** Pure black (`#000000`) with gradient overlays
- **Gradient:** `#404040` → `#282828` → `#000000` (top to bottom)
- **Cards:** Glassmorphic (white at 15-25% opacity, white border at 25-40% opacity, backdrop blur)
- **Primary Blue:** `#007AFF`
- **Accent Red:** `#E53935` / `#B71C1C`
- **Success Green:** `#00E676`
- **Text:** White (100% / 90% / 70% / 50% opacity levels)

### Typography
- **Font Family:** Poppins (throughout)
- **Headings:** 16-17px, FontWeight.w700
- **Body:** 13-14px, FontWeight.w400-w500
- **Chips/Badges:** 9-12px, FontWeight.w500-w700

### Animations
- Staggered entry (icon + text slide in)
- Floating cards (gentle vertical bobbing)
- Pulsing elements (border opacity oscillation)
- Fade transitions (content fade-in on load)
- Shimmer effects (loading placeholders)

### Haptic Feedback
- `HapticFeedback.lightImpact()` — on tap, navigation, filter selection
- `HapticFeedback.mediumImpact()` — on confirm/delete actions

---

## Location Protection System (Mountain View / Null-Island Rejection)

All networking screens implement a **3-layer location protection** system to prevent stale/invalid coordinates from being displayed:

### Layer 1: Central Model Protection (`ExtendedUserProfile.fromMap()`)
- **Mountain View city check:** `city.toLowerCase().contains('mountain view')` → `latitude`, `longitude`, `city` all set to `null`
- **Null-island check:** `lat.abs() < 0.01 && lng.abs() < 0.01` → `latitude`, `longitude` set to `null`
- Applied automatically whenever `ExtendedUserProfile` is created from Firestore data

### Layer 2: Per-Screen Firestore Read Protection
Each screen that reads user coordinates from Firestore independently checks:
- City string for "mountain view" (case-insensitive)
- Coordinates for null-island (both lat and lng absolute value < 0.01)
- Screens with this protection: `LiveConnectTabScreen`, `PendingRequestsScreen`, `MainNavigationScreen` (My Network tab)

### Layer 3: Distance Sanity Filter
- Any calculated distance `> 10,000 km` is treated as invalid and not displayed
- Applied in: `PendingRequestsScreen`, `MainNavigationScreen`, `ExtendedUserProfile.formattedDistance`

### City Display Filter
- Screens that display city names filter out "Mountain View": `MyNetworkingProfileScreen`, `NetworkingProfilesPageScreen`
- If city contains "mountain view" → displayed as empty string

### GPS Caching (`IpLocationService`)
- Fresh GPS results cached for **2 minutes** to avoid repeated GPS hardware calls
- Cache key: static `_cachedLocation` + `_cachedAt` timestamp
- On cache hit → returns immediately without GPS polling

### Summary of Protection by Screen

| Screen | MV City Check | Null-Island Check | Distance > 10K Filter | City Display Filter |
|--------|:---:|:---:|:---:|:---:|
| LiveConnectTabScreen (Around Me) | ✅ | ✅ | ✅ | — |
| MainNavigationScreen (My Network) | ✅ | ✅ | ✅ | — |
| PendingRequestsScreen | ✅ | ✅ | ✅ | — |
| MyNetworkingProfileScreen | — | — | — | ✅ |
| NetworkingProfilesPageScreen | — | — | — | ✅ |
| UserProfileDetailScreen | ✅ (via model) | ✅ (via model) | ✅ (via model) | ✅ (via model) |
| ExtendedUserProfile (model) | ✅ | ✅ | ✅ | ✅ |

---

## Performance Optimizations

### ConnectionService — Parallel Firestore Queries
Previously, `getUserConnections()` ran 3 sequential Firestore queries. Now uses `Future.wait()` to run all 3 in parallel:
1. Read `networking_profiles/{uid}` connections array
2. Query `connection_requests` where receiver + accepted
3. Query `connection_requests` where sender + accepted

Same optimization applied to `getPendingRequestUserIds()` (2 parallel queries).

### LiveConnectTabScreen — Non-blocking GPS
- Profile lat/lng used **immediately** from Firestore (no waiting for GPS)
- GPS detection runs in **background** via `_refreshLocationInBackground()`
- On GPS complete → silently reloads people list with updated coordinates
- GPS cache (2 min via `IpLocationService`) prevents repeated hardware polls
- Location refresh **debounced** at 90-second intervals

### LiveConnectTabScreen — Static Cache
- All major data (nearby people, connections, profile, interests, coordinates) cached as **static class-level variables**
- Cache tied to current user UID — invalidated on user switch
- Cache timestamp tracks freshness — background refresh after 30 seconds
- `_hasEverLoaded` flag prevents showing loading spinner on tab revisit

### Pagination
- 20 users per page with `DocumentSnapshot` cursor-based pagination
- Infinite scroll triggers next page load
- `_isLoadingMore` flag prevents duplicate page loads

---

## Firebase Schema — All 9 Screens

### Collections Overview

| Collection | Purpose |
|-----------|---------|
| `networking_profiles/{uid}` | Top-level active networking profile for each user |
| `networking_profiles/{uid}/profiles/{profileId}` | Subcollection holding multiple profiles per user |
| `connection_requests/{requestId}` | Connection requests between users |
| `users/{uid}` | Base user account data (read for name, photo, location) |
| `calls/{callId}` | Voice call signaling documents |
| `notifications/{notifId}` | Cross-user notifications |
| `conversations/{convId}` | Chat conversations (for missed call messages) |
| `conversations/{convId}/messages/{msgId}` | Chat messages subcollection |

---

### Screen 1 — Networking Screen (Main Container)

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** (stream) | `networking_profiles/{uid}/profiles` | Listens to subcollection count to decide onboarding vs tabs |
| **READ** (stream) | `calls` | Listens for incoming calls where `receiverId == currentUser.uid` |
| **READ** (stream) | `conversations` | Listens for unread message counts |
| **WRITE** | `users/{uid}` | Updates `isOnline` (bool), `lastSeen` (Timestamp) |
| **WRITE** | `calls/{callId}` | Updates status to `ringing`, `missed`, `rejected` |
| **WRITE** | `conversations/{convId}` | Creates conversation for missed calls |
| **WRITE** | `conversations/{convId}/messages/{msgId}` | Creates missed call message documents |

---

### Screen 2 — Onboarding Networking Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| — | — | No Firestore operations. Pure UI screen with animated onboarding steps. |

---

### Screen 3 — Create Networking Profile Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** | `users/{uid}` | Pre-fills name, photoUrl, bio, gender, age, dateOfBirth, location, interests |
| **WRITE** | `networking_profiles/{uid}/profiles` | Creates new profile document via `.add()` |
| **WRITE** | `networking_profiles/{uid}` | Sets active profile via `.set(merge: true)` with `_activeSubDocId` |
| **UPLOAD** | Firebase Storage | Uploads photo to `networking_photos/{uid}/{timestamp}.jpg` |

---

### Screen 4 — Edit Networking Profile Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** | `networking_profiles/{uid}` | Reads current active profile to pre-fill form fields |
| **READ** | `users/{uid}` | Fallback for location data (latitude, longitude, city) |
| **WRITE** | `networking_profiles/{uid}` | Updates top-level doc via `.set(merge: true)` |
| **WRITE** | `networking_profiles/{uid}/profiles/{_activeSubDocId}` | Updates matching subcollection doc via `.set(merge: true)` |
| **UPLOAD** | Firebase Storage | Uploads updated photo to `networking_photos/{uid}/{timestamp}.jpg` |

---

### Screen 5 — My Networking Profile Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** | `networking_profiles/{uid}` | Reads active networking profile for display |
| **READ** | `users/{uid}` | Fallback read if no networking profile exists |
| — | — | Display-only screen; navigates to Create/Edit screens |

---

### Screen 6 — Networking Profiles Page Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** | `networking_profiles/{uid}/profiles` | Queries all profiles via `.limit(50).get()` |
| **READ** | `networking_profiles/{uid}` | Migration fallback if subcollection is empty |
| **WRITE** | `networking_profiles/{uid}/profiles/{autoId}` | Migration: copies top-level data into subcollection |
| **WRITE** | `networking_profiles/{uid}` | Switches active profile; deletes last profile's top-level doc |
| **DELETE** | `networking_profiles/{uid}/profiles/{subDocId}` | Deletes a specific profile |

---

### Screen 7 — Live Connect Tab Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** | `users` | Batch-queries online status with `where('isOnline', isEqualTo: true)` |
| **READ** | `networking_profiles` | Queries all with `where('discoveryModeEnabled', isEqualTo: true).limit(fetchSize)` |
| **READ** | `connection_requests` | Via `ConnectionService.getUserConnections()` and `getPendingRequestUserIds()` |
| — | — | No direct writes; delegates to `ConnectionService` |

---

### Screen 8 — Pending Requests Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** (stream) | `connection_requests` | Streams where `receiverId == currentUser.uid AND status == 'pending'` |
| **READ** | `networking_profiles/{otherUserId}` | Fetches other user's profile for display |
| **READ** | `users/{otherUserId}` | Fallback if networking profile doesn't exist |
| **READ** | `users/{currentUid}` | Reads current user's location for distance calculation |
| **WRITE** (via service) | `connection_requests/{requestId}` | Accept/reject/cancel via `ConnectionService` |

---

### Screen 9 — User Profile Detail Screen

| Operation | Collection | Details |
|-----------|-----------|---------|
| **READ** | `networking_profiles/{user.uid}` | Fetches full profile of viewed user |
| **READ** | `users/{user.uid}` | Fallback if networking profile doesn't exist |
| **READ** | `users/{currentUserId}` | Reads current user's name and photo for voice call |
| **WRITE** | `calls` | Creates new call document for voice calling |
| **WRITE** | `notifications` | Sends call/connection notifications via `NotificationService` |
| **WRITE** (via service) | `connection_requests` | Disconnect via `ConnectionService.removeConnection()` |

---

### Document Schema — `networking_profiles/{uid}`

| Field | Type | Example |
|-------|------|---------|
| `userId` | string | `"abc123"` |
| `name` | string | `"John Doe"` |
| `photoUrl` | string | `"https://firebasestorage..."` |
| `aboutMe` | string | `"Software developer..."` |
| `occupation` | string | `"Software Engineer"` |
| `dateOfBirth` | string | `"1995-03-15"` |
| `age` | int | `30` |
| `gender` | string | `"Male"` / `"Female"` / `"Non-binary"` / `"Other"` |
| `discoveryModeEnabled` | bool | `true` |
| `allowCalls` | bool | `true` |
| `distanceRangeStart` | int | `1` (km) |
| `distanceRangeEnd` | int | `500` (km) |
| `city` | string | `"New York"` |
| `location` | string | `"New York"` |
| `latitude` | double | `40.7128` |
| `longitude` | double | `-74.0060` |
| `networkingCategory` | string | `"Professional"` |
| `networkingSubcategory` | string | `"Job Seekers"` |
| `connectionTypes` | List\<string\> | `["Networking", "Mentorship"]` |
| `activities` | List\<string\> | `["Tennis", "Running"]` |
| `interests` | List\<string\> | `["Dating", "Business"]` |
| `categoryFilters` | Map\<string, string\> | `{"Experience Level": "Senior"}` |
| `createdFrom` | string? | `"Networking"` / `"My Profile"` |
| `createdAt` | Timestamp | Server timestamp |
| `_activeSubDocId` | string | Subcollection doc ID |
| `connections` | List\<string\> | Array of connected user UIDs |
| `connectionCount` | int | `5` |

---

### Document Schema — `connection_requests/{requestId}`

| Field | Type | Example |
|-------|------|---------|
| `senderId` | string | `"user1_uid"` |
| `senderName` | string | `"John Doe"` |
| `senderPhoto` | string? | `"https://..."` |
| `senderAge` | int? | `28` |
| `senderOccupation` | string? | `"Engineer"` |
| `senderLatitude` | double? | `40.7128` |
| `senderLongitude` | double? | `-74.0060` |
| `receiverId` | string | `"user2_uid"` |
| `receiverName` | string | `"Jane Smith"` |
| `receiverPhoto` | string? | `"https://..."` |
| `receiverAge` | int? | `25` |
| `receiverOccupation` | string? | `"Designer"` |
| `receiverLatitude` | double? | `34.0522` |
| `receiverLongitude` | double? | `-118.2437` |
| `message` | string? | Optional connection message |
| `status` | string | `"pending"` / `"accepted"` / `"rejected"` |
| `createdAt` | Timestamp | Server timestamp |
| `updatedAt` | Timestamp | Server timestamp |

---

### Document Schema — `calls/{callId}`

| Field | Type | Example |
|-------|------|---------|
| `callerId` | string | Current user's UID |
| `receiverId` | string | Viewed user's UID |
| `callerName` | string | `"John Doe"` |
| `callerPhoto` | string | `"https://..."` |
| `receiverName` | string | `"Jane Smith"` |
| `receiverPhoto` | string | `"https://..."` |
| `participants` | List\<string\> | `[callerId, receiverId]` |
| `status` | string | `"calling"` / `"ringing"` / `"missed"` / `"ended"` / `"rejected"` |
| `type` | string | `"audio"` |
| `source` | string | `"Networking"` |
| `timestamp` | Timestamp | Server timestamp |
| `createdAt` | Timestamp | Server timestamp |
| `missedAt` | Timestamp? | Set when call is missed |
| `ringingAt` | Timestamp? | Set when call starts ringing |
| `rejectedAt` | Timestamp? | Set when call is rejected |
