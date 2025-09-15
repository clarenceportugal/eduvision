import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'program_chair_main.dart';

class PendingFacultyScreen extends StatefulWidget {
  const PendingFacultyScreen({super.key});

  @override
  State<PendingFacultyScreen> createState() => _PendingFacultyScreenState();
}

class _PendingFacultyScreenState extends State<PendingFacultyScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<dynamic> facultyList = [];
  bool loading = true;
  String courseName = '';

  // Pagination
  int page = 0;
  int rowsPerPage = 10;

  // Modal states
  bool previewOpen = false;
  String? previewImage;
  String? hoveredBtn;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _fetchFacultyList();
  }

  void _initializeAnimations() {
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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        courseName = prefs.getString('course') ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchFacultyList() async {
    setState(() => loading = true);
    try {
      print('Fetching pending faculty for course: $courseName');
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/initial-faculty?courseName=$courseName'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('Pending Faculty API Response Status: ${response.statusCode}');
      print('Pending Faculty API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          facultyList = data is List ? data : [];
        });
        print('Successfully loaded ${facultyList.length} pending faculty members');
      } else {
        print('Failed to fetch pending faculty: ${response.statusCode}');
        _showErrorDialog('Error', 'Failed to load pending faculty list. Please try again.');
      }
    } catch (error) {
      print('Error fetching pending faculty list: $error');
      _showErrorDialog('Error', 'Failed to load pending faculty list: $error');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _handleAccept(String facultyId) async {
    final confirmed = await _showConfirmDialog(
      'Are you sure?',
      'You are about to accept this faculty member.',
      'Yes, accept',
      'Cancel',
    );

    if (confirmed == true) {
      try {
        _showLoadingDialog('Processing...', 'Accepting faculty member...');
        
        print('Approving faculty with ID: $facultyId');
        
        final response = await http.put(
          Uri.parse('https://eduvision-dura.onrender.com/api/auth/approve-faculty/$facultyId'),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        print('Approve Faculty API Response Status: ${response.statusCode}');
        print('Approve Faculty API Response Body: ${response.body}');

        Navigator.of(context).pop(); // Close loading dialog

        if (response.statusCode == 200) {
          setState(() {
            facultyList.removeWhere((f) => f['_id'] == facultyId);
          });
          
          final maxPage = ((facultyList.length - 1) / rowsPerPage).ceil();
          if (page > maxPage) {
            setState(() => page = maxPage > 0 ? maxPage : 0);
          }
          
          _showSuccessDialog('Approved!', 'Faculty has been accepted successfully.');
        } else {
          _showErrorDialog('Error', 'Failed to approve faculty. Please try again.');
        }
      } catch (error) {
        Navigator.of(context).pop(); // Close loading dialog
        print('Error approving faculty: $error');
        _showErrorDialog('Error', 'Failed to approve faculty: $error');
      }
    }
  }

  Future<void> _handleReject(String facultyId) async {
    final confirmed = await _showConfirmDialog(
      'Are you sure?',
      'You are about to reject this faculty member.',
      'Yes, reject',
      'Cancel',
    );

    if (confirmed == true) {
      try {
        _showLoadingDialog('Processing...', 'Rejecting faculty member...');
        
        print('Rejecting faculty with ID: $facultyId');
        
        final response = await http.put(
          Uri.parse('https://eduvision-dura.onrender.com/api/auth/reject-faculty/$facultyId'),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        print('Reject Faculty API Response Status: ${response.statusCode}');
        print('Reject Faculty API Response Body: ${response.body}');

        Navigator.of(context).pop(); // Close loading dialog

        if (response.statusCode == 200) {
          setState(() {
            facultyList.removeWhere((f) => f['_id'] == facultyId);
          });
          
          final maxPage = ((facultyList.length - 1) / rowsPerPage).ceil();
          if (page > maxPage) {
            setState(() => page = maxPage > 0 ? maxPage : 0);
          }
          
          _showSuccessDialog('Rejected!', 'Faculty has been rejected successfully.');
        } else {
          _showErrorDialog('Error', 'Failed to reject faculty. Please try again.');
        }
      } catch (error) {
        Navigator.of(context).pop(); // Close loading dialog
        print('Error rejecting faculty: $error');
        _showErrorDialog('Error', 'Failed to reject faculty: $error');
      }
    }
  }

  List<dynamic> get paginatedFacultyList {
    final start = page * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, facultyList.length);
    return facultyList.sublist(start, end);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return ProgramChairMain(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFacultyTable(),
                if (previewOpen) _buildImagePreviewDialog(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Faculty ${courseName.isNotEmpty ? '- ${courseName.toUpperCase()}' : ''}',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'List of faculty members whose registration or approval is still pending.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFacultyTable() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F3F4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: const [
                  Expanded(flex: 1, child: Text('Profile', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Program', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Date Signed Up', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Center(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            // Table Body
            Expanded(
              child: loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading faculty list...'),
                        ],
                      ),
                    )
                  : facultyList.isEmpty
                      ? const Center(
                          child: Text('No account pending for approval at the moment.'),
                        )
                      : ListView.builder(
                          itemCount: paginatedFacultyList.length,
                          itemBuilder: (context, index) {
                            final faculty = paginatedFacultyList[index];
                            return _buildFacultyRow(faculty, index);
                          },
                        ),
            ),
            // Pagination
            if (facultyList.isNotEmpty)
              _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyRow(Map<String, dynamic> faculty, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  previewImage = faculty['profilePhoto'];
                  previewOpen = true;
                });
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: faculty['profilePhoto'] != null ? Colors.transparent : const Color(0xFF90caf9),
                backgroundImage: faculty['profilePhoto'] != null 
                    ? NetworkImage(faculty['profilePhoto']) 
                    : null,
                child: faculty['profilePhoto'] == null 
                    ? Text(
                        faculty['email'][0].toString().toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : null,
              ),
            ),
          ),
          // Email
          Expanded(
            flex: 2,
            child: Text(
              faculty['email'] ?? '',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          // Role
          Expanded(
            flex: 1,
            child: Text(
              faculty['role'] ?? '',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          // Department
          Expanded(
            flex: 1,
            child: Text(
              faculty['department'] is String 
                  ? faculty['department'] 
                  : faculty['department']?['name'] ?? 'N/A',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          // Program
          Expanded(
            flex: 1,
            child: Text(
              faculty['program'] is String 
                  ? faculty['program'] 
                  : faculty['program']?['name'] ?? 'N/A',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          // Date Signed Up
          Expanded(
            flex: 1,
            child: Text(
              faculty['dateSignedUp'] != null
                  ? _formatDate(faculty['dateSignedUp'])
                  : 'N/A',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          // Actions
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  'Accept',
                  Colors.green,
                  () => _handleAccept(faculty['_id']),
                  'accept-${faculty['_id']}',
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  'Reject',
                  Colors.red,
                  () => _handleReject(faculty['_id']),
                  'reject-${faculty['_id']}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed, String buttonId) {
    final isHovered = hoveredBtn == buttonId;
    
    return GestureDetector(
      onTap: onPressed,
      onTapDown: (_) => setState(() => hoveredBtn = buttonId),
      onTapUp: (_) => setState(() => hoveredBtn = null),
      onTapCancel: () => setState(() => hoveredBtn = null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isHovered ? color.withValues(alpha: 0.8) : color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (facultyList.length / rowsPerPage).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page * rowsPerPage + 1} to ${(page + 1) * rowsPerPage.clamp(0, facultyList.length)} of ${facultyList.length} entries',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          Row(
            children: [
              DropdownButton<int>(
                value: rowsPerPage,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (value) {
                  setState(() {
                    rowsPerPage = value ?? 10;
                    page = 0;
                  });
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: page > 0 ? () => setState(() => page--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('${page + 1} of $totalPages'),
              IconButton(
                onPressed: page < totalPages - 1 ? () => setState(() => page++) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewDialog() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 400,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Profile Photo',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          previewOpen = false;
                          previewImage = null;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // Image
              Container(
                padding: const EdgeInsets.all(16),
                child: previewImage != null
                    ? Image.network(
                        previewImage!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person_rounded,
                            size: 100,
                            color: Colors.grey,
                          );
                        },
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 100,
                        color: Colors.grey,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Future<void> _showErrorDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLoadingDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message, String confirmText, String cancelText) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}
