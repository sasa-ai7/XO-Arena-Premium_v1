import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/keys.dart';
import '../widgets/app_ui.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _enterArena() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Keys.hasSeenWelcomeScreen, true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  Future<void> _goToLogin() async {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bgDepth,
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom -
                    32,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // Animated XO Logo
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (_pulseAnim.value * 0.05),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: XOArenaLogoPainter(animValue: _pulseAnim.value),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Brand name
                  Text(
                    'XO ARENA',
                    style: brandFont(context, fontSize: 30),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  Text(
                    'THE ARENA AWAITS',
                    style: homeLabelFont(
                      context,
                      fontSize: 11,
                      color: AppPalette.homeCyan,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // Feature bullets
                  AppGlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    radius: 24,
                    borderColor: AppPalette.homeStroke.withOpacity(0.30),
                    child: Column(
                      children: [
                        _WelcomeBullet(
                          icon: Icons.flash_on_rounded,
                          color: AppPalette.homeCyan,
                          title: 'QUICK START',
                          body: 'No signup needed. Play in seconds.',
                        ),
                        const SizedBox(height: 16),
                        _WelcomeBullet(
                          icon: Icons.workspace_premium_outlined,
                          color: AppPalette.gold,
                          title: 'FAIR REWARDS',
                          body: 'Earn coins, unlock cosmetics.',
                        ),
                        const SizedBox(height: 16),
                        _WelcomeBullet(
                          icon: Icons.leaderboard_outlined,
                          color: AppPalette.accentPurple,
                          title: 'COMPETITIVE FLOW',
                          body: 'Solo, 1v1, coin battles & more.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // CTA Button — gold gradient
                  _WelcomeCtaButton(onTap: _enterArena),

                  const SizedBox(height: 16),

                  // Sign-in link
                  TextButton(
                    onPressed: _goToLogin,
                    child: Text(
                      'Already have an account?  Sign In',
                      style: safeInter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.textSubtle,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Feature bullet row
// ─────────────────────────────────────────
class _WelcomeBullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _WelcomeBullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.24)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: safeOrbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: homeBodyFont(context, fontSize: 13, color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Gold CTA button
// ─────────────────────────────────────────
class _WelcomeCtaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _WelcomeCtaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.gold, AppPalette.goldDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.goldHighlight.withOpacity(0.40)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50F4C14D),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0x20FFFFFF),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sports_esports_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'ENTER THE ARENA',
                  style: safeOrbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
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
