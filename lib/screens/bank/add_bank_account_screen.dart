import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bank_account_model.dart';

class AddBankAccountScreen extends StatefulWidget {
  final BankAccountModel? existingAccount;
  final Function(BankAccountModel)? onSave;

  const AddBankAccountScreen({
    super.key,
    this.existingAccount,
    this.onSave,
  });

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _swiftController = TextEditingController();
  final _upiController = TextEditingController();
  final _branchController = TextEditingController();

  AccountType _selectedAccountType = AccountType.savings;
  bool _isPrimary = false;
  bool _isLoading = false;
  bool _showAccountNumber = false;
  bool _accountNumbersMatch = true;

  late AnimationController _animationController;
  late Animation<double> _cardAnimation;

  // Bank colors for card gradient
  final List<List<Color>> _cardGradients = [
    [const Color(0xFF667eea), const Color(0xFF764ba2)], // Purple
    [const Color(0xFF11998e), const Color(0xFF38ef7d)], // Teal
    [const Color(0xFFFC466B), const Color(0xFF3F5EFB)], // Pink-Blue
    [const Color(0xFFF093FB), const Color(0xFFF5576C)], // Pink
    [const Color(0xFF4facfe), const Color(0xFF00f2fe)], // Blue
    [const Color(0xFFfa709a), const Color(0xFFfee140)], // Pink-Yellow
    [const Color(0xFF30cfd0), const Color(0xFF330867)], // Cyan-Purple
    [const Color(0xFFa8edea), const Color(0xFFFed6e3)], // Soft
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

    if (widget.existingAccount != null) {
      _loadExistingAccount();
    }

    _accountNumberController.addListener(_checkAccountMatch);
    _confirmAccountController.addListener(_checkAccountMatch);
  }

