// auth.dart — Riverpod auth state + router refresh helper
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

/// Stream of auth events (signIn / signOut / tokenRefresh / …).
/// Use this in widgets that need to react to sign-in state.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Simple ChangeNotifier subscribed to auth changes — feed this into
/// GoRouter's `refreshListenable` so redirects fire on sign-in/out.
class AuthRefresh extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;
  bool _wasSignedIn;

  AuthRefresh() : _wasSignedIn = supabase.auth.currentUser != null {
    _sub = supabase.auth.onAuthStateChange.listen((state) {
      final isSignedIn = supabase.auth.currentUser != null;
      if (isSignedIn != _wasSignedIn) {
        _wasSignedIn = isSignedIn;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
