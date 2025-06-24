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

class _LoginPageState extends State<LoginPage> {
  // Controllers
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  // Firebase instance
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const Duration _loginTimeout = Duration(seconds: 10);
  static const int _minPasswordLength = 6;
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  // State variables
  bool _obscurePassword = true;
  bool _isLoading = false;
  Timer? _debounceTimer;

  // Cached styles - computed once and reused
  late final TextStyle _titleStyle;
  late final TextStyle _subtitleStyle;
  late final InputBorder _inputBorder;
  late final InputBorder _focusedBorder;
  late final ButtonStyle _loginButtonStyle;
  late final TextStyle _loginButtonTextStyle;
  late final TextStyle _forgotPasswordTextStyle;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeStyles();
  }

  void _initializeControllers() {
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
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

    _loginButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF006A4E),
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      elevation: 5,
    );

    _loginButtonTextStyle = GoogleFonts.roboto(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    _forgotPasswordTextStyle = GoogleFonts.roboto(
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
            child: _buildLoginCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
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
            const SizedBox(height: 24),
            _buildLoginButton(),
            const SizedBox(height: 16),
            _buildForgotPasswordButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text('D-Mall', style: _titleStyle),
        const SizedBox(height: 10),
        Text('Inventory Management', style: _subtitleStyle),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _usernameController,
      enabled: !_isLoading,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
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
      textInputAction: TextInputAction.done,
      onSubmitted: _isLoading ? null : (_) => _debouncedLogin(),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: const Icon(Icons.lock, color: Color(0xFF00876A)),
        suffixIcon: _buildPasswordVisibilityIcon(),
        border: _inputBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }

  Widget _buildPasswordVisibilityIcon() {
    return IconButton(
      icon: Icon(
        _obscurePassword ? Icons.visibility : Icons.visibility_off,
        color: const Color(0xFF006A4E),
      ),
      onPressed: _isLoading ? null : _togglePasswordVisibility,
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _debouncedLogin,
      style: _loginButtonStyle,
      child: _isLoading ? _buildLoadingIndicator() : _buildLoginButtonText(),
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

  Widget _buildLoginButtonText() {
    return Text('Login', style: _loginButtonTextStyle);
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _isLoading ? null : _debouncedForgotPassword,
      child: Text('Forgot Password?', style: _forgotPasswordTextStyle),
    );
  }

  // Event handlers
  void _togglePasswordVisibility() {
    if (mounted) {
      setState(() => _obscurePassword = !_obscurePassword);
    }
  }

  void _debouncedLogin() {
    _cancelDebounceTimer();
    _debounceTimer = Timer(_debounceDelay, _login);
  }

  void _debouncedForgotPassword() {
    _cancelDebounceTimer();
    _debounceTimer = Timer(_debounceDelay, _forgotPassword);
  }

  void _cancelDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // Core functionality
  Future<void> _login() async {
    final credentials = _getCredentials();

    if (!_validateCredentials(credentials)) return;

    _setLoadingState(true);

    try {
      await _performLogin(credentials);
      _navigateToHome();
    } catch (e) {
      _handleLoginError(e);
    } finally {
      _setLoadingState(false);
    }
  }

  LoginCredentials _getCredentials() {
    return LoginCredentials(
      email: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  bool _validateCredentials(LoginCredentials credentials) {
    if (credentials.email.isEmpty || credentials.password.isEmpty) {
      _showMessage('Please enter email and password');
      return false;
    }

    if (!_emailRegex.hasMatch(credentials.email)) {
      _showMessage('Please enter a valid email address');
      return false;
    }

    if (credentials.password.length < _minPasswordLength) {
      _showMessage('Password must be at least $_minPasswordLength characters');
      return false;
    }

    return true;
  }

  Future<UserCredential> _performLogin(LoginCredentials credentials) {
    return _auth.signInWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    ).timeout(_loginTimeout);
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  void _handleLoginError(Object error) {
    if (mounted) {
      _showMessage(_getErrorMessage(error));
    }
  }

  void _setLoadingState(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _usernameController.text.trim();

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }

    _setLoadingState(true);

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showMessage('Password reset email sent. Please check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to send reset email. Please try again.');
      }
    } finally {
      _setLoadingState(false);
    }
  }

  bool _isValidEmail(String email) {
    return email.isNotEmpty && _emailRegex.hasMatch(email);
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
      return 'Login timeout. Please check your internet connection.';
    }

    return 'Login failed. Please try again.';
  }

  String _getFirebaseErrorMessage(String code) {
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
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _cancelDebounceTimer();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Helper class for better data organization
class LoginCredentials {
  final String email;
  final String password;

  const LoginCredentials({
    required this.email,
    required this.password,
  });
}