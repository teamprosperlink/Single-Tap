import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/main_navigation_screen.dart';
import '../../widgets/app_background.dart';

class UpgradePlanScreen extends StatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPersonalPlan;
  String? _selectedBusinessPlan;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
            });
          },
        ),
        title: const Text(
          'Upgrade your plan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Personal'),
                Tab(text: 'Business'),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        showParticles: true,
        overlayOpacity: 0.7,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPersonalPlans(),
                    _buildBusinessPlans(),
                  ],
                ),
              ),
              // Continue Button
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    // Check if any plan is selected based on current tab
    final isPersonalTab = _tabController.index == 0;
    final isSelected = isPersonalTab
        ? _selectedPersonalPlan != null
        : _selectedBusinessPlan != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: isSelected
            ? () {
                HapticFeedback.lightImpact();
                // Handle continue action
                final selectedPlan = isPersonalTab
                    ? _selectedPersonalPlan
                    : _selectedBusinessPlan;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected plan: $selectedPlan'),
                    backgroundColor: const Color(0xFF6366f1),
                  ),
                );
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366f1)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366f1)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            'Continue',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalPlans() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildPlanCard(
          name: 'Free',
          price: '0',
          period: 'INR / month',
          description: 'See what AI can do',
          buttonText: 'Your current plan',
          isCurrentPlan: true,
          isSelected: _selectedPersonalPlan == 'Free',
          onTap: () => setState(() => _selectedPersonalPlan = 'Free'),
          features: [
            _PlanFeature(Icons.auto_awesome_outlined, 'Get simple explanations'),
            _PlanFeature(Icons.chat_bubble_outline, 'Have short chats for common questions'),
            _PlanFeature(Icons.image_outlined, 'Try out image generation'),
            _PlanFeature(Icons.memory_outlined, 'Save limited memory and context'),
          ],
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          name: 'Go',
          price: '399',
          period: 'INR / month (inclusive of GST)',
          description: 'Keep chatting with expanded access',
          buttonText: 'Upgrade to Go',
          buttonColor: const Color(0xFF1a1a2e),
          isSelected: _selectedPersonalPlan == 'Go',
          onTap: () => setState(() => _selectedPersonalPlan = 'Go'),
          features: [
            _PlanFeature(Icons.auto_awesome, 'Explore topics in depth'),
            _PlanFeature(Icons.upload_file_outlined, 'Chat longer and upload more content'),
            _PlanFeature(Icons.photo_library_outlined, 'Make more images for your projects'),
            _PlanFeature(Icons.psychology_outlined, 'Get more memory for smarter replies'),
            _PlanFeature(Icons.task_alt_outlined, 'Get help with planning and tasks'),
            _PlanFeature(Icons.apps_outlined, 'Explore projects, tasks, and custom SingleTaps'),
          ],
          footerText: 'This plan may include ads.',
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          name: 'Plus',
          price: '1,999',
          period: 'INR / month (inclusive of GST)',
          description: 'Unlock the full experience',
          buttonText: 'Upgrade to Plus',
          isPopular: true,
        
          isSelected: _selectedPersonalPlan == 'Plus',
          onTap: () => setState(() => _selectedPersonalPlan = 'Plus'),
          features: [
            _PlanFeature(Icons.lightbulb_outlined, 'Solve complex problems'),
            _PlanFeature(Icons.history_outlined, 'Have long chats over multiple sessions'),
            _PlanFeature(Icons.speed_outlined, 'Create more images, faster'),
            _PlanFeature(Icons.bookmark_outlined, 'Remember goals and past conversations'),
            _PlanFeature(Icons.travel_explore_outlined, 'Plan travel and tasks with agent mode'),
            _PlanFeature(Icons.folder_outlined, 'Organize projects and customize SingleTaps'),
            _PlanFeature(Icons.videocam_outlined, 'Produce and share videos on Sora'),
            _PlanFeature(Icons.code_outlined, 'Write code and build apps with Codex'),
          ],
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          name: 'Pro',
          price: '19,900',
          period: 'INR / month (inclusive of GST)',
          description: 'Maximize your productivity',
          buttonText: 'Upgrade to Pro',
          buttonColor: const Color(0xFF6366f1),
          isSelected: _selectedPersonalPlan == 'Pro',
          onTap: () => setState(() => _selectedPersonalPlan = 'Pro'),
          features: [
            _PlanFeature(Icons.rocket_launch_outlined, 'Master advanced tasks and topics'),
            _PlanFeature(Icons.all_inclusive_outlined, 'Tackle big projects with unlimited SingleTap-5.2'),
            _PlanFeature(Icons.high_quality_outlined, 'Create high-quality images at any scale'),
            _PlanFeature(Icons.storage_outlined, 'Keep full context with maximum memory'),
            _PlanFeature(Icons.smart_toy_outlined, 'Run research and plan tasks with agents'),
            _PlanFeature(Icons.auto_mode_outlined, 'Scale your projects and automate workflows'),
            _PlanFeature(Icons.movie_creation_outlined, 'Expand your limits with Sora video creation'),
            _PlanFeature(Icons.terminal_outlined, 'Deploy code faster with Codex'),
            _PlanFeature(Icons.science_outlined, 'Get early access to experimental features'),
          ],
          footerText: 'Unlimited subject to abuse guardrails.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBusinessPlans() {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildPlanCard(
          name: 'Free',
          price: '0',
          period: 'INR / month',
          description: 'See what AI can do',
          buttonText: 'Your current plan',
          isCurrentPlan: true,
          isSelected: _selectedBusinessPlan == 'Free',
          onTap: () => setState(() => _selectedBusinessPlan = 'Free'),
          features: [
            _PlanFeature(Icons.auto_awesome_outlined, 'Get simple explanations'),
            _PlanFeature(Icons.chat_bubble_outline, 'Have short chats for common questions'),
            _PlanFeature(Icons.image_outlined, 'Try out image generation'),
            _PlanFeature(Icons.memory_outlined, 'Save limited memory and context'),
          ],
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          name: 'Business',
          price: '2,599',
          period: 'INR / month (exclusive of GST)',
          description: 'Get more work done with AI for teams',
          buttonText: 'Upgrade to Business',
          isPopular: true,
          buttonColor: const Color(0xFF6366f1),
          isSelected: _selectedBusinessPlan == 'Business',
          onTap: () => setState(() => _selectedBusinessPlan = 'Business'),
          features: [
            _PlanFeature(Icons.analytics_outlined, 'Conduct professional analysis'),
            _PlanFeature(Icons.all_inclusive, 'Get unlimited messages with SingleTap-5'),
            _PlanFeature(Icons.auto_awesome, 'Produce images, videos, slides, & more'),
            _PlanFeature(Icons.security_outlined, 'Secure your space with SSO, MFA, & more'),
            _PlanFeature(Icons.privacy_tip_outlined, 'Protect privacy: data never used for training'),
            _PlanFeature(Icons.folder_shared_outlined, 'Share projects & custom SingleTaps'),
            _PlanFeature(Icons.integration_instructions_outlined, 'Integrate with SharePoint & other tools'),
            _PlanFeature(Icons.receipt_long_outlined, 'Simplify billing and user management'),
            _PlanFeature(Icons.mic_outlined, 'Capture meeting notes with transcription'),
            _PlanFeature(Icons.smart_toy_outlined, 'Deploy agents to code and research'),
          ],
          footerText: 'For 2+ users, billed annually.\nUnlimited subject to abuse guardrails.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    required String period,
    required String description,
    required String buttonText,
    required List<_PlanFeature> features,
    bool isCurrentPlan = false,
    bool isPopular = false,
    bool isSelected = false,
    Color? buttonColor,
    String? footerText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6366f1).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF6366f1).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
              buttonText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 99, 213, 241).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Color.fromARGB(255, 193, 193, 218),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  period,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 16),


          // Features
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  feature.icon,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )),

          // Footer text
          if (footerText != null) ...[
            const SizedBox(height: 8),
            Text(
              footerText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _PlanFeature {
  final IconData icon;
  final String text;

  _PlanFeature(this.icon, this.text);
}
