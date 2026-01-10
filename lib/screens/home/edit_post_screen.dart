import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../res/config/app_assets.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/utils/snackbar_helper.dart';

class EditPostScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const EditPostScreen({
    super.key,
    required this.postId,
    required this.postData,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();

  File? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _allowCalls = true;
  String _selectedCurrency = 'INR';
  List<String> _hashtags = [];

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  String _fullSpeechText = '';

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPostData();
    _initSpeech();
  }

  void _loadPostData() {
    final post = widget.postData;
    _titleController.text = post['title'] ?? '';
    _descriptionController.text = post['description'] ?? '';
    _priceController.text = post['price']?.toString() ?? '';
    _existingImageUrl = post['imageUrl'];
    _allowCalls = post['allowCalls'] ?? true;
    _selectedCurrency = post['currency'] ?? 'INR';
    _hashtags = List<String>.from(post['hashtags'] ?? []);
  }

  @override
  void dispose() {
    _speech.stop();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            _showSnackBar('Speech recognition error', isError: true);
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  // Start listening for full voice input
  Future<void> _startVoiceInput() async {
    if (!_speechEnabled) {
      _showSnackBar('Speech recognition not available', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isListening = true;
      _fullSpeechText = '';
    });

    await _speech.listen(
      onResult: (result) {
        if (mounted && result.recognizedWords.isNotEmpty) {
          setState(() {
            _fullSpeechText = result.recognizedWords;
          });
          // Parse when speech is final
          if (result.finalResult) {
            _parseVoiceInput(_fullSpeechText);
          }
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_IN',
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  // Stop listening and parse
  Future<void> _stopVoiceInput() async {
    HapticFeedback.lightImpact();
    await _speech.stop();
    if (_fullSpeechText.isNotEmpty) {
      _parseVoiceInput(_fullSpeechText);
    }
    setState(() {
      _isListening = false;
    });
  }

  // Parse voice input into fields
  void _parseVoiceInput(String text) {
    if (text.isEmpty) return;

    String lowerText = text.toLowerCase();
    String remainingText = text;

    // Extract price
    final pricePatterns = [
      RegExp(
        r'(?:price|cost|amount|rupees|rs|₹|inr|\$|dollar|usd)\s*[:\s]*(\d+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+(?:\.\d{1,2})?)\s*(?:rupees|rs|₹|inr|dollar|\$|usd)',
        caseSensitive: false,
      ),
      RegExp(r'for\s+(\d+(?:\.\d{1,2})?)', caseSensitive: false),
    ];

    for (final pattern in pricePatterns) {
      final priceMatch = pattern.firstMatch(lowerText);
      if (priceMatch != null) {
        final priceValue = priceMatch.group(1);
        if (priceValue != null) {
          _priceController.text = priceValue;
          remainingText = remainingText
              .replaceFirst(priceMatch.group(0)!, '')
              .trim();
          break;
        }
      }
    }

    // Extract hashtags
    final hashtagPattern = RegExp(r'#(\w+)', caseSensitive: false);
    final hashtagMatches = hashtagPattern.allMatches(remainingText);
    for (final match in hashtagMatches) {
      final tag = match.group(1);
      if (tag != null &&
          !_hashtags.contains('#$tag') &&
          _hashtags.length < 10) {
        _hashtags.add('#$tag');
      }
      remainingText = remainingText.replaceFirst(match.group(0)!, '').trim();
    }

    // Check for "hashtag" keyword
    final hashtagKeywordPattern = RegExp(
      r'hashtag[s]?\s+(\w+(?:\s+\w+)*)',
      caseSensitive: false,
    );
    final keywordMatch = hashtagKeywordPattern.firstMatch(remainingText);
    if (keywordMatch != null) {
      final hashtagWords = keywordMatch.group(1)?.split(RegExp(r'\s+'));
      if (hashtagWords != null) {
        for (final word in hashtagWords) {
          if (word.isNotEmpty &&
              !_hashtags.contains('#$word') &&
              _hashtags.length < 10) {
            _hashtags.add('#$word');
          }
        }
      }
      remainingText = remainingText
          .replaceFirst(keywordMatch.group(0)!, '')
          .trim();
    }

    // Clean up remaining text
    remainingText = remainingText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[,\.]+\s*$'), '')
        .trim();

    // Split into title and description
    if (remainingText.isNotEmpty) {
      final sentenceEnd = RegExp(r'[.!?]').firstMatch(remainingText);
      String title;
      String description = '';

      if (sentenceEnd != null && sentenceEnd.start < 80) {
        title = remainingText.substring(0, sentenceEnd.start + 1).trim();
        description = remainingText.substring(sentenceEnd.start + 1).trim();
      } else if (remainingText.length <= 60) {
        title = remainingText;
      } else {
        int breakPoint = 60;
        for (int i = 59; i > 20; i--) {
          if (remainingText[i] == ' ') {
            breakPoint = i;
            break;
          }
        }
        title = remainingText.substring(0, breakPoint).trim();
        description = remainingText.substring(breakPoint).trim();
      }

      _titleController.text = title;
      if (description.isNotEmpty) {
        _descriptionController.text = description;
      }
    }

    setState(() {});

    if (_titleController.text.isNotEmpty) {
      _showSnackBar('Voice input parsed successfully!', isError: false);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
          _existingImageUrl = null;
        });
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
          _existingImageUrl = null;
        });
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }

  void _addHashtag() {
    final tag = _hashtagController.text.trim();
    if (tag.isEmpty) return;

    // Max 10 hashtags allowed
    if (_hashtags.length >= 10) {
      _showSnackBar('Maximum 10 hashtags allowed', isError: true);
      return;
    }

    if (!_hashtags.contains(tag) && !_hashtags.contains('#$tag')) {
      setState(() {
        _hashtags.add(tag.startsWith('#') ? tag : '#$tag');
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String tag) {
    setState(() {
      _hashtags.remove(tag);
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _existingImageUrl = null;
    });
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _existingImageUrl;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('posts/$userId/$fileName');

      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _updatePost() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please login to update post', isError: true);
        return;
      }

      // Upload new image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      } else {
        imageUrl = _existingImageUrl;
      }

      // Parse price
      double? price;
      if (_priceController.text.isNotEmpty) {
        price = double.tryParse(_priceController.text);
      }

      // Update post data
      final postData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'originalPrompt': _titleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'allowCalls': _allowCalls,
        'currency': _selectedCurrency,
        'hashtags': _hashtags,
      };

      if (imageUrl != null) {
        postData['imageUrl'] = imageUrl;
      } else {
        postData['imageUrl'] = FieldValue.delete();
      }

      if (price != null) {
        postData['price'] = price;
      } else {
        postData['price'] = FieldValue.delete();
      }

      await _firestore.collection('posts').doc(widget.postId).update(postData);

      if (mounted) {
        _showSnackBar('Post updated successfully!', isError: false);
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error updating post: $e');
      if (mounted) {
        _showSnackBar('Failed to update post', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (isError) {
      SnackBarHelper.showError(context, message);
    } else {
      SnackBarHelper.showSuccess(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Dark overlay
          Positioned.fill(child: Container(color: AppColors.darkOverlay())),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Divider line
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Voice Input Button - Single mic for all fields
                        _buildVoiceInputSection(),

                        const SizedBox(height: 20),

                        // Title Field
                        _buildGlassTextField(
                          controller: _titleController,
                          hintText: 'What are you posting?',
                          prefixIcon: Icons.title_rounded,
                          maxLines: 1,
                        ),

                        const SizedBox(height: 16),

                        // Description Field
                        _buildGlassTextField(
                          controller: _descriptionController,
                          hintText: 'Add more details...',
                          prefixIcon: Icons.description_outlined,
                          maxLines: 4,
                        ),

                        const SizedBox(height: 20),

                        // Photo Upload Section
                        _buildPhotoSection(),

                        const SizedBox(height: 20),

                        // Currency and Price Row
                        _buildPriceSection(),

                        const SizedBox(height: 20),

                        // Allow Calls Toggle
                        _buildCallToggle(),

                        const SizedBox(height: 20),

                        // Hashtags Section
                        _buildHashtagSection(),

                        const SizedBox(height: 32),

                        // Update Button
                        _buildUpdateButton(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Edit Post',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Placeholder for symmetry
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // Voice Input Section - Single mic button for all fields
  Widget _buildVoiceInputSection() {
    return GestureDetector(
      onTap: () {
        if (_isListening) {
          _stopVoiceInput();
        } else {
          _startVoiceInput();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.buttonBorderRadius),
          color: _isListening
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.buttonBackground(),
          border: Border.all(
            color: _isListening
                ? AppColors.error.withValues(alpha: 0.5)
                : AppColors.buttonBorder(),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Mic Icon on left
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? AppColors.error : AppColors.iosBlue,
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // Text instructions on right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _isListening ? 'Listening...' : 'Tap to speak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Recording indicator
                      if (_isListening) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.error,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isListening
                        ? (_fullSpeechText.isNotEmpty
                              ? _fullSpeechText
                              : 'Say title, description, price, hashtags...')
                        : 'Speak everything at once - title, price, hashtags',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        cursorColor: Colors.white,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(prefixIcon, color: Colors.grey[400], size: 22),
          prefixText: prefixText,
          prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Show existing image, new selected image, or upload buttons
        if (_selectedImage != null)
          _buildImagePreview(
            child: Image.file(
              _selectedImage!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          )
        else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
          _buildImagePreview(
            child: CachedNetworkImage(
              imageUrl: _existingImageUrl!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 200,
                color: Colors.grey[800],
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[800],
                child: const Icon(Icons.error, color: Colors.white),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildPhotoButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: _pickImageFromCamera,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPhotoButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: _pickImageFromGallery,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImagePreview({required Widget child}) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _removeImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              // Show options to change image
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Take Photo',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromCamera();
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Choose from Gallery',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromGallery();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.iosBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price (Optional)',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Currency Dropdown
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCurrency,
                  dropdownColor: const Color(0xFF2D2D3A),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 300,
                  items: _currencies.map((currency) {
                    return DropdownMenuItem<String>(
                      value: currency['code'],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${currency['symbol']} ${currency['code']}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCurrency = value;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Price Field
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    cursorColor: Colors.white,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter price',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCallToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _allowCalls
                  ? AppColors.vibrantGreen.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.call_rounded,
              color: _allowCalls ? AppColors.vibrantGreen : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Allow Calls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _allowCalls,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              setState(() {
                _allowCalls = value;
              });
            },
            activeThumbColor: AppColors.vibrantGreen,
            activeTrackColor: AppColors.vibrantGreen.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hashtags',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Hashtag input
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hashtagController,
                  cursorColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  onSubmitted: (_) => _addHashtag(),
                  decoration: InputDecoration(
                    hintText: 'Add hashtag',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: Colors.grey[400],
                      size: 22,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addHashtag,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.buttonBackground(),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.buttonBorder(),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Hashtag chips
        if (_hashtags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hashtags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeHashtag(tag),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildUpdateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _updatePost,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.buttonBackground(),
          borderRadius: BorderRadius.circular(AppColors.buttonBorderRadius),
          border: Border.all(color: AppColors.buttonBorder(), width: 1),
        ),
        child: const Center(
          child: Text(
            'Update Post',
            style: TextStyle(
              color: AppColors.buttonForeground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
