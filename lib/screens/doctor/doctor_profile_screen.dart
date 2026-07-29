// lib/screens/doctor/doctor_profile_screen.dart

import 'package:flutter/material.dart';
import '../../core/database.dart';
import '../../core/language_provider.dart';
import '../../core/app_localizations.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentDoctor;
  final void Function(Map<String, dynamic> updatedDoctor)? onProfileUpdated;

  const DoctorProfileScreen({
    super.key,
    required this.currentDoctor,
    this.onProfileUpdated,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _specializationCtrl;

  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSavingInfo = false;
  bool _isSavingPassword = false;

  AppLocalizations get _l => LanguageProvider.of(context).l;

  @override
  void initState() {
    super.initState();
    final d = widget.currentDoctor;
    _fullNameCtrl =
        TextEditingController(text: d['name'] ?? d['full_name'] ?? '');
    _phoneCtrl = TextEditingController(text: d['phone'] ?? '');
    _usernameCtrl = TextEditingController(text: d['username'] ?? '');
    _specializationCtrl = TextEditingController(
        text: d['specialization'] ?? 'Medical Specialist');
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _specializationCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SAVE INFO
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _saveInfo() async {
    final fullName = _fullNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final specialization = _specializationCtrl.text.trim();

    if (fullName.isEmpty || username.isEmpty) {
      _snack(
        _l.isArabic
            ? 'الاسم الكامل واسم المستخدم مطلوبين'
            : 'Full name and username are required',
        Colors.orange,
      );
      return;
    }

    setState(() => _isSavingInfo = true);

    try {
      final doctorId = widget.currentDoctor['id'];

      final checkUser = await DatabaseService.execute(
        "SELECT id FROM doctors WHERE username = :u AND id != :id LIMIT 1",
        {"u": username, "id": doctorId},
      );
      if (checkUser.rows.isNotEmpty) {
        _snack(
          _l.isArabic
              ? 'اسم المستخدم ده موجود بالفعل'
              : 'Username already taken',
          Colors.red,
        );
        return;
      }

      if (phone.isNotEmpty) {
        final checkPhone = await DatabaseService.execute(
          "SELECT id FROM doctors WHERE phone = :p AND id != :id LIMIT 1",
          {"p": phone, "id": doctorId},
        );
        if (checkPhone.rows.isNotEmpty) {
          _snack(
            _l.isArabic
                ? 'رقم الهاتف ده مسجل بالفعل'
                : 'Phone number already registered',
            Colors.red,
          );
          return;
        }
      }

      await DatabaseService.execute(
        "UPDATE doctors SET full_name = :fn, phone = :ph, username = :u, specialization = :sp WHERE id = :id",
        {
          "fn": fullName,
          "ph": phone,
          "u": username,
          "sp": specialization.isNotEmpty
              ? specialization
              : 'Medical Specialist',
          "id": doctorId,
        },
      );

      widget.onProfileUpdated?.call({
        ...widget.currentDoctor,
        'name': fullName,
        'full_name': fullName,
        'phone': phone,
        'username': username,
        'specialization': specialization,
      });

      _snack(
        _l.isArabic
            ? '✅ تم حفظ البيانات بنجاح'
            : '✅ Profile saved successfully',
        Colors.green,
      );
    } catch (e) {
      _snack(
        _l.isArabic ? 'خطأ في الحفظ: $e' : 'Save error: $e',
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SAVE PASSWORD
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _savePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _snack(
        _l.isArabic
            ? 'من فضلك ملّي كل حقول كلمة المرور'
            : 'Please fill all password fields',
        Colors.orange,
      );
      return;
    }
    if (newPass.length < 6) {
      _snack(
        _l.isArabic
            ? 'كلمة المرور الجديدة لازم تكون 6 أحرف على الأقل'
            : 'New password must be at least 6 characters',
        Colors.orange,
      );
      return;
    }
    if (newPass != confirm) {
      _snack(
        _l.isArabic
            ? 'كلمتا المرور مش متطابقتين'
            : 'Passwords do not match',
        Colors.red,
      );
      return;
    }

    setState(() => _isSavingPassword = true);

    try {
      final doctorId = widget.currentDoctor['id'];
      final hashedCurrent = DatabaseService.hashPassword(current);

      final check = await DatabaseService.execute(
        "SELECT id FROM doctors WHERE id = :id AND password = :p LIMIT 1",
        {"id": doctorId, "p": hashedCurrent},
      );
      if (check.rows.isEmpty) {
        _snack(
          _l.isArabic
              ? 'كلمة المرور الحالية غلط'
              : 'Current password is incorrect',
          Colors.red,
        );
        return;
      }

      await DatabaseService.execute(
        "UPDATE doctors SET password = :p WHERE id = :id",
        {"p": DatabaseService.hashPassword(newPass), "id": doctorId},
      );

      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();

      _snack(
        _l.isArabic
            ? '✅ تم تغيير كلمة المرور بنجاح'
            : '✅ Password changed successfully',
        Colors.green,
      );
    } catch (e) {
      _snack(
        _l.isArabic
            ? 'خطأ في تغيير كلمة المرور: $e'
            : 'Password change error: $e',
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ✅ E • A language toggle
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLangButton() {
    final langState = LanguageProvider.of(context);
    final isAr = langState.l.isArabic;
    return GestureDetector(
      onTap: () => langState.toggle(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: !isAr ? Colors.white : Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: !isAr ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Roboto',
              ),
              child: const Text('E'),
            ),
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isAr ? Colors.white : Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: isAr ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Roboto',
              ),
              child: const Text('A'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l = LanguageProvider.of(context).l;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          _buildHeader(l),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    l.isArabic
                        ? 'البيانات الشخصية'
                        : 'Personal Information',
                    Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(l),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    l.isArabic
                        ? 'تغيير كلمة المرور'
                        : 'Change Password',
                    Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordCard(l),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(AppLocalizations l) {
    final name = _fullNameCtrl.text.isNotEmpty
        ? _fullNameCtrl.text
        : (widget.currentDoctor['username'] ?? 'Doctor');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kOptiBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 4))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
          child: Column(
            children: [
              // ── top row: back + title + lang toggle ──
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      l.isArabic ? 'الملف الشخصي' : 'My Profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // ✅ زرار اللغة E • A
                  _buildLangButton(),
                ],
              ),
              const SizedBox(height: 16),

              // ── avatar ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 50),
              ),
              const SizedBox(height: 12),

              Text(
                name.startsWith('Dr.') ? name : 'Dr. $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.currentDoctor['specialization'] ??
                    'Medical Specialist',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kOptiBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kOptiBlue, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
      ],
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────
  Widget _buildInfoCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildField(
            controller: _fullNameCtrl,
            label: l.isArabic ? 'الاسم الكامل' : 'Full Name',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _phoneCtrl,
            label: l.isArabic ? 'رقم الهاتف' : 'Phone Number',
            icon: Icons.phone_outlined,
            type: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _usernameCtrl,
            label: l.isArabic ? 'اسم المستخدم' : 'Username',
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _specializationCtrl,
            label: l.isArabic ? 'التخصص' : 'Specialization',
            icon: Icons.medical_information_outlined,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSavingInfo ? null : _saveInfo,
              icon: _isSavingInfo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                _isSavingInfo
                    ? (l.isArabic ? 'جاري الحفظ...' : 'Saving...')
                    : (l.isArabic ? 'حفظ البيانات' : 'Save Changes'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kOptiBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Password card ─────────────────────────────────────────────────────────
  Widget _buildPasswordCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildPasswordField(
            controller: _currentPassCtrl,
            label: l.isArabic
                ? 'كلمة المرور الحالية'
                : 'Current Password',
            obscure: _obscureCurrent,
            onToggle: () =>
                setState(() => _obscureCurrent = !_obscureCurrent),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _newPassCtrl,
            label:
                l.isArabic ? 'كلمة المرور الجديدة' : 'New Password',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmPassCtrl,
            label: l.isArabic
                ? 'تأكيد كلمة المرور الجديدة'
                : 'Confirm New Password',
            obscure: _obscureConfirm,
            onToggle: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSavingPassword ? null : _savePassword,
              icon: _isSavingPassword
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded,
                      color: Colors.white),
              label: Text(
                _isSavingPassword
                    ? (l.isArabic ? 'جاري التغيير...' : 'Changing...')
                    : (l.isArabic
                        ? 'تغيير كلمة المرور'
                        : 'Change Password'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D3748),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kOptiBlue, size: 20),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kOptiBlue, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.blueGrey),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: kOptiBlue, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.blueGrey,
                size: 20),
            onPressed: onToggle,
          ),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kOptiBlue, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.blueGrey),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}