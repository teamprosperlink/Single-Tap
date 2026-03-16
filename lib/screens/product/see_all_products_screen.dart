import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../res/utils/snackbar_helper.dart';
import 'product_detail_screen.dart';

class SeeAllProductsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final String category;

  const SeeAllProductsScreen({
    super.key,
    required this.products,
    required this.category,
  });

  @override
  State<SeeAllProductsScreen> createState() => _SeeAllProductsScreenState();
}

class _SeeAllProductsScreenState extends State<SeeAllProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  // Speech to text (same as home screen)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isRecording = false;
  Timer? _recordingTimer;
  String _currentSpeechText = '';

  // Saved posts
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _savedPostIds = {};

  String get _categoryLabel {
    switch (widget.category) {
      case 'food':
        return 'Food & Dining';
      case 'electric':
        return 'Electronics';
      case 'house':
        return 'Properties';
      case 'place':
        return 'Places';
      default:
        return 'Products';
    }
  }

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.products);
    _initSpeech();
    _loadSavedPosts();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recordingTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording) {
              _finishRecording();
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted && _isRecording) {
            _finishRecording();
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  void _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _currentSpeechText = '';
    });

    if (_speechEnabled) {
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted && result.recognizedWords.isNotEmpty) {
              setState(() {
                _currentSpeechText = result.recognizedWords;
              });
              if (result.finalResult && _currentSpeechText.isNotEmpty) {
                _finishRecording();
              }
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      } catch (e) {
        debugPrint('Error starting speech: $e');
        _recordingTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && _isRecording) _finishRecording();
        });
      }
    } else {
      // Speech not available, try re-init
      await _initSpeech();
      if (_speechEnabled) {
        _startVoiceRecording();
      } else {
        setState(() => _isRecording = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone not available')),
          );
        }
      }
    }
  }

  void _stopVoiceRecording() async {
    HapticFeedback.lightImpact();
    _recordingTimer?.cancel();
    if (_speechEnabled) {
      await _speech.stop();
    }
    _finishRecording();
  }

  void _finishRecording() {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final spokenText = _currentSpeechText.trim();

    setState(() {
      _isRecording = false;
    });

    if (spokenText.isNotEmpty) {
      _searchController.value = TextEditingValue(
        text: spokenText,
        selection: TextSelection.collapsed(offset: spokenText.length),
      );
      _onSearch(spokenText);
    }
  }

  // ── Saved Posts ──
  Future<void> _loadSavedPosts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .limit(200)
          .get();
      if (mounted) {
        setState(() {
          _savedPostIds.clear();
          for (final doc in snap.docs) {
            _savedPostIds.add(doc.id);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
    }
  }

  String _productSaveId(Map<String, dynamic> item) {
    final postId = item['postId'] ?? item['id'] ?? item['_id'];
    if (postId != null && postId.toString().isNotEmpty) return postId.toString();
    final name = (item['name'] ?? '').toString();
    final price = (item['price'] ?? '').toString();
    return 'product_${name.hashCode}_${price.hashCode}';
  }

  Future<void> _toggleSaveProduct(String productId, Map<String, dynamic> productData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    try {
      final savedRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(productId);
      if (_savedPostIds.contains(productId)) {
        await savedRef.delete();
        if (mounted) {
          setState(() => _savedPostIds.remove(productId));
          SnackBarHelper.showSuccess(context, 'Post unsaved');
        }
      } else {
        await savedRef.set({
          'postId': productId,
          'postData': productData,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _savedPostIds.add(productId));
          SnackBarHelper.showSuccess(context, 'Post saved');
        }
      }
    } catch (e) {
      if (mounted) SnackBarHelper.showError(context, 'Failed to save post');
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(widget.products);
      } else {
        _filtered = widget.products.where((item) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final subtitle = _getSubtitle(item).toLowerCase();
          final price = (item['price'] as String? ?? '').toLowerCase();
          return name.contains(q) || subtitle.contains(q) || price.contains(q);
        }).toList();
      }
    });
  }

  String _getSubtitle(Map<String, dynamic> item) {
    switch (widget.category) {
      case 'food':
        return item['restaurant'] as String? ?? '';
      case 'electric':
        return item['brand'] as String? ?? '';
      case 'house':
      case 'place':
        return item['location'] as String? ?? '';
      default:
        return '';
    }
  }

  String _getBottomInfo(Map<String, dynamic> item) {
    return item['distance'] as String? ?? item['location'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Text(
                      _categoryLabel,
                      style: const TextStyle(fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // White divider
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 1,
                color: Colors.white,
              ),

              // Scrollable content
              Expanded(
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    // Search Bar or Wave animation
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: _isRecording
                            ? Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    // Recording indicator dot
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Audio wave bars
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: List.generate(10, (index) {
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 3,
                                          height:
                                              6.0 +
                                              (index % 3 == 0
                                                  ? 18.0
                                                  : (index % 2 == 0
                                                        ? 12.0
                                                        : 8.0)),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(width: 8),
                                    // Listening text
                                    Expanded(
                                      child: Text(
                                        _currentSpeechText.isNotEmpty
                                            ? _currentSpeechText
                                            : 'Listening...',
                                        style: TextStyle(fontFamily: 'Poppins', 
                                          color: _currentSpeechText.isNotEmpty
                                              ? Colors.white
                                              : Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Stop button
                                    GestureDetector(
                                      onTap: _stopVoiceRecording,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                        ),
                                        child: const Icon(
                                          Icons.stop,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : TextField(
                                controller: _searchController,
                                onChanged: _onSearch,
                                style: const TextStyle(fontFamily: 'Poppins', 
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search $_categoryLabel...',
                                  hintStyle: TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: Colors.grey[300],
                                    size: 20,
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_searchController.text.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            _onSearch('');
                                          },
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.grey[300],
                                            size: 18,
                                          ),
                                        ),
                                      GestureDetector(
                                        onTap: _startVoiceRecording,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Icon(
                                            Icons.mic,
                                            color: Colors.grey[300],
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // Products Grid
                    if (_filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: Colors.grey[600],
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No results found',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.78,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildProductCard(_filtered[i]),
                            childCount: _filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gradient colors for initials placeholder based on name hash
  static const _placeholderGradients = [
    [Color(0xFFFF6B35), Color(0xFFFF8E53)],
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    [Color(0xFF0082C8), Color(0xFF667EEA)],
    [Color(0xFFE44D26), Color(0xFFF16529)],
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  ];

  Widget _buildInitialsPlaceholder(String name, int index) {
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';
    final colors = _placeholderGradients[index % _placeholderGradients.length];
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final imageUrl = item['image'] as String? ?? '';
    final price = item['price'] as String? ?? '';
    final location = _getBottomInfo(item);
    final matchScore = item['match_score'] as String? ?? '';
    final matchType = item['match_type'] as String? ?? '';
    final cardIndex = _filtered.indexOf(item);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(item: item, category: widget.category),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full cover image or initials placeholder
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) =>
                      _buildInitialsPlaceholder(name, cardIndex),
                )
              else
                _buildInitialsPlaceholder(name, cardIndex),

              // Bottom gradient fade
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.3, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // Match score badge (top-left) — 100% = Exact, else % Similar
              if (matchScore.isNotEmpty) ...[
                () {
                  final simScore = (item['similarity_score'] as num?)?.toDouble() ?? 0.0;
                  final isExact = simScore >= 1.0 || matchType == 'exact';
                  final scoreLabel = simScore < 0.10
                      ? 'Similar'
                      : '${(simScore * 100).toStringAsFixed(0)}% Match';
                  return Positioned(
                    top: 8,
                    left: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isExact
                                ? Colors.green.withValues(alpha: 0.7)
                                : Colors.orange.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            isExact ? 'Exact' : scoreLabel,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
              ],

              // Save / Bookmark button (top-right)
              Positioned(
                top: 8,
                right: 8,
                child: Builder(builder: (context) {
                  final saveId = _productSaveId(item);
                  final isSaved = _savedPostIds.contains(saveId);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleSaveProduct(saveId, item),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF016CFF).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  );
                }),
              ),

              // Bottom glassmorphism info bar
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Price + Rating row
                          Row(
                            children: [
                              if (price.isNotEmpty && price != '₹0' && price != '₹0.0')
                                Expanded(
                                  child: Text(
                                    price,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFF00D67D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                const Spacer(),
                            ],
                          ),
                          // Location row
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.near_me, color: Colors.grey[400], size: 10),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
