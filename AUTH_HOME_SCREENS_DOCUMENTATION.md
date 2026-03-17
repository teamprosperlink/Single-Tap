# Auth & Home Module — Complete Screen Documentation

**App:** Single Tap
**Module:** Authentication + Home / Discover
**Total Screens:** 11 (1 splash + 1 onboarding + 1 account type + 1 login/signup + 1 OTP verification + 1 forgot password (3-step) + 1 change password + 1 profile setup + 1 home/discover + 1 listing detail + 1 see all products)
**Last Updated:** 17 Mar 2026

---

## Table of Contents

1. [Splash Screen](#1-splash-screen)
2. [Onboarding Screen](#2-onboarding-screen)
3. [Choose Account Type Screen](#3-choose-account-type-screen)
4. [Login / Sign Up Screen](#4-login--sign-up-screen)
5. [OTP Verification Screen](#5-otp-verification-screen)
6. [Forgot Password Screen](#6-forgot-password-screen)
7. [Change Password Screen](#7-change-password-screen)
8. [Profile Setup Screen](#8-profile-setup-screen)
9. [Home Screen (Discover / AI Chat)](#9-home-screen-discover--ai-chat)
10. [Listing Detail Screen](#10-listing-detail-screen)
11. [See All Products Screen](#11-see-all-products-screen)

---

## 1. Splash Screen

**File:** `lib/screens/login/splash_screen.dart`
**Class:** `SplashScreen` (StatefulWidget)
**Lines:** 161
**Purpose:** App launch screen with animated logo. Displays for 3 seconds with a breathing/rotation animation, then navigates to `AuthWrapper` which routes to either the home screen (if logged in) or the onboarding screen.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_animationController` | `AnimationController` | — | Controls floating + rotation animation, 3s duration, repeats in reverse |

### Background Design

| Element | Style |
|---------|-------|
| Background color | `AppColors.splashDark3` |
| Gradient | `AppColors.splashGradient` (full screen) |
| Background circles | CustomPaint with `_BackgroundPatternPainter`, white color at 3% opacity |
| Border circles | White at 5% opacity, stroke width 1 |

### Logo Animation

| Property | Value |
|----------|-------|
| Container shape | Circle |
| Size | `screenHeight * 0.28` (min 180, max 280) |
| Box shadow | White at 30% opacity, blur 40, spread 5, offset (0, 10) |
| Image | `AppAssets.logoPath`, BoxFit.cover inside ClipOval |
| Scale animation | 1.0 to 1.1 (breathing effect) |
| Rotation | rotateY from 0 to 0.5 radians |
| Duration | 3 seconds, reverse repeat |

### Navigation Flow

```
SplashScreen → (3 seconds) → AuthWrapper → OnboardingScreen (if not logged in)
                                          → MainNavigationScreen (if logged in)
```

### Custom Painter: `_BackgroundPatternPainter`

- Draws 3 filled circles (opacity 3%): at (30%, 40%), (70%, 60%), (50%, 80%) with radii 150, 200, 120
- Draws 2 border circles (opacity 5%): at (20%, 20%) r=80, (80%, 30%) r=60
- Does not repaint (`shouldRepaint` returns false)

---

## 2. Onboarding Screen

**File:** `lib/screens/login/onboarding_screen.dart`
**Class:** `OnboardingScreen` (StatefulWidget)
**Lines:** 537
**Purpose:** 4-page swipeable onboarding carousel with 3D page transitions, glassmorphism cards, and animated circular images. Introduces users to the app's features before navigating to account type selection.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_pageController` | `PageController` | viewportFraction: 0.8 | Controls page swiping |
| `_zoomController` | `AnimationController` | 1500ms, reverse repeat | Controls zoom pulse on images |
| `_currentPage` | `int` | `0` | Currently visible page index |

### Onboarding Pages Data

| Page | Title | Subtitle | Image | Color |
|------|-------|----------|-------|-------|
| 1 | Welcome to Single Tap | Your ultimate campus marketplace... | `AppAssets.logoPath` | `lightBlueTint` |
| 2 | Find Anything | From textbooks to bikes... | `searchRequirementImage` | `lightGreenTint` |
| 3 | Connect Instantly | Chat with verified students... | `searchAnnounceImage` | `lightOrangeTint` |
| 4 | Get Started | Join thousands of students... | `searchDataImage` | `lightPurpleTint` |

### AppBar / Header Layout

```
┌──────────────────────────────────────────────┐
│  Single Tap                          [Skip]  │
│                                              │
│          ┌─────────────────────┐             │
│          │                     │             │
│          │   3D Page Card      │             │
│          │   (glassmorphism)   │             │
│          │                     │             │
│          └─────────────────────┘             │
│                                              │
│              ● ─── ○ ○ ○                     │
│                                              │
│          Welcome to Single Tap               │
│   Your ultimate campus marketplace...        │
│                                              │
│              [ → Next ]                      │
│    or   [ Get Started 🚀 ] (page 4)         │
└──────────────────────────────────────────────┘
```

### Skip Button Styling

| Property | Value |
|----------|-------|
| Visibility | Hidden on last page (page 4) |
| Background | Glassmorphism: backdrop blur 10, dark 15% opacity |
| Border | `glassBorder` at 30% opacity |
| Border radius | 20 |
| Text | "Skip", `labelLarge`, white at 90% |
| Tap action | Navigate to `ChooseAccountTypeScreen` |

### 3D Page Card Styling

| Property | Value |
|----------|-------|
| Scale | `1 - (pageOffset.abs() * 0.3)`, clamped 0.8–1.0 |
| Rotation | `pageOffset * 0.5` radians on Y-axis |
| Opacity | `1 - pageOffset.abs()`, clamped 0.5–1.0 |
| Card border radius | 20 |
| Background | Glassmorphism with gradient (page color 30% → splashDark2 20%) |
| Border | `glassBorder` at 20%, width 1.5 |
| Backdrop filter | Blur sigma 10x10 |

### Image Circle Animation

| Property | Value |
|----------|-------|
| Scale range | 0.95 to 1.05 (zoom pulse) |
| Duration | 1500ms, reverse repeat |
| Circle border | Page color at 50%, width 2.5 |
| Box shadow | Page color at 30%, blur 15, spread 2 |
| Size | Responsive, clamped 100–220px |

### Page Indicators

| Property | Value |
|----------|-------|
| Active width | 30px |
| Inactive width | 8px |
| Height | 8px |
| Active color | `textPrimaryDark` (white) |
| Inactive color | `glassBorder` at 30% |
| Active glow | White at 50%, blur 8 |
| Border radius | 4 |
| Animation | 300ms |

### Next Button (Pages 1–3)

| Property | Value |
|----------|-------|
| Shape | Circle, 64x64 |
| Background | Glassmorphism, dark 15% |
| Border | `glassBorder` 30%, width 2 |
| Icon | `arrow_forward`, white, size 28 |
| Shadow | Dark 20%, blur 12, offset (0, 4) |

### Get Started Button (Page 4)

| Property | Value |
|----------|-------|
| Width | Full width |
| Height | 60 |
| Background | Glassmorphism, dark 15% |
| Border radius | 30 |
| Border | `glassBorder` 30%, width 1.5 |
| Text | "Get Started", `titleMedium` |
| Icon | `rocket_launch`, white, size 20 |
| Navigation | `ChooseAccountTypeScreen` (pushReplacement) |

### Custom Painter: `_BackgroundPatternPainter`

- Draws grid lines every 20px (horizontal + vertical) at 10% opacity
- Draws 3 filled circles at 5% opacity

---

## 3. Choose Account Type Screen

**File:** `lib/screens/login/choose_account_type_screen.dart`
**Class:** `ChooseAccountTypeScreen` (StatefulWidget)
**Lines:** 415
**Purpose:** Account type selection screen. User chooses between "Personal Account" and "Business Account" before proceeding to login. Each card shows relevant features with emoji icons.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `selectedIndex` | `int` | `-1` | Currently selected card (-1 = none) |
| `accountTypes` | `List<String>` | `["Personal Account", "Business Account"]` | Available account types |

### Screen Layout

```
┌──────────────────────────────────────────────┐
│                                              │
│  Select an account type                      │
│  Tell us if you're here as an individual     │
│  or a business                               │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ 👤  Personal / Individual        ○   │    │
│  │     For Individual buyer and sellers │    │
│  │  📡 Explore - Ideas, People, Prods  │    │
│  │  🤖 Match - Needs, Travel, Room     │    │
│  │  💬 Connect - Chat, Calls           │    │
│  │  📤 Share - Post, Ideas             │    │
│  │  ✅ Trust - Verify Rate             │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ 💼  Business / Organization      ○   │    │
│  │     For Business and Organization   │    │
│  │  🔍 List - Services, Products       │    │
│  │  📁 Propose - Full Projects         │    │
│  │  🪪 Showcase - Portfolio            │    │
│  │  📧 Manage - Clients, Discussions   │    │
│  │  📋 Deliver - End to End Output     │    │
│  └──────────────────────────────────────┘    │
│                                              │
│         [        Continue        ]           │
└──────────────────────────────────────────────┘
```

### Background Styling

| Property | Value |
|----------|-------|
| Scaffold background | Black |
| Gradient | `#404040` → `#000000` (top to bottom) |

### Title Styling

| Property | Value |
|----------|-------|
| Title text | "Select an account type" |
| Font size | 28px |
| Font weight | w700 |
| Color | White |
| Letter spacing | -0.5 |
| Subtitle color | White at 70% opacity |
| Subtitle size | 15px |

### Account Type Card (`_AccountTypeCard`)

| Property | Unselected | Selected |
|----------|-----------|----------|
| Background | White at 8% | `#2563EB` at 15% |
| Border color | White at 15% | `#2563EB` |
| Border width | 1.5 | 2 |
| Border radius | 20 | 20 |
| Box shadow | Black 30%, blur 10 | Blue 30%, blur 20 |
| Animation | 300ms easeInOut | 300ms easeInOut |
| Padding | 10 all | 10 all |

### Selection Indicator

| Property | Unselected | Selected |
|----------|-----------|----------|
| Size | 28x28 | 28x28 |
| Shape | Circle | Circle |
| Background | Transparent | `#2563EB` |
| Border | White 30%, width 2 | `#2563EB`, width 2 |
| Check icon | None | White, size 18 |

### Personal Icon

- Purple gradient circle (48x48): `#B469FF` → `#8B5CF6`
- Person icon (white, 28)
- Verification badge (24x24): white circle with blue verified icon

### Business Icon

- Amber gradient square (45x45, radius 12): `#D97706` → `#92400E`
- Work icon (white, 25)
- Shadow: amber 30%, blur 8

### Feature Item Row

| Property | Value |
|----------|-------|
| Emoji container | 36x36, white 10% bg, radius 10 |
| Emoji size | 18 |
| Text size | 14px, w500, white |
| Spacing | 12px between emoji and text, 10px bottom |

### Continue Button

| Property | Value |
|----------|-------|
| Background | `#2563EB` |
| Foreground | White |
| Height | 56 |
| Border radius | 16 |
| Font size | 17px, w600 |
| Validation | Shows snackbar if no selection |
| Navigation | `LoginScreen(accountType: selectedType)` |

---

## 4. Login / Sign Up Screen

**File:** `lib/screens/login/login_screen.dart`
**Class:** `LoginScreen` (StatefulWidget)
**Lines:** 1788
**Purpose:** Combined login and sign-up screen. Supports email/password authentication, phone OTP login, and Google Sign-In. Toggles between Sign In and Sign Up modes. Includes device login conflict detection, professional/business account setup routing, and inline OTP verification.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |
| `accountType` | `String` | No | `'Personal Account'` | Account type from previous screen |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_formKey` | `GlobalKey<FormState>` | — | Form validation key |
| `_emailOrPhoneController` | `TextEditingController` | — | Email or phone input |
| `_passwordController` | `TextEditingController` | — | Password input |
| `_signupPhoneController` | `TextEditingController` | — | Phone number for signup verification |
| `_isLoading` | `bool` | `false` | Loading state |
| `_obscurePassword` | `bool` | `true` | Password visibility toggle |
| `_isSignUpMode` | `bool` | `false` | Toggle between login and signup |
| `_acceptTerms` | `bool` | `false` | Terms acceptance checkbox |
| `_isOtpSent` | `bool` | `false` | Whether OTP has been sent |
| `_verificationId` | `String?` | `null` | Firebase phone verification ID |

### Services Used

| Service | Purpose |
|---------|---------|
| `AuthService` | Email/password auth, Google sign-in, phone OTP |
| `ProfessionalService` | Check if user has professional profile |
| `BusinessService` | Check if user has business profile |
| `Cloud Firestore` | User data, device tracking |

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  ←                Sign In / Sign Up          │
│─────────────────────────────────────────────│
│                                              │
│  📧 Email or Phone                           │
│  ┌──────────────────────────────────────┐    │
│  │ Enter email or phone number          │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  🔒 Password (hidden in phone-only login)    │
│  ┌──────────────────────────────────────┐    │
│  │ ••••••••                         👁   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  [Sign Up mode: Phone + Terms checkbox]      │
│  [Phone login: 6 OTP boxes]                  │
│                                              │
│             Forgot Password?                 │
│                                              │
│  [        Sign In / Sign Up        ]         │
│                                              │
│  ─── Or continue with ───                    │
│                                              │
│         [ G ] Google Sign-In                 │
│                                              │
│  Don't have an account? Sign Up              │
└──────────────────────────────────────────────┘
```

### AppBar Styling

| Property | Value |
|----------|-------|
| Background | Transparent |
| Title | "Sign In" or "Sign Up" (dynamic) |
| Title style | White, 20px, bold |
| Center title | Yes |
| Flexible space | Gradient `#282828` → `#404040`, bottom border white 0.5px |
| Leading | Back arrow, white, size 30 |

### Input Fields Styling

| Property | Value |
|----------|-------|
| Fill color | White at 15% |
| Border radius | 14 |
| Border (enabled) | White 20%, width 1 |
| Border (focused) | White 40%, width 1 |
| Text color | White, 16px |
| Hint color | White 35%, 15px |
| Cursor color | White |
| Prefix icon | Country code picker (for phone) |

### Authentication Flow

```
User Input → Detect phone or email
  ├─ Phone number detected (Sign In mode):
  │   → Send OTP → Show 6 OTP boxes → Verify → Navigate
  ├─ Phone number detected (Sign Up mode):
  │   → Sign up with email → Send phone OTP → OTP screen → Navigate
  ├─ Email detected:
  │   → Sign In: email + password auth
  │   → Sign Up: create account + optional phone verify
  └─ Google Sign-In:
      → Google auth → Check profile setup → Navigate
```

### Post-Auth Navigation

```
Successful Auth → Check account type
  ├─ Professional Account → ProfessionalSetupScreen (if no profile)
  ├─ Business Account → BusinessSetupScreen (if no profile)
  └─ Personal Account → ProfileSetupScreen (if not complete)
                       → MainNavigationScreen (if complete)
```

### Device Login Conflict

- Detects if user is already logged in on another device
- Shows `DeviceLoginDialog` with device name
- Options: "Force Login Here" or "Cancel"

### Google Sign-In Button

| Property | Value |
|----------|-------|
| Container | 56x56, white 10% bg, radius 16 |
| Border | White 20%, width 1 |
| Icon | Google "G" SVG or custom painted icon |
| Tap | `_signInWithGoogle()` |

### OTP Box Styling

| Property | Value |
|----------|-------|
| Box count | 6 |
| Width | Responsive, clamped 40–52px |
| Height | width * 1.1 |
| Background (default) | White 10% |
| Background (focused) | White 20% |
| Background (has value) | White 15% |
| Border (focused) | White, width 2 |
| Border (has value) | White 50%, width 1.5 |
| Glow (focused) | White 30%, blur 8, spread 1 |
| Font size | Dynamic (boxWidth * 0.45) |

### Mode Toggle

| Property | Sign In | Sign Up |
|----------|---------|---------|
| Button text | "Sign In" | "Sign Up" |
| Toggle text | "Don't have an account? Sign Up" | "Already have an account? Sign In" |
| Password field | Visible | Visible |
| Phone field | Hidden (unless phone input) | Visible (optional verification) |
| Terms checkbox | Hidden | Visible |

---

## 5. OTP Verification Screen

**File:** `lib/screens/login/otp_verification_screen.dart`
**Class:** `OtpVerificationScreen` (StatefulWidget)
**Lines:** 467
**Purpose:** Dedicated OTP verification screen for phone number authentication. Shows 6 individual OTP input boxes with auto-focus navigation, countdown timer, and resend functionality.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `phoneNumber` | `String` | Yes | — | Phone number to verify |
| `countryCode` | `String` | Yes | — | Country dialing code |
| `verificationId` | `String` | Yes | — | Firebase verification ID |
| `accountType` | `String` | Yes | — | Account type for routing |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_otpController` | `TextEditingController` | — | Combined 6-digit OTP |
| `_otpBoxControllers` | `List<TextEditingController>` | 6 controllers | Individual box controllers |
| `_otpFocusNodes` | `List<FocusNode>` | 6 nodes | Individual box focus |
| `_isLoading` | `bool` | `false` | Loading state |
| `_verificationId` | `String?` | from widget | Current verification ID |
| `_otpTimer` | `Timer?` | — | Countdown timer |
| `_otpCountdown` | `int` | `30` | Seconds remaining |

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  ←    Verify your mobile number              │
│──────────────────────────────────────────────│
│                                              │
│              📱 Illustration                  │
│         (Forgot Password.png)                │
│                                              │
│  we have sent a verification code to         │
│  +91 9876543210                              │
│                                              │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐             │
│  │  │ │  │ │  │ │  │ │  │ │  │             │
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘             │
│                                              │
│  00:30 Sec              Resend OTP ?         │
│                                              │
│                                              │
│  [        Verify OTP Login        ]          │
└──────────────────────────────────────────────┘
```

### AppBar Styling

| Property | Value |
|----------|-------|
| Title | "Verify your mobile number" |
| Title style | White, 20px, bold |
| Background | Gradient `#282828` → `#404040` |
| Border | Bottom white 0.5px |
| Leading | Chevron left, white, size 30 |

### OTP Timer

| Property | Value |
|----------|-------|
| Initial countdown | 30 seconds |
| Format | `MM:SS Sec` |
| Timer color | White 50% |
| Resend enabled | When countdown reaches 0 |
| Resend text | "Resend OTP ?" |
| Resend color (active) | White |
| Resend color (disabled) | White 40% |

### Verify Button

| Property | Value |
|----------|-------|
| Background | `#007AFF` (iOS Blue) |
| Disabled bg | `#007AFF` at 50% |
| Text | "Verify OTP Login", 17px, w600 |
| Height | 56 |
| Border radius | 16 |
| Loading | White CircularProgressIndicator, 22x22, stroke 2.5 |

### OTP Auto-focus Behavior

1. Digit entered → auto-focus next box
2. Backspace on empty → auto-focus previous box
3. All 6 digits entered → hide keyboard
4. On resend → clear all boxes, focus first

### Error Handling

- `ALREADY_LOGGED_IN`: Returns to login with device info via `Navigator.pop(context, {...})`
- Invalid OTP: Shows error snackbar
- Missing verification ID: Shows "Please request OTP first"

---

## 6. Forgot Password Screen

**File:** `lib/screens/login/forgot_password_screen.dart`
**Class:** `ForgotPasswordScreen` (StatefulWidget)
**Lines:** 923
**Purpose:** Multi-step password reset flow. Step 1: Enter phone number. Step 2: Verify OTP. Step 3: Create new password. Uses Firebase Phone Auth for verification and then updates the user's password.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_phoneController` | `TextEditingController` | — | Phone number input |
| `_otpController` | `TextEditingController` | — | Combined OTP value |
| `_newPasswordController` | `TextEditingController` | — | New password input |
| `_confirmPasswordController` | `TextEditingController` | — | Confirm password input |
| `_otpBoxControllers` | `List<TextEditingController>` | 6 controllers | Individual OTP boxes |
| `_otpFocusNodes` | `List<FocusNode>` | 6 nodes | OTP box focus nodes |
| `_currentStep` | `int` | `0` | Current step (0: Phone, 1: OTP, 2: Password) |
| `_isLoading` | `bool` | `false` | Loading state |
| `_verificationId` | `String?` | `null` | Firebase verification ID |
| `_obscurePassword` | `bool` | `true` | New password visibility |
| `_obscureConfirmPassword` | `bool` | `true` | Confirm password visibility |
| `_selectedCountryCode` | `String` | `'+91'` | Selected country code |
| `_otpCountdown` | `int` | `30` | OTP timer countdown |

### Country Codes

Supports 30 countries: India, USA, UK, Australia, UAE, Saudi Arabia, Singapore, Malaysia, Germany, France, Italy, Japan, South Korea, China, Brazil, Mexico, South Africa, Nigeria, Pakistan, Bangladesh, Nepal, Sri Lanka, Philippines, Indonesia, Thailand, Vietnam, Russia, Spain, Netherlands, Sweden.

### Step 1: Phone Number Entry

```
┌──────────────────────────────────────────────┐
│  ←         Forgot Password                   │
│──────────────────────────────────────────────│
│                                              │
│              📱 Illustration                  │
│         (Forgot Password.png)                │
│                                              │
│    Where would you like to receive a         │
│    verification code?                        │
│                                              │
│  Mobile Number                               │
│  ┌─────┬────────────────────────────┐        │
│  │ +91 ▼│ Enter phone number        │        │
│  └─────┴────────────────────────────┘        │
│                                              │
│  [           Send OTP           ]            │
└──────────────────────────────────────────────┘
```

### Step 2: OTP Verification

Same layout as OTP Verification Screen (Screen 5) with timer and resend.

### Step 3: New Password

```
┌──────────────────────────────────────────────┐
│  ←      Create New Password                  │
│──────────────────────────────────────────────│
│                                              │
│              🔐 Illustration                  │
│       (New Password Create.png)              │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ Enter new password               👁   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ Confirm new password             👁   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  [        Update Password        ]           │
└──────────────────────────────────────────────┘
```

### Country Code Picker

| Property | Value |
|----------|-------|
| Widget | `CountryCodePickerSheet` (bottom sheet) |
| Background | `#404040` |
| Shape | Top corners radius 20 |
| Selection callback | Updates `_selectedCountryCode` |

### Phone Input Field

| Property | Value |
|----------|-------|
| Height | 56 |
| Border radius | 14 |
| Background | White 15% |
| Border | White 20%, width 1 |
| Country code | Left section with dropdown arrow |
| Divider | White 20%, 1px wide, 28px tall |
| Max length | 15 digits |
| Input filter | Digits only |

### Password Fields

| Property | Value |
|----------|-------|
| Fill color | White 15% |
| Border radius | 14 |
| Border (enabled) | White 20%, width 1 |
| Border (focused) | White 40%, width 1 |
| Suffix | Visibility toggle icon (white 50%) |
| Validation | Min 6 chars, passwords must match |

### Action Buttons (All Steps)

| Property | Value |
|----------|-------|
| Background | `#007AFF` (iOS Blue) |
| Height | 56 |
| Border radius | 16 |
| Font size | 17px, w600 |
| Loading indicator | White, 22x22, stroke 2.5 |

### Password Reset Flow

```
Step 0: Enter phone → Send OTP via Firebase
Step 1: Enter 6-digit OTP → Verify with Firebase
Step 2: Enter new password → updatePassword() → Sign out → Pop to login
```

---

## 7. Change Password Screen

**File:** `lib/screens/login/change_password_screen.dart`
**Class:** `ChangePasswordScreen` (StatefulWidget)
**Lines:** 636
**Purpose:** Allows authenticated users to change their password. Has two modes: (1) For email/password users — shows current + new + confirm password form. (2) For Google sign-in users — shows info message that password change is not available.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_formKey` | `GlobalKey<FormState>` | — | Form validation |
| `_currentPasswordController` | `TextEditingController` | — | Current password |
| `_newPasswordController` | `TextEditingController` | — | New password |
| `_confirmPasswordController` | `TextEditingController` | — | Confirm password |
| `_isLoading` | `bool` | `false` | Loading state |
| `_obscureCurrentPassword` | `bool` | `true` | Current password visibility |
| `_obscureNewPassword` | `bool` | `true` | New password visibility |
| `_obscureConfirmPassword` | `bool` | `true` | Confirm password visibility |

### Screen Layout (Email/Password Users)

```
┌──────────────────────────────────────────────┐
│  ←         Change Password                   │
│──────────────────────────────────────────────│
│                                              │
│  ┌─ ℹ Info Card ──────────────────────┐      │
│  │  Your password must be at least    │      │
│  │  6 characters long                 │      │
│  └────────────────────────────────────┘      │
│                                              │
│  🔒 Current Password                     👁  │
│  🔒 New Password                         👁  │
│  🔒 Confirm New Password                 👁  │
│                                              │
│  [        Change Password        ]           │
│                                              │
│  ┌─ Password Tips ────────────────────┐      │
│  │  ✅ Use at least 6 characters      │      │
│  │  ✅ Mix uppercase and lowercase     │      │
│  │  ✅ Include numbers and symbols     │      │
│  │  ✅ Avoid common words              │      │
│  │  ✅ Don't reuse passwords           │      │
│  └────────────────────────────────────┘      │
└──────────────────────────────────────────────┘
```

### Screen Layout (Google Users)

```
┌──────────────────────────────────────────────┐
│  ←         Change Password                   │
│──────────────────────────────────────────────│
│                                              │
│              ℹ (64px icon)                    │
│                                              │
│     Password Change Not Available            │
│                                              │
│  You signed in with Google. To change        │
│  your password, please use Google's          │
│  password management.                        │
│                                              │
│           [ Go Back ]                        │
└──────────────────────────────────────────────┘
```

### AppBar Styling

| Property | Value |
|----------|-------|
| Title | "Change Password" |
| Font | Poppins, w600, white |
| Background | Transparent |
| Flexible space | Gradient `#282828` → `#404040`, border white 0.5px |
| Leading | Arrow back, white |
| Body | `AppBackground` with particles off, overlay 0.7 |

### Info Card

| Property | Value |
|----------|-------|
| Background | Blue gradient (25% → 15%) |
| Border | Blue 40%, width 1 |
| Border radius | 16 |
| Icon | `info_outline`, white |
| Text | Poppins, white 80% |

### Input Fields

| Property | Value |
|----------|-------|
| Font | Poppins, white |
| Fill | White 10% |
| Border radius | 16 |
| Border (enabled) | White 30% |
| Border (focused) | White 60% |
| Prefix | Lock icon, white70 |
| Suffix | Visibility toggle, white70 |

### Validation Rules

| Field | Rule |
|-------|------|
| Current Password | Required |
| New Password | Min 6 chars, different from current |
| Confirm Password | Must match new password |

### Change Password Flow

```
Re-authenticate → EmailAuthProvider.credential(email, currentPassword)
               → user.reauthenticateWithCredential()
               → user.updatePassword(newPassword)
               → Show success → Navigator.pop()
```

### Error Handling

| Error Code | Message |
|------------|---------|
| `wrong-password` | "Current password is incorrect" |
| `weak-password` | "New password is too weak" |
| `requires-recent-login` | "Please log out and log in again" |

---

## 8. Profile Setup Screen

**File:** `lib/screens/login/profile_setup_screen.dart`
**Class:** `ProfileSetupScreen` (ConsumerStatefulWidget)
**Lines:** 778
**Purpose:** 3-step profile setup wizard shown after first-time sign up. Collects birth date, connection type preferences, and activity interests. Data saved to Firestore `users` collection. Can be skipped entirely.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_pageController` | `PageController` | — | Controls step pages |
| `_animationController` | `AnimationController` | 800ms | Entry animation |
| `_currentStep` | `int` | `0` | Current wizard step |
| `_isLoading` | `bool` | `false` | Save loading state |
| `_selectedBirthDate` | `DateTime?` | `null` | User's birth date |
| `_selectedConnectionTypes` | `List<String>` | `[]` | Selected connection types |
| `_selectedActivities` | `List<String>` | `[]` | Selected activities |

### Total Steps: 3

### Step 1: Birth Date

```
┌──────────────────────────────────────────────┐
│  ←    Step 1 of 3               Skip         │
│  ═══ ─── ───                                 │
│                                              │
│  When were you                               │
│  born?                                       │
│                                              │
│  This helps us show you people in your       │
│  preferred age range...                      │
│                                              │
│  ┌────────────────────────────────────┐      │
│  │  📅  Select your birth date    ›   │      │
│  │      (25 years old)                │      │
│  └────────────────────────────────────┘      │
│                                              │
│  🔒 Your birth date is private.              │
│     Only your age will be visible.           │
│                                              │
│  [          Continue          ]              │
└──────────────────────────────────────────────┘
```

### Step 2: Connection Types

```
┌──────────────────────────────────────────────┐
│  ←    Step 2 of 3               Skip         │
│  ═══ ═══ ───                                 │
│                                              │
│  What are you                                │
│  looking for?                                │
│                                              │
│  SOCIAL                                      │
│  [Dating] [Friendship] [Casual Hangout]      │
│  [Travel Buddy] [Nightlife Partner]          │
│                                              │
│  PROFESSIONAL                                │
│  [Networking] [Mentorship] [Business Partner]│
│  [Career Advice] [Collaboration]             │
│                                              │
│  ACTIVITIES                                  │
│  [Workout Partner] [Sports Partner]          │
│  [Hobby Partner] [Event Companion]           │
│  [Study Group]                               │
│                                              │
│  ✅ 3 selected                               │
│  [          Continue          ]              │
└──────────────────────────────────────────────┘
```

### Step 3: Activities

```
┌──────────────────────────────────────────────┐
│  ←    Step 3 of 3               Skip         │
│  ═══ ═══ ═══                                 │
│                                              │
│  What do you                                 │
│  enjoy doing?                                │
│                                              │
│  SPORTS                                      │
│  [Tennis] [Badminton] [Basketball]            │
│  [Football] [Volleyball] [Golf]              │
│                                              │
│  FITNESS                                     │
│  [Gym] [Running] [Yoga] [Cycling]            │
│  [Swimming] [Dance]                          │
│                                              │
│  OUTDOOR                                     │
│  [Hiking] [Rock Climbing] [Camping]          │
│  [Kayaking] [Surfing]                        │
│                                              │
│  CREATIVE                                    │
│  [Photography] [Painting] [Music]            │
│  [Writing] [Cooking] [Gaming]                │
│                                              │
│  ✅ 5 selected                               │
│  [        Get Started        ]               │
└──────────────────────────────────────────────┘
```

### Connection Type Groups

| Group | Items |
|-------|-------|
| Social | Dating, Friendship, Casual Hangout, Travel Buddy, Nightlife Partner |
| Professional | Networking, Mentorship, Business Partner, Career Advice, Collaboration |
| Activities | Workout Partner, Sports Partner, Hobby Partner, Event Companion, Study Group |

### Activity Groups

| Group | Items |
|-------|-------|
| Sports | Tennis, Badminton, Basketball, Football, Volleyball, Golf |
| Fitness | Gym, Running, Yoga, Cycling, Swimming, Dance |
| Outdoor | Hiking, Rock Climbing, Camping, Kayaking, Surfing |
| Creative | Photography, Painting, Music, Writing, Cooking, Gaming |

### Progress Bar

| Property | Value |
|----------|-------|
| Segments | 3 bars with 4px gap |
| Height | 4 |
| Active color | `AppColors.success` (green) |
| Inactive color | White 24% |
| Border radius | 2 |
| Animation | 300ms |

### Chip/Tag Styling

| Property | Unselected | Selected |
|----------|-----------|----------|
| Background | White 5% | Green 20% |
| Border | White 20%, width 1 | Green, width 2 |
| Border radius | 25 | 25 |
| Text color | White | Green |
| Font weight | Normal | w600 |
| Check icon | None | Green check_circle, 16 |
| Padding | 16h, 12v | 16h, 12v |

### Bottom Buttons Area

| Property | Value |
|----------|-------|
| Background | `splashDark1` |
| Shadow | Black 30%, blur 20, offset (0, -5) |
| Selection text | Green, "{N} selected" or "{age} years old" |
| Button bg (has selection) | `AppColors.success` |
| Button bg (no selection) | `grey[700]` |
| Button text | "Continue" (steps 1-2), "Get Started" (step 3) |
| Font size | 18, w600 |
| Height | 56 |
| Border radius | 16 |

### Date Picker Theme

| Property | Value |
|----------|-------|
| Color scheme | Dark with green primary |
| Dialog bg | `splashDark1` |
| Min age | 18 |
| Max age | 100 |

### Firestore Save

```dart
users/{userId}: {
  birthDate: ISO8601 string,
  connectionTypes: [String],
  activities: [String],
  profileSetupComplete: true
}
```

### Skip Behavior

- Skip button available on all steps
- Navigates directly to `MainNavigationScreen` without saving

---

## 9. Home Screen (Discover / AI Chat)

**File:** `lib/screens/home/home_screen.dart`
**Class:** `HomeScreen` (StatefulWidget)
**Lines:** 3275
**Purpose:** Main discovery screen with AI chat interface. Users type natural language queries and receive AI-processed results as product/service cards. Supports voice input (speech-to-text), text-to-speech playback, conversation history auto-save, post creation popup, and a side drawer for chat history.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | `Key?` | No | `null` | Standard Flutter widget key |

### Static Members

| Member | Type | Description |
|--------|------|-------------|
| `globalKey` | `GlobalKey<HomeScreenState>` | Access HomeScreenState externally |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_intentController` | `TextEditingController` | — | Chat input controller |
| `_searchFocusNode` | `FocusNode` | — | Input focus tracking |
| `_chatScrollController` | `ScrollController` | — | Chat scroll position |
| `_isSearchFocused` | `bool` | `false` | Input has focus |
| `_isProcessing` | `bool` | `false` | AI processing in progress |
| `_suggestions` | `List<String>` | `[]` | AI suggestion chips |
| `_currentUserName` | `String` | `''` | Logged-in user's name |
| `_currentUserPhotoUrl` | `String?` | `null` | User's photo URL |
| `_currentUserLat/Lng` | `double?` | `null` | User's coordinates |
| `_conversation` | `List<Map>` | welcome msg | Chat messages list |
| `_currentChatId` | `String?` | `null` | Auto-saved chat ID |
| `_currentProjectId` | `String?` | `null` | Active project context |
| `_isRecording` | `bool` | `false` | Voice recording active |
| `_isVoiceProcessing` | `bool` | `false` | Voice being processed |
| `_speech` | `SpeechToText` | — | Speech recognition instance |
| `_tts` | `FlutterTts` | — | Text-to-speech instance |
| `_likedMessages` | `Set<String>` | `{}` | Liked message keys |
| `_dislikedMessages` | `Set<String>` | `{}` | Disliked message keys |
| `_savedPostIds` | `Set<String>` | `{}` | Saved product IDs |

### Services Used

| Service | Purpose |
|---------|---------|
| `ProductApiService` | Backend API for product search and matching |
| `IpLocationService` | Fallback location detection via IP |
| `NotificationService` | Notify matched post owners |
| `FirebaseAuth` | Current user authentication |
| `Cloud Firestore` | User profile, chat history, saved posts |
| `Geolocator` | GPS location |
| `SpeechToText` | Voice-to-text input |
| `FlutterTts` | Message playback |

### Screen Layout

```
┌──────────────────────────────────────────────┐
│                AI Chat Area                  │
│                                              │
│  🤖 Hi! I'm your Single Tap assistant.       │
│     What would you like to find today?       │
│                                              │
│  👤 looking for iPhone 13                     │
│                                              │
│  🤖 Here are the best matches for you:       │
│                                              │
│  ┌────────┐ ┌────────┐ ┌────────┐           │
│  │Product │ │Product │ │Product │           │
│  │Card 1  │ │Card 2  │ │Card 3  │           │
│  └────────┘ └────────┘ └────────┘           │
│                                              │
│  ────────────────────────────────────────    │
│  ┌────────────────────────────┐  🎤  📎     │
│  │ Type your message...       │              │
│  └────────────────────────────┘              │
└──────────────────────────────────────────────┘
```

### Key Features

| Feature | Description |
|---------|-------------|
| AI Chat | Natural language queries processed by backend API |
| Product Cards | Horizontal scrollable cards with match results |
| Voice Input | Speech-to-text with recording animation |
| TTS Playback | Listen to AI responses via text-to-speech |
| Like/Dislike | Rate AI responses |
| Auto-save | Conversations auto-saved to `chat_history` collection |
| Create Post | Floating popup for creating new posts |
| Chat History | Side drawer showing previous conversations |
| Saved Posts | Track bookmarked products in `saved_posts` sub-collection |
| Notifications | Notifies matched post owners about new searches |

### Message Types

| Type | Description |
|------|-------------|
| User text | Blue-ish user bubble, right-aligned |
| AI text | Dark AI bubble, left-aligned |
| Product cards | Horizontal ListView of match cards |
| Error message | Red-tinted error bubble |
| Typing indicator | Animated dots (`_TypingDotsWidget`) |

### Voice Recording Flow

```
Tap mic → _startVoiceRecording() → SpeechToText.listen()
       → Real-time text display → _finishRecording()
       → _processVoiceMessage() → Same as text input
```

### TTS Settings

| Property | Value |
|----------|-------|
| Language | en-US |
| Speech rate | 0.45 |
| Volume | 1.0 |
| Pitch | 1.0 |

### Location Detection Priority

1. Firestore user document (lat/lng)
2. Filter out stale Mountain View coordinates
3. GPS via Geolocator (5s timeout)
4. IP-based location via `IpLocationService`

### Helper Classes

| Class | Purpose |
|-------|---------|
| `Drawer3DTransition` | 3D animated drawer transition |
| `_ChatHistorySideDrawer` | Side drawer with chat history list |
| `_TypingDotsWidget` | Animated typing indicator (3 dots) |

---

## 10. Listing Detail Screen

**File:** `lib/screens/home/api_listing_detail_screen.dart`
**Class:** `ApiListingDetailScreen` (StatefulWidget)
**Lines:** 1722
**Purpose:** Full detail view for a product/service listing. Shows owner profile, images, description, product specs, highlights, keywords, distance, and action buttons (chat, voice call, save, share). Supports both active and deleted post views.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `postId` | `String` | Yes | — | Unique post identifier |
| `post` | `Map<String, dynamic>` | Yes | — | Full post data map |
| `distanceText` | `String` | No | `''` | Pre-computed distance label |
| `isDeleted` | `bool` | No | `false` | Whether post is in trash |
| `showCallButton` | `bool` | No | `true` | Show/hide call button |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_isSaved` | `bool` | `false` | Whether user has bookmarked |
| `_isActionLoading` | `bool` | `false` | Loading for actions |
| `_computedDistance` | `String` | `''` | Calculated distance |
| `_ownerName` | `String` | `''` | Post owner's display name |
| `_ownerPhoto` | `String` | `''` | Post owner's photo URL |

### Static Cache

```dart
static final Map<String, Map<String, String>> _userProfileCache = {};
```

Caches owner profile lookups (both UUID v5 and Firebase UID mapped to name/photo/uid).

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  ←  Listing Detail           [🔖] [↗ Share] │
│──────────────────────────────────────────────│
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │         Product Image(s)             │    │
│  │         (Swipeable gallery)          │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  iPhone 13 Pro Max                           │
│  📍 2.5 km away                              │
│                                              │
│  ── Owner Profile Card ──                    │
│  👤 John Doe                                 │
│     [💬 Chat]  [📞 Call]                     │
│                                              │
│  ── Smart Match Info ──                      │
│  🧠 "Great match because..."                 │
│  💡 Recommendation text                      │
│                                              │
│  ── Product Details ──                       │
│  Brand: Apple                                │
│  Category: Electronics                       │
│  Condition: Used - Like New                  │
│  Price: $800                                 │
│  Location: New York, NY                      │
│                                              │
│  ── Description ──                           │
│  Full description text...                    │
│                                              │
│  ── Highlights ──                            │
│  • 128GB Storage                             │
│  • Face ID                                   │
│                                              │
│  ── Keywords ──                              │
│  [iPhone] [Apple] [Smartphone]               │
│                                              │
│  [Deleted? Restore / Delete Forever]         │
└──────────────────────────────────────────────┘
```

### Owner Profile Resolution (6 Strategies)

| # | Strategy | Description |
|---|----------|-------------|
| 1 | Post userName | Use if already available and valid |
| 2 | Firestore post doc by listing_id | Lookup post document directly |
| 3 | Query posts by listingId field | Search posts collection |
| 4 | Query posts by originalPrompt | Match title against posts |
| 5 | api_user_mappings collection | UUID v5 → Firebase UID mapping |
| 6 | Query users by user_uuid | Search users collection |
| 7 | Direct Firebase UID lookup | Try user_id as Firebase UID |

### Computed Properties

| Property | Source |
|----------|--------|
| `_title` | model → title → name → originalPrompt |
| `_description` | smart_message → description |
| `_category` | post['category'] |
| `_brandName` | post['brand'] (cleaned of Inc/Ltd suffixes) |
| `_isDonation` | post['isDonation'] |
| `_isSimilarMatch` | match_type == 'similar' |
| `_smartMessage` | post['smart_message'] |
| `_recommendation` | post['recommendation'] |
| `_highlights` | post['highlights'] list |
| `_keywords` | post['keywords'] list |

### Accent Color

`#016CFF` (Primary Blue) — used throughout for headers and buttons.

### Action Buttons

| Action | Method | Description |
|--------|--------|-------------|
| Chat | `_openChat()` | Opens `EnhancedChatScreen` with owner |
| Voice Call | `_makeVoiceCall()` | Opens `VoiceCallScreen` |
| Save/Unsave | `_toggleSavePost()` | Bookmarks to `saved_posts` sub-collection |
| Share | Share button in app bar | Share listing externally |
| Restore | `_restorePost()` | Restore deleted post (trash view) |
| Delete Forever | `_permanentlyDeletePost()` | Permanent deletion |

### Distance Calculation

Uses Haversine formula with Earth radius 6371 km. Displays:
- `{N} m` if < 1 km
- `{N.N} km` if >= 1 km
- Hidden if > 10,000 km (invalid)

### Image Viewer

| Property | Value |
|----------|-------|
| Method | `_showImageViewer()` |
| Type | Full-screen dialog |
| Features | Swipeable gallery, page indicator |

### Save Post Flow

```dart
users/{uid}/saved_posts/{postId}: {
  postId: String,
  postData: Map,
  savedAt: serverTimestamp
}
```

---

## 11. See All Products Screen

**File:** `lib/screens/product/see_all_products_screen.dart`
**Class:** `SeeAllProductsScreen` (StatefulWidget)
**Lines:** 861
**Purpose:** Full-page grid view showing all products within a specific category. Accessible via the "See All" button on the Home Screen when a category has more than 2 products. Includes real-time text search, voice-to-text search, product bookmarking, match score badges, and navigation to `ProductDetailScreen` on card tap.

### Constructor Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `products` | `List<Map<String, dynamic>>` | Yes | — | Full list of product data maps from the category |
| `category` | `String` | Yes | — | Category identifier (`food`, `electric`, `house`, `place`) |

### State Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `_searchController` | `TextEditingController` | — | Controls the search text field |
| `_filtered` | `List<Map<String, dynamic>>` | Copy of `products` | Currently filtered product list |
| `_speech` | `SpeechToText` | — | Speech recognition engine |
| `_speechEnabled` | `bool` | `false` | Whether speech recognition initialized |
| `_isRecording` | `bool` | `false` | Whether voice recording is active |
| `_recordingTimer` | `Timer?` | `null` | Fallback timer for speech timeout |
| `_currentSpeechText` | `String` | `''` | Live transcribed text during recording |
| `_savedPostIds` | `Set<String>` | `{}` | Set of bookmarked product IDs |

### Category Label Mapping

| Category Key | Display Label |
|--------------|--------------|
| `food` | Food & Dining |
| `electric` | Electronics |
| `house` | Properties |
| `place` | Places |
| (default) | Products |

### Services Used

| Service | Purpose |
|---------|---------|
| `FirebaseAuth` | Current user UID for saved posts |
| `Cloud Firestore` | Load/save bookmarked posts (`users/{uid}/saved_posts/`) |
| `SpeechToText` | Voice-to-text search |

### Screen Layout

```
┌──────────────────────────────────────────────┐
│  ←          Electronics                      │
│──────────────────────────────────────────────│
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ 🔍 Search Electronics...        🎤  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌────────────┐  ┌────────────┐              │
│  │ [Match %]  │  │ [Match %]  │              │
│  │  Product   │  │  Product   │              │
│  │  Image     │  │  Image     │              │
│  │ ┌────────┐ │  │ ┌────────┐ │              │
│  │ │Name    │ │  │ │Name    │ │              │
│  │ │Price   │ │  │ │Price   │ │              │
│  │ │📍 Loc  │ │  │ │📍 Loc  │ │              │
│  │ └────────┘ │  │ └────────┘ │              │
│  └────────────┘  └────────────┘              │
│  ┌────────────┐  ┌────────────┐              │
│  │   ...      │  │   ...      │              │
│  └────────────┘  └────────────┘              │
└──────────────────────────────────────────────┘
```

### Navigation Trigger (from Home Screen)

The "See All" button appears in `home_screen.dart` (line 2107) when a product category has more than 2 items. Tapping it calls `_showSeeAllProducts()` which navigates using `rootNavigator: true`:

```dart
Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute(
    builder: (_) => SeeAllProductsScreen(products: data, category: category),
  ),
);
```

**"See All" Button Style:**
- Color: `Colors.blue`
- Font: Poppins, 13px, w600
- Alignment: Right-aligned above the horizontal product list

### Background Design

| Property | Value |
|----------|-------|
| Scaffold bg | `Colors.transparent` |
| Body gradient | `#404040` → `#000000` (top to bottom) |
| `extendBodyBehindAppBar` | `true` |

### App Bar (Custom)

| Element | Style |
|---------|-------|
| Back button | `Icons.arrow_back_ios_new`, white, size 20 |
| Title | Category label, Poppins 18px, w700, white, centered |
| White divider | Full-width 1px white line below app bar |

### Search Bar

| Property | Value |
|----------|-------|
| Hint text | `Search {categoryLabel}...` |
| Fill color | White at 15% opacity |
| Border | White at 30% opacity, radius 16 |
| Focused border | White at 50% opacity, radius 16 |
| Prefix icon | `search_rounded`, grey[300], size 20 |
| Clear button | `close_rounded` icon (visible when text is not empty) |
| Mic button | `mic` icon, grey[300], size 20 |
| Font | Poppins, white, 14px |

### Voice Recording UI

When recording is active, the search bar is replaced by a recording indicator:

| Element | Style |
|---------|-------|
| Container | Height 48, white 15% bg, red 50% border, radius 16 |
| Red dot | 10×10 circle, solid red |
| Wave bars | 10 animated bars, red 80%, variable heights |
| Live text | Transcribed text or "Listening..." in grey[400], 12px |
| Stop button | 32×32 red circle with white stop icon |

### Voice Recording Flow

```
Tap mic → _startVoiceRecording() → SpeechToText.listen()
       → Real-time text in wave bar → _finishRecording()
       → Sets search text → _onSearch() filters products
```

| Setting | Value |
|---------|-------|
| Listen duration | 30 seconds max |
| Pause timeout | 3 seconds |
| Locale | `en_US` |
| Partial results | Enabled |

### Search / Filter Logic

Searches across three fields (case-insensitive):
1. Product `name`
2. Subtitle (varies by category: `restaurant` for food, `brand` for electric, `location` for house/place)
3. Product `price`

### Product Grid

| Property | Value |
|----------|-------|
| Layout | `SliverGrid`, 2 columns |
| Aspect ratio | 0.78 |
| Cross-axis spacing | 12 |
| Main-axis spacing | 12 |
| Padding | Horizontal 24, vertical 12 |

### Product Card Design

| Element | Style |
|---------|-------|
| Card border | White 25% opacity, 1.5px, radius 18 |
| Card shadow | Black 40%, blur 8, offset (0,4) |
| Clip radius | 16.5 |
| Image | `CachedNetworkImage`, BoxFit.cover, full card area |
| Fallback image | Gradient initials placeholder (8 gradient color pairs) |
| Bottom gradient | Transparent → black 10% → black 85% (stops: 0.3, 0.55, 1.0) |

### Match Score Badge (Top-Left)

| Condition | Label | Color |
|-----------|-------|-------|
| `similarity_score >= 1.0` or `match_type == 'exact'` | "Exact" | Green 70% |
| `similarity_score >= 0.10` | "{N}% Match" | Orange 70% |
| `similarity_score < 0.10` | "Similar" | Orange 70% |

Badge has glassmorphism backdrop blur (10, 10), radius 8, white 25% border.

### Save / Bookmark Button (Top-Right)

| Property | Value |
|----------|-------|
| Shape | Circle |
| Color | `#016CFF` at 85% opacity |
| Border | White 40%, 1px |
| Icon (saved) | `bookmark_rounded`, white, 14 |
| Icon (unsaved) | `bookmark_border_rounded`, white, 14 |

### Save Post Flow

```dart
users/{uid}/saved_posts/{productId}: {
  postId: String,
  postData: Map,
  savedAt: serverTimestamp
}
```

- Loads up to 200 saved posts on init
- Toggle saves/unsaves with haptic feedback
- Shows success snackbar via `SnackBarHelper`

### Bottom Info Bar (Glassmorphism)

| Property | Value |
|----------|-------|
| Backdrop blur | 12, 12 |
| Background | Black 55% opacity |
| Border | White 15%, 0.5px, radius 14 |
| Position | 4px from left/right/bottom edges |

**Content:**

| Row | Style |
|-----|-------|
| Name | Poppins 12px, w700, white, 1 line max |
| Price | Poppins 12px, w700, `#00D67D` (green), hidden if ₹0 |
| Location | `near_me` icon (10px) + text in grey[400], 10px, 1 line max |

### Empty State

When no products match the search:

| Element | Style |
|---------|-------|
| Icon | `search_off_rounded`, grey[600], size 48 |
| Text | "No results found", grey[500], 16px |

### Navigation on Card Tap

Tapping a product card navigates to `ProductDetailScreen`:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProductDetailScreen(item: item, category: widget.category),
  ),
);
```

### Initials Placeholder Gradients

When no image is available, displays initials (first 2 words' first letters) on a gradient:

| Index | Gradient Colors |
|-------|----------------|
| 0 | `#FF6B35` → `#FF8E53` |
| 1 | `#667EEA` → `#764BA2` |
| 2 | `#11998E` → `#38EF7D` |
| 3 | `#FC5C7D` → `#6A82FB` |
| 4 | `#F7971E` → `#FFD200` |
| 5 | `#0082C8` → `#667EEA` |
| 6 | `#E44D26` → `#F16529` |
| 7 | `#8E2DE2` → `#4A00E0` |

Text: Poppins, white, 36px, w700, centered.

---

## Shared Patterns

### Common AppBar Pattern

All auth screens use this consistent AppBar:

```dart
AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
    icon: Icon(Icons.chevron_left, color: Colors.white, size: 30),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(title, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
  centerTitle: true,
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color.fromRGBO(40, 40, 40, 1), Color.fromRGBO(64, 64, 64, 1)],
      ),
      border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
    ),
  ),
)
```

### Common Background Pattern

| Property | Value |
|----------|-------|
| Scaffold bg | Black |
| Body gradient | `#404040` → `#000000` (top to bottom) |

### Common Button Pattern

| Property | Value |
|----------|-------|
| Background | `#007AFF` (iOS Blue) or `#2563EB` |
| Height | 56 |
| Border radius | 16 |
| Font | 17px, w600, white |
| Disabled | 50% opacity background |
| Loading | White CircularProgressIndicator 22x22 |

### Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| iOS Blue | `#007AFF` | Auth buttons, OTP verify, password reset |
| Selection Blue | `#2563EB` | Account type selection, continue button |
| Primary Blue | `#016CFF` | Listing detail accent |
| Success Green | `AppColors.success` | Profile setup progress, selected chips |
| Splash Gradient | `AppColors.splashGradient` | Splash, onboarding backgrounds |
| Dark Gradient | `#404040` → `#000000` | Auth screen bodies |
| AppBar Gradient | `#282828` → `#404040` | All screen app bars |

### Haptic Feedback

- `lightImpact` — Standard taps, navigation, successful actions
- `heavyImpact` — Error states, failed OTP
- `selectionClick` — OTP box focus, chip selection, date picker

### Snackbar Helper

All screens use `SnackBarHelper` from `lib/res/utils/snackbar_helper.dart`:
- `SnackBarHelper.showError(context, message)` — Red error snackbar
- `SnackBarHelper.showSuccess(context, message)` — Green success snackbar

### Dependencies

| Package | Usage |
|---------|-------|
| `firebase_auth` | All auth screens (login, OTP, password) |
| `cloud_firestore` | User data, chat history, saved posts |
| `speech_to_text` | Voice input on home screen |
| `flutter_tts` | Message playback on home screen |
| `geolocator` | Location for home + listing detail |
| `cached_network_image` | Owner photos in listing detail |
| `shimmer` | Loading placeholders on home screen |
| `flutter_riverpod` | State management in profile setup |

---

## Navigation Flow Summary

```
App Launch
  └── SplashScreen (3s)
       └── AuthWrapper
            ├── Not Logged In:
            │    └── OnboardingScreen (4 pages)
            │         └── ChooseAccountTypeScreen
            │              └── LoginScreen (Sign In / Sign Up)
            │                   ├── Email/Password → Auth
            │                   ├── Phone OTP → OtpVerificationScreen
            │                   ├── Google Sign-In → Auth
            │                   └── Forgot Password → ForgotPasswordScreen
            │                        └── (3 steps: Phone → OTP → New Password)
            │
            └── Logged In:
                 ├── ProfileSetupScreen (if first time)
                 │    └── (3 steps: Birth Date → Connections → Activities)
                 │
                 └── MainNavigationScreen
                      ├── Tab 1: HomeScreen (AI Chat / Discover)
                      │    ├── ApiListingDetailScreen (tap on card)
                      │    └── SeeAllProductsScreen (tap "See All" on category with 3+ items)
                      │         └── ProductDetailScreen (tap on product card)
                      ├── Tab 2: Messages
                      ├── Tab 3: Live Connect
                      └── Tab 4: Profile
```

---

## File Structure

```
lib/screens/login/
├── splash_screen.dart                ← Screen 1: App launch
├── onboarding_screen.dart            ← Screen 2: Feature carousel
├── choose_account_type_screen.dart   ← Screen 3: Account selection
├── login_screen.dart                 ← Screen 4: Login / Sign Up
├── otp_verification_screen.dart      ← Screen 5: Phone OTP verify
├── forgot_password_screen.dart       ← Screen 6: Password reset (3-step)
├── change_password_screen.dart       ← Screen 7: Change password
└── profile_setup_screen.dart         ← Screen 8: Profile wizard

lib/screens/home/
├── home_screen.dart                  ← Screen 9: AI Chat / Discover
├── api_listing_detail_screen.dart    ← Screen 10: Listing detail
└── main_navigation_screen.dart       ← Host scaffold with bottom nav

lib/screens/product/
└── see_all_products_screen.dart      ← Screen 11: See All Products grid

lib/services/
├── auth_service.dart                 ← Email, Google, Phone auth
├── product_api_service.dart          ← Backend API for products
├── ip_location_service.dart          ← IP-based location fallback
├── notification_service.dart         ← FCM + Firestore notifications
├── professional_service.dart         ← Professional profile check
└── business_service.dart             ← Business profile check

lib/widgets/common widgets/
├── country_code_picker_sheet.dart    ← Country code bottom sheet
├── device_login_dialog.dart          ← Device conflict dialog
├── app_background.dart               ← Shared background widget
└── app_drawer.dart                   ← App drawer widget
```