  void _loadExistingAccount() {
    final account = widget.existingAccount!;
    _accountHolderController.text = account.accountHolderName;
    _bankNameController.text = account.bankName;
    _accountNumberController.text = account.accountNumber;
    _confirmAccountController.text = account.accountNumber;
    _ifscController.text = account.ifscCode ?? '';
    _swiftController.text = account.swiftCode ?? '';
    _upiController.text = account.upiId ?? '';
    _branchController.text = account.branchName ?? '';
    _selectedAccountType = AccountType.fromValue(account.accountType);
    _isPrimary = account.isPrimary;
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
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _swiftController.dispose();
    _upiController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountNumberController.text != _confirmAccountController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account numbers do not match'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final account = BankAccountModel(
        id: widget.existingAccount?.id,
        userId: '', // Will be set by service
        accountHolderName: _accountHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountType: _selectedAccountType.value,
        ifscCode: _ifscController.text.trim().isNotEmpty
            ? _ifscController.text.trim()
            : null,
        swiftCode: _swiftController.text.trim().isNotEmpty
            ? _swiftController.text.trim()
            : null,
        upiId: _upiController.text.trim().isNotEmpty
            ? _upiController.text.trim()
            : null,
        branchName: _branchController.text.trim().isNotEmpty
            ? _branchController.text.trim()
            : null,
        isPrimary: _isPrimary,
        createdAt: widget.existingAccount?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.onSave != null) {
        widget.onSave!(account);
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessDialog(
        onDone: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Close screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 280,
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
              widget.existingAccount != null ? 'Edit Bank Account' : 'Add Bank Account',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: ScaleTransition(
                  scale: _cardAnimation,
                  child: _buildBankCard(isDark, size),
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
                    const SizedBox(height: 24),

                    // Account Details Section
                    _buildSectionTitle('Account Details', isDark),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: _accountHolderController,
                      label: 'Account Holder Name',
                      hint: 'Enter name as per bank records',
                      icon: Icons.person_outline_rounded,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter account holder name';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _bankNameController,
                      label: 'Bank Name',
                      hint: 'e.g., State Bank of India',
                      icon: Icons.account_balance_rounded,
                      isDark: isDark,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter bank name';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _accountNumberController,
                      label: 'Account Number',
                      hint: 'Enter your account number',
                      icon: Icons.credit_card_rounded,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      obscureText: !_showAccountNumber,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showAccountNumber
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        onPressed: () {
                          setState(() => _showAccountNumber = !_showAccountNumber);
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter account number';
                        }
                        if (value.length < 8) {
                          return 'Account number too short';
                        }
                        return null;
                      },
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _confirmAccountController,
                      label: 'Confirm Account Number',
                      hint: 'Re-enter your account number',
                      icon: Icons.credit_card_rounded,
                      isDark: isDark,
                      keyboardType: TextInputType.number,
                      obscureText: !_showAccountNumber,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm account number';
                        }
                        if (value != _accountNumberController.text) {
                          return 'Account numbers do not match';
                        }
                        return null;
                      },
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixIcon: _confirmAccountController.text.isNotEmpty
                          ? Icon(
                              _accountNumbersMatch
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: _accountNumbersMatch
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFFF3B30),
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Bank Codes Section
                    _buildSectionTitle('Bank Codes', isDark),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _ifscController,
                            label: 'IFSC Code',
                            hint: 'e.g., SBIN0001234',
                            icon: Icons.qr_code_rounded,
                            isDark: isDark,
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (value.length != 11) {
                                return 'Invalid IFSC';
                              }
                              return null;
                            },
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(11),
                              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
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
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _branchController,
                      label: 'Branch Name (Optional)',
                      hint: 'e.g., Main Branch, New York',
                      icon: Icons.location_on_outlined,
                      isDark: isDark,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 24),

                    // UPI Section
                    _buildSectionTitle('UPI Details (Optional)', isDark),
                    const SizedBox(height: 12),
                    _buildInputField(
                      controller: _upiController,
                      label: 'UPI ID',
                      hint: 'e.g., yourname@upi',
                      icon: Icons.qr_code_scanner_rounded,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    // Primary Account Toggle
                    _buildPrimaryToggle(isDark),
                    const SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(isDark),
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

  Widget _buildBankCard(bool isDark, Size size) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _currentGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: _currentGradient.first.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(25),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
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
                Row(
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedAccountType.displayName,
                          style: TextStyle(
                            color: Colors.white.withAlpha(180),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _accountNumberController.text.isEmpty
                          ? '**** **** **** ****'
                          : _formatAccountNumber(_accountNumberController.text),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _accountHolderController.text.isEmpty
                          ? 'ACCOUNT HOLDER'
                          : _accountHolderController.text.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
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
    if (number.length <= 4) return '**** **** **** ${number.padLeft(4, '*')}';
    final masked = '**** **** **** ${number.substring(number.length - 4)}';
    return masked;
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildAccountTypeSelector(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AccountType.values.map((type) {
          final isSelected = _selectedAccountType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedAccountType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0A84FF)
                      : isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(8),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0A84FF)
                        : isDark
                            ? Colors.white.withAlpha(30)
                            : Colors.black.withAlpha(15),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  type.displayName,
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
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputField({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
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
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : const Color(0xFF0A84FF).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? Colors.white60 : const Color(0xFF0A84FF),
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? Colors.white.withAlpha(10)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(10),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(8),
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
            labelStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(8),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isPrimary
                  ? const Color(0xFF34C759).withAlpha(30)
                  : isDark
                      ? Colors.white.withAlpha(15)
                      : const Color(0xFF0A84FF).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.star_rounded,
              color: _isPrimary
                  ? const Color(0xFF34C759)
                  : isDark
                      ? Colors.white60
                      : const Color(0xFF0A84FF),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set as Primary Account',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Use this account for receiving payments',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isPrimary,
            onChanged: (value) => setState(() => _isPrimary = value),
            activeTrackColor: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    final isValid = _accountHolderController.text.isNotEmpty &&
        _bankNameController.text.isNotEmpty &&
        _accountNumberController.text.isNotEmpty &&
        _confirmAccountController.text.isNotEmpty &&
        _ifscController.text.isNotEmpty &&
        _accountNumbersMatch;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isValid && !_isLoading ? _saveAccount : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A84FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? Colors.white.withAlpha(20)
              : Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
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
                  const Icon(Icons.add_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.existingAccount != null
                        ? 'Update Bank Account'
                        : 'Add Bank Account',
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
}

// Success Dialog Widget
class _SuccessDialog extends StatefulWidget {
  final VoidCallback onDone;

  const _SuccessDialog({required this.onDone});

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
          borderRadius: BorderRadius.circular(24),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF34C759),
                      const Color(0xFF30D158),
                    ],
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
            const SizedBox(height: 24),
            Text(
              'Success!',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your bank account has been\nadded successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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