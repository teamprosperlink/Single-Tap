## 12. Theming & Design System

### Color System (`app_colors.dart` - 471 lines)

#### Primary Colors

| Name | Hex | Usage |
|------|-----|-------|
| Primary | #6366F1 | Indigo - main brand color |
| Secondary | #8B5CF6 | Purple - accents |
| Accent | #EC4899 | Pink - highlights |
| Tertiary | #06B6D4 | Cyan - secondary accents |

#### Status Colors

| Name | Hex | Usage |
|------|-----|-------|
| Success | #10B981 | Emerald green |
| Warning | #F59E0B | Amber |
| Error | #EF4444 | Red |
| Info | #0EA5E9 | Sky blue |

#### Connection Type Colors

| Type | Hex | Color |
|------|-----|-------|
| Activity Partner | #00D67D | Green |
| Event Companion | #FFB800 | Yellow |
| Friendship | #FF6B9D | Pink |
| Dating | #FF4444 | Red |

#### Business Archetype Colors

| Type | Hex |
|------|-----|
| Retail | #22C55E (Green) |
| Menu | #F59E0B (Amber) |
| Appointment | #3B82F6 (Blue) |
| Hospitality | #14B8A6 (Teal) |
| Portfolio | #8B5CF6 (Purple) |

#### Background Colors

| Mode | Primary | Secondary | Tertiary |
|------|---------|-----------|---------|
| Dark | #000000 | #1C1C1E | #2C2C2E |
| Light | #F5F5F7 | #FFFFFF | - |

### Typography System (`app_text_styles.dart` - 682 lines)

**Font Family:** Poppins (Google Fonts)

| Category | Size | Weight | Usage |
|----------|------|--------|-------|
| Display Large | 34px | Bold | Hero text |
| Display Medium | 28px | w700 | Section headers |
| Display Small | 24px | Bold | Screen titles |
| Headline Large | 22px | w600 | Card titles |
| Headline Medium | 20px | Bold | Subsections |
| Title Large | 18px | Bold | List item titles |
| Title Medium | 17px | w600 | Dialog titles |
| Title Small | 16px | w600 | Small headings |
| Body Large | 16px | Normal | Primary content |
| Body Medium | 15px | Normal | Standard text |
| Body Small | 14px | Normal | Secondary content |
| Label Large | 13px | w500 | Buttons, labels |
| Label Medium | 12px | w500 | Tags, badges |
| Label Small | 11px | w500 | Fine print |
| Caption | 12px | w400 | Timestamps, hints |

### Spacing Scale

| Name | Value |
|------|-------|
| xs | 4px |
| sm | 8px |
| md | 12px |
| lg | 16px |
| xl | 20px |
| xxl | 24px |

### Border Radius Scale

| Name | Value |
|------|-------|
| Small | 8px |
| Medium | 12px |
| Large | 16px |
| XLarge | 24px |

### Theme Modes

| Mode | Background | Card | Text |
|------|-----------|------|------|
| Dark | #0f0f23 | #1C1C1E | White |
| Glassmorphism | Light + blur | Glass overlay | Dark |

### Glassmorphism Design Pattern

Used throughout the app:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white.withAlpha(15%),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withAlpha(30%)),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: content,
  ),
)
```

---

