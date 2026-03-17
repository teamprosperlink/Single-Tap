import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../res/config/app_text_styles.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../services/product_api_service.dart';
import '../../services/ip_location_service.dart';
import 'api_my_posts_screen.dart';

class ApiCreatePostScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final String? initialDescription;
  final bool isPopup;

  const ApiCreatePostScreen({super.key, this.onBack, this.initialDescription, this.isPopup = false});

  @override
  State<ApiCreatePostScreen> createState() => _ApiCreatePostScreenState();
}

class _ApiCreatePostScreenState extends State<ApiCreatePostScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  TextEditingController? _activeController;

  final List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _postCreated = false; // Prevents duplicate posts after success
  String _loadingStage = '';

  // Pre-fetched location (starts in initState to avoid lag on submit)
  Future<Map<String, dynamic>>? _locationFuture;

  bool get _isFormValid =>
      _descriptionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    if (widget.initialDescription != null && widget.initialDescription!.isNotEmpty) {
      _descriptionController.text = widget.initialDescription!;
    }
    _descriptionController.addListener(() { if (mounted) setState(() {}); });

    // Pre-warm backend + pre-fetch location as soon as screen opens
    ProductApiService().warmUp();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _locationFuture = _detectLocation(user.uid);
    }
  }

  @override
  void dispose() {
    try { _speech.stop(); } catch (_) {}
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  // ── Speech to text ──

  Future<void> _toggleMic(TextEditingController controller) async {
    if (_activeController == controller) {
      _speech.stop();
      setState(() => _activeController = null);
      return;
    }

    // Don't start mic if text field already has data
    if (controller.text.trim().isNotEmpty) return;

    if (!_speechEnabled) {
      try { _speechEnabled = await _speech.initialize(); } catch (_) {}
    }

    if (!_speechEnabled) {
      if (mounted) _showSnackBar('Mic permission denied or not supported', isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    _speech.stop();
    setState(() => _activeController = controller);
    _speech.listen(
      onResult: (result) {
        if (mounted && result.recognizedWords.isNotEmpty) {
          setState(() { controller.text = result.recognizedWords; });
          if (result.finalResult) setState(() => _activeController = null);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  // ── Image picking ──

  Future<void> _pickImageFromGallery() async {
    if (_selectedImages.isNotEmpty) {
      _showSnackBar('Maximum 1 image allowed', isError: true);
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 45,
      );
      if (image != null && mounted) {
        setState(() => _selectedImages.add(File(image.path)));
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_selectedImages.isNotEmpty) {
      _showSnackBar('Maximum 1 image allowed', isError: true);
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 45,
      );
      if (image != null && mounted) {
        setState(() => _selectedImages.add(File(image.path)));
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
    }
  }

  // ── Base64 encoding ──

  static List<String> _encodeBytesIsolate(List<Uint8List> bytesList) {
    final base64List = <String>[];
    for (final bytes in bytesList) {
      // Skip images over 500KB raw (would be ~670KB base64)
      if (bytes.length > 500 * 1024) continue;
      base64List.add(base64Encode(bytes));
    }
    return base64List;
  }

  // ── Location detection (extracted for parallel execution) ──

  Future<Map<String, dynamic>> _detectLocation(String userId) async {
    double lat = 0;
    double lng = 0;
    String locationName = '';
    Map<String, dynamic> userData = {};

    // Step 1: Try Firestore profile (instant from cache)
    try {
      debugPrint('CreatePost: fetching user profile for location...');
      final userDocSnap = await FirebaseFirestore.instance
          .collection('users').doc(userId).get();
      if (userDocSnap.exists) {
        userData = userDocSnap.data() ?? {};
        final fLat = (userData['latitude'] as num?)?.toDouble();
        final fLng = (userData['longitude'] as num?)?.toDouble();
        final fCity = (userData['city'] as String? ?? '').toLowerCase();
        final isMVCoords = (fLat != null && fLng != null &&
            (fLat - 37.422).abs() < 0.05 && (fLng + 122.084).abs() < 0.05);
        if (fLat != null && fLng != null &&
            !fCity.contains('mountain view') &&
            !isMVCoords &&
            !(fLat.abs() < 0.01 && fLng.abs() < 0.01)) {
          lat = fLat;
          lng = fLng;
          locationName = userData['city'] as String? ??
              userData['location'] as String? ?? '';
          debugPrint('CreatePost: using Firestore location: $locationName ($lat, $lng)');
        }
      }
    } catch (e) {
      debugPrint('CreatePost: Firestore profile fetch error: $e');
    }

    // Step 2: Try GPS/IP if Firestore didn't have valid location
    if (lat == 0 && lng == 0) {
      debugPrint('CreatePost: Firestore location unavailable, trying GPS/IP...');
      try {
        final locResult = await IpLocationService.detectLocation();
        if (locResult != null) {
          lat = (locResult['lat'] as num?)?.toDouble() ?? 0;
          lng = (locResult['lng'] as num?)?.toDouble() ?? 0;
          locationName = (locResult['displayAddress'] as String?) ?? '';
          debugPrint('CreatePost: GPS/IP location: $locationName ($lat, $lng)');
        }
      } catch (e) {
        debugPrint('CreatePost: GPS/IP location error: $e');
      }
    }

    if (lat == 0 && lng == 0) {
      debugPrint('CreatePost: no location detected, proceeding with 0,0');
    }

    return {'lat': lat, 'lng': lng, 'locationName': locationName, 'userData': userData};
  }

  // ── Submit ──

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _submitPost() async {
    // ── Guard: prevent duplicate submissions ──
    if (_isLoading || _postCreated) return;

    // ── Validate inputs before doing anything ──
    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      _showSnackBar('Please enter a description', isError: true);
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Please login to create a post', isError: true);
      return;
    }

    // Set loading IMMEDIATELY to prevent duplicate taps (before any async work)
    setState(() {
      _isLoading = true;
      _loadingStage = _selectedImages.isNotEmpty ? 'Preparing images...' : 'Processing...';
    });

    final priceText = _priceController.text.trim();
    final double? price = priceText.isNotEmpty ? double.tryParse(priceText) : null;

    try {
      List<String> base64Images = [];

      if (_selectedImages.isNotEmpty) {
        // Validate all image files exist in parallel
        final existChecks = await Future.wait(
          _selectedImages.map((file) async => (await file.exists()) ? file : null),
        );
        final validImages = existChecks.whereType<File>().toList();
        if (validImages.isEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar('Selected images are no longer available. Please re-select.', isError: true);
          }
          return;
        }

        // ── Read ALL images in parallel ──
        debugPrint('CreatePost: reading ${validImages.length} images in parallel...');
        final allBytes = await Future.wait(
          validImages.map((file) async {
            try {
              return await file.readAsBytes();
            } catch (e) {
              debugPrint('CreatePost: failed to read ${file.path}: $e');
              return Uint8List(0);
            }
          }),
        );
        final bytesList = allBytes.where((b) => b.length > 100).toList();

        if (bytesList.isEmpty) {
          if (mounted) _showSnackBar('Failed to read images. Please re-select.', isError: true);
          return;
        }
        debugPrint('CreatePost: ${bytesList.length} images read successfully');

        // ── Encode images + reuse pre-fetched location (started in initState) ──
        if (mounted) setState(() => _loadingStage = 'Uploading & AI analyzing...');

        final encodingFuture = compute(_encodeBytesIsolate, bytesList);
        _locationFuture ??= _detectLocation(currentUser.uid);

        final results = await Future.wait([encodingFuture, _locationFuture!]);
        base64Images = results[0] as List<String>;

        if (base64Images.isEmpty) {
          if (mounted) {
            _showSnackBar('Images are too large. Please use smaller photos (under 500KB each).', isError: true);
          }
          return;
        }
        debugPrint('CreatePost: ${base64Images.length} images encoded to base64');

        // Warn if some images were skipped
        if (base64Images.length < bytesList.length && mounted) {
          _showSnackBar('${bytesList.length - base64Images.length} large image(s) skipped', isError: false);
        }
      } else {
        // No images — just fetch location
        if (mounted) setState(() => _loadingStage = 'AI analyzing...');
        _locationFuture ??= _detectLocation(currentUser.uid);
      }

      // Reuse pre-fetched location from initState; fallback to fresh fetch
      _locationFuture ??= _detectLocation(currentUser.uid);
      final locData = await _locationFuture!;

      final double lat = locData['lat'] as double;
      final double lng = locData['lng'] as double;
      final String locationName = locData['locationName'] as String;
      final Map<String, dynamic> userData = locData['userData'] as Map<String, dynamic>;

      final autoTitle = description.length > 30 ? '${description.substring(0, 27)}...' : description;

      // ── Call API ──
      debugPrint('CreatePost: calling API with ${base64Images.length} images, location=($lat,$lng)...');
      final result = await ProductApiService().createPost(
        query: autoTitle,
        description: description,
        price: price,
        lat: lat,
        lng: lng,
        images: base64Images,
        locationName: locationName,
      );

      debugPrint('CreatePost: API response success=${result['success']}, error=${result['error']}');

      if (result['success'] != true) {
        final errorMsg = result['error']?.toString() ?? 'Failed to create post';
        if (mounted) {
          SnackBarHelper.showError(context, errorMsg);
        }
        return;
      }

      // ── API succeeded — mark as created to prevent duplicates ──
      _postCreated = true;
      debugPrint('CreatePost: API success! listingId=${result['listingId']}');

      // Clear search cache so next search fetches fresh results with new post
      ProductApiService().resetCache();

      // ── Save to Firestore — await so post shows in My Posts ──
      if (mounted) setState(() => _loadingStage = 'Saving post...');
      await _savePostToFirestore(
        currentUser: currentUser,
        userData: userData,
        result: result,
        title: autoTitle,
        description: description,
        location: locationName,
        lat: lat,
        lng: lng,
        price: price,
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Post created successfully!');
        _goBack();
      }
    } catch (e, stackTrace) {
      debugPrint('CreatePost ERROR: $e');
      debugPrint('CreatePost STACK: $stackTrace');
      if (mounted) _showSnackBar('Error: ${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Save post to Firestore — always uses listingId as doc ID to prevent duplicates
  Future<void> _savePostToFirestore({
    required User currentUser,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> result,
    required String title,
    required String description,
    required String location,
    required double lat,
    required double lng,
    double? price,
  }) async {
    try {
      final listingId = result['listingId'] as String? ?? '';

      // Safely extract images from API response
      List<String> apiImages = [];
      try {
        final apiData = result['data'];
        if (apiData != null && apiData.images is List) {
          apiImages = List<String>.from(
            (apiData.images as List).where((e) => e != null && e.toString().isNotEmpty).map((e) => e.toString()),
          );
        }
      } catch (e) {
        debugPrint('CreatePost: failed to extract images from API response: $e');
      }

      debugPrint('CreatePost: saving to Firestore, listingId=$listingId, images=${apiImages.length}');

      final postDoc = {
        'userId': currentUser.uid,
        'userName': userData['name'] ?? userData['displayName'] ?? '',
        'userPhoto': userData['photoUrl'] ?? userData['photoURL'] ?? '',
        'title': title,
        'description': description,
        'originalPrompt': title,
        'location': location,
        'latitude': lat,
        'longitude': lng,
        'images': apiImages,
        'imageUrl': apiImages.isNotEmpty ? apiImages.first : '',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
        if (price != null) 'price': price,
        if (listingId.isNotEmpty) 'listingId': listingId,
        'source': 'api_listing',
      };

      // Use listingId as document ID to prevent duplicates
      // .set() will overwrite if same listingId is used again = no duplicate
      if (listingId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(listingId)
            .set(postDoc);
      } else {
        // Fallback: use userId + timestamp to create unique but deterministic ID
        final docId = '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(docId)
            .set(postDoc);
      }
      debugPrint('CreatePost: saved to Firestore successfully');
    } catch (e) {
      debugPrint('CreatePost: Firestore save failed: $e');
      // Don't block — API post was already created successfully
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    if (isError) {
      SnackBarHelper.showError(context, message);
    } else {
      SnackBarHelper.showSuccess(context, message);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (widget.isPopup) return _buildPopup(context);
    return _buildFullScreen(context);
  }

  Widget _buildPopup(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(50, 50, 50, 1), Color.fromRGBO(20, 20, 20, 1)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          'Create Post',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7), size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                  // Form content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPhotoSection(),
                          const SizedBox(height: 12),
                          _buildLabeledField(
                            label: 'What are you posting?',
                            isMandatory: true,
                            controller: _descriptionController,
                            maxLength: 500,
                            child: _buildGlassTextField(
                              controller: _descriptionController,
                              hintText: 'Describe your item, service, or need...',
                              prefixIcon: null,
                              maxLines: null,
                              minLines: 2,
                              maxLength: 500,
                              showMic: true,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildCreateButton(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          if (_loadingStage.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              _loadingStage,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildFullScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 56,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(40, 40, 40, 1), Color.fromRGBO(64, 64, 64, 1)],
            ),
            border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
          ),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiMyPostsScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.dynamic_feed,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo Section
                            _buildPhotoSection(),
                            const SizedBox(height: 12),

                            // Description
                            _buildLabeledField(
                              label: 'What are you posting?',
                              isMandatory: true,
                              controller: _descriptionController,
                              maxLength: 500,
                              child: _buildGlassTextField(
                                controller: _descriptionController,
                                hintText: 'Add more details...',
                                prefixIcon: Icons.description_outlined,
                                maxLines: null,
                                maxLength: 500,
                                showMic: true,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Price
                            _buildLabeledField(
                              label: 'Price',
                              isMandatory: false,
                              controller: _priceController,
                              maxLength: 15,
                              child: _buildGlassTextField(
                                controller: _priceController,
                                hintText: 'Enter price (optional)',
                                prefixIcon: Icons.currency_rupee,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                                  TextInputFormatter.withFunction((oldValue, newValue) {
                                    // Prevent multiple decimal points
                                    if (newValue.text.split('.').length > 2) return oldValue;
                                    return newValue;
                                  }),
                                ],
                                maxLength: 15,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Create Button
                            _buildCreateButton(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        if (_loadingStage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            _loadingStage,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  // ── Reusable: Labeled field with char counter ──

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required int maxLength,
    required Widget child,
    bool isMandatory = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label),
                  if (isMandatory)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                ],
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Text(
                  '${controller.text.length}/$maxLength',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: controller.text.length >= maxLength ? Colors.red : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  // ── Reusable: Glass text field with mic ──

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    int? maxLines = 1,
    int? minLines,
    int? maxLength,
    TextInputType? keyboardType,
    String? prefixText,
    String? suffixText,
    bool showMic = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final bool isListening = _activeController == controller;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isListening
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: isListening
          ? GestureDetector(
              onTap: () => _toggleMic(controller),
              child: Container(
                height: maxLines == 1 ? 50 : 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(10, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 3,
                          height: 6.0 + (index % 3 == 0 ? 18.0 : (index % 2 == 0 ? 12.0 : 8.0)),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        controller.text.isNotEmpty ? controller.text : 'Listening...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: controller.text.isNotEmpty ? Colors.white : Colors.grey[400],
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.stop_rounded, color: Colors.red, size: 24),
                  ],
                ),
              ),
            )
          : TextField(
              controller: controller,
              maxLines: maxLines,
              minLines: minLines,
              maxLength: maxLength,
              buildCounter: maxLength != null
                  ? (context, {required currentLength, required isFocused, required maxLength}) {
                      return const SizedBox.shrink();
                    }
                  : null,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              cursorColor: Colors.white,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[400], size: 20) : null,
                suffixIcon: showMic
                    ? GestureDetector(
                        onTap: () => _toggleMic(controller),
                        child: Icon(
                          Icons.mic_rounded,
                          color: controller.text.trim().isNotEmpty
                              ? Colors.grey[700]
                              : Colors.grey[400],
                          size: 22,
                        ),
                      )
                    : null,
                suffixText: suffixText,
                suffixStyle: const TextStyle(
                  fontFamily: 'Poppins', color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600,
                ),
                prefixText: prefixText,
                prefixStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
              ),
            ),
    );
  }

  // ── Photo Section (Add Photo label + Camera/Gallery + preview) ──

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add Photo',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_selectedImages.length}/1',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _selectedImages.isNotEmpty ? Colors.red : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Camera & Gallery buttons
        if (_selectedImages.isEmpty)
          Row(
            children: [
              _buildPhotoButton(icon: Icons.camera_alt_rounded, label: 'Camera', onTap: _pickImageFromCamera),
              const SizedBox(width: 14),
              _buildPhotoButton(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: _pickImageFromGallery),
            ],
          ),

        // Selected images preview
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 65,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImages[index],
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Create Button ──

  Widget _buildCreateButton() {
    final bool enabled = _isFormValid && !_isLoading && !_postCreated;
    return GestureDetector(
      onTap: enabled ? _submitPost : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF016CFF) : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35), size: 22),
            const SizedBox(width: 10),
            Text(
              'Create Post',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
