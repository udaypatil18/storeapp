import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mobistore/providers/product_provider.dart';
import 'package:provider/provider.dart';
import 'package:mobistore/providers/cart_provider.dart';
import 'package:mobistore/Authentication/login.dart';
import 'package:mobistore/Authentication/sing_up.dart';
import 'package:mobistore/home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartManager.instance),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: const MobiStore(),
    ),
  );
}

class MobiStore extends StatelessWidget {
  const MobiStore({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobiStore',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Use the updated AuthGate below
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? isFirstTime;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenSignup') ?? false;

    if (!hasSeen) {
      await prefs.setBool('hasSeenSignup', true); // mark as seen
    }

    setState(() {
      isFirstTime = !hasSeen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstTime == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        if (isFirstTime == true) {
          return const SignUpPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
