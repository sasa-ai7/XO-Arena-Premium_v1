import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import 'local_store.dart';
import '../models/user_data.dart';
import 'audit_service.dart';
import 'app_mode_service.dart';
import 'connectivity_service.dart';
import 'session_service.dart';
import 'user_repo.dart';

/// Thrown when Firebase Auth account deletion requires a recent login.
/// The UI layer should catch this, show a re-auth dialog, then call [AuthService.deleteAuthOnly].
class RequiresReauthException implements Exception {
  @override
  String toString() => 'RequiresReauthException: Recent login required.';
}

/// Firebase Authentication service with Email/Password only.
/// Saves user data to Firestore and syncs to LocalStore for app compatibility.
/// Passwords are NEVER stored.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Set to true if Firestore/sync failed after a successful auth. Caller should show "Logged in but failed to sync profile".
  bool lastSyncFailed = false;

  /// True when the most recent [signInWithGoogle] created (or found no profile
  /// for) the account, so the UI must route to Complete-Profile instead of Home.
  /// Lets the login screen skip a second Firestore read to re-check existence.
  bool lastSignInWasNewUser = false;

  void _logException(Object e, StackTrace? st) {
    // Log error without exposing sensitive information
    if (kDebugMode) {
      debugPrint('[AUTH] Exception: ${e.runtimeType}');
    }
    if (st != null) {
      // Only log stack trace in debug mode, not in production
      if (kDebugMode) {
        if (kDebugMode) {
          debugPrint('[AUTH] StackTrace: $st');
        }
      }
    }
    if (e is FirebaseAuthException) {
      if (kDebugMode) {
        debugPrint('[AUTH] FirebaseAuthException code=${e.code}');
      }
      // Don't log the full message as it may contain sensitive info
    }
    if (e is FirebaseException) {
      if (kDebugMode) {
        debugPrint('[AUTH] FirebaseException code=${e.code}');
      }
      // Don't log the full message as it may contain sensitive info
    }
    if (e is PlatformException) {
      if (kDebugMode) {
        debugPrint(
            '[AUTH] PlatformException code=${e.code} message=${e.message} details=${e.details}');
      }
    }
  }

  Exception _getUserFriendlyGoogleSignInError(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final merged = '$code $msg $details';

    if (merged.contains('sign_in_canceled') ||
        merged.contains('canceled') ||
        merged.contains('cancelled')) {
      return Exception('Sign-in cancelled.');
    }

    if (merged.contains('10') ||
        merged.contains('12500') ||
        merged.contains('developer_error')) {
      return Exception(
          'Google Sign-In configuration error. Add this device SHA-1 to Firebase for com.xoarena.neonclash, download a fresh android/app/google-services.json, then rebuild and reinstall.');
    }

    if (merged.contains('network') ||
        merged.contains('socket') ||
        merged.contains('timeout')) {
      return Exception(
          'Google sign-in failed due to network issues. Please check your internet and try again.');
    }

    return Exception('Google sign-in failed. Please try again.');
  }

  /// Convert FirebaseAuthException to user-friendly error message.
  Exception _getUserFriendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception(
            'No account found with this email. Please sign up first.');
      case 'wrong-password':
        return Exception('Incorrect password. Please try again.');
      case 'email-already-in-use':
        return Exception('An account already exists with this email.');
      case 'invalid-email':
        return Exception('Invalid email address. Please check and try again.');
      case 'weak-password':
        return Exception('Password is too weak. Use at least 6 characters.');
      case 'network-request-failed':
        return Exception(
            'Network error. Please check your internet connection and try again.');
      case 'too-many-requests':
        return Exception(
            'Too many attempts. Please wait a moment and try again.');
      case 'operation-not-allowed':
        return Exception(
            'This sign-in method is not enabled. Please contact support.');
      case 'user-disabled':
        return Exception(
            'This account has been disabled. Please contact support.');
      case 'requires-recent-login':
        return Exception('Please sign in again to continue.');
      case 'account-exists-with-different-credential':
        return Exception(
            'This email is registered with Google. Please sign in with Google first, then you can link your password.');
      case 'invalid-credential':
        return Exception('Invalid email or password. Please try again.');
      default:
        return Exception('Authentication failed. Please try again.');
    }
  }

  /// Convert FirebaseException to user-friendly error message.
  Exception _getUserFriendlyFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return Exception(
            'Permission denied. Please contact support if this persists.');
      case 'unavailable':
        return Exception(
            'Service temporarily unavailable. Please try again later.');
      case 'deadline-exceeded':
        return Exception(
            'Request timed out. Please check your internet connection and try again.');
      case 'network-request-failed':
        return Exception(
            'Network error. Please check your internet connection and try again.');
      default:
        return Exception('An error occurred. Please try again.');
    }
  }

  /// Sign in with email and password. On success: save to Firestore, init UserRepo.
  ///
  /// Handles both normal accounts and Google accounts that have been linked with email/password.
  /// If account exists with Google but not linked, shows appropriate error message.
  /// Throws exceptions with user-friendly messages on failure.
  Future<User?> signInWithEmailPassword(String email, String password) async {
    lastSyncFailed = false;
    try {
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 1: signInWithEmailAndPassword');
      }
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 1 OK: signInWithEmailAndPassword');
      }
      if (user == null) {
        throw Exception('Sign-in failed. Please try again.');
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Sign-in failed. Please try again.');
      }

      await FirebaseFirestore.instance.enableNetwork();
      AppModeService.setMode(AppMode.online);

      try {
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 2: saveUserToFirestore');
        }
        await _saveUserToFirestore(currentUser, provider: 'email');
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 2 OK: saveUserToFirestore');
        }

        if (kDebugMode) {
          debugPrint('[AUTH] STEP 3: syncToLocalStore');
        }
        await _syncToLocalStore(currentUser);
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 3 OK: syncToLocalStore');
        }

        if (kDebugMode) {
          debugPrint('[AUTH] STEP 4: userRepo.initAfterAuth');
        }
        await UserRepo().initAfterAuth(currentUser.uid);
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 4 OK: userRepo.initAfterAuth');
        }
      } catch (e, st) {
        lastSyncFailed = true;
        _logException(e, st);
        if (kDebugMode) {
          debugPrint('[AUTH] Sync failed but auth succeeded - returning user');
        }
      }

      // Save login status to SharedPreferences for persistent login
      final p = await SharedPreferences.getInstance();
      await p.setBool(Keys.loggedIn, true);
      if (kDebugMode) {
        debugPrint('[AUTH] Login status saved to SharedPreferences');
      }

      // Write single-device session (non-fatal)
      try {
        await SessionService.writeSession(currentUser.uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] Session write failed (non-fatal): $e');
        }
      }

      AuditService.log('login', {'provider': 'email'});
      return currentUser;
    } on FirebaseAuthException catch (e) {
      _logException(e, null);

      // Handle account-exists-with-different-credential
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
            'This email is registered with Google. Please sign in with Google first, then you can link your password.');
      }

      throw _getUserFriendlyAuthError(e);
    } on FirebaseException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyFirestoreError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception(
          'Sign-in failed. Please check your internet connection and try again.');
    }
  }

  /// Create account with email/password and initialize profile state.
  ///
  /// Returns the created [User] on success.
  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username, {
    required bool isAdultConfirmed,
  }) async {
    lastSyncFailed = false;
    if (!isAdultConfirmed) {
      throw Exception('You must be at least 13 years old to use this app.');
    }
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Sign-up failed. Please try again.');
      }

      await FirebaseFirestore.instance.enableNetwork();
      AppModeService.setMode(AppMode.online);

      try {
        await user.updateDisplayName(username.trim());
      } catch (_) {
        // Non-fatal: profile data is still saved in Firestore.
      }

      try {
        await _saveUserToFirestore(
          user,
          name: username.trim(),
          ageVerified: true,
          minimumAgePassed: true,
          ageVerifiedAtServer: true,
          provider: 'email',
        );
        await _syncToLocalStore(user, name: username.trim());
        await UserRepo().initAfterAuth(user.uid);
      } catch (e, st) {
        lastSyncFailed = true;
        _logException(e, st);
      }

      try {
        await SessionService.writeSession(user.uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] Session write failed (non-fatal): $e');
        }
      }

      try {
        await user.sendEmailVerification();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] Email verification send failed (non-fatal): $e');
        }
      }

      AuditService.log('signup', {'provider': 'email'});
      return user;
    } on FirebaseAuthException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyAuthError(e);
    } on FirebaseException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyFirestoreError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception(
          'Sign-up failed. Please check your internet connection and try again.');
    }
  }

  Future<void> sendEmailVerification(User user) async {
    await user.sendEmailVerification();
  }

  /// Sign in with Google. Returns User if successful, or throws Exception on failure.
  /// If this is the first time signing in with Google, the user will need to complete their profile.
  Future<User?> signInWithGoogle() async {
    lastSyncFailed = false;
    lastSignInWasNewUser = false;
    final sw = Stopwatch()..start();
    debugPrint('[PERF] google_login_start');
    try {
      // Reset stale session to force account picker on some Android devices.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Trigger the Google Sign-In flow.
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn().timeout(const Duration(seconds: 30));

      if (googleUser == null) {
        // User cancelled the sign-in
        if (kDebugMode) {
          debugPrint('[AUTH] Google sign-in cancelled by user');
        }
        throw Exception('Sign-in cancelled.');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Google sign-in failed. Please try again.');
      }
      // Guest startup disables Firestore network to protect the offline
      // namespace. Authentication succeeded, so enable it for the one required
      // profile-routing read. AppMode becomes online only once routing is safe.
      await FirebaseFirestore.instance.enableNetwork();
      debugPrint('[PERF] google_auth_done_ms=${sw.elapsedMilliseconds}');

      // Capture Google photo URL from the sign-in account before it goes
      // out of scope. FirebaseAuth.currentUser.photoURL can be null right
      // after signInWithCredential, but GoogleSignInAccount always has it.
      final googlePhotoUrl = googleUser.photoUrl;

      // ── Single Firestore read for the whole login flow ───────────────────
      // This one doc.get() both routes new-vs-existing AND seeds the local
      // cache below. The login screen no longer re-reads it, and all writes
      // (profile update, session, audit, referral) run in the background so
      // navigation is not blocked on the network.
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      try {
        userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Authentication already succeeded. Do not keep the login screen
        // blocked on an optional full profile pull; use Firebase's new-user
        // hint for routing and finish synchronization in the background.
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          lastSignInWasNewUser = true;
          AppModeService.setMode(AppMode.online);
          return user;
        }
        await _syncToLocalStore(user, photoUrl: googlePhotoUrl);
        unawaited(_postGoogleLoginBackground(user, googlePhotoUrl, sw));
        AppModeService.setMode(AppMode.online);
        if (kDebugMode) {
          debugPrint('[PERF] profile pull deferred after 5s timeout');
        }
        return user;
      }
      final hasProfile = userDoc.exists && userDoc.data() != null;

      // Persist login flag immediately (cheap, local).
      final p = await SharedPreferences.getInstance();
      await p.setBool(Keys.loggedIn, true);

      if (!hasProfile) {
        // First time Google sign-in - user needs to complete profile.
        lastSignInWasNewUser = true;
        AppModeService.setMode(AppMode.online);
        if (kDebugMode) {
          debugPrint(
              '[AUTH] First time Google sign-in - profile does not exist');
        }
        return user; // UI navigates to Complete Profile Screen
      }

      // Existing user: seed LocalStore from the doc we already fetched so Home
      // renders correct coins / cosmetics / photo immediately. This is the
      // minimum data required before navigating.
      try {
        final data = UserData.fromFirestore(userDoc);
        await UserRepo().applyUserDataToLocal(data);
        await _syncToLocalStore(user, photoUrl: googlePhotoUrl);
      } catch (e, st) {
        lastSyncFailed = true;
        _logException(e, st);
      }
      debugPrint('[PERF] user_profile_ready_ms=${sw.elapsedMilliseconds}');

      // Everything below is non-critical — never block navigation on it.
      unawaited(_postGoogleLoginBackground(user, googlePhotoUrl, sw));

      AppModeService.setMode(AppMode.online);

      return user;
    } on FirebaseAuthException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyAuthError(e);
    } on FirebaseException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyFirestoreError(e);
    } on PlatformException catch (e, st) {
      _logException(e, st);
      throw _getUserFriendlyGoogleSignInError(e);
    } on TimeoutException catch (e, st) {
      _logException(e, st);
      throw Exception('Google sign-in timed out. Please try again.');
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception(
          'Google sign-in failed. Please check your internet connection and try again.');
    }
  }

  /// Non-critical work that runs AFTER the user has already navigated to Home.
  /// Updates the Firestore profile (lastLoginAt, photo, welcome gift), runs the
  /// migration/referral init, writes the single-device session, and logs the
  /// audit event. Failures here never affect the visible login.
  Future<void> _postGoogleLoginBackground(
      User user, String? googlePhotoUrl, Stopwatch sw) async {
    try {
      await _saveUserToFirestore(user,
          provider: 'google', photoUrl: googlePhotoUrl);
    } catch (e, st) {
      lastSyncFailed = true;
      _logException(e, st);
    }
    try {
      // Migration + referral-code ensure + a fresh server pull (picks up any
      // welcome-gift coins granted by _saveUserToFirestore above).
      await UserRepo().initAfterAuth(user.uid);
    } catch (e, st) {
      _logException(e, st);
    }
    try {
      await SessionService.writeSession(user.uid);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] Session write failed (non-fatal): $e');
      }
    }
    AuditService.log('login', {'provider': 'google'});
    debugPrint(
        '[PERF] post_login_background_done_ms=${sw.elapsedMilliseconds}');
  }

  /// Link email/password credential to the current Google account.
  /// This allows users to sign in with either Google or email/password.
  ///
  /// Throws user-friendly exceptions on failure.
  Future<void> linkEmailPasswordCredential(
      String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in. Please sign in first.');
    }

    if (user.email == null ||
        user.email!.toLowerCase() != email.trim().toLowerCase()) {
      throw Exception(
          'Email must match your Google account email (${user.email}).');
    }

    try {
      if (kDebugMode) {
        debugPrint(
            '[AUTH] Linking email/password credential to Google account');
      }

      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      await user.linkWithCredential(credential);

      if (kDebugMode) {
        debugPrint('[AUTH] Email/password credential linked successfully');
      }
    } on FirebaseAuthException catch (e) {
      _logException(e, null);
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already linked to another account.');
      } else if (e.code == 'credential-already-in-use') {
        throw Exception('This password is already linked to another account.');
      } else if (e.code == 'invalid-credential') {
        throw Exception(
            'Invalid email or password. Please check and try again.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Use at least 6 characters.');
      } else if (e.code == 'network-request-failed') {
        throw Exception(
            'Network error. Please check your internet connection and try again.');
      }
      throw _getUserFriendlyAuthError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception(
          'Failed to link email/password credential. Please try again.');
    }
  }

  /// Complete profile for Google sign-in user (first time).
  /// Saves profile to Firestore and links email/password credential.
  /// Password is required so the user can later sign in with email+password.
  ///
  /// Throws user-friendly exceptions on failure.
  Future<void> completeGoogleProfile({
    required String name,
    required String password,
    required String characterType,
    required bool isAdultConfirmed,
    bool acceptedTerms = false,
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in. Please sign in first.');
    }

    if (user.email == null) {
      throw Exception('User email not found. Please try signing in again.');
    }

    if (!isAdultConfirmed) {
      throw Exception('You must be at least 13 years old to use this app.');
    }

    try {
      if (kDebugMode) {
        debugPrint('[AUTH] Completing Google profile for ${user.email}');
        debugPrint('[ONBOARDING] ageVerified=true');
        debugPrint('[ONBOARDING] Creating Google profile...');
      }

      // Step 1: Link email/password credential (required)
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 1: Linking email/password credential');
      }
      try {
        await linkEmailPasswordCredential(user.email!, password);
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 1 OK: Email/password credential linked');
        }
      } catch (e) {
        // If linking fails, still save profile (user can link later)
        if (kDebugMode) {
          debugPrint(
              '[AUTH] Credential linking failed (non-fatal, continuing): $e');
        }
      }

      // Step 2: Update display name
      try {
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 2: Updating display name');
        }
        await user.updateDisplayName(name.trim());
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 2 OK: Display name updated');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] Display name update failed (non-fatal): $e');
        }
        // Continue even if display name update fails
      }

      // Reload to ensure Firebase has synced Google provider data (photoURL).
      try {
        await user.reload();
        final reloaded = _auth.currentUser;
        if (reloaded != null) user = reloaded;
      } catch (_) {}

      // Step 3: Save profile to Firestore
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 3: Saving profile to Firestore');
      }
      await _saveUserToFirestore(
        user!,
        name: name.trim(),
        characterType: characterType,
        ageVerified: true,
        minimumAgePassed: true,
        ageVerifiedAtServer: true,
        provider: 'google',
      );

      // Write Account sub-map with terms acceptance (merge so it never overwrites other keys).
      if (acceptedTerms) {
        await _firestore.collection('users').doc(user.uid).set({
          'Account': {
            'acceptedTerms': true,
            'acceptedTermsAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }

      if (kDebugMode) {
        debugPrint('[AUTH] STEP 3 OK: Profile saved to Firestore');
        debugPrint('[ONBOARDING] Profile created successfully');
      }

      // Step 4: Sync to LocalStore
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 4: Syncing to LocalStore');
      }
      await _syncToLocalStore(user, name: name.trim());
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 4 OK: Synced to LocalStore');
      }

      // Step 5: Initialize UserRepo
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 5: Initializing UserRepo');
      }
      await UserRepo().initAfterAuth(user.uid);
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 5 OK: UserRepo initialized');
      }

      // Step 6: Write single-device session (non-fatal)
      try {
        await SessionService.writeSession(user.uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] Session write failed (non-fatal): $e');
        }
      }

      AuditService.log('login', {'provider': 'google', 'firstTime': true});
    } on FirebaseAuthException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyAuthError(e);
    } on FirebaseException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyFirestoreError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception(
          'Failed to complete profile. Please check your internet connection and try again.');
    }
  }

  /// Sign out from Firebase and clear all local data.
  /// All operations are wrapped in try/catch to prevent failures from breaking the flow.
  Future<void> signOut() async {
    // Audit log BEFORE sign-out — user must still be authenticated
    AuditService.log('logout');

    // Google Sign-In sign out
    try {
      await _googleSignIn.signOut();
      if (kDebugMode) {
        debugPrint('[AUTH] Google Sign-In signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AUTH] signOut: Google Sign-In signOut failed (ignored): $e');
      }
    }

    // Firebase sign out
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] signOut: firebase signOut failed (ignored): $e');
      }
    }

    // Clear session/profile cache once. Durable per-user history and pending
    // ledger uploads are deliberately preserved across every kind of logout.
    await UserRepo().clearSessionCacheOnly();
    await UserRepo().clearUserProfileCacheForLogout();
    await LocalStore.setProfilePhotoPath(null);
    await LocalStore.setProfilePhotoUrl(null);
    LocalStore.profilePhotoUrlNotifier.value = null;
    LocalStore.profileImagePathNotifier.value = null;

    // Clear session data
    await SessionService.clearLocal();
  }

  /// Sync current Firebase user to LocalStore (for HomeHub compatibility).
  Future<void> syncCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _syncToLocalStore(user);
    }
  }

  /// Delete account and all associated data from Firestore and Firebase Auth.
  /// Follows Google Play policy requirements:
  /// Re-authenticate user with password (for account deletion)
  /// Throws Exception if re-authentication fails
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in.');
    }

    if (user.email == null) {
      throw Exception('User email not found.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      if (kDebugMode) {
        debugPrint(
            '[AUTH] reauthenticateWithPassword: Re-authentication successful');
      }
    } on FirebaseAuthException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyAuthError(e);
    } catch (e, st) {
      _logException(e, st);
      throw Exception('Re-authentication failed. Please check your password.');
    }
  }

  /// Full-cycle account purge (Google Play compliant):
  /// 0. Re-authenticate (if password provided)
  /// 1. Read user doc → write best-effort deletion_feedback/{uid}
  /// 2. Delete /users/{uid}/transactions subcollection
  /// 3. Delete /users/{uid}/purchase_counts subcollection
  /// 4. Delete /users/{uid} main document
  /// 5. Delete Firebase Auth account via user.delete()
  /// 6. Clear local storage (SharedPreferences)
  /// 7. Sign out locally
  ///
  /// Throws [RequiresReauthException] if Auth deletion needs recent login.
  Future<void> deleteAccountAndData({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
          'No user logged in. Please sign in to delete your account.');
    }

    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      throw Exception('Please connect to the internet to delete your account.');
    }

    final uid = user.uid;
    final email = user.email ?? '';

    // Inspect providers for routing and debug logging.
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final hasPassword = providers.contains('password');
    final hasGoogle = providers.contains('google.com');

    if (kDebugMode) {
      debugPrint('[DELETE] providerData=${providers.join(',')}');
      debugPrint('[DELETE] hasPassword=$hasPassword hasGoogle=$hasGoogle');
      debugPrint('[AUTH] deleteAccountAndData: Starting deletion for uid=$uid');
    }

    // STEP 0: Re-authenticate based on provider.
    // - If password is provided and the account has a password provider → password reauth.
    // - If Google-only and no password provided → trust that the caller (UI) already
    //   reauthenticated with Google before calling this method.
    // - If requires-recent-login surfaces during user.delete(), that is caught below.
    if (password != null && password.isNotEmpty) {
      if (!hasPassword) {
        // Caller tried to use a password for a Google-only account — reject clearly.
        throw Exception(
            'This account uses Google sign-in. Please re-authenticate with Google to delete your account.');
      }
      if (kDebugMode)
        debugPrint('[DELETE] Starting reauthentication (password)');
      try {
        await reauthenticateWithPassword(password);
        if (kDebugMode)
          debugPrint('[DELETE] Password reauthentication success');
      } catch (e) {
        throw Exception('Incorrect password. Please try again.');
      }
    } else if (kDebugMode) {
      debugPrint(
          '[DELETE] No password provided — assuming Google reauth was done by caller');
    }

    // STEP 1: Read user doc for audit/feedback data (best-effort).
    int finalBalance = 0;
    int totalGames = 0;

    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      final data = snap.data();
      final wallet = data?['Wallet'];
      final stats = data?['Stats'];
      if (wallet is Map) finalBalance = (wallet['coins'] as num?)?.toInt() ?? 0;
      if (stats is Map)
        totalGames = (stats['gamesPlayed'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    // STEP 2: Write deletion feedback — non-fatal, must include uid for Firestore rules.
    // Note: The UI layer (main.dart) saves user-entered reason before calling here.
    // This write merges in the final audit data (balance, games).
    try {
      await _firestore.collection('deletion_feedback').doc(uid).set({
        'uid': uid,
        'email': email,
        'reason': 'User requested deletion',
        'details': '',
        'finalBalance': finalBalance,
        'totalGames': totalGames,
        'deletionDate': FieldValue.serverTimestamp(),
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

    // STEP 3: Delete subcollections.
    await _firestore.collection('users').doc(uid).set(
      <String, dynamic>{'deletionInProgress': true},
      SetOptions(merge: true),
    );
    if (kDebugMode) debugPrint('[DELETE] deleting subcollection transactions');
    await _deleteSubcollection(uid, 'transactions');
    if (kDebugMode) debugPrint('[DELETE] deleting subcollection wallet_ledger');
    await _deleteSubcollection(uid, 'wallet_ledger');
    if (kDebugMode)
      debugPrint('[DELETE] deleting subcollection purchase_counts');
    await _deleteSubcollection(uid, 'purchase_counts');
    await _deleteSubcollection(uid, 'ownedAvatars');
    await _deleteSubcollection(uid, 'onlineRoomHistory');
    await _deleteSubcollection(uid, 'user_logs');
    await _deleteSubcollection(uid, 'Arena');

    // STEP 4: Delete main user document.
    if (kDebugMode) debugPrint('[DELETE] deleting users/$uid');
    try {
      await _firestore.collection('users').doc(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'Firestore denied deleting user data. Deploy updated firestore.rules first.');
      }
      rethrow;
    }

    // STEP 5: Delete Firebase Auth account.
    if (kDebugMode) debugPrint('[DELETE] deleting Firebase Auth user');
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw RequiresReauthException();
      }
      throw _getUserFriendlyAuthError(e);
    }

    // STEP 6: Clear all local storage.
    if (kDebugMode) debugPrint('[DELETE] clearing local cache');
    try {
      final p = await SharedPreferences.getInstance();
      await p.clear();
      await p.setBool(Keys.justDeletedAccount, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DELETE] local cleanup failed (non-fatal): $e');
      }
    }

    // STEP 7: Sign out locally (Google + Firebase Auth).
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DELETE] sign-out failed (non-fatal): $e');
      }
    }

    if (kDebugMode) debugPrint('[DELETE] account deleted successfully');
  }

  /// Delete ONLY the Firebase Auth account (called after re-authentication).
  Future<void> deleteAuthOnly() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
    await signOut();
  }

  /// Batch-delete all documents in a user subcollection.
  Future<void> _deleteSubcollection(String uid, String subcollection) async {
    const batchLimit = 300;
    bool hasMore = true;
    while (hasMore) {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection(subcollection)
          .limit(batchLimit)
          .get();
      if (snapshot.docs.isEmpty) {
        hasMore = false;
      } else {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < batchLimit) hasMore = false;
      }
    }
  }

  Future<void> _saveUserToFirestore(User user,
      {String? name,
      String? characterType,
      bool? ageVerified,
      bool? minimumAgePassed,
      bool ageVerifiedAtServer = false,
      required String provider,
      String? photoUrl}) async {
    try {
      final displayName =
          name ?? user.displayName ?? user.email?.split('@').first ?? 'Player';
      final now = DateTime.now();
      final resolvedPhotoUrl = photoUrl ?? user.photoURL;

      final ref = _firestore.collection('users').doc(user.uid);
      final existing = await ref.get();

      if (!existing.exists || existing.data() == null) {
        // New user: create full document with defaults and 200-coin welcome gift.
        // No free avatars or skins — those must be purchased.
        final userData = UserData(
          profile: UserProfile(
            name: displayName,
            email: user.email ?? '',
            provider: provider,
            createdAt: now,
            lastLoginAt: now,
            updatedAt: now,
            welcomeGiftClaimed: true,
            photoURL: resolvedPhotoUrl,
            characterType: characterType,
            ageVerified: ageVerified,
            minimumAgePassed: minimumAgePassed,
          ),
          wallet: const UserWallet(coins: 200),
          stats: const UserStats(),
          cosmetics: const UserCosmetics(
            xColor: 'ffff3b30',
            oColor: 'ff0a84ff',
            ownedXColors: [0],
            ownedOColors: [0],
            equippedAvatar: 0,
            ownedAvatars: [],
            ownedXSkins: [],
            ownedOSkins: [],
            selectedXSkin: 'default',
            selectedOSkin: 'default',
          ),
          progress: const UserProgress(),
        );
        await ref.set(userData.toFirestore(), SetOptions(merge: true));
        // Overwrite updatedAt and createdAt with server timestamp for accuracy.
        // Stamp ageVerifiedAt server-side on first create when the caller
        // confirmed the age gate (ageVerifiedAtServer = true).
        final timestampOverrides = <String, dynamic>{
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (ageVerifiedAtServer) {
          timestampOverrides['ageVerifiedAt'] = FieldValue.serverTimestamp();
        }
        await ref.set({
          'Profile': timestampOverrides,
        }, SetOptions(merge: true));
      } else {
        // Existing user: update Profile and check for pending welcome gift.
        final existingData = existing.data() ?? {};
        final existingProfile = UserProfile.fromMap(
            existingData['Profile'] as Map<String, dynamic>?);
        final existingWallet =
            UserWallet.fromMap(existingData['Wallet'] as Map<String, dynamic>?);

        // Grant welcome gift if not yet claimed (e.g. account created before this field existed).
        final shouldGrantWelcomeGift =
            existingProfile.welcomeGiftClaimed != true;

        final mergedProfile = UserProfile(
          name: name ?? existingProfile.name,
          email: user.email ?? existingProfile.email,
          provider: provider,
          createdAt: existingProfile.createdAt,
          lastLoginAt: now,
          updatedAt: now,
          welcomeGiftClaimed: shouldGrantWelcomeGift
              ? true
              : existingProfile.welcomeGiftClaimed,
          photoURL: resolvedPhotoUrl ?? existingProfile.photoURL,
          characterType: characterType ?? existingProfile.characterType,
          ageVerified: ageVerified ?? existingProfile.ageVerified,
          minimumAgePassed:
              minimumAgePassed ?? existingProfile.minimumAgePassed,
          ageVerifiedAt: existingProfile.ageVerifiedAt,
        );

        final updates = <String, dynamic>{
          'Profile': mergedProfile.toMap(),
        };

        if (shouldGrantWelcomeGift) {
          final newCoins = existingWallet.coins + 200;
          updates['Wallet'] = {'coins': newCoins};
          if (kDebugMode) {
            debugPrint(
                '[AUTH] Welcome gift granted: +200 coins (total: $newCoins)');
          }
        }

        await ref.set(updates, SetOptions(merge: true));
        // Overwrite updatedAt with server timestamp for accuracy, and
        // passively scrub legacy DOB / age fields from any pre-release
        // profile on next sign-in. Stamp ageVerifiedAt server-side when the
        // caller confirmed the age gate on this login.
        final postUpdates = <String, dynamic>{
          'Profile.updatedAt': FieldValue.serverTimestamp(),
          'Profile.birthDate': FieldValue.delete(),
          'Profile.age': FieldValue.delete(),
        };
        if (ageVerifiedAtServer) {
          postUpdates['Profile.ageVerifiedAt'] = FieldValue.serverTimestamp();
        }
        await ref.update(postUpdates);
      }
    } on FirebaseException catch (e) {
      _logException(e, null);
      // Re-throw with user-friendly message
      throw _getUserFriendlyFirestoreError(e);
    } catch (e, st) {
      _logException(e, st);
      throw Exception('Failed to save user data. Please try again.');
    }
  }

  Future<void> _syncToLocalStore(User user,
      {String? name, String? photoUrl}) async {
    final displayName =
        name ?? user.displayName ?? user.email?.split('@').first ?? 'PLAYER';
    final p = await SharedPreferences.getInstance();
    await p.setString(Keys.username, displayName.toUpperCase());
    await p.setString(Keys.email, user.email ?? '');
    await p.setBool(Keys.loggedIn, true);

    // Capture Google/Firebase profile photo URL for global sync.
    // Use explicit photoUrl override (e.g. from GoogleSignInAccount) when
    // FirebaseAuth.currentUser.photoURL is not yet populated.
    final resolvedPhoto = photoUrl ?? user.photoURL;
    if (resolvedPhoto != null && resolvedPhoto.isNotEmpty) {
      await p.setString(Keys.profilePhotoUrl, resolvedPhoto);
      LocalStore.profilePhotoUrlNotifier.value = resolvedPhoto;
      // Mirror the photo URL into Firestore so other devices / the arena
      // room writes pick up the latest Google photo. Only write when the
      // stored value differs from the Auth value — saves a Firestore write
      // on every sign-in once the photo is stable. Best-effort: failures
      // here must not block sign-in.
      unawaited(_syncProfileToFirestoreIfChanged(
        uid: user.uid,
        photoUrl: resolvedPhoto,
        displayName: user.displayName,
        email: user.email,
      ));
    }
  }

  /// Conditional Firestore write of `users/{uid}.Profile.photoURL` so the
  /// Google photo stays current across devices. Reads first, writes only on
  /// change. Used since 2026-05 when the custom photo upload feature was
  /// removed in favor of Google Sign-In photoURL as the single source of
  /// truth (Firebase Storage was never enabled for this project).
  Future<void> _syncProfileToFirestoreIfChanged({
    required String uid,
    required String photoUrl,
    String? displayName,
    String? email,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await docRef.get();
      final data = snap.data() ?? const <String, dynamic>{};
      final profile = data['Profile'];
      final storedPhoto =
          (profile is Map) ? profile['photoURL'] as String? : null;
      final storedName =
          (profile is Map) ? profile['displayName'] as String? : null;
      final photoChanged = storedPhoto != photoUrl;
      final nameChanged = displayName != null &&
          displayName.isNotEmpty &&
          storedName != displayName;
      if (!photoChanged && !nameChanged) return;
      final patch = <String, dynamic>{
        'photoURL': photoUrl,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        if (email != null && email.isNotEmpty) 'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(
        <String, dynamic>{'Profile': patch},
        SetOptions(merge: true),
      );
      if (kDebugMode) {
        debugPrint(
            '[AUTH] Profile.photoURL synced to Firestore changed=photo:$photoChanged name:$nameChanged');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] Profile sync to Firestore failed (non-fatal): $e');
      }
    }
  }

  /// Re-authenticate the current user with Google credential.
  /// Used when Firebase Auth requires recent login for sensitive operations.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in.');

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled.');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }
}
