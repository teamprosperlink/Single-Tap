import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/business_model.dart';
import '../../../../models/portfolio_item_model.dart';
import '../../../../models/business_category_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/app_components.dart';
import 'package:flutter/services.dart';
import '../../business_notifications_screen.dart';
import '../../business_analytics_screen.dart';
import '../../gallery_screen.dart';

/// Portfolio Archetype Dashboard
/// For: Construction, Technology, Art & Creative, Entertainment, Transportation, Agriculture, Manufacturing
/// Features: Project showcase, quote requests, portfolio management
class PortfolioDashboard extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const PortfolioDashboard({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<PortfolioDashboard> createState() => _PortfolioDashboardState();
}

class _PortfolioDashboardState extends State<PortfolioDashboard> {
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  bool _isLoading = true;
  int _totalProjects = 0;
  int _pendingQuotes = 0;
  int _completedProjects = 0;
  double _totalRevenue = 0.0;
  List<PortfolioItemModel> _recentProjects = [];
  List<Map<String, dynamic>> _recentQuotes = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadProjectStats(),
        _loadQuoteStats(),
        _loadRecentProjects(),
        _loadRecentQuotes(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProjectStats() async {
    final projectsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('portfolio')
        .get();

    int completed = 0;
    double revenue = 0.0;

    for (var doc in projectsSnapshot.docs) {
      final project = PortfolioItemModel.fromFirestore(doc);
      if (project.status == 'completed') {
        completed++;
        revenue += project.budget ?? 0;
      }
    }

    if (mounted) {
      setState(() {
        _totalProjects = projectsSnapshot.size;
        _completedProjects = completed;
        _totalRevenue = revenue;
      });
    }
  }

  Future<void> _loadQuoteStats() async {
    final quotesSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('quote_requests')
        .where('status', isEqualTo: 'pending')
        .get();

    if (mounted) {
      setState(() {
        _pendingQuotes = quotesSnapshot.size;
      });
    }
  }

  Future<void> _loadRecentProjects() async {
    final projectsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('portfolio')
        .orderBy('createdAt', descending: true)
        .limit(6)
        .get();

    if (mounted) {
      setState(() {
        _recentProjects = projectsSnapshot.docs
            .map((doc) => PortfolioItemModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _loadRecentQuotes() async {
    final quotesSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('quote_requests')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _recentQuotes = quotesSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    }
  }

  String get _categoryDisplayName {
    switch (widget.business.category) {
      case BusinessCategory.construction:
        return 'Construction';
      case BusinessCategory.technology:
        return 'Technology';
      case BusinessCategory.artCreative:
        return 'Creative';
      case BusinessCategory.entertainment:
        return 'Entertainment';
      case BusinessCategory.transportation:
        return 'Transportation';
      case BusinessCategory.agriculture:
        return 'Agriculture';
      case BusinessCategory.manufacturing:
        return 'Manufacturing';
      default:
        return 'Portfolio';
    }
  }

  IconData get _categoryIcon {
    switch (widget.business.category) {
      case BusinessCategory.construction:
        return Icons.construction;
      case BusinessCategory.technology:
        return Icons.computer;
      case BusinessCategory.artCreative:
        return Icons.palette;
      case BusinessCategory.entertainment:
        return Icons.celebration;
      case BusinessCategory.transportation:
        return Icons.local_shipping;
      case BusinessCategory.agriculture:
        return Icons.agriculture;
      case BusinessCategory.manufacturing:
        return Icons.factory;
      default:
        return Icons.work;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDarkMode),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData();
          widget.onRefresh();
        },
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppTheme.cardColor(isDarkMode),
              elevation: 0,
              pinned: true,
              title: Text(
                widget.business.businessName,
                style: TextStyle(
                  color: AppTheme.textPrimary(isDarkMode),
                  fontWeight: FontWeight.bold,
                  fontSize: AppTheme.fontSizeLarge,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppTheme.textPrimary(isDarkMode),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessNotificationsScreen()));
                  },
                ),
              ],
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D67D)),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      _buildWelcomeSection(isDarkMode),
                      const SizedBox(height: 24),

                      // Stats Overview
                      _buildStatsOverview(isDarkMode),
                      const SizedBox(height: 24),

                      // Quick Actions
                      _buildQuickActions(isDarkMode),
                      const SizedBox(height: 24),

                      // Pending Quotes Alert
                      if (_pendingQuotes > 0) ...[
                        _buildPendingQuotesAlert(isDarkMode),
                        const SizedBox(height: 24),
                      ],

                      // Recent Projects Portfolio
                      _buildRecentProjects(isDarkMode),
                      const SizedBox(height: 24),

                      // Recent Quote Requests
                      _buildRecentQuotes(isDarkMode),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isDarkMode) {
    return AppComponents.gradientHeader(
      title: '$_categoryDisplayName Portfolio',
      subtitle: DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
      icon: _categoryIcon,
      gradientStart: AppTheme.portfolioPurple,
      gradientEnd: const Color(0xFF7C3AED),
    );
  }

  Widget _buildStatsOverview(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Overview',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: AppTheme.spacing12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacing12,
          crossAxisSpacing: AppTheme.spacing12,
          childAspectRatio: 1.5,
          children: [
            AppComponents.statsCard(
              icon: Icons.work,
              label: 'Total Projects',
              value: _totalProjects.toString(),
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.check_circle,
              label: 'Completed',
              value: _completedProjects.toString(),
              color: AppTheme.statusSuccess,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.request_quote,
              label: 'Pending Quotes',
              value: _pendingQuotes.toString(),
              color: _pendingQuotes > 0 ? AppTheme.statusWarning : AppTheme.statusSuccess,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.attach_money,
              label: 'Total Revenue',
              value: '\$${(_totalRevenue / 1000).toStringAsFixed(0)}K',
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Quick Actions',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: AppTheme.spacing12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacing12,
          crossAxisSpacing: AppTheme.spacing12,
          childAspectRatio: 2,
          children: [
            AppComponents.actionButton(
              icon: Icons.add_photo_alternate,
              label: 'Add Project',
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => GalleryScreen(business: widget.business)));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.request_quote,
              label: 'View Quotes',
              color: AppTheme.menuAmber,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote management will be available in a future update')));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.photo_library,
              label: 'Portfolio',
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => GalleryScreen(business: widget.business)));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.analytics,
              label: 'Analytics',
              color: AppTheme.retailGreen,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessAnalyticsScreen(business: widget.business)));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingQuotesAlert(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.request_quote,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Quote Requests',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_pendingQuotes requests waiting for your response',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote management will be available in a future update')));
            },
            child: const Text(
              'View',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjects(bool isDarkMode) {
    if (_recentProjects.isEmpty) {
      return _buildEmptyProjects(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Projects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => GalleryScreen(business: widget.business)));
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF00D67D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _recentProjects.length,
          itemBuilder: (context, index) {
            return _buildProjectCard(_recentProjects[index], isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildProjectCard(PortfolioItemModel project, bool isDarkMode) {
    Color statusColor;
    final status = project.status.toLowerCase();
    switch (status) {
      case 'in_progress':
        statusColor = const Color(0xFF3B82F6);
        break;
      case 'completed':
        statusColor = const Color(0xFF10B981);
        break;
      case 'upcoming':
        statusColor = const Color(0xFFF59E0B);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: project.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: project.images.first,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
                  )
                : Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.work, size: 40, color: Colors.grey),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    project.status.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProjects(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start building your portfolio',
              style: TextStyle(
                color: isDarkMode ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentQuotes(bool isDarkMode) {
    if (_recentQuotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Quote Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote management will be available in a future update')));
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF00D67D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentQuotes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final quote = _recentQuotes[index];
            return _buildQuoteCard(quote, isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote, bool isDarkMode) {
    final status = quote['status'] ?? 'pending';
    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'quoted':
        statusColor = const Color(0xFF3B82F6);
        break;
      case 'accepted':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = Colors.grey;
    }

    final createdAt = quote['createdAt'] != null
        ? (quote['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote['customerName'] ?? 'Customer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quote['serviceType'] ?? 'Service Request',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (quote['description'] != null) ...[
            const SizedBox(height: 12),
            Text(
              quote['description'],
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: isDarkMode ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, h:mm a').format(createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
              if (quote['estimatedBudget'] != null) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.attach_money,
                  size: 14,
                  color: isDarkMode ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  '\$${quote['estimatedBudget']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
