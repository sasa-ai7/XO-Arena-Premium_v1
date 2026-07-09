import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/app_ui.dart';

class OnboardingSheet extends StatefulWidget {
  final String initialName;
  final Future<void> Function(String name) onSaveName;
  final VoidCallback onCreateAccount;

  const OnboardingSheet({super.key, 
    required this.initialName,
    required this.onSaveName,
    required this.onCreateAccount,
  });

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  late final TextEditingController _name;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 3 || name.length > 16) {
      setState(() => _error = 'DISPLAY NAME MUST BE 3-16 CHARACTERS.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await widget.onSaveName(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AppGlassCard(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        radius: 28,
        borderColor: AppPalette.homeStroke.withOpacity(0.36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WELCOME TO XO ARENA',
              style: safeOrbitron(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: AppPalette.homeCyan,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You're playing as guest. Set a display name or create an account to save your progress forever.",
              style: homeBodyFont(context, fontSize: 13, color: AppPalette.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ArenaField(
              controller: _name,
              hint: 'DISPLAY NAME (3-16 CHARS)',
              icon: Icons.person_outline,
              keyboardType: TextInputType.text,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: safeOrbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.danger,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppPalette.homeSky, AppPalette.homeBlue],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppPalette.homeStrokeStrong.withOpacity(0.45)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x302EA8FF),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _save,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'SAVE NAME',
                            style: safeOrbitron(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.8,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onCreateAccount();
              },
              child: Text(
                'Create account or sign in',
                style: homeBodyFont(
                  context,
                  fontSize: 13,
                  color: AppPalette.textSubtle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Futuristic mode-transition overlay
// ─────────────────────────────────────────────────────────────────────────────
