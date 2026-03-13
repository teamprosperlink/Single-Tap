## 14. CI/CD Pipeline

### GitHub Actions Workflow (`.github/workflows/ci.yml`)

**Trigger:** Push to `main` or Pull Request to `main`

#### Job 1: Analyze & Test (Ubuntu latest)

```yaml
Steps:
  1. Checkout code
  2. Install Flutter 3.35.7 (master channel)
  3. Create .env file (test values)
  4. flutter pub get
  5. flutter analyze --no-fatal-infos
  6. flutter test
```

#### Job 2: Build Android APK (Ubuntu latest, conditional)

**Condition:** Only on push to `main` (not PRs)
**Depends on:** Job 1 must pass

```yaml
Steps:
  1. Checkout code
  2. Setup Java 17 (Temurin)
  3. Install Flutter 3.35.7 (master channel)
  4. Create .env from GitHub Secrets (GEMINI_API_KEY)
  5. Create google-services.json from Secrets (GOOGLE_SERVICES_JSON)
  6. flutter pub get
  7. flutter build apk --release
  8. Upload APK artifact (release-apk)
```

### Build Commands

```bash
# Development
flutter run                     # Run app (debug)
flutter run -d chrome           # Run on web
flutter run -d windows          # Run on Windows

# Testing
flutter test                    # Run all tests
flutter analyze                 # Static analysis

# Production
flutter build apk               # Android APK
flutter build appbundle          # Play Store bundle
flutter build web                # Web build
flutter build windows            # Windows build

# Maintenance
flutter clean && flutter pub get # Full reset
flutter pub get                  # Install dependencies
```

---

