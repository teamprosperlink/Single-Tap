import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccountModel {
  final String? id;
  final String userId;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String accountType;
  final String? ifscCode;
  final String? swiftCode;
  final String? upiId;
  final String? branchName;
  final bool isPrimary;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Bank brand colors for visual appeal
  final String? bankColor;
  final String? bankLogo;

  BankAccountModel({
    this.id,
    required this.userId,
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    this.ifscCode,
    this.swiftCode,
    this.upiId,
    this.branchName,
    this.isPrimary = false,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.bankColor,
    this.bankLogo,
  });

  // Get masked account number for display
  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    final lastFour = accountNumber.substring(accountNumber.length - 4);
    return '**** **** $lastFour';
  }

  // Get short account number
  String get shortAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '••••${accountNumber.substring(accountNumber.length - 4)}';
  }

  factory BankAccountModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BankAccountModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      accountHolderName: data['accountHolderName'] ?? '',
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      accountType: data['accountType'] ?? 'savings',
      ifscCode: data['ifscCode'],
      swiftCode: data['swiftCode'],
      upiId: data['upiId'],
      branchName: data['branchName'],
      isPrimary: data['isPrimary'] ?? false,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      bankColor: data['bankColor'],
      bankLogo: data['bankLogo'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountType': accountType,
      'ifscCode': ifscCode,
      'swiftCode': swiftCode,
      'upiId': upiId,
      'branchName': branchName,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'bankColor': bankColor,
      'bankLogo': bankLogo,
    };
  }

  BankAccountModel copyWith({
    String? id,
    String? userId,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? accountType,
    String? ifscCode,
    String? swiftCode,
    String? upiId,
    String? branchName,
    bool? isPrimary,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bankColor,
    String? bankLogo,
  }) {
    return BankAccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountType: accountType ?? this.accountType,
      ifscCode: ifscCode ?? this.ifscCode,
      swiftCode: swiftCode ?? this.swiftCode,
      upiId: upiId ?? this.upiId,
      branchName: branchName ?? this.branchName,
      isPrimary: isPrimary ?? this.isPrimary,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bankColor: bankColor ?? this.bankColor,
      bankLogo: bankLogo ?? this.bankLogo,
    );
  }
}

// Account types
enum AccountType {
  savings('Savings', 'savings'),
  current('Current', 'current'),
  salary('Salary', 'salary'),
  fixedDeposit('Fixed Deposit', 'fixed_deposit'),
  recurring('Recurring', 'recurring');

  final String displayName;
  final String value;

  const AccountType(this.displayName, this.value);

  static AccountType fromValue(String value) {
    return AccountType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AccountType.savings,
    );
  }
}
