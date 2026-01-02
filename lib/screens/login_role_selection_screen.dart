import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import 'login_screen.dart';

class LoginRoleSelectionScreen extends StatelessWidget {
  const LoginRoleSelectionScreen({super.key});
  static const routeName = '/login-role-selection';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8), // Light gray background
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
                'Start Your Session',
                style: GoogleFonts.albertSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w600, // semibold
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
              
              // Student Button
              SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    LoginScreen.routeName,
                    arguments: const LoginArgs(UserType.student),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF257FCE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Student',
                    style: GoogleFonts.albertSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600, // semibold
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Faculty Button
              SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    LoginScreen.routeName,
                    arguments: const LoginArgs(UserType.faculty),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF257FCE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Faculty',
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