import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing Sentry context and error reporting
class SentryService {
  /// Set the current session ID in Sentry context
  static Future<void> setSessionId(String? sessionId) async {
    if (sessionId == null) {
      await Sentry.configureScope((scope) {
        scope.removeTag('session_id');
      });
      return;
    }

    await Sentry.configureScope((scope) {
      scope.setTag('session_id', sessionId);
      // Note: setContext may not be available in all Sentry versions
      // Using setTag instead which is more widely supported
    });
  }

  /// Set user context from Supabase auth
  static Future<void> setUserContext(User? user) async {
    if (user == null) {
      await Sentry.configureScope((scope) {
        scope.setUser(null);
      });
      return;
    }

    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: user.id,
        email: user.email,
      ));
    });
  }

  /// Capture an exception with optional session ID
  static Future<String?> captureException(
    dynamic exception, {
    String? sessionId,
    dynamic stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    if (sessionId != null) {
      await setSessionId(sessionId);
    }

    final eventId = await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: Hint.withMap(extra ?? {}),
    );
    return eventId.toString();
  }

  /// Capture a message with optional session ID
  static Future<String?> captureMessage(
    String message, {
    String? sessionId,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extra,
  }) async {
    if (sessionId != null) {
      await setSessionId(sessionId);
    }

    final eventId = await Sentry.captureMessage(
      message,
      level: level,
      hint: Hint.withMap(extra ?? {}),
    );
    return eventId.toString();
  }
}

