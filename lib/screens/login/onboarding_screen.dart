import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supper/screens/login/choose_account_type_screen.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _zoomController;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Supper',
      subtitle:
          'Your ultimate campus marketplace for buying, selling, and connecting with students',
      imagePath: AppAssets.logoPath,
      color: AppColors.lightBlueTint,
      gradient: [
        AppColors.lightBlueTint,
        AppColors.splashDark2,
      ],
    ),
    OnboardingPage(
      title: 'Find Anything',
      subtitle:
          'From textbooks to bikes, rooms to part-time jobs - everything you need on campus',
      imagePath: AppAssets.searchRequirementImage,
      color: AppColors.lightGreenTint,
      gradient: [
        AppColors.lightGreenTint,
        AppColors.splashDark2,
      ],
    ),
    OnboardingPage(
      title: 'Connect Instantly',
      subtitle:
          'Chat with verified students and make secure transactions in real-time',
      imagePath: AppAssets.searchAnnounceImage,
      color: AppColors.lightOrangeTint,
      gradient: [
        AppColors.lightOrangeTint,
        AppColors.splashDark2,
      ],
    ),
    OnboardingPage(
      title: 'Get Started',
      subtitle: 'Join thousands of students already using Supper every day',
      imagePath: AppAssets.searchDataImage,
      color: AppColors.lightPurpleTint,
      gradient: [
        AppColors.lightPurpleTint,
        AppColors.splashDark2,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);

    // Zoom animation controller
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ChooseAccountTypeScreen()),
    );
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Stack(
          children: [
            // Gradient Background - always visible immediately
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.splashGradient,
                ),
              ),
            ),

            // Image Background
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeBackgroundImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.splashGradient,
                    ),
                  );
                },
              ),
            ),

            // Dark overlay
            Positioned.fill(
              child: Container(color: AppColors.darkOverlay(alpha: 0.5)),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Supper',
                          style: AppTextStyles.displaySmall.copyWith(
                            shadows: [
                              Shadow(
                                color: AppColors.darkOverlay(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        if (_currentPage < 3)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.glassBackgroundDark(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.glassBorder(alpha: 0.3),
                                  ),
                                ),
                                child: GestureDetector(
                                  onTap: _getStarted,
                                  child: Text(
                                    'Skip',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: AppColors.whiteAlpha(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 3D Page View
                  Expanded(
                    flex: 2,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _build3DPage(_pages[index], index);
                      },
                    ),
                  ),

                  // Indicators
                  _buildPageIndicators(),

                  // Content
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        children: [
                          const Spacer(),
                          Text(
                            _pages[_currentPage].title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displayMedium.copyWith(
                              shadows: [
                                Shadow(
                                  color: AppColors.darkOverlay(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _pages[_currentPage].subtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyLargeReadable.copyWith(
                              color: AppColors.whiteAlpha(alpha: 0.8),
                            ),
                          ),
                          const Spacer(),

                          // Next/Get Started Button
                          if (_currentPage == 3)
                            _buildGetStartedButton()
                          else
                            _buildNextButton(),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DPage(OnboardingPage page, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double pageOffset = 0;
        if (_pageController.position.haveDimensions) {
          pageOffset = _pageController.page! - index;
        }

        double scale = (1 - (pageOffset.abs() * 0.3)).clamp(0.8, 1.0);
        double rotation = pageOffset * 0.5;
        double opacity = (1 - pageOffset.abs()).clamp(0.5, 1.0);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..scaleByDouble(scale, scale, scale, 1)
            ..rotateY(rotation),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    page.gradient[0].withValues(alpha: 0.3),
                    page.gradient[1].withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(
                  color: AppColors.glassBorder(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate circle size based on available space
                  // Account for padding (40px sides) and animation scale (1.05x max)
                  // Also account for bottom spacing (20px)
                  final availableWidth = constraints.maxWidth - 60; // 30px padding each side
                  final availableHeight = constraints.maxHeight - 40; // 20px top and bottom

                  // Use the smaller dimension to ensure circle fits
                  // Divide by 1.1 to account for animation scale
                  final maxSize = (availableWidth < availableHeight ? availableWidth : availableHeight) / 1.1;
                  final circleSize = maxSize.clamp(100.0, 220.0);

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BackgroundPatternPainter(color: page.color),
                        ),
                      ),
                      Center(
                        child: _build3DImage(page.imagePath, page.color, circleSize),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DImage(String imagePath, Color color, double size) {
    return AnimatedBuilder(
      animation: _zoomController,
      builder: (context, child) {
        final value = _zoomController.value;
        final scale = 0.95 + (value * 0.10); // 0.95 to 1.05

        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassBackgroundDark(alpha: 0.1),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(child: Image.asset(imagePath, fit: BoxFit.cover)),
          ),
        );
      },
    );
  }

  Widget _buildPageIndicators() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pages.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: _currentPage == index ? 30 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppColors.textPrimaryDark
                  : AppColors.glassBorder(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.glassBorder(alpha: 0.5)),
              boxShadow: _currentPage == index
                  ? [
                      BoxShadow(
                        color: AppColors.whiteAlpha(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: () {
        if (_currentPage < _pages.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassBackgroundDark(alpha: 0.15),
              border: Border.all(
                color: AppColors.glassBorder(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkOverlay(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: AppColors.textPrimaryDark,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return GestureDetector(
      onTap: _getStarted,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundDark(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.glassBorder(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkOverlay(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get Started',
                  style: AppTextStyles.titleMedium.copyWith(
                    shadows: [
                      Shadow(
                        color: AppColors.darkOverlay(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.rocket_launch, color: AppColors.textPrimaryDark, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color color;
  final List<Color> gradient;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.color,
    required this.gradient,
  });
}

class _BackgroundPatternPainter extends CustomPainter {
  final Color color;

  _BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw circles
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.3),
      40,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      60,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.8),
      30,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
