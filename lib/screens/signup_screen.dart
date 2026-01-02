import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'role_selection_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  static const routeName = '/signup';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _department = TextEditingController();
  bool _obscure = true;
  UserType _role = UserType.student;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final args = ModalRoute.of(context)?.settings.arguments as SignUpArgs?;
    _role = args?.role ?? UserType.student;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, RoleSelectionScreen.routeName, (_) => false),
        ),
        title: Text(_role == UserType.student ? 'Student Sign Up' : 'Faculty Sign Up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(_role == UserType.student ? 'Student' : 'Faculty'),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Full name'),
                          validator: (v) => (v ?? '').isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => EmailValidator.validate(v ?? '') ? null : 'Enter valid email',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v ?? '').length >= 6 ? null : 'Min 6 characters',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _id,
                          decoration: InputDecoration(labelText: _role == UserType.student ? 'Student ID (optional)' : 'Faculty ID (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _department,
                          decoration: InputDecoration(labelText: _role == UserType.student ? 'Major (optional)' : 'Department (required)'),
                          validator: (v) {
                            if (_role == UserType.faculty && (v == null || v.isEmpty)) {
                              return 'Department required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    final err = await auth.signup(
                                      email: _email.text.trim(),
                                      password: _password.text,
                                      fullName: _name.text.trim(),
                                      userType: _role,
                                      studentId: _role == UserType.student ? _id.text : null,
                                      facultyId: _role == UserType.faculty ? _id.text : null,
                                      department: _department.text.isEmpty ? null : _department.text,
                                    );
                                    if (err != null) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                    } else {
                                      if (!mounted) return;
                                      Navigator.pushNamedAndRemoveUntil(context, DashboardScreen.routeName, (_) => false);
                                    }
                                  },
                            child: auth.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Sign Up'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(_role == UserType.student ? 'Already a student? Login' : 'Already faculty? Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpArgs {
  const SignUpArgs(this.role);
  final UserType role;
}
