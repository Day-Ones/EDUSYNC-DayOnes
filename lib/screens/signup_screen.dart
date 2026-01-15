import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  static const routeName = '/signup';

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _facultyIdController = TextEditingController();
  final _departmentController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _hasMiddleName = true;
  UserType _selectedRole = UserType.student;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    _facultyIdController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = context.read<AuthProvider>();
    
    // Build full name
    String fullName = _firstNameController.text.trim();
    if (_hasMiddleName && _middleNameController.text.isNotEmpty) {
      fullName += ' ${_middleNameController.text.trim()}';
    }
    fullName += ' ${_lastNameController.text.trim()}';
    
    final error = await auth.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: fullName,
      userType: _selectedRole,
      studentId: _selectedRole == UserType.student ? _studentIdController.text.trim() : null,
      facultyId: _selectedRole == UserType.faculty ? _facultyIdController.text.trim() : null,
      department: _departmentController.text.trim().isNotEmpty ? _departmentController.text.trim() : null,
    );
    
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );
      Navigator.pushNamedAndRemoveUntil(context, DashboardScreen.routeName, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF257FCE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Welcome Title
                    Text(
                      'Welcome!',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF257FCE),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'Sign up your Account',
                      style: GoogleFonts.albertSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w600, // semibold
                        color: Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // First Name Field
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: GoogleFonts.albertSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w500, // medium
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Middle Name and Last Name Row with Checkbox
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _middleNameController,
                                enabled: _hasMiddleName,
                                decoration: InputDecoration(
                                  labelText: 'Middle Name',
                                  labelStyle: GoogleFonts.albertSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500, // medium
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: 'Last Name',
                                  labelStyle: GoogleFonts.albertSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500, // medium
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your last name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // "I don't have a middle name" checkbox aligned under middle name
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: !_hasMiddleName,
                                onChanged: (value) {
                                  setState(() {
                                    _hasMiddleName = !value!;
                                    if (!_hasMiddleName) {
                                      _middleNameController.clear();
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF257FCE),
                              ),
                              Text(
                                'I don\'t have a middle name',
                                style: GoogleFonts.albertSans(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Birthday and Gender Row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedDate == null
                                        ? 'Birthday'
                                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                    style: GoogleFonts.albertSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500, // medium
                                      color: _selectedDate == null
                                          ? Colors.grey[600]
                                          : Colors.black87,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              labelStyle: GoogleFonts.albertSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w500, // medium
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            items: ['Male', 'Female', 'Other'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedGender = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select gender';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Role Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I am a:',
                          style: GoogleFonts.albertSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<UserType>(
                                title: Text(
                                  'Student',
                                  style: GoogleFonts.albertSans(fontSize: 16),
                                ),
                                value: UserType.student,
                                groupValue: _selectedRole,
                                onChanged: (value) {
                                  setState(() => _selectedRole = value!);
                                },
                                activeColor: const Color(0xFF257FCE),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<UserType>(
                                title: Text(
                                  'Faculty',
                                  style: GoogleFonts.albertSans(fontSize: 16),
                                ),
                                value: UserType.faculty,
                                groupValue: _selectedRole,
                                onChanged: (value) {
                                  setState(() => _selectedRole = value!);
                                },
                                activeColor: const Color(0xFF257FCE),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Student ID or Faculty ID Field
                    TextFormField(
                      controller: _selectedRole == UserType.student 
                          ? _studentIdController 
                          : _facultyIdController,
                      decoration: InputDecoration(
                        labelText: _selectedRole == UserType.student 
                            ? 'Student ID' 
                            : 'Faculty ID',
                        labelStyle: GoogleFonts.albertSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your ${_selectedRole == UserType.student ? 'Student' : 'Faculty'} ID';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Department Field
                    TextFormField(
                      controller: _departmentController,
                      decoration: InputDecoration(
                        labelText: _selectedRole == UserType.student 
                            ? 'Department / Major' 
                            : 'Department',
                        labelStyle: GoogleFonts.albertSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: GoogleFonts.albertSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w500, // medium
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: GoogleFonts.albertSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w500, // medium
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: GoogleFonts.albertSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w500, // medium
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Create Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, child) => ElevatedButton(
                          onPressed: auth.isLoading ? null : _createAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF257FCE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Create Account',
                            style: GoogleFonts.albertSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}