import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();
  
  bool _hasConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool get hasConnection => _hasConnection;
  Stream<bool> get connectionChange => _connectionChangeController.stream;

  Future<void> initialize() async {
    await _checkConnection();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_connectionChanged);
  }

  Future<bool> _checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _hasConnection = !results.contains(ConnectivityResult.none);
      _connectionChangeController.add(_hasConnection);
      return _hasConnection;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return true; // Assume connected if check fails
    }
  }

  void _connectionChanged(List<ConnectivityResult> results) {
    final previousConnection = _hasConnection;
    _hasConnection = !results.contains(ConnectivityResult.none);
    
    if (previousConnection != _hasConnection) {
      _connectionChangeController.add(_hasConnection);
    }
  }

  void showNoConnectionSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No internet connection. Some features may not work.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void showConnectionRestoredSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi, color: Colors.white),
            SizedBox(width: 12),
            Text('Connection restored'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<T?> executeWithConnectivityCheck<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    bool showError = true,
  }) async {
    if (!_hasConnection) {
      if (showError) {
        showNoConnectionSnackBar(context);
      }
      return null;
    }

    try {
      return await operation();
    } catch (e) {
      // Check if it's a network error
      if (e.toString().contains('ENETUNREACH') || 
          e.toString().contains('NetworkException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        _hasConnection = false;
        _connectionChangeController.add(false);
        if (showError) {
          showNoConnectionSnackBar(context);
        }
      }
      rethrow;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionChangeController.close();
  }
}