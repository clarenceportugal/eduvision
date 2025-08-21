import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/custom_colors.dart';

class NetworkTestScreen extends StatefulWidget {
  const NetworkTestScreen({super.key});

  @override
  State<NetworkTestScreen> createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> {
  bool _isTesting = false;
  String _internetStatus = 'Not tested';
  String _localNetworkStatus = 'Not tested';
  String _serverStatus = 'Not tested';
  String _currentServerUrl = '';

  @override
  void initState() {
    super.initState();
    _currentServerUrl = AuthService.baseUrl;
  }

  Future<void> _testAllConnections() async {
    setState(() {
      _isTesting = true;
      _internetStatus = 'Testing...';
      _localNetworkStatus = 'Testing...';
      _serverStatus = 'Testing...';
    });

    // Test internet connectivity
    final internetResult = await AuthService.testInternetConnection();
    setState(() {
      _internetStatus = internetResult ? '✅ Connected' : '❌ Failed';
    });

    // Test local network
    final localNetworkResult = await AuthService.testLocalNetworkConnection();
    setState(() {
      _localNetworkStatus = localNetworkResult ? '✅ Connected' : '❌ Failed';
    });

    // Test server connection
    final serverResult = await AuthService.testServerConnection();
    setState(() {
      _serverStatus = serverResult ? '✅ Connected' : '❌ Failed';
    });

    setState(() {
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Network Test',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        backgroundColor: CustomColors.getSurfaceColor(context),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CustomColors.getOnSurfaceColor(context),
              ),
            ),
            const SizedBox(height: 20),

            // Server URL
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CustomColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CustomColors.getSecondaryColor(
                    context,
                  ).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Server URL:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CustomColors.getOnSurfaceColor(
                        context,
                      ).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentServerUrl,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CustomColors.getOnSurfaceColor(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Test Results
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CustomColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CustomColors.getSecondaryColor(
                    context,
                  ).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Results:',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CustomColors.getOnSurfaceColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildStatusRow('Internet Connection', _internetStatus),
                  const SizedBox(height: 12),
                  _buildStatusRow('Local Network', _localNetworkStatus),
                  const SizedBox(height: 12),
                  _buildStatusRow('Server Connection', _serverStatus),
                ],
              ),
            ),

            const Spacer(),

            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTesting ? null : _testAllConnections,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.getPrimaryColor(context),
                  foregroundColor: CustomColors.getOnPrimaryColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isTesting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                CustomColors.getOnPrimaryColor(context),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Testing...'),
                        ],
                      )
                    : Text(
                        'Test All Connections',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CustomColors.getSurfaceColor(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troubleshooting:',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CustomColors.getOnSurfaceColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Make sure your phone and computer are on the same WiFi\n'
                    '• Check if your server is running (node server.js)\n'
                    '• Update the IP address in server_config.dart\n'
                    '• Check Windows Firewall settings',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: CustomColors.getOnSurfaceColor(
                        context,
                      ).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CustomColors.getOnSurfaceColor(context),
            ),
          ),
        ),
        Text(
          status,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: status.contains('✅')
                ? CustomColors.getSuccessColor(context)
                : status.contains('❌')
                ? CustomColors.getErrorColor(context)
                : CustomColors.getOnSurfaceColor(context).withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
