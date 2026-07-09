import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../core/keys.dart';
import '../services/local_store.dart';
import '../utils/navigation_utils.dart';
import '../widgets/app_ui.dart';

/// First-launch, offline-first player setup.
///
/// A single page that collects a local player name and a character type
/// (boy/girl → stored as 'male'/'female'), creates a local
/// [OfflinePlayerProfile] via [LocalStore.createOfflineProfile], and enters
/// the Home hub. No email, no password, no Firebase Auth — the game is
/// playable offline; sign-in is optional and only needed later for online /
/// store features.
class OfflinePlayerSetupScreen extends StatefulWidget {
  const OfflinePlayerSetupScreen({super.key});

  @override
  State<OfflinePlayerSetupScreen> createState() =>
      _OfflinePlayerSetupScreenState();
}

class _OfflinePlayerSetupScreenState extends State<OfflinePlayerSetupScreen> {
  static const int _maxNameLength = 16;

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  /// 'male' | 'female' — null until the user picks a card.
  String? _selectedType;

  /// True once the name field has been focused, so we only surface the
  /// validation message after the user has interacted with it.
  bool _nameTouched = false;

  /// Guards against double taps while the profile is being created.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onChanged);
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus && !_nameTouched) {
        setState(() => _nameTouched = true);
      }
    });
    _prefillFromLegacyGuest();
  }

  /// Migration: a legacy guest (old onboarding) may have a saved [Keys.guestName]
  /// but no full offline profile / character. Pre-fill that name so the player
  /// only needs to pick a character to complete their OfflinePlayerProfile.
  Future<void> _prefillFromLegacyGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = (prefs.getString(Keys.guestName) ??
            prefs.getString(Keys.username) ??
            '')
        .trim();
    if (!mounted || legacy.isEmpty || _nameController.text.isNotEmpty) return;
    _nameController.text =
        legacy.length > _maxNameLength ? legacy.substring(0, _maxNameLength) : legacy;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String get _trimmedName => _nameController.text.trim();
  bool get _isNameValid => _trimmedName.isNotEmpty;
  bool get _canStart => _isNameValid && _selectedType != null && !_busy;

  void _selectCharacter(String type) {
    setState(() => _selectedType = type);
  }

  Future<void> _onStart() async {
    if (!_canStart) return;
    setState(() => _busy = true);

    final name = _trimmedName;
    final type = _selectedType!;

    try {
      // Create the isolated, local-only offline profile (name + character).
      // This sets Keys.offlineProfileExists=true so startup skips this screen
      // on future launches. No Firebase, no signInAnonymously.
      final profile = await LocalStore.createOfflineProfile(
        name: name,
        characterType: type,
      );

      // Mirror the name into the legacy guest key and mark the in-home
      // onboarding prompt as done so Home never re-asks for a name.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(Keys.guestName, name);
      await prefs.setBool(Keys.hasCompletedFirstEntry, true);

      // Drive the Home avatar to the chosen boy/girl portrait immediately.
      LocalStore.offlineAvatarAssetNotifier.value = profile.avatarAssetPath;

      if (!mounted) return;
      navigateToHomeHub(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final showNameError = _nameTouched && !_isNameValid;

    // This is the first required local setup — Android back must not escape
    // to login/welcome/intro. Block the pop; the user completes setup or
    // leaves the app via the OS.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppPalette.bgDepth,
        body: AuthImageBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                      maxWidth: 560,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Branded XO Arena logo ──────────────────────────
                        const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: Center(child: ArenaLogo(height: 132)),
                        ),
                        // ── Title ──────────────────────────────────────────
                        Text(
                          l10n.offlineSetupTitle,
                          style: titleFont(context).copyWith(fontSize: 26),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.offlineSetupSubtitle,
                          style: bodyFont(context).copyWith(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.66),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // ── Setup card ─────────────────────────────────────
                        AppGlassCard(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                          radius: 26,
                          borderColor:
                              AppPalette.homeStroke.withValues(alpha: 0.34),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Name label
                              Text(
                                l10n.playerNameLabel,
                                style: sectionFont(context).copyWith(
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Name field
                              TextField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                maxLength: _maxNameLength,
                                textInputAction: TextInputAction.done,
                                textCapitalization:
                                    TextCapitalization.words,
                                onSubmitted: (_) {
                                  if (_canStart) _onStart();
                                },
                                style: bodyFont(context)
                                    .copyWith(fontSize: 16, color: Colors.white),
                                cursorColor: AppPalette.primary,
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: l10n.playerNameHint,
                                  hintStyle: bodyFont(context).copyWith(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: AppPalette.primary,
                                  ),
                                  filled: true,
                                  fillColor:
                                      AppPalette.panelDeep.withValues(alpha: 0.6),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: showNameError
                                          ? AppPalette.warning
                                              .withValues(alpha: 0.8)
                                          : AppPalette.homeStroke
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: showNameError
                                          ? AppPalette.warning
                                          : AppPalette.primary,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),

                              // Validation message
                              AnimatedSize(
                                duration: const Duration(milliseconds: 160),
                                child: showNameError
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8, left: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                size: 15,
                                                color: AppPalette.warning),
                                            const SizedBox(width: 6),
                                            Text(
                                              l10n.playerNameRequired,
                                              style: bodyFont(context).copyWith(
                                                fontSize: 12,
                                                color: AppPalette.warning,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 20),

                              // Character label
                              Text(
                                l10n.chooseYourCharacter.toUpperCase(),
                                style: sectionFont(context).copyWith(
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Character cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _SetupCharacterCard(
                                      label: l10n.boy,
                                      imagePath: 'assets/account/man.png',
                                      isSelected: _selectedType == 'male',
                                      onTap: () => _selectCharacter('male'),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _SetupCharacterCard(
                                      label: l10n.girl,
                                      imagePath: 'assets/account/feminine.png',
                                      isSelected: _selectedType == 'female',
                                      onTap: () => _selectCharacter('female'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Start button (self-disables when onPressed null) ─
                        AppPillButton(
                          label: l10n.startPlaying,
                          minHeight: 56,
                          onPressed: _canStart ? _onStart : null,
                          loading: _busy,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Selectable boy/girl card — glows when selected, dims when not.
// Mirrors the style of _CharacterCard in account_character_select_screen.dart.
// ────────────────────────────────────────────────────────────────────────────
class _SetupCharacterCard extends StatelessWidget {
  final String label;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const _SetupCharacterCard({
    required this.label,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppPalette.primary
        : AppPalette.homeStroke.withValues(alpha: 0.22);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.panelElevated.withValues(alpha: 0.97),
              AppPalette.panelDeep.withValues(alpha: 0.97),
            ],
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.5),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ]
              : const [],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppPalette.panelDeep,
                          child: const Icon(Icons.person,
                              size: 72, color: AppPalette.primary),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.55, 1.0],
                              colors: [
                                Colors.transparent,
                                AppPalette.panelDeep.withValues(alpha: 0.88),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isSelected)
                        const Positioned.fill(
                          child: Opacity(
                            opacity: 0.46,
                            child: ColoredBox(color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: sectionFont(context).copyWith(
                  fontSize: 14,
                  letterSpacing: 2,
                  color: isSelected
                      ? AppPalette.primary
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppPalette.primary
                      : AppPalette.panelElevated,
                  border: Border.all(
                    color: isSelected
                        ? AppPalette.primary
                        : AppPalette.homeStroke.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
