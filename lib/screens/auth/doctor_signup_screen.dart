import 'package:flutter/material.dart';
import '../../core/database.dart';
import '../../core/language_provider.dart';
import '../../core/app_localizations.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  final TextEditingController _fullNameController  = TextEditingController();
  final TextEditingController _phoneController     = TextEditingController();
  final TextEditingController _usernameController  = TextEditingController();
  final TextEditingController _passwordController  = TextEditingController();
  final TextEditingController _confirmController   = TextEditingController();

  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final l        = LanguageProvider.of(context).l;
    final fullName = _fullNameController.text.trim();
    final phone    = _phoneController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmController.text;

    if (fullName.isEmpty || phone.isEmpty ||
        username.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack(
        l.isArabic ? 'من فضلك ملّي كل الحقول' : 'Please fill all required fields',
        Colors.orange,
      );
      return;
    }
    if (password.length < 6) {
      _showSnack(
        l.isArabic
            ? 'كلمة المرور لازم تكون 6 حروف على الأقل'
            : 'Password must be at least 6 characters',
        Colors.orange,
      );
      return;
    }
    if (password != confirm) {
      _showSnack(
        l.isArabic ? 'كلمات المرور مش متطابقة' : 'Passwords do not match',
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await DatabaseService.registerDoctor(
        username: username,
        password: password,
        fullName: fullName,
        phone:    phone,
      );

      if (!mounted) return;

      if (error != null) {
        _showSnack(error, Colors.red);
        setState(() => _isLoading = false);
      } else {
        _showSnack(
          l.isArabic ? 'تم إنشاء الحساب بنجاح!' : 'Account created successfully!',
          Colors.green,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Connection error: $e', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
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
                    color: !isAr ? Colors.white : Colors.white.withOpacity(0.35),
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

  @override
  Widget build(BuildContext context) {
    final l = LanguageProvider.of(context).l;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(l),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Text(
                    l.isArabic ? 'إنشاء حساب جديد' : 'Create New Account',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: kOptiBlue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  _buildField(
                    _fullNameController,
                    l.isArabic ? 'الاسم الكامل' : 'Full Name',
                    Icons.badge_outlined,
                  ),
                  const SizedBox(height: 15),

                  _buildField(
                    _phoneController,
                    l.isArabic ? 'رقم الهاتف' : 'Phone Number',
                    Icons.phone,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 15),

                  _buildField(
                    _usernameController,
                    l.isArabic ? 'اسم المستخدم' : 'Username',
                    Icons.alternate_email,
                  ),
                  const SizedBox(height: 15),

                  _buildField(
                    _passwordController,
                    l.isArabic ? 'كلمة المرور' : 'Password',
                    Icons.lock_outline,
                    isPass: true,
                    obscure: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 15),

                  _buildField(
                    _confirmController,
                    l.isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password',
                    Icons.lock_reset_rounded,
                    isPass: true,
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 30),

                  _buildSignupButton(l),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l.isArabic
                          ? 'عندك حساب بالفعل؟ سجل دخول'
                          : 'Already have an account? Login',
                      style: const TextStyle(
                          color: kOptiBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.28,
          decoration: const BoxDecoration(
            color: kOptiBlue,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
          child: Center(
            child: Transform.scale(
              scale: 1.5,
              child: Image.asset(
                'assets/OptiMed (1).png',
                width: 300,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.person_add_rounded,
                  size: 70,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            tooltip: l.back,
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: _buildLangButton(),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPass = false,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType type = TextInputType.text,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller:   controller,
        obscureText:  isPass ? obscure : false,
        keyboardType: type,
        decoration: InputDecoration(
          hintText:   hint,
          prefixIcon: Icon(icon, color: kOptiBlue),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
                  onPressed: onToggle,
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: kOptiBlue, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton(AppLocalizations l) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: kOptiBlue,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                l.isArabic ? 'تسجيل' : 'Register',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}