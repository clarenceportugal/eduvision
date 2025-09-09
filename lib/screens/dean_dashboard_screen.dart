import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/dashboard_components.dart';
import '../utils/responsive_utils.dart';

class DeanDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DeanDashboardScreen({super.key, required this.userData});

  @override
  State<DeanDashboardScreen> createState() => _DeanDashboardScreenState();
}

class _DeanDashboardScreenState extends State<DeanDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = widget.userData['displayName'] ?? 'Dean';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(displayName),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(displayName),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildAcademicOverviewSection(),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildQuickActionsSection(),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildAcademicAnalyticsSection(),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildFacultyManagementSection(),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildProgramOverviewSection(),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildAcademicPerformanceSection(),
                      const SizedBox(
                        height: 170,
                      ), // Bottom padding for BottomNavigationBar
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String displayName) {
    return DashboardComponents.buildSliverAppBar(
      context: context,
      title: 'Academic Administration',
      subtitle: 'Welcome back,',
      icon: Icons.school_rounded,
      displayName: displayName,
    );
  }

  Widget _buildWelcomeSection(String displayName) {
    return DashboardComponents.buildWelcomeSection(
      context: context,
      title: 'Academic Leadership Center',
      description: 'You have comprehensive oversight of academic programs, faculty management, and institutional excellence across all departments.',
      icon: Icons.school_rounded,
    );
  }

  Widget _buildAcademicOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Academic Overview',
          icon: Icons.dashboard_rounded,
          subtitle: 'Key metrics and statistics',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ResponsiveUtils.getDashboardGridCrossAxisCount(context),
          crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context),
          mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context),
          childAspectRatio: ResponsiveUtils.getResponsiveCardAspectRatio(context),
          children: [
            DashboardComponents.buildSummaryCard(
              context: context,
              title: 'Total Students',
              value: '3,456',
              icon: Icons.people_rounded,
              color: Colors.blue,
              subtitle: 'Enrolled students',
            ),
            DashboardComponents.buildSummaryCard(
              context: context,
              title: 'Faculty Members',
              value: '234',
              icon: Icons.school_rounded,
              color: Colors.green,
              subtitle: 'Active faculty',
            ),
            DashboardComponents.buildSummaryCard(
              context: context,
              title: 'Programs',
              value: '45',
              icon: Icons.book_rounded,
              color: Colors.purple,
              subtitle: 'Active programs',
            ),
            DashboardComponents.buildSummaryCard(
              context: context,
              title: 'Graduation Rate',
              value: '89%',
              icon: Icons.trending_up_rounded,
              color: Colors.orange,
              subtitle: 'Last academic year',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Quick Actions',
          icon: Icons.flash_on_rounded,
          subtitle: 'Frequently used administrative tools',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: ResponsiveUtils.getDashboardGridCrossAxisCount(context),
          crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context),
          mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context),
          childAspectRatio: ResponsiveUtils.getResponsiveActionCardAspectRatio(context),
          children: [
            DashboardComponents.buildActionCard(
              context: context,
              title: 'Faculty Management',
              description: 'Review faculty performance and manage appointments',
              icon: Icons.manage_accounts_rounded,
              color: Colors.blue,
              onTap: () => DashboardComponents.showComingSoonDialog(
                context: context,
                feature: 'Faculty Management',
              ),
            ),
            DashboardComponents.buildActionCard(
              context: context,
              title: 'Program Approval',
              description: 'Review and approve new academic programs',
              icon: Icons.approval_rounded,
              color: Colors.green,
              onTap: () => DashboardComponents.showComingSoonDialog(
                context: context,
                feature: 'Program Approval',
              ),
            ),
            DashboardComponents.buildActionCard(
              context: context,
              title: 'Academic Policies',
              description: 'Manage academic policies and regulations',
              icon: Icons.policy_rounded,
              color: Colors.purple,
              onTap: () => DashboardComponents.showComingSoonDialog(
                context: context,
                feature: 'Academic Policies',
              ),
            ),
            DashboardComponents.buildActionCard(
              context: context,
              title: 'Budget Management',
              description: 'Oversee academic budget allocation',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.orange,
              onTap: () => DashboardComponents.showComingSoonDialog(
                context: context,
                feature: 'Budget Management',
              ),
            ),
            DashboardComponents.buildActionCard(
              context: context,
              title: 'Accreditation',
              description: 'Manage accreditation processes and reports',
              icon: Icons.verified_rounded,
              color: Colors.teal,
              onTap: () => DashboardComponents.showComingSoonDialog(
                context: context,
                feature: 'Accreditation',
              ),
            ),
            DashboardComponents.buildActionCard(
              context: context,
              title: 'Student Affairs',
              description: 'Oversee student services and support',
              icon: Icons.support_agent_rounded,
              color: Colors.indigo,
              onTap: () => DashboardComponents.showComingSoonDialog(
                context: context,
                feature: 'Student Affairs',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcademicAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Academic Analytics',
          icon: Icons.analytics_rounded,
          subtitle: 'Performance insights and metrics',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
        DashboardComponents.buildAnalyticsCard(
          context: context,
          title: 'Student Performance',
          value: 'Average GPA: 3.2 | Retention Rate: 92%',
          icon: Icons.trending_up_rounded,
          color: Colors.green,
          subtitle: 'Academic performance metrics',
        ),
        const SizedBox(height: 12),
        DashboardComponents.buildAnalyticsCard(
          context: context,
          title: 'Faculty Productivity',
          value: 'Research Output: 156 papers | Teaching Score: 4.3/5',
          icon: Icons.work_rounded,
          color: Colors.blue,
          subtitle: 'Faculty performance indicators',
        ),
        const SizedBox(height: 12),
        DashboardComponents.buildAnalyticsCard(
          context: context,
          title: 'Program Effectiveness',
          value: 'Employment Rate: 87% | Industry Satisfaction: 4.1/5',
          icon: Icons.assessment_rounded,
          color: Colors.orange,
          subtitle: 'Program success metrics',
        ),
      ],
    );
  }

  Widget _buildFacultyManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Faculty Overview',
          icon: Icons.people_alt_rounded,
          subtitle: 'Faculty distribution by rank',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              DashboardComponents.buildListRow(
                context: context,
                title: 'Full Professors',
                value: '45',
                icon: Icons.person_rounded,
                color: Colors.blue,
              ),
              const Divider(),
              DashboardComponents.buildListRow(
                context: context,
                title: 'Associate Professors',
                value: '67',
                icon: Icons.person_rounded,
                color: Colors.green,
              ),
              const Divider(),
              DashboardComponents.buildListRow(
                context: context,
                title: 'Assistant Professors',
                value: '89',
                icon: Icons.person_rounded,
                color: Colors.orange,
              ),
              const Divider(),
              DashboardComponents.buildListRow(
                context: context,
                title: 'Lecturers',
                value: '33',
                icon: Icons.person_rounded,
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgramOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Program Overview',
          icon: Icons.book_rounded,
          subtitle: 'Programs by department',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              DashboardComponents.buildListRow(
                context: context,
                title: 'Engineering',
                value: '12 programs',
                icon: Icons.engineering_rounded,
                color: Colors.blue,
              ),
              const Divider(),
              DashboardComponents.buildListRow(
                context: context,
                title: 'Business',
                value: '8 programs',
                icon: Icons.business_rounded,
                color: Colors.green,
              ),
              const Divider(),
              DashboardComponents.buildListRow(
                context: context,
                title: 'Arts & Sciences',
                value: '15 programs',
                icon: Icons.science_rounded,
                color: Colors.orange,
              ),
              const Divider(),
              DashboardComponents.buildListRow(
                context: context,
                title: 'Health Sciences',
                value: '10 programs',
                icon: Icons.medical_services_rounded,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Academic Performance',
          icon: Icons.trending_up_rounded,
          subtitle: 'Key performance indicators',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              DashboardComponents.buildPerformanceIndicator(
                context: context,
                metric: 'Student Satisfaction',
                value: '4.2/5',
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              DashboardComponents.buildPerformanceIndicator(
                context: context,
                metric: 'Research Output',
                value: '156 papers',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              DashboardComponents.buildPerformanceIndicator(
                context: context,
                metric: 'Industry Partnerships',
                value: '23 active',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              DashboardComponents.buildPerformanceIndicator(
                context: context,
                metric: 'International Rankings',
                value: 'Top 500',
                color: Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

}
