import 'package:flutter/material.dart';
import '../../models/business_model.dart';

/// Base abstract class for all category-specific listing wizards
/// Provides shared UI components and navigation logic
/// Each category extends this and implements category-specific steps
abstract class BaseListingWizard extends StatefulWidget {
  final BusinessModel business;
  final dynamic existingItem; // For editing existing listings

  const BaseListingWizard({
    super.key,
    required this.business,
    this.existingItem,
  });
}

/// Base state class with shared functionality for all listing wizards
abstract class BaseListingWizardState<T extends BaseListingWizard> extends State<T> {
  // Step management
  int currentStep = 0;
  int get totalSteps => 3;

  // Shared state across all categories
  List<String> photos = [];
  int coverPhotoIndex = 0;
  String title = '';
  double price = 0.0;
  String description = '';
  List<String> tags = [];
  int quantity = 1;

  // Step 3: Visibility & Sales
  bool isBoosted = false;
  bool allowOffers = false;
  bool autoRenew = false;
  String? pickupAddress;
  double? pickupLatitude;
  double? pickupLongitude;
  bool showExactAddress = false;

  // Loading states
  bool isLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeExistingData();
  }

  /// Initialize data if editing existing listing
  void _initializeExistingData() {
    if (widget.existingItem != null) {
      loadExistingData(widget.existingItem);
    }
  }

  // ========================================
  // Abstract methods - Category implements
  // ========================================

  /// Build category-specific Step 1: Photos & Basic Info
  Widget buildStep1();

  /// Build category-specific Step 2: Description & Details
  Widget buildStep2();

  /// Build category-specific Step 3: Visibility & Sales
  Widget buildStep3();

  /// Save listing data to Firestore
  Future<void> saveData();

  /// Validate current step before proceeding
  bool validateStep(int step);

  /// Load existing data when editing
  void loadExistingData(dynamic existingItem);

  /// Get step title for progress indicator
  String getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Photos & Basic Info';
      case 1:
        return 'Description';
      case 2:
        return 'Visibility & Sales';
      default:
        return '';
    }
  }

  // ========================================
  // Shared UI Components
  // ========================================

  /// Build main wizard scaffold
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _handleBack,
        ),
        title: Text(
          widget.existingItem == null ? 'Add Listing' : 'Edit Listing',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              buildProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
              buildNavigationButtons(),
            ],
          ),
          if (isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build step progress indicator
  Widget buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index == currentStep;
          final isCompleted = index < currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Step indicator
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isActive || isCompleted
                              ? const Color(0xFF7C3AED)
                              : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Step title
                      Text(
                        getStepTitle(index),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? const Color(0xFF7C3AED)
                              : Colors.grey[600],
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Connector line
                if (index < totalSteps - 1)
                  Container(
                    width: 24,
                    height: 2,
                    color: isCompleted
                        ? const Color(0xFF7C3AED)
                        : Colors.grey[300],
                    margin: const EdgeInsets.only(bottom: 32),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Build current step content
  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return buildStep1();
      case 1:
        return buildStep2();
      case 2:
        return buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Build navigation buttons
  Widget buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            if (currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ),
            if (currentStep > 0) const SizedBox(width: 12),
            // Next/Publish button
            Expanded(
              flex: currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: isSaving ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  currentStep < totalSteps - 1 ? 'Next' : 'Publish',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // Navigation Logic
  // ========================================

  void _nextStep() async {
    // Validate current step
    if (!validateStep(currentStep)) {
      return;
    }

    // If on last step, publish the listing
    if (currentStep >= totalSteps - 1) {
      await _publishListing();
      return;
    }

    // Move to next step
    setState(() {
      currentStep++;
    });
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }

  void _handleBack() {
    if (currentStep > 0) {
      _previousStep();
    } else {
      _confirmExit();
    }
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Are you sure you want to exit? Your changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close wizard
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publishListing() async {
    setState(() {
      isSaving = true;
    });

    try {
      await saveData();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingItem == null
                  ? 'Listing published successfully!'
                  : 'Listing updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Return to previous screen
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ========================================
  // Shared Helper Methods
  // ========================================

  /// Show error message
  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show success message
  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Format price with currency
  String formatPrice(double price, String currency) {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}';
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      default:
        return code;
    }
  }
}
