# Supper App - Complete Technical Documentation

> **Version:** 1.0.0+1 | **Last Updated:** March 10, 2026
> **Platform:** Flutter 3.35.7 / Dart 3.9.2 | **Backend:** Firebase | **AI Engine:** Google Gemini

---

## About This Documentation

This documentation is split into **19 individual files** for easy navigation. Each file covers one major topic. When concatenated in order (01 → 19), they form the complete project documentation.

**Full single-file version:** [SUPPER_APP_DOCUMENTATION.md](SUPPER_APP_DOCUMENTATION.md)

---

## Quick Stats

| Metric | Value |
|--------|-------|
| Total Screens | 62 |
| Total Services | 34+ |
| Total Widgets | 18 files |
| Total Models | 15 |
| Total Dependencies | 55+ |
| Riverpod Providers | 12 |
| Test Cases | 161 |
| Dart Files | 140+ |

---

## Table of Contents

| # | File | Section | Description |
|---|------|---------|-------------|
| 01 | [01_Executive_Summary.md](01_Executive_Summary.md) | Executive Summary | App overview, architecture diagrams, Firebase/Gemini/state maps, user journey |
| 02 | [02_Tech_Stack_Libraries.md](02_Tech_Stack_Libraries.md) | Tech Stack & Libraries | 55+ dependencies: Firebase, AI, WebRTC, media, UI, platform packages |
| 03 | [03_Project_Structure.md](03_Project_Structure.md) | Project Structure | Complete directory tree of 140+ Dart files across all modules |
| 04 | [04_Frontend_Architecture.md](04_Frontend_Architecture.md) | Frontend Architecture | Service-oriented architecture, data flow, navigation, app initialization |
| 05 | [05_Data_Models_Database.md](05_Data_Models_Database.md) | Data Models & Database | 15 data models, Firestore collection schemas, field definitions |
| 06 | [06_Services_Business_Logic.md](06_Services_Business_Logic.md) | Services & Business Logic | 34+ singleton services organized by domain |
| 07 | [07_AI_Matching_Pipeline.md](07_AI_Matching_Pipeline.md) | AI / Matching Pipeline | Gemini intent analysis, 768-dim embeddings, scoring formula |
| 08 | [08_State_Management.md](08_State_Management.md) | State Management | Riverpod providers, StreamProvider, FutureProvider, StateNotifier |
| 09 | [09_Screens_User_Flows.md](09_Screens_User_Flows.md) | Screens & User Flows | 62 screens inventory, detailed widget trees, navigation maps, form fields |
| 10 | [10_Reusable_Widgets.md](10_Reusable_Widgets.md) | Reusable Widgets | 18 widget files: badges, backgrounds, chat, input, cards, avatars |
| 11 | [11_Authentication_Security.md](11_Authentication_Security.md) | Authentication & Security | Auth flows, device sessions, Firestore rules, storage rules |
| 12 | [12_Theming_Design_System.md](12_Theming_Design_System.md) | Theming & Design System | Glassmorphism, color palette, typography, dark/light themes |
| 13 | [13_Platform_Configuration.md](13_Platform_Configuration.md) | Platform Configuration | Android, iOS, Web, Windows, macOS build settings |
| 14 | [14_CICD_Pipeline.md](14_CICD_Pipeline.md) | CI/CD Pipeline | GitHub Actions workflow, build commands, deployment |
| 15 | [15_Testing_Strategy.md](15_Testing_Strategy.md) | Testing Strategy | 161 test cases across 11 files, coverage matrix, integration tests |
| 16 | [16_Performance_Optimization.md](16_Performance_Optimization.md) | Performance & Optimization | Caching (LRU), rate limiting, memory management, Firestore optimization |
| 17 | [17_API_Configuration.md](17_API_Configuration.md) | API Configuration | Environment variables, API keys, Gemini config, geocoding fallbacks |
| 18 | [18_Service_Dependency_Graph.md](18_Service_Dependency_Graph.md) | Service Dependency Graph | Complete service dependency tree and provider graph |
| 19 | [19_Appendices.md](19_Appendices.md) | Appendices | Key file paths reference, supported countries |

---

## Key Commands

```bash
flutter run                    # Run app
flutter run -d chrome          # Run on web
flutter test                   # Run tests
flutter analyze                # Check for errors
flutter build apk              # Build Android
flutter build appbundle        # Build App Bundle (Play Store)
flutter pub get                # Install deps
flutter clean && flutter pub get  # Full reset
```

---

## Architecture Overview

```
User Input (text/voice)
    |
UnifiedPostService.createPost()
    |
GeminiService.analyzeIntent() --> IntentAnalysis JSON
    |
GeminiService.generateEmbedding() --> 768-dim vector
    |
Firestore: posts/{postId}
    |
UnifiedPostService.findMatches() --> Cosine similarity + scoring
    |
Matched posts ranked (threshold >= 0.60)
    |
RealtimeMatchingService --> Push notification to matched users
```

---

*Generated from comprehensive codebase analysis of the Supper Flutter application.*
