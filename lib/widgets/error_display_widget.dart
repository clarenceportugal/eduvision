import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/custom_colors.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isLoading;
  final String? title;
  final IconData? icon;

  const ErrorDisplayWidget({
    super.key,
    this.errorMessage,
    this.onRetry,
    this.isLoading = false,
    this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CustomColors.lightError.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: CustomColors.lightError.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.error_outline,
              color: CustomColors.lightError,
              size: 30,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Error title
          Text(
            title ?? 'Error Loading Data',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: CustomColors.lightError,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Error message
          Text(
            errorMessage!,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CustomColors.lightOnSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            
            // Retry button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onRetry,
                icon: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
                label: Text(
                  isLoading ? 'Retrying...' : 'Retry',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PartialErrorWidget extends StatelessWidget {
  final List<String> failedItems;
  final VoidCallback? onRetry;

  const PartialErrorWidget({
    super.key,
    required this.failedItems,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (failedItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomColors.lightWarning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CustomColors.lightWarning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: CustomColors.lightWarning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Some data failed to load: ${failedItems.join(', ')}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CustomColors.lightWarning,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CustomColors.lightWarning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
