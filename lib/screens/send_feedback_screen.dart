import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/custom_colors.dart';

class SendFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SendFeedbackScreen({super.key, required this.userData});

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedCategory = 'General';
  int _rating = 5;
  bool _includeSystemInfo = true;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General',
    'Bug Report',
    'Feature Request',
    'Face Recognition',
    'Performance',
    'Privacy Concern',
    'User Interface',
    'Account Issues',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill email if available
    _emailController.text = widget.userData['email'] ?? '';
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Send Feedback',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: CustomColors.getOnSurfaceColor(context),
          ),
        ),
        backgroundColor: CustomColors.getSurfaceColor(context),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitFeedback,
            style: TextButton.styleFrom(
              foregroundColor: CustomColors.getPrimaryColor(context),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CustomColors.getOnPrimaryColor(context),
                      ),
                    ),
                  )
                : Text(
                    'Send',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeMessage(),
              SizedBox(height: 24),

              _buildSectionHeader('Category'),
              SizedBox(height: 12),
              _buildCategorySelector(),
              SizedBox(height: 24),

              _buildSectionHeader('Rating'),
              SizedBox(height: 12),
              _buildRatingSelector(),
              SizedBox(height: 24),

              _buildSectionHeader('Your Feedback'),
              SizedBox(height: 12),
              _buildFeedbackField(),
              SizedBox(height: 24),

              _buildSectionHeader('Contact Information'),
              SizedBox(height: 12),
              _buildEmailField(),
              SizedBox(height: 24),

              _buildAdditionalOptions(),
              SizedBox(height: 32),

              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.feedback_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'We Value Your Feedback',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Help us improve EduVision by sharing your thoughts, reporting bugs, or suggesting new features. Your feedback helps us create a better experience for everyone.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: CustomColors.getOnSurfaceColor(context),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: CustomColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CustomColors.getSecondaryColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCategory,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Row(
              children: [
                Icon(_getCategoryIcon(category), size: 20),
                SizedBox(width: 12),
                Text(category),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedCategory = value);
          }
        },
      ),
    );
  }

  Widget _buildRatingSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CustomColors.getSecondaryColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How would you rate your overall experience?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CustomColors.getOnSurfaceColor(context),
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final star = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          SizedBox(height: 8),
          Text(
            _getRatingText(_rating),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CustomColors.getOnSurfaceColor(
                context,
              ).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackField() {
    return TextFormField(
      controller: _feedbackController,
      maxLines: 6,
      decoration: InputDecoration(
        hintText: _getFeedbackPlaceholder(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your feedback';
        }
        if (value.trim().length < 10) {
          return 'Please provide more detailed feedback (at least 10 characters)';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: 'your.email@example.com',
        prefixIcon: Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        helperText: 'We\'ll use this to follow up if needed',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email address';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Additional Options'),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                title: Text(
                  'Include system information',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                subtitle: Text(
                  'Helps us diagnose technical issues',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: _includeSystemInfo,
                onChanged: (value) =>
                    setState(() => _includeSystemInfo = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitFeedback,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Sending...'),
                ],
              )
            : Text(
                'Send Feedback',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Bug Report':
        return Icons.bug_report_outlined;
      case 'Feature Request':
        return Icons.lightbulb_outline;
      case 'Face Recognition':
        return Icons.face_rounded;
      case 'Performance':
        return Icons.speed_outlined;
      case 'Privacy Concern':
        return Icons.security_outlined;
      case 'User Interface':
        return Icons.design_services_outlined;
      case 'Account Issues':
        return Icons.account_circle_outlined;
      default:
        return Icons.feedback_outlined;
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Very Poor - Major issues';
      case 2:
        return 'Poor - Several problems';
      case 3:
        return 'Average - Some improvements needed';
      case 4:
        return 'Good - Minor issues';
      case 5:
        return 'Excellent - Very satisfied';
      default:
        return '';
    }
  }

  String _getFeedbackPlaceholder() {
    switch (_selectedCategory) {
      case 'Bug Report':
        return 'Please describe the bug you encountered:\n\n• What were you trying to do?\n• What happened instead?\n• How can we reproduce this issue?';
      case 'Feature Request':
        return 'Tell us about the feature you\'d like to see:\n\n• What would this feature do?\n• How would it help you?\n• Any specific requirements?';
      case 'Face Recognition':
        return 'Share your experience with face registration:\n\n• What issues did you encounter?\n• How was the accuracy?\n• Any suggestions for improvement?';
      case 'Performance':
        return 'Describe any performance issues:\n\n• What actions feel slow?\n• When do you notice the issues?\n• Device information (if relevant)';
      default:
        return 'Share your thoughts, suggestions, or concerns about EduVision. We appreciate detailed feedback that helps us understand your experience better.';
    }
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 2));

      // In a real app, you would send the feedback to your backend
      final feedbackData = {
        'category': _selectedCategory,
        'rating': _rating,
        'feedback': _feedbackController.text.trim(),
        'email': _emailController.text.trim(),
        'includeSystemInfo': _includeSystemInfo,
        'userId': widget.userData['_id'],
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'platform': 'Flutter',
      };

      // 

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thank you for your feedback! We\'ll review it carefully.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back after showing success message
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send feedback. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
