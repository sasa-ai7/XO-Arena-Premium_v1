import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';

/// Validates Firebase configuration consistency between google-services.json
/// and firebase_options.dart to detect project mismatches.
class FirebaseConfigValidator {
  static final FirebaseConfigValidator _instance = FirebaseConfigValidator._();
  factory FirebaseConfigValidator() => _instance;
  FirebaseConfigValidator._();

  static const String _expectedProjectId = 'xo-arenaneon-clash';
  static const String _expectedPackageName = 'com.xoarena.neonclash';
  static const String _expectedAppId =
      '1:928308967161:android:7fab6afb06730609311428';
  static const String _expectedProjectNumber = '928308967161';

  /// Validates Firebase configuration and returns a list of issues found.
  /// Returns empty list if configuration is valid.
  ///
  /// Checks:
  /// 1. Project ID match between google-services.json and firebase_options.dart
  /// 2. Package name consistency
  /// 3. App ID consistency
  Future<List<String>> validateConfiguration() async {
    final issues = <String>[];

    try {
      // Check that firebase_options.dart points to the correct project
      final runtimeProjectId = DefaultFirebaseOptions.currentPlatform.projectId;
      if (runtimeProjectId != _expectedProjectId) {
        issues.add(
          'CRITICAL: Firebase project mismatch in firebase_options.dart.\n'
          '  - Expected: "$_expectedProjectId"\n'
          '  - Found:    "$runtimeProjectId"\n'
          '  - Fix: Run flutterfire configure --project=$_expectedProjectId --platforms=android',
        );
      }

      final runtimeAppId = DefaultFirebaseOptions.currentPlatform.appId;
      if (runtimeAppId != _expectedAppId) {
        issues.add(
          'CRITICAL: Firebase App ID mismatch in firebase_options.dart.\n'
          '  - Expected: "$_expectedAppId"\n'
          '  - Found:    "$runtimeAppId"',
        );
      }

      // Read google-services.json (best-effort; processed at build time on Android)
      final googleServicesJson = await _loadGoogleServicesJson();
      if (googleServicesJson == null) {
        if (kDebugMode) {
          debugPrint(
            '[FirebaseConfigValidator] google-services.json not readable at runtime (normal on Android)',
          );
        }
        return issues;
      }

      // Verify project ID in google-services.json
      final actualProjectId =
          googleServicesJson['project_info']?['project_id'] as String?;
      if (actualProjectId == null) {
        issues.add('google-services.json is missing project_info.project_id');
      } else if (actualProjectId != _expectedProjectId) {
        issues.add(
          'CRITICAL: Firebase project mismatch in google-services.json.\n'
          '  - Expected: "$_expectedProjectId"\n'
          '  - Found:    "$actualProjectId"\n'
          '  - Fix: Download the correct google-services.json from Firebase Console.',
        );
      }

      // Verify project number in google-services.json
      final actualProjectNumber =
          googleServicesJson['project_info']?['project_number'] as String?;
      if (actualProjectNumber != null &&
          actualProjectNumber != _expectedProjectNumber) {
        issues.add(
          'Firebase project number mismatch in google-services.json.\n'
          '  - Expected: "$_expectedProjectNumber"\n'
          '  - Found:    "$actualProjectNumber"',
        );
      }

      // Verify Android package name in google-services.json
      final packageName = _getPackageName(googleServicesJson);
      if (packageName != null && packageName != _expectedPackageName) {
        issues.add(
          'CRITICAL: Package name mismatch in google-services.json.\n'
          '  - Expected: "$_expectedPackageName"\n'
          '  - Found:    "$packageName"\n'
          '  - Fix: Download the correct google-services.json from Firebase Console.',
        );
      }

      // Verify App ID in google-services.json
      final actualAppId = _getAppId(googleServicesJson);
      if (actualAppId != null && actualAppId != _expectedAppId) {
        issues.add(
          'Firebase App ID mismatch in google-services.json.\n'
          '  - Expected: "$_expectedAppId"\n'
          '  - Found:    "$actualAppId"',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FirebaseConfigValidator] Error validating config: $e');
        debugPrint('[FirebaseConfigValidator] StackTrace: $st');
      }
      issues.add('Error validating Firebase configuration: $e');
    }

    return issues;
  }

  Future<Map<String, dynamic>?> _loadGoogleServicesJson() async {
    try {
      final content = await rootBundle.loadString('google-services.json');
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? _getPackageName(Map<String, dynamic> json) {
    try {
      final clients = json['client'] as List?;
      if (clients == null || clients.isEmpty) return null;
      final clientInfo =
          (clients.first as Map<String, dynamic>)['client_info']
              as Map<String, dynamic>?;
      final androidInfo =
          clientInfo?['android_client_info'] as Map<String, dynamic>?;
      return androidInfo?['package_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? _getAppId(Map<String, dynamic> json) {
    try {
      final clients = json['client'] as List?;
      if (clients == null || clients.isEmpty) return null;
      final clientInfo =
          (clients.first as Map<String, dynamic>)['client_info']
              as Map<String, dynamic>?;
      return clientInfo?['mobilesdk_app_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Validates configuration at app startup and logs any issues.
  Future<void> validateAndLogWarnings() async {
    final issues = await validateConfiguration();
    if (issues.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[FirebaseConfigValidator] ⚠️ Configuration issues detected:');
        for (final issue in issues) {
          debugPrint('[FirebaseConfigValidator]   - $issue');
        }
        debugPrint('[FirebaseConfigValidator] Please check Firebase Console configuration.');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[FirebaseConfigValidator] ✅ Firebase configuration validated successfully');
      }
    }
  }
}
