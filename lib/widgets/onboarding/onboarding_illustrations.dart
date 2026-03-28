import 'dart:math';
import 'package:flutter/material.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';

// ============================================================
// iPhone Phone Frame - matches real device look
// ============================================================
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const _PhoneFrame({required this.child, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final phoneW = constraints.maxWidth * 0.78;
          // Maintain phone aspect ratio (roughly 19.5:9) but clamp to available height
          final desiredH = phoneW * 2.05;
          final phoneH = desiredH.clamp(0.0, constraints.maxHeight * 0.95);
          // Scale factor based on phone width for responsive font/icon sizes
          final s = phoneW / 280; // 280 is reference width

          return Container(
            width: phoneW,
            height: phoneH,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(32 * s.clamp(0.7, 1.2)),
              border: Border.all(
                color: AppColors.glassBorder(alpha: 0.25),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.15),
                  blurRadius: 40, spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30 * s.clamp(0.7, 1.2)),
              child: Stack(
                children: [
                  // Screen background - actual app gradient
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromRGBO(64, 64, 64, 1), // #404040
                            Color.fromRGBO(0, 0, 0, 1),    // #000000
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Status bar
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 26 * s.clamp(0.8, 1.3),
                      padding: EdgeInsets.symmetric(horizontal: 18 * s.clamp(0.7, 1.3)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('9:41',
                              style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 8 * s.clamp(0.7, 1.3),
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteAlpha(alpha: 0.7))),
                          Row(
                            children: [
                              Icon(Icons.signal_cellular_4_bar, size: 9 * s.clamp(0.7, 1.3),
                                  color: AppColors.whiteAlpha(alpha: 0.5)),
                              SizedBox(width: 2 * s),
                              Icon(Icons.wifi, size: 9 * s.clamp(0.7, 1.3),
                                  color: AppColors.whiteAlpha(alpha: 0.5)),
                              SizedBox(width: 2 * s),
                              Icon(Icons.battery_full, size: 9 * s.clamp(0.7, 1.3),
                                  color: AppColors.whiteAlpha(alpha: 0.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Dynamic island
                  Positioned(
                    top: 5 * s.clamp(0.8, 1.3), left: 0, right: 0,
                    child: Center(
                      child: Container(
                        width: 60 * s.clamp(0.7, 1.3), height: 14 * s.clamp(0.7, 1.3),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(9 * s.clamp(0.7, 1.3)),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    top: 26 * s.clamp(0.8, 1.3), left: 0, right: 0, bottom: 16 * s.clamp(0.8, 1.3),
                    child: child,
                  ),
                  // Home indicator
                  Positioned(
                    bottom: 3 * s.clamp(0.8, 1.3), left: 0, right: 0,
                    child: Center(
                      child: Container(
                        width: 70 * s.clamp(0.7, 1.3), height: 3.5 * s.clamp(0.7, 1.3),
                        decoration: BoxDecoration(
                          color: AppColors.whiteAlpha(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Real app bar gradient (#282828 -> #404040 + white 0.5 bottom border)
Widget _appBarGradient({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(40, 40, 40, 1),  // #282828
          Color.fromRGBO(64, 64, 64, 1),  // #404040
        ],
      ),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 0.5),
      ),
    ),
    child: child,
  );
}

// Real bottom nav bar (matches main_navigation_screen.dart exactly)
Widget _bottomNav(int activeIndex) {
  const items = [
    (Icons.home, 'Home'),
    (Icons.chat_bubble, 'Chat'),
    (Icons.explore, 'Nearby'),
    (Icons.business_center, 'Networking'),
  ];

  return Container(
    height: 42,
    decoration: BoxDecoration(
      color: const Color.fromRGBO(64, 64, 64, 1), // #404040
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
      ),
    ),
    child: Row(
      children: List.generate(4, (i) {
        final active = i == activeIndex;
        return Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: active
                  ? BoxDecoration(
                      color: const Color.fromRGBO(75, 75, 75, 1), // #4B4B4B
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].$1, size: 14,
                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(height: 1),
                  Text(items[i].$2,
                      style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 6,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                        color: active ? Colors.white : Colors.white54)),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}

// ============================================================
// PAGE 1: Welcome - Combined Home Screen + AI Chat Demo
// ============================================================
class WelcomeIllustration extends StatefulWidget {
  final bool isActive;
  const WelcomeIllustration({super.key, required this.isActive});
  @override
  State<WelcomeIllustration> createState() => _WelcomeIllustrationState();
}

class _WelcomeIllustrationState extends State<WelcomeIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3500))
      ..addListener(_autoScroll);
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    if (widget.isActive) _start();
  }

  void _start() {
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    _entryCtrl.forward(from: 0);
    _pulseCtrl.repeat(reverse: true);
  }

  void _autoScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    // Start scrolling after product cards appear (0.30+), smoothly reach bottom by 0.90
    final scrollProgress = ((_entryCtrl.value - 0.30) / 0.60).clamp(0.0, 1.0);
    _scrollCtrl.jumpTo(max * Curves.easeInOut.transform(scrollProgress));
  }

  @override
  void didUpdateWidget(WelcomeIllustration old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
    if (!widget.isActive && old.isActive) _pulseCtrl.stop();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  double _f(double s, double e) =>
      Curves.easeOutCubic.transform(
          ((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: AppColors.primary,
          child: Column(
            children: [
              // App bar
              Opacity(
                opacity: _f(0.0, 0.08),
                child: _appBarGradient(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Text('SingleTap',
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 11,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.menu_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Chat area - scrollable combined content (auto-scrolls with animation)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),

                        // --- Part 1: Selling flow ---
                        // AI greeting
                        Opacity(
                          opacity: _f(0.03, 0.12),
                          child: _msgRow("Hi! I'm your Single Tap assistant. What would you like to find today?", false),
                        ),
                        const SizedBox(height: 6),

                        // User: "Selling iPhone 13 Pro"
                        _animMsg('Selling iPhone 13 Pro', true, _f(0.08, 0.18)),
                        const SizedBox(height: 6),

                        // AI: "Post created! Found 3 buyers nearby"
                        _animMsg('Post created! Found 3 buyers nearby', false, _f(0.15, 0.25)),
                        const SizedBox(height: 6),

                        // Two product cards side by side
                        SizedBox(
                          height: 115,
                          child: Opacity(
                            opacity: _f(0.22, 0.34),
                            child: Transform.translate(
                              offset: Offset(0, (1 - _f(0.22, 0.34)) * 20),
                              child: Row(
                                children: [
                                  Expanded(child: _productCard('iPhone 13', '\$699',
                                      'Exact Match', Colors.green, _pulseCtrl.value)),
                                  const SizedBox(width: 6),
                                  Expanded(child: _productCard('iPhone 14', '\$899',
                                      'Similar 89%', Colors.orange, _pulseCtrl.value)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // --- Part 2: Searching flow ---
                        // User: "iPhone"
                        _animMsg('iPhone', true, _f(0.34, 0.44)),
                        const SizedBox(height: 6),

                        // AI: "Found 1 exact match"
                        _animMsg('Found 1 exact match', false, _f(0.40, 0.50)),
                        const SizedBox(height: 6),

                        // Match result card
                        Transform.scale(
                          scale: 0.85 + _f(0.47, 0.57) * 0.15,
                          child: Opacity(
                            opacity: _f(0.47, 0.57),
                            child: _matchResultCard(),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // User: "pineapple"
                        _animMsg('pineapple', true, _f(0.55, 0.65)),
                        const SizedBox(height: 6),

                        // AI: no matches
                        _animMsg('No matches found. Your listing\nhas been stored for future matching.', false, _f(0.62, 0.74)),
                        const SizedBox(height: 4),

                        // Feedback icons
                        _feedbackRow(_f(0.72, 0.82)),
                        const SizedBox(height: 6),

                        // Listing button
                        _listingButton(_f(0.80, 0.90)),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),

              // Input field
              Opacity(
                opacity: _f(0.03, 0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Search nearby...',
                              style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 8,
                                color: Colors.grey[300])),
                        ),
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF007AFF),
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF007AFF),
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom nav
              Opacity(opacity: _f(0.0, 0.08), child: _bottomNav(0)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Shared helpers ---

  Widget _msgRow(String text, bool isUser) {
    final bubble = isUser ? _userBubble(text) : _aiBubble(text);
    if (isUser) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Flexible(child: bubble), _avatar(true)],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_avatar(false), Flexible(child: bubble)],
    );
  }

  Widget _animMsg(String text, bool isUser, double p) {
    return Transform.translate(
      offset: Offset((1 - p) * (isUser ? 40 : -40), 0),
      child: Opacity(opacity: p, child: _msgRow(text, isUser)),
    );
  }

  Widget _avatar(bool isUser) {
    return Container(
      width: 22, height: 22,
      margin: EdgeInsets.only(left: isUser ? 5 : 0, right: isUser ? 0 : 5, top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? Colors.grey[700] : null,
      ),
      child: isUser
          ? const Icon(Icons.person, color: Colors.white, size: 12)
          : ClipOval(child: Image.asset(AppAssets.logoPath, fit: BoxFit.cover)),
    );
  }

  Widget _aiBubble(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.white.withValues(alpha: 0.25),
        Colors.white.withValues(alpha: 0.15),
      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14), topRight: Radius.circular(14),
        bottomLeft: Radius.circular(3), bottomRight: Radius.circular(14)),
      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
    ),
    child: Text(text, style: const TextStyle(
        fontFamily: 'Poppins', fontSize: 8, color: Colors.white, height: 1.3)),
  );

  Widget _userBubble(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.blue.withValues(alpha: 0.6),
        Colors.purple.withValues(alpha: 0.4),
      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(14), topRight: Radius.circular(14),
        bottomLeft: Radius.circular(14), bottomRight: Radius.circular(3)),
      border: Border.all(color: Colors.blue.withValues(alpha: 0.4), width: 1),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(text, style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w500,
            color: Colors.white)),
        const SizedBox(height: 2),
        const Icon(Icons.volume_up, color: Colors.white54, size: 9),
      ],
    ),
  );

  // Product card (from old Page 1)
  Widget _productCard(String name, String price, String badge,
      Color badgeColor, double pulse) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.35),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.grey.shade600, Colors.grey.shade500]),
                  ),
                  child: Center(
                    child: Icon(Icons.phone_iphone,
                        color: Colors.white.withValues(alpha: 0.38), size: 24),
                  ),
                ),
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: badgeColor.withValues(alpha: 0.85),
                    ),
                    child: Text(badge,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 6,
                            fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF016CFF).withValues(alpha: 0.85),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.bookmark_border_rounded,
                        color: Colors.white, size: 8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 8,
                    fontWeight: FontWeight.w700, color: Colors.white)),
                Text(price, style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                    fontWeight: FontWeight.w700, color: Colors.green[400])),
                Row(
                  children: [
                    Icon(Icons.near_me, color: Colors.grey[500], size: 7),
                    const SizedBox(width: 2),
                    Text('0.5 km away', style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 6.5, color: Colors.grey[400])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Match result card (from old Page 2)
  Widget _matchResultCard() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 65,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.grey.shade500, Colors.grey.shade400]),
                    ),
                  ),
                  Positioned(
                    top: 4, left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.green.withValues(alpha: 0.85),
                      ),
                      child: const Text('Exact Match',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF007AFF),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.bookmark_border_rounded,
                          color: Colors.white, size: 8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15), width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('iphone 14 pro',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 8,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Apple · pro',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 6.5,
                          color: Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Feedback icons
  Widget _feedbackRow(double p) {
    return Opacity(
      opacity: p,
      child: Padding(
        padding: const EdgeInsets.only(left: 27),
        child: Row(
          children: [
            Icon(Icons.thumb_up_outlined,
                color: Colors.white.withValues(alpha: 0.4), size: 10),
            const SizedBox(width: 8),
            Icon(Icons.thumb_down_outlined,
                color: Colors.white.withValues(alpha: 0.4), size: 10),
            const SizedBox(width: 8),
            Icon(Icons.volume_up,
                color: Colors.white.withValues(alpha: 0.4), size: 10),
          ],
        ),
      ),
    );
  }

  // "Listing your post" pill button
  Widget _listingButton(double p) {
    return Transform.translate(
      offset: Offset((1 - p) * -20, 0),
      child: Opacity(
        opacity: p,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(left: 27),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.5), width: 1),
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF007AFF), size: 11),
                SizedBox(width: 4),
                Text('Listing your post',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                        fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 3: Matching - Real match results screen
// ============================================================
class MatchingIllustration extends StatefulWidget {
  final bool isActive;
  const MatchingIllustration({super.key, required this.isActive});
  @override
  State<MatchingIllustration> createState() => _MatchingIllustrationState();
}

class _MatchingIllustrationState extends State<MatchingIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1500));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MatchingIllustration old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
    if (!widget.isActive && old.isActive) _pulseCtrl.stop();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  double _f(double s, double e) =>
      Curves.easeOutCubic.transform(((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: AppColors.secondary,
          child: Column(
            children: [
              // App bar
              Opacity(
                opacity: _f(0.0, 0.1),
                child: _appBarGradient(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Spacer(),
                        Text('Product',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
              // Scrollable match results
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        // Match cards row 1
                        SizedBox(
                          height: 115,
                          child: Row(
                            children: [
                              Expanded(child: _matchCard('Sarah J.', 'iPhone 13',
                                  '\$650', 'Exact Match', Colors.green,
                                  _f(0.1, 0.35), _pulseCtrl.value)),
                              const SizedBox(width: 6),
                              Expanded(child: _matchCard('Mike C.', 'iPhone 13 Pro',
                                  '\$799', 'Similar 89%', Colors.orange,
                                  _f(0.2, 0.45), _pulseCtrl.value)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Match cards row 2
                        SizedBox(
                          height: 115,
                          child: Row(
                            children: [
                              Expanded(child: _matchCard('Emma W.', 'iPhone 14',
                                  '\$899', 'Similar 82%', Colors.orange,
                                  _f(0.4, 0.6), _pulseCtrl.value)),
                              const SizedBox(width: 6),
                              Expanded(child: _matchCard('Alex K.', 'iPhone 12',
                                  '\$499', 'Similar 74%', Colors.orange,
                                  _f(0.5, 0.7), _pulseCtrl.value)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Opacity(opacity: _f(0.0, 0.1), child: _bottomNav(0)),
            ],
          ),
        ),
      ),
    );
  }

  // Real product card matching home screen cards
  Widget _matchCard(String name, String product, String price,
      String badge, Color badgeColor, double progress, double pulse) {
    return Transform.translate(
      offset: Offset(0, (1 - progress) * 25),
      child: Opacity(
        opacity: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.45),
              Colors.white.withValues(alpha: 0.35),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with initials (like real match cards)
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.blue.shade700, Colors.purple.shade600,
                        ]),
                      ),
                      child: Center(
                        child: Text(name.substring(0, 1),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    Positioned(top: 3, left: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: badgeColor.withValues(alpha: 0.85),
                        ),
                        child: Text(badge, style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 5.5,
                            fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product, style: const TextStyle(fontFamily: 'Poppins', fontSize: 7,
                        fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(name, style: TextStyle(fontFamily: 'Poppins', fontSize: 6,
                        color: Colors.grey[400])),
                    Text(price, style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                        fontWeight: FontWeight.w700, color: Colors.green[400])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 4: Messages - Real conversations screen
// ============================================================
class MessagingIllustration extends StatefulWidget {
  final bool isActive;
  const MessagingIllustration({super.key, required this.isActive});
  @override
  State<MessagingIllustration> createState() => _MessagingIllustrationState();
}

class _MessagingIllustrationState extends State<MessagingIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MessagingIllustration old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
    if (!widget.isActive && old.isActive) _pulseCtrl.stop();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  double _f(double s, double e) =>
      Curves.easeOutCubic.transform(((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: AppColors.info,
          child: Column(
            children: [
              // Real Messages app bar (no bottom border)
              Opacity(
                opacity: _f(0.0, 0.1),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(40, 40, 40, 1),
                        Color.fromRGBO(64, 64, 64, 1),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Spacer(),
                        const Text('Messages',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.person_add, color: Colors.white, size: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab bar: Chats | Groups | Calls
              Opacity(
                opacity: _f(0.05, 0.15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      _tab('Chats', true), _tab('Groups', false), _tab('Calls', false),
                    ],
                  ),
                ),
              ),

              // Search bar
              Opacity(
                opacity: _f(0.1, 0.2),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.textSecondaryDark, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Search conversations...',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                                  color: AppColors.whiteAlpha(alpha: 0.4))),
                        ),
                        Icon(Icons.mic, size: 12,
                            color: Colors.white.withValues(alpha: 0.9)),
                      ],
                    ),
                  ),
                ),
              ),

              // Conversation tiles
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        _convTile('Sarah Johnson', 'Sure! Let me send photos', '2m',
                            3, 'Nearby', const Color(0xFF22C55E), Icons.near_me_outlined,
                            _f(0.15, 0.35)),
                        _convTile('Mike Chen', 'Is the price negotiable?', '15m',
                            1, 'Networking', const Color(0xFF3B82F6), Icons.hub_outlined,
                            _f(0.25, 0.45)),
                        _convTile('Emma Wilson', 'Thanks for the quick reply!', '1h',
                            0, 'Nearby', const Color(0xFF22C55E), Icons.near_me_outlined,
                            _f(0.35, 0.55)),
                        _convTile('Tech Group', 'Alex: Check this out', '3h',
                            5, 'Chat', const Color(0xFF9CA3AF), Icons.chat_bubble_outline,
                            _f(0.45, 0.65), isGroup: true),
                        _convTile('Alex Kumar', 'Typing...', 'now',
                            0, 'Business', const Color(0xFFEAB308), Icons.business_outlined,
                            _f(0.55, 0.75)),
                      ],
                    ),
                  ),
                ),
              ),

              Opacity(opacity: _f(0.0, 0.1), child: _bottomNav(1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: active ? const Color(0xFF3B82F6) : Colors.transparent, width: 1.5)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 9,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _convTile(String name, String msg, String time, int unread,
      String source, Color sourceColor, IconData sourceIcon, double progress,
      {bool isGroup = false}) {
    return Transform.translate(
      offset: Offset((1 - progress) * 30, 0),
      child: Opacity(
        opacity: progress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 14,
                backgroundColor: isGroup
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.grey[700],
                child: Icon(
                  isGroup ? Icons.group : Icons.person,
                  color: isGroup ? AppColors.primary : Colors.white,
                  size: isGroup ? 14 : 12),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 8,
                                  fontWeight: FontWeight.w600, color: Colors.white),
                              overflow: TextOverflow.ellipsis),
                        ),
                        // Source tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: sourceColor.withValues(alpha: 0.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sourceIcon, size: 7, color: sourceColor),
                              const SizedBox(width: 2),
                              Text(source, style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 5.5, fontWeight: FontWeight.w500,
                                  color: sourceColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(time, style: TextStyle(fontFamily: 'Poppins', fontSize: 6,
                        color: Colors.white.withValues(alpha: 0.5))),
                    Row(
                      children: [
                        Expanded(
                          child: Text(msg,
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                                  color: Colors.white.withValues(alpha: 0.6)),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFF25D366), // WhatsApp green
                            ),
                            child: Text('$unread',
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 6.5,
                                    fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 5: Nearby - Real nearby screen with staggered grid
// ============================================================
class NearbyIllustration extends StatefulWidget {
  final bool isActive;
  const NearbyIllustration({super.key, required this.isActive});
  @override
  State<NearbyIllustration> createState() => _NearbyIllustrationState();
}

class _NearbyIllustrationState extends State<NearbyIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800));
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2500));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _floatCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(NearbyIllustration old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
    if (!widget.isActive && old.isActive) _floatCtrl.stop();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  double _f(double s, double e) =>
      Curves.easeOutCubic.transform(((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _floatCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: AppColors.iosOrange,
          child: Column(
            children: [
              // Real Nearby app bar (no bottom border)
              Opacity(
                opacity: _f(0.0, 0.1),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(40, 40, 40, 1),
                        Color.fromRGBO(64, 64, 64, 1),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Spacer(),
                        const Text('Nearby',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.bookmark_border_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab bar: Products | Services
              Opacity(
                opacity: _f(0.05, 0.15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2), width: 0.8)),
                  ),
                  child: Row(
                    children: [
                      _nearbyTab('Products', true),
                      _nearbyTab('Services', false),
                    ],
                  ),
                ),
              ),

              // Search bar
              Opacity(
                opacity: _f(0.1, 0.2),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 12,
                            color: AppColors.textSecondaryDark),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Search posts...',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                                  color: AppColors.whiteAlpha(alpha: 0.4))),
                        ),
                        Icon(Icons.mic, size: 12,
                            color: Colors.white.withValues(alpha: 0.9)),
                      ],
                    ),
                  ),
                ),
              ),

              // Staggered grid of nearby cards (2 columns)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            _nearbyCard('AirPods Pro', 'Electronics', '\$149',
                                '0.5 km', 'Selling', Icons.headphones,
                                _f(0.15, 0.35), 72),
                            const SizedBox(height: 6),
                            _nearbyCard('Camera Sony', 'Electronics', '\$550',
                                '3.5 km', 'Selling', Icons.camera_alt,
                                _f(0.4, 0.6), 90),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Right column (offset for stagger)
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _nearbyCard('MacBook Air', 'Computers', '\$899',
                                '1.2 km', 'Selling', Icons.laptop_mac,
                                _f(0.25, 0.45), 83),
                            const SizedBox(height: 6),
                            _nearbyCard('iPad Mini', 'Tablets', '\$399',
                                '2.0 km', 'Buying', Icons.tablet_mac,
                                _f(0.5, 0.7), 63),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Opacity(opacity: _f(0.0, 0.1), child: _bottomNav(2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nearbyTab(String label, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: active ? const Color(0xFF3B82F6) : Colors.transparent, width: 1.5)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 8,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _nearbyCard(String name, String brand, String price, String dist,
      String type, IconData icon, double progress, double imageH) {
    final floatY = sin(_floatCtrl.value * pi) * 2;
    final isSelling = type == 'Selling';

    return Transform.translate(
      offset: Offset(0, (1 - progress) * 25 + floatY),
      child: Opacity(
        opacity: progress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              SizedBox(
                height: imageH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.indigo.shade900, Colors.purple.shade900,
                          ],
                        ),
                      ),
                      child: Center(child: Icon(icon, color: Colors.white38, size: 22)),
                    ),
                    // Domain badge (top-left)
                    Positioned(top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: const Color(0xFF007AFF).withValues(alpha: 0.85),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Text(brand, style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 5.5,
                            fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    // Bookmark (top-right)
                    Positioned(top: 4, right: 4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF007AFF),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.bookmark_border_rounded,
                            color: Colors.white70, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
              // Info section (black 65%)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                color: Colors.black.withValues(alpha: 0.65),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 8,
                        fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Expanded(child: Text(brand, style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 6.5,
                            color: Colors.grey[400]))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: (isSelling
                                ? const Color(0xFF4CAF50) : const Color(0xFFFF9800))
                                .withValues(alpha: 0.85),
                          ),
                          child: Text(isSelling ? 'Selling' : 'Buying',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
                                  fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(price, style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                        fontWeight: FontWeight.w700, color: Colors.green[400])),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 7, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(dist, style: TextStyle(fontFamily: 'Poppins', fontSize: 6.5,
                            color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 6: Get Started - Success with checkmark + confetti
// ============================================================
class GetStartedIllustration extends StatefulWidget {
  final bool isActive;
  const GetStartedIllustration({super.key, required this.isActive});
  @override
  State<GetStartedIllustration> createState() => _GetStartedIllustrationState();
}

class _GetStartedIllustrationState extends State<GetStartedIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _shimmerCtrl;
  final _random = Random(42);
  late List<_ConfettiPiece> _confetti;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2500));
    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000));
    _confetti = List.generate(20, (i) => _ConfettiPiece(
      x: _random.nextDouble(),
      speed: 0.5 + _random.nextDouble() * 0.5,
      size: 3 + _random.nextDouble() * 4,
      color: [AppColors.primary, AppColors.secondary, AppColors.success,
              AppColors.warning, AppColors.info, AppColors.error][i % 6],
      drift: (_random.nextDouble() - 0.5) * 0.3,
    ));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _shimmerCtrl.repeat();
  }

  @override
  void didUpdateWidget(GetStartedIllustration old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _start();
    if (!widget.isActive && old.isActive) _shimmerCtrl.stop();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  double _f(double s, double e) =>
      Curves.easeOutCubic.transform(((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _shimmerCtrl]),
        builder: (context, _) {
          final confP = _f(0.35, 0.7);
          return _PhoneFrame(
            glowColor: AppColors.success,
            child: Stack(
              children: [
                // Confetti
                if (confP > 0)
                  ...List.generate(_confetti.length, (i) {
                    final c = _confetti[i];
                    final y = -0.1 + confP * c.speed * 1.2;
                    final x = c.x + sin(confP * pi * 3 + i) * c.drift;
                    final op = confP < 0.8 ? confP : ((1 - confP) * 5).clamp(0.0, 1.0);
                    return Positioned(
                      left: x * 200, top: y * 350,
                      child: Opacity(
                        opacity: op,
                        child: Transform.rotate(
                          angle: confP * pi * 2 * c.speed,
                          child: Container(
                            width: c.size, height: c.size * 0.6,
                            decoration: BoxDecoration(
                              color: c.color, borderRadius: BorderRadius.circular(1)),
                          ),
                        ),
                      ),
                    );
                  }),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      // Checkmark
                      Transform.scale(
                        scale: 0.5 + _f(0.0, 0.3) * 0.5,
                        child: Opacity(
                          opacity: _f(0.0, 0.3),
                          child: SizedBox(
                            width: 70, height: 70,
                            child: CustomPaint(
                              painter: _CheckmarkPainter(
                                circleProgress: _f(0.0, 0.3),
                                checkProgress: _f(0.2, 0.5),
                                glowAlpha: 0.2 + _shimmerCtrl.value * 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Logo
                      Opacity(
                        opacity: _f(0.4, 0.6),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: ClipOval(
                            child: Image.asset(AppAssets.logoPath, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: _f(0.45, 0.65),
                        child: const Text('All Ready!',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: _f(0.5, 0.7),
                        child: Text('Your AI-powered matching\nis ready to go',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 8,
                                color: AppColors.whiteAlpha(alpha: 0.6), height: 1.4)),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _check('AI-powered post creation', _f(0.6, 0.8)),
                            const SizedBox(height: 4),
                            _check('Smart semantic matching', _f(0.65, 0.85)),
                            const SizedBox(height: 4),
                            _check('Voice calls & messaging', _f(0.7, 0.9)),
                            const SizedBox(height: 4),
                            _check('Nearby discovery', _f(0.75, 0.95)),
                          ],
                        ),
                      ),
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _check(String text, double p) {
    return Transform.translate(
      offset: Offset((1 - p) * 25, 0),
      child: Opacity(
        opacity: p,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 11),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 8, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double x, speed, size, drift;
  final Color color;
  _ConfettiPiece({required this.x, required this.speed, required this.size,
      required this.color, required this.drift});
}

class _CheckmarkPainter extends CustomPainter {
  final double circleProgress, checkProgress, glowAlpha;
  _CheckmarkPainter({required this.circleProgress,
      required this.checkProgress, required this.glowAlpha});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    canvas.drawCircle(c, r, Paint()
      ..color = AppColors.success.withValues(alpha: glowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));

    if (circleProgress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          -pi / 2, 2 * pi * circleProgress, false,
          Paint()..color = AppColors.success..style = PaintingStyle.stroke
            ..strokeWidth = 3..strokeCap = StrokeCap.round);
    }

    if (checkProgress > 0) {
      final p1 = Offset(size.width * 0.28, size.height * 0.52);
      final p2 = Offset(size.width * 0.44, size.height * 0.68);
      final p3 = Offset(size.width * 0.72, size.height * 0.36);
      final path = Path()..moveTo(p1.dx, p1.dy);
      if (checkProgress <= 0.5) {
        final t = checkProgress * 2;
        path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
      } else {
        final t = (checkProgress - 0.5) * 2;
        path.lineTo(p2.dx, p2.dy);
        path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
      }
      canvas.drawPath(path, Paint()..color = AppColors.success
        ..style = PaintingStyle.stroke..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter o) =>
      circleProgress != o.circleProgress || checkProgress != o.checkProgress ||
      glowAlpha != o.glowAlpha;
}
