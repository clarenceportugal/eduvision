import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/custom_colors.dart';

class DataManagementScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DataManagementScreen({super.key, required this.userData});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  Map<String, dynamic> _registrationData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrationData();
  }

  Future<void> _loadRegistrationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userData['_id']?.toString() ?? 'unknown';
      final dataString = prefs.getString('face_registration_$userId');

      if (dataString != null) {
        final data = jsonDecode(dataString);
        setState(() {
          _registrationData = Map<String, dynamic>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading registration data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Data',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        content: Text(
          'Are you sure you want to clear all face registration data? This action cannot be undone.',
          style: GoogleFonts.inter(
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: CustomColors.getOnSurfaceColor(
                context,
              ).withOpacity(0.7),
            ),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: CustomColors.getErrorColor(context),
            ),
            child: Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = widget.userData['_id']?.toString() ?? 'unknown';
        await prefs.remove('face_registration_$userId');

        setState(() {
          _registrationData = {};
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All face registration data cleared successfully'),
            backgroundColor: CustomColors.getSuccessColor(context),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: CustomColors.getErrorColor(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Data Management',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        backgroundColor: CustomColors.getSurfaceColor(context),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Face Registration Data Section
                  _buildSectionHeader('Face Registration Data'),
                  SizedBox(height: 16),

                  if (_registrationData.isEmpty)
                    _buildEmptyState()
                  else
                    _buildDataOverview(),

                  SizedBox(height: 32),

                  // Actions Section
                  _buildSectionHeader('Actions'),
                  SizedBox(height: 16),

                  _buildActionButton(
                    'Clear All Data',
                    'Remove all stored face registration data',
                    Icons.delete_outline,
                    CustomColors.getErrorColor(context),
                    _clearAllData,
                  ),

                  SizedBox(height: 16),

                  _buildActionButton(
                    'Refresh Data',
                    'Reload data from storage',
                    Icons.refresh,
                    CustomColors.getPrimaryColor(context),
                    _loadRegistrationData,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: CustomColors.getOnSurfaceColor(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: CustomColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CustomColors.getSecondaryColor(context).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.face_rounded,
            size: 64,
            color: CustomColors.getOnSurfaceColor(
              context,
            ).withValues(alpha: 0.3),
          ),
          SizedBox(height: 16),
          Text(
            'No Face Registration Data',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Complete face registration to see your data here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataOverview() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registration Summary',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 16),

          // Steps completed
          _buildDataRow(
            'Steps Completed',
            '${_registrationData.length}',
            Icons.check_circle_outline,
          ),

          SizedBox(height: 12),

          // Show individual steps
          if (_registrationData.isNotEmpty) ...[
            Divider(),
            SizedBox(height: 12),
            Text(
              'Captured Steps',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            SizedBox(height: 8),

            ..._registrationData.entries.map((entry) {
              final stepData = entry.value;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_camera,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stepData['step_name'] ??
                            'Step ${stepData['step_number']}',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${(stepData['file_size'] ?? 0) ~/ 1024}KB',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
