import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Localization will be generated - temporarily commented out
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'core/auth_service.dart';
import 'core/local_backend_service.dart';
import 'core/backend_url_helper.dart';
import 'core/hardware_detector.dart';
import 'core/ml_http_server.dart';
import 'core/supabase_state.dart';
import 'shared/accessibility_service.dart';
import 'dart:io';

void main() async {
  // Initialize bindings first to establish the zone before Sentry
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Mobile Ads SDK
  if (!kIsWeb) {
    unawaited(MobileAds.instance.initialize());
  }
  
  // Load .env file (if it exists). This must run on *all* platforms before any
  // access to `dotenv.env`, otherwise flutter_dotenv throws NotInitializedError.
  //
  // For web: attempting to load a missing asset prints a noisy 404 to the
  // console even when marked optional. We still want dotenv to be initialized,
  // so we just initialize it with an empty env map and rely on --dart-define.
  if (kIsWeb) {
    dotenv.testLoad(fileInput: '');
  } else {
    try {
      final localOverrides = await _loadLocalEnvOverrides();
      await dotenv.load(
        fileName: '.env',
        isOptional: true,
        mergeWith: localOverrides,
      );
      print('✁EEnvironment variables loaded successfully');
    } catch (e) {
      print('⚠�E�EError loading .env file: $e');
      // Initialize with empty config to prevent NotInitializedError
      dotenv.testLoad(fileInput: '');
    }
  }

  // On Flutter Web, we should not crash if Sentry is not configured.
  final sentryDsn = dotenv.env['SENTRY_DSN'] ??
      const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: '',
      );

  if (kIsWeb && sentryDsn.isEmpty) {
    // Skip Sentry entirely on web if DSN isn't provided.
    runApp(const MyApp());
    return;
  }

  await SentryFlutter.init(
    (options) {
      // Get Sentry DSN from .env file or --dart-define, with fallback to empty string
      if (sentryDsn.isNotEmpty) {
        options.dsn = sentryDsn;
        options.tracesSampleRate =
            0.2; // Capture 20% of transactions for performance monitoring
        options.environment = dotenv.env['ENVIRONMENT'] ??
            const String.fromEnvironment(
              'ENVIRONMENT',
              defaultValue: 'development',
            );
      } else {
        // Disable Sentry if DSN is not provided (non-web builds can safely continue).
        options.dsn = '';
      }
    },
    appRunner: () async {
      // Bindings already initialized before Sentry.init to avoid zone mismatch
      
      // Detect hardware capabilities and set environment variables
      // This must happen before backend initialization
      Map<String, String> hardwareEnvVars = {};
      if (!kIsWeb) {
        try {
          final hardwareDetector = HardwareDetector.instance;
          hardwareEnvVars = await hardwareDetector.detectHardware();
          print('🔍 Hardware Detection Results:');
          print('  Platform: ${hardwareEnvVars['MOBILE_PLATFORM']}');
          print('  Tensor Chip: ${hardwareEnvVars['HAS_TENSOR_CHIP']}');
          print('  Neural Engine: ${hardwareEnvVars['HAS_NEURAL_ENGINE']}');
          print('  TFLite Models: ${hardwareEnvVars['HAS_TFLITE_MODELS']}');
          print('  Core ML Models: ${hardwareEnvVars['HAS_COREML_MODELS']}');
        } catch (e) {
          print('⚠�E�EHardware detection failed: $e');
          // Set defaults if detection fails
          hardwareEnvVars = {
            'MOBILE_PLATFORM': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
            'HAS_TENSOR_CHIP': 'false',
            'HAS_NEURAL_ENGINE': 'false',
            'HAS_TFLITE_MODELS': 'false',
            'HAS_COREML_MODELS': 'false',
          };
        }
      }
      
      // Check if external backend URL is provided from --dart-define (highest priority) or .env
      // --dart-define takes precedence over .env file
      final dartDefineBackendUrl = const String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: '',
      );
      final envBackendUrl = dotenv.env['BACKEND_URL'] ?? '';
      
      print('🔍 Backend URL resolution:');
      print('  --dart-define BACKEND_URL: "$dartDefineBackendUrl"');
      print('  .env BACKEND_URL: "$envBackendUrl"');
      
      final rawBackendUrl = dartDefineBackendUrl.isNotEmpty
          ? dartDefineBackendUrl
          : envBackendUrl;

      print('✁EUsing backend URL: "$rawBackendUrl"');

      // Process backend URL (handles Android emulator localhost conversion)
      final externalBackendUrl = BackendUrlHelper.processUrl(rawBackendUrl);

      print('Processed backend URL: "$externalBackendUrl"');

      // Only start local backend if no external backend is configured and not on web
      // Check the RAW URL to determine if it's local (before Android emulator conversion)
      final isLocalBackend = rawBackendUrl.isEmpty || 
          rawBackendUrl == 'http://localhost:8080' ||
          rawBackendUrl == 'http://127.0.0.1:8080';
          
      if (isLocalBackend && !kIsWeb) {
        // Start ML HTTP server for native ML inference (runs on port 8081)
        // This allows the backend to call native ML via HTTP
        try {
          final mlServer = MLHttpServer();
          await mlServer.start();
          print('✁EML HTTP server started at: ${mlServer.baseUrl}');
        } catch (e) {
          print('⚠�E�EFailed to start ML HTTP server: $e');
          // Continue anyway - backend will fall back to GGUF models
        }
        
        // Start local backend server - wait for it to be ready
        // This ensures the backend is available before the app makes requests
        // Pass hardware environment variables to backend
        final localBackend = LocalBackendService();
        localBackend.hardwareEnvVars = hardwareEnvVars;
        try {
          await localBackend.start();
          print('✁ELocal backend started at: ${localBackend.baseUrl}');
        } catch (e) {
          print('⚠�E�EFailed to start local backend: $e');
          // Continue anyway - the app will show errors if backend isn't available
        }
      } else if (!isLocalBackend) {
        print('! Using external backend: $externalBackendUrl');
        print('! Make sure the backend is running on the host machine!');
        // Note: For external backend, hardware detection would need to be passed
        // via request headers or backend would detect from User-Agent
      } else if (kIsWeb) {
        print('⚠�E�ERunning on web - local backend not available. Configure BACKEND_URL for web.');
      }

      // Initialize Supabase with configuration from .env or --dart-define
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
          const String.fromEnvironment(
            'SUPABASE_URL',
            defaultValue: '',
          );
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
          const String.fromEnvironment(
            'SUPABASE_ANON_KEY',
            defaultValue: '',
          );

      // Supabase is optional when using local backend
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        SupabaseState.isInitialized = true;

        // Set user context from Supabase auth if available
        final authService = AuthService();
        if (authService.isLoggedIn && authService.currentUser != null) {
          final user = authService.currentUser!;
          await Sentry.configureScope((scope) {
            scope.setUser(SentryUser(id: user.id, email: user.email));
          });
        }
      }

      // Run app - zone mismatch warning is non-fatal on web
      runApp(const MyApp());
    },
  );
}

