import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/clock_provider.dart';
import '../../packs/data/pack_providers.dart';
import '../../packs/domain/entities/study_question.dart';
import '../../progress/data/progress_providers.dart';
import '../../progress/domain/entities/answer.dart';
import '../../progress/domain/entities/study_session.dart';
import '../domain/practice_session_config.dart';
import 'practice_providers.dart';

part 'practice_session_controller.g.dart';

/// Estado de una sesión de práctica en pantalla.
class PracticeSessionState {
  const PracticeSessionState({
    required this.session,
    required this.questions,
    required this.answers,
    required this.index,
  });

  final StudySession session;

  /// Preguntas de la sesión en orden, sin anuladas.
  final List<StudyQuestion> questions;

  /// Respuesta de cada pregunta ya respondida, por id de pregunta.
  final Map<String, Answer> answers;

  /// Pregunta en pantalla. Al reanudar, la primera sin responder; si ya
  /// estaban todas respondidas, la última (con su feedback y «Ver resumen»).
  final int index;

  StudyQuestion get current => questions[index];

  /// Respuesta de la pregunta en pantalla; `null` si aún no se ha respondido.
  Answer? get currentAnswer => answers[current.id];

  /// Índice de la siguiente pregunta sin responder; `null` si no queda.
  int? get nextIndex {
    for (var i = index + 1; i < questions.length; i++) {
      if (!answers.containsKey(questions[i].id)) return i;
    }
    return null;
  }

  /// No queda ninguna pregunta que mostrar (p. ej. el pack se actualizó y
  /// anuló todas las de la sesión).
  bool get isEmpty => questions.isEmpty;

  PracticeSessionState copyWith({Map<String, Answer>? answers, int? index}) =>
      PracticeSessionState(
        session: session,
        questions: questions,
        answers: answers ?? this.answers,
        index: index ?? this.index,
      );
}

/// Sesión de práctica [sessionId]. Todo sale de la base de datos (preguntas
/// de la configuración y respuestas ya guardadas), así que al recargar la
/// página se continúa por la primera pregunta sin responder.
@riverpod
class PracticeSessionController extends _$PracticeSessionController {
  /// Cuándo se mostró la pregunta actual, para medir el tiempo de respuesta.
  DateTime? _shownAt;
  bool _saving = false;

  /// `null` si la sesión no existe.
  @override
  Future<PracticeSessionState?> build(String sessionId) async {
    final progress = ref.watch(progressRepositoryProvider);
    final session = await progress.findSession(sessionId);
    if (session == null) return null;

    final config = PracticeSessionConfig.fromJson(session.config);
    final questions = await ref
        .watch(packContentRepositoryProvider)
        .questionsByIds(session.packId, config.questionIds);
    final answers = <String, Answer>{};
    for (final answer in await progress.sessionAnswers(sessionId)) {
      answers.putIfAbsent(answer.questionId, () => answer);
    }
    // Si el pack se actualizó y anuló alguna pregunta, se salta.
    final playable = [
      for (final q in questions)
        if (!q.question.voided) q,
    ];
    final firstPending = playable.indexWhere((q) => !answers.containsKey(q.id));

    _shownAt = ref.read(clockProvider)();
    return PracticeSessionState(
      session: session,
      questions: playable,
      answers: answers,
      index: firstPending == -1 ? max(playable.length - 1, 0) : firstPending,
    );
  }

  /// Responde la pregunta actual; [chosen] `null` = en blanco («Saltar»).
  /// Ignora toques repetidos mientras se guarda o si ya está respondida.
  Future<void> answer(String? chosen) async {
    final current = state.value;
    if (current == null || current.isEmpty || _saving) return;
    if (current.session.isFinished || current.currentAnswer != null) return;

    _saving = true;
    try {
      final now = ref.read(clockProvider)();
      final saved = await ref.read(answerPracticeQuestionProvider)(
        session: current.session,
        question: current.current,
        chosen: chosen,
        timeMs: now.difference(_shownAt ?? now).inMilliseconds,
      );
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          answers: {...current.answers, saved.questionId: saved},
        ),
      );
    } finally {
      _saving = false;
    }
  }

  /// Pasa a la siguiente pregunta sin responder. Si no queda ninguna,
  /// termina la sesión y devuelve `true` (la pantalla abre el resumen).
  Future<bool> next() async {
    final current = state.value;
    if (current == null) return true;
    final nextIndex = current.nextIndex;
    if (nextIndex == null) {
      await finish();
      return true;
    }
    _shownAt = ref.read(clockProvider)();
    state = AsyncData(current.copyWith(index: nextIndex));
    return false;
  }

  /// Termina la sesión ya (las que falten quedan «sin responder»).
  Future<void> finish() =>
      ref.read(progressRepositoryProvider).finishSession(sessionId);
}
