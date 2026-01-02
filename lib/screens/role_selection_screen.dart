import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'login_role_selection_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  static const routeName = '/select-role';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              
              // App Title
              Text(
                'EduSync+: Class Scheduler',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800, // extrabold
                  color: const Color(0xFF257FCE),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Subtitle
              Text(
                'Sign in to start your new session',
                style: GoogleFonts.albertSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Logo Image
              Container(
                width: 150,
                height: 150,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              
              const SizedBox(height: 80),
              
              // Log In Button
              SizedBox(
                width: 222,
                height: 47.9,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    LoginRoleSelectionScreen.routeName,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF257FCE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5), // 5px corner radius
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Log In',
                    style: GoogleFonts.albertSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600, // semibold
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Sign Up Button
              SizedBox(
                width: 222,
                height: 47.9,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    SignupScreen.routeName,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF257FCE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5), // 5px corner radius
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign up',
                    style: GoogleFonts.albertSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600, // semibold
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}