import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../../widgets/onboarding/networking_onboarding_illustrations.dart';
import 'create_networking_profile_screen.dart';

class NetworkingOnboardingScreen extends StatefulWidget {
  const NetworkingOnboardingScreen({super.key});

  @override
  State<NetworkingOnboardingScreen> createState() =>
      _NetworkingOnboardingScreenState();
}

class _NetworkingOnboardingScreenState
    extends State<NetworkingOnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  static const int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _getStarted() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CreateNetworkingProfileScreen(createdFrom: 'Networking'),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
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
                        Row(
                          children: [
                            const Icon(Icons.hub_rounded,
                                color: Color(0xFF007AFF), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Networking',
                              style: AppTextStyles.displaySmall.copyWith(
                                shadows: [
                                  Shadow(
                                    color: AppColors.darkOverlay(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
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

                  // Illustration area (swipeable)
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

                  // Page indicators
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 16),
                    child: _buildPageIndicators(),
                  ),

                  // Nav buttons or Get Started
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _currentPage == _totalPages - 1
                        ? _buildGetStartedButton()
                        : _buildNavButtons(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: switch (index) {
        0 => NetworkingCreateProfileIllustration(isActive: _currentPage == 0),
        1 => NetworkingDiscoverIllustration(isActive: _currentPage == 1),
        2 => NetworkingSmartConnectIllustration(isActive: _currentPage == 2),
        3 => NetworkingConnectChatIllustration(isActive: _currentPage == 3),
        4 => NetworkingReadyIllustration(isActive: _currentPage == 4),
        _ => const SizedBox(),
      },
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
                    colors: [Color(0xFF007AFF), Color(0xFF7C4DFF)],
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
                      color:
                          const Color(0xFF007AFF).withValues(alpha: 0.4),
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
                HapticFeedback.lightImpact();
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
                        color: AppColors.whiteAlpha(alpha: 0.8),
                        size: 16),
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
              HapticFeedback.lightImpact();
              _pageController.nextPage(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF007AFF), Color(0xFF0060D0)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF007AFF).withValues(alpha: 0.3),
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
            colors: [Color(0xFF007AFF), Color(0xFF0060D0)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Create Profile',
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
            const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
