import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_ui.dart';
import 'complete_profile_screen.dart';

class AccountCharacterSelectScreen extends StatefulWidget {
  final User user;

  const AccountCharacterSelectScreen({
    super.key,
    required this.user,
  });

  @override
  State<AccountCharacterSelectScreen> createState() =>
      _AccountCharacterSelectScreenState();
}

class _AccountCharacterSelectScreenState
    extends State<AccountCharacterSelectScreen> {
  String? _selectedCharacterType;
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('[ONBOARDING] CharacterSelectionScreen opened');
      debugPrint('[AUTH] Opening CharacterSelectionScreen');
    }
  }

  void _selectCharacter(String type) {
    setState(() => _selectedCharacterType = type);
    if (kDebugMode) {
      debugPrint('[ONBOARDING] Selected characterType=$type');
    }
  }

  void _onNext() {
    if (_selectedCharacterType == null) return;
    if (kDebugMode) {
      debugPrint(
          '[ONBOARDING] Navigating to CompleteProfileScreen with characterType=$_selectedCharacterType');
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(
          user: widget.user,
          characterType: _selectedCharacterType!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isAr = l10n.isAr;

    return Scaffold(
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () {
                        _auth.signOut();
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/login', (r) => false);
                      },
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.gameTitle,
                            style: brandFont(context, fontSize: 24)),
                        Text(
                          l10n.selectCharacter,
                          style: sectionFont(context).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        // Title card
                        AppGlassCard(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                          radius: 28,
                          borderColor: AppPalette.homeStroke.withOpacity(0.34),
                          child: Column(
                            children: [
                              Text(
                                l10n.chooseYourCharacter,
                                style: titleFont(context)
                                    .copyWith(fontSize: 24),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.selectCharacterSubtitle,
                                style: bodyFont(context).copyWith(fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Character cards row
                        Directionality(
                          textDirection: isAr
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Row(
                            children: [
                              Expanded(
                                child: _CharacterCard(
                                  label: l10n.male,
                                  imagePath: 'assets/account/man.png',
                                  isSelected: _selectedCharacterType == 'male',
                                  onTap: () => _selectCharacter('male'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _CharacterCard(
                                  label: l10n.female,
                                  imagePath: 'assets/account/feminine.png',
                                  isSelected:
                                      _selectedCharacterType == 'female',
                                  onTap: () => _selectCharacter('female'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Pinned bottom area ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppPillButton(
                        label: '${l10n.next}  →',
                        onPressed:
                            _selectedCharacterType != null ? _onNext : null,
                        minHeight: 56,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.canChangeCharacterLater,
                        style: bodyFont(context).copyWith(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Redesigned Character Card
// ────────────────────────────────────────────────────────────────────────────
class _CharacterCard extends StatelessWidget {
  final String label;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.label,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppPalette.primary
        : AppPalette.homeStroke.withOpacity(0.22);
    final borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: borderWidth),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.panelElevated.withOpacity(0.97),
              AppPalette.panelDeep.withOpacity(0.97),
            ],
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withOpacity(0.55),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: AppPalette.primary.withOpacity(0.18),
                    blurRadius: 50,
                    spreadRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Character image with seamless bottom fade ──────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppPalette.panelDeep,
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                      // Gradient fade at bottom — blends into card background
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.55, 1.0],
                              colors: [
                                Colors.transparent,
                                AppPalette.panelDeep.withOpacity(0.88),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Dark desaturation overlay for unselected state
                      if (!isSelected)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: 0.48,
                            child: const ColoredBox(color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Character label ────────────────────────────────────────
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: sectionFont(context).copyWith(
                  fontSize: 15,
                  color: isSelected ? AppPalette.primary : Colors.white.withOpacity(0.7),
                  letterSpacing: 2,
                ),
                child: Text(label),
              ),

              const SizedBox(height: 10),

              // ── Selection indicator ────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppPalette.primary
                      : AppPalette.panelElevated,
                  border: Border.all(
                    color: isSelected
                        ? AppPalette.primary
                        : AppPalette.homeStroke.withOpacity(0.35),
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppPalette.primary.withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
