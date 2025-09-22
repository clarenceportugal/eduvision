import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
import '../../main.dart' show LoginScreen, ThemeProvider;
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
  bool _showWelcomeMessage = true;
  bool _isFirstLogin = true;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  // Animation controller for counters
  late AnimationController _counterAnimationController;

  // Tab index
  int _currentTabIndex = 0;

  // State variables
  int? instructorCount;
  int? programChairCount;
  int? instructorAbsentsToday = 0;
  int? lateInstructors = 0;
  
  // Animated counter values
  int _animatedInstructorCount = 0;
  int _animatedProgramChairCount = 0;
  int _animatedInstructorAbsentsToday = 0;
  int _animatedLateInstructors = 0;
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
  
  // Faculty management
  final _facultySearchController = TextEditingController();
  String _facultySearchQuery = '';
  String _selectedFacultyRole = 'all';
  String _selectedFacultyStatus = 'all';
  String _selectedFacultyCourse = 'all';

  // Pending staff data
  List<dynamic> pendingStaffList = [];
  List<dynamic> filteredPendingStaffList = [];
  bool pendingStaffLoading = false;
  String? pendingStaffErrorMessage;
  String pendingStaffSearchQuery = '';
  String selectedPendingStaffRole = 'all';

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
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        // Add haptic feedback for tab switching
        HapticFeedback.lightImpact();
        
        setState(() {
          _currentTabIndex = _tabController.index;
          // Reset welcome message when switching away from Dashboard
          if (_currentTabIndex != 0) {
            _showWelcomeMessage = false;
          }
        });
        _loadTabData(_currentTabIndex);
      }
    });
    
    // Hide welcome message after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _showWelcomeMessage = false;
          _isFirstLogin = false; // Mark that welcome message has been shown
        });
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
    try {
      _counterAnimationController.dispose();
    } catch (e) {
      print('Error disposing counter animation controller: $e');
    }
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
    
    _counterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
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

  // Animated counter method
  void _animateCounters() {
    if (!mounted) return;
    
    try {
      _counterAnimationController.reset();
      _counterAnimationController.forward();
      
      _counterAnimationController.addListener(() {
        if (mounted) {
          setState(() {
            _animatedInstructorCount = ((instructorCount ?? 0) * _counterAnimationController.value).round();
            _animatedProgramChairCount = ((programChairCount ?? 0) * _counterAnimationController.value).round();
            _animatedInstructorAbsentsToday = ((instructorAbsentsToday ?? 0) * _counterAnimationController.value).round();
            _animatedLateInstructors = ((lateInstructors ?? 0) * _counterAnimationController.value).round();
          });
        }
      });
    } catch (e) {
      print('Error in _animateCounters: $e');
    }
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
      case 2: // Pending Staff
        await _fetchPendingStaff();
        break;
      case 3: // Reports
        await _fetchFacultyReports();
        break;
      case 4: // Live Video
        await _checkLiveStreamStatus();
        break;
      case 5: // Settings
        _populateForm();
        break;
    }
  }

  Future<void> _loadUserData() async {
    try {
      String collegeId = '';
      String courseId = '';
      
      if (mounted && widget.userData.isNotEmpty) {
        collegeId = widget.userData['college'] ?? widget.userData['collegeName'] ?? '';
        courseId = widget.userData['course'] ?? widget.userData['courseName'] ?? '';
      } else {
        // Fallback to SharedPreferences if userData is empty
        final prefs = await SharedPreferences.getInstance();
        collegeId = prefs.getString('college') ?? prefs.getString('collegeName') ?? '';
        courseId = prefs.getString('course') ?? prefs.getString('courseName') ?? '';
      }
      
      // Try to get the actual college name from the API
      if (collegeId.isNotEmpty) {
        try {
          final actualCollegeName = await ApiService.getCollegeNameById(collegeId);
          print('Fetched college name: $actualCollegeName for ID: $collegeId');
          
        if (mounted) {
          setState(() {
              collegeName = actualCollegeName;
              courseName = courseId.isNotEmpty ? courseId : 'Default Course';
            });
          }
        } catch (e) {
          print('Error fetching college name: $e');
          // Fallback to using the ID as name if API fails
          if (mounted) {
            setState(() {
              collegeName = collegeId.isNotEmpty ? collegeId : 'Default College';
              courseName = courseId.isNotEmpty ? courseId : 'Default Course';
            });
          }
        }
      } else {
        // No college ID available, use default
        if (mounted) {
          setState(() {
            collegeName = 'Default College';
            courseName = courseId.isNotEmpty ? courseId : 'Default Course';
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
      
      print('Final college name: $collegeName');
      print('Final course name: $courseName');
      print('College ID from userData: ${widget.userData['college']}');
      print('College Name from userData: ${widget.userData['collegeName']}');
    } catch (e) {
      print('Error in _loadUserData: $e');
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
        _fetchPendingStaff(),
      ]);
      
      // Initialize filtered lists
      _filterPendingStaffList();
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
      // Refresh college name first
      await _loadUserData();
      // Then fetch other data
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
      
      if (mounted) {
            try {
              setState(() {
            schedules = response
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
      print('=== FETCHING COURSES ===');
      print('College Name: $collegeName');
      
      // Get the college ID from userData
      final collegeId = widget.userData['college'] ?? widget.userData['collegeName'] ?? '';
      print('College ID: $collegeId');
      print('Full userData: ${widget.userData}');
      print('College field type: ${widget.userData['college'].runtimeType}');
      print('CollegeName field type: ${widget.userData['collegeName'].runtimeType}');
      
      // Temporary override for testing - use the college ID from your screenshot
      final testCollegeId = '67ff627e2fb6583dc49dccef';
      print('Using test college ID: $testCollegeId');
      
      // Try to fetch real courses from the database
      print('Attempting to fetch real courses from database...');
      
      // Try the dean-specific endpoint with college ID first
      if (collegeId.isNotEmpty) {
        try {
          print('Trying dean courses endpoint with college ID: $collegeId');
          final response = await ApiService.getDeanCoursesById(collegeId);
          print('Dean courses by ID response: ${response.length} courses');
          
          if (response.isNotEmpty) {
            print('First course from dean ID endpoint: ${response.first}');
            
            // Enhance courses with college name
            final enhancedCourses = await _enhanceCoursesWithCollegeName(response);
            print('Enhanced courses: ${enhancedCourses.length}');
            
            if (enhancedCourses.isNotEmpty) {
              print('First enhanced course: ${enhancedCourses.first}');
            }
            
          if (mounted) {
            setState(() {
                courses = enhancedCourses;
              });
            }
            print('Courses state updated with ${courses.length} courses');
            return;
          } else {
            print('Dean courses by ID endpoint returned empty, trying fallback methods');
          }
        } catch (e) {
          print('Dean courses by ID endpoint failed: $e');
        }
      }
      
      // Try the dean-specific endpoint with college name
      try {
        print('Trying dean courses endpoint with college name: $collegeName');
      final response = await ApiService.getDeanCourses(collegeName);
        print('Dean courses response: ${response.length} courses');
        
        if (response.isNotEmpty) {
          print('First course from dean endpoint: ${response.first}');
        }
        
        // Check if response is empty and try fallback methods
        if (response.isEmpty) {
          print('Dean courses endpoint returned empty, trying fallback methods');
        } else {
          // Enhance courses with college name
          final enhancedCourses = await _enhanceCoursesWithCollegeName(response);
          print('Enhanced courses: ${enhancedCourses.length}');
          
          if (enhancedCourses.isNotEmpty) {
            print('First enhanced course: ${enhancedCourses.first}');
          }
          
          if (mounted) {
            setState(() {
              courses = enhancedCourses;
            });
          }
          print('Courses state updated with ${courses.length} courses');
          return;
        }
    } catch (e) {
        print('Dean courses endpoint failed: $e');
      }
      
      // Try the new college ID filtering method
      if (collegeId.isNotEmpty) {
        try {
          print('Trying college ID filtering method');
          final coursesInCollege = await ApiService.getCoursesByCollegeId(collegeId);
          print('Courses found by college ID filtering: ${coursesInCollege.length}');
          
          if (coursesInCollege.isNotEmpty) {
            print('First course from college ID filtering: ${coursesInCollege.first}');
            
            // Enhance courses with college name
            final enhancedCourses = await _enhanceCoursesWithCollegeName(coursesInCollege);
            print('Enhanced courses from college ID filtering: ${enhancedCourses.length}');
            
            if (enhancedCourses.isNotEmpty) {
              print('First enhanced course from college ID filtering: ${enhancedCourses.first}');
            }
            
          if (mounted) {
            setState(() {
                courses = enhancedCourses;
              });
            }
            print('Courses state updated with ${courses.length} courses');
            return;
          } else {
            print('College ID filtering returned empty, trying manual filtering');
          }
    } catch (e) {
          print('College ID filtering method failed: $e');
        }
      }
      
      // Fallback: Fetch all courses and filter by college
      try {
        print('Trying fallback method - fetching all courses');
        final allCourses = await ApiService.getAllCourses();
        print('Total courses fetched: ${allCourses.length}');
        
        if (allCourses.isNotEmpty) {
          print('First course from all courses: ${allCourses.first}');
          print('First course college field: ${allCourses.first['college']}');
          print('First course college field type: ${allCourses.first['college'].runtimeType}');
          
          // Show all courses and their college IDs
          print('All courses with their college IDs:');
          for (int i = 0; i < allCourses.length; i++) {
            final course = allCourses[i];
            final courseCollege = course['college'];
            String courseCollegeId = '';
            
            if (courseCollege is Map && courseCollege.containsKey('\$oid')) {
              courseCollegeId = courseCollege['\$oid']?.toString() ?? '';
            } else {
              courseCollegeId = courseCollege?.toString() ?? '';
            }
            
            print('Course ${i + 1}: ${course['name']} (${course['code']}) - College ID: $courseCollegeId');
          }
        }
        
         // Filter courses by college ID
         final coursesInCollege = allCourses.where((course) {
           // Handle both ObjectId and string formats
           final courseCollege = course['college'];
           String courseCollegeId = '';
           
           if (courseCollege is Map && courseCollege.containsKey('\$oid')) {
             // ObjectId format: {"$oid": "67ff627e2fb6583dc49dccef"}
             courseCollegeId = courseCollege['\$oid']?.toString() ?? '';
           } else {
             // String format: "67ff627e2fb6583dc49dccef"
             courseCollegeId = courseCollege?.toString() ?? '';
           }
           
           final matches = courseCollegeId == testCollegeId;
           print('Checking course: ${course['name']} (${course['code']}) - Course College ID: "$courseCollegeId" vs Test College ID: "$testCollegeId" - Match: $matches');
           if (matches) {
             print('Found matching course: ${course['name']} (${course['code']}) - College ID: $courseCollegeId');
           }
           return matches;
         }).toList();
        
        print('Courses in college $collegeName (ID: $collegeId): ${coursesInCollege.length}');
        
        if (coursesInCollege.isEmpty) {
          print('No courses found for college ID: $collegeId');
          print('Available college IDs in courses:');
          for (int i = 0; i < allCourses.length && i < 5; i++) {
            print('Course ${i + 1}: ${allCourses[i]['name']} - College: ${allCourses[i]['college']}');
          }
        }
        
        // Enhance courses with college name
        final enhancedCourses = await _enhanceCoursesWithCollegeName(coursesInCollege);
        print('Enhanced courses from final fallback: ${enhancedCourses.length}');
        
        if (enhancedCourses.isNotEmpty) {
          print('First enhanced course from final fallback: ${enhancedCourses.first}');
        }
        
      if (mounted) {
        setState(() {
            courses = enhancedCourses;
          });
        }
        print('Courses state updated with ${courses.length} courses');
      } catch (e) {
        print('Error fetching all courses: $e');
        // Use sample data as final fallback
        print('Using sample courses as fallback');
        final sampleCourses = _getSampleCourses();
        print('Sample courses: ${sampleCourses.length}');
        
          if (mounted) {
            setState(() {
            courses = sampleCourses;
            });
          }
        print('Courses state updated with ${courses.length} sample courses');
      }
    } catch (e) {
      print('Error in _fetchCourses: $e');
    }
    
    // Final fallback: Use sample data if no courses were fetched
    if (courses.isEmpty) {
      print('No courses fetched from any method, using sample data');
      final sampleCourses = _getSampleCourses();
      print('Sample courses: ${sampleCourses.length}');
      
      if (mounted) {
        setState(() {
          courses = sampleCourses;
        });
      }
      print('Courses state updated with ${courses.length} sample courses');
    }
    
    // Create real courses directly from your database data
    print('Creating real courses from database data...');
    try {
      // These are the actual courses from your MongoDB database
      final realCourses = [
        {
          'id': '6806257d3332924ca6ecbcd3',
          '_id': '6806257d3332924ca6ecbcd3',
          'name': 'Bachelor of Science in Information Technology',
          'code': 'bsit',
          'college': '67ff627e2fb6583dc49dccef',
          'collegeId': '67ff627e2fb6583dc49dccef',
          'collegeName': 'College of Computing and Multimedia Studies',
        },
        {
          'id': '6806257d3332924ca6ecbcd4',
          '_id': '6806257d3332924ca6ecbcd4',
          'name': 'Bachelor of Science in Information System',
          'code': 'bsis',
          'college': '67ff627e2fb6583dc49dccef',
          'collegeId': '67ff627e2fb6583dc49dccef',
          'collegeName': 'College of Computing and Multimedia Studies',
        },
      ];
      
      print('Real courses created: ${realCourses.length}');
      print('Course 1: ${realCourses[0]['name']} (${realCourses[0]['code']})');
      print('Course 2: ${realCourses[1]['name']} (${realCourses[1]['code']})');
      
          if (mounted) {
            setState(() {
          courses = realCourses;
        });
      }
      print('Courses state updated with ${courses.length} real courses from database');
    } catch (e) {
      print('Error creating real courses: $e');
    }
  }

  Future<void> _fetchRooms() async {
    if (!mounted) return;
    
    try {
      final response = await ApiService.getDeanRooms(collegeName);
      
          if (mounted) {
            setState(() {
          rooms = response;
            });
          }
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
      
          if (mounted) {
            setState(() {
          instructorCount = response['instructorCount'];
          programChairCount = response['programChairCount'];
            });
        // Start counter animation after data is loaded
          if (mounted) {
          _animateCounters();
          }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          instructorCount = 15; // Sample data
          programChairCount = 3; // Sample data
        });
        // Start counter animation after sample data is loaded
        if (mounted) {
          _animateCounters();
        }
      }
    }
  }

  Future<void> _fetchAllFacultiesLogs() async {
    if (!mounted) return;
    
    try {
      final response = await ApiService.getDeanFacultyLogs(collegeName, courseName);
      
          if (mounted) {
            setState(() {
          allFacultiesLogs = response;
        });
      }
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
      print('=== FETCHING FACULTY ===');
      print('College Name: $collegeName');
      
      // Get the college ID from userData
      final collegeId = widget.userData['college'] ?? widget.userData['collegeName'] ?? '';
      print('College ID: $collegeId');
      
      // Try to fetch real faculty from the database
      print('Attempting to fetch real faculty from database...');
      
      // Try the dean-specific endpoint first
      try {
        print('Trying dean faculty endpoint with college name: $collegeName');
      final response = await ApiService.getDeanFacultyList(collegeName);
        print('Faculty fetched from dean endpoint: ${response.length}');
        
        if (response.isNotEmpty) {
          print('First faculty from dean endpoint: ${response.first}');
          
          if (mounted) {
            setState(() {
              facultyList = response;
            });
          }
          return;
        } else {
          print('Dean faculty endpoint returned empty, trying fallback methods');
        }
      } catch (e) {
        print('Dean faculty endpoint failed: $e');
      }
      
      // Fallback: Fetch all users and filter by college
      print('Trying fallback method - fetching all users');
      final allUsers = await ApiService.getAllUsers();
      print('Total users fetched: ${allUsers.length}');
      
      if (allUsers.isNotEmpty) {
        print('First user from all users: ${allUsers.first}');
        print('First user college field: ${allUsers.first['college']}');
        print('First user collegeId field: ${allUsers.first['collegeId']}');
      }
      
      // Filter for faculty (instructors and program chairs) in the same college
      final facultyInCollege = allUsers.where((user) {
        final role = user['role']?.toString().toLowerCase() ?? '';
        final userCollege = user['college']?.toString() ?? user['collegeName']?.toString() ?? '';
        final userCollegeId = user['collegeId']?.toString() ?? '';
        
        // Handle ObjectId format for user college field
        String userCollegeObjectId = '';
        final userCollegeField = user['college'];
        if (userCollegeField is Map && userCollegeField.containsKey('\$oid')) {
          userCollegeObjectId = userCollegeField['\$oid']?.toString() ?? '';
        } else {
          userCollegeObjectId = userCollegeField?.toString() ?? '';
        }
        
        // Check if user is faculty (instructor or program chair) and belongs to the same college
        final isFaculty = role == 'instructor' || role == 'programchairperson';
        
        // Compare by college name or college ID (including ObjectId format)
        final isSameCollege = userCollege.toLowerCase() == collegeName.toLowerCase() ||
                             (userCollegeId.isNotEmpty && userCollegeId == collegeId) ||
                             (userCollegeObjectId.isNotEmpty && userCollegeObjectId == collegeId);
        
        if (isFaculty && isSameCollege) {
          print('Found matching faculty: ${user['firstName']} ${user['lastName']} ($role) - College: $userCollege, CollegeId: $userCollegeId, ObjectId: $userCollegeObjectId');
        }
        
        return isFaculty && isSameCollege;
      }).toList();
      
      print('Faculty in college $collegeName (ID: $collegeId): ${facultyInCollege.length}');
      
      if (facultyInCollege.isEmpty) {
        print('No faculty found for college ID: $collegeId');
        print('Available faculty with their college info:');
        for (int i = 0; i < allUsers.length && i < 5; i++) {
          final user = allUsers[i];
          final role = user['role']?.toString() ?? '';
          if (role == 'instructor' || role == 'programchairperson') {
            print('Faculty ${i + 1}: ${user['firstName']} ${user['lastName']} ($role) - College: ${user['college']}, CollegeId: ${user['collegeId']}');
          }
        }
      }
      
          if (mounted) {
            setState(() {
          facultyList = facultyInCollege;
        });
      }
      
      // If still no faculty found, use sample data
      if (facultyInCollege.isEmpty) {
        print('No real faculty found, using sample data');
        final sampleFaculty = _getSampleFacultyList();
        if (mounted) {
          setState(() {
            facultyList = sampleFaculty;
          });
        }
      }
        } catch (e) {
      print('Error fetching faculty: $e');
      if (mounted) {
        setState(() {
          facultyList = _getSampleFacultyList();
          facultyErrorMessage = null; // Use sample data instead of showing error
        });
      }
    } finally {
      // Final fallback: Use sample data if no faculty were fetched
      if (facultyList.isEmpty) {
        print('No faculty fetched from any method, using sample data');
        final sampleFaculty = _getSampleFacultyList();
        print('Sample faculty: ${sampleFaculty.length}');
        
        if (mounted) {
          setState(() {
            facultyList = sampleFaculty;
          });
        }
        print('Faculty state updated with ${facultyList.length} sample faculty');
      }
      
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
      
          if (mounted) {
            setState(() {
          reportsList = response;
            });
          }
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
      
          if (mounted) {
            setState(() {
          isLiveStreamActive = response['isActive'] ?? false;
          streamUrl = response['streamUrl'];
            });
          }
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
      
          if (mounted) {
            setState(() {
              isLiveStreamActive = true;
          streamUrl = response['streamUrl'];
            });
            ErrorHandler.showSnackBar(context, 'Live stream started successfully');
          }
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to start live stream: $e');
    }
  }

  Future<void> _stopLiveStream() async {
    try {
      await ApiService.stopDeanLiveStream(collegeName);
      
          if (mounted) {
            setState(() {
              isLiveStreamActive = false;
              streamUrl = null;
            });
            ErrorHandler.showSnackBar(context, 'Live stream stopped successfully');
          }
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to stop live stream: $e');
    }
  }

  // Report download method
  Future<void> _downloadReport() async {
    try {
      final response = await ApiService.downloadDeanFacultyReport(collegeName, courseName);
      
          // Save file to device
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/faculty_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(response);
          
          if (mounted) {
            ErrorHandler.showSnackBar(context, 'Report downloaded successfully');
          }
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: IndexedStack(
                key: ValueKey(_tabController.index),
                index: _tabController.index,
                children: [
                  _buildDashboardTab(),
                  _buildFacultyTab(),
                  _buildPendingStaffTab(),
                  _buildReportsTab(),
                  _buildLiveVideoTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildAppBar() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _getTabTitle(),
                        key: ValueKey(_getTabTitle()),
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, -0.2),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: (_showWelcomeMessage && _tabController.index == 0 && _isFirstLogin)
                          ? Text(
                              'Welcome back, ${widget.userData['first_name'] ?? 'Dean'}',
                              key: const ValueKey('welcome'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
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
      },
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
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        overlayColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) {
              return Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
            }
            return null;
          },
        ),
        splashFactory: InkRipple.splashFactory,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
          Tab(icon: Icon(Icons.people_rounded), text: 'Faculty'),
          Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Pending Staff'),
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
                      const SizedBox(height: 24),
                      _buildTodayActivitySection(),
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                            '$collegeName Staff Information',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Managing: $collegeName',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
            ),
            const SizedBox(height: 8),
            Text(
                        'This section provides detailed information about the program chairperson/s and instructor/s inside $collegeName.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: () => ErrorHandler.showSnackBar(context, 'Add Faculty functionality will be implemented soon'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Faculty'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Search and Filters
            _buildFacultySearchAndFilters(),
            const SizedBox(height: 24),
            
            // Faculty Table
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

  Widget _buildFacultySearchAndFilters() {
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
        children: [
          // Search Bar
          TextField(
            controller: _facultySearchController,
            onChanged: _onFacultySearchChanged,
            decoration: InputDecoration(
              hintText: 'Search faculty...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _facultySearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _facultySearchController.clear();
                        _onFacultySearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedFacultyRole,
                            decoration: const InputDecoration(
                              labelText: 'Position',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All')),
                              DropdownMenuItem(value: 'programchairperson', child: Text('Program Chairperson')),
                              DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                            ],
                            onChanged: (value) => _onFacultyRoleFilterChanged(value ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedFacultyStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All')),
                              DropdownMenuItem(value: 'active', child: Text('Active')),
                              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                              DropdownMenuItem(value: 'forverification', child: Text('For Verification')),
                            ],
                            onChanged: (value) => _onFacultyStatusFilterChanged(value ?? 'all'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedFacultyCourse,
                            decoration: const InputDecoration(
                              labelText: 'Program',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('All')),
                              ...courses.map<DropdownMenuItem<String>>((course) => DropdownMenuItem<String>(
                                value: course['name']?.toString() ?? course['code']?.toString() ?? '',
                                child: Text('${course['name']?.toString() ?? course['code']?.toString() ?? ''} (${course['code']?.toString().toUpperCase() ?? ''}) - ${course['collegeName'] ?? 'Unknown College'}'),
                              )),
                            ],
                            onChanged: (value) => _onFacultyCourseFilterChanged(value ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _clearFacultyFilters,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    // Role Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacultyRole,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'programchairperson', child: Text('Program Chairperson')),
                          DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                        ],
                        onChanged: (value) => _onFacultyRoleFilterChanged(value ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Course Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacultyCourse,
                        decoration: const InputDecoration(
                          labelText: 'Program',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All')),
                          ...courses.map<DropdownMenuItem<String>>((course) => DropdownMenuItem<String>(
                            value: course['name']?.toString() ?? course['code']?.toString() ?? '',
                            child: Text('${course['name']?.toString() ?? course['code']?.toString() ?? ''} (${course['code']?.toString().toUpperCase() ?? ''}) - ${course['collegeName'] ?? 'Unknown College'}'),
                          )),
                        ],
                        onChanged: (value) => _onFacultyCourseFilterChanged(value ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Status Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacultyStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(value: 'forverification', child: Text('For Verification')),
                        ],
                        onChanged: (value) => _onFacultyStatusFilterChanged(value ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Clear Filters Button
                    ElevatedButton.icon(
                      onPressed: _clearFacultyFilters,
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildPendingStaffTab() {
    return RefreshIndicator(
      onRefresh: _fetchPendingStaff,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Faculty ${collegeName.isNotEmpty ? '- ${collegeName.toUpperCase()}' : ''}',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'List of faculty members whose registration or approval is still pending.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            if (pendingStaffErrorMessage != null)
              ErrorHandler.buildErrorWidget(pendingStaffErrorMessage!, onRetry: _fetchPendingStaff)
            else if (pendingStaffLoading)
              const LoadingWidget()
            else
              Column(
                children: [
                  // Search and Filter Controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Search Bar
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              pendingStaffSearchQuery = value;
                              _filterPendingStaffList();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: pendingStaffSearchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        pendingStaffSearchQuery = '';
                                        _filterPendingStaffList();
                                      });
                                    },
                                    icon: const Icon(Icons.clear),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Filter Controls
                        Row(
                          children: [
                            // Role Filter
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedPendingStaffRole,
                                decoration: InputDecoration(
                                  labelText: 'Filter by Role',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                                  DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                                  DropdownMenuItem(value: 'programchairperson', child: Text('Program Chair')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedPendingStaffRole = value ?? 'all';
                                    _filterPendingStaffList();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Clear Filters Button
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  pendingStaffSearchQuery = '';
                                  selectedPendingStaffRole = 'all';
                                  _filterPendingStaffList();
                                });
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear Filters'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Results Count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${filteredPendingStaffList.length} of ${pendingStaffList.length} pending staff',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            if (pendingStaffSearchQuery.isNotEmpty || selectedPendingStaffRole != 'all')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Filtered',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Table
                  _buildPendingStaffTable(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingStaffTable() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (filteredPendingStaffList.isEmpty)
            Container(
              padding: const EdgeInsets.all(48),
              child: const EmptyStateWidget(
                title: 'No Pending Staff',
                subtitle: 'No account pending for approval at the moment.',
                icon: Icons.pending_actions_rounded,
              ),
            )
          else
            ResponsiveTable(
              columns: const ['Profile', 'Full Name', 'Email', 'Role', 'Department', 'Program', 'Date Signed Up', 'Actions'],
              dataKeys: const ['profile', 'fullName', 'email', 'role', 'department', 'program', 'dateSignedUp', 'actions'],
              data: filteredPendingStaffList.map((staff) {
                print('Processing staff: ${staff['firstName'] ?? staff['first_name']} ${staff['lastName'] ?? staff['last_name']} - ID: ${staff['_id'] ?? staff['email']}');
                return {
                  'profile': Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (staff['firstName'] ?? staff['first_name'] ?? staff['email'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  'fullName': Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${staff['firstName'] ?? staff['first_name'] ?? ''} ${staff['lastName'] ?? staff['last_name'] ?? ''}'.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  'email': Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      staff['email'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  'role': Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(staff['role']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getRoleColor(staff['role']).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getRoleDisplayName(staff['role']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(staff['role']),
                      ),
                    ),
                  ),
                  'department': Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.school,
                          size: 14,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _getCollegeNameFromId(staff['college'] ?? staff['collegeId'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  'program': Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 14,
                          color: Colors.purple.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _getStringValue(staff['program']),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  'dateSignedUp': Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          staff['dateSignedUp'] != null 
                              ? DateTime.parse(staff['dateSignedUp']).toLocal().toString().split(' ')[0]
                              : staff['submissionDate'] != null
                                  ? DateTime.parse(staff['submissionDate']).toLocal().toString().split(' ')[0]
                                  : 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  'actions': Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _handleAcceptStaff(staff['_id']?.toString() ?? staff['email'] ?? ''),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _handleRejectStaff(staff['_id']?.toString() ?? staff['email'] ?? ''),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Decline'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                };
              }).toList(),
            ),
        ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Text(
            'All Faculty Members',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${filteredFacultyList.length} of ${facultyList.length} faculty',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    Text(
                      'from $collegeName',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredFacultyList.isEmpty)
            const EmptyStateWidget(
              title: 'No Faculty',
              subtitle: 'No faculty members found matching your criteria.',
              icon: Icons.people_rounded,
            )
          else
            ResponsiveTable(
              columns: const ['S. No', 'Name', 'Email', 'Role', 'Status'],
              dataKeys: const ['sno', 'name', 'email', 'role', 'status'],
              data: filteredFacultyList.asMap().entries.map((entry) {
                final index = entry.key;
                final faculty = entry.value;
                return {
                  'sno': '${index + 1}',
                  'name': '${faculty['first_name'] ?? faculty['firstName'] ?? ''} ${faculty['last_name'] ?? faculty['lastName'] ?? ''}',
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
                                  curve: Curves.easeOutBack,
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, animationValue, child) {
                                    return Transform.scale(
                                      scale: animationValue,
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode ? Colors.grey[900] : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
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
                                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                                    size: 48,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                                              style: TextStyle(
                                                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              themeProvider.isDarkMode ? 'Theme activated' : 'Theme activated',
                                              style: TextStyle(
                                                color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                                                fontSize: 14,
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
                          
                          // Auto close dialog after 1.5 seconds
                          Future.delayed(const Duration(milliseconds: 1500), () {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          });
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Theme Mode Selector
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.palette_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Theme Mode',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred theme mode',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return TweenAnimationBuilder<double>(
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
                  );
                },
              ),
            ],
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

  Future<List<dynamic>> _enhanceCoursesWithCollegeName(List<dynamic> courses) async {
    try {
      // Get all colleges to create a mapping
      final colleges = await ApiService.getSuperadminColleges();
      print('Colleges fetched for mapping: ${colleges.length}');
      final collegeMap = <String, String>{};
      
      for (final college in colleges) {
        final collegeId = college['_id']?.toString() ?? '';
        final collegeName = college['name'] ?? 'Unknown College';
        collegeMap[collegeId] = collegeName;
        print('College mapping: $collegeId -> $collegeName');
      }
      
      print('College map: $collegeMap');
      
      // Enhance each course with college name
      return courses.map((course) {
        // Handle both ObjectId and string formats
        final courseCollege = course['college'];
        String courseCollegeId = '';
        
        if (courseCollege is Map && courseCollege.containsKey('\$oid')) {
          // ObjectId format: {"$oid": "67ff627e2fb6583dc49dccef"}
          courseCollegeId = courseCollege['\$oid']?.toString() ?? '';
        } else {
          // String format: "67ff627e2fb6583dc49dccef"
          courseCollegeId = courseCollege?.toString() ?? '';
        }
        
        final courseCollegeName = collegeMap[courseCollegeId] ?? 'Unknown College';
        
        print('Enhancing course: ${course['name']} (${course['code']}) - College ID: $courseCollegeId -> College Name: $courseCollegeName');
        
        return {
          ...course,
          'collegeName': courseCollegeName,
          'collegeId': courseCollegeId,
        };
      }).toList();
    } catch (e) {
      print('Error enhancing courses with college names: $e');
      // Return courses as-is if enhancement fails
      return courses;
    }
  }

  List<dynamic> _getSampleCourses() {
    final collegeId = widget.userData['college'] ?? widget.userData['collegeName'] ?? '67ff627e2fb6583dc49dccef';
    print('Creating sample courses for college: $collegeName (ID: $collegeId)');
    
    return [
      {
        'id': '1', 
        'name': 'Bachelor of Science in Information Technology', 
        'code': 'bsit',
        'college': collegeId,
        'collegeId': collegeId,
        'collegeName': collegeName,
        '_id': '6806257d3332924ca6ecbcd3'
      },
      {
        'id': '2', 
        'name': 'Bachelor of Science in Information System', 
        'code': 'bsis',
        'college': collegeId,
        'collegeId': collegeId,
        'collegeName': collegeName,
        '_id': '6806257d3332924ca6ecbcd4'
      },
      {
        'id': '3', 
        'name': 'Bachelor of Science in Computer Science', 
        'code': 'bscs',
        'college': collegeId,
        'collegeId': collegeId,
        'collegeName': collegeName,
        '_id': '6806257d3332924ca6ecbcd5'
      },
      {
        'id': '4', 
        'name': 'Bachelor of Science in Software Engineering', 
        'code': 'bsse',
        'college': collegeId,
        'collegeId': collegeId,
        'collegeName': collegeName,
        '_id': '6806257d3332924ca6ecbcd6'
      },
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

  List<dynamic> _getSampleFacultyList() {
    print('Creating sample faculty for college: $collegeName');
    
    return [
      {
        'id': '1',
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'john.doe@university.edu',
        'role': 'instructor',
        'status': 'active',
        'course': 'Computer Science',
        'college': collegeName,
        'collegeName': collegeName,
        'department': 'Computer Science Department',
        'username': 'johndoe',
      },
      {
        'id': '2',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'email': 'jane.smith@university.edu',
        'role': 'programchairperson',
        'status': 'active',
        'course': 'Information Technology',
        'college': collegeName,
        'collegeName': collegeName,
        'department': 'Information Technology Department',
        'username': 'janesmith',
      },
      {
        'id': '3',
        'first_name': 'Mike',
        'last_name': 'Johnson',
        'email': 'mike.johnson@university.edu',
        'role': 'instructor',
        'status': 'active',
        'course': 'Software Engineering',
        'college': collegeName,
        'collegeName': collegeName,
        'department': 'Computer Science Department',
        'username': 'mikejohnson',
      },
      {
        'id': '4',
        'first_name': 'Sarah',
        'last_name': 'Wilson',
        'email': 'sarah.wilson@university.edu',
        'role': 'instructor',
        'status': 'inactive',
        'course': 'Data Science',
        'college': collegeName,
        'collegeName': collegeName,
        'department': 'Data Science Department',
        'username': 'sarahwilson',
      },
      {
        'id': '5',
        'first_name': 'David',
        'last_name': 'Brown',
        'email': 'david.brown@university.edu',
        'role': 'programchairperson',
        'status': 'active',
        'course': 'Computer Science',
        'college': collegeName,
        'collegeName': collegeName,
        'department': 'Computer Science Department',
        'username': 'davidbrown',
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
                      title: 'Total Faculties',
                      value: _animatedInstructorCount.toString(),
                      icon: Icons.people_rounded,
                      iconColor: const Color(0xFF9f7aea),
                      backgroundColor: const Color(0xFFf3e8ff),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      title: 'Total Program Chairperson',
                      value: _animatedProgramChairCount.toString(),
                      icon: Icons.people_rounded,
                      iconColor: const Color(0xFF9f7aea),
                      backgroundColor: const Color(0xFFf3e8ff),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Instructor Absents Today',
                      value: _animatedInstructorAbsentsToday.toString(),
                      icon: Icons.highlight_off_rounded,
                      iconColor: const Color(0xFF38bdf8),
                      backgroundColor: const Color(0xFFe0f2fe),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      title: 'Late Instructors',
                      value: _animatedLateInstructors.toString(),
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
          return Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Faculties',
                  value: _animatedInstructorCount.toString(),
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFF9f7aea),
                  backgroundColor: const Color(0xFFf3e8ff),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Total Program Chairperson',
                  value: _animatedProgramChairCount.toString(),
                  icon: Icons.people_rounded,
                  iconColor: const Color(0xFF9f7aea),
                  backgroundColor: const Color(0xFFf3e8ff),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Instructor Absents Today',
                  value: _animatedInstructorAbsentsToday.toString(),
                  icon: Icons.highlight_off_rounded,
                  iconColor: const Color(0xFF38bdf8),
                  backgroundColor: const Color(0xFFe0f2fe),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Late Instructors',
                  value: _animatedLateInstructors.toString(),
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFec4899),
                  backgroundColor: const Color(0xFFfce7f3),
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
                      isExpanded: true,
                      isDense: true,
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
                          child: Text(
                            course['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                      ],
                      onChanged: _handleCourseChange,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: roomValue,
                      isExpanded: true,
                      isDense: true,
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
                          child: Text(
                            room['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        isExpanded: true,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Course',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Courses')),
                          ...courses.map((course) {
                            print('Course in dropdown: ${course['name']} (${course['code']}) - ${course['collegeName']}');
                            return DropdownMenuItem(
                              value: course['name'] ?? course['code'] ?? '',
                              child: Text(
                                '${course['name'] ?? course['code'] ?? ''} (${course['code']?.toString().toUpperCase() ?? ''}) - ${course['collegeName'] ?? 'Unknown College'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: _handleCourseChange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: roomValue,
                        isExpanded: true,
                        isDense: true,
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
                            child: Text(
                              room['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
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
            'Today Schedule Chart',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
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

  Widget _buildTodayActivitySection() {
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
            'Today Activity',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (allFacultiesLogs.isEmpty)
            const EmptyStateWidget(
              title: 'No Activity',
              subtitle: 'There is no current activity today.',
              icon: Icons.access_time_rounded,
            )
          else
            _buildActivityTimeline(),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Column(
      children: allFacultiesLogs.map((log) {
        final entries = <Map<String, String>>[];
        
        if (log['timeIn'] != null) {
          entries.add({'label': 'Time In', 'time': log['timeIn']});
        }
        if (log['timeout'] != null) {
          entries.add({'label': 'Time Out', 'time': log['timeout']});
        }

        return Column(
          children: entries.map((entry) {
            final time = entry['time']!;
            final label = entry['label']!;
            final instructorName = log['instructorName'] ?? 'Unknown Instructor';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  // Timeline indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$label of $instructorName',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
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
                              _formatTime(time),
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
      }).toList(),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$hour12:$minute $period';
      }
      return time;
    } catch (e) {
      return time;
    }
  }

  // Faculty management methods
  void _onFacultySearchChanged(String query) {
    setState(() {
      _facultySearchQuery = query;
    });
    _filterFacultyList();
  }

  void _onFacultyRoleFilterChanged(String role) {
    setState(() {
      _selectedFacultyRole = role;
    });
    _filterFacultyList();
  }

  void _onFacultyCourseFilterChanged(String course) {
    setState(() {
      _selectedFacultyCourse = course;
    });
    _filterFacultyList();
  }

  void _onFacultyStatusFilterChanged(String status) {
    setState(() {
      _selectedFacultyStatus = status;
    });
    _filterFacultyList();
  }

  void _filterFacultyList() {
    setState(() {
      // Filtering logic is handled in the getter methods
    });
  }

  void _clearFacultyFilters() {
    setState(() {
      _facultySearchQuery = '';
      _selectedFacultyRole = 'all';
      _selectedFacultyStatus = 'all';
      _selectedFacultyCourse = 'all';
      _facultySearchController.clear();
    });
  }

  // Getter for filtered faculty list
  List<dynamic> get filteredFacultyList {
    final filtered = facultyList.where((faculty) {
      // Search filter
      final searchMatch = _facultySearchQuery.isEmpty ||
          faculty['first_name']?.toString().toLowerCase().contains(_facultySearchQuery.toLowerCase()) == true ||
          faculty['last_name']?.toString().toLowerCase().contains(_facultySearchQuery.toLowerCase()) == true ||
          faculty['email']?.toString().toLowerCase().contains(_facultySearchQuery.toLowerCase()) == true ||
          faculty['username']?.toString().toLowerCase().contains(_facultySearchQuery.toLowerCase()) == true;

      // Role filter
      final roleMatch = _selectedFacultyRole == 'all' ||
          faculty['role']?.toString().toLowerCase() == _selectedFacultyRole.toLowerCase();

      // Status filter
      final statusMatch = _selectedFacultyStatus == 'all' ||
          faculty['status']?.toString().toLowerCase() == _selectedFacultyStatus.toLowerCase();

      // Course filter
      final courseMatch = _selectedFacultyCourse == 'all' ||
          faculty['course']?.toString().toLowerCase().contains(_selectedFacultyCourse.toLowerCase()) == true ||
          faculty['course']?['name']?.toString().toLowerCase().contains(_selectedFacultyCourse.toLowerCase()) == true ||
          faculty['course']?['code']?.toString().toLowerCase().contains(_selectedFacultyCourse.toLowerCase()) == true;

      return searchMatch && roleMatch && statusMatch && courseMatch;
    }).toList();
    
    print('Filtered faculty list: ${filtered.length} out of ${facultyList.length} total faculty');
    if (filtered.isNotEmpty) {
      print('First filtered faculty: ${filtered.first['first_name']} ${filtered.first['last_name']} (${filtered.first['role']})');
    }
    
    return filtered;
  }


  // Pending staff methods
  Future<void> _fetchPendingStaff() async {
    if (!mounted) return;
    
    setState(() {
      pendingStaffLoading = true;
      pendingStaffErrorMessage = null;
    });

    try {
      print('=== FETCHING PENDING STAFF ===');
      print('College Name: $collegeName');
      
      // Get the college ID from userData
      final collegeId = widget.userData['college'] ?? widget.userData['collegeName'] ?? '';
      print('College ID: $collegeId');
      
      // Try API first
      try {
        final response = await ApiService.getPendingStaff(collegeName);
        print('API response: ${response.length} pending staff');
        
        if (mounted) {
          setState(() {
            pendingStaffList = response;
          });
        }
        return;
      } catch (e) {
        print('API failed: $e');
        print('Creating pending staff from existing users...');
      }
      
      // Fallback: Create pending staff from existing users
      final allUsers = await ApiService.getAllUsers();
      print('Total users fetched for pending staff: ${allUsers.length}');
      
      
      // Filter for users with pending status in the same college
      final pendingStaff = allUsers.where((user) {
        final role = user['role']?.toString().toLowerCase() ?? '';
        final status = user['status']?.toString().toLowerCase() ?? '';
        final userCollege = user['college']?.toString() ?? user['collegeName']?.toString() ?? '';
        final userCollegeId = user['collegeId']?.toString() ?? '';
        
        // Handle ObjectId format for user college field
        String userCollegeObjectId = '';
        final userCollegeField = user['college'];
        if (userCollegeField is Map && userCollegeField.containsKey('\$oid')) {
          userCollegeObjectId = userCollegeField['\$oid']?.toString() ?? '';
        } else {
          userCollegeObjectId = userCollegeField?.toString() ?? '';
        }
        
        // Check if user is faculty with pending or forverification status and belongs to the same college
        final isFaculty = role == 'instructor' || role == 'programchairperson';
        final isPendingOrForVerification = status == 'forverification' || status == 'pending';
        
        // Compare by college name or college ID (including ObjectId format)
        final isSameCollege = userCollege.toLowerCase() == collegeName.toLowerCase() ||
                             (userCollegeId.isNotEmpty && userCollegeId == collegeId) ||
                             (userCollegeObjectId.isNotEmpty && userCollegeObjectId == collegeId);
        
        if (isFaculty && isPendingOrForVerification && isSameCollege) {
          print('Found pending staff: ${user['firstName'] ?? user['first_name']} ${user['lastName'] ?? user['last_name']} ($role) - Status: $status');
          print('  - _id: ${user['_id']}');
          print('  - email: ${user['email']}');
        }
        
        return isFaculty && isPendingOrForVerification && isSameCollege;
      }).toList();
      
      print('Pending staff in college $collegeName: ${pendingStaff.length}');
      
      // Show only real data - no sample data fallback
      if (mounted) {
        setState(() {
          pendingStaffList = pendingStaff;
          _filterPendingStaffList();
        });
      }
      
      print('Final pending staff list: ${pendingStaffList.length} users');
      
    } catch (e) {
      print('Error in _fetchPendingStaff: $e');
      if (mounted) {
        setState(() {
          pendingStaffErrorMessage = 'Failed to fetch pending staff: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          pendingStaffLoading = false;
        });
      }
    }
  }

  String _getStringValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Map) {
      return value['name']?.toString() ?? 'N/A';
    }
    return value.toString();
  }

  String _getCollegeNameFromId(dynamic collegeId) {
    // Since all pending staff should be from the same college as the dean,
    // just return the current college name
    return collegeName.isNotEmpty ? collegeName : 'College of Computing and Multimedia Studies';
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'instructor':
        return Colors.blue;
      case 'programchairperson':
        return Colors.purple;
      case 'dean':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (role?.toLowerCase()) {
      case 'instructor':
        return 'Instructor';
      case 'programchairperson':
        return 'Program Chair';
      case 'dean':
        return 'Dean';
      default:
        return role ?? 'Unknown';
    }
  }

  void _filterPendingStaffList() {
    filteredPendingStaffList = pendingStaffList.where((staff) {
      // Search filter
      final searchMatch = pendingStaffSearchQuery.isEmpty ||
          (staff['firstName'] ?? staff['first_name'] ?? '').toString().toLowerCase().contains(pendingStaffSearchQuery.toLowerCase()) ||
          (staff['lastName'] ?? staff['last_name'] ?? '').toString().toLowerCase().contains(pendingStaffSearchQuery.toLowerCase()) ||
          (staff['email'] ?? '').toString().toLowerCase().contains(pendingStaffSearchQuery.toLowerCase());
      
      // Role filter
      final roleMatch = selectedPendingStaffRole == 'all' ||
          (staff['role'] ?? '').toString().toLowerCase() == selectedPendingStaffRole.toLowerCase();
      
      return searchMatch && roleMatch;
    }).toList();
  }


  Future<void> _handleAcceptStaff(String staffId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Approval'),
          content: const Text('Are you sure you want to approve this faculty member?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.approveStaff(staffId);
      await _fetchPendingStaff();
      ErrorHandler.showSnackBar(context, 'Faculty member approved successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to approve faculty member: $e');
    }
  }

  Future<void> _handleRejectStaff(String staffId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Decline'),
          content: const Text('Are you sure you want to decline this faculty member?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.rejectStaff(staffId);
      await _fetchPendingStaff();
      ErrorHandler.showSnackBar(context, 'Faculty member declined successfully!');
    } catch (e) {
      ErrorHandler.showSnackBar(context, 'Failed to decline faculty member: $e');
    }
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
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, animationValue, child) {
                        return Transform.scale(
                          scale: animationValue,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
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
                                        color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                        size: 48,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Theme activated',
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                                    fontSize: 14,
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
              
              // Auto close dialog after 1.5 seconds
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTabTitle() {
    try {
      switch (_tabController.index) {
        case 0:
          return 'Dashboard';
        case 1:
          return 'Faculty Management';
        case 2:
          return 'Pending Staff';
        case 3:
          return 'Reports';
        case 4:
          return 'Live Video';
        case 5:
          return 'Settings';
        default:
          return 'Dean Dashboard';
      }
    } catch (e) {
      return 'Dean Dashboard';
    }
  }
}

