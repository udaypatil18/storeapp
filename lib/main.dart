import 'package:flutter/material.dart';
import 'package:mobistore/Authentication/login.dart';
import 'package:mobistore/home.dart';

void main() {
  runApp(const MobiStore());
}

class MobiStore extends StatelessWidget {
  const MobiStore({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobiStore',
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
