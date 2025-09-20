import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/custom_colors.dart';

class LoadingStateManager extends StatefulWidget {
  final bool isLoading;
  final String? loadingMessage;
  final Widget child;
  final bool showSkeleton;
  final Widget? skeletonWidget;

  const LoadingStateManager({
    super.key,
    required this.isLoading,
    this.loadingMessage,
    required this.child,
    this.showSkeleton = false,
    this.skeletonWidget,
  });

  @override
  State<LoadingStateManager> createState() => _LoadingStateManagerState();
}

class _LoadingStateManagerState extends State<LoadingStateManager>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(LoadingStateManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isLoading)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: widget.showSkeleton
                    ? (widget.skeletonWidget ?? _buildDefaultSkeleton())
                    : _buildLoadingIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(CustomColors.primaryRed),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            widget.loadingMessage ?? 'Loading...',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CustomColors.lightOnSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSkeletonBox(height: 20, width: double.infinity),
          const SizedBox(height: 12),
          _buildSkeletonBox(height: 16, width: 200),
          const SizedBox(height: 8),
          _buildSkeletonBox(height: 16, width: 150),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double? height;
  final double? width;
  final EdgeInsets? padding;

  const SkeletonCard({
    super.key,
    this.height,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBox(height: 16, width: double.infinity),
          const SizedBox(height: 8),
          _buildSkeletonBox(height: 14, width: 120),
          const SizedBox(height: 12),
          _buildSkeletonBox(height: 12, width: 80),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets? padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SkeletonCard(height: itemHeight),
        );
      },
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final int crossAxisCount;
  final EdgeInsets? padding;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 120,
    this.crossAxisCount = 2,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SkeletonCard(height: itemHeight);
      },
    );
  }
}
