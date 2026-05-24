import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../core/keys.dart';
import '../core/language_switch_dialog.dart';
import '../services/auth_service.dart';
import '../widgets/app_ui.dart';
import 'account_character_select_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _auth = AuthService();

  Timer? _emailSaveDebounce;
  bool _loading = false;
  String? _errorMessage;

  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _checkJustDeletedFlag();
    _loadSavedCredentials();
    _email.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _email.removeListener(_onEmailChanged);
    _emailSaveDebounce?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _setError(String? message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  void _onEmailChanged() {
    _emailSaveDebounce?.cancel();
    _setError(null);
    _emailSaveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _saveEmail();
    });
  }

  Future<void> _loadSavedCredentials() async {
    final p = await SharedPreferences.getInstance();
    final savedEmail = p.getString(Keys.savedEmail);
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _email.text = savedEmail;
    }
  }

  Future<void> _saveEmail() async {
    final email = _email.text.trim();
    if (email.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString(Keys.savedEmail, email);
    }
  }

  Future<void> _checkJustDeletedFlag() async {
    final p = await SharedPreferences.getInstance();
    final justDeleted = p.getBool(Keys.justDeletedAccount) ?? false;
    if (justDeleted) {
      await p.setBool(Keys.justDeletedAccount, false);
      if (kDebugMode) {
        debugPrint('[AUTH] AutoLogin: skipped (manual login required)');
      }
    }
  }

  String _mapAuthError(String raw) {
    final l10n = AppL10n.of(context);
    final lower = raw.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('internet') ||
        lower.contains('socket')) {
      return l10n.networkError;
    }
    if (lower.contains('wrong-password') ||
        lower.contains('incorrect password')) {
      return l10n.incorrectPassword;
    }
    if (lower.contains('user-not-found') ||
        lower.contains('account not found')) {
      return l10n.accountNotFound;
    }
    if (lower.contains('invalid email') || lower.contains('invalid-email')) {
      return l10n.invalidEmailError;
    }
    if (lower.contains('account-exists-with-different-credential') ||
        lower.contains('registered with google')) {
      return l10n.emailUsesGoogle;
    }
    return l10n.loginFailed;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    _setError(null);

    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final user =
          await _auth.signInWithEmailPassword(_email.text.trim(), _pass.text);
      if (!mounted) return;
      if (user != null) {
        await _saveEmail();
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
        return; // widget will be disposed — skip setState
      }
      _setError(AppL10n.of(context).invalidEmailOrPassword);
    } catch (e) {
      if (!mounted) return;
      _setError(_mapAuthError(e.toString()));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    _setError(null);
    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final firestore = FirebaseFirestore.instance;
          final profileDoc =
              await firestore.collection('users').doc(currentUser.uid).get();
          if (!mounted) return;
          final hasProfile = profileDoc.exists && profileDoc.data() != null;
          if (!hasProfile) {
            if (kDebugMode) {
              debugPrint('[AUTH] New Google user detected');
              debugPrint('[AUTH] Opening AccountCharacterSelectScreen');
            }
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) =>
                      AccountCharacterSelectScreen(user: currentUser)),
            );
            return; // widget will be disposed — skip setState
          }
        }
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
        return; // widget will be disposed — skip setState
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _mapAuthError(e.toString());
      if (!msg.toLowerCase().contains('cancel')) {
        _setError(msg);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLanguage() async {
    await confirmAndSwitchLanguage(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isAr = l10n.isAr;
    return Scaffold(
      backgroundColor: AppPalette.bgDepth,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.20,
                  child: CustomPaint(
                    painter: _ArenaGridPainter(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    // Language toggle — pinned top-right
                    Align(
                      alignment: isAr ? Alignment.topLeft : Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                        child: GestureDetector(
                          onTap: _toggleLanguage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppPalette.panelDeep.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppPalette.primary.withOpacity(0.38),
                              ),
                            ),
                            child: Text(
                              isAr ? 'en' : 'ع',
                              style: safeOrbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              children: [
                                // Floating logo + title — no frame, no chips.
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                                  child: Column(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Soft neon glow behind the logo.
                                          Container(
                                            width: 200,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppPalette.primary
                                                      .withOpacity(0.18),
                                                  blurRadius: 80,
                                                  spreadRadius: 20,
                                                ),
                                                BoxShadow(
                                                  color: AppPalette.accentPurple
                                                      .withOpacity(0.12),
                                                  blurRadius: 60,
                                                  spreadRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                          AnimatedBuilder(
                                            animation: _pulseAnim,
                                            builder: (context, child) =>
                                                Transform.scale(
                                              scale: 1.0 +
                                                  (_pulseAnim.value * 0.04),
                                              child: SizedBox(
                                                width: 136,
                                                height: 136,
                                                child: CustomPaint(
                                                  painter: XOArenaLogoPainter(
                                                      animValue:
                                                          _pulseAnim.value),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        l10n.gameTitle,
                                        style: brandFont(context, fontSize: 34),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AppGlassCard(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 22, 20, 24),
                                  radius: 28,
                                  borderColor:
                                      AppPalette.homeStroke.withOpacity(0.30),
                                  child: Column(
                                    children: [
                                      Text(
                                        l10n.signIn,
                                        style: safeOrbitron(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppPalette.homeSky,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildAccountForm(
                                          key: const ValueKey('account')),
                                      const SizedBox(height: 14),
                                      _buildFeedbackBanner(),
                                      const SizedBox(height: 18),
                                      _buildActions(l10n),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountForm({required Key key}) {
    final l10n = AppL10n.of(context);
    return Form(
      key: _form,
      child: Column(
        key: key,
        children: [
          ArenaField(
            controller: _email,
            hint: l10n.emailHint,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return AppL10n.of(context).emailRequired;
              if (!s.contains('@') || !s.contains('.'))
                return AppL10n.of(context).emailInvalid;
              return null;
            },
          ),
          const SizedBox(height: 12),
          ArenaField(
            controller: _pass,
            hint: l10n.passwordHint,
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (v) {
              final s = v ?? '';
              if (s.isEmpty) return AppL10n.of(context).passwordRequired;
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _loading
          ? Container(
              key: const ValueKey('loading-account'),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.homeSky.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppPalette.homeSky.withOpacity(0.24)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppPalette.homeSky),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppL10n.of(context).connectingArenaProfile,
                      style: safeOrbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.homeSky,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Container(
                  key: ValueKey(_errorMessage),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppPalette.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppPalette.danger.withOpacity(0.28)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppPalette.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: safeOrbitron(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.danger,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(key: ValueKey('feedback-empty')),
    );
  }

  Widget _buildActions(AppL10n l10n) {
    return Column(
      children: [
        _ArenaPrimaryButton(
          label: l10n.enterArena,
          icon: Icons.login_rounded,
          loading: _loading,
          onTap: _loading ? null : _login,
        ),
        const SizedBox(height: 12),
        _ArenaGoogleButton(
          label: l10n.continueWithGoogle,
          loading: _loading,
          onTap: _loading ? null : _signInWithGoogle,
        ),
      ],
    );
  }

}

class _ArenaPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _ArenaPrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.homeSky, AppPalette.homeBlue],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppPalette.homeStrokeStrong.withOpacity(0.55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402EA8FF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: const Color(0x20FFFFFF),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: safeOrbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ArenaGoogleButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _ArenaGoogleButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelElevated.withOpacity(0.96),
            AppPalette.panelDeep.withOpacity(0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.homeStroke.withOpacity(0.26)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleIcon(),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: safeOrbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -1.57, 1.25,
        false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -0.30, 1.30,
        false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 1.00, 1.35,
        false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 2.35, 1.35,
        false, paint);

    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
          center.dx + radius * 0.05, center.dy - 1.2, radius * 0.82, 2.4),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArenaGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPalette.primary.withOpacity(0.06)
      ..strokeWidth = 0.5;

    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final accentPaint = Paint()
      ..color = AppPalette.primary.withOpacity(0.16)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(24, 60), const Offset(24, 90), accentPaint);
    canvas.drawLine(const Offset(24, 60), const Offset(54, 60), accentPaint);
    canvas.drawLine(
        Offset(size.width - 24, 60), Offset(size.width - 24, 90), accentPaint);
    canvas.drawLine(
        Offset(size.width - 24, 60), Offset(size.width - 54, 60), accentPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class XOArenaLogoPainter extends CustomPainter {
  final double animValue;

  XOArenaLogoPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(70, 70);
    const radius = 62.0;

    final points = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 6) + (i * math.pi / 3);
      points.add(Offset(center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius));
    }

    final hexPath = Path()..addPolygon(points, true);

    final ringOpacity = animValue * 0.4 + 0.6;

    // Outer glow
    final outerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = AppPalette.primary.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(hexPath, outerGlow);

    // Outer ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppPalette.primary.withOpacity(ringOpacity);
    canvas.drawPath(hexPath, ring);

    // Inner decorative ring (radius 56)
    final innerPoints = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 6) + (i * math.pi / 3);
      innerPoints.add(Offset(
          center.dx + math.cos(angle) * 56, center.dy + math.sin(angle) * 56));
    }
    final innerHexPath = Path()..addPolygon(innerPoints, true);
    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppPalette.accentPurple.withOpacity(0.28);
    canvas.drawPath(innerHexPath, innerRing);

    // Radial inner glow
    final innerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppPalette.gold.withOpacity(0.12),
          AppPalette.gold.withOpacity(0.0)
        ],
      ).createShader(const Rect.fromLTRB(25, 25, 115, 115));
    canvas.drawCircle(center, 45, innerGlow);

    final xBounds =
        Rect.fromCenter(center: const Offset(52, 70), width: 32, height: 32);
    const xPad = 8.0;

    final xGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10
      ..color = AppPalette.primary.withOpacity(0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final xMainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = AppPalette.primary
      ..maskFilter = null;

    final x1 = Offset(xBounds.left + xPad, xBounds.top + xPad);
    final x2 = Offset(xBounds.right - xPad, xBounds.bottom - xPad);
    final x3 = Offset(xBounds.right - xPad, xBounds.top + xPad);
    final x4 = Offset(xBounds.left + xPad, xBounds.bottom - xPad);

    canvas.drawLine(x1, x2, xGlowPaint);
    canvas.drawLine(x3, x4, xGlowPaint);
    canvas.drawLine(x1, x2, xMainPaint);
    canvas.drawLine(x3, x4, xMainPaint);

    // Center divider
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppPalette.strokeStrong.withOpacity(0.55);
    canvas.drawLine(const Offset(70, 56), const Offset(70, 84), divider);

    // O glow
    final oGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.accentPurple.withOpacity(0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(88, 70), 12, oGlow);

    // O main
    canvas.drawCircle(
        const Offset(88, 70),
        12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = AppPalette.accentPurple);

    // 6 dots at hexagon vertices
    final dot = Paint()
      ..color = AppPalette.gold.withOpacity(animValue * 0.5 + 0.5);

    for (final p in points) {
      canvas.drawCircle(p, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant XOArenaLogoPainter oldDelegate) {
    return oldDelegate.animValue != animValue;
  }
}

