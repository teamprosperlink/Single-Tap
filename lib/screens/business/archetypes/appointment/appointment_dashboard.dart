import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../models/business_model.dart';
import '../../../../models/appointment_model.dart';
import '../../../../models/service_model.dart';
import '../../../../models/business_category_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/app_components.dart';
import 'package:flutter/services.dart';
import '../../business_notifications_screen.dart';
import '../../business_analytics_screen.dart';
import '../../business_services_tab.dart';
import '../../appointments/appointment_form_screen.dart';
import '../../appointments/appointments_tab.dart';

/// Appointment Archetype Dashboard
/// For: Healthcare, Education, Real Estate, Legal, Home Services, Fitness, Pet Care, Wedding/Events, Professional
/// Features: Calendar-based booking, staff management, service offerings
class AppointmentDashboard extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const AppointmentDashboard({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<AppointmentDashboard> createState() => _AppointmentDashboardState();
}

class _AppointmentDashboardState extends State<AppointmentDashboard> {
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  bool _isLoading = true;
  int _todayAppointments = 0;
  int _upcomingAppointments = 0;
  int _totalServices = 0;
  double _todayRevenue = 0.0;
  List<AppointmentModel> _todaySchedule = [];
  List<ServiceModel> _popularServices = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadAppointmentStats(),
        _loadServiceStats(),
        _loadTodaySchedule(),
        _loadPopularServices(),
      ]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAppointmentStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));


    final todaySnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('dateTime', isLessThan: Timestamp.fromDate(todayEnd))
        .get();

    // Upcoming appointments (next 7 days)
    final upcomingSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .where('dateTime', isLessThan: Timestamp.fromDate(weekEnd))
        .get();

    double revenue = 0.0;
    for (var doc in todaySnapshot.docs) {
      final appointment = AppointmentModel.fromFirestore(doc);
      if (appointment.status == AppointmentStatus.completed ||
          appointment.status == AppointmentStatus.confirmed) {
        revenue += appointment.price ?? 0.0;
      }
    }

    if (mounted) {
      setState(() {
        _todayAppointments = todaySnapshot.size;
        _upcomingAppointments = upcomingSnapshot.size;
        _todayRevenue = revenue;
      });
    }
  }

  Future<void> _loadServiceStats() async {
    final servicesSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('services')
        .get();

    if (mounted) {
      setState(() {
        _totalServices = servicesSnapshot.size;
      });
    }
  }

  Future<void> _loadTodaySchedule() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final appointmentsSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('dateTime', isLessThan: Timestamp.fromDate(todayEnd))
        .orderBy('dateTime', descending: false)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _todaySchedule = appointmentsSnapshot.docs
            .map((doc) => AppointmentModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  Future<void> _loadPopularServices() async {
    final servicesSnapshot = await _firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('services')
        .orderBy('bookingCount', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _popularServices = servicesSnapshot.docs
            .map((doc) => ServiceModel.fromFirestore(doc))
            .toList();
      });
    }
  }

  String get _categoryDisplayName {
    switch (widget.business.category) {
      case BusinessCategory.healthcare:
        return 'Healthcare';
      case BusinessCategory.education:
        return 'Education';
      case BusinessCategory.realEstate:
        return 'Real Estate';
      case BusinessCategory.legal:
        return 'Legal Services';
      case BusinessCategory.homeServices:
        return 'Home Services';
      case BusinessCategory.fitness:
        return 'Fitness';
      case BusinessCategory.petServices:
        return 'Pet Services';
      case BusinessCategory.weddingEvents:
        return 'Wedding & Events';
      case BusinessCategory.professional:
        return 'Professional';
      default:
        return 'Appointments';
    }
  }

  IconData get _categoryIcon {
    switch (widget.business.category) {
      case BusinessCategory.healthcare:
        return Icons.medical_services;
      case BusinessCategory.education:
        return Icons.school;
      case BusinessCategory.realEstate:
        return Icons.apartment;
      case BusinessCategory.legal:
        return Icons.gavel;
      case BusinessCategory.homeServices:
        return Icons.home_repair_service;
      case BusinessCategory.fitness:
        return Icons.fitness_center;
      case BusinessCategory.petServices:
        return Icons.pets;
      case BusinessCategory.weddingEvents:
        return Icons.cake;
      case BusinessCategory.professional:
        return Icons.work;
      default:
        return Icons.calendar_today;
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

                      // Today's Schedule
                      _buildTodaySchedule(isDarkMode),
                      const SizedBox(height: 24),

                      // Popular Services
                      _buildPopularServices(isDarkMode),
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
      title: '$_categoryDisplayName Dashboard',
      subtitle: DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
      icon: _categoryIcon,
      gradientStart: AppTheme.appointmentBlue,
      gradientEnd: const Color(0xFF2563EB),
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
              icon: Icons.today,
              label: 'Today',
              value: _todayAppointments.toString(),
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.upcoming,
              label: 'Upcoming',
              value: _upcomingAppointments.toString(),
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.attach_money,
              label: 'Revenue Today',
              value: '\$${_todayRevenue.toStringAsFixed(0)}',
              color: AppTheme.statusSuccess,
              isDarkMode: isDarkMode,
            ),
            AppComponents.statsCard(
              icon: Icons.miscellaneous_services,
              label: 'Services',
              value: _totalServices.toString(),
              color: AppTheme.menuAmber,
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
              icon: Icons.add_circle,
              label: 'New Appointment',
              color: AppTheme.appointmentBlue,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(business: widget.business, onSave: (_) { _loadDashboardData(); widget.onRefresh(); })));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.calendar_month,
              label: 'View Calendar',
              color: AppTheme.portfolioPurple,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentsTab(business: widget.business, onRefresh: () { _loadDashboardData(); widget.onRefresh(); })));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.people,
              label: 'Manage Staff',
              color: AppTheme.retailGreen,
              isDarkMode: isDarkMode,
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff management will be available in a future update')));
              },
            ),
            AppComponents.actionButton(
              icon: Icons.analytics,
              label: 'Analytics',
              color: AppTheme.menuAmber,
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

  Widget _buildTodaySchedule(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Today\'s Schedule',
          isDarkMode: isDarkMode,
          actionLabel: 'View All',
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentsTab(business: widget.business, onRefresh: () { _loadDashboardData(); widget.onRefresh(); })));
          },
        ),
        const SizedBox(height: AppTheme.spacing12),
        if (_todaySchedule.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 48,
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No appointments today',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todaySchedule.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildAppointmentCard(_todaySchedule[index], isDarkMode);
            },
          ),
      ],
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment, bool isDarkMode) {
    Color statusColor;
    switch (appointment.status) {
      case AppointmentStatus.pending:
      case AppointmentStatus.confirmed:
        statusColor = AppTheme.appointmentBlue;
        break;
      case AppointmentStatus.inProgress:
        statusColor = AppTheme.portfolioPurple;
        break;
      case AppointmentStatus.completed:
        statusColor = AppTheme.statusSuccess;
        break;
      case AppointmentStatus.cancelled:
        statusColor = AppTheme.statusError;
        break;
      default:
        statusColor = Colors.grey;
    }

    return AppComponents.card(
      isDarkMode: isDarkMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(appointment.dateTime),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${appointment.duration} mins',
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
                  appointment.status.displayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appointment.customerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.medical_services,
                size: 16,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appointment.serviceName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
              Text(
                '\$${(appointment.price ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPopularServices(bool isDarkMode) {
    if (_popularServices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppComponents.sectionHeader(
          title: 'Popular Services',
          isDarkMode: isDarkMode,
          actionLabel: 'View All',
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessServicesTab(business: widget.business, onRefresh: widget.onRefresh)));
          },
        ),
        const SizedBox(height: AppTheme.spacing12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _popularServices.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing12),
          itemBuilder: (context, index) {
            final service = _popularServices[index];
            return _buildServiceCard(service, isDarkMode);
          },
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceModel service, bool isDarkMode) {
    return AppComponents.card(
      isDarkMode: isDarkMode,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medical_services,
              color: Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${service.duration} mins',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${service.bookingCount} bookings',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '\$${(service.price ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
