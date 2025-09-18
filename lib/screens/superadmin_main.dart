import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SuperadminMain extends StatefulWidget {
  final Widget child;

  const SuperadminMain({super.key, required this.child});

  @override
  State<SuperadminMain> createState() => _SuperadminMainState();
}

class _SuperadminMainState extends State<SuperadminMain> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> menuItems = [
    {
      'text': 'Dashboard',
      'icon': Icons.dashboard_rounded,
      'path': '/superadmin-dashboard',
    },
    {
      'text': 'Dean',
      'icon': Icons.school_rounded,
      'path': '/dean-info',
    },
    {
      'text': 'Program Chairperson',
      'icon': Icons.assignment_ind_rounded,
      'path': '/programchairinfo-only',
    },
    {
      'text': 'Instructor',
      'icon': Icons.person_rounded,
      'path': '/instructorinfo-only',
    },
    {
      'text': 'Pending Instructors',
      'icon': Icons.hourglass_empty_rounded,
      'path': '/pending-instructors',
    },
    {
      'text': 'Pending Program Chairpersons',
      'icon': Icons.pending_actions_rounded,
      'path': '/pending-programchairpersons',
    },
    {
      'text': 'Pending Deans',
      'icon': Icons.schedule_rounded,
      'path': '/pending-deans',
    },
    {
      'text': 'Live Video',
      'icon': Icons.videocam_rounded,
      'path': '/deanlivevideo',
    },
    {
      'text': 'Camera Settings',
      'icon': Icons.tune_rounded,
      'path': '/deanlivevideo',
    },
  ];

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
                const SizedBox(height: 20),
                // Logo/Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Super Admin',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      // Users Info Section
                      _buildSectionHeader('Users Info'),
                      _buildMenuItem(0, 'Dashboard'),
                      _buildMenuItem(1, 'Dean'),
                      _buildMenuItem(2, 'Program Chairperson'),
                      _buildMenuItem(3, 'Instructor'),
                      
                      const SizedBox(height: 20),
                      
                      // Pending Accounts Section
                      _buildSectionHeader('Pending Accounts'),
                      _buildMenuItem(4, 'Pending Instructors'),
                      _buildMenuItem(5, 'Pending Program Chairpersons'),
                      _buildMenuItem(6, 'Pending Deans'),
                      
                      const SizedBox(height: 20),
                      
                      // Cam Config Section
                      _buildSectionHeader('Cam Config'),
                      _buildMenuItem(7, 'Live Video'),
                      _buildMenuItem(8, 'Camera Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
            margin: const EdgeInsets.only(right: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, String text) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
            // Handle navigation here
            _handleNavigation(menuItems[index]['path']);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1e88e5).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  menuItems[index]['icon'],
                  color: isSelected ? const Color(0xFF1e88e5) : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      color: isSelected ? const Color(0xFF1e88e5) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(String path) {
    // This would typically use Navigator or a routing solution
    // For now, we'll just print the path
    // 
    
    // You can implement actual navigation here based on your routing setup
    // Example:
    // Navigator.pushNamed(context, path);
  }
}
