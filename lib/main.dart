import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/auth/login_screen.dart';
import 'core/constants.dart';
import 'core/language_provider.dart';
import 'core/app_localizations.dart';
import 'core/auth_gate.dart'; // ← بدل license_service.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // ← حذفنا: final isLicensed = await LicenseService.isLicensed();

  runApp(const DoctorSystemApp());
}

class DoctorSystemApp extends StatelessWidget {
  const DoctorSystemApp({super.key}); // ← حذفنا isLicensed من الـ constructor

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      child: Builder(
        builder: (ctx) {
          final langState = LanguageProvider.of(ctx);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: langState.l.appTitle,
            theme: ThemeData(
              primaryColor: kPrimaryRed,
              scaffoldBackgroundColor: Colors.white,
              fontFamily: 'Cairo',
            ),
            home: AuthGate(
              appId: 'doctor_app',
              accentColor: kPrimaryRed,
              child: const DoctorLoginScreen(),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════
//  شاشة الجهاز الغير مرخص
//  ← تم حذفها لأن AuthGate بيعمل نفس الوظيفة بشكل أحسن
// ════════════════════════════════════════