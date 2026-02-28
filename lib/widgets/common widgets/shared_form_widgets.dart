import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared reusable form widgets used across profile, networking, and other screens.
class SharedFormWidgets {
  SharedFormWidgets._();

  // ── Occupation options (used by profile edit, networking, etc.) ──
  static const List<String> occupationOptions = [
    'Accountant',
    'Actor/Actress',
    'Architect',
    'Artist',
    'Attorney/Lawyer',
    'Banker',
    'Barber/Hairstylist',
    'Bartender',
    'Business Owner',
    'Chef/Cook',
    'Civil Engineer',
    'Consultant',
    'Content Creator',
    'Customer Service',
    'Data Analyst',
    'Data Scientist',
    'Dentist',
    'Designer (Graphic/UI/UX)',
    'Developer/Programmer',
    'Doctor/Physician',
    'Driver/Delivery',
    'Electrician',
    'Engineer',
    'Entrepreneur',
    'Farmer',
    'Financial Advisor',
    'Firefighter',
    'Fitness Trainer',
    'Flight Attendant',
    'Freelancer',
    'HR Manager',
    'Interior Designer',
    'Journalist',
    'Marketing Manager',
    'Mechanic',
    'Military/Armed Forces',
    'Musician',
    'Nurse',
    'Paramedic',
    'Pharmacist',
    'Photographer',
    'Pilot',
    'Plumber',
    'Police Officer',
    'Product Manager',
    'Professor/Lecturer',
    'Project Manager',
    'Psychologist',
    'Real Estate Agent',
    'Receptionist',
    'Researcher',
    'Restaurant Manager',
    'Retail Worker',
    'Sales Manager',
    'Scientist',
    'Security Guard',
    'Social Media Manager',
    'Social Worker',
    'Software Engineer',
    'Student',
    'Teacher',
    'Therapist',
    'Translator',
    'Veterinarian',
    'Video Editor',
    'Waiter/Waitress',
    'Web Developer',
    'Writer/Author',
    'Other',
  ];

  // ── Gender options ──
  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  // ── Glass input decoration for form fields ──
  static InputDecoration glassInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? labelText,
  }) {
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1,
      ),
    );
    final focusedOutlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.5),
        width: 1.5,
      ),
    );
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: Icon(prefixIcon, color: Colors.grey[400], size: 22),
      suffixIcon: suffixIcon,
      border: outlineBorder,
      enabledBorder: outlineBorder,
      focusedBorder: focusedOutlineBorder,
      disabledBorder: outlineBorder,
      errorBorder: outlineBorder,
      focusedErrorBorder: focusedOutlineBorder,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      counterStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.15),
    );
  }

  // ── Image picker dialog (Gallery / Camera / Remove) ──
  static void showImagePickerDialog({
    required BuildContext context,
    required VoidCallback onPickGallery,
    required VoidCallback onTakePhoto,
    VoidCallback? onRemovePhoto,
    bool showRemove = false,
    String title = 'Change Photo',
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth - 64;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Gallery option
                _imagePickerOption(
                  ctx: ctx,
                  icon: Icons.photo_library,
                  iconColor: const Color(0xFF6366f1),
                  label: 'Choose from Gallery',
                  onTap: onPickGallery,
                  showBorder: true,
                ),
                // Camera option
                _imagePickerOption(
                  ctx: ctx,
                  icon: Icons.camera_alt,
                  iconColor: const Color(0xFF6366f1),
                  label: 'Take a Photo',
                  onTap: onTakePhoto,
                  showBorder: showRemove,
                ),
                // Remove option
                if (showRemove && onRemovePhoto != null)
                  _imagePickerOption(
                    ctx: ctx,
                    icon: Icons.delete,
                    iconColor: Colors.red,
                    label: 'Remove Photo',
                    labelColor: Colors.red,
                    onTap: onRemovePhoto,
                    showBorder: false,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _imagePickerOption({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    bool showBorder = true,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(ctx);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: labelColor ?? Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Custom dropdown dialog (scrollable list with selection) ──
  static void showCustomDropdown({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String? selectedValue,
    required Function(String) onSelected,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth - 32;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: const Alignment(0, 0.5),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Options list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option == selectedValue;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onSelected(option);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366f1).withValues(alpha: 0.2)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: isSelected
                                        ? const Color(0xFF6366f1)
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check,
                                  color: Color(0xFF6366f1),
                                  size: 20,
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
        );
      },
    );
  }
}
