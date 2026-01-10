# 📚 PROJECT MEMORY - MAIN FILE
**Current Version: v1.0.0**  
**Last Updated: September 11, 2025**

---

## 🔄 VERSION HISTORY
- **v1.0.0** - Initial WebRTC Implementation (Sept 11, 2025)

---

## 📱 CURRENT STATE: WebRTC Voice Calling Implementation

### Technology Stack
- **WebRTC**: For peer-to-peer audio streaming
- **Firebase Firestore**: For signaling and call state management  
- **Metered.ca**: For TURN/STUN servers
- **Flutter WebRTC Plugin**: flutter_webrtc package

### Working Features ✅
1. **Voice Calls**: One-to-one audio calls working
2. **Call Flow**: Outgoing → WebRTCCallScreen, Incoming → Overlay → WebRTCCallScreen
3. **Profile Display**: Users see OTHER person's profile (FIXED)
4. **Timer Sync**: Server timestamp based timing
5. **Connection Quality**: Real-time monitoring with visual indicators
6. **Network Recovery**: Auto-reconnection on network changes
7. **Audio Controls**: Mute/Speaker toggle working
8. **Call Termination**: Both users disconnect properly

### Key Files
- `lib/services/webrtc_call_service.dart` - Main WebRTC service
- `lib/screens/webrtc_call_screen.dart` - Call UI screen
- `lib/services/simple_call_service.dart` - Call orchestration
- `lib/services/global_call_handler.dart` - Incoming call handling
- `lib/widgets/webrtc_incoming_call_overlay.dart` - Incoming call UI

### Fixed Issues History
1. ✅ Profile display bug (users were seeing own profile)
2. ✅ Audio configuration conflicts  
3. ✅ Connection failures behind NAT
4. ✅ Signaling state conflicts
5. ✅ Timer synchronization
6. ✅ Call termination sync

### API Keys & Configuration
- **Metered.ca API**: Configured in webrtc_call_service.dart
- **Firebase**: Configured in google-services.json and GoogleService-Info.plist
- **TURN/STUN**: Dynamic credentials from Metered.ca

### Build Commands
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Testing Checklist
- [ ] Outgoing call initiates correctly
- [ ] Incoming call shows overlay
- [ ] Accept/Reject buttons work
- [ ] Audio flows both directions
- [ ] Timer shows same duration for both users
- [ ] Mute/unmute works
- [ ] Speaker toggle works
- [ ] Call ends for both users
- [ ] 45-second timeout works
- [ ] Busy detection works

---

## 🚫 CRITICAL RULES (NEVER BREAK)

1. **ALWAYS READ FIRST, ACT SECOND**
   - Read ALL relevant files completely
   - Understand CURRENT implementation
   - Check what's ALREADY WORKING
   - NEVER assume - always verify

2. **NEVER DELETE WITHOUT PERMISSION**
   - Don't delete working features
   - Don't replace existing implementations
   - Only ADD or FIX, never REMOVE unless told

3. **FOLLOW INSTRUCTIONS EXACTLY**
   - If told to "read and fix" - READ FIRST
   - Do EXACTLY what's asked, nothing more

4. **VERIFY BEFORE MODIFYING**
   - Test current functionality first
   - Only fix REAL issues

5. **PRESERVE EXISTING WORK**
   - Respect code that's already there
   - Keep working features intact


### Call State Flow
1. **Initiating**: Create Firestore doc → Navigate to WebRTCCallScreen
2. **Receiving**: Listen for calls → Show overlay → Accept/Reject
3. **Connected**: WebRTC peer connection established
4. **Ended**: Clean up resources → Navigate back

### Known Limitations
- No video calling (audio only)
- No group calls (one-to-one only)
- No call recording
- No CallKit integration (iOS)

---

## 🔮 FUTURE ENHANCEMENTS (Not Implemented)
1. Video calling support
2. Group calls with SFU
3. Call recording
4. CallKit/ConnectionService integration
5. Call history
6. Missed call notifications
7. Background mode support

---

## ⚠️ DO NOT CHANGE
- Profile display logic (working correctly)
- Timer synchronization (using server timestamp)
- Call termination flow (both users disconnect)
- TURN/STUN configuration (Metered.ca)
- Audio configuration (AndroidAudioConfiguration.communication)

---

## 📊 METRICS
- APK Size: ~100MB
- Call Connection Time: ~2-5 seconds
- Audio Quality: Good (with proper network)
- Timeout: 45 seconds for unanswered calls
- Max Call Duration: Unlimited

---

## 🐛 DEBUGGING
Enable verbose logging:
```dart
print('WebRTC: ${message}');
```

Check Firestore calls collection for state
Monitor console for WebRTC logs
Use Chrome://webrtc-internals for debugging

---

**END OF CURRENT VERSION**