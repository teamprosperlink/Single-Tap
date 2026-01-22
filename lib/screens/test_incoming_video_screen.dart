import 'package:flutter/material.dart';
import 'call/incoming_video_call_screen.dart';

/// Test screen to directly open incoming video call screen
/// Use this to verify if IncomingVideoCallScreen works independently
class TestIncomingVideoScreen extends StatelessWidget {
  const TestIncomingVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Incoming Video Call')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Test incoming video call screen directly
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IncomingVideoCallScreen(
                      callId: 'test_call_123',
                      callerName: 'Test Caller',
                      callerPhoto: null,
                      callerId: 'test_user_id',
                      onCallAccepted: () {
                        debugPrint('  Test call accepted');
                      },
                    ),
                  ),
                );
              },
              child: const Text('Test Video Call Screen'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tap button to test incoming video call screen',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
