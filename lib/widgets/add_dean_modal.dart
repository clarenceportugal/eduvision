import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class AddDeanModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onAddDean;
  final List<dynamic> colleges;

  const AddDeanModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onAddDean,
    required this.colleges,
  });

  @override
  State<AddDeanModal> createState() => _AddDeanModalState();
}

class _AddDeanModalState extends State<AddDeanModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _extNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _highestEducationalAttainmentController = TextEditingController();
  final _academicRankController = TextEditingController();
  final _statusOfAppointmentController = TextEditingController();

  String _selectedCollege = '';
  final String _selectedRole = 'dean';
  int _numberOfPrep = 0;
  int _totalTeachingLoad = 0;
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _generatePassword();
    _generateUsername();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _extNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _highestEducationalAttainmentController.dispose();
    _academicRankController.dispose();
    _statusOfAppointmentController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    _passwordController.text = random.toString().padLeft(4, '0');
  }

  void _generateUsername() {
    if (_firstNameController.text.isNotEmpty && _lastNameController.text.isNotEmpty) {
      _usernameController.text = ApiService.generateUsername(
        _firstNameController.text,
        _lastNameController.text,
      );
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  Future<void> _handleAddDean() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCollege.isEmpty) {
      _showErrorSnackBar('Please select a college');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final deanData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'ext_name': _extNameController.text.trim(),
        'email': _emailController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
        'college': _selectedCollege,
        'highestEducationalAttainment': _highestEducationalAttainmentController.text.trim(),
        'academicRank': _academicRankController.text.trim(),
        'statusOfAppointment': _statusOfAppointmentController.text.trim(),
        'numberOfPrep': _numberOfPrep,
        'totalTeachingLoad': _totalTeachingLoad,
        'status': 'active',
      };

      await ApiService.addDean(deanData);
      
      if (mounted) {
        widget.onAddDean(deanData);
        _showSuccessSnackBar('Dean added successfully!');
        _resetForm();
        widget.onClose();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to add dean: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _firstNameController.clear();
    _lastNameController.clear();
    _middleNameController.clear();
    _extNameController.clear();
    _emailController.clear();
    _usernameController.clear();
    _highestEducationalAttainmentController.clear();
    _academicRankController.clear();
    _statusOfAppointmentController.clear();
    _selectedCollege = '';
    _numberOfPrep = 0;
    _totalTeachingLoad = 0;
    _generatePassword();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Dean',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D1308),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      _buildSectionTitle('Personal Information'),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _firstNameController,
                              label: 'First Name *',
                              onChanged: (value) => _generateUsername(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _lastNameController,
                              label: 'Last Name *',
                              onChanged: (value) => _generateUsername(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _middleNameController,
                              label: 'Middle Name',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _extNameController,
                              label: 'Extension Name (Jr., Sr., etc.)',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Account Information Section
                      _buildSectionTitle('Account Information'),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _emailController,
                              label: 'Email Address *',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!ApiService.isValidEmail(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _usernameController,
                              label: 'Username *',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildTextField(
                              controller: _passwordController,
                              label: 'Password *',
                              obscureText: !_showPassword,
                              suffixIcon: IconButton(
                                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: _togglePasswordVisibility,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.length < 4) {
                                  return 'Password must be at least 4 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildDropdown(
                              value: _selectedCollege,
                  items: widget.colleges.map<DropdownMenuItem<String>>((college) => DropdownMenuItem<String>(
                    value: college['_id']?.toString(),
                    child: Text(
                      college['name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                              onChanged: (value) => setState(() => _selectedCollege = value ?? ''),
                              label: 'College *',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Academic Information Section
                      _buildSectionTitle('Academic Information'),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _highestEducationalAttainmentController,
                              label: 'Highest Educational Attainment',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _academicRankController,
                              label: 'Academic Rank',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _statusOfAppointmentController,
                              label: 'Status of Appointment',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildNumberField(
                              value: _numberOfPrep,
                              label: 'Number of Preparations',
                              onChanged: (value) => setState(() => _numberOfPrep = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildNumberField(
                        value: _totalTeachingLoad,
                        label: 'Total Teaching Load',
                        onChanged: (value) => setState(() => _totalTeachingLoad = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAddDean,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D1308),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add Dean'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF3D1308),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3D1308), width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String label,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3D1308), width: 2),
        ),
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a $label';
        }
        return null;
      },
    );
  }

  Widget _buildNumberField({
    required int value,
    required String label,
    required void Function(int) onChanged,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        final intValue = int.tryParse(value) ?? 0;
        onChanged(intValue);
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3D1308), width: 2),
        ),
      ),
    );
  }
}
