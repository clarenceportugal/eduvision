import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'face_registration_screen.dart';
import 'face_verification_screen.dart';
import 'face_data_debug_screen.dart';
import '../utils/custom_colors.dart';

class FaceRecognitionDemo extends StatelessWidget {
  const FaceRecognitionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomColors.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Face Recognition Demo',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        backgroundColor: CustomColors.getSurfaceColor(context),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CustomColors.getPrimaryColor(context).withOpacity(0.1),
                    CustomColors.getPrimaryColor(context).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.face_rounded,
                    size: 64,
                    color: CustomColors.getPrimaryColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Face Recognition System',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.getOnSurfaceColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register your face and verify your identity using advanced ML techniques',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: CustomColors.getOnSurfaceColor(
                        context,
                      ).withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Features
            Text(
              'Features',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CustomColors.getOnSurfaceColor(context),
              ),
            ),
            const SizedBox(height: 16),

            _buildFeatureCard(
              context,
              Icons.camera_alt_rounded,
              'Face Detection',
              'Real-time face detection using Google ML Kit',
              Colors.blue,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              Icons.face_retouching_natural_rounded,
              'Facial Landmarks',
              '68 facial landmarks for precise analysis',
              Colors.green,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              Icons.psychology_rounded,
              '512D Embeddings',
              'High-quality facial embeddings using TensorFlow Lite',
              Colors.purple,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              Icons.security_rounded,
              'Secure Verification',
              'SHA-256 protected embeddings with 60% threshold',
              Colors.orange,
            ),

            const Spacer(),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () => _navigateToRegistration(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(Icons.face_rounded, size: 20),
              label: Text(
                'Register Face',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => _navigateToVerification(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
              icon: Icon(Icons.face_retouching_natural_rounded, size: 20),
              label: Text(
                'Verify Face',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Debug Button
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceDataDebugScreen(),
                ),
              ),
              icon: Icon(Icons.bug_report, size: 20),
              label: Text(
                'Debug Face Data',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
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
                    fontWeight: FontWeight.bold,
                    color: CustomColors.getOnSurfaceColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
    );
  }

  void _navigateToRegistration(BuildContext context) {
    // Example user data - replace with your actual user data
    final userData = {
      'email': 'demo@example.com',
      'username': 'demo_user',
      'name': 'Demo User',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRegistrationScreen(userData: userData),
      ),
    );
  }

  void _navigateToVerification(BuildContext context) {
    // You can get this from your authentication system
    final userId = 'demo@example.com';

    // Show dialog to input user ID or get from auth
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String inputUserId = userId;

        return AlertDialog(
          title: Text(
            'Face Verification',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: CustomColors.getOnSurfaceColor(context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the user ID to verify:',
                style: GoogleFonts.inter(
                  color: CustomColors.getOnSurfaceColor(context),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: inputUserId),
                onChanged: (value) => inputUserId = value,
                decoration: InputDecoration(
                  labelText: 'User ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: CustomColors.getOnSurfaceColor(
                  context,
                ).withOpacity(0.7),
              ),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FaceVerificationScreen(userId: inputUserId),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomColors.getPrimaryColor(context),
                foregroundColor: CustomColors.getOnPrimaryColor(context),
              ),
              child: Text('Verify'),
            ),
          ],
        );
      },
    );
  }
}