Future<Map<String, String>> _loadLocalEnvOverrides() async {
  try {
    final envContents = await rootBundle.loadString('.env.local');
    if (envContents.trim().isEmpty) {
      return const {};
    }
    return const Parser().parse(envContents.split('\n'));
  } on Exception {
    // File doesn't exist in assets or other issues, which is fine
    return const {};
  } catch (e) {
    // Fallback for any other parsing errors
    print('⚠�E�EFailed to load .env.local overrides: $e');
    return const {};
  }
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
    const appFontFallback = <String>[
      // Covers a lot of symbols and “missing glyph Ecases.
      'NotoSansSymbols2',
      // Emoji fallback. Note: on Flutter Web, emoji rendering may still depend
      // on the active renderer/platform, but keeping this helps on native.
      'NotoColorEmoji',
    ];

    TextTheme _applyAppFonts(TextTheme t) => t.copyWith(
          displayLarge: t.displayLarge?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          displayMedium: t.displayMedium?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          displaySmall: t.displaySmall?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          headlineLarge: t.headlineLarge?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          headlineMedium: t.headlineMedium?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          headlineSmall: t.headlineSmall?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          titleLarge: t.titleLarge?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          titleMedium: t.titleMedium?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          titleSmall: t.titleSmall?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          bodyLarge: t.bodyLarge?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          bodyMedium: t.bodyMedium?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          bodySmall: t.bodySmall?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          labelLarge: t.labelLarge?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          labelMedium: t.labelMedium?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
          labelSmall: t.labelSmall?.copyWith(
            fontFamily: 'NotoSans',
            fontFamilyFallback: appFontFallback,
          ),
        );

    final baseTheme = ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'NotoSans',
      fontFamilyFallback: appFontFallback,
    );

    final theme = _highContrast || _fontScale != 1.0
        ? _accessibilityService.getAccessibilityTheme(
            baseTheme: baseTheme,
            highContrast: _highContrast,
            fontScale: _fontScale,
          )
        : baseTheme;

    final themedWithFonts = theme.copyWith(
      textTheme: _applyAppFonts(theme.textTheme),
      primaryTextTheme: _applyAppFonts(theme.primaryTextTheme),
    );

    return MaterialApp(
      title: 'DreamFlow AI',
      theme: themedWithFonts,
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
    // Handle OAuth callback errors gracefully (for web)
    // If there's an error in the URL fragment, ignore it and proceed to login
    try {
      final uri = Uri.base;
      if (uri.hasFragment) {
        final fragment = uri.fragment;
        // If there's an authentication error, just proceed to show login screen
        // Don't try to process invalid OAuth callbacks
        if (fragment.contains('error=') || fragment.contains('error_description=')) {
          // Clear loading and show login screen
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      // Ignore errors - just proceed to show login screen
      print('Auth check error (non-critical): $e');
    }

    // If Supabase isn't configured, we can't subscribe to auth events; just
    // stop loading and show the login screen (or whatever the app decides).
    if (!SupabaseState.isInitialized) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Listen to auth state changes only if Supabase is configured/initialized.
    // Otherwise `Supabase.instance` asserts and crashes in debug/web.
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
