import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProgramChairInfoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProgramChairInfoScreen({super.key, required this.userData});

  @override
  State<ProgramChairInfoScreen> createState() => _ProgramChairInfoScreenState();
}

class _ProgramChairInfoScreenState extends State<ProgramChairInfoScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  List<Map<String, dynamic>> programChairInfo = [];
  bool loading = true;
  String? error;
  String selectedCollegeCode = "all";
  List<Map<String, dynamic>> colleges = [];
  bool dropdownOpen = false;
  int page = 0;
  int rowsPerPage = 10;

  // Keep alive for better performance
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    if (mounted) {
      await _fetchData();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    try {
      // Load any user-specific data if needed
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load user data: $e';
        });
      }
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await _fetchProgramChairInfo();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _fetchProgramChairInfo() async {
    if (!mounted) return;
    
    try {
      print('Fetching program chair info...');
      
      final response = await http.get(
        Uri.parse('https://eduvision-dura.onrender.com/api/superadmin/programchairinfo-only'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      print('Program Chair Info API Response Status: ${response.statusCode}');
      print('Program Chair Info API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            programChairInfo = data is List ? data.cast<Map<String, dynamic>>() : [];
            
            // Extract unique colleges
            final collegeMap = <String, Map<String, dynamic>>{};
            for (final pc in programChairInfo) {
              if (pc['college'] != null) {
                collegeMap[pc['college']['_id']] = pc['college'];
              }
            }
            
            colleges = [
              {'_id': 'all', 'code': 'All', 'name': 'All Colleges'},
              ...collegeMap.values.toList(),
            ];
          });
          print('Successfully loaded ${programChairInfo.length} program chairs');
        }
      } else {
        print('Failed to fetch program chair info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching program chair info: $e');
      if (mounted) {
        setState(() {
          error = 'Failed to fetch program chair info';
        });
      }
    }
  }

  List<Map<String, dynamic>> get filteredProgramChairInfo {
    if (selectedCollegeCode == "all") return programChairInfo;
    return programChairInfo.where((pc) => pc['college']?['code'] == selectedCollegeCode).toList();
  }

  List<Map<String, dynamic>> get paginatedData {
    final start = page * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, filteredProgramChairInfo.length);
    return filteredProgramChairInfo.sublist(start, end);
  }

  void _handleChangePage(int newPage) {
    setState(() {
      page = newPage;
    });
  }

  void _handleChangeRowsPerPage(int newRowsPerPage) {
    setState(() {
      rowsPerPage = newRowsPerPage;
      page = 0;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: const Color(0xFFf4f6f8),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSearchAndAdd(),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildTable(),
                ),
                if (filteredProgramChairInfo.isNotEmpty) _buildPagination(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'List of Program Chairperson/s',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This section contains a list of all current program chairpersons across departments and their respective information.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndAdd() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, username, or email...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              // Implement search functionality
              print('Search: $value');
            },
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            // Handle add program chairperson
            print('Add Program Chairperson clicked');
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Program Chairperson'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading data...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: paginatedData.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No program chairperson data available.'),
                    ),
                  )
                : _buildTableBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFf9f9f9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Full Name',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Username',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Email',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _buildCollegeDropdown(),
          ),
          Expanded(
            child: Text(
              'Status',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Action',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollegeDropdown() {
    return GestureDetector(
      onTap: () {
        setState(() {
          dropdownOpen = !dropdownOpen;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(
              'College',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTableBody() {
    return Stack(
      children: [
        ListView.builder(
          itemCount: paginatedData.length,
          itemBuilder: (context, index) {
            final programChair = paginatedData[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${programChair['last_name']}, ${programChair['first_name']} ${programChair['middle_name'] != null ? programChair['middle_name'][0] + '.' : ''}',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      programChair['username'] ?? '',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      programChair['email'] ?? '',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      programChair['college']?['name'] ?? 'N/A',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      programChair['status'] == 'forverification'
                          ? 'For Verification'
                          : (programChair['status'] ?? '').isNotEmpty
                              ? (programChair['status'][0].toUpperCase() + programChair['status'].substring(1))
                              : 'N/A',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => print('Edit ${programChair['_id']}'),
                          icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                        ),
                        IconButton(
                          onPressed: () => print('Delete ${programChair['_id']}'),
                          icon: const Icon(Icons.delete_rounded, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (dropdownOpen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: colleges.map((college) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedCollegeCode = college['code'] == 'All' ? 'all' : college['code'];
                        dropdownOpen = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        college['code'],
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page * rowsPerPage + 1} to ${(page * rowsPerPage + rowsPerPage).clamp(0, filteredProgramChairInfo.length)} of ${filteredProgramChairInfo.length} entries',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Row(
            children: [
              DropdownButton<int>(
                value: rowsPerPage,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _handleChangeRowsPerPage(value);
                  }
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: page > 0 ? () => _handleChangePage(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${page + 1}',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              IconButton(
                onPressed: (page + 1) * rowsPerPage < filteredProgramChairInfo.length
                    ? () => _handleChangePage(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
