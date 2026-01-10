import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/business_model.dart';
import '../../widgets/business/glassmorphic_card.dart';

/// Analytics dashboard screen for business
class BusinessAnalyticsScreen extends StatefulWidget {
  final BusinessModel business;

  const BusinessAnalyticsScreen({
    super.key,
    required this.business,
  });

  @override
  State<BusinessAnalyticsScreen> createState() => _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends State<BusinessAnalyticsScreen> {
  // final BusinessService _businessService = BusinessService(); // TODO: Use for real data
  String _selectedPeriod = '7D';
  bool _isLoading = true;

  // Analytics data
  int _totalViews = 0;
  int _totalInquiries = 0;
  int _responseRate = 0;
  List<FlSpot> _viewsData = [];
  Map<String, int> _inquiriesByStatus = {};
  List<Map<String, dynamic>> _topServices = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    // For now, generate mock data based on business stats
    // In production, this would fetch from an analytics service
    await Future.delayed(const Duration(milliseconds: 500));

    final days = _selectedPeriod == '7D' ? 7 : (_selectedPeriod == '30D' ? 30 : 90);

    // Generate mock views data
    _viewsData = List.generate(days, (i) {
      final baseViews = 10 + (widget.business.totalOrders * 2);
      final variance = (i * 3 % 15) - 7;
      return FlSpot(i.toDouble(), (baseViews + variance).toDouble().clamp(0, 100));
    });

    // Calculate totals
    _totalViews = _viewsData.fold(0, (sum, spot) => sum + spot.y.toInt());
    _totalInquiries = widget.business.totalOrders;
    _responseRate = _totalInquiries > 0
        ? ((widget.business.completedOrders / _totalInquiries) * 100).toInt().clamp(0, 100)
        : 0;

    // Mock inquiries by status
    _inquiriesByStatus = {
      'New': widget.business.pendingOrders,
      'Responded': (widget.business.completedOrders * 0.4).toInt(),
      'Completed': widget.business.completedOrders,
      'Declined': (widget.business.totalOrders * 0.1).toInt(),
    };

    // Mock top services
    _topServices = [
      {'name': 'Service consultation', 'views': 45, 'inquiries': 12},
      {'name': 'Product inquiry', 'views': 32, 'inquiries': 8},
      {'name': 'General inquiry', 'views': 28, 'inquiries': 5},
    ];

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          _buildPeriodSelector(isDarkMode),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              color: const Color(0xFF00D67D),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(isDarkMode),
                    const SizedBox(height: 24),

                    // Views Chart
                    _buildSectionTitle('Profile Views', isDarkMode),
                    const SizedBox(height: 12),
                    _buildViewsChart(isDarkMode),
                    const SizedBox(height: 24),

                    // Inquiries Chart
                    _buildSectionTitle('Inquiries by Status', isDarkMode),
                    const SizedBox(height: 12),
                    _buildInquiriesChart(isDarkMode),
                    const SizedBox(height: 24),

                    // Top Services
                    _buildSectionTitle('Top Performing', isDarkMode),
                    const SizedBox(height: 12),
                    _buildTopServices(isDarkMode),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['7D', '30D', '90D'].map((period) {
                final isSelected = _selectedPeriod == period;
                return GestureDetector(
                  onTap: () {
                    if (_selectedPeriod != period) {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedPeriod = period);
                      _loadAnalytics();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF00D67D), Color(0xFF00B86B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      period,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white54 : Colors.grey[600]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassSummaryCard(
            title: 'Views',
            value: _formatNumber(_totalViews),
            icon: Icons.visibility_outlined,
            color: Colors.blue,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassSummaryCard(
            title: 'Inquiries',
            value: _totalInquiries.toString(),
            icon: Icons.inbox_outlined,
            color: const Color(0xFF00D67D),
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassSummaryCard(
            title: 'Response',
            value: '$_responseRate%',
            icon: Icons.trending_up,
            color: Colors.orange,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return GlassmorphicCard(
      showGlow: true,
      glowColor: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
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

  Widget _buildViewsChart(bool isDarkMode) {
    return GlassmorphicCard(
      showGlow: true,
      glowColor: const Color(0xFF00D67D),
      child: SizedBox(
        height: 200,
        child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDarkMode ? Colors.white12 : Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 20,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _selectedPeriod == '7D' ? 1 : (_selectedPeriod == '30D' ? 5 : 15),
                getTitlesWidget: (value, meta) {
                  if (_selectedPeriod == '7D') {
                    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    final index = value.toInt() % 7;
                    return Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                    );
                  }
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _viewsData,
              isCurved: true,
              color: const Color(0xFF00D67D),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D67D).withValues(alpha: 0.3),
                    const Color(0xFF00D67D).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: 0,
        ),
        ),
      ),
    );
  }

  Widget _buildInquiriesChart(bool isDarkMode) {
    final maxValue = _inquiriesByStatus.values.fold(0, (max, v) => v > max ? v : max);

    return GlassmorphicCard(
      child: Column(
        children: _inquiriesByStatus.entries.map((entry) {
          final color = _getStatusColor(entry.key);
          final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: 24,
                        width: MediaQuery.of(context).size.width * 0.5 * percentage,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: Text(
                    entry.value.toString(),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopServices(bool isDarkMode) {
    return GlassmorphicCard(
      padding: EdgeInsets.zero,
      child: _topServices.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up_outlined,
                      size: 40,
                      color: isDarkMode ? Colors.white24 : Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No data available yet',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topServices.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final service = _topServices[index];
                final rankColors = [Colors.amber, Colors.grey[400]!, Colors.brown[300]!];
                final rankColor = index < 3 ? rankColors[index] : const Color(0xFF00D67D);

                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rankColor.withValues(alpha: 0.3),
                          rankColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: rankColor.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: index < 3
                        ? Icon(
                            Icons.emoji_events,
                            color: rankColor,
                            size: 18,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rankColor,
                            ),
                          ),
                  ),
                  title: Text(
                    service['name'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 12,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${service['views']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 12,
                            color: Color(0xFF00D67D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${service['inquiries']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00D67D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.orange;
      case 'Responded':
        return Colors.blue;
      case 'Completed':
        return const Color(0xFF00D67D);
      case 'Declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
