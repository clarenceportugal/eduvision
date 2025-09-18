import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorHandler {
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Error',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Success',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.green.shade700,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static String getErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    } else if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    } else {
      return 'An unexpected error occurred';
    }
  }

  static Widget buildErrorWidget(String message, {VoidCallback? onRetry}) {
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
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
