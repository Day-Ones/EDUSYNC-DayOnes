import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/connectivity_service.dart';
import '../widgets/loading_overlay.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  UserType _role = UserType.student;
  bool _init = false;
  bool _isGoogleLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final args = ModalRoute.of(context)?.settings.arguments as LoginArgs?;
    _role = args?.role ?? UserType.student;
  }

  Future<void> _signInWithGoogle() async {
    // Check internet connection first
    final connectivity = context.read<ConnectivityService>();
    if (!connectivity.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet connection required to login'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isGoogleLoading = true);

    final auth = context.read<AuthProvider>();
    final error = await auth.signInWithGoogle(role: _role);

    setState(() => _isGoogleLoading = false);

    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, DashboardScreen.routeName, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.isLoading || _isGoogleLoading;
    
    return PopScope(
      canPop: !isLoading, // Prevent back during loading
      child: LoadingOverlay(
        isLoading: isLoading,
        message: _isGoogleLoading ? 'Signing in with Google...' : 'Logging in...',
        child: Scaffold(
          backgroundColor: const Color(0xFFE8E8E8),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: isLoading ? null : () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF257FCE).withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    color: isLoading ? Colors.grey : const Color(0xFF257FCE),
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
                    color: Colors.black.withOpacity(0.1),
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
                      // Title
                      Text(
                        _role == UserType.student
                            ? 'Student Login'
                            : 'Faculty Login',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF257FCE),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Sign in to your account',
                        style: GoogleFonts.albertSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Google Sign-In Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed:
                              isLoading ? null : _signInWithGoogle,
                          icon: Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.g_mobiledata, size: 24),
                                ),
                          label: Text(
                            'Continue with Google',
                            style: GoogleFonts.albertSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isLoading ? Colors.grey : Colors.black87,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isLoading ? Colors.grey[300]! : Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'or',
                              style: GoogleFonts.albertSans(color: Colors.grey),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Email Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: GoogleFonts.albertSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide:
                                    const BorderSide(color: Color(0xFF257FCE)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) =>
                                EmailValidator.validate(value ?? '')
                                    ? null
                                    : 'Enter a valid email',
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Password Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: GoogleFonts.albertSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(5),
                                borderSide:
                                    const BorderSide(color: Color(0xFF257FCE)),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) => (value ?? '').length >= 6
                                ? null
                                : 'Password must be at least 6 characters',
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  // Check internet connection first
                                  final connectivity =
                                      context.read<ConnectivityService>();
                                  if (!connectivity.isOnline) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Internet connection required to login'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (!_formKey.currentState!.validate())
                                    return;
                                  final err = await auth.login(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                    role: _role,
                                    remember: _remember,
                                  );
                                  if (err != null) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err)));
                                  } else {
                                    if (!mounted) return;
                                    Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        DashboardScreen.routeName,
                                        (_) => false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF257FCE),
                            disabledBackgroundColor: const Color(0xFF257FCE).withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                                  'LOG IN',
                                  style: GoogleFonts.albertSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sign Up Link
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.pushNamed(
                            context, SignupScreen.routeName),
                        child: Text(
                          "Don't have an account? Sign Up",
                          style: GoogleFonts.albertSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isLoading ? Colors.grey : Colors.black87,
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
      ),
      ),
    );
  }
}

class LoginArgs {
  const LoginArgs(this.role);
  final UserType role;
}
