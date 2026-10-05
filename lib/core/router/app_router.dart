import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/packs/presentation/packs_page.dart';
import '../../features/practice/presentation/practice_session_page.dart';
import '../../features/practice/presentation/practice_setup_page.dart';
import '../../features/practice/presentation/session_summary_page.dart';
import '../domain/session_mode.dart';

part 'app_router.g.dart';

// Sesión y resumen son hermanas bajo /practice (no anidadas): «atrás» desde
// el resumen vuelve a la configuración, no a una sesión ya terminada.
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'packs',
        builder: (context, state) => const PacksPage(),
        routes: [
          GoRoute(
            path: 'practice',
            name: 'practice',
            builder: (context, state) => const PracticeSetupPage(),
            routes: [
              GoRoute(
                path: 'session/:sessionId',
                name: 'practice-session',
                builder: (context, state) => PracticeSessionPage(
                  sessionId: state.pathParameters['sessionId']!,
                  mode: SessionMode.practice,
                ),
              ),
              GoRoute(
                path: 'summary/:sessionId',
                name: 'practice-summary',
                builder: (context, state) => SessionSummaryPage(
                  sessionId: state.pathParameters['sessionId']!,
                  mode: SessionMode.practice,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
