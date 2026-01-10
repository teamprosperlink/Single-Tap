# Migration Guide: Unified Matching Service

## Overview

This guide explains how to migrate from the old matching services to the new `UnifiedMatchingService`, which consolidates all matching logic into a single, optimized, and AI-powered service.

## What's New

### ✅ Problems Fixed

1. **Single Service**: Consolidated 5 overlapping services into one
2. **Centralized Config**: All API keys and configs in one place (`api_config.dart`)
3. **Smart Caching**: LRU cache for embeddings and match results
4. **AI-Only**: No hardcoded categories - pure AI understanding
5. **Better Performance**: Optimized for client-side with efficient algorithms
6. **Correct API Usage**: Fixed Gemini model version issues

### 🗂️ Architecture

```
OLD (5 Services):
- matching_service.dart
- ai_matching_service.dart
- enhanced_matching_service.dart
- realtime_matching_service.dart
- smart_intent_matcher.dart

NEW (1 Service):
- unified_matching_service.dart
  ├── Intent Analysis (AI-powered)
  ├── Embedding Generation (with caching)
  ├── Multi-factor Matching Algorithm
  ├── Real-time Matching
  └── Post Management
```

## Quick Start

### 1. Initialize the Service

```dart
import 'package:your_app/services/unified_matching_service.dart';

// Initialize once at app startup (main.dart or splash screen)
final matchingService = UnifiedMatchingService();
await matchingService.initialize();
```

### 2. Analyze User Intent

```dart
// User types: "iPhone"
final intent = await matchingService.analyzeIntent("iPhone");

print(intent.primaryIntent); // "Seeking or offering an iPhone"
print(intent.actionType); // "neutral" (needs clarification)
print(intent.clarificationsNeeded); // ["Do you want to buy or sell?"]
```

### 3. Generate Clarifying Questions

```dart
final questions = await matchingService.generateClarifyingQuestions(
  "iPhone",
  intent,
);

for (final q in questions) {
  print(q.question); // "Do you want to buy or sell an iPhone?"
  print(q.options); // ["Buy", "Sell"]
}
```

### 4. Create a Post

```dart
final postId = await matchingService.createPost(
  userInput: "Selling iPhone 15 Pro Max",
  intent: intent,
  clarificationAnswers: {
    "action": "sell",
    "price": "1200",
    "condition": "like new"
  },
  location: "New York, NY",
  latitude: 40.7128,
  longitude: -74.0060,
  images: ["url1", "url2"],
);

print("Post created: $postId");
// Real-time matching triggers automatically!
```

### 5. Find Matches

```dart
final matches = await matchingService.findMatches(
  userId: currentUser.uid,
  userIntent: intent,
  userAnswers: {"action": "buy"},
  userLat: 40.7128,
  userLon: -74.0060,
  limit: 20,
);

for (final match in matches) {
  print("Match: ${match.postData['title']}");
  print("Score: ${match.score}");
  print("Reasons: ${match.reasons}");
  print("Breakdown: ${match.breakdown}");
}
```

## Migration Steps

### Step 1: Replace Service Imports

**Before:**
```dart
import 'package:your_app/services/matching_service.dart';
import 'package:your_app/services/ai_matching_service.dart';
import 'package:your_app/services/enhanced_matching_service.dart';
```

**After:**
```dart
import 'package:your_app/services/unified_matching_service.dart';
```

### Step 2: Update Intent Analysis

**Before (using categories):**
```dart
final post = PostModel(
  category: PostCategory.marketplace,
  intent: PostIntent.selling,
  // ...
);
```

**After (AI-powered):**
```dart
final intent = await UnifiedMatchingService().analyzeIntent(userInput);
final postId = await UnifiedMatchingService().createPost(
  userInput: userInput,
  intent: intent,
  clarificationAnswers: answers,
);
```

### Step 3: Update Matching Logic

**Before:**
```dart
final matches = await MatchingService().findMatches(postId);
// or
final matches = await EnhancedMatchingService().findMatches(post);
```

**After:**
```dart
final matches = await UnifiedMatchingService().findMatches(
  userId: userId,
  userIntent: intent,
  userAnswers: answers,
  userLat: userLat,
  userLon: userLon,
);
```

### Step 4: Remove Old Dependencies

After migrating all screens, you can safely delete:
- `lib/services/matching_service.dart`
- `lib/services/ai_matching_service.dart`
- `lib/services/enhanced_matching_service.dart`
- `lib/services/realtime_matching_service.dart`
- `lib/services/smart_intent_matcher.dart`

