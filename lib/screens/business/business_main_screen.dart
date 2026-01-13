import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/business_category_config.dart';
import '../../models/business_model.dart';
import '../../models/conversation_model.dart';
import '../../services/business_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat services/conversation_service.dart';
import '../login/choose_account_type_screen.dart';
import 'business_home_tab.dart';
import 'business_messages_tab.dart';
import 'business_public_profile_tab.dart';
import 'business_setup_screen.dart';
import 'category_content_tab.dart';

/// Main business screen with category-aware bottom navigation
///
/// Navigation structure:
/// - Home: Dashboard with stats and quick actions
/// - [Category-specific]: Products/Menu/Rooms/Services based on business type
/// - Chat: Messages and conversations
/// - Profile: Public profile view
class BusinessMainScreen extends ConsumerStatefulWidget {
  const BusinessMainScreen({super.key});

  @override
  ConsumerState<BusinessMainScreen> createState() => _BusinessMainScreenState();
}

class _BusinessMainScreenState extends ConsumerState<BusinessMainScreen> {
  int _currentIndex = 0;
  final BusinessService _businessService = BusinessService();
  final ConversationService _conversationService = ConversationService();
  BusinessModel? _business;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    setState(() => _isLoading = true);

    final business = await _businessService.getMyBusiness();
    if (mounted) {
      setState(() {
        _business = business;
        _isLoading = false;
      });
    }
  }

  void _refreshBusiness() {
    _loadBusinessData();
  }

  /// Get the business category from business type
  BusinessCategory get _category {
    return BusinessCategoryExtension.fromBusinessType(_business?.businessType);
  }

  /// Build navigation items based on business category
  List<_NavItem> _buildNavItems() {
    final category = _category;

    return [
      // Home tab - always first
      const _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      // Category-specific content tab
      _NavItem(
        icon: category.contentTabIcon,
        activeIcon: category.contentTabActiveIcon,
        label: category.contentTabLabel,
      ),
      // Chat tab
      const _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chat',
      ),
      // Profile tab
      const _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D67D)),
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: _EmptyBusinessWidget(
            onSetup: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessSetupScreen(
                    onComplete: () {
                      Navigator.pop(context);
                      _loadBusinessData();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final navItems = _buildNavItems();

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home Tab
          BusinessHomeTab(
            business: _business!,
            category: _category,
            onRefresh: _refreshBusiness,
            onSwitchTab: (index) => setState(() => _currentIndex = index),
          ),
          // Category Content Tab (Products/Menu/Rooms/Services)
          CategoryContentTab(
            business: _business!,
            category: _category,
            onRefresh: _refreshBusiness,
          ),
          // Messages Tab
          BusinessMessagesTab(
            business: _business!,
          ),
          // Profile Tab (Public Profile View)
          BusinessPublicProfileTab(
            business: _business!,
            onRefresh: _refreshBusiness,
            onLogout: () async {
              final navigator = Navigator.of(context);
              await AuthService().signOut();
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const ChooseAccountTypeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(isDarkMode, navItems),
    );
  }

  Widget _buildBottomNavBar(bool isDarkMode, List<_NavItem> navItems) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _currentIndex == index;

              // Home tab (index 0) gets active status indicator
              if (index == 0 && _business != null) {
                return _buildHomeNavItem(item, isSelected, isDarkMode);
              }

              // Messages tab (index 2) gets unread badge
              if (index == 2 && _business != null) {
                return _buildMessagesNavItem(item, isSelected, isDarkMode);
              }

              return _NavBarItem(
                icon: isSelected ? item.activeIcon : item.icon,
                label: item.label,
                isSelected: isSelected,
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentIndex = index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Home nav item with active status indicator
  Widget _buildHomeNavItem(_NavItem item, bool isSelected, bool isDarkMode) {
    final isOnline = _business?.isOnline ?? false;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = 0);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 24,
                  color: isSelected
                      ? const Color(0xFF00D67D)
                      : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                ),
                // Online status indicator
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF00D67D) : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white54 : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesNavItem(_NavItem item, bool isSelected, bool isDarkMode) {
    return StreamBuilder<List<ConversationModel>>(
      stream: _conversationService.getBusinessConversations(_business!.id),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (var conv in snapshot.data!) {
            unreadCount += conv.getUnreadCount(_business!.userId);
          }
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = 2);
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 24,
                      color: isSelected
                          ? const Color(0xFF00D67D)
                          : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF00D67D)
                        : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF00D67D)
                  : (isDarkMode ? Colors.white54 : Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white54 : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBusinessWidget extends StatelessWidget {
  final VoidCallback onSetup;

  const _EmptyBusinessWidget({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_rounded,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Business Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your business profile to start showcasing your products and services to customers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_business),
            label: const Text(
              'Create Business Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
