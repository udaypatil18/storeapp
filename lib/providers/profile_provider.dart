import 'package:flutter/material.dart';

class ProfileProvider extends ChangeNotifier {
  String? _username;

  String? get username => _username;

  void setUsername(String name) {
    _username = name;
    notifyListeners();
  }
}
