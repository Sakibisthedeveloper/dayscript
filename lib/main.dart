import 'firebase_options.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'domain/entities/diary_entry.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/diary/diary_bloc.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firebase_diary_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/diary_usecases.dart';
import 'core/theme/theme_cubit.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/sign_in_screen.dart';
import 'presentation/screens/editor_screen.dart';
import 'presentation/screens/view_entry_screen.dart';
import 'presentation/screens/calendar_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/export_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch(e) {
    // Handling error silently or via logs
  }
  
  final authRepository = FirebaseAuthRepository();
  final diaryRepository = FirebaseDiaryRepository();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(
            getUserStream: GetUserStream(authRepository),
            signInWithGoogle: SignInWithGoogle(authRepository),
            signOut: SignOut(authRepository),
          ),
        ),
        BlocProvider(
          create: (context) => DiaryBloc(
            getEntries: GetEntries(diaryRepository),
            saveEntry: SaveEntry(diaryRepository),
            deleteEntry: DeleteEntry(diaryRepository),
            getWeeklyPulse: GetWeeklyPulse(diaryRepository),
          ),
        ),
        BlocProvider(
          create: (context) => ThemeCubit(),
        ),
      ],
      child: const DayScriptApp(),
    ),
  );
}

class DayScriptApp extends StatefulWidget {
  const DayScriptApp({super.key});

  @override
  State<DayScriptApp> createState() => _DayScriptAppState();
}

class _DayScriptAppState extends State<DayScriptApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: GoRouterRefreshStream(context.read<AuthBloc>().stream),
      redirect: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final bool loggingIn = state.matchedLocation == '/login';
        final bool isSplash = state.matchedLocation == '/splash';

        if (isSplash) return null;

        if (authState is! Authenticated) {
          return loggingIn ? null : '/login';
        }

        if (loggingIn) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: SplashScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: HomeScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: SignInScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: ProfileScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
        GoRoute(
          path: '/editor',
          pageBuilder: (context, state) {
            final existingEntry = state.extra as DiaryEntry?;
            return CustomTransitionPage(
              child: EditorScreen(entry: existingEntry),
              transitionsBuilder: _slideUpTransition,
            );
          },
        ),
        GoRoute(
          path: '/entry',
          pageBuilder: (context, state) {
            final entry = state.extra as DiaryEntry;
            return CustomTransitionPage(
              child: ViewEntryScreen(entry: entry),
              transitionsBuilder: _slideTransition,
            );
          },
        ),
        GoRoute(
          path: '/calendar',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: CalendarScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: SearchScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
        GoRoute(
          path: '/export',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: ExportScreen(),
            transitionsBuilder: _fadeTransition,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp.router(
          title: 'DayScript',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

Widget _fadeTransition(context, animation, secondaryAnimation, child) {
  return FadeTransition(opacity: animation, child: child);
}

Widget _slideTransition(context, animation, secondaryAnimation, child) {
  return SlideTransition(
    position: animation.drive(
      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)),
    ),
    child: child,
  );
}

Widget _slideUpTransition(context, animation, secondaryAnimation, child) {
  return SlideTransition(
    position: animation.drive(
      Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)),
    ),
    child: child,
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
