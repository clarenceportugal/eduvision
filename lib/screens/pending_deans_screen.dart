import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingDeansScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PendingDeansScreen({super.key, required this.userData});

  @override
  State<PendingDeansScreen> createState() => _PendingDeansScreenState();
}

class _PendingDeansScreenState extends State<PendingDeansScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  List<Map<String, dynamic>> facultyList = [];
  bool loading = true;
  String? error;
  String collegeName = "";
  int page = 0;
  int rowsPerPage = 10;
  bool previewOpen = false;
  String? previewImage;
  String? hoveredBtn;

  // Keep alive for better performance
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    if (mounted) {
      await _fetchData();
    }
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
      if (mounted) {
        setState(() {
          collegeName = prefs.getString('college') ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load user data: $e';
        });
      }
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await _fetchFaculty();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _fetchFaculty() async {
    if (!mounted || collegeName.isEmpty) return;
    
    try {
      // 
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/initial-staff?collegeName=$collegeName'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      // 
      // 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            facultyList = data is List ? data.cast<Map<String, dynamic>>() : [];
          });
          // 
        }
      } else {
        // 
      }
    } catch (error) {
      // 
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
        
        // 
        
        final response = await http.put(
          Uri.parse('https://eduvision-dura.onrender.com/api/auth/approve-faculty/$facultyId'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        // 
        // 

        if (mounted) {
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
            final errorData = jsonDecode(response.body);
            _showErrorDialog('Error', errorData['message'] ?? 'Failed to approve faculty. Please try again.');
          }
        }
      } catch (error) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          // 
          _showErrorDialog('Error', 'Failed to approve faculty. Please try again.');
        }
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
        
        // 
        
        final response = await http.put(
          Uri.parse('https://eduvision-dura.onrender.com/api/auth/reject-faculty/$facultyId'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        // 
        // 

        if (mounted) {
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
            final errorData = jsonDecode(response.body);
            _showErrorDialog('Error', errorData['message'] ?? 'Failed to reject faculty. Please try again.');
          }
        }
      } catch (error) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          // 
          _showErrorDialog('Error', 'Failed to reject faculty. Please try again.');
        }
      }
    }
  }

  List<Map<String, dynamic>> get paginatedFacultyList {
    final start = page * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, facultyList.length);
    return facultyList.sublist(start, end);
  }

  void _handleChangePage(int newPage) {
    setState(() {
      page = newPage;
    });
  }

  void _handleChangeRowsPerPage(int newRowsPerPage) {
    setState(() {
      rowsPerPage = newRowsPerPage;
      page = 0;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: const Color(0xFFf4f6f8),
      body: FadeTransition(
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
                Expanded(
                  child: _buildTable(),
                ),
                if (facultyList.isNotEmpty) _buildPagination(),
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
          'Pending Dean${collegeName.isNotEmpty ? ' - ${collegeName.toUpperCase()}' : ''}',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildTable() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading faculty list...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: facultyList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No account pending for approval at the moment.'),
                    ),
                  )
                : _buildTableBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFf5f5f5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Profile',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Email',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Role',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Department',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Program',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Date Signed Up',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Actions',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    return ListView.builder(
      itemCount: paginatedFacultyList.length,
      itemBuilder: (context, index) {
        final faculty = paginatedFacultyList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      previewImage = faculty['profilePhoto'];
                      previewOpen = true;
                    });
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: faculty['profilePhoto'] != null
                        ? NetworkImage(faculty['profilePhoto'])
                        : null,
                    child: faculty['profilePhoto'] == null
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  faculty['email'] ?? '',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  faculty['role'] ?? '',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  faculty['department'] is String
                      ? faculty['department']
                      : faculty['department']?['name'] ?? 'N/A',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  faculty['program'] is String
                      ? faculty['program']
                      : faculty['program']?['name'] ?? 'N/A',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  faculty['dateSignedUp'] != null
                      ? _formatDate(faculty['dateSignedUp'])
                      : 'N/A',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
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
      },
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed, String hoverKey) {
    return GestureDetector(
      onTap: onPressed,
      onTapDown: (_) {
        setState(() {
          hoveredBtn = hoverKey;
        });
      },
      onTapUp: (_) {
        setState(() {
          hoveredBtn = null;
        });
      },
      onTapCancel: () {
        setState(() {
          hoveredBtn = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hoveredBtn == hoverKey ? color.withValues(alpha: 0.8) : color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page * rowsPerPage + 1} to ${(page * rowsPerPage + rowsPerPage).clamp(0, facultyList.length)} of ${facultyList.length} entries',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
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
                  if (value != null) {
                    _handleChangeRowsPerPage(value);
                  }
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: page > 0 ? () => _handleChangePage(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${page + 1}',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              IconButton(
                onPressed: (page + 1) * rowsPerPage < facultyList.length
                    ? () => _handleChangePage(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message, String confirmText, String cancelText) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );
  }

  void _showLoadingDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
