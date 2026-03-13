## 16. Performance & Optimization

### Caching Strategy

| Cache | Storage | TTL | Max Size | Purpose |
|-------|---------|-----|----------|---------|
| Embedding Cache | In-memory (LRU) | 24 hours | 1000 entries | Avoid re-computing embeddings |
| Match Cache | In-memory (LRU) | 30 minutes | 1000 entries | Avoid re-running match queries |
| Message Cache | In-memory | 10 minutes | 20 conversations × 50 msgs | Fast message access |
| Photo URL Cache | In-memory | 1 hour | 100 entries | Avoid Firestore reads for photos |
| Current User Cache | In-memory + Firestore | 5 minutes | 1 entry | Fast current user access |
| Firestore Cache | Disk (native) | Persistent | 50MB | Offline support |
| Image Cache | Disk | Persistent | 50 items | CachedNetworkImage |

### Rate Limiting & Debouncing

| Operation | Limit | Purpose |
|-----------|-------|---------|
| Location updates | 60s + 100m movement | Prevent Firestore flooding |
| Post creation | 5-10/day (by account type) | Prevent spam |
| Photo URL retries | 5-minute cooldown | Handle 429 errors |
| Firestore queries | 200 docs max per match | Control costs |
| Service initialization | Once per app lifecycle | Singleton pattern |

### Memory Management

| Component | Strategy |
|-----------|----------|
| AppOptimizer | 100MB max memory cache, 50 image cache entries, 30-min cleanup |
| MemoryManager | 10MB max buffer, 1MB optimal chunk, 1-min periodic cleanup |
| Image Compression | Before upload (flutter_image_compress) |
| Video Compression | Before upload (video_compress) |
| LRU Eviction | Oldest entries removed when cache full |

### Firestore Optimization

- `limit()` on all queries (mandatory rule)
- `persistenceEnabled: true` with 50MB cache
- Pagination with `startAfter` cursor
- Debounced writes to prevent thrashing
- Batch operations with 500-item limit
- Index-backed queries (firestore.indexes.json)

### Build Optimization

| Setting | Value | Purpose |
|---------|-------|---------|
| MultiDex | Enabled | Support >65K methods |
| ProGuard | Enabled (release) | Code shrinking |
| Core Library Desugaring | 2.0.3 | Java 17 backport |
| Gradle Daemon | Disabled | Memory stability |
| JVM Args | -Xmx2048m | Build memory |

---

