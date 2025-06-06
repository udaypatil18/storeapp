import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mobistore/Authentication/login.dart';
import 'package:mobistore/home.dart';
import 'package:mobistore/Authentication/sing_up.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobistore/firebase_services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MobiStore());
}

class MobiStore extends StatelessWidget {
  const MobiStore({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobiStore',
      home: SignUpPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
