/// Construction dashboard for project management, quotes, and material tracking
library;

import 'package:flutter/material.dart';
import 'package:supper/services/firebase_provider.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/widgets/business/coming_soon_widgets.dart';

class ConstructionDashboard extends StatefulWidget {
  final String businessId;

  const ConstructionDashboard({super.key, required this.businessId});

  @override
  State<ConstructionDashboard> createState() => _ConstructionDashboardState();
}

class _ConstructionDashboardState extends State<ConstructionDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadConstructionStats();
  }

  Future<void> _loadConstructionStats() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseProvider.firestore;

      // Get projects
      final projectsSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('projects')
          .get();

      int totalProjects = projectsSnapshot.docs.length;
      int activeProjects = projectsSnapshot.docs
          .where((doc) => (doc.data()['status'] as String? ?? '') == 'active')
          .length;
      int completedProjects = projectsSnapshot.docs
          .where(
            (doc) => (doc.data()['status'] as String? ?? '') == 'completed',
          )
          .length;

      double totalRevenue = 0;
      for (var doc in projectsSnapshot.docs) {
        if (doc.data()['status'] == 'completed') {
          final budget = doc.data()['budget'] as num? ?? 0;
          totalRevenue += budget;
        }
      }

      // Get quote requests
      final quotesSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('quotes')
          .get();

      int totalQuotes = quotesSnapshot.docs.length;
      int pendingQuotes = quotesSnapshot.docs
          .where((doc) => (doc.data()['status'] as String? ?? '') == 'pending')
          .length;

      // Get materials inventory
      final materialsSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('materials')
          .get();

      double materialsValue = 0;
      for (var doc in materialsSnapshot.docs) {
        final quantity = doc.data()['quantity'] as num? ?? 0;
        final unitPrice = doc.data()['unitPrice'] as num? ?? 0;
        materialsValue += (quantity * unitPrice);
      }

      setState(() {
        _stats = {
          'totalProjects': totalProjects,
          'activeProjects': activeProjects,
          'completedProjects': completedProjects,
          'totalQuotes': totalQuotes,
          'pendingQuotes': pendingQuotes,
          'totalRevenue': totalRevenue,
          'materialsValue': materialsValue,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading construction stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.warning),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConstructionStats,
      color: AppColors.warning,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Construction Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Project management and material tracking',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.iosGray),
            ),
            const SizedBox(height: 24),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  title: 'Active Projects',
                  value: _stats['activeProjects'].toString(),
                  icon: Icons.construction,
                  color: AppColors.warning,
                  subtitle: '${_stats['completedProjects']} completed',
                ),
                _buildStatCard(
                  title: 'Quote Requests',
                  value: _stats['pendingQuotes'].toString(),
                  icon: Icons.request_quote,
                  color: AppColors.iosBlue,
                  subtitle: '${_stats['totalQuotes']} total',
                ),
                _buildStatCard(
                  title: 'Total Revenue',
                  value:
                      '\$${(_stats['totalRevenue'] as num).toStringAsFixed(0)}',
                  icon: Icons.payments,
                  color: AppColors.success,
                  subtitle: 'From projects',
                ),
                _buildStatCard(
                  title: 'Materials Value',
                  value:
                      '\$${(_stats['materialsValue'] as num).toStringAsFixed(0)}',
                  icon: Icons.inventory,
                  color: AppColors.secondary,
                  subtitle: 'Current stock',
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildQuickActionChip(
                  label: 'New Project',
                  icon: Icons.add_box,
                  color: AppColors.warning,
                  onTap: () => showComingSoonDialog(context, 'newProject'),
                ),
                _buildQuickActionChip(
                  label: 'Quote Requests',
                  icon: Icons.description,
                  color: AppColors.iosBlue,
                  onTap: () => showComingSoonDialog(context, 'quoteRequests'),
                ),
                _buildQuickActionChip(
                  label: 'Material Orders',
                  icon: Icons.local_shipping,
                  color: AppColors.secondary,
                  onTap: () => showComingSoonDialog(context, 'materialOrders'),
                ),
                _buildQuickActionChip(
                  label: 'Worker Schedule',
                  icon: Icons.people,
                  color: AppColors.success,
                  onTap: () => showComingSoonDialog(context, 'workerSchedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightSecondary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackAlpha(alpha: 0.05),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.iosGray,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.iosGrayLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}
