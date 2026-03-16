import 'dart:async';
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
import '../../services/location_services/geocoding_service.dart';
import '../../services/ip_location_service.dart';

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
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _offerController = TextEditingController();
  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  TextEditingController? _activeController;

  // Auto-detected GPS coordinates
  double? _detectedLat;
  double? _detectedLng;
  bool _isDetectingLocation = false;

  // Location search autocomplete
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  bool _showLocationSuggestions = false;
  Timer? _locationDebounce;

  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _keywords = [];
  bool _isLoading = false;
  bool _allowCalls = true;
  bool _isDonation = false;

  // Structured post type & sub-category
  String? _selectedPostType;
  String? _selectedSubCategory;

  static const Map<String, List<String>> _subCategoryMap = {
    'Services': [
      'Repair', 'Cleaning', 'Tutoring', 'Delivery', 'Salon & Beauty',
      'Photography', 'Web Development', 'Consulting', 'Plumbing',
      'Electrical', 'Painting', 'Catering', 'Mechanic', 'Carpentry', 'Others',
    ],
    'Jobs': [
      'Full Time', 'Part Time', 'Internship', 'Freelance',
      'Contract', 'Remote', 'Others',
    ],
    'Products': [
      'Electronics', 'Fashion', 'Furniture', 'Vehicles', 'Mobile & Phones',
      'Laptops', 'Books', 'Grocery', 'Appliances', 'Accessories', 'Others',
    ],
    'Donation': [
      'Clothes', 'Food', 'Books', 'Electronics', 'Furniture',
      'Toys', 'Medical', 'Others',
    ],
  };

  static const Map<String, IconData> _postTypeIcons = {
    'Services': Icons.build_rounded,
    'Jobs': Icons.work_rounded,
    'Products': Icons.shopping_bag_rounded,
    'Donation': Icons.volunteer_activism_rounded,
  };

  static const Map<String, List<Color>> _postTypeColors = {
    'Services': [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    'Jobs': [Color(0xFF6366F1), Color(0xFF818CF8)],
    'Products': [Color(0xFFF97316), Color(0xFFFB923C)],
    'Donation': [Color(0xFFEC4899), Color(0xFFF472B6)],
  };

  static const Map<String, IconData> _subCategoryIcons = {
    // Services
    'Repair': Icons.build_rounded,
    'Cleaning': Icons.cleaning_services_rounded,
    'Tutoring': Icons.menu_book_rounded,
    'Delivery': Icons.local_shipping_rounded,
    'Salon & Beauty': Icons.spa_rounded,
    'Photography': Icons.camera_alt_rounded,
    'Web Development': Icons.web_rounded,
    'Consulting': Icons.support_agent_rounded,
    'Plumbing': Icons.plumbing_rounded,
    'Electrical': Icons.electrical_services_rounded,
    'Painting': Icons.format_paint_rounded,
    'Catering': Icons.restaurant_rounded,
    'Mechanic': Icons.build_circle_rounded,
    'Carpentry': Icons.carpenter_rounded,
    // Jobs
    'Full Time': Icons.work_rounded,
    'Part Time': Icons.work_outline_rounded,
    'Internship': Icons.school_rounded,
    'Freelance': Icons.laptop_mac_rounded,
    'Contract': Icons.description_rounded,
    'Remote': Icons.home_work_rounded,
    // Products
    'Electronics': Icons.devices_rounded,
    'Fashion': Icons.checkroom_rounded,
    'Furniture': Icons.chair_rounded,
    'Vehicles': Icons.directions_car_rounded,
    'Mobile & Phones': Icons.phone_android_rounded,
    'Laptops': Icons.laptop_rounded,
    'Books': Icons.auto_stories_rounded,
    'Grocery': Icons.shopping_basket_rounded,
    'Appliances': Icons.kitchen_rounded,
    'Accessories': Icons.watch_rounded,
    // Donation
    'Clothes': Icons.checkroom_rounded,
    'Food': Icons.restaurant_rounded,
    'Toys': Icons.toys_rounded,
    'Medical': Icons.medical_services_rounded,
    // Shared
    'Others': Icons.more_horiz_rounded,
  };

  String _selectedCurrency = 'INR';
  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
  ];

  bool get _isFormValid =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      _selectedPostType != null &&
      (_selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _loadPostData();
    _initSpeech();
    _titleController.addListener(() { if (mounted) setState(() {}); });
    _descriptionController.addListener(() { if (mounted) setState(() {}); });
    _locationController.addListener(_onLocationTextChanged);
  }

  void _onLocationTextChanged() {
    if (!mounted) return;
    setState(() {});
    final query = _locationController.text.trim();
    _locationDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _locationSuggestions = [];
        _showLocationSuggestions = false;
      });
      return;
    }
    _locationDebounce = Timer(const Duration(milliseconds: 400), () {
      _searchLocationSuggestions(query);
    });
  }

  Future<void> _searchLocationSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingLocation = true);
    try {
      // Use detected GPS; if not ready, fetch from Firestore user profile
      double? lat = _detectedLat;
      double? lng = _detectedLng;
      if (lat == null || lng == null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            lat = (doc.data()?['latitude'] as num?)?.toDouble();
            lng = (doc.data()?['longitude'] as num?)?.toDouble();
          }
        }
      }
      final results = await GeocodingService.searchLocation(
        query,
        userLat: lat,
        userLng: lng,
      );
      if (mounted) {
        setState(() {
          _locationSuggestions = results;
          _showLocationSuggestions = results.isNotEmpty;
          _isSearchingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Location search error: $e');
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion) {
    final area = (suggestion['area'] ?? '').toString();
    final city = (suggestion['city'] ?? '').toString();
    final state = (suggestion['state'] ?? '').toString();

    String display = '';
    if (area.isNotEmpty && city.isNotEmpty && area != city) {
      display = '$area, $city';
    } else if (city.isNotEmpty && state.isNotEmpty) {
      display = '$city, $state';
    } else if (city.isNotEmpty) {
      display = city;
    } else if (area.isNotEmpty) {
      display = area;
    } else {
      display = (suggestion['formatted'] ?? '').toString().split(',').take(2).join(',').trim();
    }

    _locationController.removeListener(_onLocationTextChanged);
    _locationController.text = display;
    _locationController.addListener(_onLocationTextChanged);

    _detectedLat = (suggestion['latitude'] as num?)?.toDouble();
    _detectedLng = (suggestion['longitude'] as num?)?.toDouble();

    setState(() {
      _showLocationSuggestions = false;
      _locationSuggestions = [];
    });
  }

  void _loadPostData() {
    final post = widget.postData;
    _titleController.text = post['title'] ?? '';
    _descriptionController.text = post['description'] ?? '';
    _priceController.text = post['price']?.toString() ?? '';
    _allowCalls = post['allowCalls'] != false;
    _isDonation = post['isDonation'] == true;
    _selectedCurrency = post['currency'] ?? 'INR';
    _locationController.text = post['location']?.toString() ?? '';
    _offerController.text = post['offer']?.toString() ?? '';
    // Load structured post type & sub category
    _selectedPostType = post['postType'] as String?;
    _selectedSubCategory = post['subCategory'] as String?;
    if (_selectedSubCategory != null && _selectedSubCategory!.isEmpty) {
      _selectedSubCategory = null;
    }
    // Backward compat: if postType not set, try to infer from old categories
    if (_selectedPostType == null) {
      final existingCategories = post['categories'] as List<dynamic>? ?? [];
      final singleCat = post['category']?.toString() ?? '';
      for (final known in _subCategoryMap.keys) {
        if (existingCategories.any((c) => c.toString() == known) || singleCat == known) {
          _selectedPostType = known;
          break;
        }
      }
    }
    // Load existing keywords
    final existingKeywords = post['keywords'] as List<dynamic>? ?? [];
    for (final kw in existingKeywords) {
      final keyword = kw?.toString() ?? '';
      if (keyword.isNotEmpty && !_keywords.contains(keyword)) {
        _keywords.add(keyword);
      }
    }
    // Load existing GPS coordinates
    _detectedLat = (post['latitude'] as num?)?.toDouble();
    _detectedLng = (post['longitude'] as num?)?.toDouble();
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
    _locationDebounce?.cancel();
    try { _speech.stop(); } catch (_) {}
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _keywordController.dispose();
    _locationController.dispose();
    _offerController.dispose();
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

  Future<void> _autoDetectLocation() async {
    if (!mounted || _isDetectingLocation) return;
    setState(() => _isDetectingLocation = true);

    // Priority 1: Fresh GPS via IpLocationService (always accurate)
    try {
      final result = await IpLocationService.detectLocation();
      if (result != null && mounted) {
        _detectedLat = result['lat'] as double;
        _detectedLng = result['lng'] as double;
        final display = result['displayAddress'] as String?;
        _locationController.removeListener(_onLocationTextChanged);
        setState(() {
          _isDetectingLocation = false;
          if (display != null && display.isNotEmpty) {
            _locationController.text = display;
          }
        });
        _locationController.addListener(_onLocationTextChanged);
        debugPrint('AutoDetect: Fresh GPS location used');
        return;
      }
    } catch (e) {
      debugPrint('AutoDetect: GPS location error: $e');
    }

    // Priority 2: Firestore user profile (only if GPS failed, skip stale data)
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists && mounted) {
          final lat = (userDoc.data()?['latitude'] as num?)?.toDouble();
          final lng = (userDoc.data()?['longitude'] as num?)?.toDouble();
          final city = userDoc.data()?['city'] as String? ??
              userDoc.data()?['location'] as String? ?? '';
          // Skip stale/emulator data
          final cityLower = city.toLowerCase();
          final isMVCoords = (lat != null && lng != null &&
              (lat - 37.422).abs() < 0.05 && (lng + 122.084).abs() < 0.05);
          if (lat != null && lng != null &&
              !cityLower.contains('mountain view') &&
              !isMVCoords &&
              !(lat.abs() < 0.01 && lng.abs() < 0.01)) {
            _detectedLat = lat;
            _detectedLng = lng;
            _locationController.removeListener(_onLocationTextChanged);
            setState(() {
              _isDetectingLocation = false;
              if (city.isNotEmpty) {
                _locationController.text = city;
              }
            });
            _locationController.addListener(_onLocationTextChanged);
            debugPrint('AutoDetect: Firestore fallback: $lat, $lng');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('AutoDetect: Firestore GPS error: $e');
    }

    if (mounted) {
      setState(() => _isDetectingLocation = false);
      _showSnackBar('Could not detect location. Please enter manually.', isError: true);
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


  Future<List<String>> _uploadNewImages() async {
    if (_selectedImages.isEmpty) return [];

    final List<String> urls = [];
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      final postFolder = 'post_${DateTime.now().millisecondsSinceEpoch}';
      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = 'image_$i.jpg';
        final ref = _storage.ref().child('posts/$userId/$postFolder/$fileName');
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
    if (_isLoading) return;
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', isError: true);
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please enter a description', isError: true);
      return;
    }

    if (_selectedPostType == null) {
      _showSnackBar('Please select a post type', isError: true);
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

      // Use already-detected coordinates, or try fetching now
      double? lat = _detectedLat;
      double? lng = _detectedLng;
      if (lat == null || lng == null) {
        // Priority 1: Fresh GPS
        try {
          final locResult = await IpLocationService.detectLocation();
          if (locResult != null) {
            lat = locResult['lat'] as double;
            lng = locResult['lng'] as double;
          }
        } catch (e) {
          debugPrint('Location error during post update: $e');
        }
        // Priority 2: Firestore user profile (skip stale Mountain View)
        if (lat == null || lng == null) {
          try {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              if (userDoc.exists) {
                final fLat = (userDoc.data()?['latitude'] as num?)?.toDouble();
                final fLng = (userDoc.data()?['longitude'] as num?)?.toDouble();
                final fCity = (userDoc.data()?['city'] as String? ?? '').toLowerCase();
                final isMVCoords2 = (fLat != null && fLng != null &&
                    (fLat - 37.422).abs() < 0.05 && (fLng + 122.084).abs() < 0.05);
                if (fLat != null && fLng != null &&
                    !fCity.contains('mountain view') &&
                    !isMVCoords2 &&
                    !(fLat.abs() < 0.01 && fLng.abs() < 0.01)) {
                  lat = fLat;
                  lng = fLng;
                }
              }
            }
          } catch (e) {
            debugPrint('Location error during post update: $e');
          }
        }
      }

      // Block post update if no coordinates (critical for 10km filter)
      if (lat == null || lng == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'Location is required. Please enable GPS or enter your location.',
            isError: true,
          );
        }
        return;
      }

      // Update post data
      final postData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'originalPrompt': _titleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'allowCalls': _allowCalls,
        'isDonation': _selectedPostType == 'Donation',
        'currency': _selectedCurrency,
        'keywords': _keywords,
        'hashtags': <String>[],
        'postType': _selectedPostType,
        'subCategory': _selectedSubCategory ?? '',
        'category': _selectedSubCategory ?? _selectedPostType ?? '',
        'categories': [
          if (_selectedPostType != null) _selectedPostType,
          if (_selectedSubCategory != null) _selectedSubCategory,
        ],
        'location': _locationController.text.trim(),
        'offer': _offerController.text.trim(),
      };

      // lat & lng guaranteed non-null (validated above)
      postData['latitude'] = lat;
      postData['longitude'] = lng;

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
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
        title: const Text(
          'Edit NearBy Post',
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

                          const SizedBox(height: 20),

                          // Title Field
                          _buildLabeledField(
                            label: 'Title',
                            isMandatory: true,
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

                          const SizedBox(height: 16),

                          // Category
                          _buildPostTypeSection(),

                          const SizedBox(height: 16),

                          // Keywords / Highlights
                          _buildKeywordsSection(),

                          const SizedBox(height: 16),

                          // Location
                          _buildLocationField(),

                          const SizedBox(height: 16),

                          // Offer
                          _buildOfferField(),

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
    List<TextInputFormatter>? inputFormatters,
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
                prefixText: prefixText,
                prefixStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 16),
                suffixText: suffixText,
                suffixStyle: TextStyle(fontFamily: 'Poppins', color: Colors.grey[400], fontSize: 15),
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
              '$totalImages/3',
              style: TextStyle(
                fontFamily: 'Poppins',
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
                fontFamily: 'Poppins',
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
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 15),
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
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 15,
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
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter price',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.grey[400],
                        fontSize: 14,
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
                fontFamily: 'Poppins',
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
                fontFamily: 'Poppins',
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

  Widget _buildKeywordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Highlights (Optional)',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_keywords.length}/5',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _keywords.length >= 5 ? Colors.red : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Keyword chips
        if (_keywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _keywords.map((kw) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF016CFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF016CFF).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        kw,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _keywords.remove(kw));
                      },
                      child: const Icon(Icons.close, color: Colors.white70, size: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        // Input row
        if (_keywords.length < 5)
          Row(
            children: [
              Expanded(
                child: _buildGlassTextField(
                  controller: _keywordController,
                  hintText: 'e.g. Like New, Fast Delivery...',
                  prefixIcon: Icons.label_outline_rounded,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  final kw = _keywordController.text.trim();
                  if (kw.isEmpty) return;
                  if (_keywords.contains(kw)) return;
                  HapticFeedback.lightImpact();
                  setState(() {
                    _keywords.add(kw);
                    _keywordController.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF016CFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPostTypeSection() {
    final catColor = _selectedPostType != null
        ? (_postTypeColors[_selectedPostType]?[0] ?? const Color(0xFF6366F1))
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post Type label
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'Post Type'),
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
        const SizedBox(height: 8),
        // Post Type Dropdown — networking style
        GestureDetector(
          onTap: () => _showPostTypeDialog(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: _selectedPostType != null
                  ? catColor.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                if (_selectedPostType != null) ...[
                  Icon(
                    _postTypeIcons[_selectedPostType] ?? Icons.category_rounded,
                    color: catColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _selectedPostType ?? 'Select Post Type',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: _selectedPostType != null
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              ],
            ),
          ),
        ),

        // Sub Category Dropdown
        if (_selectedPostType != null) ...[
          const SizedBox(height: 16),
          Text(
            'Sub Category',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showSubCategoryDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  if (_selectedSubCategory != null) ...[
                    Icon(
                      _subCategoryIcons[_selectedSubCategory] ?? Icons.label_rounded,
                      color: catColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      _selectedSubCategory ?? 'Select Sub Category',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: _selectedSubCategory != null
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showPostTypeDialog() {
    HapticFeedback.lightImpact();
    final options = _subCategoryMap.keys.toList();
    showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(64, 64, 64, 1),
                Color.fromRGBO(0, 0, 0, 1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Post Type',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final isSelected = opt == _selectedPostType;
                        final itemColor = (_postTypeColors[opt] ?? [const Color(0xFF6366F1)])[0];
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [itemColor, itemColor.withValues(alpha: 0.7)]
                                    : [
                                        Colors.white.withValues(alpha: 0.25),
                                        Colors.white.withValues(alpha: 0.15),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? itemColor.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.3),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : itemColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : itemColor.withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    _postTypeIcons[opt] ?? Icons.category_rounded,
                                    color: isSelected ? Colors.white : itemColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  opt,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedPostType = selected;
          _selectedSubCategory = null;
          _isDonation = selected == 'Donation';
        });
      }
    });
  }

  void _showSubCategoryDialog() {
    if (_selectedPostType == null) return;
    final options = _subCategoryMap[_selectedPostType] ?? [];
    final catColor = (_postTypeColors[_selectedPostType] ?? [const Color(0xFF6366F1)])[0];
    HapticFeedback.lightImpact();

    showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(64, 64, 64, 1),
                Color.fromRGBO(0, 0, 0, 1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_selectedPostType — Sub Category',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final isSelected = opt == _selectedSubCategory;
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, opt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [catColor, catColor.withValues(alpha: 0.7)]
                                    : [
                                        Colors.white.withValues(alpha: 0.25),
                                        Colors.white.withValues(alpha: 0.15),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? catColor.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.3),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : catColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : catColor.withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    _subCategoryIcons[opt] ?? Icons.label_rounded,
                                    color: isSelected ? Colors.white : catColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    opt,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedSubCategory = selected;
        });
      }
    });
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_isSearchingLocation)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 1.5),
              ),
            const SizedBox(width: 8),
            if (_isDetectingLocation)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              )
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _autoDetectLocation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded, color: Color(0xFF016CFF), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Detect',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: const Color(0xFF016CFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _locationController,
          hintText: _isDetectingLocation ? 'Detecting location...' : 'e.g. Mumbai, Delhi...',
          prefixIcon: Icons.location_on_outlined,
          maxLines: 1,
        ),
        // Location suggestions dropdown
        if (_showLocationSuggestions && _locationSuggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(64, 64, 64, 1),
                  Color.fromRGBO(0, 0, 0, 1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _showLocationSuggestions = false;
                        _locationSuggestions = [];
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, right: 10),
                        child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 2),
                itemCount: _locationSuggestions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 40,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                itemBuilder: (context, index) {
                  final s = _locationSuggestions[index];
                  final city = (s['city'] ?? '').toString();
                  final state = (s['state'] ?? '').toString();
                  final area = (s['area'] ?? '').toString();
                  final title = area.isNotEmpty ? area : city;
                  String subtitle = '';
                  if (city.isNotEmpty && city != title) subtitle = city;
                  if (state.isNotEmpty) {
                    subtitle = subtitle.isNotEmpty ? '$subtitle, $state' : state;
                  }
                  return InkWell(
                    onTap: () => _selectLocationSuggestion(s),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF016CFF).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF016CFF).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(Icons.location_on_outlined, color: Color(0xFF016CFF), size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOfferField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offer (Optional)',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildGlassTextField(
          controller: _offerController,
          hintText: 'e.g. 10% off, Buy 1 Get 1...',
          prefixIcon: Icons.local_offer_rounded,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildUpdateButton() {
    final bool enabled = _isFormValid && !_isLoading;
    return GestureDetector(
      onTap: enabled ? _updatePost : null,
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
              Icons.save_outlined,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Update Post',
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

