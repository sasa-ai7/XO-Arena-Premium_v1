import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/app_l10n.dart';
import '../../core/language_switch_dialog.dart';
import '../../core/app_theme.dart';
import '../../core/coin_format.dart';
import '../../core/keys.dart';
import '../../core/responsive_metrics.dart';
import '../../models/game_avatar.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/local_store.dart';
import '../../services/sound_service.dart';
import '../../services/user_repo.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/full_avatar_display.dart';
import '../account_details_screen.dart';
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
  int _coins = 0;
  int _lastLevel = 1;
  int _completions = 0;
  int _equippedAvatar = 0;
  bool _editingName = false;
  bool _dangerExpanded = false;
  bool _isMusicEnabled = true;
  // Re-entrancy guard for the avatar image picker. Tapping the change-avatar
  // button while a picker is already open used to crash with
  // PlatformException(already_active). We refuse the second call and log it.
  bool _isPickingImage = false;
  double _musicVolume = 0.7;

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
      _coins = p.getInt(Keys.coins) ?? 0;
      _lastLevel = p.getInt(Keys.levelGameCurrentLevel) ?? 1;
      // If level is 0, show 1 (start level)
      if (_lastLevel == 0) _lastLevel = 1;
      _completions = p.getInt(Keys.levelGameCompletions) ?? 0;
      _equippedAvatar = LocalStore.equippedAvatarNotifier.value;
      _isMusicEnabled = SoundService().isMusicEnabled;
      _musicVolume = SoundService().musicVolume;
    });
    _usernameController.text = _username;
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

    setState(() {
      _username = upperName;
      _editingName = false;
    });
    showTopNotification(context, AppL10n.of(context).nameUpdated, color: AppPalette.success);
  }

  Future<void> _showAvatarOptions() async {
    // Re-entrancy guard: image_picker's native plugin throws
    // PlatformException(already_active, ...) if pickImage is called while
    // another picker is still open. Bail out cleanly on the second tap.
    if (_isPickingImage) {
      if (kDebugMode) debugPrint('[IMAGE_PICKER] already picking ignored');
      return;
    }
    _isPickingImage = true;
    if (kDebugMode) debugPrint('[IMAGE_PICKER] started');

    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      // already_active can still race in if the native plugin has a stale
      // session; surface it gracefully instead of crashing.
      if (kDebugMode) {
        debugPrint('[IMAGE_PICKER] PlatformException: ${e.code} ${e.message}');
      }
      _isPickingImage = false;
      if (!mounted) return;
      final l10n = AppL10n.of(context);
      final msg = e.code == 'already_active'
          ? l10n.imagePickerAlreadyOpen
          : (e.code == 'photo_access_denied' || e.code == 'camera_access_denied')
              ? l10n.permissionDenied
              : l10n.uploadFailed;
      showTopNotification(context, msg, color: AppPalette.warning);
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('[IMAGE_PICKER] error: $e');
      _isPickingImage = false;
      return;
    }

    if (picked == null) {
      if (kDebugMode) debugPrint('[IMAGE_PICKER] cancelled');
      _isPickingImage = false;
      return;
    }
    if (!mounted) {
      _isPickingImage = false;
      return;
    }
    // Release the guard before any further async work — the picker itself
    // is closed at this point, so re-opening from a retry button is fine.
    _isPickingImage = false;
    if (kDebugMode) debugPrint('[IMAGE_PICKER] finished');

    final file = File(picked.path);
    
    // Validate file size (max 5MB)
    final fileSizeInBytes = await file.length();
    const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
    if (fileSizeInBytes > maxSizeInBytes) {
      if (!mounted) return;
      showTopNotification(context, AppL10n.of(context).imageTooLarge,
        color: AppPalette.danger);
      return;
    }
    
    // Save locally first
    await LocalStore.setProfilePhotoPath(file.path);

    // Check connectivity before uploading
    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      if (!mounted) return;
      showTopNotification(context, AppL10n.of(context).noInternetPhotoSaved,
        color: AppPalette.warning);
      if (mounted) setState(() => _equippedAvatar = LocalStore.equippedAvatarNotifier.value);
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppGlassCard(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  AppL10n.of(context).uploadingPhoto,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Upload to Firebase Storage if user is signed in
    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user != null) {
        // Stable path — overwrite on each update so old files don't accumulate.
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${user.uid}/profile.jpg');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uid': user.uid,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
        final task = await ref.putFile(file, metadata);
        final url = await task.ref.getDownloadURL();
        await LocalStore.setProfilePhotoUrl(url);
        await user.updatePhotoURL(url);
        await UserRepo().syncToFirestore(user.uid, {
          'Profile': {'photoURL': url}
        });
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success
      if (mounted) {
        showTopNotification(context, AppL10n.of(context).photoUpdated,
          color: AppPalette.success);
        setState(() => _equippedAvatar = LocalStore.equippedAvatarNotifier.value);
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) debugPrint('[PHOTO] Firebase Storage error: code=${e.code} msg=${e.message}');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      String userMsg;
      final l10n = AppL10n.of(context);
      if (e.code == 'storage/unauthorized' || e.code == 'unauthorized') {
        userMsg = l10n.uploadNotAllowed;
      } else if (e.code == 'storage/object-not-found' || e.code == 'object-not-found') {
        userMsg = 'Storage bucket not found. Please enable Firebase Storage in the console.';
      } else {
        userMsg = l10n.uploadFailedCode(e.code);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMsg),
          backgroundColor: AppPalette.danger,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _showAvatarOptions(),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PHOTO] Upload failed: $e');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).uploadFailed),
          backgroundColor: AppPalette.danger,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _showAvatarOptions(),
          ),
        ),
      );
    }
  }

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
                                setDialogState(() => errorMessage =
                                    dl10n.passwordTooWeak);
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

                                if (!ctx.mounted) return;
                                currentPassController.dispose();
                                newPassController.dispose();
                                confirmPassController.dispose();
                                Navigator.pop(ctx);
                                showTopNotification(
                                    context, l10n.success,
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
                        fill: Colors.white.withOpacity(0.08),
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

    await UserRepo().clearLocalCache();
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
      showTopNotification(context, "Could not open link.",
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
                Text("Contact Support / Refunds",
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
                  label: "Send email",
                  fill: Colors.white.withOpacity(0.08),
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
                      showTopNotification(context, AppL10n.of(context).mailNotAvailable,
                          color: AppPalette.danger);
                    }
                  },
                ),
                const SizedBox(height: 8),
                AppPillButton(
                  label: AppL10n.of(context).ok,
                  fill: Colors.white.withOpacity(0.06),
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
                        title: Text(dl10n.dontUseAnymore,
                            style: bodyFont(ctx2)),
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
                              borderSide:
                                  BorderSide(color: AppPalette.primary),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
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
                        fill: AppPalette.danger.withOpacity(0.90),
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
                            showTopNotification(
                                ctx2, dl10n.deleteReasonHint,
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
                        fill: Colors.white.withOpacity(0.08),
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
                          fill: Colors.white.withOpacity(0.08),
                          stroke: AppPalette.strokeStrong,
                          onPressed: () => Navigator.pop(ctx, null),
                          icon: Icons.close,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppPillButton(
                          label: "CONFIRM",
                          fill: AppPalette.danger.withOpacity(0.9),
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

      showTopNotification(context, AppL10n.of(context).accountDeletedSuccessfully,
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
        if (kDebugMode) debugPrint('[DELETE] deletion_feedback failed non-fatal: $e');
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
      showTopNotification(context, AppL10n.of(context).accountDeletedSuccessfully,
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
                        fill: Colors.white.withOpacity(0.08),
                        stroke: AppPalette.strokeStrong,
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: Icons.close,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPillButton(
                        label: isGoogle ? "SIGN IN" : "CONFIRM",
                        fill: AppPalette.danger.withOpacity(0.9),
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
      showTopNotification(context, AppL10n.of(context).accountDeletedSuccessfully,
          color: AppPalette.success);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      showTopNotification(
          context, "Re-authentication failed. Please try again.",
          color: AppPalette.danger);
    }
  }

  void _showPolicies() {
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
                Text("PRIVACY & TERMS",
                    style: titleFont(ctx).copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  "We store: name + email + (age optional) + stats + coins + transactions\n\n"
                  "No cash-out, no real rewards, and no money transfers\n\n"
                  "Coins are for in-game use only\n\n"
                  "Any purchases, if offered, are processed through the platform's official billing system.\n\n"
                  "There is a Delete Account option in Settings, which permanently deletes the data\n\n"
                  "Contact: ${AppConfig.supportEmail}",
                  style: bodyFont(ctx),
                ),
                const SizedBox(height: 16),
                // Privacy Policy link
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppPalette.primary),
                  title: Text("Privacy Policy",
                      style:
                          bodyFont(ctx).copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: AppPalette.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConfig.privacyPolicyUrl);
                  },
                ),
                // Terms link
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: const Icon(Icons.description_outlined,
                      color: AppPalette.primary),
                  title: Text("Terms",
                      style:
                          bodyFont(ctx).copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: AppPalette.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConfig.termsUrl);
                  },
                ),
                // Delete Account Info link
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppPalette.danger),
                  title: Text("Delete Account Info",
                      style:
                          bodyFont(ctx).copyWith(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18, color: AppPalette.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConfig.accountDeletionUrl);
                  },
                ),
                const SizedBox(height: 14),
                AppPillButton(
                  label: AppL10n.of(context).ok,
                  fill: Colors.white.withOpacity(0.08),
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
              child: ValueListenableBuilder<int>(
                valueListenable: LocalStore.equippedAvatarNotifier,
                builder: (_, avatarId, __) {
                  // Nullable resolver: 0 / unknown → no paid frame.
                  final avatar = gameAvatarByIdOrNull(avatarId);
                  return ProfileHeader(
                    username: _username,
                    email: _email,
                    provider: _provider,
                    games: _games,
                    wins: _wins,
                    losses: _losses,
                    draws: _draws,
                    topLevel: _lastLevel,
                    avatar: avatar,
                    editingName: _editingName,
                    usernameController: _usernameController,
                    onCameraTap: _showAvatarOptions,
                    onEditName: () => setState(() => _editingName = true),
                    onCancelEdit: () {
                      _usernameController.text = _username;
                      setState(() => _editingName = false);
                    },
                    onSaveName: _saveName,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppPalette.primary.withOpacity(0.35)),
                          ),
                          child: Text(
                            isAr ? 'EN' : 'عر',
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
                    icon: Icons.privacy_tip_outlined,
                    label: AppL10n.of(context).privacyPolicyRow,
                    subtitle: AppL10n.of(context).privacyPolicySubtitle,
                    onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.description_outlined,
                    label: AppL10n.of(context).termsOfService,
                    subtitle: AppL10n.of(context).termsOfServiceSubtitle,
                    onTap: () => _openUrl(AppConfig.termsUrl),
                  ),
                  const SizedBox(height: 8),
                  SettingTile(
                    icon: Icons.delete_forever_outlined,
                    label: AppL10n.of(context).accountDeletionInfo,
                    subtitle: AppL10n.of(context).accountDeletionInfoSubtitle,
                    onTap: () => _openUrl(AppConfig.accountDeletionUrl),
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
                    final coinWidget = GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StorePage(initialTab: 2),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: coinWidth,
                        child: ValueListenableBuilder<int>(
                          valueListenable: LocalStore.coinsNotifier,
                          builder: (_, coins, __) => CoinPill(
                            coins: coins,
                            width: coinWidth,
                          ),
                        ),
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
                                  style: titleFont(context).copyWith(fontSize: 18),
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

