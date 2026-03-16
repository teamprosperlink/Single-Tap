import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../res/config/app_text_styles.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../services/ip_location_service.dart';
// import '../../services/product_api_service.dart'; // removed — service deleted

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _descriptionController = TextEditingController();

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  TextEditingController? _activeController;

  final List<File> _selectedImages = [];
  bool _isLoading = false;
  final bool _postCreated = false;
  String _loadingStage = '';

  bool get _isFormValid =>
      _descriptionController.text.trim().isNotEmpty &&
      _selectedImages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _descriptionController.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    try { _speech.stop(); } catch (_) {}
    _descriptionController.dispose();
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

    // Try to initialize if not ready
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
    if (_selectedImages.length >= 3) {
      _showSnackBar('Maximum 3 images allowed', isError: true);
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
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_selectedImages.length >= 3) {
      _showSnackBar('Maximum 3 images allowed', isError: true);
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
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
  }

  Future<List<String>> _convertImagesToBase64() async {
    final base64Images = <String>[];
    int totalBytes = 0;
    const int maxTotalBytes = 9 * 1024 * 1024; // 9MB safety margin

    for (final file in _selectedImages) {
      try {
        final bytes = await file.readAsBytes();
        totalBytes += bytes.length;

        if (totalBytes > maxTotalBytes) {
          debugPrint('CreatePost: payload would exceed 9MB at image ${base64Images.length + 1}');
          _showSnackBar(
            'Images are too large. Using first ${base64Images.length} image(s) only.',
            isError: false,
          );
          break;
        }

        base64Images.add(base64Encode(bytes));
      } catch (e) {
        debugPrint('CreatePost: failed to encode image: $e');
      }
    }

    return base64Images;
  }

  Future<void> _createPost() async {
    if (_isLoading || _postCreated) return;

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please enter a description', isError: true);
      return;
    }

    if (_selectedImages.isEmpty) {
      _showSnackBar('Please add at least one image', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingStage = 'Preparing...';
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please login to create a post', isError: true);
        return;
      }

      // Detect location via IpLocationService
      if (mounted) setState(() => _loadingStage = 'Detecting location...');
      try {
        await IpLocationService.detectLocation();
      } catch (e) {
        debugPrint('CreatePost: location error: $e');
      }

      // Convert images to base64 for API upload
      if (mounted) setState(() => _loadingStage = 'Preparing images...');
      final base64Images = await _convertImagesToBase64();

      if (base64Images.isEmpty) {
        _showSnackBar('Failed to process images. Please try again.', isError: true);
        return;
      }

      // TODO: ProductApiService removed — post creation not available
      if (mounted) {
        _showSnackBar('Post creation via API is not available.', isError: true);
      }
      return;
    } catch (e) {
      debugPrint('CreatePost: unexpected error: $e');
      if (mounted) {
        _showSnackBar('Failed to create post. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStage = '';
        });
      }
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

  @override
  Widget build(BuildContext context) {
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
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        title: const Text(
          'Create NearBy Post',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
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
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo Upload Section
                          _buildPhotoSection(),
                          const SizedBox(height: 12),

                          // Description Field
                          _buildLabeledField(
                            label: 'Description',
                            isMandatory: true,
                            controller: _descriptionController,
                            maxLength: 250,
                            child: _buildGlassTextField(
                              controller: _descriptionController,
                              hintText: 'Add more details...',
                              prefixIcon: Icons.description_outlined,
                              maxLines: null,
                              maxLength: 250,
                              showMic: true,
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

            // Loading overlay
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
                              fontSize: 14,
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
    int? maxLines = 1,
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
                          fontFamily: 'Poppins',
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
                            fontFamily: 'Poppins',
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      );
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
                prefixIcon: Icon(prefixIcon, color: Colors.grey[400], size: 20),
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
                suffixText: suffixText,
                suffixStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                prefixText: prefixText,
                prefixStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Add Photo'),
                  TextSpan(
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
            Text(
              '${_selectedImages.length}/3',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _selectedImages.length >= 3
                    ? Colors.red
                    : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Selected images preview
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImages[index],
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
                              _selectedImages.removeAt(index);
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
        if (_selectedImages.length < 3)
          Row(
            children: [
              _buildPhotoButton(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: _pickImageFromCamera,
              ),
              const SizedBox(width: 14),
              _buildPhotoButton(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: _pickImageFromGallery,
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
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final bool enabled = _isFormValid && !_isLoading;
    return GestureDetector(
      onTap: enabled ? _createPost : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF016CFF)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF016CFF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Create Post',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
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
