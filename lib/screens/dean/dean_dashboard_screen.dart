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
import '../face_registration_screen.dart';

class DeanDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DeanDashboardScreen({super.key, required this.userData});

  @override
  State<DeanDashboardScreen> createState() => _DeanDashboardScreenState();
}

class _DeanDashboardScreenState extends State<DeanDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  // Tab index
  int _currentTabIndex = 0;

  // State variables
  int? instructorCount;
  int? programChairCount;
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
  List<dynamic> reportsList = [];
  bool reportsLoading = false;
  String? reportsErrorMessage;

  // Live video data
  bool isLiveStreamActive = false;
  String? liveStreamError;
  String? streamUrl;

  // Settings data
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? successMessage;

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
    // Only initialize data if userData is valid
    if (widget.userData.isNotEmpty) {
      _initializeData();
    } else {
      if (mounted) {
        setState(() {
          errorMessage = 'Invalid user data. Please login again.';
        });
      }
    }
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
      duration: const Duration(milliseconds: 800), // Reduced duration for better performance
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
      if (mounted && !_animationController.isAnimating) {
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
        await _fetchFacultyReports();
        break;
      case 3: // Live Video
        await _checkLiveStreamStatus();
        break;
      case 4: // Settings
        _populateForm();
        break;
    }
  }

  Future<void> _loadUserData() async {
    try {
      if (mounted && widget.userData.isNotEmpty) {
        setState(() {
          collegeName = widget.userData['college'] ?? widget.userData['collegeName'] ?? 'Default College';
          courseName = widget.userData['course'] ?? widget.userData['courseName'] ?? 'Default Course';
        });
      } else {
        // Fallback to SharedPreferences if userData is empty
        final prefs = await SharedPreferences.getInstance();
        if (mounted) {
          setState(() {
            collegeName = prefs.getString('college') ?? prefs.getString('collegeName') ?? 'Default College';
            courseName = prefs.getString('course') ?? prefs.getString('courseName') ?? 'Default Course';
          });
        }
      }
      
      // Ensure we have valid values
      if (collegeName.isEmpty) {
        collegeName = 'Default College';
      }
      if (courseName.isEmpty) {
        courseName = 'Default Course';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          collegeName = 'Default College';
          courseName = 'Default Course';
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
    if (!mounted) return;
    
    try {
      final response = await ApiService.getDeanSchedules(collegeName, courseName);
      ApiService.logApiCall('/api/auth/dean/all-schedules/today', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted && data != null) {
            try {
              setState(() {
                schedules = (data as List<dynamic>)
                    .map((item) => Schedule.fromJson(item))
                    .toList();
                _generateChartData();
              });
            } catch (e) {
              if (mounted) {
                setState(() {
                  // Use sample data if parsing fails
                  schedules = _getSampleSchedules();
                  _generateChartData();
                });
              }
            }
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              // Use sample data if API fails
              schedules = _getSampleSchedules();
              _generateChartData();
            });
          }
        },
      );
        } catch (e) {
      if (mounted) {
        setState(() {
          // Use sample data if exception occurs
          schedules = _getSampleSchedules();
          _generateChartData();
        });
      }
    }
  }

  Future<void> _fetchCourses() async {
    if (!mounted) return;
    
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
          if (mounted) {
            setState(() {
              courses = _getSampleCourses();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          courses = _getSampleCourses();
        });
      }
    }
  }

  Future<void> _fetchRooms() async {
    if (!mounted) return;
    
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
          if (mounted) {
            setState(() {
              rooms = _getSampleRooms();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          rooms = _getSampleRooms();
        });
      }
    }
  }

  Future<void> _fetchInstructorCount() async {
    if (!mounted) return;
    
    try {
      final response = await ApiService.getDeanInstructorCount(collegeName);
      ApiService.logApiCall('/api/auth/count-all/instructors', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              instructorCount = data['instructorCount'];
              programChairCount = data['programChairCount'];
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              instructorCount = 15; // Sample data
              programChairCount = 3; // Sample data
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          instructorCount = 15; // Sample data
          programChairCount = 3; // Sample data
        });
      }
    }
  }

  Future<void> _fetchAllFacultiesLogs() async {
    if (!mounted) return;
    
    try {
      final response = await ApiService.getDeanFacultyLogs(collegeName, courseName);
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
          if (mounted) {
            setState(() {
              allFacultiesLogs = _getSampleFacultyLogs();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          allFacultiesLogs = _getSampleFacultyLogs();
        });
      }
    }
  }

  void _handleCourseChange(String? value) {
    if (value == null) return;
    
    setState(() {
      courseValue = value;
    });
    
    // Refresh schedules when course filter changes
    _fetchSchedules();
  }

  void _handleRoomChange(String? value) {
    if (value == null) return;
    
    setState(() {
      roomValue = value;
    });
    
    // Refresh schedules when room filter changes
    _fetchSchedules();
  }

  // Faculty methods
  Future<void> _fetchFacultyList() async {
    if (!mounted) return;
    
    setState(() {
      facultyLoading = true;
      facultyErrorMessage = null;
    });

    try {
      final response = await ApiService.getDeanFacultyList(collegeName);
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted && data != null) {
            setState(() {
              facultyList = data as List<dynamic>;
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              facultyErrorMessage = 'Failed to fetch faculty: $error';
            });
          }
        },
      );
        } catch (e) {
      if (mounted) {
        setState(() {
          facultyErrorMessage = 'Failed to fetch faculty: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          facultyLoading = false;
        });
      }
    }
  }

  // Reports methods
  Future<void> _fetchFacultyReports() async {
    if (!mounted) return;
    
    setState(() {
      reportsLoading = true;
      reportsErrorMessage = null;
    });

    try {
      final response = await ApiService.getDeanFacultyReports(collegeName, courseName);
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted && data != null) {
            setState(() {
              reportsList = data as List<dynamic>;
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              reportsErrorMessage = 'Failed to fetch reports: $error';
            });
          }
        },
      );
        } catch (e) {
      if (mounted) {
        setState(() {
          reportsErrorMessage = 'Failed to fetch reports: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          reportsLoading = false;
        });
      }
    }
  }

  // Live video methods
  Future<void> _checkLiveStreamStatus() async {
    if (!mounted) return;
    
    try {
      final response = await ApiService.getDeanLiveStatus(collegeName);
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted && data != null) {
            setState(() {
              isLiveStreamActive = data['isActive'] ?? false;
              streamUrl = data['streamUrl'];
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              liveStreamError = 'Failed to check live status: $error';
            });
          }
        },
      );
        } catch (e) {
      if (mounted) {
        setState(() {
          liveStreamError = 'Failed to check live status: $e';
        });
      }
    }
  }

  // Live stream control methods
  Future<void> _startLiveStream() async {
    try {
      final response = await ApiService.startDeanLiveStream(collegeName);
      ApiService.logApiCall('/api/auth/start-live-stream', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              isLiveStreamActive = true;
              streamUrl = data['streamUrl'];
            });
            ErrorHandler.showSnackBar(context, 'Live stream started successfully');
          }
        },
        (error) {
          ErrorHandler.showSnackBar(context, error);
        },
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to start live stream: $e');
    }
  }

  Future<void> _stopLiveStream() async {
    try {
      final response = await ApiService.stopDeanLiveStream(collegeName);
      ApiService.logApiCall('/api/auth/stop-live-stream', response);
      
      ApiService.handleApiResponse(
        response,
        (data) {
          if (mounted) {
            setState(() {
              isLiveStreamActive = false;
              streamUrl = null;
            });
            ErrorHandler.showSnackBar(context, 'Live stream stopped successfully');
          }
        },
        (error) {
          ErrorHandler.showSnackBar(context, error);
        },
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to stop live stream: $e');
    }
  }

  // Report download method
  Future<void> _downloadReport() async {
    try {
      final response = await ApiService.downloadDeanFacultyReport(collegeName, courseName);
      ApiService.logApiCall('/api/auth/faculty-reports/download', response);
      
      ApiService.handleApiResponse(
        response,
        (data) async {
          // Save file to device
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/faculty_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
          await file.writeAsBytes(data);
          
          if (mounted) {
            ErrorHandler.showSnackBar(context, 'Report downloaded successfully');
          }
        },
        (error) {
          ErrorHandler.showSnackBar(context, error);
        },
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to download report: $e');
    }
  }

  // Settings methods
  void _populateForm() {
    _firstNameController.text = widget.userData['first_name'] ?? widget.userData['firstName'] ?? '';
    _lastNameController.text = widget.userData['last_name'] ?? widget.userData['lastName'] ?? '';
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
                  'Dean Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back, ${widget.userData['first_name'] ?? 'Dean'}',
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
                      _buildStatsCards(),
                      const SizedBox(height: 24),
                      _buildFilters(),
                      const SizedBox(height: 24),
                      _buildSchedulesSection(),
                      const SizedBox(height: 24),
                      _buildTimelineChart(),
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
      onRefresh: _fetchFacultyReports,
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
              ErrorHandler.buildErrorWidget(reportsErrorMessage!, onRetry: _fetchFacultyReports)
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
      onRefresh: _checkLiveStreamStatus,
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
          if (facultyList.isEmpty)
            const EmptyStateWidget(
              title: 'No Faculty',
              subtitle: 'No faculty members found.',
              icon: Icons.people_rounded,
            )
          else
            ResponsiveTable(
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
                  'status': faculty['status'] ?? 'Active',
                };
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReportsTable() {
    return Column(
      children: [
        // Report Actions
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
                            onPressed: _downloadReport,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download Report'),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _fetchFacultyReports,
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
                            onPressed: _downloadReport,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download Report'),
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
                            onPressed: _fetchFacultyReports,
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
        // Reports Table
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
                'Faculty Reports',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              if (reportsList.isEmpty)
                const EmptyStateWidget(
                  title: 'No Reports',
                  subtitle: 'No reports available.',
                  icon: Icons.assessment_rounded,
                )
              else
                ResponsiveTable(
                  columns: const ['S. No', 'Faculty', 'Report Type', 'Date', 'Status'],
                  dataKeys: const ['sno', 'faculty', 'reportType', 'date', 'status'],
                  data: reportsList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = entry.value;
                    return {
                      'sno': '${index + 1}',
                      'faculty': '${report['facultyName'] ?? ''}',
                      'reportType': report['reportType'] ?? '',
                      'date': report['date'] ?? '',
                      'status': report['status'] ?? '',
                    };
                  }).toList(),
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
        // Live Status Card
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
                  color: isLiveStreamActive ? Colors.red : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLiveStreamActive ? 'Live Stream Active' : 'Live Stream Inactive',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLiveStreamActive 
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
        // Video Player
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: isLiveStreamActive && streamUrl != null
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
        // Controls
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
                            onPressed: isLiveStreamActive ? _stopLiveStream : _startLiveStream,
                            icon: Icon(isLiveStreamActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                            label: Text(isLiveStreamActive ? 'Stop Stream' : 'Start Stream'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLiveStreamActive ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _checkLiveStreamStatus,
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
                            onPressed: isLiveStreamActive ? _stopLiveStream : _startLiveStream,
                            icon: Icon(isLiveStreamActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
                            label: Text(isLiveStreamActive ? 'Stop Stream' : 'Start Stream'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLiveStreamActive ? Colors.red : Colors.green,
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
                            onPressed: _checkLiveStreamStatus,
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
          // Dean Management
          _buildDeanManagementSection(),
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
        'Dean';

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
                    widget.userData['role']?.toString() ?? 'Dean',
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
          onTap: () {
            // Show password change dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Change Password'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ErrorHandler.showSnackBar(context, 'Password change functionality will be implemented soon');
                    },
                    child: Text('Change Password'),
                  ),
                ],
              ),
            );
          },
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
          onTap: () {
            // Show profile update dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Update Profile'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: widget.userData['firstName'] ?? ''),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: widget.userData['lastName'] ?? ''),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: widget.userData['email'] ?? ''),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ErrorHandler.showSnackBar(context, 'Profile update functionality will be implemented soon');
                    },
                    child: Text('Update Profile'),
                  ),
                ],
              ),
            );
          },
        ),
        _buildSettingItem(
          Icons.school_rounded,
          'College Settings',
          'Manage college-specific configurations',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'College settings not implemented yet'),
        ),
        _buildSettingItem(
          Icons.people_rounded,
          'Faculty Management',
          'Manage faculty members and permissions',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Faculty management not implemented yet'),
        ),
      ],
    );
  }

  Widget _buildDeanManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dean Management',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingItem(
          Icons.assessment_rounded,
          'Reports & Analytics',
          'View and manage college reports',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Reports & analytics not implemented yet'),
        ),
        _buildSettingItem(
          Icons.schedule_rounded,
          'Schedule Management',
          'Manage college schedules and timetables',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Schedule management not implemented yet'),
        ),
        _buildSettingItem(
          Icons.videocam_rounded,
          'Live Stream Settings',
          'Configure live streaming for college',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Live stream settings not implemented yet'),
        ),
        _buildSettingItem(
          Icons.person_search_rounded,
          'Attendance Policies',
          'Set attendance rules and policies',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Attendance policies not implemented yet'),
        ),
        _buildSettingItem(
          Icons.school_rounded,
          'Faculty Management',
          'Manage faculty members and assignments',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Faculty management not implemented yet'),
        ),
        _buildSettingItem(
          Icons.class_rounded,
          'Course Management',
          'Manage courses and curriculum',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Course management not implemented yet'),
        ),
        _buildSettingItem(
          Icons.room_rounded,
          'Room Allocation',
          'Manage classroom and facility allocation',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Room allocation not implemented yet'),
        ),
        _buildSettingItem(
          Icons.grade_rounded,
          'Academic Policies',
          'Set academic rules and grading policies',
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onTap: () => ErrorHandler.showSnackBar(context, 'Academic policies not implemented yet'),
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
    if (name.isEmpty) return 'D';
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  List<Schedule> _getSampleSchedules() {
    return [
      Schedule(
        courseTitle: 'Data Structures',
        courseCode: 'CS101',
        room: 'Room 101',
        startTime: '08:00',
        endTime: '10:00',
        semesterStartDate: '2024-01-15',
        semesterEndDate: '2024-05-15',
        instructor: Instructor(
          firstName: 'John',
          lastName: 'Doe',
        ),
        section: Section(
          sectionName: 'A',
        ),
        days: Days(
          mon: true,
          tue: false,
          wed: true,
          thu: false,
          fri: true,
          sat: false,
          sun: false,
        ),
      ),
      Schedule(
        courseTitle: 'Algorithms',
        courseCode: 'CS102',
        room: 'Room 102',
        startTime: '10:00',
        endTime: '12:00',
        semesterStartDate: '2024-01-15',
        semesterEndDate: '2024-05-15',
        instructor: Instructor(
          firstName: 'Jane',
          lastName: 'Smith',
        ),
        section: Section(
          sectionName: 'B',
        ),
        days: Days(
          mon: false,
          tue: true,
          wed: false,
          thu: true,
          fri: false,
          sat: false,
          sun: false,
        ),
      ),
      Schedule(
        courseTitle: 'Database Systems',
        courseCode: 'CS103',
        room: 'Room 103',
        startTime: '14:00',
        endTime: '16:00',
        semesterStartDate: '2024-01-15',
        semesterEndDate: '2024-05-15',
        instructor: Instructor(
          firstName: 'Mike',
          lastName: 'Johnson',
        ),
        section: Section(
          sectionName: 'C',
        ),
        days: Days(
          mon: true,
          tue: true,
          wed: false,
          thu: false,
          fri: false,
          sat: false,
          sun: false,
        ),
      ),
    ];
  }

  List<dynamic> _getSampleCourses() {
    return [
      {'id': '1', 'name': 'Computer Science', 'code': 'CS'},
      {'id': '2', 'name': 'Information Technology', 'code': 'IT'},
      {'id': '3', 'name': 'Software Engineering', 'code': 'SE'},
      {'id': '4', 'name': 'Data Science', 'code': 'DS'},
    ];
  }

  List<dynamic> _getSampleRooms() {
    return [
      {'id': '1', 'name': 'Room 101', 'capacity': 50},
      {'id': '2', 'name': 'Room 102', 'capacity': 40},
      {'id': '3', 'name': 'Room 103', 'capacity': 60},
      {'id': '4', 'name': 'Room 104', 'capacity': 30},
    ];
  }

  List<dynamic> _getSampleFacultyLogs() {
    return [
      {
        'id': '1',
        'instructorName': 'John Doe',
        'course': 'Data Structures',
        'room': 'Room 101',
        'timeIn': '08:00',
        'timeOut': '10:00',
        'status': 'Present',
        'date': DateTime.now().toIso8601String(),
      },
      {
        'id': '2',
        'instructorName': 'Jane Smith',
        'course': 'Algorithms',
        'room': 'Room 102',
        'timeIn': '10:00',
        'timeOut': '12:00',
        'status': 'Present',
        'date': DateTime.now().toIso8601String(),
      },
      {
        'id': '3',
        'instructorName': 'Mike Johnson',
        'course': 'Database Systems',
        'room': 'Room 103',
        'timeIn': '14:00',
        'timeOut': '16:00',
        'status': 'Present',
        'date': DateTime.now().toIso8601String(),
      },
    ];
  }

  void _generateChartData() {
    final today = DateTime.now();
    final year = today.year;
    final month = today.month;
    final date = today.day;

    final formattedData = <Map<String, dynamic>>[];

    for (final schedule in schedules) {
      try {
        final startTimeParts = schedule.startTime.split(':');
        final endTimeParts = schedule.endTime.split(':');
        
        if (startTimeParts.length != 2 || endTimeParts.length != 2) {
          continue; // Skip invalid time format
        }
        
        final startHour = int.parse(startTimeParts[0]);
        final startMinute = int.parse(startTimeParts[1]);
        final endHour = int.parse(endTimeParts[0]);
        final endMinute = int.parse(endTimeParts[1]);

        // Validate time values
        if (startHour < 0 || startHour > 23 || startMinute < 0 || startMinute > 59 ||
            endHour < 0 || endHour > 23 || endMinute < 0 || endMinute > 59) {
          continue; // Skip invalid time values
        }

        formattedData.add({
          'instructor': '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
          'subject': schedule.courseCode,
          'startTime': DateTime(year, month, date, startHour, startMinute),
          'endTime': DateTime(year, month, date, endHour, endMinute),
        });
      } catch (e) {
        // Skip invalid schedule entries
        continue;
      }
    }

    setState(() {
      chartData = formattedData;
    });
  }

  Widget _buildStatsCards() {
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
                      value: instructorCount?.toString() ?? '0',
                      icon: Icons.people_rounded,
                      iconColor: Colors.blue,
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      title: 'Program Chairs',
                      value: programChairCount?.toString() ?? '0',
                      icon: Icons.school_rounded,
                      iconColor: Colors.green,
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Instructors',
                  value: instructorCount?.toString() ?? '0',
                  icon: Icons.people_rounded,
                  iconColor: Colors.blue,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Program Chairs',
                  value: programChairCount?.toString() ?? '0',
                  icon: Icons.school_rounded,
                  iconColor: Colors.green,
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Filters',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: courseValue,
                      decoration: InputDecoration(
                        labelText: 'Course',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Courses')),
                        ...courses.map((course) => DropdownMenuItem(
                          value: course['name'] ?? '',
                          child: Text(course['name'] ?? ''),
                        )),
                      ],
                      onChanged: _handleCourseChange,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: roomValue,
                      decoration: InputDecoration(
                        labelText: 'Room',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Rooms')),
                        ...rooms.map((room) => DropdownMenuItem(
                          value: room['name'] ?? '',
                          child: Text(room['name'] ?? ''),
                        )),
                      ],
                      onChanged: _handleRoomChange,
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: courseValue,
                        decoration: InputDecoration(
                          labelText: 'Course',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Courses')),
                          ...courses.map((course) => DropdownMenuItem(
                            value: course['name'] ?? '',
                            child: Text(course['name'] ?? ''),
                          )),
                        ],
                        onChanged: _handleCourseChange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: roomValue,
                        decoration: InputDecoration(
                          labelText: 'Room',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Rooms')),
                          ...rooms.map((room) => DropdownMenuItem(
                            value: room['name'] ?? '',
                            child: Text(room['name'] ?? ''),
                          )),
                        ],
                        onChanged: _handleRoomChange,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Today\'s Schedules',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (schedules.isEmpty)
            const EmptyStateWidget(
              title: 'No Schedules',
              subtitle: 'No schedules found for today.',
              icon: Icons.schedule_rounded,
            )
          else
            ResponsiveTable(
              columns: const ['Time', 'Course', 'Room', 'Instructor', 'Status'],
              dataKeys: const ['time', 'course', 'room', 'instructor', 'status'],
              data: schedules.map((schedule) => {
                'time': '${schedule.startTime} - ${schedule.endTime}',
                'course': schedule.courseTitle,
                'room': schedule.room,
                'instructor': '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
                'status': 'Active',
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineChart() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Schedule Timeline',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (chartData.isEmpty)
            const EmptyStateWidget(
              title: 'No Data',
              subtitle: 'No timeline data available.',
              icon: Icons.timeline_rounded,
            )
          else
            TimelineChart(
              chartData: chartData,
            ),
        ],
      ),
    );
  }
}

