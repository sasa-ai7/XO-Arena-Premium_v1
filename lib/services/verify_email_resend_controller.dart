import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import 'auth_service.dart';

/// Result of attempting to send verification email.
class ResendResult {
  final bool success;
  final String? errorMessage;

  const ResendResult({required this.success, this.errorMessage});
}

/// Controller for managing email verification resend policy.
/// 
/// Policy:
/// - Max 3 resends total
/// - 30-second cooldown between each resend
/// - After 3rd resend, 1-hour lockout
/// - State persists across app restarts
class VerifyEmailResendController extends ChangeNotifier {
  static final VerifyEmailResendController _instance = VerifyEmailResendController._();
  factory VerifyEmailResendController() => _instance;
  VerifyEmailResendController._();

  final AuthService _authService = AuthService();

  // Policy constants
  static const int _maxResends = 3;
  static const Duration _cooldownDuration = Duration(seconds: 30);
  static const Duration _lockoutDuration = Duration(hours: 1);

  // State
  int _resendCount = 0;
  int? _lastSentAtMs;
  int? _lockoutUntilMs;
  bool _isInitialized = false;

  // Getters
  int get resendCount => _resendCount;
  bool get canSend => _computeCanSend();
  Duration? get remainingCooldown => _computeRemainingCooldown();
  Duration? get remainingLockout => _computeRemainingLockout();

  /// Initialize controller by loading state from SharedPreferences.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _resendCount = prefs.getInt(Keys.verify_resend_count) ?? 0;
      _lastSentAtMs = prefs.getInt(Keys.verify_last_sent_at_ms);
      _lockoutUntilMs = prefs.getInt(Keys.verify_lockout_until_ms);