**Keep these** (they're still used):
- `lib/services/gemini_service.dart` (updated to use config)
- `lib/services/vector_service.dart` (updated to use config)
- `lib/services/ai_intent_engine.dart` (updated to use config)

## Example: Complete User Flow

```dart
import 'package:your_app/services/unified_matching_service.dart';

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _service = UnifiedMatchingService();
  final _controller = TextEditingController();

  IntentAnalysis? _intent;
  List<ClarifyingQuestion>? _questions;
  Map<String, dynamic> _answers = {};

  @override
  void initState() {
    super.initState();
    _service.initialize();
  }

  Future<void> _analyzeInput() async {
    final input = _controller.text;
    if (input.isEmpty) return;

    // Step 1: Analyze intent
    final intent = await _service.analyzeIntent(input);
    setState(() => _intent = intent);

    // Step 2: Generate clarifying questions if needed
    if (intent.clarificationsNeeded.isNotEmpty) {
      final questions = await _service.generateClarifyingQuestions(
        input,
        intent,
      );
      setState(() => _questions = questions);
    } else {
      // No clarification needed, create post directly
      _createPost();
    }
  }

  Future<void> _createPost() async {
    if (_intent == null) return;

    try {
      final postId = await _service.createPost(
        userInput: _controller.text,
        intent: _intent!,
        clarificationAnswers: _answers,
        location: "Current Location",
        latitude: 40.7128,
        longitude: -74.0060,
      );

      // Navigate to matches screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchesScreen(postId: postId),
        ),
      );
    } catch (e) {
      print("Error creating post: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Post")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "What are you looking for?",
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _analyzeInput,
              child: Text("Analyze"),
            ),
            if (_questions != null) ...[
              SizedBox(height: 24),
              Text("Please clarify:"),
              ..._questions!.map((q) => ClarifyingQuestionWidget(
                question: q,
                onAnswer: (answer) {
                  setState(() => _answers[q.id] = answer);
                },
              )),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createPost,
                child: Text("Create Post"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

## Performance Tips

### 1. Cache Statistics

Monitor cache performance:

```dart
final stats = UnifiedMatchingService().getCacheStats();
print(stats);
// {
//   "embedding_cache": {
//     "size": 523,
//     "hits": 1245,
//     "misses": 234,
//     "hit_rate": 0.84
//   },
//   "match_cache": { ... }
// }
```

### 2. Clear Cache

Clear cache when needed:

```dart
// Clear all caches
UnifiedMatchingService().clearCache();

// Or clear specific caches
CacheService().clearEmbeddingCache();
CacheService().clearMatchCache();
```

### 3. Batch Operations

For multiple posts, use batch operations:

```dart
final texts = ["text1", "text2", "text3"];
final embeddings = await UnifiedMatchingService().generateBatchEmbeddings(texts);
```

## Configuration

Edit `lib/config/api_config.dart` to customize:

```dart
class ApiConfig {
  // API Keys
  static const String geminiApiKey = 'YOUR_API_KEY';

  // Model names
  static const String geminiFlashModel = 'gemini-1.5-flash-latest';
  static const String geminiEmbeddingModel = 'text-embedding-004';

  // Matching thresholds
  static const double semanticSimilarityThreshold = 0.7; // Adjust as needed
  static const double intentMatchWeight = 0.4; // 40% weight
  static const double semanticMatchWeight = 0.3; // 30% weight

  // Cache settings
  static const Duration embeddingCacheDuration = Duration(hours: 24);
  static const int maxCacheSize = 1000;
}
```

## Troubleshooting

### Issue: "Service not initialized"

**Solution:**
```dart
await UnifiedMatchingService().initialize();
```

### Issue: Low match scores

**Solution:** Adjust weights in `api_config.dart`:
```dart
static const double intentMatchWeight = 0.5; // Increase intent weight
static const double semanticMatchWeight = 0.4; // Increase semantic weight
```

### Issue: Slow performance

**Solution:**
1. Check cache hit rate (should be >70%)
2. Reduce limit in findMatches (default: 20)
3. Consider moving to backend/Cloud Functions for production

### Issue: Gemini API quota exceeded

**Solution:**
```dart
// The service automatically falls back to deterministic embeddings
// Check logs for warnings:
// "⚠️ Gemini API quota exceeded. Using fallback embedding."
```

## Best Practices

1. **Initialize Once**: Initialize the service at app startup
2. **Use Caching**: Don't clear cache unnecessarily
3. **Batch Operations**: Use batch embedding generation when possible
4. **Monitor Stats**: Check cache statistics regularly
5. **Error Handling**: Always wrap API calls in try-catch
6. **Location**: Provide user location for better matches
7. **Clarifications**: Always ask clarifying questions when needed

## Next Steps

1. ✅ Migrate one screen at a time
2. ✅ Test thoroughly with various inputs
3. ✅ Monitor cache performance
4. ✅ Adjust weights and thresholds as needed
5. ✅ Consider backend migration for scale (Cloud Functions)

## Support

For issues or questions:
1. Check logs for errors
2. Verify API key is valid
3. Check Firestore security rules
4. Review cache statistics
5. Test with simple inputs first

---

**Last Updated:** 2025-11-13
**Version:** 1.0.0
**Service:** UnifiedMatchingService
