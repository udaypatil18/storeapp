import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobistore/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false; // Added loading state

  // Added email validation regex
  final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF006A4E), // Deep Teal
              Color(0xFF00876A), // Soft Emerald Green
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 15,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo or Title
                        Text(
                          'MobiStore',
                          style: GoogleFonts.montserrat(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF006A4E),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Inventory Management',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 30),

                        // Username TextField
                        TextField(
                          controller: _usernameController,
                          enabled: !_isLoading, // Disable during loading
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: GoogleFonts.roboto(),
                            prefixIcon:
                            Icon(Icons.person, color: Color(0xFF00876A)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                  color: Color(0xFF00876A), width: 2),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // Password TextField
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading, // Disable during loading
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: GoogleFonts.roboto(),
                            prefixIcon:
                            Icon(Icons.lock, color: Color(0xFF00876A)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Color(0xFF006A4E),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                  color: Color(0xFF00876A), width: 2),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Login Button with Loading State
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Text(
                            'Login',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF006A4E),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Forgot Password
                        TextButton(
                          onPressed: _isLoading ? null : _forgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.roboto(
                              color: Color(0xFF00876A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  // Optimized login function with proper validation and error handling
  void _login() async {
    // Get and trim input values
    final email = _usernameController.text.trim();
    final password = _passwordController.text;

    // Client-side validation before making network request
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password');
      return;
    }

    // Validate email format
    if (!_emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    // Validate password length
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Attempt login with timeout
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
        Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Login timeout'),
      );

      // Navigate to HomePage on successful login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_getErrorMessage(e.code));
    } on TimeoutException {
      _showMessage('Login timeout. Please check your internet connection.');
    } catch (e) {
      _showMessage('An error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Separate error message handling
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  // Helper method to show messages
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _forgotPassword() {
    if (_isLoading) return;

    final email = _usernameController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    FirebaseAuth.instance
        .sendPasswordResetEmail(email: email)
        .then((_) {
      _showMessage('Password reset email sent. Please check your inbox.');
    })
        .catchError((error) {
      _showMessage('Failed to send reset email. Please try again.');
    })
        .whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}