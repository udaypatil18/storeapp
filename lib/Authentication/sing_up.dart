import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobistore/Authentication/login.dart';
import 'package:mobistore/home.dart';
import 'dart:async';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  // Firebase instance
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const Duration _registrationTimeout = Duration(seconds: 15);
  static const int _minPasswordLength = 6;
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  // State variables
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  Timer? _debounceTimer;

  // Cached styles - computed once and reused
  late final TextStyle _titleStyle;
  late final TextStyle _subtitleStyle;
  late final InputBorder _inputBorder;
  late final InputBorder _focusedBorder;
  late final ButtonStyle _registerButtonStyle;
  late final TextStyle _registerButtonTextStyle;
  late final TextStyle _loginLinkTextStyle;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeStyles();
  }

  void _initializeControllers() {
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  void _initializeStyles() {
    _titleStyle = GoogleFonts.montserrat(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF006A4E),
      letterSpacing: 1.2,
    );

    _subtitleStyle = GoogleFonts.roboto(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade700,
    );

    _inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    _focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFF00876A), width: 2),
    );

    _registerButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF006A4E),
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 5,
    );

    _registerButtonTextStyle = GoogleFonts.roboto(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    _loginLinkTextStyle = GoogleFonts.roboto(
      color: const Color(0xFF00876A),
      fontWeight: FontWeight.w600,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF006A4E), Color(0xFF00876A)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildSignupCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupCard() {
    return Card(
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
            _buildHeader(),
            const SizedBox(height: 30),
            _buildEmailField(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 20),
            _buildConfirmPasswordField(),
            const SizedBox(height: 24),
            _buildRegisterButton(),
            const SizedBox(height: 16),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('Create Account', style: _titleStyle),
        const SizedBox(height: 10),
        Text('D-Mall', style: _subtitleStyle),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      enabled: !_isLoading,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: const Icon(Icons.email, color: Color(0xFF00876A)),
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
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF00876A)),
        suffixIcon: _buildPasswordVisibilityIcon(
          _obscurePassword,
              () => _togglePasswordVisibility(isConfirmField: false),
        ),
        border: _inputBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      enabled: !_isLoading,
      textInputAction: TextInputAction.done,
      onSubmitted: _isLoading ? null : (_) => _debouncedRegister(),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00876A)),
        suffixIcon: _buildPasswordVisibilityIcon(
          _obscureConfirmPassword,
              () => _togglePasswordVisibility(isConfirmField: true),
        ),
        border: _inputBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }

  Widget _buildPasswordVisibilityIcon(bool obscureText, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(
        obscureText ? Icons.visibility : Icons.visibility_off,
        color: const Color(0xFF006A4E),
      ),
      onPressed: _isLoading ? null : onPressed,
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _debouncedRegister,
      style: _registerButtonStyle,
      child: _isLoading ? _buildLoadingIndicator() : _buildRegisterButtonText(),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildRegisterButtonText() {
    return Text('Create Account', style: _registerButtonTextStyle);
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: _isLoading ? null : _navigateToLogin,
      child: Text(
        'Already have an account? Login',
        style: _loginLinkTextStyle,
      ),
    );
  }

  // Event handlers
  void _togglePasswordVisibility({required bool isConfirmField}) {
    if (mounted) {
      setState(() {
        if (isConfirmField) {
          _obscureConfirmPassword = !_obscureConfirmPassword;
        } else {
          _obscurePassword = !_obscurePassword;
        }
      });
    }
  }

  void _debouncedRegister() {
    _cancelDebounceTimer();
    _debounceTimer = Timer(_debounceDelay, _registerUser);
  }

  void _cancelDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // Core functionality
  Future<void> _registerUser() async {
    final credentials = _getCredentials();

    if (!_validateCredentials(credentials)) return;

    _setLoadingState(true);

    try {
      await _performRegistration(credentials);
      _handleRegistrationSuccess();
    } catch (e) {
      _handleRegistrationError(e);
    } finally {
      _setLoadingState(false);
    }
  }

  RegistrationCredentials _getCredentials() {
    return RegistrationCredentials(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      confirmPassword: _confirmPasswordController.text.trim(),
    );
  }

  bool _validateCredentials(RegistrationCredentials credentials) {
    if (_hasEmptyFields(credentials)) {
      _showMessage('All fields are required.');
      return false;
    }

    if (!_isValidEmail(credentials.email)) {
      _showMessage('Please enter a valid email address');
      return false;
    }

    if (!_isValidPassword(credentials.password)) {
      _showMessage('Password must be at least $_minPasswordLength characters');
      return false;
    }

    if (!_passwordsMatch(credentials)) {
      _showMessage('Passwords do not match.');
      return false;
    }

    return true;
  }

  bool _hasEmptyFields(RegistrationCredentials credentials) {
    return credentials.email.isEmpty ||
        credentials.password.isEmpty ||
        credentials.confirmPassword.isEmpty;
  }

  bool _isValidEmail(String email) {
    return _emailRegex.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= _minPasswordLength;
  }

  bool _passwordsMatch(RegistrationCredentials credentials) {
    return credentials.password == credentials.confirmPassword;
  }

  Future<UserCredential> _performRegistration(RegistrationCredentials credentials) {
    return _auth.createUserWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    ).timeout(_registrationTimeout);
  }

  void _handleRegistrationSuccess() {
    if (mounted) {
      _showMessage('Registration Successful!');
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _handleRegistrationError(Object error) {
    if (mounted) {
      _showMessage(_getErrorMessage(error));
    }
  }

  void _setLoadingState(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  // Utility methods
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return _getFirebaseErrorMessage(error.code);
    }

    if (error is TimeoutException) {
      return 'Registration timeout. Please check your internet connection.';
    }

    return 'Registration failed. Please try again.';
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _cancelDebounceTimer();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// Helper class for better data organization
class RegistrationCredentials {
  final String email;
  final String password;
  final String confirmPassword;

  const RegistrationCredentials({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });
}