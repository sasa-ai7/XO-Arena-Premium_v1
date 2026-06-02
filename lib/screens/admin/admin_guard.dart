import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Hardcoded admin email kept in sync with `isAdmin()` in firestore.rules.
const String _kHardcodedAdminEmail = 'adminarena77@gmail.com';

/// Returns true when the signed-in user passes EITHER of:
///   • email == [_kHardcodedAdminEmail], or
///   • admins/{uid} doc exists with active == true.
///
/// Result is cached per uid for the session to avoid re-reading on every
/// page navigation.
class AdminAuth {
  AdminAuth._();
  static final Map<String, bool> _cache = <String, bool>{};

  static Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final uid = user.uid;
    if (!forceRefresh && _cache.containsKey(uid)) return _cache[uid]!;

    if (user.email == _kHardcodedAdminEmail) {
      _cache[uid] = true;
      return true;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final active = doc.data()?['active'] == true;
      _cache[uid] = active;
      return active;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdminAuth] admins/$uid lookup failed: $e');
      }
      _cache[uid] = false;
      return false;
    }
  }

  static void clearCache() => _cache.clear();
}

/// Wraps an admin page. Shows a spinner while resolving admin status,
/// redirects non-admins back to home, and renders [child] for admins.
class AdminGate extends StatefulWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late Future<bool> _check;

  @override
  void initState() {
    super.initState();
    _check = AdminAuth.isCurrentUserAdmin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _check,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF040A14),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == true) return widget.child;
        // Non-admin: bounce back home on next frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        });
        return const Scaffold(
          backgroundColor: Color(0xFF040A14),
          body: Center(
            child: Text(
              'Admin access required.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      },
    );
  }
}
