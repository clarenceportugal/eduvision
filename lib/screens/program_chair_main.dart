import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgramChairMain extends StatelessWidget {
  final Widget child;

  const ProgramChairMain({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf4f6f8),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: const Color(0xFF3D1308),
            child: Column(
              children: [
                const SizedBox(height: 60), // Space for app bar
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildMenuSection(
                        context,
                        'Faculty',
                        [
                          _buildMenuItem(
                            context,
                            'Faculty Info',
                            Icons.people_rounded,
                            '/faculty-info',
                            const Color(0xFFF8E5EE),
                          ),
                          _buildMenuItem(
                            context,
                            'Pending Faculty',
                            Icons.pending_actions_rounded,
                            '/pending-faculty',
                            const Color(0xFFF8E5EE),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMenuItem(
                        context,
                        'Dashboard',
                        Icons.dashboard_rounded,
                        '/dashboard',
                        const Color(0xFFF8E5EE),
                      ),
                      _buildMenuItem(
                        context,
                        'Live Video',
                        Icons.videocam_rounded,
                        '/live-video',
                        const Color(0xFFF8E5EE),
                      ),
                      _buildMenuItem(
                        context,
                        'Generate Reports',
                        Icons.assessment_rounded,
                        '/faculty-reports',
                        const Color(0xFFF8E5EE),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // App Bar
                Container(
                  height: 60,
                  color: Colors.white,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Program Chair Dashboard',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      // User info and logout
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              'PC',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Program Chair',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF8E5EE),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFF4F1A0F),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String text,
    IconData icon,
    String path,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle navigation
            print('Navigate to: $path');
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(
                right: BorderSide(
                  color: Colors.transparent,
                  width: 5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: textColor,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
