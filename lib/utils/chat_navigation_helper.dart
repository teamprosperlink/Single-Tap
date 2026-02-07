import 'package:flutter/material.dart';

/// Helper class for navigating to chat screens.
class ChatNavigationHelper {
  ChatNavigationHelper._();

  /// Open a chat with a customer user.
  static Future<void> openCustomerChat(
    BuildContext context, {
    String? userId,
    String? userName,
    String? userPhoto,
    String? customerId,
    String? customerName,
    String? customerPhoto,
  }) async {
    // Stub: no-op
  }

  /// Open a chat with a business.
  static Future<void> openBusinessChat(
    BuildContext context, {
    required String businessId,
    required String businessName,
    String? businessPhoto,
  }) async {
    // Stub: no-op
  }
}
