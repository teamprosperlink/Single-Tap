import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  IconData get _categoryIcon {
    switch (widget.category) {
      case 'food':
        return Icons.restaurant;
      case 'electric':
        return Icons.devices;
      case 'house':
        return Icons.home_rounded;
      case 'place':
        return Icons.place;
      default:
        return Icons.category;
    }
  }

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.products);
    _initSpeech();
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                                        style: TextStyle(
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search $_categoryLabel...',
                                  hintStyle: TextStyle(
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
                                style: TextStyle(
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
                                childAspectRatio: 1.0,
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

  Widget _buildProductCard(Map<String, dynamic> item) {
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
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                item['image'] as String? ?? '',
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: Colors.grey[700],
                  child: Icon(_categoryIcon, color: Colors.white54, size: 40),
                ),
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 80,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item['name'] as String? ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Subtitle
                  Text(
                    _getSubtitle(item),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Price + Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['price'] as String? ?? '',
                          style: TextStyle(
                            color: Colors.green[400],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.star, color: Colors.amber[400], size: 14),
                      const SizedBox(width: 2),
                      Text(
                        '${item['rating'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Bottom info
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey[500],
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          _getBottomInfo(item),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
