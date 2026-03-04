# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- Internal project title -->
# Supper App

## STRICT RULES (READ FIRST, ALWAYS OBEY)

1. **NEVER create .md files** — no status files, no summary files, no progress files, no reports
2. **NEVER modify files not listed in the task** — ask first if unsure
3. **NEVER make "improvements" beyond what was requested** — no bonus refactors, no extra docstrings
4. **ONE task at a time** — complete it, let the user verify, then move on
5. **Always read a file before editing it** — never guess at file contents
6. **Keep changes minimal** — smallest diff that solves the problem
7. **When editing CLAUDE.md** — use the Edit tool to change ONLY the specific section, NEVER rewrite the entire file
8. **All progress tracking belongs in git commits** — not in files

## Current Task Context

_Update ONLY this section before each session:_
- **Working on:** (describe current feature/fix)
- **Files involved:** (list the 2-3 files)
- **Do NOT touch:** (files that should remain unchanged)
- **Left off at:** (what was done, what remains)

## Project Overview

**Supper** — Flutter AI-powered matching app. Users type natural language, Gemini AI understands intent, creates embeddings, and matches people semantically.

**Stack:** Flutter 3.35.7 / Dart 3.9.2 / Firebase / Gemini AI / WebRTC / Riverpod

**Account types:** `personal`, `professional` (individual specialist), `business` (catalog + bookings + reviews)

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

## Architecture (Quick Reference)

**Data flow:** User input → UnifiedIntentProcessor → Gemini AI → UnifiedPostService → posts/{postId} → UnifiedMatchingService → Matches

**Matching score:** semantic similarity (768-dim embeddings) × 0.70 keyword damping + 15% intent complementarity bonus + 5% location bonus − 15% lifestyle penalty. Surface threshold: 0.60 (configurable in `lib/res/config/api_config.dart`).

**Key services (all singletons):** UnifiedPostService (posts), GeminiService (AI), LocationService (GPS), FirebaseProvider (all Firebase), CatalogService, ConnectionService, NotificationService

**State management:** Riverpod — `StreamProvider` for real-time Firestore, `FutureProvider` for one-time fetches. Providers defined in `lib/providers/`.

**Database:** posts/ (single source of truth), users/, users/{id}/catalog/, conversations/, notifications/, connection_requests/

**Navigation (5 tabs):** Home/Discover (`UniversalMatchingScreen`) → Messages (`ConversationsScreen`) → Live Connect (`LiveConnectTabScreen`) → Networking → Profile (`ProfileWithHistoryScreen`)

## Critical Constraints

- No hardcoded categories — AI determines intent dynamically
- Always use `limit()` on Firestore queries
- Always use `FirebaseProvider` — never create new Firebase instances
- Never use old collections (user_intents, intents, processed_intents)
- Services follow singleton pattern: `static final _instance` with factory constructor — never call `ServiceName()` constructors directly
- After catalog add/delete, call `UnifiedPostService().syncBusinessPost(userId)` to keep catalog matchable
- API keys loaded via `flutter_dotenv` from `.env` at runtime; accessed via `lib/res/config/api_config.dart`
- Never show exact GPS coordinates (privacy)

## Detailed Documentation

Architecture details, database schemas, code patterns, and conventions are in `.claude/rules/` files (auto-loaded when relevant).