      // Check if lockout has expired
      if (_lockoutUntilMs != null) {
        final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(_lockoutUntilMs!);
        if (DateTime.now().isAfter(lockoutUntil)) {
          // Lockout expired, reset state
          await _resetState();
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VERIFY] Failed to initialize controller: $e');
      }
      _isInitialized = true; // Mark as initialized to prevent retry loops
    }
  }

  /// Check if email can be sent based on policy.
  bool _computeCanSend() {
    if (!_isInitialized) return false;

    // Check lockout
    if (_lockoutUntilMs != null) {
      final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(_lockoutUntilMs!);
      if (DateTime.now().isBefore(lockoutUntil)) {
        return false; // Still in lockout
      }
      // Lockout expired, reset state synchronously (save async later)
      _resendCount = 0;
      _lastSentAtMs = null;
      _lockoutUntilMs = null;
      // Save asynchronously without awaiting
      _saveState();
    }

    // Check if max resends reached
    if (_resendCount >= _maxResends) {
      return false;
    }

    // Check cooldown
    if (_lastSentAtMs != null) {
      final lastSentAt = DateTime.fromMillisecondsSinceEpoch(_lastSentAtMs!);
      final cooldownUntil = lastSentAt.add(_cooldownDuration);
      if (DateTime.now().isBefore(cooldownUntil)) {
        return false; // Still in cooldown
      }
    }

    return true;
  }

  /// Compute remaining cooldown duration, or null if no cooldown.
  Duration? _computeRemainingCooldown() {
    if (_lastSentAtMs == null) return null;

    final lastSentAt = DateTime.fromMillisecondsSinceEpoch(_lastSentAtMs!);
    final cooldownUntil = lastSentAt.add(_cooldownDuration);
    final now = DateTime.now();

    if (now.isBefore(cooldownUntil)) {
      return cooldownUntil.difference(now);
    }

    return null;
  }

  /// Compute remaining lockout duration, or null if no lockout.
  Duration? _computeRemainingLockout() {
    if (_lockoutUntilMs == null) return null;

    final lockoutUntil = DateTime.fromMillisecondsSinceEpoch(_lockoutUntilMs!);
    final now = DateTime.now();

    if (now.isBefore(lockoutUntil)) {
      return lockoutUntil.difference(now);
    }

    // Lockout expired
    return null;
  }

  /// Send verification email if allowed by policy.
  /// Returns ResendResult indicating success or failure with error message.
  Future<ResendResult> sendVerificationEmailIfAllowed() async {
    // Ensure initialized
    if (!_isInitialized) {
      await initialize();
    }

    // Check if user exists
    final user = _authService.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('[VERIFY] [RESEND] Cannot send: No user logged in');
      }
      return const ResendResult(
        success: false,
        errorMessage: 'No user logged in. Please sign in first.',
      );
    }

    // Check if already verified
    await user.reload();
    final currentUser = _authService.currentUser;
    if (currentUser?.emailVerified ?? false) {
      if (kDebugMode) {
        debugPrint('[VERIFY] [RESEND] Cannot send: Email already verified');
      }
      return const ResendResult(
        success: false,
        errorMessage: 'Email is already verified.',
      );
    }

    // Log resend request
    final attemptNumber = _resendCount + 1;
    if (kDebugMode) {
      debugPrint('[VERIFY] [RESEND] User requested resend (attempt $attemptNumber/$_maxResends)');
    }

    // Check policy
    if (!canSend) {
      final lockout = remainingLockout;
      if (lockout != null) {
        final formatted = formatRemainingTime(lockout);
        if (kDebugMode) {
          debugPrint('[VERIFY] [RESEND] Blocked by lockout: $formatted remaining');
        }
        return ResendResult(
          success: false,
          errorMessage: 'Too many verification emails sent. Please try again in $formatted.',
        );
      }

      final cooldown = remainingCooldown;
      if (cooldown != null) {
        final formatted = formatRemainingTime(cooldown);
        if (kDebugMode) {
          debugPrint('[VERIFY] [RESEND] Blocked by cooldown: $formatted remaining');
        }
        return ResendResult(
          success: false,
          errorMessage: 'Please wait $formatted before requesting another verification email.',
        );
      }

      if (kDebugMode) {
        debugPrint('[VERIFY] [RESEND] Blocked: Cannot send at this time');
      }
      return const ResendResult(
        success: false,
        errorMessage: 'Cannot send verification email at this time.',
      );
    }

    // Send email
    try {
      if (kDebugMode) {
        debugPrint('[VERIFY] [RESEND] Sending verification email to ${user.email}');
      }
      await _authService.sendEmailVerification(user);
      
      // Update state
      _resendCount++;
      _lastSentAtMs = DateTime.now().millisecondsSinceEpoch;

      // If this was the 3rd resend, set lockout
      if (_resendCount >= _maxResends) {
        _lockoutUntilMs = DateTime.now().add(_lockoutDuration).millisecondsSinceEpoch;
        if (kDebugMode) {
          debugPrint('[VERIFY] [RESEND] Maximum resends reached ($_maxResends), lockout activated for 1 hour');
        }
      }

      // Save to SharedPreferences
      await _saveState();

      if (kDebugMode) {
        debugPrint('[VERIFY] [RESEND] Verification email sent successfully (attempt $_resendCount/$_maxResends)');
      }

      notifyListeners();
      return const ResendResult(success: true);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'too-many-requests') {
        // Firebase also says too many requests - enforce our lockout
        if (kDebugMode) {
          debugPrint('[VERIFY] [RESEND] Firebase returned too-many-requests, enforcing lockout');
        }
        _resendCount = _maxResends;
        _lockoutUntilMs = DateTime.now().add(_lockoutDuration).millisecondsSinceEpoch;
        await _saveState();
        errorMessage = 'Too many verification emails sent. Please wait 1 hour before trying again.';
      } else if (e.code == 'network-request-failed') {
        if (kDebugMode) {
          debugPrint('[VERIFY] [RESEND] Network error: ${e.message}');
        }
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else {
        if (kDebugMode) {
          debugPrint('[VERIFY] [RESEND] Firebase error: ${e.code} - ${e.message}');
        }
        errorMessage = 'Failed to send verification email. Please try again.';
      }
      
      notifyListeners();
      return ResendResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VERIFY] [RESEND] Unexpected error sending verification email: $e');
      }
      notifyListeners();
      return const ResendResult(
        success: false,
        errorMessage: 'Failed to send verification email. Please try again.',
      );
    }
  }

  /// Reset state (used when lockout expires or user verifies email).
  Future<void> _resetState() async {
    _resendCount = 0;
    _lastSentAtMs = null;
    _lockoutUntilMs = null;
    await _saveState();
    notifyListeners();
  }

  /// Reset state when email is verified (call this externally when verification succeeds).
  Future<void> resetOnVerification() async {
    await _resetState();
  }

  /// Save state to SharedPreferences.
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(Keys.verify_resend_count, _resendCount);
      if (_lastSentAtMs != null) {
        await prefs.setInt(Keys.verify_last_sent_at_ms, _lastSentAtMs!);
      } else {
        await prefs.remove(Keys.verify_last_sent_at_ms);
      }
      if (_lockoutUntilMs != null) {
        await prefs.setInt(Keys.verify_lockout_until_ms, _lockoutUntilMs!);
      } else {
        await prefs.remove(Keys.verify_lockout_until_ms);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VERIFY] Failed to save state: $e');
      }
    }
  }

  /// Format remaining time for display.
  /// Returns "mm:ss" for < 1 hour, "hh:mm:ss" for >= 1 hour.
  static String formatRemainingTime(Duration duration) {
    final totalSeconds = duration.inSeconds;
    
    if (totalSeconds < 3600) {
      // Less than 1 hour: show mm:ss
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      // 1 hour or more: show hh:mm:ss
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      final seconds = totalSeconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
