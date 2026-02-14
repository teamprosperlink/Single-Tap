/// Art & Creative portfolio dashboard for artwork showcase and commission tracking
library;

import 'package:flutter/material.dart';
import 'package:supper/services/firebase_provider.dart';
import 'package:supper/res/config/app_colors.dart';
import 'package:supper/widgets/business/coming_soon_widgets.dart';

class ArtPortfolioDashboard extends StatefulWidget {
  final String businessId;

  const ArtPortfolioDashboard({super.key, required this.businessId});

  @override
  State<ArtPortfolioDashboard> createState() => _ArtPortfolioDashboardState();
}

class _ArtPortfolioDashboardState extends State<ArtPortfolioDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadArtStats();
  }

  Future<void> _loadArtStats() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseProvider.firestore;

      // Get artworks
      final artworksSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('artworks')
          .get();

      int totalArtworks = artworksSnapshot.docs.length;
      int availableForSale = artworksSnapshot.docs
          .where((doc) => (doc.data()['isAvailable'] as bool? ?? false))
          .length;

      // Get commissions
      final commissionsSnapshot = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('commissions')
          .get();

      int totalCommissions = commissionsSnapshot.docs.length;
      int pendingCommissions = commissionsSnapshot.docs
          .where((doc) => (doc.data()['status'] as String? ?? '') == 'pending')
          .length;
      int inProgressCommissions = commissionsSnapshot.docs
          .where(
            (doc) => (doc.data()['status'] as String? ?? '') == 'in_progress',
          )
          .length;

      double totalRevenue = 0;
      for (var doc in commissionsSnapshot.docs) {
        if (doc.data()['status'] == 'completed') {
          final price = doc.data()['price'] as num? ?? 0;
          totalRevenue += price;
        }
      }

      // Get portfolio views (from business document)
      final businessDoc = await firestore
          .collection('businesses')
          .doc(widget.businessId)
          .get();

      int portfolioViews = businessDoc.data()?['views'] ?? 0;

      setState(() {
        _stats = {
          'totalArtworks': totalArtworks,
          'availableForSale': availableForSale,
          'totalCommissions': totalCommissions,
          'pendingCommissions': pendingCommissions,
          'inProgressCommissions': inProgressCommissions,
          'totalRevenue': totalRevenue,
          'portfolioViews': portfolioViews,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading art stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadArtStats,
      color: AppColors.secondary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Art Portfolio Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Showcase your work and manage commissions',
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
                  title: 'Total Artworks',
                  value: _stats['totalArtworks'].toString(),
                  icon: Icons.palette,
                  color: AppColors.secondary,
                  subtitle: '${_stats['availableForSale']} for sale',
                ),
                _buildStatCard(
                  title: 'Commission Requests',
                  value: _stats['pendingCommissions'].toString(),
                  icon: Icons.request_quote,
                  color: AppColors.warning,
                  subtitle: '${_stats['inProgressCommissions']} in progress',
                ),
                _buildStatCard(
                  title: 'Portfolio Views',
                  value: _stats['portfolioViews'].toString(),
                  icon: Icons.visibility,
                  color: AppColors.iosBlue,
                  subtitle: 'Total impressions',
                ),
                _buildStatCard(
                  title: 'Total Revenue',
                  value:
                      '\$${(_stats['totalRevenue'] as num).toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                  color: AppColors.success,
                  subtitle: 'From sales',
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
                  label: 'Upload Artwork',
                  icon: Icons.add_photo_alternate,
                  color: AppColors.secondary,
                  onTap: () => showComingSoonDialog(context, 'uploadArtwork'),
                ),
                _buildQuickActionChip(
                  label: 'View Commissions',
                  icon: Icons.work,
                  color: AppColors.warning,
                  onTap: () => showComingSoonDialog(context, 'viewCommissions'),
                ),
                _buildQuickActionChip(
                  label: 'Schedule Exhibition',
                  icon: Icons.event,
                  color: AppColors.iosBlue,
                  onTap: () =>
                      showComingSoonDialog(context, 'scheduleExhibition'),
                ),
                _buildQuickActionChip(
                  label: 'Update Portfolio',
                  icon: Icons.edit,
                  color: AppColors.success,
                  onTap: () => showComingSoonDialog(context, 'updatePortfolio'),
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
