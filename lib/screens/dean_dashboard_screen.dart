import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard_components.dart';

class DeanDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DeanDashboardScreen({super.key, required this.userData});

  @override
  State<DeanDashboardScreen> createState() => _DeanDashboardScreenState();
}

class _DeanDashboardScreenState extends State<DeanDashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
      // Check if courseName is available, if not use a default value
      if (courseName.isEmpty) {
        print('Warning: courseName is empty, using default value');
        courseName = 'ALL';
      }
      
      final shortCourseValue = courseName.replaceAll(RegExp(r'^bs', caseSensitive: false), '').toUpperCase();
      print('Fetching schedules with course: $shortCourseValue');
      
      final response = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/dean/all-schedules/today'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'shortCourseValue': shortCourseValue}),
      ).timeout(const Duration(seconds: 10));

      print('Schedules API Response Status: ${response.statusCode}');
      print('Schedules API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            schedules = data.map((item) => Schedule.fromJson(item)).toList();
            _generateChartData();
          });
          print('Successfully loaded ${schedules.length} schedules');
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load schedules: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching schedules: $error');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load schedules';
        });
      }
    }
  }

  void _generateChartData() {
    final today = DateTime.now();
    final year = today.year;
    final month = today.month;
    final date = today.day;

    final formattedData = <Map<String, dynamic>>[];

    // Filter schedules based on course and room selection (like in React version)
    final filteredSchedules = schedules.where((schedule) {
      final courseMatch = courseValue == "all" || schedule.courseCode.toLowerCase() == courseValue.toLowerCase();
      final roomMatch = roomValue == "all" || schedule.room.toLowerCase() == roomValue.toLowerCase();
      return courseMatch && roomMatch;
    }).toList();

    for (final schedule in filteredSchedules) {
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

  Future<void> _fetchCourses() async {
    if (!mounted) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/all-courses/college?CollegeName=$collegeName'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            courses = jsonDecode(response.body);
          });
        }
      }
    } catch (error) {
      print('Error fetching courses: $error');
    }
  }

  Future<void> _fetchRooms() async {
    if (!mounted) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/all-rooms/college?CollegeName=$collegeName'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            rooms = jsonDecode(response.body);
          });
        }
      }
    } catch (error) {
      print('Error fetching rooms: $error');
    }
  }

  Future<void> _fetchInstructorCount() async {
    if (!mounted) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/count-all/instructors?CollegeName=$collegeName'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            instructorCount = data['instructorCount'];
            programChairCount = data['programChairCount'];
          });
        }
      }
    } catch (error) {
      print('Error fetching instructor count: $error');
    }
  }

  Future<void> _fetchAllFacultiesLogs() async {
    if (!mounted) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/logs/all-faculties/today?courseName=$courseName'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            allFacultiesLogs = jsonDecode(response.body);
          });
        }
      }
    } catch (error) {
      print('Error fetching faculty logs: $error');
    }
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            if (errorMessage != null)
              SliverToBoxAdapter(
                child: _buildErrorWidget(),
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
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade600,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'An unknown error occurred',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return DashboardComponents.buildSliverAppBar(
      context: context,
      title: '${collegeName.isNotEmpty ? collegeName : "Loading..."} Dean Dashboard',
      subtitle: 'Dashboard',
      icon: Icons.admin_panel_settings_rounded,
      displayName: widget.userData['displayName'] ?? 'Dean',
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${collegeName.isNotEmpty ? collegeName : "Loading..."} Dean Dashboard',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              TextSpan(
                text: ' / ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              TextSpan(
                text: 'Attendance',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
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
            _buildStatCard(
              'Total Faculties',
              instructorCount?.toString() ?? 'Loading...',
              Icons.people_rounded,
              const Color(0xFF9f7aea),
              const Color(0xFFf3e8ff),
            ),
            _buildStatCard(
              'Total Program Chairperson',
              programChairCount?.toString() ?? 'Loading...',
              Icons.people_rounded,
              const Color(0xFF9f7aea),
              const Color(0xFFf3e8ff),
            ),
            _buildStatCard(
              'Instructor Absents Today',
              '0',
              Icons.highlight_off_rounded,
              const Color(0xFF38bdf8),
              const Color(0xFFe0f2fe),
            ),
            _buildStatCard(
              'Late Instructors',
              '0',
              Icons.warning_amber_rounded,
              const Color(0xFFec4899),
              const Color(0xFFfce7f3),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.more_horiz_rounded,
            color: Colors.grey,
            size: 20,
          ),
        ],
      ),
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
              final isMobile = constraints.maxWidth < 600;
              return isMobile
                  ? Column(
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
                        _buildDropdown('Course', courseValue, courses, (value) {
                          setState(() => courseValue = value);
                          _generateChartData();
                        }),
                        const SizedBox(height: 12),
                        _buildDropdown('Room', roomValue, rooms, (value) {
                          setState(() => roomValue = value);
                          _generateChartData();
                        }),
                      ],
                    )
                  : Row(
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
                        Row(
                          children: [
                            _buildDropdown('Course', courseValue, courses, (value) {
                              setState(() => courseValue = value);
                              _generateChartData();
                            }),
                            const SizedBox(width: 16),
                            _buildDropdown('Room', roomValue, rooms, (value) {
                              setState(() => roomValue = value);
                              _generateChartData();
                            }),
                          ],
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : schedules.isEmpty
                    ? Center(
                        child: Text(
                          'No data available. Please select an option from the dropdown.',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : _buildTimelineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<dynamic> items, Function(String) onChanged) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Container(
          width: isMobile ? double.infinity : 200,
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All')),
              ...items.map((item) => DropdownMenuItem(
                value: item['code'] ?? item['name'],
                child: Text((item['code'] ?? item['name']).toString().toUpperCase()),
              )),
            ],
            onChanged: (value) => onChanged(value ?? 'all'),
          ),
        );
      },
    );
  }

  Widget _buildTimelineChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Schedule Timeline (6 AM - 6 PM)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildTimelineVisualization(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineVisualization() {
    if (chartData.isEmpty) {
      return Center(
        child: Text(
          'No schedule data available',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Create time slots from 6 AM to 6 PM (12 hours)
    final timeSlots = List.generate(12, (index) => 6 + index);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Time axis
          Container(
            height: 30,
            child: Row(
              children: timeSlots.map((hour) {
                final isAM = hour < 12;
                final displayHour = hour == 12 ? 12 : hour % 12;
                final ampm = isAM ? 'AM' : 'PM';
                
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$displayHour $ampm',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Timeline bars
          Container(
            height: 120,
            child: Stack(
              children: chartData.map((data) {
                final startTime = data['startTime'] as DateTime;
                final endTime = data['endTime'] as DateTime;
                
                // Calculate position and width based on time
                final startHour = startTime.hour;
                final startMinute = startTime.minute;
                final endHour = endTime.hour;
                final endMinute = endTime.minute;
                
                // Convert to minutes from 6 AM
                final startMinutes = (startHour - 6) * 60 + startMinute;
                final endMinutes = (endHour - 6) * 60 + endMinute;
                
                // Calculate position and width (720 minutes = 12 hours)
                final left = (startMinutes / 720) * 100;
                final width = ((endMinutes - startMinutes) / 720) * 100;
                
                return Positioned(
                  left: left,
                  width: width,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            data['subject'],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            data['instructor'],
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                return _buildMobileScheduleList();
              } else {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('S. No', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Instructor', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('End Time', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Room', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Section', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Course', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _buildDataTableRows(),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScheduleList() {
    if (schedules.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No schedules found.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: index % 2 == 0
                ? Colors.transparent
                : Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${schedule.startTime} - ${schedule.endTime}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${schedule.courseTitle} (${schedule.courseCode})',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    schedule.room,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.group_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    schedule.section.sectionName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<DataRow> _buildDataTableRows() {
    if (schedules.isEmpty) {
      return [
        const DataRow(
          cells: [
            DataCell(Text('No schedules found.')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
          ],
        ),
      ];
    }

    return schedules.asMap().entries.map((entry) {
      final index = entry.key;
      final schedule = entry.value;
      return DataRow(
        color: MaterialStateProperty.all(
          index % 2 == 0
              ? Colors.transparent
              : Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        ),
        cells: [
          DataCell(Text('${index + 1}')),
          DataCell(Text(
            '${schedule.instructor.firstName} ${schedule.instructor.lastName}',
          )),
          DataCell(Text(schedule.startTime)),
          DataCell(Text(schedule.endTime)),
          DataCell(Text(schedule.room)),
          DataCell(Text(schedule.section.sectionName)),
          DataCell(Text('${schedule.courseTitle} (${schedule.courseCode})')),
        ],
      );
    }).toList();
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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

// Data models
class Schedule {
  final String courseTitle;
  final String courseCode;
  final Instructor instructor;
  final String room;
  final String startTime;
  final String endTime;
  final String semesterStartDate;
  final String semesterEndDate;
  final Section section;
  final Days days;

  Schedule({
    required this.courseTitle,
    required this.courseCode,
    required this.instructor,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.semesterStartDate,
    required this.semesterEndDate,
    required this.section,
    required this.days,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      courseTitle: json['courseTitle'] ?? '',
      courseCode: json['courseCode'] ?? '',
      instructor: Instructor.fromJson(json['instructor'] ?? {}),
      room: json['room'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      semesterStartDate: json['semesterStartDate'] ?? '',
      semesterEndDate: json['semesterEndDate'] ?? '',
      section: Section.fromJson(json['section'] ?? {}),
      days: Days.fromJson(json['days'] ?? {}),
    );
  }
}

class Instructor {
  final String firstName;
  final String lastName;

  Instructor({required this.firstName, required this.lastName});

  factory Instructor.fromJson(Map<String, dynamic> json) {
    return Instructor(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }
}

class Section {
  final String sectionName;

  Section({required this.sectionName});

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      sectionName: json['sectionName'] ?? '',
    );
  }
}

class Days {
  final bool mon;
  final bool tue;
  final bool wed;
  final bool thu;
  final bool fri;
  final bool sat;
  final bool sun;

  Days({
    required this.mon,
    required this.tue,
    required this.wed,
    required this.thu,
    required this.fri,
    required this.sat,
    required this.sun,
  });

  factory Days.fromJson(Map<String, dynamic> json) {
    return Days(
      mon: json['mon'] ?? false,
      tue: json['tue'] ?? false,
      wed: json['wed'] ?? false,
      thu: json['thu'] ?? false,
      fri: json['fri'] ?? false,
      sat: json['sat'] ?? false,
      sun: json['sun'] ?? false,
    );
  }
}