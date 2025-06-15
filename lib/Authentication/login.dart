import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobistore/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  bool _obscurePassword = true;
  bool _isLoading = false;

  // Cache commonly used styles and colors
  late final _titleStyle = GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: const Color(0xFF006A4E),
    letterSpacing: 1.2,
  );

  late final _subtitleStyle = GoogleFonts.roboto(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.grey.shade700,
  );

  late final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );

  late final _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Color(0xFF00876A), width: 2),
  );

  // Debounce timer for login button
  Timer? _debounceTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF006A4E),
              Color(0xFF00876A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 15,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('MobiStore', style: _titleStyle),
                      const SizedBox(height: 10),
                      Text('Inventory Management', style: _subtitleStyle),
                      const SizedBox(height: 30),
                      _buildEmailField(),
                      const SizedBox(height: 20),
                      _buildPasswordField(),
                      const SizedBox(height: 24),
                      _buildLoginButton(),
                      const SizedBox(height: 16),
                      _buildForgotPasswordButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _usernameController,
      enabled: !_isLoading,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: const Icon(Icons.person, color: Color(0xFF00876A)),
        border: _inputBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF00876A)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF006A4E),
          ),
          onPressed: _isLoading ? null : _togglePasswordVisibility,
        ),
        border: _inputBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _debouncedLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006A4E),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 5,
      ),
      child: _isLoading
          ? const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2,
        ),
      )
          : Text(
        'Login',
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _isLoading ? null : _debouncedForgotPassword,
      child: Text(
        'Forgot Password?',
        style: GoogleFonts.roboto(
          color: const Color(0xFF00876A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _debouncedLogin() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _login);
  }

  void _debouncedForgotPassword() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _forgotPassword);
  }

  Future<void> _login() async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text;

    if (!_validateInputs(email, password)) return;

    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateInputs(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password');
      return false;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address');
      return false;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return false;
    }
    return true;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found': return 'No user found for that email.';
        case 'wrong-password': return 'Wrong password provided.';
        case 'invalid-email': return 'Invalid email address.';
        case 'user-disabled': return 'This user account has been disabled.';
        case 'too-many-requests': return 'Too many login attempts. Please try again later.';
      }
    }
    if (error is TimeoutException) {
      return 'Login timeout. Please check your internet connection.';
    }
    return 'Login failed. Please try again.';
  }

  void _forgotPassword() async {
    final email = _usernameController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showMessage('Password reset email sent. Please check your inbox.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}