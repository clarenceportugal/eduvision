import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/schedule_model.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/timeline_chart.dart';
import '../../widgets/common/responsive_table.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../utils/error_handler.dart';
import '../../main.dart' show LoginScreen, ThemeProvider;
import '../face_registration_screen.dart';
import '../../widgets/add_dean_modal.dart';
import '../../widgets/add_instructor_modal.dart';
import '../../widgets/add_program_chair_modal.dart';
import '../../widgets/edit_user_modal.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SuperadminDashboardScreen({super.key, required this.userData});

  @override
  State<SuperadminDashboardScreen> createState() => _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;
  int _currentTabIndex = 0;

  // State variables
  Map<String, int> counts = {
    'dean': 0,
    'programChairperson': 0,
    'instructor': 0,
    'superadmin': 0,
  };
  List<dynamic> allFacultiesLogs = [];
  List<Schedule> schedules = [];
  List<dynamic> colleges = [];
  List<dynamic> rooms = [];
  List<dynamic> programs = [];
  bool loading = false;
  bool isRefreshing = false;
  String? errorMessage;

  String courseName = "";
  String collegeName = "";

  // Filter values
  String collegeValue = "all";
  String courseValue = "all";
  String roomValue = "all";
  bool loadingCourses = false;
  bool loadingColleges = false;
  bool loadingSchedules = false;

  // New state variables for consolidated screens
  List<dynamic> deansList = [];
  List<dynamic> instructorsList = [];
  List<dynamic> programChairsList = [];
  List<dynamic> pendingDeans = [];
  List<dynamic> pendingInstructors = [];
  List<dynamic> pendingProgramChairs = [];
  List<dynamic> allUsersList = [];
  bool allUsersLoading = false;
  String? allUsersErrorMessage;
  bool isLive = false;
  String? streamUrl;
  String? streamKey;
  bool liveLoading = false;
  String? liveErrorMessage;
  Map<String, dynamic> userData = {};
  bool settingsLoading = false;
  String? settingsErrorMessage;
  bool notificationsEnabled = true;

  // Search and filtering state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedRole = 'all';
  String _selectedCollege = 'all';
  List<dynamic> _filteredUsers = [];
  bool _isSearching = false;
  
  // Pagination state
  int _currentPage = 0;
  int _rowsPerPage = 10;
  List<int> _rowsPerPageOptions = [5, 10, 25, 50];

  // Modal state
  bool _showAddDeanModal = false;
  bool _showAddInstructorModal = false;
  bool _showAddProgramChairModal = false;
  bool _showEditUserModal = false;
  Map<String, dynamic> _selectedUser = {};

  // Chart data for timeline visualization
  List<Map<String, dynamic>> chartData = [];

  // Keep alive for better performance
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _initializeAnimations();
    _initializeData();
    _loadNotificationSetting();
    userData = widget.userData;
  }

  void _initializeTabController() {
    _tabController = TabController(length: 11, vsync: this); // 11 tabs total
    print('TabController created with length: ${_tabController.length}');
    print('Expected tabs: 11, TabBarView children: 11, TabBar tabs: 11');
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        final newIndex = _tabController.index;
        print('Tab changed to index: $newIndex');
        
        // Safety check for valid index
        if (newIndex >= 0 && newIndex < _tabController.length) {
        setState(() {
            _currentTabIndex = newIndex;
        });
        _loadTabData();
          
          // Trigger animation for tab change
          _animationController.reset();
          _animationController.forward();
        } else {
          print('Invalid tab index: $newIndex, length: ${_tabController.length}');
        }
      }
    });
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

    // Delay animation start to prevent memory issues
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    setState(() {
      settingsLoading = true;
      settingsErrorMessage = null;
    });
    
    try {
      final userData = await ApiService.getUserData();
      if (mounted) {
        setState(() {
          courseName = userData['course'] ?? '';
          collegeName = userData['college'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          settingsErrorMessage = 'Failed to load user data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          settingsLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('notifications_enabled');
      if (mounted) {
        setState(() {
          notificationsEnabled = saved ?? true; // Default to true
        });
      }
    } catch (e) {
      print('Error loading notification setting: $e');
    }
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (e) {
      print('Error saving notification setting: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // Fetch data in parallel for better performance
      await Future.wait([
        _fetchUserCounts(),
        _fetchColleges(),
        _fetchRooms(),
        _fetchSchedules(),
        _fetchAllFacultiesLogs(),
        _fetchDeansList(),
        _fetchInstructorsList(),
        _fetchProgramChairsList(),
        _fetchPendingDeans(),
        _fetchPendingInstructors(),
        _fetchPendingProgramChairs(),
        _loadAllUsers(), // Load all users for fallback debugging
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = ErrorHandler.getErrorMessage(e);
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

  Future<void> _refreshData() async {
    if (!mounted) return;
    
    setState(() {
      isRefreshing = true;
      errorMessage = null;
    });

    try {
      await _fetchData();
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchUserCounts() async {
    if (!mounted) return;
    
    try {
      print('Fetching user counts...');
      final data = await ApiService.getSuperadminUserCounts();
      print('User counts received: $data');
      if (mounted) {
        setState(() {
          counts = Map<String, int>.from(data);
        });
        print('Counts updated in state: $counts');
      }
    } catch (error) {
      print('Error fetching user counts: $error');
      if (mounted) {
        setState(() {
          counts = {
            'deans': 0,
            'instructors': 0,
            'programChairs': 0,
            'pendingDeans': 0,
            'pendingInstructors': 0,
            'pendingProgramChairs': 0,
            'totalUsers': 0,
          };
        });
      }
    }
  }

  Future<void> _fetchColleges() async {
    if (!mounted) return;
    
    try {
      setState(() => loadingColleges = true);
      final data = await ApiService.getSuperadminColleges();
      if (mounted) {
        setState(() {
          colleges = data;
        });
      }
    } catch (error) {
      // 
    } finally {
      if (mounted) {
        setState(() => loadingColleges = false);
      }
    }
  }

  Future<void> _fetchRooms() async {
    if (!mounted || collegeName.isEmpty) return;
    
    try {
      final data = await ApiService.getSuperadminRooms(collegeName);
      if (mounted) {
        setState(() {
          rooms = data;
        });
      }
    } catch (error) {
      // 
    }
  }

  Future<void> _fetchSchedules() async {
    if (!mounted) return;
    
    setState(() {
      loadingSchedules = true;
    });
    
    try {
      print('Fetching schedules...');
      print('Current courseValue: $courseValue');
      
      final shortCourseValue = courseValue == "all" ? "" : courseValue.replaceAll(RegExp(r'^bs', caseSensitive: false), '').toUpperCase();
      print('Short course value: $shortCourseValue');
      
      final data = await ApiService.getSuperadminSchedules(shortCourseValue);
      print('Schedules fetched: ${data.length} items');
      
      if (mounted) {
        setState(() {
          schedules = data.map((item) => Schedule.fromJson(item)).toList();
          _generateChartData();
        });
        print('Schedules updated in state: ${schedules.length} items');
      }
    } catch (error) {
      print('Error fetching schedules: $error');
      if (mounted) {
        setState(() {
          schedules = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingSchedules = false;
        });
      }
    }
  }

  Future<void> _fetchAllFacultiesLogs() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      final data = await ApiService.getSuperadminFacultyLogs(courseName);
      if (mounted) {
        setState(() {
          allFacultiesLogs = data;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          allFacultiesLogs = _getSampleFacultyLogs();
        });
      }
    }
  }

  Future<void> _fetchDeansList() async {
    if (!mounted) return;
    
    try {
      final data = await ApiService.getSuperadminDeans();
      if (mounted) {
        setState(() {
          deansList = data;
        });
        
        // If no deans found, try to get all users as fallback for debugging
        if (data.isEmpty) {
          print('No deans found, fetching all users for debugging...');
          final allUsers = await ApiService.getAllUsers();
          print('All users available: ${allUsers.length}');
          if (allUsers.isNotEmpty) {
            print('Sample user structure: ${allUsers.first}');
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          deansList = [];
        });
      }
    }
  }

  Future<void> _fetchInstructorsList() async {
    if (!mounted) return;
    
    try {
      final data = await ApiService.getSuperadminInstructors();
      if (mounted) {
        setState(() {
          instructorsList = data;
        });
        
        // If no instructors found, try to get all users as fallback for debugging
        if (data.isEmpty) {
          print('No instructors found, fetching all users for debugging...');
          final allUsers = await ApiService.getAllUsers();
          print('All users available: ${allUsers.length}');
          if (allUsers.isNotEmpty) {
            print('Sample user structure: ${allUsers.first}');
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          instructorsList = [];
        });
      }
    }
  }

  Future<void> _fetchProgramChairsList() async {
    if (!mounted) return;
    
    try {
      final data = await ApiService.getSuperadminProgramChairs();
      if (mounted) {
        setState(() {
          programChairsList = data;
        });
        
        // If no program chairs found, try to get all users as fallback for debugging
        if (data.isEmpty) {
          print('No program chairs found, fetching all users for debugging...');
          final allUsers = await ApiService.getAllUsers();
          print('All users available: ${allUsers.length}');
          if (allUsers.isNotEmpty) {
            print('Sample user structure: ${allUsers.first}');
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          programChairsList = [];
        });
      }
    }
  }

  Future<void> _loadAllUsers() async {
    if (!mounted) return;
    
    setState(() {
      allUsersLoading = true;
      allUsersErrorMessage = null;
    });
    
    try {
      final data = await ApiService.getAllUsers();
      if (mounted) {
        setState(() {
          allUsersList = data;
          allUsersLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          allUsersList = [];
          allUsersLoading = false;
          allUsersErrorMessage = 'Failed to load users: ${error.toString()}';
        });
      }
    }
  }

  Future<void> _fetchPendingDeans() async {
    if (!mounted) return;
    
    try {
      final data = await ApiService.getSuperadminPendingDeans();
      if (mounted) {
        setState(() {
          pendingDeans = data;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          pendingDeans = _getSamplePendingDeansData();
        });
      }
    }
  }

  Future<void> _fetchPendingInstructors() async {
    if (!mounted) return;
    
    try {
      final data = await ApiService.getSuperadminPendingInstructors();
      if (mounted) {
        setState(() {
          pendingInstructors = data;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          pendingInstructors = _getSamplePendingInstructorsData();
        });
      }
    }
  }

  Future<void> _fetchPendingProgramChairs() async {
    if (!mounted) return;
    
    try {
      final data = await ApiService.getSuperadminPendingProgramChairs();
      if (mounted) {
        setState(() {
          pendingProgramChairs = data;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          pendingProgramChairs = _getSamplePendingProgramChairsData();
        });
      }
    }
  }

  Future<void> _handleCollegeChange(String code) async {
    setState(() {
      collegeValue = code;
      courseValue = "all";
    });

    setState(() => loadingCourses = true);
    try {
      final data = await ApiService.getSuperadminCourses(code);
      if (mounted) {
        setState(() {
          programs = data;
        });
      }
      
      // Fetch rooms and schedules for the new college
      await _fetchRooms();
      await _fetchSchedules();
    } catch (error) {
      print('Error in college change: $error');
    } finally {
      if (mounted) {
        setState(() => loadingCourses = false);
      }
    }
  }

  void _handleCourseChange(String value) {
    setState(() {
      courseValue = value;
    });
    _fetchSchedules();
  }

  void _handleRoomChange(String value) {
    setState(() {
      roomValue = value;
    });
  }

  void _generateChartData() {
    final today = DateTime.now();
    final year = today.year;
    final month = today.month;
    final date = today.day;

    final formattedData = <Map<String, dynamic>>[];

    for (final schedule in schedules) {
      final startTimeParts = schedule.startTime.split(':');
      final endTimeParts = schedule.endTime.split(':');
      
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endHour = int.parse(endTimeParts[0]);
      final endMinute = int.parse(endTimeParts[1]);

      formattedData.add({
        'instructor': '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
        'subject': schedule.courseCode,
        'startTime': DateTime(year, month, date, startHour, startMinute),
        'endTime': DateTime(year, month, date, endHour, endMinute),
        'room': schedule.room,
        'section': schedule.section.sectionName,
        'courseTitle': schedule.courseTitle,
      });
    }

    setState(() {
      chartData = formattedData;
    });
  }

  Future<void> _loadTabData() async {
    switch (_currentTabIndex) {
      case 1: // Deans
        await _fetchDeansList();
        break;
      case 2: // Instructors
        await _fetchInstructorsList();
        break;
      case 3: // Program Chairs
        await _fetchProgramChairsList();
        break;
      case 4: // Pending Deans
        await _fetchPendingDeans();
        break;
      case 5: // Pending Instructors
        await _fetchPendingInstructors();
        break;
      case 6: // Pending Program Chairs
        await _fetchPendingProgramChairs();
        break;
      case 7: // All Users
        await _loadAllUsers();
        break;
      case 8: // Schedule
        await _fetchSchedules();
        break;
      case 9: // Live Video
        await _checkLiveStatus();
        break;
      case 10: // Settings
        print('Loading settings tab data...');
        await _loadUserData();
        print('Settings tab data loaded');
        break;
    }
  }

  // Search and filtering methods
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      _currentPage = 0; // Reset to first page when searching
    });
    _filterUsers();
  }

  void _filterUsers() {
    List<dynamic> usersToFilter = [];
    
    switch (_currentTabIndex) {
      case 1: // Deans
        usersToFilter = deansList;
        break;
      case 2: // Instructors
        usersToFilter = instructorsList;
        break;
      case 3: // Program Chairs
        usersToFilter = programChairsList;
        break;
      case 4: // Pending Deans
        usersToFilter = pendingDeans;
        break;
      case 5: // Pending Instructors
        usersToFilter = pendingInstructors;
        break;
      case 6: // Pending Program Chairs
        usersToFilter = pendingProgramChairs;
        break;
      case 7: // All Users
        usersToFilter = allUsersList;
        break;
    }

    setState(() {
      _filteredUsers = usersToFilter.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            user['firstName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            user['lastName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            user['email']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            user['username']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) == true;

        final matchesStatus = _selectedStatus == 'all' ||
            user['status']?.toString().toLowerCase() == _selectedStatus.toLowerCase();

        final matchesRole = _selectedRole == 'all' ||
            user['role']?.toString().toLowerCase() == _selectedRole.toLowerCase();

        final matchesCollege = _selectedCollege == 'all' ||
            user['college']?.toString().toLowerCase().contains(_selectedCollege.toLowerCase()) == true;

        return matchesSearch && matchesStatus && matchesRole && matchesCollege;
      }).toList();
    });
  }

  void _onStatusFilterChanged(String status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 0; // Reset to first page when filtering
    });
    _filterUsers();
  }

  void _onRoleFilterChanged(String role) {
    setState(() {
      _selectedRole = role;
      _currentPage = 0; // Reset to first page when filtering
    });
    _filterUsers();
  }

  void _onCollegeFilterChanged(String college) {
    setState(() {
      _selectedCollege = college;
      _currentPage = 0; // Reset to first page when filtering
    });
    _filterUsers();
  }

  // Pagination methods
  void _handleChangePage(int newPage) {
    setState(() {
      _currentPage = newPage;
    });
  }

  void _handleChangeRowsPerPage(int newRowsPerPage) {
    setState(() {
      _rowsPerPage = newRowsPerPage;
      _currentPage = 0; // Reset to first page
    });
  }

  List<dynamic> _getPaginatedUsers(List<dynamic> users) {
    if (users.isEmpty) return [];
    
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, users.length);
    
    // Ensure startIndex is within bounds
    if (startIndex >= users.length) {
      return [];
    }
    
    return users.sublist(startIndex, endIndex);
  }

  Widget _buildPaginationControls(List<dynamic> users) {
    if (users.isEmpty) return const SizedBox.shrink();
    
    // Calculate total pages safely
    final totalPages = (users.length / _rowsPerPage).ceil();
    final safeCurrentPage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = safeCurrentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, users.length);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          
          if (isMobile) {
            // Mobile layout - stack vertically
            return Column(
              children: [
                Text(
                  'Showing ${startIndex + 1} to $endIndex of ${users.length} entries',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Rows per page:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      items: _rowsPerPageOptions.map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          _handleChangeRowsPerPage(newValue);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: safeCurrentPage > 0 ? () => _handleChangePage(safeCurrentPage - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${safeCurrentPage + 1} of $totalPages'),
                    IconButton(
                      onPressed: safeCurrentPage < totalPages - 1 
                          ? () => _handleChangePage(safeCurrentPage + 1) 
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          } else {
            // Desktop layout - use flex widgets
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Showing ${startIndex + 1} to $endIndex of ${users.length} entries',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Rows per page:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _rowsPerPage,
                        items: _rowsPerPageOptions.map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            _handleChangeRowsPerPage(newValue);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: safeCurrentPage > 0 ? () => _handleChangePage(safeCurrentPage - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('${safeCurrentPage + 1} of $totalPages'),
                      IconButton(
                        onPressed: safeCurrentPage < totalPages - 1 
                            ? () => _handleChangePage(safeCurrentPage + 1) 
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // Modal methods
  void _openAddDeanModal() {
    setState(() {
      _showAddDeanModal = true;
    });
  }

  void _closeAddDeanModal() {
    setState(() {
      _showAddDeanModal = false;
    });
  }

  void _openAddInstructorModal() {
    setState(() {
      _showAddInstructorModal = true;
    });
  }

  void _closeAddInstructorModal() {
    setState(() {
      _showAddInstructorModal = false;
    });
  }

  void _openAddProgramChairModal() {
    setState(() {
      _showAddProgramChairModal = true;
    });
  }

  void _closeAddProgramChairModal() {
    setState(() {
      _showAddProgramChairModal = false;
    });
  }

  void _openEditUserModal(Map<String, dynamic> user) {
    setState(() {
      _selectedUser = user;
      _showEditUserModal = true;
    });
  }

  void _closeEditUserModal() {
    setState(() {
      _showEditUserModal = false;
      _selectedUser = {};
    });
  }

  // User management methods
  Future<void> _handleAddDean(Map<String, dynamic> deanData) async {
    try {
      await ApiService.addDean(deanData);
      await _fetchDeansList();
      await _fetchUserCounts();
      ErrorHandler.showSnackBar(context, 'Dean added successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to add dean: $e');
    }
  }

  Future<void> _handleAddInstructor(Map<String, dynamic> instructorData) async {
    try {
      await ApiService.addInstructor(instructorData);
      await _fetchInstructorsList();
      await _fetchUserCounts();
      ErrorHandler.showSnackBar(context, 'Instructor added successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to add instructor: $e');
    }
  }

  Future<void> _handleAddProgramChair(Map<String, dynamic> programChairData) async {
    try {
      await ApiService.addProgramChair(programChairData);
      await _fetchProgramChairsList();
      await _fetchUserCounts();
      ErrorHandler.showSnackBar(context, 'Program Chair added successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to add program chair: $e');
    }
  }

  Future<void> _handleUpdateUser(Map<String, dynamic> userData) async {
    try {
      await ApiService.updateUser(_selectedUser['id'], userData);
      await _loadTabData(); // Refresh current tab data
      await _fetchUserCounts();
      ErrorHandler.showSnackBar(context, 'User updated successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to update user: $e');
    }
  }

  Future<void> _handleDeleteUser(String userId, String userRole) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this ${userRole.toLowerCase()}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      switch (userRole.toLowerCase()) {
        case 'dean':
          await ApiService.deleteDean(userId);
          await _fetchDeansList();
          break;
        case 'instructor':
          await ApiService.deleteInstructor(userId);
          await _fetchInstructorsList();
          break;
        case 'programchairperson':
        case 'program_chair':
          await ApiService.deleteProgramChair(userId);
          await _fetchProgramChairsList();
          break;
        default:
          throw Exception('Unknown user role: $userRole');
      }
      await _fetchUserCounts();
      ErrorHandler.showSnackBar(context, 'User deleted successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to delete user: $e');
    }
  }

  // Data fetching methods for consolidated screens

  Future<void> _checkLiveStatus() async {
    if (!mounted) return;
    
    setState(() {
      liveLoading = true;
      liveErrorMessage = null;
    });

    try {
      final userData = await ApiService.getUserData();
      final collegeName = userData['college'] ?? '';
      
      if (collegeName.isNotEmpty) {
        final status = await ApiService.getDeanLiveStatus(collegeName);
        if (mounted) {
          setState(() {
            isLive = status['isLive'] ?? false;
            streamUrl = status['streamUrl'];
            streamKey = status['streamKey'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          liveErrorMessage = ErrorHandler.getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          liveLoading = false;
        });
      }
    }
  }

  Future<void> _startLiveStream() async {
    if (!mounted) return;
    
    setState(() {
      liveLoading = true;
      liveErrorMessage = null;
    });

    try {
      final userData = await ApiService.getUserData();
      final collegeName = userData['college'] ?? '';
      
      if (collegeName.isNotEmpty) {
        final result = await ApiService.startDeanLiveStream(collegeName);
        if (mounted) {
          setState(() {
            isLive = true;
            streamUrl = result['streamUrl'];
            streamKey = result['streamKey'];
          });
          ErrorHandler.showSuccessDialog(context, 'Live stream started successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          liveErrorMessage = ErrorHandler.getErrorMessage(e);
        });
        ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          liveLoading = false;
        });
      }
    }
  }

  Future<void> _stopLiveStream() async {
    if (!mounted) return;
    
    setState(() {
      liveLoading = true;
      liveErrorMessage = null;
    });

    try {
      final userData = await ApiService.getUserData();
      final collegeName = userData['college'] ?? '';
      
      if (collegeName.isNotEmpty) {
        await ApiService.stopDeanLiveStream(collegeName);
        if (mounted) {
          setState(() {
            isLive = false;
            streamUrl = null;
            streamKey = null;
          });
          ErrorHandler.showSuccessDialog(context, 'Live stream stopped successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          liveErrorMessage = ErrorHandler.getErrorMessage(e);
        });
        ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          liveLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await ApiService.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
                }
              },
              child: Text(
                'Logout',
                style: GoogleFonts.inter(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 48),
        child: _buildAppBar(),
      ),
      body: Stack(
        children: [
          TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildDeansTab(),
          _buildInstructorsTab(),
          _buildProgramChairsTab(),
          _buildPendingDeansTab(),
          _buildPendingInstructorsTab(),
          _buildPendingProgramChairsTab(),
              _buildAllUsersTab(),
              _buildScheduleTab(),
          _buildLiveVideoTab(),
          _buildSettingsTab(),
            ],
          ),
          // Add Dean Modal
          AddDeanModal(
            isOpen: _showAddDeanModal,
            onClose: _closeAddDeanModal,
            onAddDean: _handleAddDean,
            colleges: colleges,
          ),
          // Add Instructor Modal
          AddInstructorModal(
            isOpen: _showAddInstructorModal,
            onClose: _closeAddInstructorModal,
            onAddInstructor: _handleAddInstructor,
            colleges: colleges,
          ),
          // Add Program Chair Modal
          AddProgramChairModal(
            isOpen: _showAddProgramChairModal,
            onClose: _closeAddProgramChairModal,
            onAddProgramChair: _handleAddProgramChair,
            colleges: colleges,
          ),
          // Edit User Modal
          EditUserModal(
            isOpen: _showEditUserModal,
            onClose: _closeEditUserModal,
            onUpdateUser: _handleUpdateUser,
            user: _selectedUser,
            colleges: colleges,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      title: Text(
        'Superadmin Dashboard',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
          tabAlignment: TabAlignment.start,
        indicatorColor: Theme.of(context).colorScheme.primary,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
        tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 16), text: 'Dashboard'),
            Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 16), text: 'Deans'),
            Tab(icon: Icon(Icons.person_rounded, size: 16), text: 'Instructors'),
            Tab(icon: Icon(Icons.school_rounded, size: 16), text: 'Program Chairs'),
            Tab(icon: Icon(Icons.hourglass_empty_rounded, size: 16), text: 'Pending Deans'),
            Tab(icon: Icon(Icons.pending_actions_rounded, size: 16), text: 'Pending Instructors'),
            Tab(icon: Icon(Icons.pending_actions_rounded, size: 16), text: 'Pending Program Chairs'),
            Tab(icon: Icon(Icons.people_rounded, size: 16), text: 'All Users'),
            Tab(icon: Icon(Icons.schedule_rounded, size: 16), text: 'Schedule'),
            Tab(icon: Icon(Icons.videocam_rounded, size: 16), text: 'Live Video'),
            Tab(icon: Icon(Icons.settings_rounded, size: 16), text: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (errorMessage != null)
            SliverToBoxAdapter(
              child: ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _refreshData),
            )
          else
            SliverToBoxAdapter(
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
                        _buildStatisticsCards(),
                        const SizedBox(height: 24),
                        _buildScheduleChart(),
                        const SizedBox(height: 24),
                        _buildSchedulesTable(),
                        const SizedBox(height: 24),
                        _buildTodayActivity(),
                        const SizedBox(height: 100),
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

  Widget _buildDeansTab() {
    return RefreshIndicator(
      onRefresh: _fetchDeansList,
      child: errorMessage != null
          ? ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchDeansList)
          : loading
              ? const LoadingWidget(message: 'Loading deans...')
              : _buildDeansList(),
    );
  }

  Widget _buildInstructorsTab() {
    return RefreshIndicator(
      onRefresh: _fetchInstructorsList,
      child: errorMessage != null
          ? ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchInstructorsList)
          : loading
              ? const LoadingWidget(message: 'Loading instructors...')
              : _buildInstructorsList(),
    );
  }

  Widget _buildProgramChairsTab() {
    return RefreshIndicator(
      onRefresh: _fetchProgramChairsList,
      child: errorMessage != null
          ? ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchProgramChairsList)
          : loading
              ? const LoadingWidget(message: 'Loading program chairs...')
              : _buildProgramChairsList(),
    );
  }

  Widget _buildPendingDeansTab() {
    return RefreshIndicator(
      onRefresh: _fetchPendingDeans,
      child: errorMessage != null
          ? ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchPendingDeans)
          : loading
              ? const LoadingWidget(message: 'Loading pending deans...')
              : _buildPendingDeansList(),
    );
  }

  Widget _buildPendingInstructorsTab() {
    return RefreshIndicator(
      onRefresh: _fetchPendingInstructors,
      child: errorMessage != null
          ? ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchPendingInstructors)
          : loading
              ? const LoadingWidget(message: 'Loading pending instructors...')
              : _buildPendingInstructorsList(),
    );
  }

  Widget _buildPendingProgramChairsTab() {
    return RefreshIndicator(
      onRefresh: _fetchPendingProgramChairs,
      child: errorMessage != null
          ? ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchPendingProgramChairs)
          : loading
              ? const LoadingWidget(message: 'Loading pending program chairs...')
              : _buildPendingProgramChairsList(),
    );
  }

  Widget _buildLiveVideoTab() {
    return RefreshIndicator(
      onRefresh: _checkLiveStatus,
      child: liveErrorMessage != null
          ? ErrorHandler.buildErrorWidget(liveErrorMessage!, onRetry: _checkLiveStatus)
          : liveLoading
              ? const LoadingWidget(message: 'Loading live stream status...')
              : _buildLiveVideoContent(),
    );
  }

  Widget _buildAllUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadAllUsers,
      child: allUsersErrorMessage != null
          ? ErrorHandler.buildErrorWidget(allUsersErrorMessage!, onRetry: _loadAllUsers)
          : allUsersLoading
              ? const LoadingWidget(message: 'Loading all users...')
              : _buildAllUsersList(),
    );
  }

  Widget _buildScheduleTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchSchedules();
        await _fetchColleges();
        await _fetchRooms();
      },
      child: _buildScheduleContent(),
    );
  }

  Widget _buildScheduleContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter controls
          _buildScheduleFilters(),
          const SizedBox(height: 24),
          // Schedule content
          if (loadingSchedules)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: LoadingWidget(message: 'Loading schedules...'),
              ),
            )
          else if (schedules.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: EmptyStateWidget(
                  icon: Icons.schedule_rounded,
                  title: 'No Schedules Found',
                  subtitle: 'There are no schedules for the selected filters.',
                ),
              ),
            )
          else ...[
            // Schedule chart
            _buildScheduleChart(),
            const SizedBox(height: 24),
            // Schedule table
            _buildSchedulesTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Schedules',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  'College',
                  collegeValue,
                  colleges.map<DropdownMenuItem<String>>((college) => DropdownMenuItem<String>(
                    value: college['code'],
                    child: Text(
                      college['name'],
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  (value) => _handleCollegeChange(value!),
                  loadingColleges,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildDropdown(
                  'Course',
                  courseValue,
                  programs.map<DropdownMenuItem<String>>((program) => DropdownMenuItem<String>(
                    value: program['code'].toString().toLowerCase(),
                    child: Text(
                      program['code'].toString().toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  (value) => _handleCourseChange(value!),
                  loadingCourses,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildDropdown(
                  'Room',
                  roomValue,
                  rooms.map<DropdownMenuItem<String>>((room) => DropdownMenuItem<String>(
                    value: room['name'],
                    child: Text(
                      room['name'],
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  (value) => _handleRoomChange(value!),
                  false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    print('Building settings tab - loading: $settingsLoading, error: $settingsErrorMessage');
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: settingsErrorMessage != null
          ? ErrorHandler.buildErrorWidget(settingsErrorMessage!, onRetry: _loadUserData)
          : settingsLoading
              ? const LoadingWidget(message: 'Loading settings...')
              : _buildSettingsContent(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by name, email, or username...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterControls() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, email, or username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter controls
          Row(
            children: [
              // Status filter
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'forverification', child: Text('For Verification')),
                  ],
                  onChanged: (value) => _onStatusFilterChanged(value ?? 'all'),
                ),
              ),
              const SizedBox(width: 12),
              
              // Role filter
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Roles')),
                    DropdownMenuItem(value: 'dean', child: Text('Dean')),
                    DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                    DropdownMenuItem(value: 'programchairperson', child: Text('Program Chair')),
                  ],
                  onChanged: (value) => _onRoleFilterChanged(value ?? 'all'),
                ),
              ),
              
              // College filter (only for program chairs)
              if (_currentTabIndex == 3) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCollege,
                    decoration: const InputDecoration(
                      labelText: 'College',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Colleges')),
                      ...colleges.map<DropdownMenuItem<String>>((college) {
                        return DropdownMenuItem<String>(
                          value: college['name']?.toString() ?? '',
                          child: Text(
                            college['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) => _onCollegeFilterChanged(value ?? 'all'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeansList() {
    final usersToShow = _isSearching ? _filteredUsers : deansList;
    final paginatedUsers = _getPaginatedUsers(usersToShow);
    
    return Column(
      children: [
        // Search bar only (no dropdown filters)
        _buildSearchBar(),
        
        // Add Dean button
        Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deans (${usersToShow.length})',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddDeanModal,
                icon: const Icon(Icons.add),
                label: const Text('Add Dean'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D1308),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: usersToShow.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'No Deans Found',
                  subtitle: 'There are no deans matching your search criteria.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
      padding: const EdgeInsets.all(16),
                        itemCount: paginatedUsers.length,
      itemBuilder: (context, index) {
                          final dean = paginatedUsers[index];
        return _buildDeanCard(dean, index);
      },
                      ),
                    ),
                    _buildPaginationControls(usersToShow),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInstructorsList() {
    final usersToShow = _isSearching ? _filteredUsers : instructorsList;
    final paginatedUsers = _getPaginatedUsers(usersToShow);
    
    return Column(
      children: [
        // Search bar only (no dropdown filters)
        _buildSearchBar(),
        
        // Add Instructor button
        Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Instructors (${usersToShow.length})',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddInstructorModal,
                icon: const Icon(Icons.add),
                label: const Text('Add Instructor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D1308),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: usersToShow.isEmpty
              ? const EmptyStateWidget(
        icon: Icons.person_rounded,
        title: 'No Instructors Found',
                  subtitle: 'There are no instructors matching your search criteria.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
      padding: const EdgeInsets.all(16),
                        itemCount: paginatedUsers.length,
      itemBuilder: (context, index) {
                          final instructor = paginatedUsers[index];
        return _buildInstructorCard(instructor, index);
      },
                      ),
                    ),
                    _buildPaginationControls(usersToShow),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProgramChairsList() {
    final usersToShow = _isSearching ? _filteredUsers : programChairsList;
    final paginatedUsers = _getPaginatedUsers(usersToShow);
    
    return Column(
      children: [
        // Search bar only (no dropdown filters)
        _buildSearchBar(),
        
        // Add Program Chair button
        Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Program Chairs (${usersToShow.length})',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddProgramChairModal,
                icon: const Icon(Icons.add),
                label: const Text('Add Program Chair'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D1308),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: usersToShow.isEmpty
              ? const EmptyStateWidget(
        icon: Icons.school_rounded,
        title: 'No Program Chairs Found',
                  subtitle: 'There are no program chairs matching your search criteria.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: paginatedUsers.length,
                        itemBuilder: (context, index) {
                          final programChair = paginatedUsers[index];
                          return _buildProgramChairCard(programChair, index);
                        },
                      ),
                    ),
                    _buildPaginationControls(usersToShow),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAllUsersList() {
    final usersToShow = _isSearching ? _filteredUsers : allUsersList;
    final paginatedUsers = _getPaginatedUsers(usersToShow);
    
    return Column(
      children: [
        // Search and filter controls
        _buildSearchAndFilterControls(),
        
        // Users list
        Expanded(
          child: usersToShow.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.people_rounded,
                  title: 'No Users Found',
                  subtitle: 'There are no users matching your search criteria.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
      padding: const EdgeInsets.all(16),
                        itemCount: paginatedUsers.length,
      itemBuilder: (context, index) {
                          final user = paginatedUsers[index];
                          return _buildUserCard(user, index);
                        },
                      ),
                    ),
                    _buildPaginationControls(usersToShow),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPendingDeansList() {
    if (pendingDeans.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.hourglass_empty_rounded,
        title: 'No Pending Deans',
        subtitle: 'All dean applications have been processed.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingDeans.length,
      itemBuilder: (context, index) {
        final dean = pendingDeans[index];
        return _buildPendingDeanCard(dean, index);
      },
    );
  }

  Widget _buildPendingInstructorsList() {
    if (pendingInstructors.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pending_actions_rounded,
        title: 'No Pending Instructors',
        subtitle: 'All instructor applications have been processed.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingInstructors.length,
      itemBuilder: (context, index) {
        final instructor = pendingInstructors[index];
        return _buildPendingInstructorCard(instructor, index);
      },
    );
  }

  Widget _buildPendingProgramChairsList() {
    if (pendingProgramChairs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pending_actions_rounded,
        title: 'No Pending Program Chairs',
        subtitle: 'All program chair applications have been processed.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingProgramChairs.length,
      itemBuilder: (context, index) {
        final programChair = pendingProgramChairs[index];
        return _buildPendingProgramChairCard(programChair, index);
      },
    );
  }

  Widget _buildDeanCard(Map<String, dynamic> dean, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dean['firstName'] ?? ''} ${dean['lastName'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  dean['email'] ?? 'No email',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'College: ${dean['college'] ?? 'Not specified'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openEditUserModal(dean);
                  break;
                case 'delete':
                  _showDeleteUserDialog(dean);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorCard(Map<String, dynamic> instructor, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person_rounded,
              color: Colors.blue.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  instructor['email'] ?? 'No email',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'College: ${instructor['college'] ?? 'Not specified'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openEditUserModal(instructor);
                  break;
                case 'delete':
                  _showDeleteUserDialog(instructor);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgramChairCard(Map<String, dynamic> programChair, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.school_rounded,
              color: Colors.green.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${programChair['firstName'] ?? ''} ${programChair['lastName'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  programChair['email'] ?? 'No email',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'College: ${programChair['college'] ?? 'Not specified'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openEditUserModal(programChair);
                  break;
                case 'delete':
                  _showDeleteUserDialog(programChair);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    // Determine icon and color based on role
    IconData icon;
    Color iconColor;
    
    switch (user['role']?.toString().toLowerCase()) {
      case 'dean':
        icon = Icons.admin_panel_settings_rounded;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'instructor':
        icon = Icons.person_rounded;
        iconColor = Colors.blue.shade600;
        break;
      case 'programchairperson':
      case 'program_chair':
        icon = Icons.school_rounded;
        iconColor = Colors.green.shade600;
        break;
      default:
        icon = Icons.person_rounded;
        iconColor = Colors.grey.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  user['email'] ?? 'No email',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (user['college'] != null && user['college'] != 'No College')
                  Text(
                    user['college'] ?? 'No College',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user['role']?.toString().toUpperCase() ?? 'UNKNOWN',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: user['status'] == 'pending' 
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user['status']?.toString().toUpperCase() ?? 'ACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: user['status'] == 'pending' 
                                ? Colors.orange.shade600
                                : Colors.green.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'view':
                  // TODO: Implement view details functionality
                  ErrorHandler.showSnackBar(context, 'View details functionality not implemented yet');
                  break;
                case 'edit':
                  _openEditUserModal(user);
                  break;
                case 'delete':
                  _showDeleteUserDialog(user);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded),
                    SizedBox(width: 8),
                    Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDeanCard(Map<String, dynamic> dean, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dean['firstName'] ?? ''} ${dean['lastName'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      dean['email'] ?? 'No email',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('College', dean['college'] ?? 'Not specified'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem('Course', dean['course'] ?? 'Not specified'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Applied', _formatDate(dean['createdAt'])),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem('Status', 'Awaiting Approval'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAcceptDeanDialog(dean),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDeanDialog(dean),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInstructorCard(Map<String, dynamic> instructor, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.hourglass_empty_rounded,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${instructor['firstName'] ?? ''} ${instructor['lastName'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      instructor['email'] ?? 'No email',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('College', instructor['college'] ?? 'Not specified'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem('Course', instructor['course'] ?? 'Not specified'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Applied', _formatDate(instructor['createdAt'])),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem('Status', 'Awaiting Approval'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAcceptInstructorDialog(instructor),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectInstructorDialog(instructor),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingProgramChairCard(Map<String, dynamic> programChair, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${programChair['firstName'] ?? ''} ${programChair['lastName'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      programChair['email'] ?? 'No email',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('College', programChair['college'] ?? 'Not specified'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem('Course', programChair['course'] ?? 'Not specified'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem('Applied', _formatDate(programChair['createdAt'])),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem('Status', 'Awaiting Approval'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAcceptProgramChairDialog(programChair),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectProgramChairDialog(programChair),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Super Admin Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            // Database Health Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: errorMessage == null ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: errorMessage == null ? Colors.green.shade300 : Colors.red.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    errorMessage == null ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 16,
                    color: errorMessage == null ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    errorMessage == null ? 'DB Connected' : 'DB Issues',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: errorMessage == null ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Dashboard / Attendance',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Total Users per Role:',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final crossAxisCount = isTablet ? 4 : 2;
        
        // Show loading state if counts are empty
        if (counts.isEmpty) {
          return SizedBox(
            height: 200,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isTablet ? 1.4 : 1.2,
          children: [
            StatCard(
              title: 'Total Deans',
              value: counts['deans']?.toString() ?? '0',
              icon: Icons.school_rounded,
              iconColor: const Color(0xFF9f7aea),
              backgroundColor: const Color(0xFFf3e8ff),
            ),
            StatCard(
              title: 'Total Program Chairs',
              value: counts['programChairs']?.toString() ?? '0',
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFF9f7aea),
              backgroundColor: const Color(0xFFf3e8ff),
            ),
            StatCard(
              title: 'Total Instructors',
              value: counts['instructors']?.toString() ?? '0',
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF38bdf8),
              backgroundColor: const Color(0xFFe0f2fe),
            ),
            StatCard(
              title: 'Total Users',
              value: counts['totalUsers']?.toString() ?? '0',
              icon: Icons.admin_panel_settings_rounded,
              iconColor: const Color(0xFFec4899),
              backgroundColor: const Color(0xFFfce7f3),
            ),
            StatCard(
              title: 'Pending Deans',
              value: counts['pendingDeans']?.toString() ?? '0',
              icon: Icons.hourglass_empty_rounded,
              iconColor: const Color(0xFFf59e0b),
              backgroundColor: const Color(0xFFfef3c7),
            ),
            StatCard(
              title: 'Pending Instructors',
              value: counts['pendingInstructors']?.toString() ?? '0',
              icon: Icons.pending_actions_rounded,
              iconColor: const Color(0xFFf59e0b),
              backgroundColor: const Color(0xFFfef3c7),
            ),
            StatCard(
              title: 'Pending Program Chairs',
              value: counts['pendingProgramChairs']?.toString() ?? '0',
              icon: Icons.pending_actions_rounded,
              iconColor: const Color(0xFFf59e0b),
              backgroundColor: const Color(0xFFfef3c7),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today Schedule Chart',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  
                  if (isMobile) {
                    return Column(
                      children: [
                        _buildDropdown(
                          'College',
                          collegeValue,
                          colleges.map<DropdownMenuItem<String>>((college) => DropdownMenuItem<String>(
                            value: college['code'],
                            child: Text(college['name']),
                          )).toList(),
                          (value) => _handleCollegeChange(value!),
                          loadingColleges,
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          'Course',
                          courseValue,
                          programs.map<DropdownMenuItem<String>>((program) => DropdownMenuItem<String>(
                            value: program['code'].toString().toLowerCase(),
                            child: Text(program['code'].toString().toUpperCase()),
                          )).toList(),
                          (value) => _handleCourseChange(value!),
                          loadingCourses,
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(
                          'Room',
                          roomValue,
                          rooms.map<DropdownMenuItem<String>>((room) => DropdownMenuItem<String>(
                            value: room['name'],
                            child: Text(room['name']),
                          )).toList(),
                          (value) => _handleRoomChange(value!),
                          false,
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildDropdown(
                          'College',
                          collegeValue,
                          colleges.map<DropdownMenuItem<String>>((college) => DropdownMenuItem<String>(
                            value: college['code'],
                            child: Text(
                              college['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          (value) => _handleCollegeChange(value!),
                          loadingColleges,
                        ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildDropdown(
                          'Course',
                          courseValue,
                          programs.map<DropdownMenuItem<String>>((program) => DropdownMenuItem<String>(
                            value: program['code'].toString().toLowerCase(),
                            child: Text(
                              program['code'].toString().toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          (value) => _handleCourseChange(value!),
                          loadingCourses,
                        ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildDropdown(
                          'Room',
                          roomValue,
                          rooms.map<DropdownMenuItem<String>>((room) => DropdownMenuItem<String>(
                            value: room['name'],
                            child: Text(
                              room['name'],
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          (value) => _handleRoomChange(value!),
                          false,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          TimelineChart(
            chartData: chartData,
            loading: loading,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<DropdownMenuItem<String>> items, Function(String?) onChanged, bool loading) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return SizedBox(
          width: isMobile ? double.infinity : double.infinity,
          child: DropdownButtonFormField<String>(
            initialValue: value == "all" ? null : value,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            isExpanded: true,
            items: loading ? [
              DropdownMenuItem(
                value: null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Loading...',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ] : items,
            onChanged: loading ? null : onChanged,
          ),
        );
      },
    );
  }

  Widget _buildSchedulesTable() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Schedules Today',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ResponsiveTable(
            columns: const [
              'S. No',
              'Instructor',
              'Start Time',
              'End Time',
              'Room',
              'Section',
              'Course',
            ],
            data: schedules.asMap().entries.map((entry) {
              final index = entry.key;
              final schedule = entry.value;
              return {
                'S. No': '${index + 1}',
                'Instructor': '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
                'Start Time': schedule.startTime,
                'End Time': schedule.endTime,
                'Room': schedule.room,
                'Section': schedule.section.sectionName,
                'Course': '${schedule.courseTitle} (${schedule.courseCode})',
              };
            }).toList(),
            dataKeys: const [
              'S. No',
              'Instructor',
              'Start Time',
              'End Time',
              'Room',
              'Section',
              'Course',
            ],
            loading: loading,
            emptyMessage: 'No schedules found.',
          ),
        ],
      ),
    );
  }

  Widget _buildTodayActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today Activity',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          allFacultiesLogs.isEmpty
              ? Center(
                  child: Text(
                    'There is no current activity today.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allFacultiesLogs.length,
                  itemBuilder: (context, index) {
                    final log = allFacultiesLogs[index];
                    return _buildActivityItem(log, index);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> log, int index) {
    final entries = <Map<String, String>>[];
    
    if (log['timeIn'] != null) {
      entries.add({'label': 'Time In', 'time': log['timeIn']});
    }
    if (log['timeout'] != null) {
      entries.add({'label': 'Time Out', 'time': log['timeout']});
    }

    return Column(
      children: entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry['label']} of ${log['instructorName'] ?? 'Unknown Instructor'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(entry['time']!),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final ampm = hour < 12 ? 'AM' : 'PM';
      return '$hour12:$minute $ampm';
    } catch (e) {
      return 'Invalid time';
    }
  }

  Widget _buildLiveVideoContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusCard(),
          const SizedBox(height: 24),
          _buildStreamControls(),
          const SizedBox(height: 24),
          if (isLive && streamUrl != null) _buildStreamInfo(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? Colors.green.shade300 : Colors.red.shade300,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isLive ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              color: isLive ? Colors.green.shade600 : Colors.red.shade600,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLive ? 'Live Stream Active' : 'Live Stream Inactive',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  isLive 
                      ? 'Stream is currently broadcasting'
                      : 'Stream is not currently active',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLive ? Colors.green.shade300 : Colors.red.shade300,
              ),
            ),
            child: Text(
              isLive ? 'LIVE' : 'OFFLINE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isLive ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stream Controls',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLive ? null : _startLiveStream,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Stream'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLive ? _stopLiveStream : null,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop Stream'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stream Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoItem('Stream URL', streamUrl ?? 'Not available'),
          const SizedBox(height: 12),
          _buildInfoItem('Stream Key', streamKey ?? 'Not available'),
          const SizedBox(height: 16),
          Text(
            'Note: Use these credentials to configure your streaming software (OBS, etc.)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedTheme(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          data: Theme.of(context),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.98 + (0.02 * value),
                child: Opacity(
                  opacity: value,
                  child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildProfileSection(),
                              ),
                            );
                          },
                        ),
          const SizedBox(height: 32),
          // App Settings
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildAppSettingsSection(),
                              ),
                            );
                          },
                        ),
          const SizedBox(height: 32),
          // Account Settings
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildAccountSection(),
                              ),
                            );
                          },
                        ),
          const SizedBox(height: 32),
          // System Settings
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildSystemSection(),
                              ),
                            );
                          },
                        ),
          const SizedBox(height: 32),
          // Support Section
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildSupportSection(),
                              ),
                            );
                          },
                        ),
          const SizedBox(height: 32),
          // Danger Zone
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutBack,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: _buildDangerSection(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeSelector() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: Row(
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.elasticOut,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.rotate(
                                angle: value * 0.1,
                                child: Icon(
                                  Icons.palette_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          const Text('Theme Mode'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      child: const Text('Choose your preferred theme mode'),
                    ),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildThemeModeOption(
                                    'Light',
                                    Icons.light_mode_rounded,
                                    ThemeMode.light,
                                    themeProvider,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildThemeModeOption(
                                    'Dark',
                                    Icons.dark_mode_rounded,
                                    ThemeMode.dark,
                                    themeProvider,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildThemeModeOption(
                                    'System',
                                    Icons.settings_brightness_rounded,
                                    ThemeMode.system,
                                    themeProvider,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ));
            },
          );
        },
      );
    }

  Widget _buildThemeModeOption(String label, IconData icon, ThemeMode mode, ThemeProvider themeProvider) {
    final isSelected = themeProvider.themeMode == mode;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: GestureDetector(
            onTap: () {
              // Add haptic feedback for better UX
              HapticFeedback.lightImpact();
              
              // Animate the theme change
              themeProvider.setThemeMode(mode);
              
              // Show centered square popup
              showDialog(
                context: context,
                barrierDismissible: true,
                barrierColor: Colors.black.withValues(alpha: 0.5),
                builder: (BuildContext context) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.7 + (0.3 * value),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.elasticOut,
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, animationValue, child) {
                                    return Transform.rotate(
                                      angle: animationValue * 0.5,
                                      child: Icon(
                                        icon,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '$label Mode',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Switched Successfully',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
              
              // Auto close after 2 seconds
              Future.delayed(const Duration(milliseconds: 2000), () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ] : [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: Column(
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.8 + (0.2 * value),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    icon,
                                    key: ValueKey('$icon-${isSelected}'),
                                    color: isSelected 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    size: 22,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 5 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOutCubic,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    child: Text(label),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSection() {
    String userName = userData['displayName'] ?? 
        userData['name'] ?? 
        userData['fullName'] ?? 
        userData['firstName'] ?? 
        userData['username'] ?? 
        userData['email']?.toString().split('@')[0] ?? 
        'Superadmin';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              _getInitials(userName),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userData['email']?.toString() ?? 'No email available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    userData['role']?.toString() ?? 'Superadmin',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ErrorHandler.showSnackBar(context, 'Edit profile functionality not implemented yet');
            },
            icon: Icon(
              Icons.edit_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Settings',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.notifications_rounded,
          'Notifications',
          'Receive push notifications',
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Switch(
                        key: ValueKey('notification-switch'),
                        value: notificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            notificationsEnabled = value;
                          });
                          _saveNotificationSetting(value);
                          // Add haptic feedback
                          HapticFeedback.lightImpact();
                          
                          // Show centered square popup
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierColor: Colors.black.withValues(alpha: 0.5),
                            builder: (BuildContext context) {
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                child: TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.elasticOut,
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: 0.7 + (0.3 * value),
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            TweenAnimationBuilder<double>(
                                              duration: const Duration(milliseconds: 800),
                                              curve: Curves.elasticOut,
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              builder: (context, animationValue, child) {
                                                return Transform.rotate(
                                                  angle: animationValue * 0.5,
                                                  child: Icon(
                                                    notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              notificationsEnabled ? 'Notifications On' : 'Notifications Off',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              notificationsEnabled ? 'You will receive notifications' : 'Notifications disabled',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                          
                          // Auto close after 2 seconds
                          Future.delayed(const Duration(milliseconds: 2000), () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          });
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        inactiveThumbColor: Theme.of(context).colorScheme.outline,
                        inactiveTrackColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildSettingItem(
          Icons.dark_mode_rounded,
          'Dark Mode',
          'Switch between light and dark themes',
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Switch(
                        key: ValueKey('switch-${themeProvider.isDarkMode}'),
                        value: themeProvider.isDarkMode,
            onChanged: (value) {
                          // Add haptic feedback
                          HapticFeedback.lightImpact();
                          
                          final newMode = value ? ThemeMode.dark : ThemeMode.light;
                          themeProvider.setThemeMode(newMode);
                          
                          // Show centered square popup
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierColor: Colors.black.withValues(alpha: 0.5),
                            builder: (BuildContext context) {
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                child: TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.elasticOut,
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: 0.7 + (0.3 * value),
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            TweenAnimationBuilder<double>(
                                              duration: const Duration(milliseconds: 800),
                                              curve: Curves.elasticOut,
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              builder: (context, animationValue, child) {
                                                return Transform.rotate(
                                                  angle: animationValue * 0.5,
                                                  child: Icon(
                                                    themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Switched Successfully',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                          
                          // Auto close after 2 seconds
                          Future.delayed(const Duration(milliseconds: 2000), () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          });
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        inactiveThumbColor: Theme.of(context).colorScheme.outline,
                        inactiveTrackColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildThemeModeSelector(),
        _buildSettingItem(
          Icons.fingerprint_rounded,
          'Biometric Login',
          'Use fingerprint or face recognition',
          Switch(
            value: false,
            onChanged: (value) {
              ErrorHandler.showSnackBar(context, 'Biometric login not implemented yet');
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        _buildSettingItem(
          Icons.face_rounded,
          'Face Registration',
          'Register your face for attendance monitoring',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FaceRegistrationScreen(userData: widget.userData),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.lock_rounded,
          'Change Password',
          'Update your account password',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Change password functionality not implemented yet'),
        ),
        _buildSettingItem(
          Icons.edit_rounded,
          'Update Profile',
          'Edit your profile information',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Update profile functionality not implemented yet'),
        ),
        _buildSettingItem(
          Icons.admin_panel_settings_rounded,
          'Admin Settings',
          'Manage system-wide admin configurations',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Admin settings not implemented yet'),
        ),
        _buildSettingItem(
          Icons.security_rounded,
          'Security Settings',
          'Configure system security and access controls',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Security settings not implemented yet'),
        ),
      ],
    );
  }

  Widget _buildSystemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Management',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.storage_rounded,
          'Database Status',
          'Check database connection and performance',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Database status check not implemented yet'),
        ),
        _buildSettingItem(
          Icons.health_and_safety_rounded,
          'API Health Check',
          'Verify all API endpoints are working',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'API health check not implemented yet'),
        ),
        _buildSettingItem(
          Icons.backup_rounded,
          'System Backup',
          'Create and manage system backups',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'System backup not implemented yet'),
        ),
        _buildSettingItem(
          Icons.update_rounded,
          'System Updates',
          'Check for and install system updates',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'System updates not implemented yet'),
        ),
        _buildSettingItem(
          Icons.clear_all_rounded,
          'Clear Cache',
          'Clear application cache and temporary data',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Clear cache functionality not implemented yet'),
        ),
        _buildSettingItem(
          Icons.admin_panel_settings_rounded,
          'User Management',
          'Manage all system users and permissions',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'User management not implemented yet'),
        ),
        _buildSettingItem(
          Icons.security_rounded,
          'Security Settings',
          'Configure system security and access controls',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Security settings not implemented yet'),
        ),
        _buildSettingItem(
          Icons.analytics_rounded,
          'System Analytics',
          'View system performance and usage analytics',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'System analytics not implemented yet'),
        ),
        _buildSettingItem(
          Icons.description_rounded,
          'System Logs',
          'View and manage system logs and audit trails',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'System logs not implemented yet'),
        ),
        _buildSettingItem(
          Icons.settings_applications_rounded,
          'Application Settings',
          'Configure application-wide settings and preferences',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Application settings not implemented yet'),
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.help_rounded,
          'Help & FAQ',
          'Get help and find answers to common questions',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Help & FAQ not implemented yet'),
        ),
        _buildSettingItem(
          Icons.feedback_rounded,
          'Send Feedback',
          'Share your thoughts and suggestions',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Send feedback not implemented yet'),
        ),
        _buildSettingItem(
          Icons.info_rounded,
          'About',
          'App version and information',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'About not implemented yet'),
        ),
      ],
    );
  }

  Widget _buildDangerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danger Zone',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade800,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.logout_rounded,
          'Logout',
          'Sign out of your account',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.red.shade600,
          ),
          onTap: _handleLogout,
          isDanger: true,
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle,
    Widget trailing, {
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDanger 
                      ? Colors.red.shade50 
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDanger ? Colors.red.shade600 : Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDanger ? Colors.red.shade800 : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDanger ? Colors.red.shade600 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  // Utility methods
  String _getInitials(String name) {
    if (name.isEmpty) return 'S';
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not available';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Dialog methods
  void _showAcceptDeanDialog(Map<String, dynamic> dean) {
    ErrorHandler.showConfirmDialog(
      context,
      'Accept Dean',
      'Are you sure you want to accept ${dean['firstName']} ${dean['lastName']} as a dean?',
      () => _acceptDean(dean['id']),
    );
  }

  void _showRejectDeanDialog(Map<String, dynamic> dean) {
    ErrorHandler.showConfirmDialog(
      context,
      'Reject Dean',
      'Are you sure you want to reject ${dean['firstName']} ${dean['lastName']}? This action cannot be undone.',
      () => _rejectDean(dean['id']),
    );
  }

  void _showAcceptInstructorDialog(Map<String, dynamic> instructor) {
    ErrorHandler.showConfirmDialog(
      context,
      'Accept Instructor',
      'Are you sure you want to accept ${instructor['firstName']} ${instructor['lastName']} as an instructor?',
      () => _acceptInstructor(instructor['id']),
    );
  }

  void _showRejectInstructorDialog(Map<String, dynamic> instructor) {
    ErrorHandler.showConfirmDialog(
      context,
      'Reject Instructor',
      'Are you sure you want to reject ${instructor['firstName']} ${instructor['lastName']}? This action cannot be undone.',
      () => _rejectInstructor(instructor['id']),
    );
  }

  void _showAcceptProgramChairDialog(Map<String, dynamic> programChair) {
    ErrorHandler.showConfirmDialog(
      context,
      'Accept Program Chair',
      'Are you sure you want to accept ${programChair['firstName']} ${programChair['lastName']} as a program chair?',
      () => _acceptProgramChair(programChair['id']),
    );
  }

  void _showRejectProgramChairDialog(Map<String, dynamic> programChair) {
    ErrorHandler.showConfirmDialog(
      context,
      'Reject Program Chair',
      'Are you sure you want to reject ${programChair['firstName']} ${programChair['lastName']}? This action cannot be undone.',
      () => _rejectProgramChair(programChair['id']),
    );
  }


  void _showDeleteUserDialog(Map<String, dynamic> user) {
    ErrorHandler.showConfirmDialog(
      context,
      'Delete User',
      'Are you sure you want to delete ${user['firstName']} ${user['lastName']}? This action cannot be undone.',
      () => _handleDeleteUser(user['id'], user['role']),
    );
  }

  // Action methods
  Future<void> _acceptDean(String deanId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Accepting dean...');
      await ApiService.acceptDean(deanId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Dean accepted successfully');
      _fetchPendingDeans();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _rejectDean(String deanId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Rejecting dean...');
      await ApiService.rejectDean(deanId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Dean rejected successfully');
      _fetchPendingDeans();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _acceptInstructor(String instructorId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Accepting instructor...');
      await ApiService.acceptInstructor(instructorId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Instructor accepted successfully');
      _fetchPendingInstructors();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _rejectInstructor(String instructorId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Rejecting instructor...');
      await ApiService.rejectInstructor(instructorId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Instructor rejected successfully');
      _fetchPendingInstructors();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _acceptProgramChair(String programChairId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Accepting program chair...');
      await ApiService.acceptProgramChair(programChairId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Program chair accepted successfully');
      _fetchPendingProgramChairs();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _rejectProgramChair(String programChairId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Rejecting program chair...');
      await ApiService.rejectProgramChair(programChairId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Program chair rejected successfully');
      _fetchPendingProgramChairs();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }



  // Sample data methods
  List<dynamic> _getSampleFacultyLogs() {
    return [
      {
        'id': '1',
        'instructorName': 'John Doe',
        'course': 'Data Structures',
        'room': 'Room 101',
        'timeIn': '08:00',
        'timeout': '10:00',
        'status': 'Present',
        'date': DateTime.now().toIso8601String(),
      },
      {
        'id': '2',
        'instructorName': 'Jane Smith',
        'course': 'Algorithms',
        'room': 'Room 102',
        'timeIn': '10:00',
        'timeout': '12:00',
        'status': 'Present',
        'date': DateTime.now().toIso8601String(),
      },
      {
        'id': '3',
        'instructorName': 'Mike Johnson',
        'course': 'Database Systems',
        'room': 'Room 103',
        'timeIn': '14:00',
        'timeout': '16:00',
        'status': 'Present',
        'date': DateTime.now().toIso8601String(),
      },
    ];
  }




  List<dynamic> _getSamplePendingDeansData() {
    return [
      {
        '_id': '1',
        'email': 'pending.dean1@university.edu',
        'role': 'dean',
        'department': 'Computer Science',
        'program': 'BS Computer Science',
        'profilePhoto': '',
        'dateSignedUp': DateTime.now().toIso8601String(),
      },
      {
        '_id': '2',
        'email': 'pending.dean2@university.edu',
        'role': 'dean',
        'department': 'Engineering',
        'program': 'BS Engineering',
        'profilePhoto': '',
        'dateSignedUp': DateTime.now().toIso8601String(),
      },
    ];
  }

  List<dynamic> _getSamplePendingInstructorsData() {
    return [
      {
        '_id': '1',
        'email': 'pending.instructor1@university.edu',
        'role': 'instructor',
        'department': 'Computer Science',
        'program': 'BS Computer Science',
        'profilePhoto': '',
        'dateSignedUp': DateTime.now().toIso8601String(),
      },
      {
        '_id': '2',
        'email': 'pending.instructor2@university.edu',
        'role': 'instructor',
        'department': 'Information Technology',
        'program': 'BS Information Technology',
        'profilePhoto': '',
        'dateSignedUp': DateTime.now().toIso8601String(),
      },
    ];
  }

  List<dynamic> _getSamplePendingProgramChairsData() {
    return [
      {
        '_id': '1',
        'email': 'pending.pc1@university.edu',
        'role': 'programchairperson',
        'department': 'Computer Science',
        'program': 'BS Computer Science',
        'profilePhoto': '',
        'dateSignedUp': DateTime.now().toIso8601String(),
      },
      {
        '_id': '2',
        'email': 'pending.pc2@university.edu',
        'role': 'programchairperson',
        'department': 'Information Technology',
        'program': 'BS Information Technology',
        'profilePhoto': '',
        'dateSignedUp': DateTime.now().toIso8601String(),
      },
    ];
  }
}
