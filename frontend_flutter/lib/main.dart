import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Localization will be generated - temporarily commented out
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/accessibility_service.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      // Get Sentry DSN from environment or use empty string to disable
      final sentryDsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: '',
      );

      if (sentryDsn.isNotEmpty) {
        options.dsn = sentryDsn;
        options.tracesSampleRate =
            0.2; // Capture 20% of transactions for performance monitoring
        options.environment = const String.fromEnvironment(
          'ENVIRONMENT',
          defaultValue: 'development',
        );
      } else {
        // Disable Sentry if DSN is not provided
        options.dsn = '';
      }
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Supabase with configuration from --dart-define
      final supabaseUrl = const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: '',
      );
      final supabaseAnonKey = const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      );

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception(
          'Missing required configuration. Please provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.\n'
          'Example: flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key',
        );
      }

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

      // Set user context from Supabase auth if available
      final authService = AuthService();
      if (authService.isLoggedIn && authService.currentUser != null) {
        final user = authService.currentUser!;
        await Sentry.configureScope((scope) {
          scope.setUser(SentryUser(id: user.id, email: user.email));
        });
      }

      runApp(const MyApp());
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _accessibilityService = AccessibilityService();
  bool _highContrast = false;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadAccessibilitySettings();
  }

  Future<void> _loadAccessibilitySettings() async {
    final highContrast = await _accessibilityService.getHighContrast();
    final fontScale = await _accessibilityService.getFontScale();
    if (mounted) {
      setState(() {
        _highContrast = highContrast;
        _fontScale = fontScale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.dark,
      useMaterial3: true,
    );

    final theme = _highContrast || _fontScale != 1.0
        ? _accessibilityService.getAccessibilityTheme(
            baseTheme: baseTheme,
            highContrast: _highContrast,
            fontScale: _fontScale,
          )
        : baseTheme;

    return MaterialApp(
      title: 'Dream Flow',
      theme: theme,
      localizationsDelegates: const [
        // AppLocalizations.delegate, // Uncomment after running: flutter gen-l10n
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('es', ''), // Spanish
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(_fontScale)),
          child: child!,
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // Check if user was previously logged in
    final wasLoggedIn = await _authService.wasLoggedIn();
    if (!wasLoggedIn) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Check if user is currently logged in
    if (_authService.isLoggedIn) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
