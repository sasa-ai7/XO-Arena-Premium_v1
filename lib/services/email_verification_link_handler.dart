import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'verify_email_resend_controller.dart';

/// Result of verification link processing.
class VerificationLinkResult {
  final bool success;
  final String? errorMessage;

  const VerificationLinkResult({required this.success, this.errorMessage});
}

/// Service for handling Firebase email verification links.
/// 
/// Validates verification links and applies action codes to verify emails.
class EmailVerificationLinkHandler {
  static final EmailVerificationLinkHandler _instance = EmailVerificationLinkHandler._();
  factory EmailVerificationLinkHandler() => _instance;
  EmailVerificationLinkHandler._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VerifyEmailResendController _resendController = VerifyEmailResendController();

  // Allowed domains for verification links
  static const List<String> _allowedDomains = [
    'xo-arenaneon-clash.web.app',
    'xo-arenaneon-clash.firebaseapp.com',
  ];

  /// Validate and process a verification link.
  /// 
  /// Returns VerificationLinkResult indicating success or failure.
  /// On success, applies the action code and resets resend policy.
  Future<VerificationLinkResult> handleVerificationLink(Uri uri) async {
    // First check if this is a verification link using isVerificationLink()
    if (!isVerificationLink(uri)) {
      return const VerificationLinkResult(
        success: false,
        errorMessage: 'Invalid verification link.',
      );
    }

    // Validate domain
    final domainValidation = _validateDomain(uri);
    if (!domainValidation.success) {
      return domainValidation;
    }

    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) {
      return const VerificationLinkResult(
        success: false,
        errorMessage: 'Invalid verification link: missing oobCode.',
      );
    }

    // Apply action code
    try {
      if (kDebugMode) {
        debugPrint('[VERIFY] Applying action code for email verification...');
      }

      await _auth.applyActionCode(oobCode);

      if (kDebugMode) {
        debugPrint('[VERIFY] Action code applied successfully.');
      }

      // Try to reload user if logged in, but return success even if user is null
      // (user might click link before opening app)
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await user.reload();
          final currentUser = _auth.currentUser;
          
          if (currentUser?.emailVerified ?? false) {
            // Reset resend policy since email is now verified
            await _resendController.resetOnVerification();
            
            if (kDebugMode) {
              debugPrint('[VERIFY] Email verified successfully. Resend policy reset.');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[VERIFY] Warning: Failed to reload user after applyActionCode: $e');
          }
          // Continue - action code was applied successfully
        }
      } else {
        if (kDebugMode) {
          debugPrint('[VERIFY] No current user (user may click link before opening app). Action code applied successfully.');
        }
      }

      // Return success - action code was applied successfully
      // User will see verification status when they sign in
      return const VerificationLinkResult(success: true);
    } on FirebaseAuthException catch (e) {
      _logException(e);
      String errorMessage;
      switch (e.code) {
        case 'expired-action-code':
          errorMessage = 'This verification link has expired. Please request a new verification email.';
          break;
        case 'invalid-action-code':
          errorMessage = 'Invalid verification link. The link may have already been used.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found for this verification link.';
          break;
        default:
          errorMessage = 'Failed to verify email. Please try again or request a new verification link.';
      }
      return VerificationLinkResult(success: false, errorMessage: errorMessage);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[VERIFY] Unexpected error processing verification link: $e');
        debugPrint('[VERIFY] StackTrace: $st');
      }
      return const VerificationLinkResult(
        success: false,
        errorMessage: 'Failed to verify email. Please try again.',
      );
    }
  }

  /// Validate that the URI domain is allowed.
  VerificationLinkResult _validateDomain(Uri uri) {
    final host = uri.host.toLowerCase();
    
    // Check against allowed domains
    for (final allowedDomain in _allowedDomains) {
      if (host == allowedDomain.toLowerCase()) {
        return const VerificationLinkResult(success: true);
      }
    }

    // Also allow localhost for development
    if (kDebugMode && (host == 'localhost' || host == '127.0.0.1')) {
      return const VerificationLinkResult(success: true);
    }

    if (kDebugMode) {
      debugPrint('[VERIFY] Invalid domain: $host');
      debugPrint('[VERIFY] Allowed domains: $_allowedDomains');
    }

    return const VerificationLinkResult(
      success: false,
      errorMessage: 'Invalid verification link: unauthorized domain.',
    );
  }

  /// Validate that required query parameters are present.
  VerificationLinkResult _validateQueryParams(Uri uri) {
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];

    if (mode != 'verifyEmail') {
      if (kDebugMode) {
        debugPrint('[VERIFY] Invalid mode: $mode (expected verifyEmail)');
      }
      return const VerificationLinkResult(
        success: false,
        errorMessage: 'Invalid verification link: incorrect action type.',
      );
    }

    if (oobCode == null || oobCode.isEmpty) {
      if (kDebugMode) {
        debugPrint('[VERIFY] Missing oobCode parameter');
      }
      return const VerificationLinkResult(
        success: false,
        errorMessage: 'Invalid verification link: missing verification code.',
      );
    }

    return const VerificationLinkResult(success: true);
  }

  void _logException(FirebaseAuthException e) {
    if (kDebugMode) {
      debugPrint('[VERIFY] FirebaseAuthException: code=${e.code}, message=${e.message}');
    }
  }

  /// Check if a URI is a verification link (without processing it).
  bool isVerificationLink(Uri uri) {
    // Check path (should be /__/auth/action for Firebase Hosting)
    final path = uri.path.toLowerCase();
    if (path != '/__/auth/action' && !path.contains('__/auth/action')) {
      return false;
    }

    // Check mode parameter
    final mode = uri.queryParameters['mode'];
    if (mode != 'verifyEmail') {
      return false;
    }

    // Check oobCode parameter
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) {
      return false;
    }

    return true;
  }
}
