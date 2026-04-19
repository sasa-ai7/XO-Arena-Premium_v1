import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/keys.dart';
import '../main.dart' show LocalStore;
import '../models/user_data.dart';
import 'audit_service.dart';
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
        debugPrint('[AUTH] PlatformException code=${e.code} message=${e.message} details=${e.details}');
      }
    }
  }

  Exception _getUserFriendlyGoogleSignInError(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final merged = '$code $msg $details';

    if (merged.contains('sign_in_canceled') || merged.contains('canceled') || merged.contains('cancelled')) {
      return Exception('Sign-in cancelled.');
    }

    if (merged.contains('10') || merged.contains('12500') || merged.contains('developer_error')) {
      return Exception(
        'Google Sign-In configuration error. Add this device SHA-1 to Firebase for com.sasa.xogame, download a fresh android/app/google-services.json, then rebuild and reinstall.'
      );
    }

    if (merged.contains('network') || merged.contains('socket') || merged.contains('timeout')) {
      return Exception('Google sign-in failed due to network issues. Please check your internet and try again.');
    }

    return Exception('Google sign-in failed. Please try again.');
  }

  /// Convert FirebaseAuthException to user-friendly error message.
  Exception _getUserFriendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email. Please sign up first.');
      case 'wrong-password':
        return Exception('Incorrect password. Please try again.');
      case 'email-already-in-use':
        return Exception('An account already exists with this email.');
      case 'invalid-email':
        return Exception('Invalid email address. Please check and try again.');
      case 'weak-password':
        return Exception('Password is too weak. Use at least 6 characters.');
      case 'network-request-failed':
        return Exception('Network error. Please check your internet connection and try again.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please wait a moment and try again.');
      case 'operation-not-allowed':
        return Exception('This sign-in method is not enabled. Please contact support.');
      case 'user-disabled':
        return Exception('This account has been disabled. Please contact support.');
      case 'requires-recent-login':
        return Exception('Please sign in again to continue.');
      case 'account-exists-with-different-credential':
        return Exception('This email is registered with Google. Please sign in with Google first, then you can link your password.');
      case 'invalid-credential':
        return Exception('Invalid email or password. Please try again.');
      case 'invalid-email':
        return Exception('Invalid email address. Please check and try again.');
      case 'user-disabled':
        return Exception('This account has been disabled. Please contact support.');
      default:
        return Exception('Authentication failed. Please try again.');
    }
  }

  /// Convert FirebaseException to user-friendly error message.
  Exception _getUserFriendlyFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return Exception('Permission denied. Please contact support if this persists.');
      case 'unavailable':
        return Exception('Service temporarily unavailable. Please try again later.');
      case 'deadline-exceeded':
        return Exception('Request timed out. Please check your internet connection and try again.');
      case 'network-request-failed':
        return Exception('Network error. Please check your internet connection and try again.');
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
        await SessionService.writeSession(currentUser!.uid);
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
        throw Exception('This email is registered with Google. Please sign in with Google first, then you can link your password.');
      }
      
      throw _getUserFriendlyAuthError(e);
    } on FirebaseException catch (e) {
      _logException(e, null);
      throw _getUserFriendlyFirestoreError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception('Sign-in failed. Please check your internet connection and try again.');
    }
  }

  /// Create account with email/password and initialize profile state.
  ///
  /// Returns the created [User] on success.
  Future<User?> signUpWithEmailPassword(
    String email,
    String password,
    String username, {
    required int age,
  }) async {
    lastSyncFailed = false;
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Sign-up failed. Please try again.');
      }

      try {
        await user.updateDisplayName(username.trim());
      } catch (_) {
        // Non-fatal: profile data is still saved in Firestore.
      }

      try {
        await _saveUserToFirestore(
          user,
          name: username.trim(),
          age: age,
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
      throw Exception('Sign-up failed. Please check your internet connection and try again.');
    }
  }

  Future<void> sendEmailVerification(User user) async {
    await user.sendEmailVerification();
  }

  /// Sign in with Google. Returns User if successful, or throws Exception on failure.
  /// If this is the first time signing in with Google, the user will need to complete their profile.
  Future<User?> signInWithGoogle() async {
    lastSyncFailed = false;
    try {
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 1: GoogleSignIn().signIn()');
      }
      
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

      if (kDebugMode) {
        debugPrint('[AUTH] STEP 1 OK: GoogleSignIn().signIn()');
        debugPrint('[AUTH] STEP 2: Obtaining Google authentication credentials');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) {
        debugPrint('[AUTH] STEP 2 OK: Google authentication credentials obtained');
        debugPrint('[AUTH] STEP 3: signInWithCredential');
      }

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      var user = userCredential.user;

      if (user == null) {
        throw Exception('Google sign-in failed. Please try again.');
      }

      // Capture Google photo URL from the sign-in account before it goes
      // out of scope. FirebaseAuth.currentUser.photoURL can be null right
      // after signInWithCredential, but GoogleSignInAccount always has it.
      final googlePhotoUrl = googleUser.photoUrl;

      if (kDebugMode) {
        debugPrint('[AUTH] STEP 3 OK: signInWithCredential');
        debugPrint('[AUTH] Google photoUrl: $googlePhotoUrl, Firebase photoURL: ${user.photoURL}');
        debugPrint('[AUTH] STEP 4: Checking if profile exists in Firestore');
      }

      // Check if user profile exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final hasProfile = userDoc.exists && userDoc.data() != null;

      if (!hasProfile) {
        // First time Google sign-in - user needs to complete profile
        if (kDebugMode) {
          debugPrint('[AUTH] First time Google sign-in - profile does not exist');
        }
        // Save login status but don't sync yet (will be done after profile completion)
        final p = await SharedPreferences.getInstance();
        await p.setBool(Keys.loggedIn, true);
        return user; // Return user so UI can navigate to Complete Profile Screen
      }

      // Existing user - sync data
      try {
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 5: saveUserToFirestore');
        }
        await _saveUserToFirestore(user, provider: 'google', photoUrl: googlePhotoUrl);
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 5 OK: saveUserToFirestore');
        }

        if (kDebugMode) {
          debugPrint('[AUTH] STEP 6: syncToLocalStore');
        }
        await _syncToLocalStore(user, photoUrl: googlePhotoUrl);
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 6 OK: syncToLocalStore');
        }

        if (kDebugMode) {
          debugPrint('[AUTH] STEP 7: userRepo.initAfterAuth');
        }
        await UserRepo().initAfterAuth(user.uid);
        if (kDebugMode) {
          debugPrint('[AUTH] STEP 7 OK: userRepo.initAfterAuth');
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
        await SessionService.writeSession(user.uid);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] Session write failed (non-fatal): $e');
        }
      }

      AuditService.log('login', {'provider': 'google'});
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
      throw Exception('Google sign-in failed. Please check your internet connection and try again.');
    }
  }

  /// Link email/password credential to the current Google account.
  /// This allows users to sign in with either Google or email/password.
  /// 
  /// Throws user-friendly exceptions on failure.
  Future<void> linkEmailPasswordCredential(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in. Please sign in first.');
    }

    if (user.email == null || user.email!.toLowerCase() != email.trim().toLowerCase()) {
      throw Exception('Email must match your Google account email (${user.email}).');
    }

    try {
      if (kDebugMode) {
        debugPrint('[AUTH] Linking email/password credential to Google account');
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
        throw Exception('Invalid email or password. Please check and try again.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Use at least 6 characters.');
      } else if (e.code == 'network-request-failed') {
        throw Exception('Network error. Please check your internet connection and try again.');
      }
      throw _getUserFriendlyAuthError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception('Failed to link email/password credential. Please try again.');
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
    required int age,
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in. Please sign in first.');
    }

    if (user.email == null) {
      throw Exception('User email not found. Please try signing in again.');
    }

    try {
      if (kDebugMode) {
        debugPrint('[AUTH] Completing Google profile for ${user.email}');
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
          debugPrint('[AUTH] Credential linking failed (non-fatal, continuing): $e');
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
      await _saveUserToFirestore(user!, name: name.trim(), age: age, provider: 'google');
      if (kDebugMode) {
        debugPrint('[AUTH] STEP 3 OK: Profile saved to Firestore');
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
      throw Exception('Failed to complete profile. Please check your internet connection and try again.');
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
        debugPrint('[AUTH] signOut: Google Sign-In signOut failed (ignored): $e');
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

    // Clear login status
    final p = await SharedPreferences.getInstance();
    await p.setBool(Keys.loggedIn, false);
    if (kDebugMode) {
      debugPrint('[AUTH] Login status cleared from SharedPreferences');
    }

    // Clear local cache (preserve justDeletedAccount if needed)
    await UserRepo().clearLocalCache();

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
        debugPrint('[AUTH] reauthenticateWithPassword: Re-authentication successful');
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
  /// 1. Read user doc → build Ghost Record → write to /deletion_feedback/{uid}
  /// 2. Delete /users/{uid}/transactions subcollection
  /// 3. Delete /users/{uid}/purchase_counts subcollection
  /// 4. Delete /users/{uid} main document
  /// 5. Clean local storage (SharedPreferences)
  /// 6. Delete Firebase Auth account
  ///
  /// Throws [RequiresReauthException] if Auth deletion needs recent login.
  Future<void> deleteAccountAndData({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in. Please sign in to delete your account.');
    }

    final isOnline = await ConnectivityService().online;
    if (!isOnline) {
      throw Exception('Please connect to the internet to delete your account.');
    }

    final uid = user.uid;
    if (kDebugMode) {
      debugPrint('[AUTH] deleteAccountAndData: Starting deletion for uid=$uid');
    }

    // STEP 0: Re-authenticate if password provided
    if (password != null && password.isNotEmpty) {
      try {
        await reauthenticateWithPassword(password);
      } catch (e) {
        throw Exception('Incorrect password. Please try again.');
      }
    }

    // STEP 1: Read user document for Ghost Record BEFORE deleting anything
    int finalBalance = 0;
    int totalGames = 0;
    String email = user.email ?? '';
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final wallet = data['Wallet'] as Map<String, dynamic>?;
        final stats = data['Stats'] as Map<String, dynamic>?;
        finalBalance = (wallet?['coins'] as num?)?.toInt() ?? 0;
        totalGames = (stats?['gamesPlayed'] as num?)?.toInt() ?? 0;
        final profile = data['Profile'] as Map<String, dynamic>?;
        if (profile != null && (profile['email'] as String?)?.isNotEmpty == true) {
          email = profile['email'] as String;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] deleteAccountAndData: Failed to read user doc for ghost record (non-fatal): $e');
      }
    }

    // STEP 2: Write Ghost Record to /deletion_feedback/{uid}
    try {
      await _firestore.collection('deletion_feedback').doc(uid).set({
        'email': email,
        'uid': uid,
        'finalBalance': finalBalance,
        'totalGames': totalGames,
        'deletionDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[AUTH] deleteAccountAndData: Ghost Record written');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] deleteAccountAndData: Ghost Record write failed (non-fatal): $e');
      }
    }

    // STEP 3: Delete subcollections
    try {
      await _deleteSubcollection(uid, 'transactions');
      await _deleteSubcollection(uid, 'purchase_counts');
      if (kDebugMode) {
        debugPrint('[AUTH] deleteAccountAndData: Subcollections deleted');
      }
    } catch (e, st) {
      _logException(e, st);
      if (e is FirebaseException) {
        throw _getUserFriendlyFirestoreError(e);
      }
      throw Exception('Failed to delete your data. Please try again.');
    }

    // STEP 4: Delete main user document
    try {
      await _firestore.collection('users').doc(uid).delete();
      if (kDebugMode) {
        debugPrint('[AUTH] deleteAccountAndData: Main document deleted');
      }
    } catch (e, st) {
      _logException(e, st);
      if (e is FirebaseException) {
        throw _getUserFriendlyFirestoreError(e);
      }
      throw Exception('Failed to delete your data. Please try again.');
    }

    // STEP 5: Clean local storage
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(Keys.loggedIn, false);
      await p.remove(Keys.username);
      await p.remove(Keys.email);
      await p.remove(Keys.gamesPlayed);
      await p.remove(Keys.wins);
      await p.remove(Keys.losses);
      await p.remove(Keys.draws);
      await p.remove(Keys.coins);
      await p.remove(Keys.xColor);
      await p.remove(Keys.oColor);
      await p.remove(Keys.ownedXColors);
      await p.remove(Keys.ownedOColors);
      await p.remove(Keys.topupHistory);
      await p.remove(Keys.levelGameCurrentLevel);
      await p.remove(Keys.levelGameCompleted);
      await p.remove(Keys.migrated);
      await p.setBool(Keys.justDeletedAccount, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AUTH] deleteAccountAndData: Local cleanup failed (non-fatal): $e');
      }
    }

    // STEP 6: Delete Firebase Auth account
    try {
      await user.delete();
      await signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw RequiresReauthException();
      }
      _logException(e, null);
      throw _getUserFriendlyAuthError(e);
    } catch (e, st) {
      _logException(e, st);
      if (e is Exception) rethrow;
      throw Exception('Account deletion failed. Please try again.');
    }
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
      {String? name, int? age, required String provider, String? photoUrl}) async {
    try {
      final displayName =
          name ?? user.displayName ?? user.email?.split('@').first ?? 'Player';
      final now = DateTime.now();
      final resolvedPhotoUrl = photoUrl ?? user.photoURL;

      final profile = UserProfile(
        name: displayName,
        age: age,
        email: user.email ?? '',
        provider: provider,
        createdAt: now,
        lastLoginAt: now,
      );

      final ref = _firestore.collection('users').doc(user.uid);
      final existing = await ref.get();

      if (!existing.exists || existing.data() == null) {
        // New user: create full document with defaults and welcome gift
        final userData = UserData(
          profile: UserProfile(
            name: displayName,
            age: age,
            email: user.email ?? '',
            provider: provider,
            createdAt: now,
            lastLoginAt: now,
            welcomeGiftClaimed: true, // Mark as claimed for new users
            photoURL: resolvedPhotoUrl,
          ),
          wallet: const UserWallet(coins: 200), // Welcome gift: 200 coins
          stats: const UserStats(),
          cosmetics: const UserCosmetics(
            xColor: 'ffff3b30',
            oColor: 'ff0a84ff',
            ownedXColors: [0],
            ownedOColors: [0],
          ),
          progress: const UserProgress(),
        );
        await ref.set(userData.toFirestore(), SetOptions(merge: true));
      } else {
        // Existing user: check for welcome gift and update Profile
        final existingData = existing.data() ?? {};
        final existingProfile =
            UserProfile.fromMap(existingData['Profile'] as Map<String, dynamic>?);
        final existingWallet =
            UserWallet.fromMap(existingData['Wallet'] as Map<String, dynamic>?);
        
        // Check if welcome gift needs to be granted
        bool shouldGrantWelcomeGift = existingProfile.welcomeGiftClaimed != true;
        
        final mergedProfile = UserProfile(
          name: name ?? existingProfile.name,
          age: age ?? existingProfile.age,
          email: user.email ?? existingProfile.email,
          provider: provider,
          createdAt: existingProfile.createdAt,
          lastLoginAt: now,
          welcomeGiftClaimed: shouldGrantWelcomeGift ? true : existingProfile.welcomeGiftClaimed,
          photoURL: resolvedPhotoUrl ?? existingProfile.photoURL,
        );
        
        final updates = <String, dynamic>{
          'Profile': mergedProfile.toMap(),
        };
        
        // Grant welcome gift if needed
        if (shouldGrantWelcomeGift) {
          final newCoins = (existingWallet.coins) + 200;
          updates['Wallet'] = {'coins': newCoins};
          if (kDebugMode) {
            debugPrint('[AUTH] Welcome gift granted: +200 coins (total: $newCoins)');
          }
        }
        
        await ref.set(updates, SetOptions(merge: true));
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

  Future<void> _syncToLocalStore(User user, {String? name, String? photoUrl}) async {
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
