import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResponsiveTable extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> data;
  final List<String> dataKeys;
  final bool loading;
  final String emptyMessage;

  const ResponsiveTable({
    super.key,
    required this.columns,
    required this.data,
    required this.dataKeys,
    this.loading = false,
    this.emptyMessage = 'No data available',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        if (isMobile) {
          return _buildMobileList(context);
        } else {
          return _buildDesktopTable(context);
        }
      },
    );
  }

  Widget _buildMobileList(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            emptyMessage,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: index % 2 == 0
                ? Colors.transparent
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item['time'] != null)
                    Text(
                      item['time'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...dataKeys.asMap().entries.where((entry) {
                final i = entry.key;
                final key = entry.value;
                return i < columns.length && key != 'time' && item[key] != null;
              }).map((entry) {
                final i = entry.key;
                final key = entry.value;
                final value = item[key];
                if (value is Widget) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${columns[i]}:',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        value,
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${columns[i]}: ${value.toString()}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  );
                }
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map((column) => DataColumn(
          label: Text(
            column,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )).toList(),
        rows: data.isEmpty
            ? [
                DataRow(
                  cells: List.generate(
                    columns.length,
                    (index) => DataCell(Text(emptyMessage)),
                  ),
                ),
              ]
            : data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return DataRow(
                  color: WidgetStateProperty.all(
                    index % 2 == 0
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  cells: dataKeys.map((key) {
                    final value = item[key];
                    if (value is Widget) {
                      return DataCell(value);
                    } else {
                      return DataCell(Text(value?.toString() ?? ''));
                    }
                  }).toList(),
                );
              }).toList(),
      ),
    );
  }
}
