import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/custom_colors.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final Function(int) onPageChanged;
  final bool isLoading;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Items info
          Text(
            'Showing ${_getStartItem()} to ${_getEndItem()} of $totalItems items',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CustomColors.lightOnSurface.withOpacity(0.7),
            ),
          ),
          
          // Pagination controls
          Row(
            children: [
              // Previous button
              _buildPageButton(
                icon: Icons.chevron_left,
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                isEnabled: currentPage > 1 && !isLoading,
              ),
              
              const SizedBox(width: 8),
              
              // Page numbers
              ..._buildPageNumbers(),
              
              const SizedBox(width: 8),
              
              // Next button
              _buildPageButton(
                icon: Icons.chevron_right,
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                isEnabled: currentPage < totalPages && !isLoading,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isEnabled ? CustomColors.primaryRed : Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 16,
          color: isEnabled ? Colors.white : Colors.grey[600],
        ),
        onPressed: isEnabled ? onPressed : null,
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final List<Widget> pageNumbers = [];
    const int maxVisiblePages = 5;
    
    int startPage = (currentPage - (maxVisiblePages ~/ 2)).clamp(1, totalPages);
    int endPage = (startPage + maxVisiblePages - 1).clamp(1, totalPages);
    
    // Adjust start if we're near the end
    if (endPage - startPage < maxVisiblePages - 1) {
      startPage = (endPage - maxVisiblePages + 1).clamp(1, totalPages);
    }
    
    // Add first page and ellipsis if needed
    if (startPage > 1) {
      pageNumbers.add(_buildPageNumber(1));
      if (startPage > 2) {
        pageNumbers.add(_buildEllipsis());
      }
    }
    
    // Add visible page numbers
    for (int i = startPage; i <= endPage; i++) {
      pageNumbers.add(_buildPageNumber(i));
    }
    
    // Add ellipsis and last page if needed
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pageNumbers.add(_buildEllipsis());
      }
      pageNumbers.add(_buildPageNumber(totalPages));
    }
    
    return pageNumbers;
  }

  Widget _buildPageNumber(int page) {
    final isCurrentPage = page == currentPage;
    
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isCurrentPage ? CustomColors.primaryRed : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isCurrentPage ? null : Border.all(color: Colors.grey[300]!),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
        ),
        onPressed: isLoading ? null : () => onPageChanged(page),
        child: Text(
          '$page',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isCurrentPage ? FontWeight.w600 : FontWeight.w400,
            color: isCurrentPage ? Colors.white : CustomColors.lightOnSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Center(
        child: Text(
          '...',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: CustomColors.lightOnSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  int _getStartItem() {
    return ((currentPage - 1) * itemsPerPage) + 1;
  }

  int _getEndItem() {
    return (currentPage * itemsPerPage).clamp(1, totalItems);
  }
}

class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final int itemsPerPage;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Widget Function(BuildContext)? emptyWidget;
  final Widget Function(BuildContext)? loadingWidget;
  final bool isLoading;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;

  const PaginatedListView({
    super.key,
    required this.items,
    this.itemsPerPage = 10,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.isLoading = false,
    this.padding,
    this.physics,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  int _currentPage = 1;
  late List<T> _paginatedItems;

  @override
  void initState() {
    super.initState();
    _updatePaginatedItems();
  }

  @override
  void didUpdateWidget(PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items || oldWidget.itemsPerPage != widget.itemsPerPage) {
      _currentPage = 1;
      _updatePaginatedItems();
    }
  }

  void _updatePaginatedItems() {
    final startIndex = (_currentPage - 1) * widget.itemsPerPage;
    final endIndex = (startIndex + widget.itemsPerPage).clamp(0, widget.items.length);
    _paginatedItems = widget.items.sublist(startIndex, endIndex);
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _updatePaginatedItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return widget.loadingWidget?.call(context) ?? 
        const Center(child: CircularProgressIndicator());
    }

    if (widget.items.isEmpty) {
      return widget.emptyWidget?.call(context) ?? 
        const Center(child: Text('No items found'));
    }

    return Column(
      children: [
        // List items
        Expanded(
          child: ListView.builder(
            padding: widget.padding ?? EdgeInsets.zero,
            physics: widget.physics,
            itemCount: _paginatedItems.length,
            itemBuilder: (context, index) {
              final globalIndex = (_currentPage - 1) * widget.itemsPerPage + index;
              return widget.itemBuilder(context, _paginatedItems[index], globalIndex);
            },
          ),
        ),
        
        // Pagination controls
        PaginationWidget(
          currentPage: _currentPage,
          totalPages: (widget.items.length / widget.itemsPerPage).ceil(),
          totalItems: widget.items.length,
          itemsPerPage: widget.itemsPerPage,
          onPageChanged: _onPageChanged,
          isLoading: widget.isLoading,
        ),
      ],
    );
  }
}
