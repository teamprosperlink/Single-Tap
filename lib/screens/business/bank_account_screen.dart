import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';

/// Screen for managing business bank account details
class BankAccountScreen extends StatefulWidget {
  final BusinessModel business;

  const BankAccountScreen({
    super.key,
    required this.business,
  });

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final BusinessService _businessService = BusinessService();

  final _holderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _swiftController = TextEditingController();
  final _upiController = TextEditingController();

  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final bank = widget.business.bankAccount;
    if (bank != null) {
      _isEditing = true;
      _holderNameController.text = bank.accountHolderName;
      _bankNameController.text = bank.bankName;
      _accountNumberController.text = bank.accountNumber;
      _confirmAccountController.text = bank.accountNumber;
      _ifscController.text = bank.ifscCode;
      _swiftController.text = bank.swiftCode ?? '';
      _upiController.text = bank.upiId ?? '';
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _swiftController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Bank Account' : 'Add Bank Account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your bank details are used for receiving payments from customers. Please ensure all information is accurate.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account Holder Name
              _buildLabel('Account Holder Name', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _holderNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  'Enter name as per bank records',
                  Icons.person_outline,
                  isDarkMode,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Bank Name
              _buildLabel('Bank Name', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bankNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  'e.g., State Bank of India',
                  Icons.account_balance_outlined,
                  isDarkMode,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter bank name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Account Number
              _buildLabel('Account Number', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  'Enter account number',
                  Icons.numbers,
                  isDarkMode,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter account number';
                  }
                  if (value.length < 9) {
                    return 'Account number must be at least 9 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Confirm Account Number
              _buildLabel('Confirm Account Number', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmAccountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  'Re-enter account number',
                  Icons.numbers,
                  isDarkMode,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please confirm account number';
                  }
                  if (value != _accountNumberController.text) {
                    return 'Account numbers do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // IFSC Code
              _buildLabel('IFSC Code', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ifscController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  'e.g., SBIN0001234',
                  Icons.code,
                  isDarkMode,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter IFSC code';
                  }
                  if (value.length != 11) {
                    return 'IFSC code must be 11 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // SWIFT Code (Optional)
              _buildLabel('SWIFT Code (Optional)', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _swiftController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  'For international transfers',
                  Icons.language,
                  isDarkMode,
                ),
              ),
              const SizedBox(height: 20),

              // UPI ID (Optional)
              _buildLabel('UPI ID (Optional)', isDarkMode),
              const SizedBox(height: 8),
              TextFormField(
                controller: _upiController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  'e.g., yourname@upi',
                  Icons.qr_code,
                  isDarkMode,
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D67D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Bank Account' : 'Add Bank Account',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // Delete button for existing accounts
              if (_isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _confirmDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Remove Bank Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
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
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white70 : Colors.grey[700],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDarkMode) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: isDarkMode ? Colors.white38 : Colors.grey[500],
      ),
      filled: true,
      fillColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[100],
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
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final bankAccount = BankAccount(
      accountHolderName: _holderNameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      ifscCode: _ifscController.text.trim().toUpperCase(),
      swiftCode: _swiftController.text.trim().isEmpty
          ? null
          : _swiftController.text.trim().toUpperCase(),
      upiId: _upiController.text.trim().isEmpty
          ? null
          : _upiController.text.trim(),
      isVerified: false,
    );

    final success = await _businessService.updateBankAccount(
      widget.business.id,
      bankAccount,
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Bank account updated' : 'Bank account added'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save bank account'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Remove Bank Account?'),
        content: const Text(
          'Are you sure you want to remove your bank account? You will need to add it again to receive payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _businessService.removeBankAccount(widget.business.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bank account removed')),
                );
                Navigator.pop(context, true);
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
