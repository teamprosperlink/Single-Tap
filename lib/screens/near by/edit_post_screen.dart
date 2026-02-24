import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  TextEditingController? _activeController;

  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  bool _isLoading = false;
  bool _allowCalls = true;
  bool _isDonation = false;
  String _selectedCurrency = 'INR';
  List<String> _hashtags = [];

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
    _allowCalls = post['allowCalls'] ?? true;
    _isDonation = post['isDonation'] ?? false;
    _selectedCurrency = post['currency'] ?? 'INR';
    _hashtags = List<String>.from(post['hashtags'] ?? []);

    // Load existing images
    final images = post['images'] as List<dynamic>? ?? [];
    final rawImageUrl = post['imageUrl'];
    if (rawImageUrl != null && rawImageUrl.toString().isNotEmpty) {
      _existingImageUrls.add(rawImageUrl.toString());
    }
    for (final img in images) {
      final url = img?.toString() ?? '';
      if (url.isNotEmpty && !_existingImageUrls.contains(url)) {
        _existingImageUrls.add(url);
      }
    }
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

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  Future<void> _toggleMic(TextEditingController controller) async {
    if (_activeController == controller) {
      _speech.stop();
      setState(() => _activeController = null);
      return;
    }

    if (!_speechEnabled) {
      try {
        _speechEnabled = await _speech.initialize();
      } catch (_) {}
    }

    if (!_speechEnabled) {
      if (mounted) {
        _showSnackBar('Mic permission denied or not supported', isError: true);
      }
      return;
    }

    HapticFeedback.lightImpact();
    _speech.stop();
    setState(() => _activeController = controller);
    _speech.listen(
      onResult: (result) {
        if (mounted && result.recognizedWords.isNotEmpty) {
          setState(() {
            controller.text = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() => _activeController = null);
          }
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

  Future<void> _pickImageFromCamera() async {
    if (_selectedImages.length + _existingImageUrls.length >= 3) {
      _showSnackBar('Maximum 3 images allowed', isError: true);
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_selectedImages.length + _existingImageUrls.length >= 3) {
      _showSnackBar('Maximum 3 images allowed', isError: true);
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }

  void _addHashtag() {
    final tag = _hashtagController.text.trim();
    if (tag.isEmpty) return;

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

  Future<List<String>> _uploadNewImages() async {
    if (_selectedImages.isEmpty) return [];

    final List<String> urls = [];
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child('posts/$userId/$fileName');
        await ref.putFile(_selectedImages[i]);
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
    }
    return urls;
  }

  Future<void> _updatePost() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', isError: true);
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please enter a description', isError: true);
      return;
    }

    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      _showSnackBar('Please add at least one image', isError: true);
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

      // Upload new images
      final newImageUrls = await _uploadNewImages();
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

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
        'isDonation': _isDonation,
        'currency': _selectedCurrency,
        'hashtags': _hashtags,
      };

      if (allImageUrls.isNotEmpty) {
        postData['imageUrl'] = allImageUrls.first;
        postData['images'] = allImageUrls;
      } else {
        postData['imageUrl'] = FieldValue.delete();
        postData['images'] = FieldValue.delete();
      }

      if (price != null) {
        postData['price'] = price;
      } else {
        postData['price'] = FieldValue.delete();
      }

      await _firestore.collection('posts').doc(widget.postId).update(postData);

      if (mounted) {
        _showSnackBar('Post updated successfully!', isError: false);
        Navigator.pop(context, true);
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
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Field
                          _buildLabeledField(
                            label: 'Title',
                            controller: _titleController,
                            maxLength: 30,
                            child: _buildGlassTextField(
                              controller: _titleController,
                              hintText: 'What are you posting?',
                              prefixIcon: Icons.title_rounded,
                              maxLines: 1,
                              maxLength: 30,
                              showMic: true,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Description Field
                          _buildLabeledField(
                            label: 'Description',
                            controller: _descriptionController,
                            maxLength: 250,
                            child: _buildGlassTextField(
                              controller: _descriptionController,
                              hintText: 'Add more details...',
                              prefixIcon: Icons.description_outlined,
                              maxLines: 1,
                              maxLength: 250,
                              showMic: true,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Photo Upload Section
                          _buildPhotoSection(),

                          const SizedBox(height: 20),

                          // Donation Toggle
                          _buildDonationToggle(),

                          const SizedBox(height: 12),

                          // Currency and Price Row (hidden when donation)
                          if (!_isDonation) ...[
                            _buildPriceSection(),
                            const SizedBox(height: 20),
                          ],

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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(40, 40, 40, 1),
            Color.fromRGBO(64, 64, 64, 1),
          ],
        ),
        border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
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
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
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

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required int maxLength,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
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
                    color: controller.text.length >= maxLength
                        ? Colors.red
                        : Colors.grey[400],
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

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? prefixText,
    bool showMic = false,
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
          // Wave recording UI
          ? GestureDetector(
              onTap: () => _toggleMic(controller),
              child: Container(
                height: maxLines == 1 ? 50 : 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(10, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 3,
                          height:
                              6.0 +
                              (index % 3 == 0
                                  ? 18.0
                                  : (index % 2 == 0 ? 12.0 : 8.0)),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 12),
                    // Listening text
                    Expanded(
                      child: Text(
                        controller.text.isNotEmpty
                            ? controller.text
                            : 'Listening...',
                        style: TextStyle(
                          color: controller.text.isNotEmpty
                              ? Colors.white
                              : Colors.grey[400],
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stop icon
                    const Icon(Icons.stop_rounded, color: Colors.red, size: 24),
                  ],
                ),
              ),
            )
          // Normal text field
          : TextField(
              controller: controller,
              maxLines: maxLines,
              maxLength: maxLength,
              buildCounter: maxLength != null
                  ? (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12, top: 4),
                        child: Text(
                          '$currentLength/$maxLength',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      );
                    }
                  : null,
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
                suffixIcon: showMic
                    ? GestureDetector(
                        onTap: () => _toggleMic(controller),
                        child: Icon(
                          Icons.mic_rounded,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                      )
                    : null,
                prefixText: prefixText,
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    final totalImages = _existingImageUrls.length + _selectedImages.length;
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
              '$totalImages/3',
              style: TextStyle(
                color: totalImages >= 3 ? Colors.red : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Existing + new images preview
        if (totalImages > 0) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: totalImages,
              itemBuilder: (context, index) {
                final isExisting = index < _existingImageUrls.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: isExisting
                            ? CachedNetworkImage(
                                imageUrl: _existingImageUrls[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Image.file(
                                _selectedImages[index - _existingImageUrls.length],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExisting) {
                                _existingImageUrls.removeAt(index);
                              } else {
                                _selectedImages.removeAt(
                                  index - _existingImageUrls.length,
                                );
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Upload buttons (show when less than 3 images)
        if (totalImages < 3)
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
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
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
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
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
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
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
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
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

  Widget _buildDonationToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDonation
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: _isDonation ? Colors.orange : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Donation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _isDonation,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              setState(() {
                _isDonation = value;
                if (value) _priceController.clear();
              });
            },
            activeThumbColor: Colors.orange,
            activeTrackColor: Colors.orange.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
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
                  decoration: const BoxDecoration(
                    color: AppColors.iosBlue,
                    shape: BoxShape.circle,
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
          color: AppColors.iosBlue,
          borderRadius: BorderRadius.circular(16),
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
