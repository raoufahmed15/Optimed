// ════════════════════════════════════════════════════════════════════════════
//  AuthGate — wraps any app with online device authentication
//  Place at: lib/core/auth_gate.dart
//
//  Usage in main():
//    home: AuthGate(appId: 'nurse_app', child: const AuthWrapper()),
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'online_auth_service.dart';

// ─── AuthGate ─────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  final String appId;
  final Widget child;
  final Color accentColor;

  const AuthGate({
    super.key,
    required this.appId,
    required this.child,
    this.accentColor = const Color(0xFF0055CC),
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with SingleTickerProviderStateMixin {
  _GatePhase _phase = _GatePhase.loading;
  AuthResult? _result;
  String _macAddress = '';

  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _runAuth();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _runAuth() async {
    // Small delay so the loading screen renders first
    await Future.delayed(const Duration(milliseconds: 400));

    final mac = await OnlineAuthService.getMacAddress();
    if (mounted) setState(() => _macAddress = mac);

    final result = await OnlineAuthService.validate(widget.appId);

    if (!mounted) return;
    setState(() {
      _result = result;
      _phase = result.isAllowed ? _GatePhase.allowed : _GatePhase.denied;
    });

    // If allowed, brief success flash then proceed
    if (result.isAllowed) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _phase = _GatePhase.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _GatePhase.done) return widget.child;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: _phase == _GatePhase.loading
            ? _LoadingView(
                accentColor: widget.accentColor,
                pulseAnim: _pulseAnim,
                mac: _macAddress,
              )
            : _phase == _GatePhase.allowed
                ? _SuccessFlash(accentColor: widget.accentColor)
                : _DeniedView(
                    result: _result!,
                    mac: _macAddress,
                    accentColor: widget.accentColor,
                  ),
      ),
    );
  }
}

enum _GatePhase { loading, allowed, denied, done }

// ─── Loading View ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final Color accentColor;
  final Animation<double> pulseAnim;
  final String mac;

  const _LoadingView({
    required this.accentColor,
    required this.pulseAnim,
    required this.mac,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing lock icon
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Opacity(
              opacity: pulseAnim.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                  color: accentColor.withOpacity(0.08),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 52,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'جارٍ التحقق من الجهاز',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'يرجى الانتظار...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 3,
            ),
          ),
          if (mac.isNotEmpty) ...[
            const SizedBox(height: 32),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mac,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Success Flash ────────────────────────────────────────────────────────────
class _SuccessFlash extends StatelessWidget {
  final Color accentColor;
  const _SuccessFlash({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade700.withOpacity(0.15),
              border: Border.all(color: Colors.green.shade500, width: 2),
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                size: 52, color: Colors.green.shade400),
          ),
          const SizedBox(height: 24),
          const Text(
            'تم التحقق بنجاح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Denied View ──────────────────────────────────────────────────────────────
class _DeniedView extends StatelessWidget {
  final AuthResult result;
  final String mac;
  final Color accentColor;

  const _DeniedView({
    required this.result,
    required this.mac,
    required this.accentColor,
  });

  String get _titleText {
    switch (result.status) {
      case AuthStatus.notFound:
        return 'جهاز غير مسجل';
      case AuthStatus.blocked:
        return 'تم حظر هذا الجهاز';
      case AuthStatus.offline:
        return 'لا يوجد اتصال';
      default:
        return 'خطأ في التحقق';
    }
  }

  IconData get _icon {
    switch (result.status) {
      case AuthStatus.blocked:
        return Icons.block_rounded;
      case AuthStatus.offline:
        return Icons.wifi_off_rounded;
      default:
        return Icons.no_accounts_rounded;
    }
  }

  Color get _iconColor {
    switch (result.status) {
      case AuthStatus.offline:
        return Colors.orange.shade400;
      default:
        return Colors.red.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _iconColor.withOpacity(0.1),
              border: Border.all(color: _iconColor.withOpacity(0.6), width: 2),
            ),
            child: Icon(_icon, size: 52, color: _iconColor),
          ),
          const SizedBox(height: 28),

          // Title
          Text(
            _titleText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),

          // Message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Text(
              result.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(height: 36),

          // MAC display
          if (mac.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(children: [
                Text(
                  'كود الجهاز',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  mac,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: mac)),
                  icon: const Icon(Icons.copy_rounded,
                      size: 14, color: Colors.white38),
                  label: Text(
                    'نسخ',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontFamily: 'Cairo'),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 24),

          // Contact box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.red.shade800.withOpacity(0.3)),
            ),
            child: Column(children: [
              Text(
                'للتفعيل يرجى التواصل مع',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'OPTIMED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 12),
              _phoneRow('01062015096'),
              const SizedBox(height: 8),
              _phoneRow('01006947262'),
            ]),
          ),

          // Close button (optional)
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: Text(
              'إغلاق البرنامج',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneRow(String number) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.phone_rounded, color: Colors.red.shade400, size: 15),
        const SizedBox(width: 8),
        SelectableText(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}