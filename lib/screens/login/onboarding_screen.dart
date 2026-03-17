import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:single_tap/screens/login/choose_account_type_screen.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../widgets/onboarding/onboarding_illustrations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _contentAnimCtrl;
  int _currentPage = 0;

  static const int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _contentAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentAnimCtrl.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const ChooseAccountTypeScreen()),
    );
  }

  void _onPageChanged(int page) {
    _contentAnimCtrl.forward(from: 0);
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    // Responsive vertical padding for top bar
    final topBarVPad = screenH < 700 ? 8.0 : 16.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.splashGradient,
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Top bar with title and skip
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 24, vertical: topBarVPad),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Single Tap',
                          style: AppTextStyles.displaySmall.copyWith(
                            shadows: [
                              Shadow(
                                color: AppColors.darkOverlay(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        if (_currentPage < _totalPages - 1)
                          GestureDetector(
                            onTap: _getStarted,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassBackgroundDark(
                                        alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          AppColors.glassBorder(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color:
                                          AppColors.whiteAlpha(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Illustration area (swipeable) - takes remaining space
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _totalPages,
                      itemBuilder: (context, index) {
                        return _buildIllustration(index);
                      },
                    ),
                  ),

                  // Bottom content card
                  _buildBottomCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(int index) {
    // Wrap each illustration with padding
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: switch (index) {
        0 => WelcomeIllustration(isActive: _currentPage == 0),
        1 => MatchingIllustration(isActive: _currentPage == 1),
        2 => MessagingIllustration(isActive: _currentPage == 2),
        3 => NearbyIllustration(isActive: _currentPage == 3),
        4 => GetStartedIllustration(isActive: _currentPage == 4),
        _ => const SizedBox(),
      },
    );
  }

  Widget _buildBottomCard() {
    final isLast = _currentPage == _totalPages - 1;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.glassBackgroundDark(alpha: 0.12),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: AnimatedBuilder(
            animation: _contentAnimCtrl,
            builder: (context, _) {
              final opacity = _contentAnimCtrl.value.clamp(0.0, 1.0);
              final slideY = (1 - _contentAnimCtrl.value) * 15;

              return Transform.translate(
                offset: Offset(0, slideY),
                child: Opacity(
                  opacity: opacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page indicators
                      _buildPageIndicators(),
                      const SizedBox(height: 20),

                      // Bottom action - Nav buttons or Get Started
                      if (isLast)
                        _buildGetStartedButton()
                      else
                        _buildNavButtons(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  )
                : null,
            color: isActive
                ? null
                : AppColors.glassBorder(alpha: 0.3),
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : AppColors.glassBorder(alpha: 0.4),
              width: 0.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildNavButtons() {
    return Row(
      children: [
        // Previous button (hidden on first page)
        if (_currentPage > 0)
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.glassBorder(alpha: 0.4),
                  ),
                  color: AppColors.glassBackgroundDark(alpha: 0.15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.whiteAlpha(alpha: 0.8), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Previous',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.whiteAlpha(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          const Spacer(),

        const SizedBox(width: 8),

        // Next button
        Expanded(
          child: GestureDetector(
            onTap: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGetStartedButton() {
    return GestureDetector(
      onTap: _getStarted,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: AppColors.darkOverlay(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.rocket_launch,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
