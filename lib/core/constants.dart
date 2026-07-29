import 'package:flutter/material.dart';

// الألوان الرئيسية - نفس ألوان الدكتور
const Color kPrimaryRed = Color.fromARGB(255, 163, 26, 104);
const Color kSecondaryRed = Color(0xFFD32F2F);
const Color kBackground = Color(0xFFF8F9FF);
const Color kSuccess = Color(0xFF4CAF50);
const Color kWarning = Color(0xFFFF9800);
const Color kError = Color(0xFFF44336);

// نصوص التطبيق


const String kBaseUrl = 'http://127.0.0.1:8080';
const String kSendPatientUrl = 'http://127.0.0.1:8080/add';
// روابط السيرفرات
const String kDoctorPingUrl = 'http://127.0.0.1:8080/ping';
const String kAddPatientUrl =
    'http://127.0.0.1:8080/add'; // أرسل مباشرة للدكتور

// Static lists (English)
const List<String> departments = [
  "Reception",
  "Emergency",
  "Dentistry",
  "Internal Medicine",
  "Pediatrics",
  "Gynecology"
];
const List<String> priorities = ["Normal", "Medium", "Urgent"];
const List<String> genders = ["male", "female"];

// Default values
const String defaultDepartment = "Reception";
const String defaultPriority = "Normal";
const String defaultGender = "male";

// مفاتيح SharedPreferences
const String kCurrentUserKey = 'currentUser';
const String kNursesKey = 'nurses';
