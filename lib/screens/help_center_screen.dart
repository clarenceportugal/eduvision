import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/custom_colors.dart';

class HelpCenterScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HelpCenterScreen({super.key, required this.userData});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<HelpArticle> _allArticles = [
    HelpArticle(
      title: 'Getting Started with Face Registration',
      category: 'Face Recognition',
      content:
          'Learn how to register your face for secure authentication:\n\n'
          '1. Go to Settings → Face Registration\n'
          '2. Position your face in the camera frame\n'
          '3. Follow the on-screen instructions\n'
          '4. Complete all 5 poses (center, up, down, left, right)\n'
          '5. Wait for automatic capture when pose is correct\n\n'
          'Tips:\n'
          '• Ensure good lighting\n'
          '• Keep your face centered\n'
          '• Hold steady for automatic capture\n'
          '• Remove glasses if detection fails',
      keywords: ['face', 'registration', 'setup', 'authentication'],
    ),
    HelpArticle(
      title: 'Troubleshooting Face Recognition Issues',
      category: 'Face Recognition',
      content:
          'Common face recognition problems and solutions:\n\n'
          'Problem: Face not detected\n'
          '• Check lighting conditions\n'
          '• Clean camera lens\n'
          '• Remove face coverings\n'
          '• Try different angle\n\n'
          'Problem: Registration fails\n'
          '• Ensure stable internet connection\n'
          '• Check camera permissions\n'
          '• Restart the app\n'
          '• Clear app cache\n\n'
          'Problem: Slow recognition\n'
          '• Update to latest app version\n'
          '• Restart device\n'
          '• Re-register face data',
      keywords: ['troubleshoot', 'issues', 'problems', 'detection', 'fails'],
    ),
    HelpArticle(
      title: 'Managing Your Account',
      category: 'Account',
      content:
          'How to manage your EduVision account:\n\n'
          'Updating Profile:\n'
          '• Go to Settings → Profile\n'
          '• Edit your information\n'
          '• Save changes\n\n'
          'Changing Password:\n'
          '• Go to Settings → Security\n'
          '• Select "Change Password"\n'
          '• Enter current and new password\n\n'
          'Account Settings:\n'
          '• Notification preferences\n'
          '• Privacy settings\n'
          '• Data management\n'
          '• Theme selection',
      keywords: ['account', 'profile', 'password', 'settings', 'manage'],
    ),
    HelpArticle(
      title: 'Privacy and Data Security',
      category: 'Privacy',
      content:
          'Understanding how your data is protected:\n\n'
          'Data Encryption:\n'
          '• All face data is encrypted\n'
          '• Secure cloud storage\n'
          '• Local processing when possible\n\n'
          'Data Control:\n'
          '• Download your data anytime\n'
          '• Delete account and data\n'
          '• Control data sharing\n\n'
          'Privacy Features:\n'
          '• Minimal data collection\n'
          '• No third-party selling\n'
          '• Transparent privacy policy\n'
          '• User consent required',
      keywords: ['privacy', 'security', 'data', 'encryption', 'protection'],
    ),
    HelpArticle(
      title: 'Using the Dashboard',
      category: 'Navigation',
      content:
          'Navigate the EduVision dashboard effectively:\n\n'
          'Main Features:\n'
          '• Quick actions panel\n'
          '• Recent activity feed\n'
          '• Statistics overview\n'
          '• Shortcut buttons\n\n'
          'Navigation:\n'
          '• Use bottom navigation bar\n'
          '• Access settings via profile icon\n'
          '• Search functionality\n'
          '• Quick access menu\n\n'
          'Customization:\n'
          '• Rearrange widgets\n'
          '• Set preferences\n'
          '• Theme selection\n'
          '• Notification settings',
      keywords: ['dashboard', 'navigation', 'interface', 'menu', 'features'],
    ),
    HelpArticle(
      title: 'App Performance and Optimization',
      category: 'Performance',
      content:
          'Optimize EduVision for best performance:\n\n'
          'Device Requirements:\n'
          '• Android 7.0+ or iOS 12+\n'
          '• 2GB RAM minimum\n'
          '• Front-facing camera\n'
          '• Internet connection\n\n'
          'Performance Tips:\n'
          '• Close other apps\n'
          '• Ensure sufficient storage\n'
          '• Update app regularly\n'
          '• Clear cache periodically\n\n'
          'Battery Optimization:\n'
          '• Disable background refresh\n'
          '• Reduce screen brightness\n'
          '• Use WiFi when available\n'
          '• Enable power saving mode',
      keywords: [
        'performance',
        'optimization',
        'speed',
        'battery',
        'requirements',
      ],
    ),
  ];

  List<HelpArticle> get _filteredArticles {
    if (_searchQuery.isEmpty) return _allArticles;

    return _allArticles.where((article) {
      final query = _searchQuery.toLowerCase();
      return article.title.toLowerCase().contains(query) ||
          article.content.toLowerCase().contains(query) ||
          article.category.toLowerCase().contains(query) ||
          article.keywords.any((keyword) => keyword.contains(query));
    }).toList();
  }

  Map<String, List<HelpArticle>> get _categorizedArticles {
    final categories = <String, List<HelpArticle>>{};
    for (final article in _filteredArticles) {
      categories.putIfAbsent(article.category, () => []).add(article);
    }
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help Center',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        backgroundColor: CustomColors.getSurfaceColor(context),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search help articles...',
                prefixIcon: Icon(
                  Icons.search,
                  color: CustomColors.getOnSurfaceColor(
                    context,
                  ).withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: CustomColors.getSecondaryColor(
                      context,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                filled: true,
                fillColor: CustomColors.getSurfaceColor(context),
              ),
            ),
          ),

          // Quick Actions
          if (_searchQuery.isEmpty) _buildQuickActions(),

          // Help Articles
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildCategorizedArticles()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Help',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CustomColors.getOnSurfaceColor(context),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Face Registration Guide',
                  'Step-by-step setup',
                  Icons.face_rounded,
                  () => _showArticle(_allArticles[0]),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Troubleshooting',
                  'Common issues',
                  Icons.build_rounded,
                  () => _showArticle(_allArticles[1]),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Contact Support',
                  'Get personalized help',
                  Icons.support_agent_rounded,
                  _showContactOptions,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Video Tutorials',
                  'Watch guides',
                  Icons.play_circle_rounded,
                  _showVideoTutorials,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedArticles() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20),
      children: _categorizedArticles.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                entry.key,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ...entry.value.map((article) => _buildArticleTile(article)),
            SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredArticles.length,
      itemBuilder: (context, index) =>
          _buildArticleTile(_filteredArticles[index]),
    );
  }

  Widget _buildArticleTile(HelpArticle article) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showArticle(article),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(article.category),
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      article.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Face Recognition':
        return Icons.face_rounded;
      case 'Account':
        return Icons.person_rounded;
      case 'Privacy':
        return Icons.security_rounded;
      case 'Navigation':
        return Icons.dashboard_rounded;
      case 'Performance':
        return Icons.speed_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  void _showArticle(HelpArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpArticleScreen(article: article),
      ),
    );
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact Support',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email Support'),
              subtitle: Text('support@eduvision.com'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.chat),
              title: Text('Live Chat'),
              subtitle: Text('Available 9 AM - 5 PM'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Phone Support'),
              subtitle: Text('+1 (555) 123-4567'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoTutorials() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video Tutorials'),
        content: Text(
          'Video tutorials are available on our website and YouTube channel. Visit eduvision.com/tutorials for the latest guides.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

class HelpArticle {
  final String title;
  final String category;
  final String content;
  final List<String> keywords;

  HelpArticle({
    required this.title,
    required this.category,
    required this.content,
    required this.keywords,
  });
}

class HelpArticleScreen extends StatelessWidget {
  final HelpArticle article;

  const HelpArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          article.title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                article.category,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              article.content,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Was this helpful?',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showFeedback(context, true),
                        icon: Icon(Icons.thumb_up_outlined, size: 16),
                        label: Text('Yes'),
                      ),
                      SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showFeedback(context, false),
                        icon: Icon(Icons.thumb_down_outlined, size: 16),
                        label: Text('No'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(BuildContext context, bool isHelpful) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHelpful
              ? 'Thanks for your feedback!'
              : 'We\'ll work on improving this article.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}
