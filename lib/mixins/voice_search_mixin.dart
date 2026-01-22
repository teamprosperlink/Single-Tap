import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Mixin for voice search functionality
/// Provides reusable voice search methods for any screen that needs it
mixin VoiceSearchMixin<T extends StatefulWidget> on State<T> {
  // Voice search state variables
  bool _isListening = false;
  stt.SpeechToText? _speech;
  bool _speechEnabled = false;
  Timer? _silenceTimer;

  bool get isListening => _isListening;

  /// Initialize speech recognition
  Future<void> initSpeech() async {
    _speech = stt.SpeechToText();
    _speechEnabled = await _speech!.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            stopVoiceSearch();
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  /// Start voice search
  /// [onResult] callback is called with the recognized text
  Future<void> startVoiceSearch(Function(String) onResult) async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Request microphone permission first
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('Microphone permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice search'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if speech is available
    if (!_speechEnabled && _speech != null) {
      _speechEnabled = await _speech!.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted && _isListening) {
            _silenceTimer?.cancel();
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (!_speechEnabled) {
        debugPrint('Speech recognition not available');
        return;
      }
    }

    setState(() {
      _isListening = true;
    });

    // Start 5-second silence timer
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isListening) {
        stopVoiceSearch();
      }
    });

    // Start listening
    if (_speech != null) {
      await _speech!.listen(
        onResult: (result) {
          if (mounted) {
            if (result.recognizedWords.isNotEmpty) {
              _silenceTimer?.cancel();
            }

            // Call the callback with recognized text
            onResult(result.recognizedWords);

            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              stopVoiceSearch();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN', // Support for Indian English
      );
    }
  }

  /// Stop voice search
  Future<void> stopVoiceSearch() async {
    if (!mounted) return;

    _silenceTimer?.cancel();
    await _speech?.stop();

    setState(() {
      _isListening = false;
    });
  }

  /// Dispose voice search resources
  void disposeVoiceSearch() {
    _silenceTimer?.cancel();
    _speech?.stop();
  }
}
