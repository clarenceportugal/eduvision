import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard_components.dart';
import '../utils/api_test.dart';

class ProgramChairDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProgramChairDashboardScreen({super.key, required this.userData});

  @override
  State<ProgramChairDashboardScreen> createState() => _ProgramChairDashboardScreenState();
}

class _ProgramChairDashboardScreenState extends State<ProgramChairDashboardScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  int? instructorCount;
  int? schedulesCountToday;
  List<dynamic> allFacultiesLogs = [];
  List<Schedule> schedules = [];
  bool loading = false;
  bool isRefreshing = false;
  String? errorMessage;

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
          courseName = prefs.getString('course') ?? '';
        });
        
        // Test all API connections after loading user data
        if (courseName.isNotEmpty) {
          _testApiConnections();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load user data: $e';
        });
      }
    }
  }

  Future<void> _testApiConnections() async {
    print('Testing all API connections for course: $courseName');
    final results = await ApiTest.testAllConnections(courseName);
    ApiTest.printTestResults(results);
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
        _fetchInstructorCount(),
        _fetchSchedulesCountToday(),
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
      final shortCourseName = courseName.replaceAll(RegExp(r'^bs', caseSensitive: false), '').toUpperCase();
      print('Fetching schedules for course: $shortCourseName');
      
      final response = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/all-schedules/today'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'shortCourseName': shortCourseName}),
      ).timeout(const Duration(seconds: 15));

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
        throw Exception('Failed to load schedules: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      print('Error fetching schedules: $error');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load schedules: $error';
        });
      }
    }
  }

  Future<void> _fetchInstructorCount() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      print('Fetching instructor count for course: $courseName');
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/count/instructors?course=$courseName'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('Instructor Count API Response Status: ${response.statusCode}');
      print('Instructor Count API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            instructorCount = data['count'] ?? 0;
          });
          print('Successfully loaded instructor count: $instructorCount');
        }
      } else {
        print('Failed to fetch instructor count: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching instructor count: $error');
    }
  }

  Future<void> _fetchSchedulesCountToday() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      print('Fetching schedules count for course: $courseName');
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/schedules-count/today?course=$courseName'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('Schedules Count API Response Status: ${response.statusCode}');
      print('Schedules Count API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            schedulesCountToday = data['count'] ?? 0;
          });
          print('Successfully loaded schedules count: $schedulesCountToday');
        }
      } else {
        print('Failed to fetch schedules count: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching schedules count: $error');
    }
  }

  Future<void> _fetchAllFacultiesLogs() async {
    if (!mounted || courseName.isEmpty) return;
    
    try {
      print('Fetching faculty logs for course: $courseName');
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/logs/all-faculties/today?courseName=$courseName'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('Faculty Logs API Response Status: ${response.statusCode}');
      print('Faculty Logs API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            allFacultiesLogs = jsonDecode(response.body) ?? [];
          });
          print('Successfully loaded ${allFacultiesLogs.length} faculty logs');
        }
      } else {
        print('Failed to fetch faculty logs: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching faculty logs: $error');
    }
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
      title: '${courseName.isNotEmpty ? courseName.toUpperCase() : "Loading..."} Program Chairperson Dashboard',
      subtitle: 'Dashboard',
      icon: Icons.admin_panel_settings_rounded,
      displayName: widget.userData['displayName'] ?? 'Program Chair',
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
                '${courseName.isNotEmpty ? courseName.toUpperCase() : "Loading..."} Program Chairperson Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _testApiConnections,
              icon: const Icon(Icons.wifi_find_rounded, size: 16),
              label: const Text('Test Connections'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Displaying today\'s faculty information for the ${courseName.isNotEmpty ? courseName.toUpperCase() : "Loading..."} program.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              'Instructor Absents Today',
              '0',
              Icons.highlight_off_rounded,
              const Color(0xFF38bdf8),
              const Color(0xFFe0f2fe),
            ),
            _buildStatCard(
              'Classes Today',
              schedulesCountToday?.toString() ?? 'Loading...',
              Icons.event_available_rounded,
              const Color(0xFFfb923c),
              const Color(0xFFffedd5),
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
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
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
          Text(
            'Today Schedule Chart',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : chartData.isEmpty
                    ? Center(
                        child: Text(
                          'No schedule data available.',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : _buildTimelineVisualization(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineVisualization() {
    // Create time slots from 7 AM to 6 PM (11 hours) - matching React version
    final timeSlots = List.generate(11, (index) => 7 + index);
    
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
                
                // Calculate position and width based on time (7 AM to 6 PM = 11 hours = 660 minutes)
                final startHour = startTime.hour;
                final startMinute = startTime.minute;
                final endHour = endTime.hour;
                final endMinute = endTime.minute;
                
                // Convert to minutes from 7 AM
                final startMinutes = (startHour - 7) * 60 + startMinute;
                final endMinutes = (endHour - 7) * 60 + endMinute;
                
                // Calculate position and width (660 minutes = 11 hours)
                final left = (startMinutes / 660) * 100;
                final width = ((endMinutes - startMinutes) / 660) * 100;
                
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
                    '${schedule.section.course} - ${schedule.section.section}${schedule.section.block}',
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
          DataCell(Text('${schedule.section.course} - ${schedule.section.section}${schedule.section.block}')),
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
  final String course;
  final String section;
  final String block;
  final String sectionName;

  Section({
    required this.course,
    required this.section,
    required this.block,
    required this.sectionName,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      course: json['course'] ?? '',
      section: json['section'] ?? '',
      block: json['block'] ?? '',
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
