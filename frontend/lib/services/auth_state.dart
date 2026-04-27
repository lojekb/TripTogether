import 'package:flutter/material.dart';
import 'package:trip_together/models/user.dart';
import 'package:trip_together/services/auth_service.dart';

class AuthState extends ChangeNotifier {
  final AuthService authService;

  User? currentUser;
  String? token;
  bool loading = false;
  Map<String, List<String>> fieldErrors = {};
  List<String> nonFieldErrors = [];

  AuthState({required this.authService});

  Future<bool> login({required String email, required String password}) async {
    loading = true;
    fieldErrors = {};
    nonFieldErrors = [];
    notifyListeners();

    try {
      final result = await authService.login(email: email, password: password);
      currentUser = result.user;
      token = result.token;
      loading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (ve) {
      fieldErrors = ve.errors;
    } catch (e) {
      nonFieldErrors = [e.toString()];
    }

    loading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    currentUser = null;
    token = null;
    notifyListeners();
  }
}
