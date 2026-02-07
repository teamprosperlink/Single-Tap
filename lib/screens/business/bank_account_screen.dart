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

class _BankAccountScreenState extends State<BankAccountScreen>
    with SingleTickerProviderStateMixin {
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
  bool _showAccountNumber = false;
  bool _accountNumbersMatch = true;
  String _selectedAccountType = 'savings';

  late AnimationController _animationController;
  late Animation<double> _cardAnimation;

  final List<Map<String, dynamic>> _accountTypes = [
    {'value': 'savings', 'label': 'Savings', 'icon': Icons.savings_outlined},
    {'value': 'current', 'label': 'Current', 'icon': Icons.account_balance_wallet_outlined},
    {'value': 'salary', 'label': 'Salary', 'icon': Icons.payments_outlined},
    {'value': 'business', 'label': 'Business', 'icon': Icons.business_center_outlined},
  ];

  // Card gradients
  final List<List<Color>> _cardGradients = [
    [const Color(0xFF667eea), const Color(0xFF764ba2)],
    [const Color(0xFF11998e), const Color(0xFF38ef7d)],
    [const Color(0xFFFC466B), const Color(0xFF3F5EFB)],
    [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
    [const Color(0xFFfa709a), const Color(0xFFfee140)],
    [const Color(0xFF30cfd0), const Color(0xFF330867)],
  ];

  List<Color> get _currentGradient {
    final index = _bankNameController.text.length % _cardGradients.length;
    return _cardGradients[index];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();

    _loadExistingData();

    _accountNumberController.addListener(_checkAccountMatch);
    _confirmAccountController.addListener(_checkAccountMatch);
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

  void _checkAccountMatch() {
    if (_confirmAccountController.text.isNotEmpty) {
      setState(() {
        _accountNumbersMatch =
            _accountNumberController.text == _confirmAccountController.text;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Card Preview
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0A0A0F) : Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _isEditing ? 'Edit Bank Account' : 'Add Bank Account',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 110, 20, 20),
                child: ScaleTransition(
                  scale: _cardAnimation,
                  child: _buildBankCard(isDark),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Account Type Section
                    _buildSectionTitle('Account Type', isDark),
                    const SizedBox(height: 12),
                    _buildAccountTypeSelector(isDark),
                    const SizedBox(height: 28),

                    // Account Details Section
                    _buildSectionTitle('Account Details', isDark),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _holderNameController,
                      label: 'Account Holder Name',
                      hint: 'Enter name as per bank records',
                      icon: Icons.person_outline_rounded,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter account holder name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bankNameController,
                      label: 'Bank Name',
                      hint: 'e.g., State Bank of India',
                      icon: Icons.account_balance_rounded,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter bank name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _accountNumberController,
                      label: 'Account Number',
                      hint: 'Enter your account number',
                      icon: Icons.credit_card_rounded,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      obscureText: !_showAccountNumber,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showAccountNumber
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: isDark ? Colors.white54 : Colors.black45,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() => _showAccountNumber = !_showAccountNumber);
                        },
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
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmAccountController,
                      label: 'Confirm Account Number',
                      hint: 'Re-enter your account number',
                      icon: Icons.credit_card_rounded,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      obscureText: !_showAccountNumber,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixIcon: _confirmAccountController.text.isNotEmpty
                          ? Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                _accountNumbersMatch
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: _accountNumbersMatch
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFFF3B30),
                                size: 22,
                              ),
                            )
                          : null,
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
                    const SizedBox(height: 28),

                    // Bank Codes Section
                    _buildSectionTitle('Bank Codes', isDark),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _ifscController,
                            label: 'IFSC Code',
                            hint: 'SBIN0001234',
                            icon: Icons.qr_code_rounded,
                            isDark: isDark,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
                              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                            ],
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              if (value.length != 11) {
                                return '11 chars required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _swiftController,
                            label: 'SWIFT (Optional)',
                            hint: 'For international',
                            icon: Icons.public_rounded,
                            isDark: isDark,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
                              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // UPI Section
                    _buildSectionTitle('UPI Details (Optional)', isDark),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _upiController,
                      label: 'UPI ID',
                      hint: 'e.g., yourname@upi',
                      icon: Icons.qr_code_scanner_rounded,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(isDark),

                    // Delete Button
                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      _buildDeleteButton(isDark),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCard(bool isDark) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _currentGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: _currentGradient.first.withAlpha(100),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          // Chip icon
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              width: 50,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade300,
                    Colors.amber.shade600,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.amber.shade800.withAlpha(80),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bankNameController.text.isEmpty
                          ? 'Bank Name'
                          : _bankNameController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _accountTypes.firstWhere(
                          (t) => t['value'] == _selectedAccountType,
                        )['label'],
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatAccountNumber(_accountNumberController.text),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACCOUNT HOLDER',
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _holderNameController.text.isEmpty
                                  ? 'Your Name'
                                  : _holderNameController.text.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (_ifscController.text.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'IFSC',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(150),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _ifscController.text.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withAlpha(230),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAccountNumber(String number) {
    if (number.isEmpty) return '**** **** ****';
    if (number.length <= 4) return '**** **** ${number.padLeft(4, '*')}';
    return '**** **** ${number.substring(number.length - 4)}';
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF0A84FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTypeSelector(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _accountTypes.map((type) {
          final isSelected = _selectedAccountType == type['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedAccountType = type['value']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0A84FF)
                      : isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0A84FF)
                        : isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(10),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0A84FF).withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      type['icon'],
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : isDark
                              ? Colors.white60
                              : Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['label'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isDark
                                ? Colors.white70
                                : Colors.black54,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A84FF).withAlpha(30)
                : const Color(0xFF0A84FF).withAlpha(15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF0A84FF),
          ),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.white.withAlpha(8)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF0A84FF),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFF3B30),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFF3B30),
            width: 2,
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.black26,
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFFF3B30),
          fontSize: 12,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    final isValid = _holderNameController.text.isNotEmpty &&
        _bankNameController.text.isNotEmpty &&
        _accountNumberController.text.isNotEmpty &&
        _confirmAccountController.text.isNotEmpty &&
        _ifscController.text.isNotEmpty &&
        _accountNumbersMatch;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isValid && !_isSaving ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? Colors.white.withAlpha(15)
              : Colors.grey[300],
          disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? Icons.check_rounded : Icons.add_rounded,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Update Bank Account' : 'Add Bank Account',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_outline_rounded, size: 22),
        label: const Text(
          'Remove Bank Account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF3B30),
          side: BorderSide(
            color: const Color(0xFFFF3B30).withAlpha(100),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
      _showSuccessDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save bank account'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessDialog(
        isEditing: _isEditing,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
        },
      ),
    );
  }

  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF3B30),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Remove Bank Account?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This action cannot be undone. You will need to add your bank account again to receive payments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black54,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        final success = await _businessService.removeBankAccount(widget.business.id);
                        if (success && mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Bank account removed'),
                              backgroundColor: const Color(0xFF34C759),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          navigator.pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Success Dialog Widget
class _SuccessDialog extends StatefulWidget {
  final bool isEditing;
  final VoidCallback onDone;

  const _SuccessDialog({
    required this.isEditing,
    required this.onDone,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF34C759), Color(0xFF30D158)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34C759).withAlpha(80),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CheckPainter(_checkAnimation.value),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Success!',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isEditing
                  ? 'Your bank account has been\nupdated successfully'
                  : 'Your bank account has been\nadded successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: widget.onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Check mark painter for animation
class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final startX = size.width * 0.25;
    final startY = size.height * 0.5;
    final midX = size.width * 0.45;
    final midY = size.height * 0.65;
    final endX = size.width * 0.75;
    final endY = size.height * 0.35;

    path.moveTo(startX, startY);

    if (progress <= 0.5) {
      final t = progress * 2;
      path.lineTo(
        startX + (midX - startX) * t,
        startY + (midY - startY) * t,
      );
    } else {
      path.lineTo(midX, midY);
      final t = (progress - 0.5) * 2;
      path.lineTo(
        midX + (endX - midX) * t,
        midY + (endY - midY) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
