import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_ui.dart';

/// Second onboarding screen for Google Sign-In users.
/// Receives characterType from AccountCharacterSelectScreen.
class CompleteProfileScreen extends StatefulWidget {
  final User user;
  final String characterType;

  const CompleteProfileScreen({
    super.key,
    required this.user,
    required this.characterType,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _loading = false;
  bool _termsAccepted = false;
  final _auth = AuthService();

  // Birth date state
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();

    // Guard: characterType must be set by AccountCharacterSelectScreen.
    if (widget.characterType.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ONBOARDING] ERROR: CompleteProfileScreen opened without characterType — returning');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    if (widget.user.displayName != null &&
        widget.user.displayName!.isNotEmpty) {
      _name.text = widget.user.displayName!;
    }
    if (kDebugMode) {
      debugPrint(
          '[ONBOARDING] CompleteProfileScreen opened with characterType=${widget.characterType}');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  // ── Birth date helpers ───────────────────────────────────────────────────
  DateTime? get _birthDate {
    if (_selectedYear == null || _selectedMonth == null || _selectedDay == null) {
      return null;
    }
    return DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _onYearChanged(int? year) {
    setState(() {
      _selectedYear = year;
      _clampDay();
    });
  }

  void _onMonthChanged(int? month) {
    setState(() {
      _selectedMonth = month;
      _clampDay();
    });
  }

  void _clampDay() {
    if (_selectedYear != null && _selectedMonth != null && _selectedDay != null) {
      final maxDay = _daysInMonth(_selectedYear!, _selectedMonth!);
      if (_selectedDay! > maxDay) _selectedDay = null;
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _completeProfile() async {
    final l10n = AppL10n.of(context);
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    if (_birthDate == null) {
      showTopNotification(context, l10n.selectBirthDate,
          color: AppPalette.danger);
      return;
    }

    final age = _calculateAge(_birthDate!);
    if (kDebugMode) {
      final bd = _birthDate!;
      debugPrint(
          '[ONBOARDING] birthDate=${bd.year.toString().padLeft(4, '0')}-${bd.month.toString().padLeft(2, '0')}-${bd.day.toString().padLeft(2, '0')} age=$age');
    }

    if (age < 13) {
      _showAgeRestrictionDialog();
      return;
    }

    if (!_termsAccepted) {
      showTopNotification(context, l10n.acceptTermsRequired,
          color: AppPalette.danger);
      return;
    }

    setState(() => _loading = true);
    try {
      if (kDebugMode) debugPrint('[ONBOARDING] Creating Google profile...');
      await _auth.completeGoogleProfile(
        name: _name.text.trim(),
        password: _password.text,
        characterType: widget.characterType,
        birthDate: _birthDate!,
        acceptedTerms: _termsAccepted,
      );
      if (!mounted) return;

      final l10n = AppL10n.of(context);
      if (_auth.lastSyncFailed) {
        showTopNotification(context, l10n.profileCompletedFailedSync,
            color: AppPalette.warning);
      } else {
        showTopNotification(context, l10n.profileCompletedSuccess,
            color: AppPalette.success);
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppL10n.of(context);
      String errorMessage = e.toString().replaceAll('Exception: ', '');

      if (errorMessage.toLowerCase().contains('email must match')) {
        errorMessage = l10n.emailMustMatchGoogle;
      } else if (errorMessage.toLowerCase().contains('already linked')) {
        errorMessage = l10n.passwordAlreadyLinked;
      } else if (errorMessage.toLowerCase().contains('weak-password') ||
          errorMessage.toLowerCase().contains('password is too weak')) {
        errorMessage = l10n.passwordTooWeak;
      } else if (errorMessage.toLowerCase().contains('network') ||
          errorMessage.toLowerCase().contains('internet')) {
        errorMessage = l10n.internetProblem;
      } else if (errorMessage.toLowerCase().contains('invalid email') ||
          errorMessage.toLowerCase().contains('invalid-email')) {
        errorMessage = l10n.invalidEmailError;
      } else if (errorMessage.toLowerCase().contains('at least 13')) {
        errorMessage = l10n.ageRestriction13Msg;
      }

      showTopNotification(context, errorMessage, color: AppPalette.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAgeRestrictionDialog() {
    final l10n = AppL10n.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 48, color: AppPalette.danger),
              const SizedBox(height: 16),
              Text(l10n.ageRestrictionTitle,
                  style: titleFont(ctx).copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Text(
                l10n.ageRestrictionMsgAlt,
                style: bodyFont(ctx),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppPillButton(
                label: l10n.ok,
                fill: AppPalette.danger,
                onPressed: () {
                  Navigator.pop(ctx);
                  _auth.signOut();
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Birth date UI builder ────────────────────────────────────────────────
  Widget _buildBirthDateRow() {
    final l10n = AppL10n.of(context);
    final currentYear = DateTime.now().year;
    final years = List.generate(101, (i) => currentYear - i);
    final maxDay = (_selectedYear != null && _selectedMonth != null)
        ? _daysInMonth(_selectedYear!, _selectedMonth!)
        : 31;
    final days = List.generate(maxDay, (i) => i + 1);
    final monthNames = l10n.monthNames;

    final dropdownDecoration = BoxDecoration(
      color: AppPalette.panelDeep.withOpacity(0.9),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: AppPalette.homeStroke.withOpacity(0.35),
        width: 1.2,
      ),
    );

    Widget styledDropdown<T>({
      required String hint,
      required T? value,
      required List<T> items,
      required String Function(T) label,
      required void Function(T?) onChanged,
      int flex = 1,
    }) {
      return Expanded(
        flex: flex,
        child: Container(
          decoration: dropdownDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppPalette.panelDeep,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppPalette.primary, size: 18),
              hint: Text(
                hint,
                style: safeInter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.45),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: safeInter(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map((item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(label(item)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cake_outlined, size: 16, color: AppPalette.primary),
            const SizedBox(width: 6),
            Text(
              l10n.birthDateLabel,
              style: sectionFont(context).copyWith(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            styledDropdown<int>(
              hint: l10n.yearHint,
              value: _selectedYear,
              items: years,
              label: (y) => y.toString(),
              onChanged: _onYearChanged,
              flex: 3,
            ),
            const SizedBox(width: 8),
            styledDropdown<int>(
              hint: l10n.monthHint,
              value: _selectedMonth,
              items: List.generate(12, (i) => i + 1),
              label: (m) => monthNames[m - 1],
              onChanged: _onMonthChanged,
              flex: 3,
            ),
            const SizedBox(width: 8),
            styledDropdown<int>(
              hint: l10n.dayHint,
              value: _selectedDay,
              items: days,
              label: (d) => d.toString().padLeft(2, '0'),
              onChanged: (d) => setState(() => _selectedDay = d),
              flex: 2,
            ),
          ],
        ),
      ],
    );
  }

  // ── Main build ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          variant: AppBackgroundVariant.homeNeon,
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.gameTitle,
                              style: brandFont(context, fontSize: 24)),
                          Text(
                            l10n.completeProfile,
                            style: sectionFont(context).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          // Header card
                          AppGlassCard(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                            radius: 28,
                            borderColor: AppPalette.homeStroke.withOpacity(0.34),
                            child: Column(
                              children: [
                                Text(
                                  l10n.activateArenaProfile,
                                  style: titleFont(context).copyWith(fontSize: 24),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.activateProfileDesc,
                                  style: bodyFont(context).copyWith(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Form card
                          AppGlassCard(
                            padding: const EdgeInsets.all(22),
                            radius: 28,
                            borderColor: AppPalette.homeStroke.withOpacity(0.30),
                            child: Form(
                              key: _form,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.completeYourProfile,
                                      style: sectionFont(context)),
                                  const SizedBox(height: 20),

                                  // Verified email display
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
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
                                      border: Border.all(
                                        color: AppPalette.success.withOpacity(0.42),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppPalette.success.withOpacity(0.12),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.email_outlined,
                                              color: AppPalette.success),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.user.email ?? '',
                                                style: safeInter(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.success.withOpacity(0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                  border: Border.all(
                                                      color: AppPalette.success
                                                          .withOpacity(0.28)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.verified,
                                                        size: 12,
                                                        color: AppPalette.success),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      l10n.verifiedGoogleEmail,
                                                      style: homeLabelFont(
                                                        context,
                                                        fontSize: 8,
                                                        color: AppPalette.success,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Name field
                                  AuthField(
                                    controller: _name,
                                    hint: l10n.nameHint,
                                    icon: Icons.person_outline,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      final l = AppL10n.of(context);
                                      if (s.isEmpty) return l.nameRequired;
                                      if (s.length < 3) return l.nameTooShort;
                                      if (s.length > 20) return l.nameTooLong;
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Birth date
                                  _buildBirthDateRow(),

                                  const SizedBox(height: 16),

                                  // Password section label
                                  Text(
                                    l10n.setPassword,
                                    style: sectionFont(context).copyWith(fontSize: 11),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                                    child: Text(
                                      l10n.setPasswordHint,
                                      style: safeInter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ),

                                  // Password fields
                                  ArenaField(
                                    controller: _password,
                                    hint: l10n.passwordHint,
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      final l = AppL10n.of(context);
                                      final s = v ?? '';
                                      if (s.isEmpty) return l.passwordRequired;
                                      if (s.length < 6) return l.passwordTooShort;
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ArenaField(
                                    controller: _password2,
                                    hint: l10n.confirmPasswordHint,
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      final l = AppL10n.of(context);
                                      if ((v ?? '').isEmpty) return l.confirmPasswordRequired;
                                      if (v != _password.text) return l.passwordsDoNotMatch;
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // Terms & Privacy checkbox
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _termsAccepted = !_termsAccepted),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _termsAccepted,
                                            onChanged: (v) => setState(
                                                () => _termsAccepted = v ?? false),
                                            activeColor: AppPalette.primary,
                                            side: BorderSide(
                                                color: AppPalette.homeStroke
                                                    .withOpacity(0.5)),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            l10n.agreeToTermsAlt,
                                            style: safeInter(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.75),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Submit button
                                  AppPillButton(
                                    label: l10n.createAccount,
                                    loading: _loading,
                                    onPressed: _loading ? null : _completeProfile,
                                    minHeight: 56,
                                  ),

                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.linkingNote,
                                    style: bodyFont(context).copyWith(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.6),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
