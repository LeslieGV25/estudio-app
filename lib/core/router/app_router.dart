import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/exam/presentation/exam_session_page.dart';
import '../../features/exam/presentation/exam_setup_page.dart';
import '../../features/exam/presentation/exam_summary_page.dart';
import '../../features/packs/presentation/packs_page.dart';
import '../../features/practice/presentation/practice_session_page.dart';
import '../../features/practice/presentation/practice_setup_page.dart';
import '../../features/practice/presentation/session_summary_page.dart';
import '../../features/review/presentation/review_page.dart';
import '../domain/session_mode.dart';

part 'app_router.g.dart';

// Sesión y resumen son hermanas bajo /practice y /review (no anidadas):
// «atrás» desde el resumen vuelve a la configuración o a la pantalla de
// repaso, no a una sesión ya terminada.
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
            // `?tema=N`: empieza con ese tema marcado («Practicar este tema»).
            builder: (context, state) => PracticeSetupPage(
              topicId: int.tryParse(state.uri.queryParameters['tema'] ?? ''),
            ),
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
          GoRoute(
            path: 'exam',
            name: 'exam',
            builder: (context, state) => const ExamSetupPage(),
            routes: [
              GoRoute(
                path: 'session/:sessionId',
                name: 'exam-session',
                builder: (context, state) => ExamSessionPage(
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
              GoRoute(
                path: 'summary/:sessionId',
                name: 'exam-summary',
                builder: (context, state) => ExamSummaryPage(
                  sessionId: state.pathParameters['sessionId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'review',
            name: 'review',
            builder: (context, state) => const ReviewPage(),
            routes: [
              GoRoute(
                path: 'session/:sessionId',
                name: 'review-session',
                builder: (context, state) => PracticeSessionPage(
                  sessionId: state.pathParameters['sessionId']!,
                  mode: SessionMode.review,
                ),
              ),
              GoRoute(
                path: 'summary/:sessionId',
                name: 'review-summary',
                builder: (context, state) => SessionSummaryPage(
                  sessionId: state.pathParameters['sessionId']!,
                  mode: SessionMode.review,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
