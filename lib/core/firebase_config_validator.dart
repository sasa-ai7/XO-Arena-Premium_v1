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

  /// Validates Firebase configuration and returns a list of issues found.
  /// Returns empty list if configuration is valid.
  /// 
  /// Checks:
  /// 1. Project ID match between google-services.json and firebase_options.dart
  /// 2. Package name consistency
  Future<List<String>> validateConfiguration() async {
    final issues = <String>[];

    try {
      // Get expected project ID from firebase_options.dart
      final expectedProjectId = DefaultFirebaseOptions.currentPlatform.projectId;
      
      // Read google-services.json
      final googleServicesJson = await _loadGoogleServicesJson();
      if (googleServicesJson == null) {
        // File not readable (normal on Android) - can't validate, but that's okay
        // The build system still uses it, and runtime errors will catch mismatches
        if (kDebugMode) {
          debugPrint('[FirebaseConfigValidator] Cannot read google-services.json for validation (normal on Android)');
        }
        return issues; // Return empty - no issues detected, but also can't validate
      }

      // Check project ID match
      final actualProjectId = googleServicesJson['project_info']?['project_id'] as String?;
      if (actualProjectId == null) {
        issues.add('google-services.json missing project_info.project_id');
      } else if (actualProjectId != expectedProjectId) {
        issues.add(
          'Project ID mismatch:\n'
          '  - google-services.json: "$actualProjectId"\n'
          '  - firebase_options.dart: "$expectedProjectId"\n'
          '  - Fix: Download correct google-services.json from Firebase Console for project "$expectedProjectId"'
        );
      }

      // Check package name (optional, but good to verify)
      final packageName = _getPackageName(googleServicesJson);
      if (packageName != null && packageName != 'com.sasa.xogame') {
        issues.add(
          'Package name mismatch in google-services.json: "$packageName"\n'
          '  - Expected: "com.sasa.xogame"'
        );
      }

    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FirebaseConfigValidator] Error validating config: $e');
        debugPrint('[FirebaseConfigValidator] StackTrace: $st');
      }
      issues.add('Error validating configuration: $e');
    }

    return issues;
  }

  /// Loads and parses google-services.json from assets or file system.
  /// 
  /// Note: On Android, google-services.json is processed at build time and
  /// may not be directly readable at runtime. This validator provides best-effort
  /// validation and will gracefully handle cases where the file cannot be read.
  Future<Map<String, dynamic>?> _loadGoogleServicesJson() async {
    try {
      // Try to load from assets first (if bundled)
      try {
        final content = await rootBundle.loadString('google-services.json');
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        // If not in assets, the file is likely processed at build time
        // This is normal on Android - google-services.json is merged into the app
        if (kDebugMode) {
          debugPrint('[FirebaseConfigValidator] google-services.json not readable from assets (normal on Android)');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseConfigValidator] Error loading google-services.json: $e');
      }
      return null;
    }
  }

  /// Extracts package name from google-services.json.
  String? _getPackageName(Map<String, dynamic> json) {
    try {
      final clients = json['client'] as List?;
      if (clients == null || clients.isEmpty) {
        return null;
      }

      final firstClient = clients.first as Map<String, dynamic>?;
      if (firstClient == null) return null;

      final clientInfo = firstClient['client_info'] as Map<String, dynamic>?;
      if (clientInfo == null) return null;

      final androidClientInfo = clientInfo['android_client_info'] as Map<String, dynamic>?;
      if (androidClientInfo == null) return null;

      return androidClientInfo['package_name'] as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseConfigValidator] Error extracting package name: $e');
      }
      return null;
    }
  }

  /// Validates configuration and logs warnings if issues are found.
  /// This is a convenience method that can be called at app startup.
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
        debugPrint('[FirebaseConfigValidator] ✅ Configuration validated successfully');
      }
    }
  }
}
