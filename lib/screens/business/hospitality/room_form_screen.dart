import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/room_model.dart';
import '../../../services/business_service.dart';

/// Screen for adding/editing a room
class RoomFormScreen extends StatefulWidget {
  final String businessId;
  final RoomModel? room;
  final VoidCallback onSaved;

  const RoomFormScreen({
    super.key,
    required this.businessId,
    this.room,
    required this.onSaved,
  });

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final BusinessService _businessService = BusinessService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _totalRoomsController;
  late TextEditingController _availableRoomsController;
  late TextEditingController _capacityController;
  late TextEditingController _sizeController;

  RoomType _selectedType = RoomType.standard;
  BedType? _selectedBedType;
  List<String> _selectedAmenities = [];
  bool _isAvailable = true;
  bool _isSaving = false;

  // Image management
  List<String> _existingImages = [];
  final List<File> _newImages = [];

  bool get isEditing => widget.room != null;

  @override
  void initState() {
    super.initState();
    final room = widget.room;

    _nameController = TextEditingController(text: room?.name ?? '');
    _descriptionController = TextEditingController(text: room?.description ?? '');
    _priceController = TextEditingController(
      text: room?.pricePerNight.toStringAsFixed(0) ?? '',
    );
    _totalRoomsController = TextEditingController(
      text: room?.totalRooms.toString() ?? '1',
    );
    _availableRoomsController = TextEditingController(
      text: room?.availableRooms.toString() ?? '1',
    );
    _capacityController = TextEditingController(
      text: room?.capacity.toString() ?? '2',
    );
    _sizeController = TextEditingController(
      text: room?.roomSize?.toString() ?? '',
    );

    if (room != null) {
      _selectedType = room.type;
      _selectedBedType = room.bedType;
      _selectedAmenities = List.from(room.amenities);
      _isAvailable = room.isAvailable;
      _existingImages = List.from(room.images);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _totalRoomsController.dispose();
    _availableRoomsController.dispose();
    _capacityController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Room' : 'Add Room',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveRoom,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF00D67D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionTitle('Room Photo', isDarkMode),
            const SizedBox(height: 16),
            _buildImagePicker(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Basic Information', isDarkMode),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Room Name',
              hint: 'e.g., Deluxe Room, Ocean View Suite',
              isDarkMode: isDarkMode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a room name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe this room...',
              isDarkMode: isDarkMode,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Room Type', isDarkMode),
            const SizedBox(height: 16),
            _buildRoomTypeSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Pricing', isDarkMode),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _priceController,
              label: 'Price Per Night',
              hint: 'Enter price',
              isDarkMode: isDarkMode,
              prefixText: '\u20B9 ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Capacity & Inventory', isDarkMode),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _capacityController,
                    label: 'Max Guests',
                    hint: '2',
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _sizeController,
                    label: 'Size (sq ft)',
                    hint: 'Optional',
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _totalRoomsController,
                    label: 'Total Rooms',
                    hint: '1',
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _availableRoomsController,
                    label: 'Available',
                    hint: '1',
                    isDarkMode: isDarkMode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Bed Type', isDarkMode),
            const SizedBox(height: 16),
            _buildBedTypeSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Amenities', isDarkMode),
            const SizedBox(height: 16),
            _buildAmenitiesSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildAvailabilityToggle(isDarkMode),
            const SizedBox(height: 32),
            _buildSaveButton(isDarkMode),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDarkMode,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white38 : Colors.grey[400],
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D67D), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildRoomTypeSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RoomType.values.map((type) {
        final isSelected = _selectedType == type;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedType = type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D)
                  : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
              ),
            ),
            child: Text(
              type.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBedTypeSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BedType.values.map((type) {
        final isSelected = _selectedBedType == type;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedBedType = type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D)
                  : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
              ),
            ),
            child: Text(
              type.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmenitiesSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RoomAmenities.all.map((amenity) {
        final isSelected = _selectedAmenities.contains(amenity);
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isSelected) {
                _selectedAmenities.remove(amenity);
              } else {
                _selectedAmenities.add(amenity);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                  : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check,
                    size: 16,
                    color: Color(0xFF00D67D),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  amenity,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF00D67D)
                        : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailabilityToggle(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isAvailable
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isAvailable ? Icons.check_circle : Icons.cancel,
              color: _isAvailable ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room Availability',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _isAvailable
                      ? 'This room is visible to guests'
                      : 'This room is hidden from guests',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              setState(() => _isAvailable = value);
            },
            activeThumbColor: const Color(0xFF00D67D),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          if (_existingImages.isEmpty && _newImages.isEmpty)
            // Empty state
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: isDarkMode ? Colors.white38 : Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Add Room Photo',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to select image',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white38 : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Images display
            Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Existing images
                      ..._existingImages.map((imageUrl) {
                        final index = _existingImages.indexOf(imageUrl);
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _existingImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // New images
                      ..._newImages.map((file) {
                        final index = _newImages.indexOf(file);
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _newImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Add more button
                      if (_existingImages.length + _newImages.length < 5)
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Color(0xFF00D67D),
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can add up to 5 photos',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _newImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSaveButton(bool isDarkMode) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveRoom,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D67D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.5),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              isEditing ? 'Save Changes' : 'Add Room',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Upload new images first
      final uploadedImageUrls = <String>[];

      // Generate temporary room ID for image upload
      final tempRoomId = widget.room?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      for (final imageFile in _newImages) {
        final imageUrl = await _businessService.uploadRoomImage(
          widget.businessId,
          tempRoomId,
          imageFile,
        );
        if (imageUrl != null) {
          uploadedImageUrls.add(imageUrl);
        }
      }

      // Combine existing and new images
      final allImages = [..._existingImages, ...uploadedImageUrls];

      final room = RoomModel(
        id: widget.room?.id ?? '',
        businessId: widget.businessId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        type: _selectedType,
        pricePerNight: double.tryParse(_priceController.text) ?? 0,
        currency: 'INR',
        capacity: int.tryParse(_capacityController.text) ?? 2,
        totalRooms: int.tryParse(_totalRoomsController.text) ?? 1,
        availableRooms: int.tryParse(_availableRoomsController.text) ?? 1,
        roomSize: _sizeController.text.isEmpty
            ? null
            : double.tryParse(_sizeController.text),
        bedType: _selectedBedType ?? BedType.double,
        amenities: _selectedAmenities,
        images: allImages,
        isAvailable: _isAvailable,
      );

      if (isEditing) {
        await _businessService.updateRoom(widget.businessId, room.id, room);
      } else {
        await _businessService.createRoom(room);
      }

      if (mounted) {
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
