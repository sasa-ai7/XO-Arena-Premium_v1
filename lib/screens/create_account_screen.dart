import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';

import '../core/app_config.dart';
import '../core/app_l10n.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/verify_email_resend_controller.dart';
import '../widgets/app_ui.dart';

/// Firebase-powered sign-up screen with Email/Password.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _loading = false;
  bool _privacyConsent = false;
  final _auth = AuthService();

  // Age gate state: null = unanswered, true = Yes (13+), false = No.
  bool? _isAdultConfirmed;

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    final l10n = AppL10n.of(context);

    // Check privacy consent
    if (!_privacyConsent) {
      showTopNotification(context, l10n.acceptPrivacyRequired, color: AppPalette.danger);
      return;
    }

    // Age gate (replaces full DOB collection — policy-safe).
    if (_isAdultConfirmed != true) {
      showTopNotification(context, l10n.ageGateRequired, color: AppPalette.danger);
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _auth.signUpWithEmailPassword(
        _email.text.trim(),
        _pass.text,
        _username.text.trim(),
        isAdultConfirmed: true,
      );
      if (!mounted) return;
      if (user != null) {
        // Check if email is verified (it won't be on first sign-up)
        await user.reload();
        final currentUser = _auth.currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          // Show verification dialog instead of navigating to home
          _showVerificationDialog(currentUser);
        } else {
          // Email already verified (unlikely but possible)
          if (_auth.lastSyncFailed) {
            showTopNotification(context, AppL10n.of(context).failedToSyncProfile, color: AppPalette.warning);
          }
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        showTopNotification(context, AppL10n.of(context).signUpFailed, color: AppPalette.danger);
      }
    } on FirebaseAuthException catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AUTH] SignUp FirebaseAuthException: $e');
        debugPrint('[AUTH] StackTrace: $st');
        debugPrint('[AUTH] code=${e.code} message=${e.message}');
      }
      if (!mounted) return;
      final msg = e.message ?? _authErrorMessage(e.code);
      showTopNotification(context, msg, color: AppPalette.danger);
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AUTH] SignUp FirebaseException: $e');
        debugPrint('[AUTH] StackTrace: $st');
        debugPrint('[AUTH] code=${e.code} message=${e.message}');
      }
      if (!mounted) return;
      final msg = e.code == 'permission-denied'
          ? 'Firestore permissions prevent saving'
          : (e.message ?? AppL10n.of(context).signUpFailed);
      showTopNotification(context, msg, color: AppPalette.danger);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AUTH] SignUp exception: $e');
        debugPrint('[AUTH] StackTrace: $st');
      }
      if (!mounted) return;
      showTopNotification(context, AppL10n.of(context).signUpFailed, color: AppPalette.danger);
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
              Icon(Icons.block, size: 48, color: AppPalette.danger),
              const SizedBox(height: 16),
              Text(
                l10n.ageRestrictionTitle,
                style: titleFont(ctx).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.ageRestrictionMsg,
                style: bodyFont(ctx),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppPillButton(
                label: l10n.ok,
                fill: AppPalette.primary,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerificationDialog(user: user),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        showTopNotification(context, AppL10n.of(context).couldNotOpenPrivacyPolicy, color: AppPalette.danger);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[URL] launch exception: $e');
      }
      if (!mounted) return;
      showTopNotification(context, "Could not open Privacy Policy.", color: AppPalette.danger);
    }
  }

  Future<void> _openGooglePolicies() async {
    final uri = Uri.parse(AppConfig.googlePoliciesUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        showTopNotification(context, AppL10n.of(context).couldNotOpenGooglePolicies, color: AppPalette.danger);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[URL] launch exception: $e');
      }
      if (!mounted) return;
      showTopNotification(context, "Could not open Google Policies.", color: AppPalette.danger);
    }
  }

  String _authErrorMessage(String code) {
    final l10n = AppL10n.of(context);
    switch (code) {
      case 'email-already-in-use':
        return l10n.emailAlreadyInUse;
      case 'invalid-email':
        return l10n.invalidEmailError;
      case 'weak-password':
        return l10n.passwordTooWeak;
      case 'network-request-failed':
        return l10n.internetProblem;
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled. Enable it in Firebase Console.';
      default:
        return l10n.signUpFailed;
    }
  }

  Widget _buildAgeGateRow() {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cake_outlined, size: 16, color: AppPalette.primary),
            const SizedBox(width: 6),
            Text(
              l10n.ageGateQuestion,
              style: sectionFont(context).copyWith(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppPillButton(
                label: l10n.ageGateYes,
                fill: _isAdultConfirmed == true
                    ? AppPalette.success
                    : AppPalette.panelElevated,
                onPressed: () =>
                    setState(() => _isAdultConfirmed = true),
                minHeight: 48,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppPillButton(
                label: l10n.ageGateNo,
                fill: _isAdultConfirmed == false
                    ? AppPalette.danger
                    : AppPalette.panelElevated,
                onPressed: () {
                  setState(() => _isAdultConfirmed = false);
                  _showAgeRestrictionDialog();
                },
                minHeight: 48,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      body: AppBackground(
        variant: AppBackgroundVariant.homeNeon,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    AppIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.gameTitle,
                            style: brandFont(context, fontSize: 24),
                          ),
                          Text(
                            l10n.createAccount,
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
                          AppGlassCard(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                            radius: 28,
                            borderColor: AppPalette.homeStroke.withOpacity(0.34),
                            child: Column(
                              children: [
                                Text(
                                  l10n.forgeYourArenaId,
                                  style: titleFont(context).copyWith(fontSize: 24),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.createAccountDesc,
                                  style: bodyFont(context).copyWith(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _CreateAccountChip(
                                      label: l10n.chipAge13Plus,
                                      icon: Icons.verified_user_outlined,
                                      color: AppPalette.primary,
                                    ),
                                    _CreateAccountChip(
                                      label: l10n.chipEmailVerified,
                                      icon: Icons.mark_email_read_outlined,
                                      color: AppPalette.accentPurple,
                                    ),
                                    _CreateAccountChip(
                                      label: l10n.chipSyncReady,
                                      icon: Icons.cloud_done_outlined,
                                      color: AppPalette.gold,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppGlassCard(
                            padding: const EdgeInsets.all(22),
                            radius: 28,
                            borderColor: AppPalette.homeStroke.withOpacity(0.30),
                            child: Form(
                              key: _form,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.accountDetails, style: sectionFont(context)),
                                  const SizedBox(height: 14),
                                  AuthField(
                                    controller: _username,
                                    hint: l10n.nameHint,
                                    icon: Icons.person_outline,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return AppL10n.of(context).nameRequired;
                                      if (s.length < 3) return AppL10n.of(context).nameTooShort;
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildAgeGateRow(),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    controller: _email,
                                    hint: l10n.emailHint,
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return AppL10n.of(context).emailRequired;
                                      if (!s.contains('@') || !s.contains('.')) return AppL10n.of(context).emailInvalid;
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
                                      if (s.length < 6) return AppL10n.of(context).passwordTooShort;
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ArenaField(
                                    controller: _pass2,
                                    hint: l10n.confirmPasswordHint,
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      if ((v ?? '').isEmpty) return AppL10n.of(context).confirmPasswordRequired;
                                      if (v != _pass.text) return AppL10n.of(context).passwordsDoNotMatch;
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppPalette.panelDeep.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppPalette.homeStroke.withOpacity(0.24),
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      value: _privacyConsent,
                                      onChanged: (value) {
                                        setState(() => _privacyConsent = value ?? false);
                                      },
                                      activeColor: AppPalette.primary,
                                      checkColor: AppPalette.panelDeep,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      title: RichText(
                                        text: TextSpan(
                                          style: bodyFont(context).copyWith(fontSize: 12),
                                          children: [
                                            TextSpan(text: l10n.agreeToPrivacyPrefix),
                                            WidgetSpan(
                                              child: GestureDetector(
                                                onTap: _openPrivacyPolicy,
                                                child: Text(
                                                  l10n.privacyPolicy,
                                                  style: bodyFont(context).copyWith(
                                                    fontSize: 12,
                                                    color: AppPalette.primary,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            TextSpan(text: l10n.agreeToPrivacyAnd),
                                            WidgetSpan(
                                              child: GestureDetector(
                                                onTap: _openGooglePolicies,
                                                child: Text(
                                                  l10n.googlePolicies,
                                                  style: bodyFont(context).copyWith(
                                                    fontSize: 12,
                                                    color: AppPalette.primary,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AppPillButton(
                                    label: l10n.createAccount,
                                    loading: _loading,
                                    onPressed: _loading ? null : _create,
                                    minHeight: 56,
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

class _CreateAccountChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _CreateAccountChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: homeLabelFont(
              context,
              fontSize: 8.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Verification dialog with resend policy, countdown timer, and refresh button.
class _VerificationDialog extends StatefulWidget {
  final User user;

  const _VerificationDialog({required this.user});

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  final VerifyEmailResendController _controller = VerifyEmailResendController();
  final AuthService _authService = AuthService();
  Timer? _countdownTimer;
  bool _isSending = false;
  bool _isRefreshing = false;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    await _checkVerificationStatus();
    _controller.addListener(_onControllerChanged);
    _startCountdownTimer();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        // Check if cooldown/lockout expired
        if (_controller.canSend) {
          // No need to keep timer running if we can send
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    try {
      await widget.user.reload();
      final currentUser = _authService.currentUser;
      if (mounted && (currentUser?.emailVerified ?? false)) {
        setState(() {
          _isEmailVerified = true;
        });
        // Reset controller state when verified
        await _controller.resetOnVerification();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VERIFY] Failed to check verification status: $e');
      }
    }
  }

  Future<void> _handleResend() async {
    if (_isSending || !_controller.canSend) return;

    if (kDebugMode) {
      debugPrint('[VERIFY] [UI] Resend button pressed by user (CreateAccount dialog)');
    }

    setState(() => _isSending = true);

    final result = await _controller.sendVerificationEmailIfAllowed();

    if (!mounted) return;

    setState(() => _isSending = false);

    if (result.success) {
      if (kDebugMode) {
        debugPrint('[VERIFY] [UI] Resend successful (CreateAccount dialog)');
      }
      showTopNotification(
        context,
        AppL10n.of(context).verificationEmailSent,
        color: AppPalette.success,
      );
      _startCountdownTimer(); // Restart timer to show countdown
    } else {
      if (kDebugMode) {
        debugPrint('[VERIFY] [UI] Resend failed: ${result.errorMessage} (CreateAccount dialog)');
      }
      showTopNotification(
        context,
        result.errorMessage ?? AppL10n.of(context).failedToSendVerification,
        color: AppPalette.danger,
      );
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _checkVerificationStatus();
      if (mounted) {
        if (_isEmailVerified) {
          showTopNotification(
            context,
            AppL10n.of(context).emailVerifiedSuccess,
            color: AppPalette.success,
          );
          // Close dialog after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to login screen
            }
          });
        } else {
          showTopNotification(
            context,
            AppL10n.of(context).emailNotVerifiedYet,
            color: AppPalette.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(
          context,
          AppL10n.of(context).failedToRefreshStatus,
          color: AppPalette.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _getResendButtonLabel() {
    final l10n = AppL10n.of(context);

    if (_isSending) return l10n.sending;
    if (_isEmailVerified) return l10n.emailVerified;

    final lockout = _controller.remainingLockout;
    if (lockout != null) {
      final formatted = VerifyEmailResendController.formatRemainingTime(lockout);
      return l10n.tryAgainIn(formatted);
    }

    final cooldown = _controller.remainingCooldown;
    if (cooldown != null) {
      final seconds = cooldown.inSeconds;
      return l10n.resendInSeconds(seconds);
    }

    return l10n.resendEmail;
  }

  bool _isResendButtonDisabled() {
    return _isSending || 
           _isEmailVerified || 
           !_controller.canSend ||
           _controller.remainingCooldown != null ||
           _controller.remainingLockout != null;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AppGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isEmailVerified ? Icons.check_circle : Icons.mark_email_read,
              size: 64,
              color: _isEmailVerified ? AppPalette.success : AppPalette.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _isEmailVerified ? l10n.emailVerified : l10n.verifyEmail,
              style: titleFont(context).copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _isEmailVerified ? l10n.emailVerifiedMsg : l10n.verifyEmailMsg,
              style: bodyFont(context),
              textAlign: TextAlign.center,
            ),
            if (!_isEmailVerified) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppPalette.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.warning.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppPalette.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.checkSpamTip,
                        style: bodyFont(context).copyWith(
                          fontSize: 12,
                          color: AppPalette.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_isEmailVerified) ...[
              SizedBox(
                width: double.infinity,
                child: AppPillButton(
                  label: _isRefreshing ? l10n.checking : l10n.refreshStatus,
                  fill: Colors.white.withOpacity(0.08),
                  stroke: AppPalette.strokeStrong,
                  loading: _isRefreshing,
                  onPressed: _isRefreshing ? null : _handleRefresh,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: AppPillButton(
                label: _getResendButtonLabel(),
                fill: _isEmailVerified
                    ? AppPalette.success.withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                stroke: AppPalette.strokeStrong,
                loading: _isSending,
                onPressed: _isResendButtonDisabled() ? null : _handleResend,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppPillButton(
                label: l10n.goToLogin,
                fill: AppPalette.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
