import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/service_model.dart';
import '../../models/portfolio_item_model.dart';
import '../../services/professional_service.dart';
import '../../services/inquiry_service.dart';
import '../../widgets/professional/service_card.dart';
import '../../widgets/professional/portfolio_card.dart';
import '../../widgets/professional/add_service_sheet.dart';
import '../../widgets/professional/add_portfolio_sheet.dart';
import 'service_detail_screen.dart';
import 'portfolio_detail_screen.dart';
import 'inquiries_screen.dart';

/// Tab-based dashboard for managing professional profile, services, and portfolio
class ProfessionalDashboardScreen extends ConsumerStatefulWidget {
  const ProfessionalDashboardScreen({super.key});

  @override
  ConsumerState<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends ConsumerState<ProfessionalDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfessionalService _professionalService = ProfessionalService();
  final InquiryService _inquiryService = InquiryService();

  // Statistics
  Map<String, dynamic> _stats = {
    'services': 0,
    'activeServices': 0,
    'portfolio': 0,
    'views': 0,
    'inquiries': 0,
  };

  int _pendingInquiries = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
    _loadPendingInquiries();
  }

  Future<void> _loadPendingInquiries() async {
    final count = await _inquiryService.getPendingCount();
    if (mounted) {
      setState(() => _pendingInquiries = count);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _professionalService.getProfessionalStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Custom App Bar
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderBackground(isDarkMode),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // Inquiries button with badge
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.mail_outline,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InquiriesScreen(),
                          ),
                        ).then((_) => _loadPendingInquiries());
                      },
                    ),
                    if (_pendingInquiries > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00D67D),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _pendingInquiries > 9 ? '9+' : '$_pendingInquiries',
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
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  onPressed: () {
                    // TODO: Navigate to professional settings
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF00D67D),
                    unselectedLabelColor:
                        isDarkMode ? Colors.white54 : Colors.grey[600],
                    indicatorColor: const Color(0xFF00D67D),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Services'),
                      Tab(text: 'Portfolio'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(isDarkMode),
            _buildServicesTab(isDarkMode),
            _buildPortfolioTab(isDarkMode),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(isDarkMode),
    );
  }

  Widget _buildHeaderBackground(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF2D2D44),
                  const Color(0xFF1A1A2E),
                ]
              : [
                  const Color(0xFF00D67D).withValues(alpha: 0.1),
                  Colors.white,
                ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'Professional Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your services and portfolio',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF00D67D),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid
            _buildStatsGrid(isDarkMode),

            const SizedBox(height: 24),

            // Quick Actions
            _buildSectionTitle('Quick Actions', isDarkMode),
            const SizedBox(height: 12),
            _buildQuickActions(isDarkMode),

            const SizedBox(height: 24),

            // Recent Activity (placeholder)
            _buildSectionTitle('Recent Activity', isDarkMode),
            const SizedBox(height: 12),
            _buildRecentActivity(isDarkMode),

            const SizedBox(height: 24),

            // Tips Card
            _buildTipsCard(isDarkMode),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isDarkMode) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Services',
          '${_stats['services'] ?? 0}',
          Icons.work_outline,
          const Color(0xFF00D67D),
          isDarkMode,
        ),
        _buildStatCard(
          'Active',
          '${_stats['activeServices'] ?? 0}',
          Icons.play_circle_outline,
          Colors.blue,
          isDarkMode,
        ),
        _buildStatCard(
          'Portfolio Items',
          '${_stats['portfolio'] ?? 0}',
          Icons.photo_library_outlined,
          Colors.purple,
          isDarkMode,
        ),
        _buildStatCard(
          'Total Views',
          '${_stats['views'] ?? 0}',
          Icons.visibility_outlined,
          Colors.orange,
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.add_box_outlined,
            label: 'Add Service',
            color: const Color(0xFF00D67D),
            isDarkMode: isDarkMode,
            onTap: () => _showAddServiceSheet(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Add Portfolio',
            color: Colors.purple,
            isDarkMode: isDarkMode,
            onTap: () => _showAddPortfolioSheet(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(bool isDarkMode) {
    // Placeholder for recent activity
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your inquiries and views will appear here',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D67D).withValues(alpha: 0.15),
            const Color(0xFF00D67D).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D67D).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Color(0xFF00D67D),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Tips to get more clients',
                style: TextStyle(
                  color: Color(0xFF00D67D),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem('Add high-quality images to your services'),
          _buildTipItem('Build a diverse portfolio showcasing your best work'),
          _buildTipItem('Set competitive pricing for your services'),
          _buildTipItem('Respond quickly to inquiries'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF00D67D),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab(bool isDarkMode) {
    return StreamBuilder<List<ServiceModel>>(
      stream: _professionalService.watchMyServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        final services = snapshot.data ?? [];

        if (services.isEmpty) {
          return EmptyServicesWidget(
            onAdd: _showAddServiceSheet,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // StreamBuilder handles refresh automatically
          },
          color: const Color(0xFF00D67D),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return ServiceCard(
                service: service,
                onTap: () => _showServiceDetails(service),
                onEdit: () => _showEditServiceSheet(service),
                onDelete: () => _confirmDeleteService(service),
                onToggleActive: () => _toggleServiceActive(service),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPortfolioTab(bool isDarkMode) {
    return StreamBuilder<List<PortfolioItemModel>>(
      stream: _professionalService.watchMyPortfolio(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return EmptyPortfolioWidget(
            onAdd: _showAddPortfolioSheet,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // StreamBuilder handles refresh automatically
          },
          color: const Color(0xFF00D67D),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return PortfolioCard(
                item: item,
                onTap: () => _showPortfolioDetails(item),
                onEdit: () => _showEditPortfolioSheet(item),
                onDelete: () => _confirmDeletePortfolio(item),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFAB(bool isDarkMode) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.lightImpact();
        _showAddOptions();
      },
      backgroundColor: const Color(0xFF00D67D),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Add New'),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF2D2D44).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Add New',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildOptionTile(
                      icon: Icons.work_outline,
                      title: 'Add Service',
                      subtitle: 'Create a new service offering',
                      color: const Color(0xFF00D67D),
                      isDarkMode: isDarkMode,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddServiceSheet();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildOptionTile(
                      icon: Icons.photo_library_outlined,
                      title: 'Add Portfolio Item',
                      subtitle: 'Showcase your work',
                      color: Colors.purple,
                      isDarkMode: isDarkMode,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddPortfolioSheet();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  // Service actions
  void _showAddServiceSheet() {
    AddServiceSheet.show(
      context,
      onSave: (service) async {
        final id = await _professionalService.createService(service);
        if (id != null) {
          _loadStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Service created successfully')),
            );
          }
        }
      },
    );
  }

  void _showEditServiceSheet(ServiceModel service) {
    AddServiceSheet.show(
      context,
      existingService: service,
      onSave: (updatedService) async {
        final success =
            await _professionalService.updateService(service.id, updatedService);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service updated successfully')),
          );
        }
      },
    );
  }

  void _showServiceDetails(ServiceModel service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(service: service),
      ),
    );
  }

  void _confirmDeleteService(ServiceModel service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Service?'),
        content: Text(
          'Are you sure you want to delete "${service.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await _professionalService.deleteService(service.id);
              if (success && mounted) {
                _loadStats();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Service deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleServiceActive(ServiceModel service) async {
    final success = await _professionalService.toggleServiceActive(
      service.id,
      !service.isActive,
    );
    if (success) {
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              service.isActive ? 'Service paused' : 'Service activated',
            ),
          ),
        );
      }
    }
  }

  // Portfolio actions
  void _showAddPortfolioSheet() {
    AddPortfolioSheet.show(
      context,
      onSave: (item) async {
        final id = await _professionalService.createPortfolioItem(item);
        if (id != null) {
          _loadStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Portfolio item added')),
            );
          }
        }
      },
    );
  }

  void _showEditPortfolioSheet(PortfolioItemModel item) {
    AddPortfolioSheet.show(
      context,
      existingItem: item,
      onSave: (updatedItem) async {
        final success =
            await _professionalService.updatePortfolioItem(item.id, updatedItem);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Portfolio item updated')),
          );
        }
      },
    );
  }

  void _showPortfolioDetails(PortfolioItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioDetailScreen(item: item),
      ),
    );
  }

  void _confirmDeletePortfolio(PortfolioItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Portfolio Item?'),
        content: Text(
          'Are you sure you want to delete "${item.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await _professionalService.deletePortfolioItem(item.id);
              if (success && mounted) {
                _loadStats();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Portfolio item deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
