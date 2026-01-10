import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/service_model.dart';
import '../../models/inquiry_model.dart';
import '../../services/inquiry_service.dart';

/// Bottom sheet for sending inquiry to a professional
class SendInquirySheet extends StatefulWidget {
  final String professionalId;
  final ServiceModel? service;

  const SendInquirySheet({
    super.key,
    required this.professionalId,
    this.service,
  });

  static Future<void> show(
    BuildContext context, {
    required String professionalId,
    ServiceModel? service,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendInquirySheet(
        professionalId: professionalId,
        service: service,
      ),
    );
  }

  @override
  State<SendInquirySheet> createState() => _SendInquirySheetState();
}

class _SendInquirySheetState extends State<SendInquirySheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final InquiryService _inquiryService = InquiryService();

  String? _selectedBudget;
  String? _selectedTimeline;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _sendInquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final inquiryId = await _inquiryService.sendInquiry(
        professionalId: widget.professionalId,
        message: _messageController.text.trim(),
        serviceId: widget.service?.id,
        serviceName: widget.service?.title,
        projectDescription: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        budget: _selectedBudget,
        timeline: _selectedTimeline,
      );

      if (inquiryId != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inquiry sent successfully!'),
            backgroundColor: Color(0xFF00D67D),
          ),
        );
      } else {
        throw Exception('Failed to send inquiry');
      }
    } catch (e) {
      debugPrint('Error sending inquiry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send inquiry: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Inquiry',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (widget.service != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'For: ${widget.service!.title}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message
                        _buildLabel('Message *', isDarkMode),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 3,
                          maxLength: 500,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: _buildInputDecoration(
                            'Briefly describe what you need...',
                            isDarkMode,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a message';
                            }
                            if (value.trim().length < 20) {
                              return 'Message too short (min 20 characters)';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Project Description (Optional)
                        _buildLabel('Project Details (Optional)', isDarkMode),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 1000,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: _buildInputDecoration(
                            'Provide more details about your project, requirements, references...',
                            isDarkMode,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Budget
                        _buildLabel('Budget Range', isDarkMode),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _selectedBudget,
                          items: BudgetOptions.ranges,
                          hint: 'Select your budget',
                          isDarkMode: isDarkMode,
                          onChanged: (value) {
                            setState(() => _selectedBudget = value);
                          },
                        ),

                        const SizedBox(height: 20),

                        // Timeline
                        _buildLabel('Timeline', isDarkMode),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          value: _selectedTimeline,
                          items: TimelineOptions.options,
                          hint: 'When do you need this?',
                          isDarkMode: isDarkMode,
                          onChanged: (value) {
                            setState(() => _selectedTimeline = value);
                          },
                        ),

                        const SizedBox(height: 24),

                        // Tips
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Color(0xFF00D67D),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tips for better responses',
                                    style: TextStyle(
                                      color: Color(0xFF00D67D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTipItem(
                                'Be specific about your requirements',
                                isDarkMode,
                              ),
                              _buildTipItem(
                                'Include relevant references or examples',
                                isDarkMode,
                              ),
                              _buildTipItem(
                                'Mention your deadline clearly',
                                isDarkMode,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendInquiry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D67D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Send Inquiry',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
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

  Widget _buildLabel(String text, bool isDarkMode) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, bool isDarkMode) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDarkMode ? Colors.white38 : Colors.grey[400],
      ),
      filled: true,
      fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
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
        borderSide: const BorderSide(
          color: Color(0xFF00D67D),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[400]!),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      counterStyle: TextStyle(
        color: isDarkMode ? Colors.white38 : Colors.grey[500],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required bool isDarkMode,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ),
          isExpanded: true,
          dropdownColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTipItem(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            size: 14,
            color: Color(0xFF00D67D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white60 : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
