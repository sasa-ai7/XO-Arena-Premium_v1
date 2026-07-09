import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../core/keys.dart';
import '../core/language_switch_dialog.dart';
import '../services/auth_service.dart';
import '../services/local_store.dart';
import '../utils/navigation_utils.dart';
import '../widgets/app_ui.dart';
import 'account_character_select_screen.dart';
import 'offline_player_setup_screen.dart';

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

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

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

  /// Continue without signing in. Uses the existing local OfflinePlayerProfile
  /// if present (→ Home), otherwise opens the one-page offline setup. No
  /// Firebase account is created and signInAnonymously is never called.
  Future<void> _continueAsGuest() async {
    final profile = await LocalStore.getOfflineProfile();
    if (!mounted) return;
    if (profile != null) {
      LocalStore.offlineAvatarAssetNotifier.value = profile.avatarAssetPath;
      navigateToHomeHub(context);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OfflinePlayerSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isAr = l10n.isAr;
    final media = MediaQuery.of(context);
    // Large, crisp logo anchored in the upper-middle zone. Scales with screen
    // width and clamps so it stays dominant yet never overlaps the card on
    // small phones.
    final logoHeight =
        (media.size.width * 0.66).clamp(190.0, 260.0).toDouble();

    return Scaffold(
      backgroundColor: AppPalette.bgDepth,
      body: AuthImageBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // Language switch — fixed-height top row so toggling it never
                // shifts the logo / login panel below.
                Align(
                  alignment: isAr ? Alignment.topLeft : Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _LangSquareButton(
                      label: isAr ? 'EN' : 'ع',
                      onTap: _toggleLanguage,
                    ),
                  ),
                ),
                // Logo + login panel scroll together as one stable unit and
                // stay vertically centered, so nothing jumps on language switch
                // or when the keyboard opens.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 32,
                          ),
                          child: Column(
                            // Logo sits in the upper-middle, the compact card in
                            // the lower half; spaceBetween keeps them balanced.
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                    top: constraints.maxHeight * 0.06),
                                child: ArenaLogo(height: logoHeight),
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: constraints.maxHeight * 0.03),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 480),
                                  child: _LoginGlassPanel(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          l10n.signIn,
                                          textAlign: TextAlign.center,
                                          style: safeOrbitron(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: AppPalette.homeSky,
                                            letterSpacing: 4,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildAccountForm(
                                            key: const ValueKey('account')),
                                        const SizedBox(height: 10),
                                        _buildFeedbackBanner(),
                                        const SizedBox(height: 14),
                                        _buildActions(l10n),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
            margin: EdgeInsets.zero,
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
            margin: EdgeInsets.zero,
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
              margin: EdgeInsets.zero,
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
                  margin: EdgeInsets.zero,
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
        const SizedBox(height: 12),
        _ArenaGuestButton(
          label: l10n.continueAsGuest,
          onTap: _loading ? null : _continueAsGuest,
        ),
      ],
    );
  }

}

/// Large square glass language-switch button for the top corner. Shares the
/// same glass / blur / neon-border language as the login card so it reads as an
/// intentional premium control rather than a tiny hidden icon.
class _LangSquareButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LangSquareButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Solid semi-opaque glass (no BackdropFilter) — one fewer expensive
    // backdrop pass on the auth screen.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelElevated.withOpacity(0.82),
            AppPalette.panelDeep.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.homeSky.withOpacity(0.45),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.homeSky.withOpacity(0.18),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.language,
                    size: 18, color: AppPalette.primary),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: safeOrbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primary,
                    letterSpacing: 1.0,
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

/// Secondary "Continue as Guest" button — an outlined ghost control so it reads
/// as clearly optional next to the primary ENTER ARENA / Google actions.
class _ArenaGuestButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ArenaGuestButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppPalette.homeStroke.withOpacity(0.45),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppPalette.homeSky),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: safeOrbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.homeSky,
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

/// Light frosted-glass login panel. Deliberately NOT a heavy dark box — a very
/// subtle backdrop blur plus a translucent light→dark gradient (max ~0.30
/// opacity) let the XO-BACK.png artwork stay visible through it, so the panel
/// reads as part of the same scene rather than a separate solid block.
class _LoginGlassPanel extends StatelessWidget {
  final Widget child;

  const _LoginGlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        // Lighter blur — cleaner glassmorphism, cheaper GPU pass.
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                AppPalette.bgDepth.withOpacity(0.24),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            // Subtle neon-sky border glow to match the XO Arena atmosphere.
            border: Border.all(
              color: AppPalette.homeSky.withOpacity(0.32),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppPalette.homeSky.withOpacity(0.16),
                blurRadius: 26,
                spreadRadius: -6,
              ),
              BoxShadow(
                color: AppPalette.accentPurple.withOpacity(0.08),
                blurRadius: 30,
                spreadRadius: -10,
              ),
            ],
          ),
          child: child,
        ),
      ),
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
      margin: EdgeInsets.zero,
      height: 58,
      decoration: BoxDecoration(
        // Vivid cyan→blue gradient — the clear primary action.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.homeCyan,
            AppPalette.homeSky,
            AppPalette.homeBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppPalette.homeStrokeStrong.withOpacity(0.60)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.homeSky.withOpacity(0.45),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppPalette.homeBlue.withOpacity(0.30),
            blurRadius: 30,
            spreadRadius: -4,
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
      margin: EdgeInsets.zero,
      height: 52,
      decoration: BoxDecoration(
        // Understated dark glass so it stays clearly secondary to ENTER ARENA.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelElevated.withOpacity(0.72),
            AppPalette.panelDeep.withOpacity(0.68),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.homeStroke.withOpacity(0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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

