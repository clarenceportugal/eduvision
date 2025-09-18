import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/schedule_model.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/timeline_chart.dart';
import '../../widgets/common/responsive_table.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../utils/error_handler.dart';
import '../../main.dart' show LoginScreen;

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
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
      final data = await ApiService.getSuperadminUserCounts();
      if (mounted) {
        setState(() {
          counts = Map<String, int>.from(data);
        });
      }
    } catch (error) {
      // 
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
      // 
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
      case 7: // Live Video
        await _checkLiveStatus();
        break;
      case 8: // Settings
        await _loadUserData();
        break;
    }
  }

  // Data fetching methods for consolidated screens
  Future<void> _fetchDeansList() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getSuperadminDeans();
      if (mounted) {
        setState(() {
          deansList = data;
        });
      }
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

  Future<void> _fetchInstructorsList() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getSuperadminInstructors();
      if (mounted) {
        setState(() {
          instructorsList = data;
        });
      }
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

  Future<void> _fetchProgramChairsList() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getSuperadminProgramChairs();
      if (mounted) {
        setState(() {
          programChairsList = data;
        });
      }
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

  Future<void> _fetchPendingDeans() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getSuperadminPendingDeans();
      if (mounted) {
        setState(() {
          pendingDeans = data;
        });
      }
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

  Future<void> _fetchPendingInstructors() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getSuperadminPendingInstructors();
      if (mounted) {
        setState(() {
          pendingInstructors = data;
        });
      }
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

  Future<void> _fetchPendingProgramChairs() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.getSuperadminPendingProgramChairs();
      if (mounted) {
        setState(() {
          pendingProgramChairs = data;
        });
      }
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
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
          Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Deans'),
          Tab(icon: Icon(Icons.person_rounded), text: 'Instructors'),
          Tab(icon: Icon(Icons.school_rounded), text: 'Program Chairs'),
          Tab(icon: Icon(Icons.hourglass_empty_rounded), text: 'Pending Deans'),
          Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Pending Instructors'),
          Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Pending Program Chairs'),
          Tab(icon: Icon(Icons.videocam_rounded), text: 'Live Video'),
          Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
        ],
      ),
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Super Admin Dashboard',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dashboard / Attendance',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
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
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isTablet ? 1.4 : 1.2,
          children: [
            StatCard(
              title: 'Total Dean',
              value: counts['dean']?.toString() ?? '0',
              icon: Icons.school_rounded,
              iconColor: const Color(0xFF9f7aea),
              backgroundColor: const Color(0xFFf3e8ff),
            ),
            StatCard(
              title: 'Total Program Chairperson',
              value: counts['programChairperson']?.toString() ?? '0',
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFF9f7aea),
              backgroundColor: const Color(0xFFf3e8ff),
            ),
            StatCard(
              title: 'Total Instructors',
              value: counts['instructor']?.toString() ?? '0',
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF38bdf8),
              backgroundColor: const Color(0xFFe0f2fe),
            ),
            StatCard(
              title: 'Total Superadmin',
              value: counts['superadmin']?.toString() ?? '0',
              icon: Icons.admin_panel_settings_rounded,
              iconColor: const Color(0xFFec4899),
              backgroundColor: const Color(0xFFfce7f3),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today Schedule Chart',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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
                        const SizedBox(width: 16),
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
                        const SizedBox(width: 16),
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
          width: isMobile ? double.infinity : 200,
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
}
