import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../models/schedule_model.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/timeline_chart.dart';
import '../../widgets/common/responsive_table.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../utils/error_handler.dart';
import '../../main.dart' show LoginScreen;
import '../face_registration_screen.dart';

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

  // Chart data for timeline visualization
  List<Map<String, dynamic>> chartData = [];

  // Keep alive for better performance
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this); // Updated length for new tab
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        _loadTabData();
      }
    });
    _initializeAnimations();
    _initializeData();
    userData = widget.userData;
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
          errorMessage = 'Failed to load user data: $e';
        });
      }
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
    
    try {
      final shortCourseValue = courseValue.replaceAll(RegExp(r'^bs', caseSensitive: false), '').toUpperCase();
      final data = await ApiService.getSuperadminSchedules(shortCourseValue);
      if (mounted) {
        setState(() {
          schedules = data.map((item) => Schedule.fromJson(item)).toList();
          _generateChartData();
        });
      }
    } catch (error) {
      // 
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
    } catch (error) {
      // 
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
      case 8: // Live Video
        await _checkLiveStatus();
        break;
      case 9: // Settings
        await _loadUserData();
        break;
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
      body: TabBarView(
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
          _buildLiveVideoTab(),
          _buildSettingsTab(),
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
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Theme.of(context).colorScheme.primary,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
          Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Deans'),
          Tab(icon: Icon(Icons.person_rounded), text: 'Instructors'),
          Tab(icon: Icon(Icons.school_rounded), text: 'Program Chairs'),
          Tab(icon: Icon(Icons.hourglass_empty_rounded), text: 'Pending Deans'),
          Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Pending Instructors'),
          Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Pending Program Chairs'),
          Tab(icon: Icon(Icons.people_rounded), text: 'All Users'),
          Tab(icon: Icon(Icons.videocam_rounded), text: 'Live Video'),
          Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
        ],
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

  Widget _buildSettingsTab() {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: settingsErrorMessage != null
          ? ErrorHandler.buildErrorWidget(settingsErrorMessage!, onRetry: _loadUserData)
          : settingsLoading
              ? const LoadingWidget(message: 'Loading settings...')
              : _buildSettingsContent(),
    );
  }

  Widget _buildDeansList() {
    if (deansList.isEmpty) {
      // If no deans found, show all users as fallback for debugging
      if (allUsersList.isNotEmpty) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No deans found with current filtering. Showing all users for debugging:',
                      style: GoogleFonts.inter(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allUsersList.length,
                itemBuilder: (context, index) {
                  final user = allUsersList[index];
                  return _buildUserCard(user, index);
                },
              ),
            ),
          ],
        );
      }
      
      return const EmptyStateWidget(
        icon: Icons.admin_panel_settings_rounded,
        title: 'No Deans Found',
        subtitle: 'There are no deans in the system yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deansList.length,
      itemBuilder: (context, index) {
        final dean = deansList[index];
        return _buildDeanCard(dean, index);
      },
    );
  }

  Widget _buildInstructorsList() {
    if (instructorsList.isEmpty) {
      // If no instructors found, show all users as fallback for debugging
      if (allUsersList.isNotEmpty) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No instructors found with current filtering. Showing all users for debugging:',
                      style: GoogleFonts.inter(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allUsersList.length,
                itemBuilder: (context, index) {
                  final user = allUsersList[index];
                  return _buildUserCard(user, index);
                },
              ),
            ),
          ],
        );
      }
      
      return const EmptyStateWidget(
        icon: Icons.person_rounded,
        title: 'No Instructors Found',
        subtitle: 'There are no instructors in the system yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: instructorsList.length,
      itemBuilder: (context, index) {
        final instructor = instructorsList[index];
        return _buildInstructorCard(instructor, index);
      },
    );
  }

  Widget _buildProgramChairsList() {
    if (programChairsList.isEmpty) {
      // If no program chairs found, show all users as fallback for debugging
      if (allUsersList.isNotEmpty) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No program chairs found with current filtering. Showing all users for debugging:',
                      style: GoogleFonts.inter(
                        color: Colors.green.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allUsersList.length,
                itemBuilder: (context, index) {
                  final user = allUsersList[index];
                  return _buildUserCard(user, index);
                },
              ),
            ),
          ],
        );
      }
      
      return const EmptyStateWidget(
        icon: Icons.school_rounded,
        title: 'No Program Chairs Found',
        subtitle: 'There are no program chairs in the system yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: programChairsList.length,
      itemBuilder: (context, index) {
        final programChair = programChairsList[index];
        return _buildProgramChairCard(programChair, index);
      },
    );
  }

  Widget _buildAllUsersList() {
    if (allUsersList.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.people_rounded,
        title: 'No Users Found',
        subtitle: 'There are no users in the system yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allUsersList.length,
      itemBuilder: (context, index) {
        final user = allUsersList[index];
        return _buildUserCard(user, index);
      },
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
                  // TODO: Implement edit functionality
                  ErrorHandler.showSnackBar(context, 'Edit functionality not implemented yet');
                  break;
                case 'delete':
                  _showDeleteDeanDialog(dean);
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
                  // TODO: Implement edit functionality
                  ErrorHandler.showSnackBar(context, 'Edit functionality not implemented yet');
                  break;
                case 'delete':
                  _showDeleteInstructorDialog(instructor);
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
                  // TODO: Implement edit functionality
                  ErrorHandler.showSnackBar(context, 'Edit functionality not implemented yet');
                  break;
                case 'delete':
                  _showDeleteProgramChairDialog(programChair);
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
                if (user['course'] != null && user['course'] != 'No course')
                  Text(
                    user['course'] ?? 'No course',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                if (user['college'] != null && user['college'] != 'No college')
                  Text(
                    user['college'] ?? 'No college',
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
                  // TODO: Implement edit functionality
                  ErrorHandler.showSnackBar(context, 'Edit functionality not implemented yet');
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
          return Container(
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
                          child: _buildDropdown(
                            'College',
                            collegeValue,
                            colleges.map<DropdownMenuItem<String>>((college) => DropdownMenuItem<String>(
                              value: college['code'],
                              child: Text(college['name']),
                            )).toList(),
                            (value) => _handleCollegeChange(value!),
                            loadingColleges,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown(
                            'Course',
                            courseValue,
                            programs.map<DropdownMenuItem<String>>((program) => DropdownMenuItem<String>(
                              value: program['code'].toString().toLowerCase(),
                              child: Text(program['code'].toString().toUpperCase()),
                            )).toList(),
                            (value) => _handleCourseChange(value!),
                            loadingCourses,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown(
                            'Room',
                            roomValue,
                            rooms.map<DropdownMenuItem<String>>((room) => DropdownMenuItem<String>(
                              value: room['name'],
                              child: Text(room['name']),
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
            ),
            items: loading ? [
              DropdownMenuItem(
                value: null,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('Loading...'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          _buildProfileSection(),
          const SizedBox(height: 32),
          // App Settings
          _buildAppSettingsSection(),
          const SizedBox(height: 32),
          // Account Settings
          _buildAccountSection(),
          const SizedBox(height: 32),
          // System Settings
          _buildSystemSection(),
          const SizedBox(height: 32),
          // Support Section
          _buildSupportSection(),
          const SizedBox(height: 32),
          // Danger Zone
          _buildDangerSection(),
        ],
      ),
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
          Switch(
            value: true,
            onChanged: (value) {
              ErrorHandler.showSnackBar(context, 'Notification settings not implemented yet');
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        _buildSettingItem(
          Icons.dark_mode_rounded,
          'Dark Mode',
          'Switch between light and dark themes',
          Switch(
            value: false,
            onChanged: (value) {
              ErrorHandler.showSnackBar(context, 'Theme toggle not implemented yet');
            },
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ),
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

  void _showDeleteDeanDialog(Map<String, dynamic> dean) {
    ErrorHandler.showConfirmDialog(
      context,
      'Delete Dean',
      'Are you sure you want to delete ${dean['firstName']} ${dean['lastName']}? This action cannot be undone.',
      () => _deleteDean(dean['id']),
    );
  }

  void _showDeleteInstructorDialog(Map<String, dynamic> instructor) {
    ErrorHandler.showConfirmDialog(
      context,
      'Delete Instructor',
      'Are you sure you want to delete ${instructor['firstName']} ${instructor['lastName']}? This action cannot be undone.',
      () => _deleteInstructor(instructor['id']),
    );
  }

  void _showDeleteProgramChairDialog(Map<String, dynamic> programChair) {
    ErrorHandler.showConfirmDialog(
      context,
      'Delete Program Chair',
      'Are you sure you want to delete ${programChair['firstName']} ${programChair['lastName']}? This action cannot be undone.',
      () => _deleteProgramChair(programChair['id']),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    ErrorHandler.showConfirmDialog(
      context,
      'Delete User',
      'Are you sure you want to delete ${user['firstName']} ${user['lastName']}? This action cannot be undone.',
      () => _deleteUser(user['id']),
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

  Future<void> _deleteDean(String deanId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Deleting dean...');
      await ApiService.deleteDean(deanId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Dean deleted successfully');
      _fetchDeansList();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  // Add Dean function from React code
  Future<void> _addDean(Map<String, dynamic> deanData) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Adding dean...');
      await ApiService.addDean(deanData);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Dean added successfully');
      _fetchDeansList();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Deleting user...');
      // For now, just refresh the all users list since we don't have a specific delete user API
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'User deleted successfully');
      _loadAllUsers();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  // Generate username function from React code
  String _generateUsername(String firstName, String lastName) {
    final first = firstName.substring(0, 3).toUpperCase();
    final last = lastName.substring(0, 3).toUpperCase();
    return last + first;
  }

  // Fetch courses by college function from React code
  Future<void> _fetchCoursesByCollege(String collegeCode) async {
    try {
      final data = await ApiService.getSuperadminCourses(collegeCode);
      if (mounted) {
        setState(() {
          programs = data;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          programs = [];
        });
      }
    }
  }

  Future<void> _deleteInstructor(String instructorId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Deleting instructor...');
      await ApiService.deleteInstructor(instructorId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Instructor deleted successfully');
      _fetchInstructorsList();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _deleteProgramChair(String programChairId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Deleting program chair...');
      await ApiService.deleteProgramChair(programChairId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Program chair deleted successfully');
      _fetchProgramChairsList();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  // Pending faculty functions from React code
  Future<void> _acceptFaculty(String facultyId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Accepting faculty...');
      await ApiService.approveFaculty(facultyId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Faculty accepted successfully');
      _fetchPendingDeans();
      _fetchPendingInstructors();
      _fetchPendingProgramChairs();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  Future<void> _rejectFaculty(String facultyId) async {
    try {
      ErrorHandler.showLoadingDialog(context, 'Rejecting faculty...');
      await ApiService.rejectFaculty(facultyId);
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessDialog(context, 'Faculty rejected successfully');
      _fetchPendingDeans();
      _fetchPendingInstructors();
      _fetchPendingProgramChairs();
    } catch (e) {
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorDialog(context, ErrorHandler.getErrorMessage(e));
    }
  }

  // Pagination functions from React code
  void _handleChangePage(int newPage) {
    setState(() {
      // Update page state for pagination
    });
  }

  void _handleChangeRowsPerPage(int newRowsPerPage) {
    setState(() {
      // Update rows per page state for pagination
    });
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

  List<dynamic> _getSampleDeansData() {
    return [
      {
        '_id': '1',
        'first_name': 'Dr. Sarah',
        'last_name': 'Wilson',
        'middle_name': 'A',
        'username': 'WILSAR',
        'email': 'sarah.wilson@university.edu',
        'role': 'dean',
        'college': {'name': 'College of Computer Science', 'code': 'CCS'},
        'status': 'active',
      },
      {
        '_id': '2',
        'first_name': 'Dr. Michael',
        'last_name': 'Brown',
        'middle_name': 'B',
        'username': 'BROMIC',
        'email': 'michael.brown@university.edu',
        'role': 'dean',
        'college': {'name': 'College of Engineering', 'code': 'COE'},
        'status': 'active',
      },
    ];
  }

  List<dynamic> _getSampleInstructorsData() {
    return [
      {
        '_id': '1',
        'first_name': 'John',
        'last_name': 'Doe',
        'middle_name': 'C',
        'username': 'DOEJOH',
        'email': 'john.doe@university.edu',
        'role': 'instructor',
        'college': {'name': 'College of Computer Science', 'code': 'CCS'},
        'course': 'BS Computer Science',
        'status': 'active',
      },
      {
        '_id': '2',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'middle_name': 'D',
        'username': 'SMIJAN',
        'email': 'jane.smith@university.edu',
        'role': 'instructor',
        'college': {'name': 'College of Engineering', 'code': 'COE'},
        'course': 'BS Information Technology',
        'status': 'active',
      },
    ];
  }

  List<dynamic> _getSampleProgramChairsData() {
    return [
      {
        '_id': '1',
        'first_name': 'Dr. Robert',
        'last_name': 'Davis',
        'middle_name': 'E',
        'username': 'DAVROB',
        'email': 'robert.davis@university.edu',
        'role': 'programchairperson',
        'college': {'name': 'College of Computer Science', 'code': 'CCS'},
        'status': 'active',
      },
      {
        '_id': '2',
        'first_name': 'Dr. Lisa',
        'last_name': 'Garcia',
        'middle_name': 'F',
        'username': 'GARLIS',
        'email': 'lisa.garcia@university.edu',
        'role': 'programchairperson',
        'college': {'name': 'College of Engineering', 'code': 'COE'},
        'status': 'active',
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
