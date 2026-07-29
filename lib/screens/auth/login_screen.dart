import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/database.dart';
import '../../core/language_provider.dart';
import '../../core/app_localizations.dart';
import '../doctor/dashboard.dart';
import 'doctor_signup_screen.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class DoctorLoginScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> doctor)? onLogin;
  const DoctorLoginScreen({super.key, this.onLogin});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _rememberMe = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final isRemembered = prefs.getBool('doctor_rememberMe') ?? false;
    if (isRemembered) {
      setState(() {
        _rememberMe = true;
        _identifierController.text =
            prefs.getString('doctor_savedIdentifier') ?? '';
        _passwordController.text =
            prefs.getString('doctor_savedPassword') ?? '';
      });
    }
  }

  Future<void> _handleLogin() async {
    final l = LanguageProvider.of(context).l;
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage =
          l.isArabic ? 'من فضلك ملّي كل الحقول' : 'Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final doctorData = await DatabaseService.loginDoctor(
        usernameOrPhone: identifier,
        password: password,
      );

      if (doctorData == null) {
        setState(() {
          _errorMessage = l.isArabic
              ? 'اسم المستخدم أو الرقم أو كلمة المرور غلط'
              : 'Username, phone or password is incorrect';
          _isLoading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('doctor_rememberMe', _rememberMe);
      if (_rememberMe) {
        await prefs.setString('doctor_savedIdentifier', identifier);
        await prefs.setString('doctor_savedPassword', password);
      } else {
        await prefs.remove('doctor_savedIdentifier');
        await prefs.remove('doctor_savedPassword');
      }

      if (mounted) {
        if (widget.onLogin != null) {
          widget.onLogin!({
            ...doctorData,
            'avatarColor': kOptiBlue.value,
          });
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorDashboard(
                currentDoctor: {
                  ...doctorData,
                  'avatarColor': kOptiBlue.value,
                },
                onLogout: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DoctorLoginScreen()),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = l.isArabic
            ? 'خطأ في الاتصال. تحقق من قاعدة البيانات.'
            : 'Connection error. Check database.';
        _isLoading = false;
      });
    }
  }

  Widget _buildLangButton() {
    return Builder(
      builder: (ctx) {
        final langState = LanguageProvider.of(ctx);
        final isAr = langState.l.isArabic;

        return GestureDetector(
          onTap: () => langState.toggle(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color:
                        !isAr ? Colors.white : Colors.white.withOpacity(0.35),
                    fontSize: 13,
                    fontWeight: !isAr ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Roboto',
                  ),
                  child: const Text('E'),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isAr ? Colors.white : Colors.white.withOpacity(0.35),
                    fontSize: 13,
                    fontWeight: isAr ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Roboto',
                  ),
                  child: const Text('A'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.35,
      decoration: const BoxDecoration(
        color: kOptiBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Transform.scale(
              scale: 1.5,
              child: Image.asset(
                'assets/OptiMed (1).png',
                width: 300,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.medical_services,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: _buildLangButton(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageProvider.of(context).l;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Text(
                    l.isArabic ? 'تسجيل دخول الدكتور' : 'Doctor Login',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kOptiBlue),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    _identifierController,
                    l.isArabic
                        ? 'اسم المستخدم أو رقم الهاتف'
                        : 'Username or Phone',
                    Icons.person,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    _passwordController,
                    l.isArabic ? 'كلمة المرور' : 'Password',
                    Icons.lock,
                    isPass: true,
                  ),
                  _buildRememberMe(l),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 30),
                  _buildLoginButton(l),
                  const SizedBox(height: 25),
                  _buildSignUpLink(l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPass = false,
    TextInputType type = TextInputType.text,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        obscureText: isPass ? _obscurePassword : false,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: kOptiBlue),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: kOptiBlue, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildRememberMe(AppLocalizations l) {
    return CheckboxListTile(
      title: Text(l.isArabic ? 'تذكرني' : 'Remember me'),
      value: _rememberMe,
      onChanged: (v) => setState(() => _rememberMe = v!),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: kOptiBlue,
    );
  }

  Widget _buildLoginButton(AppLocalizations l) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: kOptiBlue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                l.isArabic ? 'دخول النظام' : 'Login to System',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildSignUpLink(AppLocalizations l) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(l.isArabic ? 'مش عندك حساب؟ ' : "Don't have an account? "),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const DoctorSignupScreen()),
            ),
            borderRadius: BorderRadius.circular(4),
            splashColor: kOptiBlue.withOpacity(0.2),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                l.isArabic ? 'إنشاء حساب' : 'Create Account',
                style: const TextStyle(
                  color: kOptiBlue,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}