## 7. AI / Matching Pipeline

### Overview

The matching system uses **no hardcoded categories**. All intent understanding is dynamic, powered by Gemini AI. The system uses a **dual-signal approach**: semantic similarity (768-dimensional embeddings) combined with keyword overlap.

### Pipeline Flow

```
┌──────────────────────────────────────────────────────────────┐
│ 1. USER INPUT (Voice or Text)                                │
│    "I want to buy an iPhone 14 Pro"                          │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 2. INTENT ANALYSIS (Gemini AI)                               │
│    - primary_intent: "buy iPhone 14 Pro"                     │
│    - action_type: "seeking"                                  │
│    - domain: "marketplace"                                   │
│    - complementary_intents: ["selling iPhone 14", ...]       │
│    - is_symmetric: false                                     │
│    - exchange_model: "paid"                                  │
│    - search_keywords: ["iphone", "14", "pro"]                │
│    - value_profile: []                                       │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 3. EMBEDDING GENERATION (768-dim)                            │
│    Text: "buy iPhone 14 Pro marketplace seeking"             │
│    → [0.45, -0.12, 0.89, ...] (768 values)                  │
│    → Cached for 24 hours                                     │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 4. POST STORED IN FIRESTORE                                  │
│    posts/{postId} with all fields + embedding + keywords     │
│    Expires in 30 days                                        │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 5. MATCH FINDING (Scoring Algorithm)                         │
│    Search embedding from complementary_intents               │
│    Compare against all active posts:                         │
│    ┌─ Semantic: cosine_similarity(search_emb, post_emb)      │
│    ├─ Keywords: shared + complementary keyword hits           │
│    ├─ Intent: offer↔seek bonus (+0.15)                       │
│    ├─ Location: distance-based score (×0.05)                 │
│    └─ Lifestyle: clash penalty (-0.15)                       │
│    Final threshold: ≥ 0.60                                   │
└─────────────────────┬────────────────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────────────────┐
│ 6. REALTIME MATCHING                                         │
│    RealtimeMatchingService listens for new posts             │
│    If score ≥ 0.65 → Push notification to matched users      │
└──────────────────────────────────────────────────────────────┘
```

### Intent Analysis Structure (from Gemini)

```json
{
  "primary_intent": "buy iPhone 14 Pro",
  "action_type": "offering | seeking | neutral",
  "is_symmetric": false,
  "skill_level": "beginner | intermediate | advanced | expert | any",
  "exchange_model": "free | paid | barter | equity | flexible | unspecified",
  "domain": "marketplace | jobs | housing | services | education | fitness | ...",
  "complementary_intents": ["selling iPhone 14", "iPhone for sale", ...],
  "search_keywords": ["iphone", "14", "pro", "buy"],
  "value_profile": ["vegan", "pets", "no_smoking", ...],
  "title": "Looking to Buy iPhone 14 Pro",
  "description": "User wants to purchase an iPhone 14 Pro",
  "confidence": 0.95,
  "entities": { "product": "iPhone 14 Pro", "price_range": "$800-1000" }
}
```

### Scoring Formula

```
relevance = max(semantic_similarity, keyword_score × 0.70)

final_score = relevance
            + intent_bonus      (0.15 if offer↔seek + evidence)
            + location_bonus    (location_score × 0.05)
            - lifestyle_penalty (0.15 if lifestyle clash)
            - domain_penalty    (0.10 if domain mismatch)
```

### Thresholds & Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Pre-filter threshold | 0.40 | Skip if semantic similarity below |
| Final threshold | 0.60 | Minimum to surface as match |
| Realtime threshold | 0.65 | Minimum for push notification |
| Intent bonus | 0.15 | Offer ↔ seek complementarity |
| Location weight | 0.05 | Location proximity factor |
| Lifestyle penalty | 0.15 | Lifestyle incompatibility |
| Domain mismatch penalty | 0.10 | Different domains |
| Keyword damping | 0.70 | Keyword signal dampening |
| Query limit | 200 | Max posts fetched for matching |
| Max results | 20 | Top matches returned |
| Embedding dimension | 768 | Vector size |
| Cache duration | 24h | Embedding cache TTL |

### Hard Filters (Automatic Rejection)

1. **Same-side block**: Two sellers don't match (unless both symmetric, e.g., gym partners)
2. **Exchange model incompatibility**: free ↔ paid, equity ↔ paid
3. **Domain mismatch**: Different specific domains with no keyword overlap
4. **Below pre-filter**: Semantic similarity < 0.40

### Lifestyle Incompatibility Pairs

| Value A | Value B |
|---------|---------|
| vegan | meat_based, bbq, non_vegetarian |
| vegetarian | meat_based, bbq, non_vegetarian |
| pets | no_pets |
| smoking | no_smoking |
| quiet | loud |
| night_owl | early_bird |
| hunting | animal_rights |

### Location Scoring

| Service Type | 0 km | 50 km | 200 km | 500 km | >500 km |
|-------------|-------|-------|--------|--------|---------|
| in_person | 1.0 | 1.0 | ~0.6 | 0.0 | 0.0 |
| community | 1.0 | 1.0 | 1.0 | ~0.5 | 0.0 |
| professional | 1.0 | 1.0 | 1.0 | 1.0 | ~0.5 |
| digital | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

### Voice Assistant Function Tools

The voice assistant can execute these functions via Gemini function calling:

| Function | Description |
|----------|-------------|
| searchPosts(query) | Keyword search across posts |
| searchByEmbedding(text) | Semantic search via embeddings |
| searchNearby(text, radiusKm) | Location-based search |
| createPost(prompt) | Create new post |
| getMatches(postId) | Find matches for a post |
| findMatchesForMe() | Find best matches for user |
| getMyPosts() | List user's active posts |
| getUserProfile() | Get current user profile |
| getRecentConversations() | List recent chats |
| navigateTo(screen) | Navigate to app screen |

---

