import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/language_switch_dialog.dart';
import '../../core/app_theme.dart';
import '../../core/keys.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_store.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../services/user_repo.dart';
import '../../widgets/app_ui.dart';
import '../account_details_screen.dart';
import '../legal/policy_page.dart';
import '../store/store_page.dart';
import '../../utils/navigation_utils.dart';
import 'settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  final bool embedded;
  const SettingsPage({super.key, this.embedded = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  String _username = "PLAYER";
  String _email = "";
  String _provider = "email"; // "email" or "google"
  int _games = 0, _wins = 0, _losses = 0, _draws = 0;
  int _lastLevel = 1;
  bool _editingName = false;
  bool _dangerExpanded = false;
  bool _isMusicEnabled = true;
  double _musicVolume = 0.7;
  bool _notificationsEnabled = false;

  // Username editing
  final TextEditingController _usernameController = TextEditingController();
  late final AnimationController _headerFadeController;
  late final Animation<double> _headerFade;

  // Delete account reason state
  String? _deleteReason;
  String _otherReasonText = "";
  bool _showOtherTextField = false;

  @override
  void initState() {
    super.initState();
    _headerFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _headerFade =
        CurvedAnimation(parent: _headerFadeController, curve: Curves.easeOut);
    _load();
    _headerFadeController.forward();
  }

  @override
  void dispose() {
    _headerFadeController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      try {
        await UserRepo().pullServerToLocal(uid);
        // Load provider from Firestore
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final profile = data['Profile'] as Map<String, dynamic>?;
            if (profile != null) {
              _provider = profile['provider'] as String? ?? 'email';
            }
          }
        }
      } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    // Guard setState with mounted check to prevent "setState called after dispose" crash
    if (!mounted) return;
    setState(() {
      _username = (p.getString(Keys.username) ?? "PLAYER").toUpperCase();
      _email = p.getString(Keys.email) ?? "";
      _games = p.getInt(Keys.gamesPlayed) ?? 0;
      _wins = p.getInt(Keys.wins) ?? 0;
      _losses = p.getInt(Keys.losses) ?? 0;
      _draws = p.getInt(Keys.draws) ?? 0;
      _lastLevel = p.getInt(Keys.levelGameCurrentLevel) ?? 1;
      // If level is 0, show 1 (start level)
      if (_lastLevel == 0) _lastLevel = 1;
      _isMusicEnabled = SoundService().isMusicEnabled;
      _musicVolume = SoundService().musicVolume;
      _notificationsEnabled = p.getBool(Keys.notificationsEnabled) ?? false;
    });
    _usernameController.text = _username;
  }

  // Controls game notifications: the daily 9 PM local play reminder plus real
  // FCM messages (rewards, invites, etc.).
  Future<void> _setDailyRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      final granted =
          await NotificationService().requestNotificationsPermission();
      if (!granted) {
        if (!mounted) return;
        showTopNotification(
            context, AppL10n.of(context).notificationPermissionDenied,
            color: AppPalette.danger);
        return;
      }
      await prefs.setBool(Keys.notificationsEnabled, true);
      // Schedule the local daily 9 PM reminder and register for FCM pushes.
      await NotificationService().scheduleDailyPlayReminder();
      await FcmService.instance.registerToken();
      if (mounted) setState(() => _notificationsEnabled = true);
    } else {
      await prefs.setBool(Keys.notificationsEnabled, false);
      await NotificationService().cancelDailyPlayReminder();
      await FcmService.instance.unregisterToken();
      if (mounted) setState(() => _notificationsEnabled = false);
    }
  }

  Future<void> _saveName() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) {
      showTopNotification(context, AppL10n.of(context).nameCannotBeEmpty,
          color: AppPalette.danger);
      return;
    }
    if (newName.length > 20) {
      showTopNotification(context, AppL10n.of(context).nameTooLong20,
          color: AppPalette.danger);
      return;
    }

    final upperName = newName.toUpperCase();
    final p = await SharedPreferences.getInstance();
    await p.setString(Keys.username, upperName);

    final user = AuthService().currentUser;
    if (user != null) {
      try {
        await user.updateDisplayName(upperName);
        await UserRepo().syncToFirestore(user.uid, {
          'Profile': {
            'name': upperName,
          },
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SETTINGS] Failed to update Firebase name: $e');
        }
        // Non-fatal: local name is saved, continue
      }
    }

    if (!mounted) return;
    setState(() {
      _username = upperName;
      _editingName = false;
    });
    showTopNotification(context, AppL10n.of(context).nameUpdated,
        color: AppPalette.success);
  }

  // Custom profile-photo upload was removed 2026-05-20 — the app now uses
  // the Google Sign-In photoURL exclusively (Firebase Storage was never
  // enabled for this project). See AuthService._syncToLocalStore for the
  // read side, and the helper text under the profile header in build().

  void _showChangePasswordDialog() {
    final l10n = AppL10n.of(context);
    if (_provider == 'google') {
      showTopNotification(context, l10n.googlePasswordNote,
          color: AppPalette.warning);
      return;
    }

    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          final dl10n = AppL10n.of(ctx2);
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dl10n.changePasswordTitle,
                      style: safeOrbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                          letterSpacing: 2),
                    ),
                    const SizedBox(height: 20),
                    ArenaField(
                      controller: currentPassController,
                      hint: dl10n.currentPasswordHint,
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    ArenaField(
                      controller: newPassController,
                      hint: dl10n.newPasswordHint,
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    ArenaField(
                      controller: confirmPassController,
                      hint: dl10n.confirmNewPasswordHint,
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 8),
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x20FF3B30),
                          border: Border.all(color: const Color(0x50FF3B30)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFFF3B30), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: safeInter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B6B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppPillButton(
                            label: dl10n.cancelBtn,
                            fill: const Color(0xFF1A1A1A),
                            onPressed: isLoading
                                ? null
                                : () {
                                    currentPassController.dispose();
                                    newPassController.dispose();
                                    confirmPassController.dispose();
                                    Navigator.pop(ctx);
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppPillButton(
                            label: dl10n.success,
                            loading: isLoading,
                            onPressed: () async {
                              final current = currentPassController.text;
                              final newPass = newPassController.text;
                              final confirm = confirmPassController.text;

                              if (current.isEmpty ||
                                  newPass.isEmpty ||
                                  confirm.isEmpty) {
                                setDialogState(() =>
                                    errorMessage = dl10n.passwordRequired);
                                return;
                              }
                              if (newPass.length < 6) {
                                setDialogState(() =>
                                    errorMessage = dl10n.passwordTooShort);
                                return;
                              }
                              if (newPass != confirm) {
                                setDialogState(() =>
                                    errorMessage = dl10n.passwordsDoNotMatch);
                                return;
                              }
                              if (current == newPass) {
                                setDialogState(
                                    () => errorMessage = dl10n.passwordTooWeak);
                                return;
                              }

                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null || user.email == null) {
                                  throw Exception('No user found.');
                                }

                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: current,
                                );

                                await user
                                    .reauthenticateWithCredential(credential);
                                await user.updatePassword(newPass);

                                if (!ctx.mounted || !mounted) return;
                                currentPassController.dispose();
                                newPassController.dispose();
                                confirmPassController.dispose();
                                Navigator.pop(ctx);
                                showTopNotification(context, l10n.success,
                                    color: AppPalette.success);
                              } on FirebaseAuthException catch (e) {
                                String msg;
                                switch (e.code) {
                                  case 'wrong-password':
                                  case 'invalid-credential':
                                    msg = l10n.incorrectPassword;
                                    break;
                                  case 'weak-password':
                                    msg = l10n.passwordTooWeak;
                                    break;
                                  case 'requires-recent-login':
                                    msg = l10n.loginFailed;
                                    break;
                                  case 'network-request-failed':
                                    msg = l10n.networkError;
                                    break;
                                  default:
                                    msg = 'Failed: ${e.message ?? e.code}';
                                }
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = msg;
                                });
                              } catch (_) {
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = l10n.loginFailed;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout, size: 48, color: AppPalette.warning),
                const SizedBox(height: 16),
                Text(
                  "Sign Out",
                  style: titleFont(ctx).copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "End this arena session on this device? Your synced progress will stay on your account.",
                  style: bodyFont(ctx),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: "STAY",
                        fill: Colors.white.withValues(alpha: 0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: "SIGN OUT",
                        fill: AppPalette.danger,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    // Check online status before logging out
    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      if (!mounted) return;
      showTopNotification(
        context,
        "You're offline. Please connect to the internet to log out.",
        color: AppPalette.danger,
      );
      return;
    }

    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (kDebugMode) {
          debugPrint('[URL] Failed to open $url');
        }
        if (!mounted) return;
        showTopNotification(context, AppL10n.of(context).couldNotOpenLink,
            color: AppPalette.danger);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[URL] launch exception: $e');
      }
      if (!mounted) return;
      showTopNotification(context, AppL10n.of(context).couldNotOpenLink,
          color: AppPalette.danger);
    }
  }

  Future<void> _contactSupport() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppL10n.of(ctx).contactSupportTitle,
                    style: titleFont(ctx).copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  AppConfig.refundRulesText,
                  style: bodyFont(ctx),
                ),
                const SizedBox(height: 8),
                Text(
                  "Contact: ${AppConfig.refundEmail}",
                  style: bodyFont(ctx).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                AppPillButton(
                  label: AppL10n.of(ctx).sendEmailBtn,
                  fill: Colors.white.withValues(alpha: 0.08),
                  stroke: AppPalette.strokeStrong,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri(
                      scheme: "mailto",
                      path: AppConfig.refundEmail,
                      queryParameters: {
                        "subject": "XO Arena Support / Refund",
                        "body":
                            "Describe your issue here.\n\nAccount email: $_email\nDevice: Android\n",
                      },
                    );
                    if (!await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                      if (!mounted) return;
                      showTopNotification(
                          context, AppL10n.of(context).mailNotAvailable,
                          color: AppPalette.danger);
                    }
                  },
                ),
                const SizedBox(height: 8),
                AppPillButton(
                  label: AppL10n.of(context).ok,
                  fill: Colors.white.withValues(alpha: 0.06),
                  stroke: AppPalette.strokeStrong,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    if (!mounted) return;

    // Reset state
    _deleteReason = null;
    _otherReasonText = "";
    _showOtherTextField = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          final dl10n = AppL10n.of(ctx2);
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppGlassCard(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dl10n.deleteAccountTitle,
                          style: titleFont(ctx2).copyWith(fontSize: 18)),
                      const SizedBox(height: 10),
                      Text(
                        dl10n.deleteAccountWarning,
                        style: bodyFont(ctx2),
                      ),
                      const SizedBox(height: 16),
                      // Reason selection
                      Text(dl10n.deleteAccountReasonPrompt,
                          style: sectionFont(ctx2)),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title:
                            Text(dl10n.dontUseAnymore, style: bodyFont(ctx2)),
                        value: "I don't use the app anymore",
                        groupValue: _deleteReason,
                        onChanged: (value) {
                          setDialogState(() {
                            _deleteReason = value;
                            _showOtherTextField = false;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dl10n.foundBetterAlternative,
                            style: bodyFont(ctx2)),
                        value: "I found a better alternative",
                        groupValue: _deleteReason,
                        onChanged: (value) {
                          setDialogState(() {
                            _deleteReason = value;
                            _showOtherTextField = false;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dl10n.tooBuggy, style: bodyFont(ctx2)),
                        value: "Too many bugs or crashes",
                        groupValue: _deleteReason,
                        onChanged: (value) {
                          setDialogState(() {
                            _deleteReason = value;
                            _showOtherTextField = false;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dl10n.privacyConcernsReason,
                            style: bodyFont(ctx2)),
                        value: "Privacy concerns",
                        groupValue: _deleteReason,
                        onChanged: (value) {
                          setDialogState(() {
                            _deleteReason = value;
                            _showOtherTextField = false;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dl10n.wantFresh, style: bodyFont(ctx2)),
                        value: "I want to start fresh",
                        groupValue: _deleteReason,
                        onChanged: (value) {
                          setDialogState(() {
                            _deleteReason = value;
                            _showOtherTextField = false;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(dl10n.otherReason, style: bodyFont(ctx2)),
                        value: "Other",
                        groupValue: _deleteReason,
                        onChanged: (value) {
                          setDialogState(() {
                            _deleteReason = value;
                            _showOtherTextField = true;
                          });
                        },
                      ),
                      // Other reason text field
                      if (_showOtherTextField) ...[
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: dl10n.deleteReasonHint,
                            hintStyle: bodyFont(ctx2)
                                .copyWith(color: AppPalette.textMuted),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppPalette.radiusSmall),
                              borderSide: BorderSide(color: AppPalette.stroke),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppPalette.radiusSmall),
                              borderSide: BorderSide(color: AppPalette.stroke),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppPalette.radiusSmall),
                              borderSide: BorderSide(color: AppPalette.primary),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                          ),
                          style: bodyFont(ctx2),
                          maxLines: 3,
                          onChanged: (value) {
                            _otherReasonText = value;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppPillButton(
                        label: dl10n.confirmDelete,
                        fill: AppPalette.danger.withValues(alpha: 0.90),
                        onPressed: () {
                          // Validation
                          if (_deleteReason == null) {
                            showTopNotification(
                                ctx2, dl10n.deleteAccountReasonPrompt,
                                color: AppPalette.danger);
                            return;
                          }
                          if (_deleteReason == "Other" &&
                              _otherReasonText.trim().isEmpty) {
                            showTopNotification(ctx2, dl10n.deleteReasonHint,
                                color: AppPalette.danger);
                            return;
                          }

                          Navigator.pop(ctx);
                          final details = _deleteReason == "Other"
                              ? _otherReasonText.trim()
                              : null;
                          _deleteAccount(
                              reason: _deleteReason!, details: details);
                        },
                        icon: Icons.delete_forever,
                      ),
                      const SizedBox(height: 8),
                      AppPillButton(
                        label: dl10n.cancelBtn,
                        fill: Colors.white.withValues(alpha: 0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Check if deletion is locked
  Future<bool> _isDeletionLocked() async {
    final p = await SharedPreferences.getInstance();
    final lockedUntil = p.getInt(Keys.deleteLockedUntil);
    if (lockedUntil == null) return false;

    final lockedUntilDate = DateTime.fromMillisecondsSinceEpoch(lockedUntil);
    if (DateTime.now().isBefore(lockedUntilDate)) {
      return true; // Still locked
    } else {
      // Lock expired - reset
      await p.remove(Keys.deleteLockedUntil);
      await p.setInt(Keys.deleteAttempts, 0);
      await p.remove(Keys.deleteLastAttempt);
      return false;
    }
  }

  // Get lock message
  Future<String?> _getLockMessage() async {
    final p = await SharedPreferences.getInstance();
    final lockedUntil = p.getInt(Keys.deleteLockedUntil);
    if (lockedUntil == null) return null;

    final lockedUntilDate = DateTime.fromMillisecondsSinceEpoch(lockedUntil);
    if (DateTime.now().isBefore(lockedUntilDate)) {
      final remaining = lockedUntilDate.difference(DateTime.now());
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      return "Account deletion is locked. Please try again after ${hours}h ${minutes}m";
    }
    return null;
  }

  // Increment failed attempts
  Future<void> _incrementDeleteAttempts() async {
    final p = await SharedPreferences.getInstance();
    final attempts = (p.getInt(Keys.deleteAttempts) ?? 0) + 1;
    await p.setInt(Keys.deleteAttempts, attempts);
    await p.setInt(
        Keys.deleteLastAttempt, DateTime.now().millisecondsSinceEpoch);

    if (attempts >= 3) {
      // Lock for 24 hours
      final lockedUntil = DateTime.now().add(const Duration(hours: 24));
      await p.setInt(
          Keys.deleteLockedUntil, lockedUntil.millisecondsSinceEpoch);
    }
  }

  // Reset delete attempts (on success)
  Future<void> _resetDeleteAttempts() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(Keys.deleteAttempts, 0);
    await p.remove(Keys.deleteLastAttempt);
    await p.remove(Keys.deleteLockedUntil);
  }

  Future<void> _deleteAccount({required String reason, String? details}) async {
    if (!mounted) return;

    // Check if deletion is locked
    if (await _isDeletionLocked()) {
      final lockMessage = await _getLockMessage();
      if (!mounted) return;
      if (lockMessage != null) {
        showTopNotification(context, lockMessage, color: AppPalette.danger);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Detect linked providers to route reauth correctly.
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final hasPassword = providers.contains('password');
    final hasGoogle = providers.contains('google.com');

    if (kDebugMode) {
      debugPrint('[DELETE] providerData=${providers.join(',')}');
      debugPrint('[DELETE] hasPassword=$hasPassword hasGoogle=$hasGoogle');
    }

    if (hasGoogle && !hasPassword) {
      // Google-only account — reauthenticate via Google, never ask for password.
      await _deleteAccountWithGoogle(reason: reason, details: details);
    } else {
      // Email/password account (or both) — request password first.
      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) return;
      await _deleteAccountWithPassword(
          reason: reason, details: details, password: password);
    }
  }

  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: AppPalette.warning),
                  const SizedBox(height: 16),
                  Text(
                    "Confirm Password",
                    style: safeOrbitron(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "For security, please enter your password to confirm account deletion.",
                    textAlign: TextAlign.center,
                    style: bodyFont(ctx).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  ArenaField(
                    controller: passwordController,
                    hint: 'PASSWORD',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppPillButton(
                          label: AppL10n.of(context).cancelBtn,
                          fill: Colors.white.withValues(alpha: 0.08),
                          stroke: AppPalette.strokeStrong,
                          onPressed: () => Navigator.pop(ctx, null),
                          icon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppPillButton(
                          label: "CONFIRM",
                          fill: AppPalette.danger.withValues(alpha: 0.9),
                          onPressed: () {
                            Navigator.pop(ctx, passwordController.text);
                          },
                          icon: Icons.check,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccountWithPassword({
    required String reason,
    String? details,
    required String password,
  }) async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint(
          '[DELETE] reason=$reason${details != null ? ", details=$details" : ""}');
    }

    final isOnline = await ConnectivityService().online;
    if (!mounted) return;
    if (!isOnline) {
      showTopNotification(
          context, "Please connect to the internet to delete your account.",
          color: AppPalette.danger);
      return;
    }

    // Save deletion reason feedback (NON-FATAL) — must include uid for Firestore rule.
    final userForFeedback = FirebaseAuth.instance.currentUser;
    final uid = userForFeedback?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('deletion_feedback')
            .doc(uid)
            .set({
          'uid': uid,
          'email': userForFeedback?.email ?? '',
          'reason': reason,
          'details': details ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (kDebugMode) {
          debugPrint('[DELETE] deletion_feedback saved');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DELETE] deletion_feedback failed non-fatal: $e');
        }
      }
    }

    // Show loading dialog with purge message
    _showDeletionLoadingDialog();

    try {
      await AuthService().deleteAccountAndData(password: password);

      await _resetDeleteAttempts();

      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      showTopNotification(
          context, AppL10n.of(context).accountDeletedSuccessfully,
          color: AppPalette.success);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on RequiresReauthException {
      // Firestore data already wiped — need re-auth to delete Auth account
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      await _handleReauthForDeletion();
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();

      String errorMessage;
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }

      if (errorMessage.contains('Incorrect password') ||
          errorMessage.contains('wrong-password') ||
          errorMessage.contains('invalid-credential')) {
        await _incrementDeleteAttempts();

        if (await _isDeletionLocked()) {
          final lockMessage = await _getLockMessage();
          errorMessage = lockMessage ??
              "Too many failed attempts. Account deletion is locked for 24 hours.";
        } else {
          final p = await SharedPreferences.getInstance();
          final attempts = p.getInt(Keys.deleteAttempts) ?? 0;
          final remaining = 3 - attempts;
          errorMessage = "Incorrect password. $remaining attempts remaining.";
        }
      } else if (errorMessage.contains('internet') ||
          errorMessage.contains('network') ||
          errorMessage.contains('connect to the internet')) {
        errorMessage = "Please check your internet connection and try again.";
      } else if (errorMessage.contains('Firestore') ||
          errorMessage.contains('Permission denied') ||
          errorMessage.contains('deletion failed')) {
        errorMessage =
            "Could not delete account data. Please contact support if this persists.";
      } else {
        errorMessage = "Could not delete account. Please try again.";
      }

      if (!mounted) return;
      showTopNotification(context, errorMessage, color: AppPalette.danger);
    }
  }

  /// Delete account for Google-only users: reauthenticates via Google then runs
  /// the full deletion cycle. No password is ever requested.
  Future<void> _deleteAccountWithGoogle({
    required String reason,
    String? details,
  }) async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint(
          '[DELETE] reason=$reason${details != null ? ", details=$details" : ""} (Google flow)');
    }

    final isOnline = await ConnectivityService().online;
    if (!mounted) return;
    if (!isOnline) {
      showTopNotification(
          context, 'Please connect to the internet to delete your account.',
          color: AppPalette.danger);
      return;
    }

    // Save deletion feedback BEFORE reauthenticating — user is still signed in.
    final userForFeedback = FirebaseAuth.instance.currentUser;
    final uid = userForFeedback?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('deletion_feedback')
            .doc(uid)
            .set({
          'uid': uid,
          'email': userForFeedback?.email ?? '',
          'reason': reason,
          'details': details ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (kDebugMode) debugPrint('[DELETE] deletion_feedback saved');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[DELETE] deletion_feedback failed non-fatal: $e');
        }
      }
    }

    // Reauthenticate with Google.
    if (kDebugMode) debugPrint('[DELETE] Starting reauthentication (Google)');
    try {
      await AuthService().reauthenticateWithGoogle();
      if (kDebugMode) debugPrint('[DELETE] Google reauthentication success');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase().contains('cancel')
          ? 'Google sign-in was cancelled.'
          : 'Google re-authentication failed. Please try again.';
      showTopNotification(context, msg, color: AppPalette.danger);
      return;
    }

    // Run full deletion cycle — reauth already done, pass no password.
    _showDeletionLoadingDialog();
    try {
      await AuthService().deleteAccountAndData();
      await _resetDeleteAttempts();

      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      showTopNotification(
          context, AppL10n.of(context).accountDeletedSuccessfully,
          color: AppPalette.success);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on RequiresReauthException {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      await _handleReauthForDeletion();
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      final errorMessage = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      showTopNotification(context, errorMessage, color: AppPalette.danger);
    }
  }

  void _showDeletionLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  "Wiping all your data from our servers...",
                  textAlign: TextAlign.center,
                  style: bodyFont(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle re-authentication when Firebase Auth requires recent login.
  Future<void> _handleReauthForDeletion() async {
    if (!mounted) return;

    final user = AuthService().currentUser;
    if (user == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security, size: 48, color: AppPalette.warning),
                const SizedBox(height: 16),
                Text(
                  "Security Check",
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please log in one last time to confirm account deletion.",
                  textAlign: TextAlign.center,
                  style: bodyFont(ctx).copyWith(height: 1.3),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        label: AppL10n.of(context).cancelBtn,
                        fill: Colors.white.withValues(alpha: 0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: isGoogle ? "SIGN IN" : "CONFIRM",
                        fill: AppPalette.danger.withValues(alpha: 0.9),
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: isGoogle ? Icons.account_circle : Icons.check,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (isGoogle) {
        await AuthService().reauthenticateWithGoogle();
      } else {
        final password = await _showPasswordDialog();
        if (password == null || password.isEmpty) return;
        await AuthService().reauthenticateWithPassword(password);
      }

      _showDeletionLoadingDialog();
      await AuthService().deleteAuthOnly();
      await _resetDeleteAttempts();

      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      showTopNotification(
          context, AppL10n.of(context).accountDeletedSuccessfully,
          color: AppPalette.success);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      showTopNotification(context, AppL10n.of(context).reauthFailedRetry,
          color: AppPalette.danger);
    }
  }

  Widget _sectionHeader(String text) {
    return Row(
      children: [
        Text(
          text,
          style: safeOrbitron(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppPalette.goldHighlight,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppPalette.strokeSoft)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollContent = Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Column(
          children: [
            FadeTransition(
              opacity: _headerFade,
              child: ProfileHeader(
                username: _username,
                email: _email,
                provider: _provider,
                games: _games,
                wins: _wins,
                losses: _losses,
                draws: _draws,
                topLevel: _lastLevel,
                editingName: _editingName,
                usernameController: _usernameController,
                // No camera tap: profile photo is synced from Google
                // Sign-In (2026-05). The helper text below explains it.
                onEditName: () => setState(() => _editingName = true),
                onCancelEdit: () {
                  _usernameController.text = _username;
                  setState(() => _editingName = false);
                },
                onSaveName: _saveName,
              ),
            ),
            const SizedBox(height: 8),
            // Muted helper line so users understand why no edit button is
            // visible — the photo is taken from their Google account.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppL10n.of(context).profilePhotoFromGoogle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.textMuted.withValues(alpha: 0.85),
                  fontSize: 11,
                  height: 1.4,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded,
                          color: AppPalette.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(AppL10n.of(context).musicLabel,
                          style: safeOrbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.goldHighlight,
                              letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.music_note_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(AppL10n.of(context).musicLabel,
                                    style: safeOrbitron(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                const Spacer(),
                                Switch(
                                  value: _isMusicEnabled,
                                  activeColor: AppPalette.primary,
                                  onChanged: (val) async {
                                    setState(() => _isMusicEnabled = val);
                                    await SoundService().setMusicEnabled(val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isMusicEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.volume_down,
                            color: Color(0xFF888888), size: 14),
                        Expanded(
                          child: SliderTheme(
                            data: const SliderThemeData(
                              activeTrackColor: AppPalette.primary,
                              inactiveTrackColor: AppPalette.strokeSoft,
                              thumbColor: AppPalette.goldHighlight,
                              overlayColor: Color(0x2058D8FF),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _musicVolume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) async {
                                setState(() => _musicVolume = val);
                                await SoundService().setMusicVolume(val);
                              },
                            ),
                          ),
                        ),
                        const Icon(Icons.volume_up,
                            color: Color(0xFF888888), size: 14),
                        const SizedBox(width: 4),
                        Text('${(_musicVolume * 100).toInt()}%',
                            style: safeOrbitron(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.goldHighlight)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── NOTIFICATIONS SECTION ────────────────────────────────────
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: AppPalette.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(AppL10n.of(context).dailyRemindersLabel,
                          style: safeOrbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.goldHighlight,
                              letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          AppL10n.of(context)
                                              .dailyRemindersLabel,
                                          style: safeOrbitron(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                      const SizedBox(height: 2),
                                      Text(
                                          AppL10n.of(context)
                                              .dailyRemindersSubtitle,
                                          style: safeInter(
                                              fontSize: 11,
                                              color: Colors.white
                                                  .withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _notificationsEnabled,
                                  activeColor: AppPalette.primary,
                                  onChanged: (val) =>
                                      _setDailyRemindersEnabled(val),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── LANGUAGE SECTION ─────────────────────────────────────────
            ValueListenableBuilder<Locale>(
              valueListenable: LocalStore.localeNotifier,
              builder: (ctx, locale, __) {
                final isAr = locale.languageCode == 'ar';
                return AppGlassCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: AppPalette.strokeSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(AppL10n.of(ctx).language),
                      const SizedBox(height: 10),
                      SettingTile(
                        icon: Icons.language_outlined,
                        label: AppL10n.of(ctx).currentLanguageLabel,
                        subtitle: AppL10n.of(ctx).switchToLabel,
                        onTap: () => confirmAndSwitchLanguage(ctx),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    AppPalette.primary.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            isAr ? 'en' : 'ع',
                            style: safeOrbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(AppL10n.of(context).accountSection),
                  const SizedBox(height: 10),
                  SettingTile(
                    icon: Icons.manage_accounts_outlined,
                    label: AppL10n.of(context).accountDetailsRow,
                    subtitle: AppL10n.of(context).accountDetailsSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountDetailsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.lock_outline,
                    label: AppL10n.of(context).changePassword,
                    subtitle: AppL10n.of(context).changePasswordSubtitle,
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppGlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: AppPalette.strokeSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(AppL10n.of(context).supportAndLegal),
                  const SizedBox(height: 10),
                  SettingTile(
                    icon: Icons.support_agent_outlined,
                    label: AppL10n.of(context).contactSupportRow,
                    subtitle: AppL10n.of(context).contactSupportSubtitle,
                    onTap: _contactSupport,
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.link_rounded,
                    label: AppL10n.of(context).contactLinkLabel,
                    subtitle: AppL10n.of(context).contactLinkSubtitle,
                    onTap: () => _openUrl(AppConfig.contactUrl),
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.privacy_tip_outlined,
                    label: AppL10n.of(context).privacyPolicyRow,
                    subtitle: AppL10n.of(context).privacyPolicySubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PolicyPage.privacy()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.description_outlined,
                    label: AppL10n.of(context).termsOfService,
                    subtitle: AppL10n.of(context).termsOfServiceSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PolicyPage.terms()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.delete_forever_outlined,
                    label: AppL10n.of(context).accountDeletionInfo,
                    subtitle: AppL10n.of(context).accountDeletionInfoSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PolicyPage.accountDeletion()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DangerZoneCard(
              expanded: _dangerExpanded,
              onToggle: () =>
                  setState(() => _dangerExpanded = !_dangerExpanded),
              onDelete: _showDeleteAccountConfirmation,
            ),
            const SizedBox(height: 24),
            PremiumLogoutCard(onTap: _showLogoutConfirmDialog),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Column(children: [scrollContent]);
    }

    return Scaffold(
      body: SafeArea(
        child: AppBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final coinWidth = clampDouble(
                      constraints.maxWidth * 0.34,
                      128.0,
                      156.0,
                    );
                    final titleWidth = max(
                      0.0,
                      constraints.maxWidth - coinWidth - 66.0,
                    );
                    // Shared coin pill — same widget as Home/Missions/Online
                    // so the balance display is visually identical everywhere
                    // instead of the old two-line "BALANCE" block.
                    final coinWidget = SizedBox(
                      width: coinWidth,
                      child: ArenaCoinBalance(
                        compact: true,
                        minWidth: coinWidth,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StorePage(initialTab: 2),
                            ),
                          );
                        },
                      ),
                    );

                    if (constraints.maxWidth < 360) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppIconButton(
                                icon: Icons.arrow_back,
                                onTap: () => navigateToHomeHub(context),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: max(0.0, constraints.maxWidth - 56.0),
                                child: Text(
                                  "SETTINGS",
                                  style:
                                      titleFont(context).copyWith(fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          coinWidget,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => navigateToHomeHub(context),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: titleWidth,
                          child: Text(
                            "SETTINGS",
                            style: titleFont(context).copyWith(fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        coinWidget,
                      ],
                    );
                  },
                ),
              ),
              scrollContent,
            ],
          ),
        ),
      ),
    );
  }
}
