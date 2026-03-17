import 'dart:math';
import 'package:flutter/material.dart';
import '../../res/config/app_colors.dart';

// ============================================================
// iPhone Phone Frame - matches real device look (shared style)
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
                            Color.fromRGBO(64, 64, 64, 1),
                            Color.fromRGBO(0, 0, 0, 1),
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
          Color.fromRGBO(40, 40, 40, 1),
          Color.fromRGBO(64, 64, 64, 1),
        ],
      ),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 0.5),
      ),
    ),
    child: child,
  );
}

// Bottom nav bar for networking screens (Networking tab active)
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
      color: const Color.fromRGBO(64, 64, 64, 1),
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
                      color: const Color.fromRGBO(75, 75, 75, 1),
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
// PAGE 1: Create Profile - Shows profile creation form
// ============================================================
class NetworkingCreateProfileIllustration extends StatefulWidget {
  final bool isActive;
  const NetworkingCreateProfileIllustration({super.key, required this.isActive});
  @override
  State<NetworkingCreateProfileIllustration> createState() =>
      _NetworkingCreateProfileIllustrationState();
}

class _NetworkingCreateProfileIllustrationState
    extends State<NetworkingCreateProfileIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3200));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(NetworkingCreateProfileIllustration old) {
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
      Curves.easeOutCubic.transform(
          ((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: const Color(0xFF007AFF),
          child: Column(
            children: [
              // App bar
              Opacity(
                opacity: _f(0.0, 0.08),
                child: _appBarGradient(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Spacer(),
                        Text('Create Profile',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              // Form content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Profile photo circle
                        Center(
                          child: Opacity(
                            opacity: _f(0.05, 0.18),
                            child: Transform.scale(
                              scale: 0.8 + _f(0.05, 0.18) * 0.2,
                              child: Container(
                                width: 55, height: 55,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [
                                    const Color(0xFF007AFF).withValues(alpha: 0.3),
                                    const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                                  ]),
                                  border: Border.all(
                                    color: const Color(0xFF007AFF).withValues(alpha: 0.6),
                                    width: 1.5),
                                ),
                                child: Icon(Icons.camera_alt_rounded,
                                    color: Colors.white.withValues(alpha: 0.7), size: 20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Name field
                        _animField('Full Name', 'Rahul Sharma', Icons.person_rounded,
                            _f(0.12, 0.25)),
                        const SizedBox(height: 5),

                        // About me field
                        _animField('About Me', 'Software developer...', Icons.info_outline_rounded,
                            _f(0.18, 0.32)),
                        const SizedBox(height: 5),

                        // Occupation field
                        _animField('Occupation', 'Full Stack Dev', Icons.work_rounded,
                            _f(0.24, 0.38)),
                        const SizedBox(height: 8),

                        // Section: Category
                        _sectionTitle('Networking Category', _f(0.32, 0.45)),
                        const SizedBox(height: 4),

                        // Category chips
                        Opacity(
                          opacity: _f(0.38, 0.52),
                          child: Transform.translate(
                            offset: Offset(0, (1 - _f(0.38, 0.52)) * 15),
                            child: Wrap(
                              spacing: 4, runSpacing: 4,
                              children: [
                                _categoryChip('Professional', const Color(0xFF007AFF), true),
                                _categoryChip('Business', const Color(0xFFFFA502), false),
                                _categoryChip('Social', const Color(0xFFFF6B8A), false),
                                _categoryChip('Tech', const Color(0xFF00B4D8), false),
                                _categoryChip('Creative', const Color(0xFF7C4DFF), false),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subcategory chips
                        Opacity(
                          opacity: _f(0.48, 0.62),
                          child: Transform.translate(
                            offset: Offset(0, (1 - _f(0.48, 0.62)) * 12),
                            child: Wrap(
                              spacing: 3, runSpacing: 3,
                              children: [
                                _subCategoryChip('Job Seekers', true),
                                _subCategoryChip('Freelancers', false),
                                _subCategoryChip('Mentors', false),
                                _subCategoryChip('Remote', false),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Gender & DOB row
                        Opacity(
                          opacity: _f(0.55, 0.68),
                          child: Row(
                            children: [
                              Expanded(child: _miniField('Gender', 'Male', Icons.person_outline)),
                              const SizedBox(width: 4),
                              Expanded(child: _miniField('DOB', '15 Jan 1995', Icons.cake_rounded)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Location field
                        _animField('Location', 'Mumbai, India', Icons.location_on_rounded,
                            _f(0.62, 0.75)),
                        const SizedBox(height: 8),

                        // Discovery toggle
                        Opacity(
                          opacity: _f(0.72, 0.85),
                          child: _toggleRow('Visible in Discovery', true),
                        ),
                        const SizedBox(height: 4),
                        Opacity(
                          opacity: _f(0.76, 0.88),
                          child: _toggleRow('Allow Calls', true),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),

              // Save button
              Opacity(
                opacity: _f(0.82, 0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Container(
                    width: double.infinity,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF0060D0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withValues(
                              alpha: 0.15 + _pulseCtrl.value * 0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.save_rounded, color: Colors.white, size: 11),
                          SizedBox(width: 4),
                          Text('Save Profile',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 8,
                                  fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Opacity(opacity: _f(0.0, 0.08), child: _bottomNav(3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animField(String label, String value, IconData icon, double p) {
    return Transform.translate(
      offset: Offset((1 - p) * 30, 0),
      child: Opacity(
        opacity: p,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 11),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
                      color: Colors.white.withValues(alpha: 0.4))),
                  Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 7.5,
                      color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 10),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 5,
                  color: Colors.white.withValues(alpha: 0.4))),
              Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 6.5,
                  color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, double p) {
    return Opacity(
      opacity: p,
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(title, style: TextStyle(fontFamily: 'Poppins', fontSize: 7.5,
            fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
      ),
    );
  }

  Widget _categoryChip(String label, Color color, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: selected ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 6,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? color : Colors.white.withValues(alpha: 0.6))),
    );
  }

  Widget _subCategoryChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: selected
            ? const Color(0xFF007AFF).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: selected
              ? const Color(0xFF007AFF).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? const Color(0xFF007AFF)
              : Colors.white.withValues(alpha: 0.5))),
    );
  }

  Widget _toggleRow(String label, bool value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                color: Colors.white.withValues(alpha: 0.7))),
          ),
          Container(
            width: 26, height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: value ? const Color(0xFF34C759) : Colors.grey[700],
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 11, height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 2: Discover People - Profile cards grid
// ============================================================
class NetworkingDiscoverIllustration extends StatefulWidget {
  final bool isActive;
  const NetworkingDiscoverIllustration({super.key, required this.isActive});
  @override
  State<NetworkingDiscoverIllustration> createState() =>
      _NetworkingDiscoverIllustrationState();
}

class _NetworkingDiscoverIllustrationState
    extends State<NetworkingDiscoverIllustration>
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
  void didUpdateWidget(NetworkingDiscoverIllustration old) {
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
      Curves.easeOutCubic.transform(
          ((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _floatCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: const Color(0xFF00B4D8),
          child: Column(
            children: [
              // App bar
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
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF007AFF).withValues(alpha: 0.9),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 12),
                        ),
                        const Spacer(),
                        const Text('Networking',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        const SizedBox(width: 22),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab bar: Discover All | Smart Connect
              Opacity(
                opacity: _f(0.05, 0.15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      _tab('Around me', true),
                      _tab('My Network', false),
                      _tab('Request', false),
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
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Search people...',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                                  color: Colors.white.withValues(alpha: 0.4))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Profile cards grid
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
                            _profileCard('Priya M.', 'UI/UX Designer', 'Creative',
                                const Color(0xFF7C4DFF), '0.8 km',
                                Icons.palette_rounded, _f(0.15, 0.35), 75),
                            const SizedBox(height: 5),
                            _profileCard('Amit K.', 'Startup Founder', 'Business',
                                const Color(0xFFFFA502), '3.2 km',
                                Icons.business_rounded, _f(0.4, 0.6), 65),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Right column
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            _profileCard('Neha S.', 'Data Scientist', 'Tech',
                                const Color(0xFF00B4D8), '1.5 km',
                                Icons.code_rounded, _f(0.25, 0.45), 75),
                            const SizedBox(height: 5),
                            _profileCard('Ravi P.', 'Fitness Coach', 'Personal Dev',
                                const Color(0xFF00E676), '2.1 km',
                                Icons.fitness_center_rounded, _f(0.5, 0.7), 65),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Opacity(opacity: _f(0.0, 0.1), child: _bottomNav(3)),
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
            color: active ? const Color(0xFF007AFF) : Colors.transparent, width: 1.5)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 7,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _profileCard(String name, String role, String category,
      Color catColor, String distance, IconData catIcon,
      double progress, double imageH) {
    final floatY = sin(_floatCtrl.value * pi) * 2;

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
              // Avatar area
              SizedBox(
                height: imageH.toDouble(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            catColor.withValues(alpha: 0.6),
                            catColor.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(name.substring(0, 1),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 24,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    // Category badge
                    Positioned(top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: catColor.withValues(alpha: 0.85),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 6, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(category, style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 5.5,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    // Connect button
                    Positioned(top: 4, right: 4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF007AFF),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: 9),
                      ),
                    ),
                  ],
                ),
              ),
              // Info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
                color: Colors.black.withValues(alpha: 0.65),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 7.5,
                        fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(role, style: TextStyle(fontFamily: 'Poppins', fontSize: 6,
                        color: Colors.grey[400])),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 6, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(distance, style: TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
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
// PAGE 3: Smart Connect - Filtered matching
// ============================================================
class NetworkingSmartConnectIllustration extends StatefulWidget {
  final bool isActive;
  const NetworkingSmartConnectIllustration({super.key, required this.isActive});
  @override
  State<NetworkingSmartConnectIllustration> createState() =>
      _NetworkingSmartConnectIllustrationState();
}

class _NetworkingSmartConnectIllustrationState
    extends State<NetworkingSmartConnectIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000));
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(NetworkingSmartConnectIllustration old) {
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
      Curves.easeOutCubic.transform(
          ((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: const Color(0xFFFFA502),
          child: Column(
            children: [
              // App bar (no bottom border - tabs below)
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
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF007AFF).withValues(alpha: 0.9),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 12),
                        ),
                        const Spacer(),
                        const Text('Networking',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        const SizedBox(width: 22),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab bar: Discover All | Smart Connect | My Network
              Opacity(
                opacity: _f(0.05, 0.15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      _tab('Around me', false),
                      _tab('My Network', true),
                      _tab('Request', false),
                    ],
                  ),
                ),
              ),

              // Filter chips row
              Opacity(
                opacity: _f(0.08, 0.22),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('Professional', const Color(0xFF007AFF), true),
                        const SizedBox(width: 4),
                        _filterChip('Age: 25-35', const Color(0xFF00E676), true),
                        const SizedBox(width: 4),
                        _filterChip('Male', const Color(0xFF7C4DFF), false),
                        const SizedBox(width: 4),
                        _filterChip('< 5 km', const Color(0xFFFFA502), true),
                      ],
                    ),
                  ),
                ),
              ),

              // "Smart Match" header
              Opacity(
                opacity: _f(0.18, 0.3),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: const Color(0xFFFFA502).withValues(alpha: 0.8), size: 10),
                      const SizedBox(width: 4),
                      Text('Filtered Results',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8))),
                      const Spacer(),
                      Text('12 matches',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 6.5,
                              color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ),

              // Profile cards grid
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
                            _profileCard('Arjun M.', 'Software Engineer', 'Job Seekers',
                                const Color(0xFF007AFF), '0.3 km',
                                Icons.work_rounded, _f(0.22, 0.42), 75),
                            const SizedBox(height: 5),
                            _profileCard('Sanjay R.', 'Tech Lead', 'Freelancers',
                                const Color(0xFF7C4DFF), '2.5 km',
                                Icons.laptop_mac_rounded, _f(0.42, 0.62), 65),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Right column
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            _profileCard('Vikram S.', 'Product Manager', 'Mentors',
                                const Color(0xFF00B4D8), '1.8 km',
                                Icons.school_rounded, _f(0.32, 0.52), 75),
                            const SizedBox(height: 5),
                            _profileCard('Karan J.', 'DevOps Engineer', 'Remote',
                                const Color(0xFF00E676), '4.1 km',
                                Icons.cloud_rounded, _f(0.52, 0.72), 65),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Opacity(opacity: _f(0.0, 0.1), child: _bottomNav(3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 6.5,
              fontWeight: FontWeight.w500,
              color: active ? color : Colors.white.withValues(alpha: 0.6))),
          if (active) ...[
            const SizedBox(width: 3),
            Icon(Icons.check_circle, size: 7, color: color),
          ],
        ],
      ),
    );
  }

  Widget _tab(String label, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: active ? const Color(0xFF007AFF) : Colors.transparent, width: 1.5)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 7,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _profileCard(String name, String role, String category,
      Color catColor, String distance, IconData catIcon,
      double progress, double imageH) {
    final floatY = sin(_pulseCtrl.value * pi) * 2;

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
              // Avatar area
              SizedBox(
                height: imageH.toDouble(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            catColor.withValues(alpha: 0.6),
                            catColor.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(name.substring(0, 1),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 24,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    // Category badge
                    Positioned(top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: catColor.withValues(alpha: 0.85),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 6, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(category, style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 5.5,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    // Connect button
                    Positioned(top: 4, right: 4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF007AFF),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: 9),
                      ),
                    ),
                  ],
                ),
              ),
              // Info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
                color: Colors.black.withValues(alpha: 0.65),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 7.5,
                        fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(role, style: TextStyle(fontFamily: 'Poppins', fontSize: 6,
                        color: Colors.grey[400])),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 6, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(distance, style: TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
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
// PAGE 4: Connect & Chat - Connection requests + messaging
// ============================================================
class NetworkingConnectChatIllustration extends StatefulWidget {
  final bool isActive;
  const NetworkingConnectChatIllustration({super.key, required this.isActive});
  @override
  State<NetworkingConnectChatIllustration> createState() =>
      _NetworkingConnectChatIllustrationState();
}

class _NetworkingConnectChatIllustrationState
    extends State<NetworkingConnectChatIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000));
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _floatCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(NetworkingConnectChatIllustration old) {
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
      Curves.easeOutCubic.transform(
          ((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _floatCtrl]),
        builder: (context, _) => _PhoneFrame(
          glowColor: const Color(0xFF7C4DFF),
          child: Column(
            children: [
              // App bar (no bottom border - tabs below)
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
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF007AFF).withValues(alpha: 0.9),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 12),
                        ),
                        const Spacer(),
                        const Text('Networking',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        const SizedBox(width: 22),
                      ],
                    ),
                  ),
                ),
              ),

              // Tab bar: Discover All | Smart Connect | My Network
              Opacity(
                opacity: _f(0.05, 0.15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      _tab('Around me', false),
                      _tab('My Network', false),
                      _tab('Request', true),
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
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Search people...',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 7,
                                  color: Colors.white.withValues(alpha: 0.4))),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Profile cards grid
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
                            _profileCard('Neha S.', 'Data Scientist', 'Tech',
                                const Color(0xFF00B4D8), '1.5 km',
                                Icons.code_rounded, _f(0.15, 0.35), 75),
                            const SizedBox(height: 5),
                            _profileCard('Rohit G.', 'Startup Founder', 'Business',
                                const Color(0xFFFFA502), '2.0 km',
                                Icons.business_rounded, _f(0.4, 0.6), 65),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Right column
                      Expanded(
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            _profileCard('Priya M.', 'UI/UX Designer', 'Creative',
                                const Color(0xFF7C4DFF), '0.8 km',
                                Icons.palette_rounded, _f(0.25, 0.45), 75),
                            const SizedBox(height: 5),
                            _profileCard('Arjun M.', 'Software Engineer', 'Job Seekers',
                                const Color(0xFF007AFF), '3.5 km',
                                Icons.work_rounded, _f(0.5, 0.7), 65),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Opacity(opacity: _f(0.0, 0.1), child: _bottomNav(3)),
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
            color: active ? const Color(0xFF007AFF) : Colors.transparent, width: 1.5)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 7,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _profileCard(String name, String role, String category,
      Color catColor, String distance, IconData catIcon,
      double progress, double imageH) {
    final floatY = sin(_floatCtrl.value * pi) * 2;

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
              // Avatar area
              SizedBox(
                height: imageH.toDouble(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            catColor.withValues(alpha: 0.6),
                            catColor.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(name.substring(0, 1),
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 24,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                    // Category badge
                    Positioned(top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: catColor.withValues(alpha: 0.85),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 6, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(category, style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 5.5,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    // Connect button
                    Positioned(top: 4, right: 4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF007AFF),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white, size: 9),
                      ),
                    ),
                  ],
                ),
              ),
              // Info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
                color: Colors.black.withValues(alpha: 0.65),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 7.5,
                        fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(role, style: TextStyle(fontFamily: 'Poppins', fontSize: 6,
                        color: Colors.grey[400])),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(Icons.near_me, size: 6, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(distance, style: TextStyle(fontFamily: 'Poppins', fontSize: 5.5,
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
// PAGE 5: Ready to Network - Success with checkmark + confetti
// ============================================================
class NetworkingReadyIllustration extends StatefulWidget {
  final bool isActive;
  const NetworkingReadyIllustration({super.key, required this.isActive});
  @override
  State<NetworkingReadyIllustration> createState() =>
      _NetworkingReadyIllustrationState();
}

class _NetworkingReadyIllustrationState extends State<NetworkingReadyIllustration>
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
      color: [const Color(0xFF007AFF), const Color(0xFF7C4DFF),
              const Color(0xFF00E676), const Color(0xFFFFA502),
              const Color(0xFF00B4D8), const Color(0xFFFF6B8A)][i % 6],
      drift: (_random.nextDouble() - 0.5) * 0.3,
    ));
    if (widget.isActive) _start();
  }

  void _start() {
    _entryCtrl.forward(from: 0);
    _shimmerCtrl.repeat();
  }

  @override
  void didUpdateWidget(NetworkingReadyIllustration old) {
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
      Curves.easeOutCubic.transform(
          ((_entryCtrl.value - s) / (e - s)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _shimmerCtrl]),
        builder: (context, _) {
          final confP = _f(0.35, 0.7);
          return _PhoneFrame(
            glowColor: const Color(0xFF00E676),
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
                Positioned.fill(
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      // Icon
                      Opacity(
                        opacity: _f(0.4, 0.6),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              const Color(0xFF007AFF).withValues(alpha: 0.3),
                              const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                            ]),
                            border: Border.all(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.hub_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: _f(0.45, 0.65),
                        child: const Text('Ready to Network!',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                                fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: _f(0.5, 0.7),
                        child: Text('Create your profile and\nstart connecting',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 8,
                                color: AppColors.whiteAlpha(alpha: 0.6), height: 1.4)),
                      ),
                      const SizedBox(height: 14),
                      Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _check('Create networking profile', _f(0.6, 0.8)),
                            const SizedBox(height: 4),
                            _check('Discover people nearby', _f(0.65, 0.85)),
                            const SizedBox(height: 4),
                            _check('Smart filtered matching', _f(0.7, 0.9)),
                            const SizedBox(height: 4),
                            _check('Chat & voice calls', _f(0.75, 0.95)),
                          ],
                        ),
                      const Spacer(flex: 3),
                    ],
                  ),
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
            const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 11),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 8, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Shared helpers
// ============================================================

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
    const checkColor = Color(0xFF00E676);

    canvas.drawCircle(c, r, Paint()
      ..color = checkColor.withValues(alpha: glowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));

    if (circleProgress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          -pi / 2, 2 * pi * circleProgress, false,
          Paint()..color = checkColor..style = PaintingStyle.stroke
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
      canvas.drawPath(path, Paint()..color = checkColor
        ..style = PaintingStyle.stroke..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter o) =>
      circleProgress != o.circleProgress || checkProgress != o.checkProgress ||
      glowAlpha != o.glowAlpha;
}
