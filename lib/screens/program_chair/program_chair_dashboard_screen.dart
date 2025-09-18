import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/schedule_model.dart';
import '../../services/api_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/timeline_chart.dart';
import '../../widgets/common/responsive_table.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../main.dart' show LoginScreen;

class ProgramChairDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProgramChairDashboardScreen({super.key, required this.userData});

  @override
  State<ProgramChairDashboardScreen> createState() => _ProgramChairDashboardScreenState();
}

class _ProgramChairDashboardScreenState extends State<ProgramChairDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  // Tab index
  int _currentTabIndex = 0;

  // State variables
  int? instructorCount;
  int? schedulesCount;
  List<dynamic> allFacultiesLogs = [];
  List<Schedule> schedules = [];
  List<dynamic> courses = [];
  List<dynamic> rooms = [];
  String courseValue = "all";
  String roomValue = "all";
  bool loading = false;
  bool isRefreshing = false;
  String? errorMessage;

  String collegeName = "";
  String courseName = "";

  // Chart data for timeline visualization
  List<Map<String, dynamic>> chartData = [];

  // Faculty data
  List<dynamic> facultyList = [];
  bool facultyLoading = false;
  String? facultyErrorMessage;

  // Reports data
  List<dynamic> dailyReports = [];
  bool reportsLoading = false;
  String? reportsErrorMessage;

  // Live video data
  bool isLive = false;
  String? streamUrl;
  bool liveLoading = false;
  String? liveErrorMessage;

  // Settings data
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? successMessage;
  bool settingsLoading = false;
  String? settingsErrorMessage;

  // Removed AutomaticKeepAliveClientMixin to prevent memory leaks

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        _loadTabData(_currentTabIndex);
      }
    });
    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _initializeData() async {
    await _loadUserData();
    if (mounted) {
      await _fetchData();
    }
  }

  Future<void> _loadTabData(int tabIndex) async {
    switch (tabIndex) {
      case 0: // Dashboard
        await _fetchData();
        break;
      case 1: // Faculty
        await _fetchFacultyList();
        break;
      case 2: // Reports
        await _fetchDailyReports();
        break;
      case 3: // Live Video
        await _checkLiveStatus();
        break;
      case 4: // Settings
        _populateForm();
        break;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          collegeName = prefs.getString('college') ?? '';
          courseName = prefs.getString('course') ?? '';
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
        _fetchSchedules(),
        _fetchCourses(),
        _fetchRooms(),
        _fetchInstructorCount(),
        _fetchSchedulesCount(),
        _fetchAllFacultiesLogs(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load data: $e';
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

  Future<void> _fetchSchedules() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      final response = await ApiService.getProgramChairSchedules(courseName);
      ApiService.logApiCall('/api/auth/all-schedules/today', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              schedules = (data as List<dynamic>)
                  .map((item) => Schedule.fromJson(item))
                  .toList();
            });
          }
        },
        (error) {
          // 
        },
      );
    } catch (e) {
      // 
    }
  }

  Future<void> _fetchCourses() async {
    if (!mounted || collegeName.isEmpty) return;
    
    try {
      final response = await ApiService.getDeanCourses(collegeName);
      ApiService.logApiCall('/api/auth/all-courses/college', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              courses = data as List<dynamic>;
            });
          }
        },
        (error) {
          // 
        },
      );
    } catch (e) {
      // 
    }
  }

  Future<void> _fetchRooms() async {
    if (!mounted || collegeName.isEmpty) return;
    
    try {
      final response = await ApiService.getDeanRooms(collegeName);
      ApiService.logApiCall('/api/auth/all-rooms/college', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              rooms = data as List<dynamic>;
            });
          }
        },
        (error) {
          // 
        },
      );
    } catch (e) {
      // 
    }
  }

  Future<void> _fetchInstructorCount() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      final response = await ApiService.getProgramChairInstructorCount(courseName);
      ApiService.logApiCall('/api/auth/count/instructors', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              instructorCount = data['instructorCount'];
            });
          }
        },
        (error) {
          // 
        },
      );
    } catch (e) {
      // 
    }
  }

  Future<void> _fetchSchedulesCount() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      final response = await ApiService.getProgramChairSchedulesCount(courseName);
      ApiService.logApiCall('/api/auth/schedules-count/today', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              schedulesCount = data['schedulesCount'];
            });
          }
        },
        (error) {
          // 
        },
      );
    } catch (e) {
      // 
    }
  }

  Future<void> _fetchAllFacultiesLogs() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      final response = await ApiService.getProgramChairFacultyLogs(courseName);
      ApiService.logApiCall('/api/auth/logs/all-faculties/today', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              allFacultiesLogs = data as List<dynamic>;
            });
          }
        },
        (error) {
          // 
        },
      );
    } catch (e) {
      // 
    }
  }

  void _handleCourseChange(String? value) {
    if (value == null) return;
    
    setState(() {
      courseValue = value;
    });
  }

  void _handleRoomChange(String? value) {
    if (value == null) return;
    
    setState(() {
      roomValue = value;
    });
  }

  // Faculty methods
  Future<void> _fetchFacultyList() async {
    if (!mounted || courseName.isEmpty) return;
    
    setState(() {
      facultyLoading = true;
      facultyErrorMessage = null;
    });

    try {
      final response = await ApiService.getProgramChairFaculty(courseName);
      ApiService.logApiCall('/api/auth/programchairs', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              facultyList = data as List<dynamic>;
              facultyLoading = false;
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              facultyErrorMessage = error;
              facultyLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          facultyErrorMessage = 'Failed to fetch faculty list: $e';
          facultyLoading = false;
        });
      }
    }
  }

  // Reports methods
  Future<void> _fetchDailyReports() async {
    if (!mounted || courseName.isEmpty) return;
    
    setState(() {
      reportsLoading = true;
      reportsErrorMessage = null;
    });

    try {
      final response = await ApiService.getProgramChairDailyReport(courseName);
      ApiService.logApiCall('/api/auth/show-daily-report', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              dailyReports = data as List<dynamic>;
              reportsLoading = false;
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              reportsErrorMessage = error;
              reportsLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          reportsErrorMessage = 'Failed to fetch daily reports: $e';
          reportsLoading = false;
        });
      }
    }
  }

  Future<void> _generateMonthlyReport() async {
    try {
      final response = await ApiService.generateProgramChairReport(courseName);
      ApiService.logApiCall('/api/auth/generate-monthly-report', response);
      
      ApiService.handleApiResponse(
        response,
        (data) async {
          // Save file to device
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/monthly_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
          await file.writeAsString(data.toString());
          
          if (mounted) {
            ErrorHandler.showSnackBar(context, 'Monthly report generated successfully');
          }
        },
        (error) {
          ErrorHandler.showSnackBar(context, error, isError: true);
        },
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to generate monthly report: $e', isError: true);
    }
  }

  // Live video methods
  Future<void> _checkLiveStatus() async {
    if (!mounted || courseName.isEmpty) return;
    
    setState(() {
      liveLoading = true;
      liveErrorMessage = null;
    });

    try {
      final response = await ApiService.getDeanLiveStatus(courseName);
      ApiService.logApiCall('/api/auth/live-status/college', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              isLive = data['isLive'] ?? false;
              streamUrl = data['streamUrl'];
              liveLoading = false;
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              liveErrorMessage = error;
              liveLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          liveErrorMessage = 'Failed to check live status: $e';
          liveLoading = false;
        });
      }
    }
  }

  Future<void> _startLiveStream() async {
    try {
      final response = await ApiService.startDeanLiveStream(courseName);
      ApiService.logApiCall('/api/auth/start-live-stream', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              isLive = true;
              streamUrl = data['streamUrl'];
            });
            ErrorHandler.showSnackBar(context, 'Live stream started successfully');
          }
        },
        (error) {
          ErrorHandler.showSnackBar(context, error, isError: true);
        },
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to start live stream: $e', isError: true);
    }
  }

  Future<void> _stopLiveStream() async {
    try {
      final response = await ApiService.stopDeanLiveStream(courseName);
      ApiService.logApiCall('/api/auth/stop-live-stream', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              isLive = false;
              streamUrl = null;
            });
            ErrorHandler.showSnackBar(context, 'Live stream stopped successfully');
          }
        },
        (error) {
          ErrorHandler.showSnackBar(context, error, isError: true);
        },
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to stop live stream: $e', isError: true);
    }
  }

  // Settings methods
  void _populateForm() {
    _firstNameController.text = widget.userData['firstName'] ?? '';
    _lastNameController.text = widget.userData['lastName'] ?? '';
    _emailController.text = widget.userData['email'] ?? '';
  }


  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(),
              ),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        // Clear user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        // Navigate to login screen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Failed to logout: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildFacultyTab(),
                _buildReportsTab(),
                _buildLiveVideoTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Program Chair Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back, ${widget.userData['firstName'] ?? 'Program Chair'}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 30,
            ),
          ),
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
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Theme.of(context).colorScheme.primary,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
          Tab(icon: Icon(Icons.people_rounded), text: 'Faculty'),
          Tab(icon: Icon(Icons.assessment_rounded), text: 'Reports'),
          Tab(icon: Icon(Icons.videocam_rounded), text: 'Live'),
          Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
        ],
      ),
    );
  }



  Widget _buildStatisticsCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Total Instructors',
                      value: instructorCount?.toString() ?? 'Loading...',
                      icon: Icons.people_rounded,
                      iconColor: const Color(0xFF9f7aea),
                      backgroundColor: const Color(0xFFf3e8ff),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Total Schedules',
                      value: schedulesCount?.toString() ?? 'Loading...',
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF9f7aea),
                      backgroundColor: const Color(0xFFf3e8ff),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Instructor Absents Today',
                      value: '0',
                      icon: Icons.highlight_off_rounded,
                      iconColor: const Color(0xFF38bdf8),
                      backgroundColor: const Color(0xFFe0f2fe),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Late Instructors',
                      value: '0',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFec4899),
                      backgroundColor: const Color(0xFFfce7f3),
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              StatCard(
                title: 'Total Instructors',
                value: instructorCount?.toString() ?? 'Loading...',
                icon: Icons.people_rounded,
                iconColor: const Color(0xFF9f7aea),
                backgroundColor: const Color(0xFFf3e8ff),
              ),
              StatCard(
                title: 'Total Schedules',
                value: schedulesCount?.toString() ?? 'Loading...',
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF9f7aea),
                backgroundColor: const Color(0xFFf3e8ff),
              ),
              StatCard(
                title: 'Instructor Absents Today',
                value: '0',
                icon: Icons.highlight_off_rounded,
                iconColor: const Color(0xFF38bdf8),
                backgroundColor: const Color(0xFFe0f2fe),
              ),
              StatCard(
                title: 'Late Instructors',
                value: '0',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFec4899),
                backgroundColor: const Color(0xFFfce7f3),
              ),
            ],
          );
        }
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
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                // Mobile layout - stack vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today Schedule Chart',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            'Course',
                            courseValue,
                            courses.map<DropdownMenuItem<String>>((course) => DropdownMenuItem<String>(
                              value: course['code'],
                              child: Text(course['code'].toString().toUpperCase()),
                            )).toList(),
                            _handleCourseChange,
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
                            _handleRoomChange,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Desktop layout - horizontal
                return Row(
                  children: [
                    Text(
                      'Today Schedule Chart',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    _buildDropdown(
                      'Course',
                      courseValue,
                      courses.map<DropdownMenuItem<String>>((course) => DropdownMenuItem<String>(
                        value: course['code'],
                        child: Text(course['code'].toString().toUpperCase()),
                      )).toList(),
                      _handleCourseChange,
                    ),
                    const SizedBox(width: 16),
                    _buildDropdown(
                      'Room',
                      roomValue,
                      rooms.map<DropdownMenuItem<String>>((room) => DropdownMenuItem<String>(
                        value: room['name'],
                        child: Text(room['name']),
                      )).toList(),
                      _handleRoomChange,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            child: schedules.isEmpty
                ? const EmptyStateWidget(
                    title: 'No Schedules',
                    subtitle: 'No data available. Please select an option from the dropdown.',
                    icon: Icons.schedule_rounded,
                  )
                : TimelineChart(
                    chartData: schedules.map((s) => s.toMap()).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<DropdownMenuItem<String>> items, Function(String?) onChanged) {
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
            items: items,
            onChanged: onChanged,
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
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              
              if (schedules.isEmpty) {
                return const EmptyStateWidget(
                  title: 'No Schedules',
                  subtitle: 'No schedules found.',
                  icon: Icons.schedule_rounded,
                );
              }

              return ResponsiveTable(
                columns: const ['S. No', 'Instructor', 'Start Time', 'End Time', 'Room', 'Section', 'Course'],
                dataKeys: const ['sno', 'instructor', 'startTime', 'endTime', 'room', 'section', 'course'],
                data: schedules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final schedule = entry.value;
                  return {
                    'sno': '${index + 1}',
                    'instructor': '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
                    'startTime': schedule.startTime,
                    'endTime': schedule.endTime,
                    'room': schedule.room,
                    'section': schedule.section.sectionName,
                    'course': '${schedule.courseTitle} (${schedule.courseCode})',
                  };
                }).toList(),
              );
            },
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
            'Today\'s Activity',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (allFacultiesLogs.isEmpty)
            const EmptyStateWidget(
              title: 'No Activity',
              subtitle: 'There is no current activity today.',
              icon: Icons.history_rounded,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allFacultiesLogs.length,
              itemBuilder: (context, index) {
                final log = allFacultiesLogs[index];
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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry['time'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
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
              },
            ),
        ],
      ),
    );
  }

  // Tab build methods
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null)
              ErrorHandler.buildErrorWidget(errorMessage!, onRetry: _fetchData)
            else if (loading)
              const LoadingWidget()
            else
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatisticsCards(),
                      const SizedBox(height: 24),
                      _buildScheduleChart(),
                      const SizedBox(height: 24),
                      _buildSchedulesTable(),
                      const SizedBox(height: 24),
                      _buildTodayActivity(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyTab() {
    return RefreshIndicator(
      onRefresh: _fetchFacultyList,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faculty Information',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dashboard / Faculty Info',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            if (facultyErrorMessage != null)
              ErrorHandler.buildErrorWidget(facultyErrorMessage!, onRetry: _fetchFacultyList)
            else if (facultyLoading)
              const LoadingWidget()
            else
              _buildFacultyTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _fetchDailyReports,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Faculty Reports',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dashboard / Reports',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            if (reportsErrorMessage != null)
              ErrorHandler.buildErrorWidget(reportsErrorMessage!, onRetry: _fetchDailyReports)
            else if (reportsLoading)
              const LoadingWidget()
            else
              _buildReportsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveVideoTab() {
    return RefreshIndicator(
      onRefresh: _checkLiveStatus,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Video',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dashboard / Live Video',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            _buildLiveVideoContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dashboard / Settings',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingsContent(),
        ],
      ),
    );
  }

  Widget _buildFacultyTable() {
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
            'All Faculty Members',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (facultyList.isEmpty) {
                return const EmptyStateWidget(
                  title: 'No Faculty',
                  subtitle: 'No faculty members found.',
                  icon: Icons.people_rounded,
                );
              }

              return ResponsiveTable(
                columns: const ['S. No', 'Name', 'Email', 'Role', 'Status'],
                dataKeys: const ['sno', 'name', 'email', 'role', 'status'],
                data: facultyList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final faculty = entry.value;
                  return {
                    'sno': '${index + 1}',
                    'name': '${faculty['firstName'] ?? ''} ${faculty['lastName'] ?? ''}',
                    'email': faculty['email'] ?? '',
                    'role': faculty['role'] ?? '',
                    'status': faculty['status'] ?? '',
                  };
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTable() {
    return Column(
      children: [
        Container(
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
                'Report Actions',
                style: GoogleFonts.inter(
                  fontSize: 18,
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _generateMonthlyReport,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Generate Monthly Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _fetchDailyReports,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh Data'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateMonthlyReport,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Generate Monthly Report'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _fetchDailyReports,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh Data'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
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
                'Daily Reports',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (dailyReports.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No Reports',
                      subtitle: 'No reports available.',
                      icon: Icons.assessment_rounded,
                    );
                  }

                  return ResponsiveTable(
                    columns: const ['S. No', 'Faculty Name', 'Date', 'Status', 'Attendance'],
                    dataKeys: const ['sno', 'facultyName', 'date', 'status', 'attendance'],
                    data: dailyReports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final report = entry.value;
                      return {
                        'sno': '${index + 1}',
                        'facultyName': report['facultyName'] ?? '',
                        'date': report['date'] ?? '',
                        'status': report['status'] ?? '',
                        'attendance': report['attendance'] ?? '',
                      };
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveVideoContent() {
    return Column(
      children: [
        Container(
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
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isLive ? Colors.red : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLive ? 'Live Stream Active' : 'Live Stream Inactive',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLive 
                          ? 'Stream is currently broadcasting'
                          : 'No active stream at the moment',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: isLive && streamUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const Center(
                    child: Text(
                      'Live Video Player\n(WebRTC implementation required)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Live Stream',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a live stream to begin broadcasting',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 24),
        Container(
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLive ? _stopLiveStream : _startLiveStream,
                            icon: Icon(isLive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                            label: Text(isLive ? 'Stop Stream' : 'Start Stream'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLive ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _checkLiveStatus,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh Status'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isLive ? _stopLiveStream : _startLiveStream,
                            icon: Icon(isLive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                            label: Text(isLive ? 'Stop Stream' : 'Start Stream'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLive ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _checkLiveStatus,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh Status'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
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
          // Program Chair Management
          _buildProgramChairManagementSection(),
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
    String userName = widget.userData['displayName'] ?? 
        widget.userData['name'] ?? 
        widget.userData['fullName'] ?? 
        widget.userData['firstName'] ?? 
        widget.userData['username'] ?? 
        widget.userData['email']?.toString().split('@')[0] ?? 
        'Program Chair';

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
                  widget.userData['email']?.toString() ?? 'No email available',
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
                    widget.userData['role']?.toString() ?? 'Program Chair',
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
          onTap: () => ErrorHandler.showSnackBar(context, 'Face registration not implemented yet'),
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
          Icons.book_rounded,
          'Program Settings',
          'Manage program-specific configurations',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Program settings not implemented yet'),
        ),
        _buildSettingItem(
          Icons.people_rounded,
          'Instructor Management',
          'Manage instructors under your program',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Instructor management not implemented yet'),
        ),
      ],
    );
  }

  Widget _buildProgramChairManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Program Chair Management',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.assessment_rounded,
          'Daily Reports',
          'View and manage daily faculty reports',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Daily reports not implemented yet'),
        ),
        _buildSettingItem(
          Icons.calendar_month_rounded,
          'Monthly Reports',
          'Generate and view monthly reports',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Monthly reports not implemented yet'),
        ),
        _buildSettingItem(
          Icons.schedule_rounded,
          'Program Schedules',
          'Manage program schedules and timetables',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Program schedules not implemented yet'),
        ),
        _buildSettingItem(
          Icons.videocam_rounded,
          'Live Stream Settings',
          'Configure live streaming for program',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Live stream settings not implemented yet'),
        ),
        _buildSettingItem(
          Icons.person_search_rounded,
          'Attendance Monitoring',
          'Monitor instructor attendance',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Attendance monitoring not implemented yet'),
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

  String _getInitials(String name) {
    if (name.isEmpty) return 'P';
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }
}

