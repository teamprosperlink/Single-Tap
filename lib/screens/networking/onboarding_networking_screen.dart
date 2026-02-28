import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' show sin, pi;

import 'create_networking_profile_screen.dart';
import '../../widgets/networking/networking_widgets.dart';

class LiveConnectScreen extends StatefulWidget {
  const LiveConnectScreen({super.key});

  @override
  State<LiveConnectScreen> createState() => _LiveConnectScreenState();
}

class _LiveConnectScreenState extends State<LiveConnectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  final List<CurvedAnimation> _iconCurves = [];
  final List<CurvedAnimation> _textCurves = [];

  static const _steps = [
    (
      icon: Icons.person_add_alt_1_rounded,
      color: Color(0xFF007AFF),
      title: 'Create Profile',
      text:
          'Create your networking profile to get started — visible in the Drawer under Networking Profiles',
      isLeft: true,
    ),
    (
      icon: Icons.send_rounded,
      color: Color(0xFF00B4D8),
      title: 'Send Request',
      text:
          'Find someone in Discover All or Smart Connect and send them a connection request',
      isLeft: false,
    ),
    (
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFFFA502),
      title: 'Pending Request',
      text:
          'The other user gets a pending request — they can choose to accept or delete it',
      isLeft: true,
    ),
    (
      icon: Icons.check_circle_rounded,
      color: Color(0xFF00E676),
      title: 'Accept or Delete',
      text:
          'If accepted, the connection card appears in My Networking — if deleted, the user reappears in Discover & Smart Connect',
      isLeft: false,
    ),
    (
      icon: Icons.account_circle_rounded,
      color: Color(0xFF7C4DFF),
      title: 'Your Profiles',
      text:
          'All your created profiles are saved in the Drawer → Networking Profiles — manage or switch anytime',
      isLeft: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..forward();

    for (int i = 0; i < _steps.length; i++) {
      final rowStart = (i * 0.18).clamp(0.0, 0.75);
      _iconCurves.add(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(rowStart, (rowStart + 0.12).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ));
      _textCurves.add(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(
            (rowStart + 0.08).clamp(0.0, 1.0), (rowStart + 0.2).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ));
    }

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _staggerCtrl.stop();
    _floatCtrl.stop();
    _pulseCtrl.stop();
    for (final c in _iconCurves) {
      c.dispose();
    }
    for (final c in _textCurves) {
      c.dispose();
    }
    _staggerCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NetworkingWidgets.networkingAppBar(
        title: 'Getting Started',
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: NetworkingWidgets.bodyGradient(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              /// Step cards
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      for (int i = 0; i < _steps.length; i++)
                        _buildStepRow(i),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              /// Page dots
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageDot(true),
                    const SizedBox(width: 6),
                    _pageDot(false),
                    const SizedBox(width: 6),
                    _pageDot(false),
                  ],
                ),
              ),

              /// Button
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LiveConnectFeaturesScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF0060D0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "See Features",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int index) {
    final s = _steps[index];
    final iconCurve = _iconCurves[index];
    final textCurve = _textCurves[index];

    final iconSlide = s.isLeft ? -50.0 : 50.0;
    final textSlide = s.isLeft ? 50.0 : -50.0;

    final iconWidget = AnimatedBuilder(
      animation: iconCurve,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(iconSlide * (1 - iconCurve.value), 0),
          child: Opacity(opacity: iconCurve.value, child: child),
        );
      },
      child: _iconBox(s.icon, s.color, index),
    );

    final textWidget = AnimatedBuilder(
      animation: textCurve,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(textSlide * (1 - textCurve.value), 0),
          child: Opacity(opacity: textCurve.value, child: child),
        );
      },
      child: _textCard(s.title, s.text, s.color, index + 1),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: s.isLeft
            ? [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(child: textWidget),
              ]
            : [
                Expanded(child: textWidget),
                const SizedBox(width: 12),
                iconWidget,
              ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color, int index) {
    final phase = index * 0.4;
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _pulseCtrl]),
      builder: (context, child) {
        final dy = sin((_floatCtrl.value + phase) * pi) * 4;
        final glowAlpha = 0.15 + (_pulseCtrl.value * 0.2);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowAlpha),
                  blurRadius: 16 + (_pulseCtrl.value * 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 26, color: color),
          ),
        );
      },
    );
  }

  Widget _textCard(String title, String text, Color accent, int step) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final borderAlpha = 0.2 + (_pulseCtrl.value * 0.15);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: accent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pageDot(bool active) {
    return Container(
      width: active ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active
            ? const Color(0xFF007AFF)
            : Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

class LiveConnectFeaturesScreen extends StatefulWidget {
  const LiveConnectFeaturesScreen({super.key});

  @override
  State<LiveConnectFeaturesScreen> createState() =>
      _LiveConnectFeaturesScreenState();
}

class _LiveConnectFeaturesScreenState extends State<LiveConnectFeaturesScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  final List<CurvedAnimation> _iconCurves = [];
  final List<CurvedAnimation> _textCurves = [];

  static const _features = [
    (
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6B8A),
      title: 'Vibe Match',
      text:
          'Set your interests, preferences, and tastes to discover people who feel like your vibe',
      isLeft: true,
    ),
    (
      icon: Icons.public_rounded,
      color: Color(0xFF00B4D8),
      title: 'Nearby & Global',
      text:
          'Find people near you, in your city, or from cultures and countries you care about',
      isLeft: false,
    ),
    (
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF7C4DFF),
      title: 'Meaningful Intros',
      text:
          "Every request comes with a short note: why they're reaching out and what they're interested in",
      isLeft: true,
    ),
    (
      icon: Icons.shield_rounded,
      color: Color(0xFF00E676),
      title: 'Safe & Private',
      text:
          'Your profile and chats stay fully protected with strong privacy controls and safe defaults',
      isLeft: false,
    ),
    (
      icon: Icons.call_rounded,
      color: Color(0xFF007AFF),
      title: 'Chat & Call',
      text:
          'Move from matching to real-time chat or calls and build meaningful connections faster',
      isLeft: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..forward();

    // Pre-create CurvedAnimations for each row
    for (int i = 0; i < _features.length; i++) {
      final rowStart = (i * 0.18).clamp(0.0, 0.75);
      _iconCurves.add(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(rowStart, (rowStart + 0.12).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ));
      _textCurves.add(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(
            (rowStart + 0.08).clamp(0.0, 1.0), (rowStart + 0.2).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ));
    }

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _staggerCtrl.stop();
    _floatCtrl.stop();
    _pulseCtrl.stop();
    for (final c in _iconCurves) {
      c.dispose();
    }
    for (final c in _textCurves) {
      c.dispose();
    }
    _staggerCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NetworkingWidgets.networkingAppBar(
        title: 'Features',
        onBack: () {
          if (!mounted) return;
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      body: Container(
        decoration: NetworkingWidgets.bodyGradient(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              /// Feature list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      for (int i = 0; i < _features.length; i++)
                        _buildFeatureRow(i),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              /// Page dots
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageDot(false),
                    const SizedBox(width: 6),
                    _pageDot(true),
                    const SizedBox(width: 6),
                    _pageDot(false),
                  ],
                ),
              ),

              /// Button
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SmartLiveConnect(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF0060D0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF007AFF).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Find Your Vibe',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(int index) {
    final f = _features[index];
    final iconCurve = _iconCurves[index];
    final textCurve = _textCurves[index];

    final iconSlide = f.isLeft ? -50.0 : 50.0;
    final textSlide = f.isLeft ? 50.0 : -50.0;

    final iconWidget = AnimatedBuilder(
      animation: iconCurve,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(iconSlide * (1 - iconCurve.value), 0),
          child: Opacity(opacity: iconCurve.value, child: child),
        );
      },
      child: _iconBox(f.icon, f.color, index),
    );

    final textWidget = AnimatedBuilder(
      animation: textCurve,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(textSlide * (1 - textCurve.value), 0),
          child: Opacity(opacity: textCurve.value, child: child),
        );
      },
      child: _textCard(f.title, f.text, f.color),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: f.isLeft
            ? [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(child: textWidget),
              ]
            : [
                Expanded(child: textWidget),
                const SizedBox(width: 12),
                iconWidget,
              ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color, int index) {
    // Offset each icon's phase so they don't all float in sync
    final phase = index * 0.4;
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _pulseCtrl]),
      builder: (context, child) {
        final dy = sin((_floatCtrl.value + phase) * pi) * 4;
        final glowAlpha = 0.15 + (_pulseCtrl.value * 0.2);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowAlpha),
                  blurRadius: 16 + (_pulseCtrl.value * 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 26, color: color),
          ),
        );
      },
    );
  }

  Widget _textCard(String title, String text, Color accent) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final borderAlpha = 0.2 + (_pulseCtrl.value * 0.15);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pageDot(bool active) {
    return Container(
      width: active ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active
            ? const Color(0xFF007AFF)
            : Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

class SmartLiveConnect extends StatefulWidget {
  const SmartLiveConnect({super.key});

  @override
  State<SmartLiveConnect> createState() => _SmartLiveConnectState();
}

class _SmartLiveConnectState extends State<SmartLiveConnect>
    with TickerProviderStateMixin {
  late final AnimationController _staggerCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  final List<CurvedAnimation> _iconCurves = [];
  final List<CurvedAnimation> _textCurves = [];

  static const _tabs = [
    (
      icon: Icons.explore_rounded,
      color: Color(0xFF00B4D8),
      title: 'Discover All',
      text:
          'Browse all profiles nearby or worldwide without any filters — just explore freely and find people who catch your eye',
      isLeft: true,
    ),
    (
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFFA502),
      title: 'Smart Connect',
      text:
          'Use filters like category, age, gender, location and more to find exactly the kind of people you want to connect with',
      isLeft: false,
    ),
    (
      icon: Icons.person_pin_rounded,
      color: Color(0xFF7C4DFF),
      title: 'My Networking',
      text:
          'Manage your connections, pending requests, and conversations — your networking hub all in one place',
      isLeft: true,
    ),
    (
      icon: Icons.chat_rounded,
      color: Color(0xFF00E676),
      title: 'Chat & Call',
      text:
          'Once connected, chat or voice call directly from My Networking — all messages appear in your Messages screen',
      isLeft: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..forward();

    for (int i = 0; i < _tabs.length; i++) {
      final rowStart = (i * 0.2).clamp(0.0, 0.75);
      _iconCurves.add(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(rowStart, (rowStart + 0.15).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ));
      _textCurves.add(CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(
            (rowStart + 0.1).clamp(0.0, 1.0), (rowStart + 0.25).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      ));
    }

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _staggerCtrl.stop();
    _floatCtrl.stop();
    _pulseCtrl.stop();
    for (final c in _iconCurves) {
      c.dispose();
    }
    for (final c in _textCurves) {
      c.dispose();
    }
    _staggerCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NetworkingWidgets.networkingAppBar(
        title: 'Explore Tabs',
        onBack: () {
          if (!mounted) return;
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      body: Container(
        decoration: NetworkingWidgets.bodyGradient(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              /// Tab feature cards
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      for (int i = 0; i < _tabs.length; i++)
                        _buildTabRow(i),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              /// Page dots
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageDot(false),
                    const SizedBox(width: 6),
                    _pageDot(false),
                    const SizedBox(width: 6),
                    _pageDot(true),
                  ],
                ),
              ),

              /// Button
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: GestureDetector(
                  onTap: () async {
                    if (!mounted) return;
                    HapticFeedback.lightImpact();
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CreateNetworkingProfileScreen(
                                createdFrom: 'Networking'),
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF0060D0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF)
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Discover People',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabRow(int index) {
    final t = _tabs[index];
    final iconCurve = _iconCurves[index];
    final textCurve = _textCurves[index];

    final iconSlide = t.isLeft ? -50.0 : 50.0;
    final textSlide = t.isLeft ? 50.0 : -50.0;

    final iconWidget = AnimatedBuilder(
      animation: iconCurve,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(iconSlide * (1 - iconCurve.value), 0),
          child: Opacity(opacity: iconCurve.value, child: child),
        );
      },
      child: _iconBox(t.icon, t.color, index),
    );

    final textWidget = AnimatedBuilder(
      animation: textCurve,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(textSlide * (1 - textCurve.value), 0),
          child: Opacity(opacity: textCurve.value, child: child),
        );
      },
      child: _textCard(t.title, t.text, t.color),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: t.isLeft
            ? [
                iconWidget,
                const SizedBox(width: 12),
                Expanded(child: textWidget),
              ]
            : [
                Expanded(child: textWidget),
                const SizedBox(width: 12),
                iconWidget,
              ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color, int index) {
    final phase = index * 0.4;
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _pulseCtrl]),
      builder: (context, child) {
        final dy = sin((_floatCtrl.value + phase) * pi) * 4;
        final glowAlpha = 0.15 + (_pulseCtrl.value * 0.2);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowAlpha),
                  blurRadius: 16 + (_pulseCtrl.value * 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 30, color: color),
          ),
        );
      },
    );
  }

  Widget _textCard(String title, String text, Color accent) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final borderAlpha = 0.2 + (_pulseCtrl.value * 0.15);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pageDot(bool active) {
    return Container(
      width: active ? 22 : 7,
      height: 7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: active
            ? const Color(0xFF007AFF)
            : Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}
