import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'program_chair_main.dart';

class FacultyInfoScreen extends StatefulWidget {
  const FacultyInfoScreen({super.key});

  @override
  State<FacultyInfoScreen> createState() => _FacultyInfoScreenState();
}

class _FacultyInfoScreenState extends State<FacultyInfoScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<dynamic> facultyList = [];
  bool loading = true;
  String searchQuery = '';
  String selectedStatus = 'all';
  String courseName = '';
  String collegeName = '';

  // Pagination
  int page = 0;
  int rowsPerPage = 10;

  // Modal states
  bool openModal = false;
  bool showPassword = false;
  Map<String, dynamic> newFaculty = {};

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
        collegeName = prefs.getString('college') ?? '';
      });
    } catch (e) {
      // 
    }
  }

  Future<void> _fetchFacultyList() async {
    setState(() => loading = true);
    try {
      // 
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/faculty?course=$courseName'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      // 
      // 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          facultyList = data is List ? data : [];
        });
        // 
      } else {
        // 
        _showErrorDialog('Error', 'Failed to load faculty list. Please try again.');
      }
    } catch (error) {
      // 
      _showErrorDialog('Error', 'Failed to load faculty list: $error');
    } finally {
      setState(() => loading = false);
    }
  }

  void _handleOpenModal() {
    setState(() {
      newFaculty = {
        'last_name': '',
        'first_name': '',
        'middle_name': '',
        'username': '',
        'email': '',
        'password': _generateRandomPassword(),
        'role': 'instructor',
        'college': collegeName,
        'course': courseName,
        'highestEducationalAttainment': '',
        'academicRank': '',
        'statusOfAppointment': '',
        'numberOfPrep': 0,
        'totalTeachingLoad': 0,
      };
      openModal = true;
    });
  }

  void _handleCloseModal() {
    setState(() {
      openModal = false;
      newFaculty = {};
    });
  }

  String _generateRandomPassword() {
    return (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
  }

  String _generateUsername(String firstName, String lastName) {
    final first = firstName.length >= 3 ? firstName.substring(0, 3).toUpperCase() : firstName.toUpperCase();
    final last = lastName.length >= 3 ? lastName.substring(0, 3).toUpperCase() : lastName.toUpperCase();
    return last + first;
  }

  Future<void> _handleAddAccount() async {
    if (newFaculty['last_name'].toString().trim().isEmpty ||
        newFaculty['first_name'].toString().trim().isEmpty ||
        newFaculty['email'].toString().trim().isEmpty ||
        newFaculty['password'].toString().trim().isEmpty) {
      _showErrorDialog('Missing Fields', 'Please fill out all required fields.');
      return;
    }

    try {
      print('Adding new faculty: ${newFaculty['email']}');
      
      final response = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/faculty'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(newFaculty),
      ).timeout(const Duration(seconds: 15));

      // 
      // 

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newFacultyData = jsonDecode(response.body);
        setState(() {
          facultyList.add(newFacultyData);
        });
        _showSuccessDialog('Success', 'Faculty account added successfully!');
        _handleCloseModal();
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorDialog('Error', errorData['message'] ?? 'Failed to add faculty account.');
      }
    } catch (error) {
      // 
      _showErrorDialog('Error', 'Failed to add faculty account: $error');
    }
  }

  Future<void> _handleDeleteAccount(String id) async {
    final confirmed = await _showConfirmDialog(
      'Are you sure?',
      'This action cannot be undone!',
    );

    if (confirmed == true) {
      try {
        // 
        
        final response = await http.delete(
          Uri.parse('https://eduvision-dura.onrender.com/api/auth/faculty/$id'),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        // 
        // 

        if (response.statusCode == 200 || response.statusCode == 204) {
          setState(() {
            facultyList.removeWhere((faculty) => faculty['_id'] == id);
          });
          _showSuccessDialog('Deleted!', 'The faculty account has been deleted successfully.');
        } else {
          _showErrorDialog('Error', 'Failed to delete faculty account.');
        }
      } catch (error) {
        // 
        _showErrorDialog('Error', 'Something went wrong! Unable to delete the account: $error');
      }
    }
  }

  List<dynamic> get filteredFacultyList {
    return facultyList.where((faculty) {
      final fullName = '${faculty['last_name']}, ${faculty['first_name']} ${faculty['middle_name'] ?? ''}'.toLowerCase();
      final matchesSearch = fullName.contains(searchQuery.toLowerCase()) ||
          faculty['username'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          faculty['email'].toString().toLowerCase().contains(searchQuery.toLowerCase());

      final matchesStatus = selectedStatus == 'all' ||
          faculty['status'].toString().toLowerCase() == selectedStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<dynamic> get paginatedFacultyList {
    final filtered = filteredFacultyList;
    final start = page * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
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
                _buildSearchAndAdd(),
                const SizedBox(height: 24),
                _buildFacultyTable(),
                if (openModal) _buildAddFacultyModal(),
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
          'Faculty Information ${courseName.isNotEmpty ? '- ${courseName.toUpperCase()}' : ''}',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This section provides detailed information about the faculty members${courseName.isNotEmpty ? ' under the ${courseName.toUpperCase()} program' : ''}.',
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
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search faculty...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
                page = 0;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        DropdownButton<String>(
          value: selectedStatus,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            DropdownMenuItem(value: 'forverification', child: Text('For Verification')),
          ],
          onChanged: (value) {
            setState(() {
              selectedStatus = value ?? 'all';
              page = 0;
            });
          },
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          onPressed: _handleOpenModal,
          mini: true,
          child: const Icon(Icons.add_rounded),
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
                  Expanded(flex: 2, child: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            // Table Body
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFacultyList.isEmpty
                      ? const Center(
                          child: Text('No faculty members found.'),
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
            if (filteredFacultyList.isNotEmpty)
              _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyRow(Map<String, dynamic> faculty, int index) {
    final fullName = '${faculty['last_name']}, ${faculty['first_name']} ${faculty['middle_name'] != null ? '${faculty['middle_name'][0]}.' : ''}';
    
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
            child: CircleAvatar(
              radius: 16,
              backgroundColor: faculty['profilePhotoUrl'] != null ? Colors.transparent : const Color(0xFF90caf9),
              backgroundImage: faculty['profilePhotoUrl'] != null 
                  ? NetworkImage(faculty['profilePhotoUrl']) 
                  : null,
              child: faculty['profilePhotoUrl'] == null 
                  ? Text(
                      faculty['first_name'][0].toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    )
                  : null,
            ),
          ),
          // Full Name
          Expanded(
            flex: 2,
            child: Text(
              fullName,
              style: GoogleFonts.inter(fontSize: 14),
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
          // Username
          Expanded(
            flex: 1,
            child: Text(
              faculty['username'] ?? '',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(faculty['status']).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(faculty['status']),
                  width: 1,
                ),
              ),
              child: Text(
                _getStatusText(faculty['status']),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _getStatusColor(faculty['status']),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Actions
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _handleDeleteAccount(faculty['_id']),
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  iconSize: 20,
                ),
                IconButton(
                  onPressed: () {
                    // Handle block action
                  },
                  icon: const Icon(Icons.block_rounded, color: Colors.orange),
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'forverification':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'forverification':
        return 'For Verification';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _buildPagination() {
    final totalPages = (filteredFacultyList.length / rowsPerPage).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page * rowsPerPage + 1} to ${(page + 1) * rowsPerPage.clamp(0, filteredFacultyList.length)} of ${filteredFacultyList.length} entries',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          Row(
            children: [
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

  Widget _buildAddFacultyModal() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Faculty',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _buildFormField('First Name', 'first_name', true),
              _buildFormField('Last Name', 'last_name', true),
              _buildFormField('Middle Name', 'middle_name', false),
              _buildFormField('Email', 'email', true),
              _buildFormField('Password', 'password', true, isPassword: true),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _handleCloseModal,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _handleAddAccount,
                    child: const Text('Add Faculty'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, String key, bool required, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: label + (required ? ' *' : ''),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                )
              : null,
        ),
        obscureText: isPassword && !showPassword,
        onChanged: (value) {
          setState(() {
            newFaculty[key] = value;
            if (key == 'first_name' || key == 'last_name') {
              newFaculty['username'] = _generateUsername(
                newFaculty['first_name'] ?? '',
                newFaculty['last_name'] ?? '',
              );
            }
          });
        },
      ),
    );
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

  Future<bool?> _showConfirmDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
        );
      },
    );
  }
}
