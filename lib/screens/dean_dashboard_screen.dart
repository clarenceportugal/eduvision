import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
<<<<<<< HEAD
import '../widgets/dashboard_components.dart';
import '../utils/responsive_utils.dart';
=======
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664

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
<<<<<<< HEAD
                  padding: ResponsiveUtils.getResponsivePadding(context),
=======
                  padding: const EdgeInsets.all(20.0),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(displayName),
<<<<<<< HEAD
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
=======
                      const SizedBox(height: 24),
                      _buildAcademicOverviewSection(),
                      const SizedBox(height: 24),
                      _buildQuickActionsSection(),
                      const SizedBox(height: 24),
                      _buildAcademicAnalyticsSection(),
                      const SizedBox(height: 24),
                      _buildFacultyManagementSection(),
                      const SizedBox(height: 24),
                      _buildProgramOverviewSection(),
                      const SizedBox(height: 24),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
    return DashboardComponents.buildSliverAppBar(
      context: context,
      title: 'Academic Administration',
      subtitle: 'Welcome back,',
      icon: Icons.school_rounded,
      displayName: displayName,
=======
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Academic Administration',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome back,',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
    );
  }

  Widget _buildWelcomeSection(String displayName) {
<<<<<<< HEAD
    return DashboardComponents.buildWelcomeSection(
      context: context,
      title: 'Academic Leadership Center',
      description: 'You have comprehensive oversight of academic programs, faculty management, and institutional excellence across all departments.',
      icon: Icons.school_rounded,
=======
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Academic Leadership Center',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You have comprehensive oversight of academic programs, faculty management, and institutional excellence across all departments.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
    );
  }

  Widget _buildAcademicOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
<<<<<<< HEAD
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
=======
        Text(
          'Academic Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            _buildSummaryCard(
              'Total Students',
              '3,456',
              Icons.people_rounded,
              Colors.blue,
              'Enrolled students',
            ),
            _buildSummaryCard(
              'Faculty Members',
              '234',
              Icons.school_rounded,
              Colors.green,
              'Active faculty',
            ),
            _buildSummaryCard(
              'Programs',
              '45',
              Icons.book_rounded,
              Colors.purple,
              'Active programs',
            ),
            _buildSummaryCard(
              'Graduation Rate',
              '89%',
              Icons.trending_up_rounded,
              Colors.orange,
              'Last academic year',
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
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
=======
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildEnhancedActionCard(
              'Faculty Management',
              'Review faculty performance and manage appointments',
              Icons.manage_accounts_rounded,
              Colors.blue,
              () => _showComingSoonDialog('Faculty Management'),
            ),
            _buildEnhancedActionCard(
              'Program Approval',
              'Review and approve new academic programs',
              Icons.approval_rounded,
              Colors.green,
              () => _showComingSoonDialog('Program Approval'),
            ),
            _buildEnhancedActionCard(
              'Academic Policies',
              'Manage academic policies and regulations',
              Icons.policy_rounded,
              Colors.purple,
              () => _showComingSoonDialog('Academic Policies'),
            ),
            _buildEnhancedActionCard(
              'Budget Management',
              'Oversee academic budget allocation',
              Icons.account_balance_wallet_rounded,
              Colors.orange,
              () => _showComingSoonDialog('Budget Management'),
            ),
            _buildEnhancedActionCard(
              'Accreditation',
              'Manage accreditation processes and reports',
              Icons.verified_rounded,
              Colors.teal,
              () => _showComingSoonDialog('Accreditation'),
            ),
            _buildEnhancedActionCard(
              'Student Affairs',
              'Oversee student services and support',
              Icons.support_agent_rounded,
              Colors.indigo,
              () => _showComingSoonDialog('Student Affairs'),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
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
=======
        Text(
          'Academic Analytics',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildAnalyticsCard(
          'Student Performance',
          'Average GPA: 3.2 | Retention Rate: 92%',
          Icons.trending_up_rounded,
          Colors.green,
          'Academic performance metrics',
        ),
        const SizedBox(height: 12),
        _buildAnalyticsCard(
          'Faculty Productivity',
          'Research Output: 156 papers | Teaching Score: 4.3/5',
          Icons.work_rounded,
          Colors.blue,
          'Faculty performance indicators',
        ),
        const SizedBox(height: 12),
        _buildAnalyticsCard(
          'Program Effectiveness',
          'Employment Rate: 87% | Industry Satisfaction: 4.1/5',
          Icons.assessment_rounded,
          Colors.orange,
          'Program success metrics',
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
        ),
      ],
    );
  }

  Widget _buildFacultyManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
<<<<<<< HEAD
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Faculty Overview',
          icon: Icons.people_alt_rounded,
          subtitle: 'Faculty distribution by rank',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
=======
        Text(
          'Faculty Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
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
=======
              _buildFacultyRow(
                'Full Professors',
                '45',
                Icons.person_rounded,
                Colors.blue,
              ),
              const Divider(),
              _buildFacultyRow(
                'Associate Professors',
                '67',
                Icons.person_rounded,
                Colors.green,
              ),
              const Divider(),
              _buildFacultyRow(
                'Assistant Professors',
                '89',
                Icons.person_rounded,
                Colors.orange,
              ),
              const Divider(),
              _buildFacultyRow(
                'Lecturers',
                '33',
                Icons.person_rounded,
                Colors.purple,
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Program Overview',
          icon: Icons.book_rounded,
          subtitle: 'Programs by department',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
=======
        Text(
          'Program Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
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
=======
              _buildProgramRow(
                'Engineering',
                '12 programs',
                Icons.engineering_rounded,
                Colors.blue,
              ),
              const Divider(),
              _buildProgramRow(
                'Business',
                '8 programs',
                Icons.business_rounded,
                Colors.green,
              ),
              const Divider(),
              _buildProgramRow(
                'Arts & Sciences',
                '15 programs',
                Icons.science_rounded,
                Colors.orange,
              ),
              const Divider(),
              _buildProgramRow(
                'Health Sciences',
                '10 programs',
                Icons.medical_services_rounded,
                Colors.red,
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
        DashboardComponents.buildSectionHeader(
          context: context,
          title: 'Academic Performance',
          icon: Icons.trending_up_rounded,
          subtitle: 'Key performance indicators',
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
=======
        Text(
          'Academic Performance',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
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
<<<<<<< HEAD
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
=======
              _buildPerformanceIndicator(
                'Student Satisfaction',
                '4.2/5',
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildPerformanceIndicator(
                'Research Output',
                '156 papers',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildPerformanceIndicator(
                'Industry Partnerships',
                '23 active',
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildPerformanceIndicator(
                'International Rankings',
                'Top 500',
                Colors.purple,
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
              ),
            ],
          ),
        ),
      ],
    );
  }

<<<<<<< HEAD
=======
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyRow(
    String rank,
    String count,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              rank,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            count,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildProgramRow(
    String department,
    String programs,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              department,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            programs,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicator(String metric, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            metric,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.construction_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Coming Soon',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            '$feature feature is currently under development and will be available soon.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
>>>>>>> 60cf4f3b2dfd41f06f3eab28e0557d97d3326664
}
