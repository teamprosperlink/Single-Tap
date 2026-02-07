import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'business_service.dart';

class FirebaseProvider extends InheritedWidget {
  final BusinessService businessService;

  const FirebaseProvider({
    super.key,
    required this.businessService,
    required super.child,
  });

  /// Firestore instance.
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Firebase Auth instance.
  static FirebaseAuth get auth => FirebaseAuth.instance;

  /// Current authenticated user's ID.
  static String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static FirebaseProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FirebaseProvider>()!;
  }

  @override
  bool updateShouldNotify(covariant FirebaseProvider oldWidget) => false;
}
