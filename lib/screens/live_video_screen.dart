import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'program_chair_main.dart';

class LiveVideoScreen extends StatefulWidget {
  const LiveVideoScreen({super.key});

  @override
  State<LiveVideoScreen> createState() => _LiveVideoScreenState();
}

class _LiveVideoScreenState extends State<LiveVideoScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<dynamic> labs = [];
  String selectedLab = "Lab 1";
  List<dynamic> schedules = [];
  int? currentMinutesSinceStart;
  List<dynamic> logs = [];

  final List<String> timeLabels = [
    "6 AM", "7 AM", "8 AM", "9 AM", "10 AM", "11 AM", "12 PM",
    "1 PM", "2 PM", "3 PM", "4 PM", "5 PM", "6 PM", "7 PM"
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
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

  Future<void> _initializeData() async {
    await _fetchLabs();
    await _fetchSchedules();
    await _fetchLogs();
    _startTimeUpdate();
  }

  Future<void> _fetchLabs() async {
    // Mock data for labs
    setState(() {
      labs = [
        {'_id': '1', 'name': 'Lab 1'},
        {'_id': '2', 'name': 'Lab 2'},
        {'_id': '3', 'name': 'Lab 3'},
      ];
    });
  }

  Future<void> _fetchSchedules() async {
    // Mock data for schedules
    setState(() {
      schedules = [];
    });
  }

  Future<void> _fetchLogs() async {
    // Mock data for logs
    setState(() {
      logs = [];
    });
  }

  void _startTimeUpdate() {
    _updatePointer();
    
    // Update every minute
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _startTimeUpdate();
      }
    });
  }

  void _updatePointer() {
    final now = DateTime.now();
    final startOfTimeline = DateTime(now.year, now.month, now.day, 6, 0);
    final diffInMinutes = now.difference(startOfTimeline).inMinutes;
    
    if (diffInMinutes >= 0 && diffInMinutes <= 780) {
      setState(() {
        currentMinutesSinceStart = diffInMinutes;
      });
    } else {
      setState(() {
        currentMinutesSinceStart = null;
      });
    }
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
                _buildVideoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Live Face Recognition Feed',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: selectedLab,
            decoration: InputDecoration(
              labelText: 'Select Lab',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: labs.map<DropdownMenuItem<String>>((lab) {
              return DropdownMenuItem<String>(
                value: lab['name'],
                child: Text(lab['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedLab = value ?? "Lab 1";
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Expanded(
      child: Row(
        children: [
          // Video Stream (2/3)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off_rounded,
                          size: 64,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Video Stream Not Available',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'WebRTC connection required',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Scrollable Timeline (1/3)
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  // Timeline Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Schedule Timeline',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Timeline Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Current time indicator
                            if (currentMinutesSinceStart != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 2,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Current Time',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Timeline
                            _buildTimeline(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: timeLabels.map((label) {
        
        return Column(
          children: [
            // Main time label
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            // Time ticks
            ...List.generate(12, (tickIndex) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 60), // Space for time label
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.grey[300],
                      ),
                    ),
                    if (tickIndex < 11) // Don't show mini ticks for the last tick
                      ...List.generate(4, (miniIndex) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              const SizedBox(width: 60),
                              Container(
                                width: 20,
                                height: 1,
                                color: Colors.grey[200],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            }),
            // Log entries for this time period
            ..._buildLogEntriesForTime(label),
          ],
        );
      }).toList(),
    );
  }

  List<Widget> _buildLogEntriesForTime(String timeLabel) {
    return logs.where((log) {
      final time = log['timeIn'] ?? log['timeout'];
      if (time == null) return false;
      
      final hour = int.parse(time.split(':')[0]);
      final isAM = hour < 12;
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final ampm = isAM ? 'AM' : 'PM';
      final logTime = '$hour12 $ampm';
      
      return logTime == timeLabel;
    }).map((log) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE5383B),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          log['status'] ?? 'Unknown',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }).toList();
  }
}
