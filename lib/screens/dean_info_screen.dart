import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeanInfoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DeanInfoScreen({super.key, required this.userData});

  @override
  State<DeanInfoScreen> createState() => _DeanInfoScreenState();
}

class _DeanInfoScreenState extends State<DeanInfoScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  List<Map<String, dynamic>> deans = [];
  bool loading = true;
  String? error;
  String selectedStatus = "all";
  bool openModal = false;
  List<Map<String, dynamic>> colleges = [];
  List<String> collegeCourses = [];
  int page = 0;
  int rowsPerPage = 10;

  // New faculty form data
  Map<String, dynamic> newFaculty = {
    'last_name': '',
    'first_name': '',
    'middle_name': '',
    'ext_name': '',
    'college': '',
    'username': '',
    'email': '',
    'password': '',
    'role': 'dean',
    'highestEducationalAttainment': '',
    'academicRank': '',
    'statusOfAppointment': '',
    'numberOfPrep': 0,
    'totalTeachingLoad': 0,
  };

  bool showPassword = false;

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
      // Load any user-specific data if needed
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
      await Future.wait([
        _fetchColleges(),
        _fetchDeans(),
      ]);
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

  Future<void> _fetchColleges() async {
    if (!mounted) return;
    
    try {
      // 
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/all-colleges'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      // 
      // 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            colleges = data is List ? data.cast<Map<String, dynamic>>() : [];
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

  Future<void> _fetchDeans() async {
    if (!mounted) return;
    
    try {
      // 
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/dean'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      // 
      // 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            deans = data is List ? data.cast<Map<String, dynamic>>() : [];
          });
          // 
        }
      } else {
        // 
      }
    } catch (e) {
      // 
      if (mounted) {
        setState(() {
          error = 'Failed to fetch deans';
        });
      }
    }
  }


  Future<void> _handleDeleteDean(String id) async {
    final confirmed = await _showConfirmDialog(
      'Are you sure?',
      'This action cannot be undone!',
    );

    if (confirmed == true) {
      try {
        // 
        
        final response = await http.delete(
          Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/faculty/$id'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 15));

        // 
        // 

        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              deans.removeWhere((dean) => dean['_id'] == id);
            });
            _showSuccessDialog('Deleted!', 'Dean account has been deleted.');
          }
        } else {
          final errorData = jsonDecode(response.body);
          _showErrorDialog('Error', errorData['message'] ?? 'An error occurred while deleting the dean.');
        }
    } catch (e) {
      // 
      _showErrorDialog('Error', 'An error occurred while deleting the dean.');
    }
    }
  }

  List<Map<String, dynamic>> get filteredDeans {
    if (selectedStatus == "all") return deans;
    return deans.where((dean) => dean['status'] == selectedStatus).toList();
  }

  List<Map<String, dynamic>> get paginatedDeans {
    final start = page * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, filteredDeans.length);
    return filteredDeans.sublist(start, end);
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
                _buildSearchAndAdd(),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildTable(),
                ),
                if (filteredDeans.isNotEmpty) _buildPagination(),
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
          'List of Dean/s',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This section contains a list of all current deans across departments and their respective information.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndAdd() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, username, or email...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              // Implement search functionality
              // 
            },
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              openModal = true;
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Dean'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            Text('Loading data...'),
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
            child: paginatedDeans.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No dean records found.'),
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
            flex: 2,
            child: Text(
              'Full Name',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Username',
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
              'College',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _buildStatusDropdown(),
          ),
          Expanded(
            child: Text(
              'Action',
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

  Widget _buildStatusDropdown() {
    return PopupMenuButton<String>(
      initialValue: selectedStatus,
      onSelected: (value) {
        setState(() {
          selectedStatus = value;
        });
      },
      child: Row(
        children: [
          Text(
            'Status of Account',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('All')),
        const PopupMenuItem(value: 'forverification', child: Text('For Verification')),
        const PopupMenuItem(value: 'active', child: Text('Active')),
        const PopupMenuItem(value: 'inactive', child: Text('Inactive')),
      ],
    );
  }

  Widget _buildTableBody() {
    return ListView.builder(
      itemCount: paginatedDeans.length,
      itemBuilder: (context, index) {
        final dean = paginatedDeans[index];
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
                flex: 2,
                child: Text(
                  '${dean['last_name']}, ${dean['first_name']} ${dean['middle_name'] != null ? dean['middle_name'][0] + '.' : ''} ${dean['ext_name'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  dean['username'] ?? '',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  dean['email'] ?? '',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  dean['college']?['name'] ?? 'N/A',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  dean['status'] == 'forverification'
                      ? 'For Verification'
                      : (dean['status'] ?? '').isNotEmpty
                          ? (dean['status'][0].toUpperCase() + dean['status'].substring(1))
                          : 'N/A',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => print('Edit ${dean['_id']}'),
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                    ),
                    IconButton(
                      onPressed: () => _handleDeleteDean(dean['_id']),
                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
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
            'Showing ${page * rowsPerPage + 1} to ${(page * rowsPerPage + rowsPerPage).clamp(0, filteredDeans.length)} of ${filteredDeans.length} entries',
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
                onPressed: (page + 1) * rowsPerPage < filteredDeans.length
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

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, delete it!'),
          ),
        ],
      ),
    );
  }
}
