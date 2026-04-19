import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/app_ui.dart';

/// Complete Profile Screen for first-time Google Sign-In users.
/// Allows users to enter Name, Password, and Age to complete their profile.
class CompleteProfileScreen extends StatefulWidget {
  final User user;

  const CompleteProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _age = TextEditingController();
  bool _loading = false;
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Google account if available
    if (widget.user.displayName != null && widget.user.displayName!.isNotEmpty) {
      _name.text = widget.user.displayName!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _password2.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;

    // Validate age
    final ageStr = _age.text.trim();
    if (ageStr.isEmpty) {
      showTopNotification(context, 'Age is required.', color: AppPalette.danger);
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null || age < 1 || age > 99) {
      showTopNotification(context, 'Please enter a valid age.', color: AppPalette.danger);
      return;
    }

    // COPPA compliance: Block users under 13
    if (age < 13) {
      _showAgeRestrictionDialog();
      return;
    }
    
    setState(() => _loading = true);
    try {
      await _auth.completeGoogleProfile(
        name: _name.text.trim(),
        password: _password.text,
        age: age,
      );
      if (!mounted) return;
      
      if (_auth.lastSyncFailed) {
        showTopNotification(context, 'Profile completed but failed to sync', color: AppPalette.warning);
      } else {
        showTopNotification(context, 'Profile completed successfully!', color: AppPalette.success);
      }
      
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      
      // Improve error messages for common cases
      if (errorMessage.toLowerCase().contains('email must match')) {
        errorMessage = 'Email must match your Google account email.';
      } else if (errorMessage.toLowerCase().contains('already linked')) {
        errorMessage = 'This password is already linked to another account.';
      } else if (errorMessage.toLowerCase().contains('weak-password') || 
                 errorMessage.toLowerCase().contains('password is too weak')) {
        errorMessage = 'Password is too weak. Use at least 6 characters.';
      } else if (errorMessage.toLowerCase().contains('network') || 
                 errorMessage.toLowerCase().contains('internet')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else if (errorMessage.toLowerCase().contains('invalid email') || 
                 errorMessage.toLowerCase().contains('invalid-email')) {
        errorMessage = 'Invalid email address. Please check and try again.';
      }
      
      showTopNotification(context, errorMessage, color: AppPalette.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAgeRestrictionDialog() {
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
              Text(
                'Age Restriction',
                style: titleFont(ctx).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'You are not eligible to use this app.',
                style: bodyFont(ctx),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppPillButton(
                label: 'OK',
                fill: AppPalette.primary,
                onPressed: () {
                  Navigator.pop(ctx);
                  _auth.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          variant: AppBackgroundVariant.homeNeon,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back,
                      onTap: () {
                        // Sign out and go back to login
                        _auth.signOut();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'XO ARENA',
                            style: brandFont(context, fontSize: 24),
                          ),
                          Text(
                            'COMPLETE PROFILE',
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
                                  'Activate Your Arena Profile',
                                  style: titleFont(context).copyWith(fontSize: 24),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Finish setup for your Google sign-in account so your progress, cosmetics, and balance stay linked everywhere.',
                                  style: bodyFont(context).copyWith(fontSize: 14),
                                  textAlign: TextAlign.center,
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
                                  Text('COMPLETE YOUR PROFILE', style: sectionFont(context)),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                          child: const Icon(Icons.email_outlined, color: AppPalette.success),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.success.withOpacity(0.16),
                                                  borderRadius: BorderRadius.circular(999),
                                                  border: Border.all(color: AppPalette.success.withOpacity(0.28)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.verified,
                                                      size: 12,
                                                      color: AppPalette.success,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'VERIFIED GOOGLE EMAIL',
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
                                  AuthField(
                                    controller: _name,
                                    hint: 'Name',
                                    icon: Icons.person_outline,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Name is required';
                                      if (s.length < 3) return 'Name is too short';
                                      if (s.length > 20) return 'Name is too long (max 20 characters)';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'SET PASSWORD',
                                    style: sectionFont(context).copyWith(fontSize: 11),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                                    child: Text(
                                      'Set a password to sign in with email & password.',
                                      style: safeInter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ArenaField(
                                    controller: _password,
                                    hint: 'PASSWORD',
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      final s = v ?? '';
                                      if (s.isEmpty) return 'Password is required';
                                      if (s.length < 6) return 'Password must be at least 6 characters';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ArenaField(
                                    controller: _password2,
                                    hint: 'CONFIRM PASSWORD',
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      if ((v ?? '').isEmpty) return 'Please confirm your password';
                                      if (v != _password.text) return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  AuthField(
                                    controller: _age,
                                    hint: 'Age (Required)',
                                    icon: Icons.cake_outlined,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    maxLength: 2,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Age is required';
                                      final n = int.tryParse(s);
                                      if (n == null || n < 1 || n > 99) {
                                        return 'Enter age between 1 and 99';
                                      }
                                      if (n < 13) {
                                        return 'You are not eligible to use this app.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  AppPillButton(
                                    label: 'COMPLETE PROFILE',
                                    loading: _loading,
                                    onPressed: _loading ? null : _completeProfile,
                                    minHeight: 56,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'This links an email/password login method to your Google account.',
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
