import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../../core/constants.dart';

// استيراد dashboard.dart باستخدام المسار الصحيح
import '../doctor/dashboard.dart'; // ✅ المسار الصحيح

class DoctorAuthWrapper extends StatefulWidget {
  const DoctorAuthWrapper({super.key});

  @override
  State<DoctorAuthWrapper> createState() => _DoctorAuthWrapperState();
}

class _DoctorAuthWrapperState extends State<DoctorAuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentDoctor;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final doctorJson = prefs.getString('currentDoctor');

    if (doctorJson != null) {
      setState(() {
        _currentDoctor = jsonDecode(doctorJson);
        _isLoggedIn = true;
      });
    }

    setState(() => _isLoading = false);
  }

  void _onLogin(Map<String, dynamic> doctor) {
    setState(() {
      _currentDoctor = doctor;
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    setState(() {
      _currentDoctor = null;
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kPrimaryRed),
              const SizedBox(height: 20),
              const Text('جاري التحميل...'),
            ],
          ),
        ),
      );
    }

    return _isLoggedIn
        ? DoctorDashboard( // ✅ تم إصلاح الخطأ هنا
            currentDoctor: _currentDoctor!,
            onLogout: _onLogout,
          )
        : DoctorLoginScreen(onLogin: _onLogin);
  }
}