import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_state.dart';
import 'backend_url_helper.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserId = 'userId';
  static const String _keyUserEmail = 'userEmail';
  static const String _keyAnonymousUserId = 'anonymousUserId';

  // Get current user
  User? get currentUser {
    if (!SupabaseState.isInitialized) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    if (!SupabaseState.isInitialized) {
      throw const AuthException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY (or pass via --dart-define).',
      );
    }
    
    try {
      // Call the backend signup endpoint instead of Supabase directly
      // This ensures Klaviyo tracking and profile creation
      final backendUrl = BackendUrlHelper.getBackendUrl();
      final signupUrl = Uri.parse('$backendUrl/api/v1/auth/signup');
      
      final response = await http.post(
        signupUrl,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
          if (fullName != null) 'full_name': fullName,
          'signup_method': 'email',
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        // Now sign in to get the auth session
        final authResponse = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (authResponse.user != null) {
          await _saveUserData(authResponse.user!);
        }
        
        return authResponse;
      } else if (response.statusCode == 409) {
        throw const AuthException('An account with this email already exists.');
      } else {
        final errorData = json.decode(response.body);
        throw AuthException(errorData['detail'] ?? 'Failed to create account.');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to create account: ${e.toString()}');
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (!SupabaseState.isInitialized) {
      throw const AuthException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY (or pass via --dart-define).',
      );
    }
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _saveUserData(response.user!);
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!SupabaseState.isInitialized) {
      await _clearUserData();
      return;
    }
    try {
      await Supabase.instance.client.auth.signOut();
      await _clearUserData();
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    if (!SupabaseState.isInitialized) {
      throw const AuthException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY (or pass via --dart-define).',
      );
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Save user data to local storage
  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserEmail, user.email ?? '');
  }

  // Clear user data from local storage
  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
  }

  // Check if user was previously logged in
  Future<bool> wasLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Get stored user email
  Future<String?> getStoredUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  // Get or create anonymous user ID for unauthenticated users
  Future<String> getOrCreateAnonymousUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? anonymousUserId = prefs.getString(_keyAnonymousUserId);
    
    if (anonymousUserId == null || anonymousUserId.isEmpty) {
      // Generate a new anonymous user ID (UUID format)
      anonymousUserId = _generateAnonymousUserId();
      await prefs.setString(_keyAnonymousUserId, anonymousUserId);
    }
    
    return anonymousUserId;
  }

  // Generate a unique anonymous user ID
  String _generateAnonymousUserId() {
    // Generate a UUID-like string for anonymous users
    // Format: anonymous-{timestamp}-{random}
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    return 'anonymous-$timestamp-$random';
  }

  // Get current user ID (authenticated or anonymous)
  Future<String?> getCurrentUserId() async {
    if (isLoggedIn && currentUser != null) {
      return currentUser!.id;
    }
    return await getOrCreateAnonymousUserId();
  }

  // COPPA Compliance: Age verification
  static bool isAgeValid(DateTime birthDate) {
    final now = DateTime.now();
    final age = now.year - birthDate.year -
        (now.month > birthDate.month ||
                (now.month == birthDate.month && now.day >= birthDate.day)
            ? 0
            : 1);
    return age >= 13;
  }

  // COPPA Compliance: Check if user needs parental consent
  static bool requiresParentalConsent(DateTime birthDate) {
    final now = DateTime.now();
    final age = now.year - birthDate.year -
        (now.month > birthDate.month ||
                (now.month == birthDate.month && now.day >= birthDate.day)
            ? 0
            : 1);
    return age < 13;
  }

  // COPPA Compliance: Request parental consent
  Future<bool> requestParentalConsent({
    required String childEmail,
    required String parentEmail,
    required DateTime childBirthDate,
  }) async {
    try {
      // Store consent request in Supabase
      // This would typically send an email to the parent for verification
      final response = await Supabase.instance.client
          .from('parental_consents')
          .insert({
        'child_email': childEmail,
        'parent_email': parentEmail,
        'child_birth_date': childBirthDate.toIso8601String(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      // In a real implementation, you would send an email to the parent
      // with a verification link. For now, we'll just store the request.

      return response != null;
    } catch (e) {
      print('Error requesting parental consent: $e');
      return false;
    }
  }

  // COPPA Compliance: Check if parental consent is verified
  Future<bool> isParentalConsentVerified(String childEmail) async {
    try {
      final response = await Supabase.instance.client
          .from('parental_consents')
          .select('status')
          .eq('child_email', childEmail)
          .eq('status', 'verified')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking parental consent: $e');
      return false;
    }
  }

  // COPPA Compliance: Store age verification data (minimal data collection)
  Future<void> storeAgeVerification({
    required String userId,
    required bool isOver13,
    DateTime? birthDate, // Only store if required for consent
  }) async {
    try {
      // Store minimal data - only what's necessary
      await Supabase.instance.client.from('user_age_verification').upsert({
        'user_id': userId,
        'is_over_13': isOver13,
        'verified_at': DateTime.now().toIso8601String(),
        // Only store birth date if under 13 (for consent purposes)
        if (!isOver13 && birthDate != null)
          'birth_date': birthDate.toIso8601String(),
      });
    } catch (e) {
      print('Error storing age verification: $e');
      // Non-critical, continue
    }
  }
}
