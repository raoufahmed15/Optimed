// lib/core/language_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
//  Global language state — wrap MaterialApp with LanguageProvider
//  Access anywhere: LanguageProvider.of(context).language
//  Toggle:          LanguageProvider.of(context).toggle()
//  Listen:          LanguageProvider.of(context).addListener(fn)  ← جديد
//  ⚠️ لا يغير اتجاه الصفحة — اللغة بس تتغير
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

const String _kLangKey = 'app_language';

class LanguageProvider extends StatefulWidget {
  final Widget child;
  const LanguageProvider({super.key, required this.child});

  static LanguageProviderState of(BuildContext context) {
    final _LanguageInherited? inherited =
        context.dependOnInheritedWidgetOfExactType<_LanguageInherited>();
    assert(inherited != null, 'No LanguageProvider found in widget tree');
    return inherited!.state;
  }

  @override
  State<LanguageProvider> createState() => LanguageProviderState();
}

// ✅ الاسم الموحّد — يُستخدم في Login / Signup / Dashboard كلهم
class LanguageProviderState extends State<LanguageProvider> {
  AppLanguage _language = AppLanguage.english;

  // ✅ listeners — أي صفحة تقدر تشترك وتاخد إشعار لما اللغة تتغير
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final fn in List<VoidCallback>.from(_listeners)) {
      fn();
    }
  }

  AppLanguage get language => _language;
  AppLocalizations get l => AppLocalizations(_language);
  bool get isArabic => _language == AppLanguage.arabic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    if (mounted && saved != null) {
      setState(() {
        _language =
            saved == 'arabic' ? AppLanguage.arabic : AppLanguage.english;
      });
    }
  }

  Future<void> toggle() async {
    final next = _language == AppLanguage.english
        ? AppLanguage.arabic
        : AppLanguage.english;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLangKey, next == AppLanguage.arabic ? 'arabic' : 'english');
    if (mounted) {
      setState(() => _language = next);
      _notifyListeners(); // ✅ أخبر كل الصفحات المشتركة
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLangKey, lang == AppLanguage.arabic ? 'arabic' : 'english');
    if (mounted) {
      setState(() => _language = lang);
      _notifyListeners(); // ✅ أخبر كل الصفحات المشتركة
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LanguageInherited(
      state: this,
      language: _language,
      child: widget.child,
    );
  }
}

// ✅ للتوافق مع أي كود قديم بيستخدم LanguageState
typedef LanguageState = LanguageProviderState;

class _LanguageInherited extends InheritedWidget {
  final LanguageProviderState state;
  final AppLanguage language;

  const _LanguageInherited({
    required this.state,
    required this.language,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LanguageInherited old) =>
      old.language != language;
}