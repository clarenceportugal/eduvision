import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimelineChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final bool loading;

  const TimelineChart({
    super.key,
    required this.chartData,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : chartData.isEmpty
              ? Center(
                  child: Text(
                    'No data available',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : chartData.length > 100
                  ? Center(
                      child: Text(
                        'Too much data to display (${chartData.length} items)',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : _buildTimelineVisualization(context),
    );
  }

  Widget _buildTimelineVisualization(BuildContext context) {
    // Create time slots from 7 AM to 6 PM (11 hours) - matching React version
    final timeSlots = List.generate(11, (index) => 7 + index);
    
    // Memoize the expensive data processing
    final processedData = _processChartData();
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Time axis
          SizedBox(
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
          SizedBox(
            height: 120,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                
                return Stack(
                  children: processedData.map((data) {
                    final startTime = (data['startTime'] ?? data['Start']) as DateTime;
                    final endTime = (data['endTime'] ?? data['End']) as DateTime;
                    
                    // Calculate position and width based on time (7 AM to 6 PM = 11 hours = 660 minutes)
                    final startHour = startTime.hour;
                    final startMinute = startTime.minute;
                    final endHour = endTime.hour;
                    final endMinute = endTime.minute;
                    
                    // Convert to minutes from 7 AM
                    final startMinutes = (startHour - 7) * 60 + startMinute;
                    final endMinutes = (endHour - 7) * 60 + endMinute;
                    
                    // Calculate position and width (660 minutes = 11 hours)
                    final leftPercent = (startMinutes / 660);
                    final widthPercent = ((endMinutes - startMinutes) / 660);
                    
                    // Ensure valid positioning
                    if (leftPercent < 0 || widthPercent <= 0 || leftPercent + widthPercent > 1) {
                      return const SizedBox.shrink(); // Skip invalid positioning
                    }
                    
                    final left = leftPercent * availableWidth;
                    final width = widthPercent * availableWidth;
                    
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
                                data['subject'] ?? data['Subject'] ?? 'Unknown',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                data['instructor'] ?? data['Instructor'] ?? 'Unknown',
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _processChartData() {
    // Filter out invalid data early to improve performance
    return chartData.where((data) {
      final startTimeValue = data['startTime'] ?? data['Start'];
      final endTimeValue = data['endTime'] ?? data['End'];
      return startTimeValue != null && endTimeValue != null;
    }).take(50).toList(); // Limit to 50 items to prevent performance issues
  }
}