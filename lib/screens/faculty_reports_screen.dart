import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'program_chair_main.dart';

class FacultyReportsScreen extends StatefulWidget {
  const FacultyReportsScreen({super.key});

  @override
  State<FacultyReportsScreen> createState() => _FacultyReportsScreenState();
}

class _FacultyReportsScreenState extends State<FacultyReportsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String courseName = '';

  // Pagination
  int page = 0;
  int rowsPerPage = 10;

  final List<Map<String, String>> columns = [
    {'id': 'name', 'label': 'Instructor Name'},
    {'id': 'courseCode', 'label': 'Course Code'},
    {'id': 'courseTitle', 'label': 'Course Title'},
    {'id': 'status', 'label': 'Status'},
    {'id': 'timeInOut', 'label': 'Time In & Out'},
    {'id': 'room', 'label': 'Room'},
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _fetchData();
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
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() => loading = true);
    try {
      print("Fetching daily report for CourseName: $courseName");

      final response = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/show-daily-report'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'CourseName': courseName}),
      ).timeout(const Duration(seconds: 15));

      print("Daily Report API Response Status: ${response.statusCode}");
      print("Daily Report API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print("Attendance data: ${data['data']}");
          setState(() {
            rows = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
          print("Successfully loaded ${rows.length} attendance records");
        } else {
          print("API returned success = false: $data");
          _showErrorDialog('Error', 'Failed to load daily report data.');
        }
      } else {
        print("Failed to fetch daily report: ${response.statusCode}");
        _showErrorDialog('Error', 'Failed to load daily report. Please try again.');
      }
    } catch (error) {
      print("Failed to fetch attendance data: $error");
      _showErrorDialog('Error', 'Failed to load daily report: $error');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _handleGenerateReport() async {
    try {
      _showLoadingDialog('Generating Report', 'Please wait while we generate your report...');

      print('Generating report for course: $courseName');

      final response = await http.post(
        Uri.parse('https://eduvision-dura.onrender.com/api/auth/generate-monthly-report'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/octet-stream',
        },
        body: jsonEncode({'CourseName': courseName}),
      ).timeout(const Duration(seconds: 30));

      print('Generate Report API Response Status: ${response.statusCode}');
      print('Generate Report API Response Headers: ${response.headers}');

      Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200) {
        // Save file to downloads
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/DailyAttendanceReport_${DateTime.now().millisecondsSinceEpoch}.docx');
        await file.writeAsBytes(response.bodyBytes);
        
        print('Report saved to: ${file.path}');
        
        _showSuccessDialog(
          'Report Generated',
          'Daily attendance report has been downloaded successfully!\nSaved to: ${file.path}',
        );
      } else {
        print('Failed to generate report: ${response.statusCode}');
        _showErrorDialog('Error', 'Failed to generate report. Please try again.');
      }
    } catch (error) {
      Navigator.of(context).pop(); // Close loading dialog
      print('Error generating report: $error');
      _showErrorDialog('Error', 'Failed to generate report: $error');
    }
  }

  List<Map<String, dynamic>> get paginatedRows {
    final start = page * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, rows.length);
    return rows.sublist(start, end);
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
                _buildReportTable(),
                const SizedBox(height: 24),
                _buildGenerateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Faculty Daily Report',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Displays the attendance summary of faculty members for the current day.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReportTable() {
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
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: columns.map((column) {
                  return Expanded(
                    child: Text(
                      column['label']!,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Table Body
            Expanded(
              child: loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading attendance data...'),
                        ],
                      ),
                    )
                  : rows.isEmpty
                      ? const Center(
                          child: Text('No attendance records available for today.'),
                        )
                      : ListView.builder(
                          itemCount: paginatedRows.length,
                          itemBuilder: (context, index) {
                            final row = paginatedRows[index];
                            return _buildTableRow(row, index);
                          },
                        ),
            ),
            // Pagination
            if (rows.isNotEmpty)
              _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> row, int index) {
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
        children: columns.map((column) {
          final value = row[column['id']] ?? '';
          return Expanded(
            child: Text(
              value.toString(),
              style: GoogleFonts.inter(fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (rows.length / rowsPerPage).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page * rowsPerPage + 1} to ${(page + 1) * rowsPerPage.clamp(0, rows.length)} of ${rows.length} entries',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          Row(
            children: [
              DropdownButton<int>(
                value: rowsPerPage,
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                ],
                onChanged: (value) {
                  setState(() {
                    rowsPerPage = value ?? 10;
                    page = 0;
                  });
                },
              ),
              const SizedBox(width: 16),
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

  Widget _buildGenerateButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: _handleGenerateReport,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Generate & Download Report'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
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

  Future<void> _showLoadingDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }
}
