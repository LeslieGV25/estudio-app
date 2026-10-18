import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/clock_provider.dart';
import '../../packs/data/pack_providers.dart';
import '../../packs/domain/entities/study_question.dart';
import '../../progress/data/progress_providers.dart';
import '../../progress/domain/entities/study_session.dart';
import '../domain/exam_session_config.dart';
import 'exam_providers.dart';

part 'exam_session_controller.g.dart';

/// Un ejercicio de simulacro en pantalla.
class ExamSessionState {
  const ExamSessionState({
    required this.session,
    required this.config,
    required this.questions,
  });

  final StudySession session;

  /// Configuración con el borrador al día (lo que se ve en pantalla).
  final ExamSessionConfig config;

  /// Preguntas del ejercicio en orden. Las que el pack ya no tenga se omiten.
  final List<StudyQuestion> questions;

  bool get isEmpty => questions.isEmpty;

  int get index => config.currentIndex.clamp(0, questions.length - 1);

  StudyQuestion get current => questions[index];

  String? get currentChoice => config.choices[current.id];

  /// `null` si el ejercicio no tiene tiempo.
  DateTime? get deadline => config.deadline(session.startedAt);

  /// Entregado y con otro ejercicio después.
  bool get hasNextPart => session.isFinished && config.nextSessionId != null;

  ExamSessionState withConfig(ExamSessionConfig config) =>
      ExamSessionState(session: session, config: config, questions: questions);
}

/// Ejercicio de simulacro [sessionId]. El borrador (opciones marcadas,
/// tiempo por pregunta y pregunta abierta) se guarda en la base de datos con
/// cada cambio: al recargar la página se sigue igual, con el temporizador
/// contando desde `started_at`.
@riverpod
class ExamSessionController extends _$ExamSessionController {
  /// Cuándo se mostró la pregunta actual, para sumar su tiempo.
  DateTime? _shownAt;

  /// Escrituras del borrador en orden; entregar espera a la última.
  Future<void> _writes = Future.value();
  bool _submitting = false;

  /// `null` si la sesión no existe.
  @override
  Future<ExamSessionState?> build(String sessionId) async {
    final progress = ref.watch(progressRepositoryProvider);
    var session = await progress.findSession(sessionId);
    if (session == null) return null;

    // Si se vuelve cuando ya se acabó el tiempo, se entrega lo que había.
    final deadline = ExamSessionConfig.fromJson(session.config)
        .deadline(session.startedAt);
    final now = ref.read(clockProvider)();
    if (!session.isFinished && deadline != null && !now.isBefore(deadline)) {
      await ref.read(submitExamPartProvider)(sessionId);
      session = (await progress.findSession(sessionId))!;
    }

    final config = ExamSessionConfig.fromJson(session.config);
    final questions = await ref
        .watch(packContentRepositoryProvider)
        .questionsByIds(session.packId, config.paper.questionIds);
    _shownAt = now;
    return ExamSessionState(
      session: session,
      config: config,
      questions: questions,
    );
  }

  /// Marca [letter] en la pregunta actual; `null` la deja en blanco.
  void choose(String? letter) =>
      _update((s) => s.config.withChoice(s.current.id, letter));

  /// Abre la pregunta [index] (desde la rejilla o con anterior/siguiente).
  void goTo(int index) => _update((s) {
    if (index < 0 || index >= s.questions.length) return s.config;
    return s.config.copyWith(currentIndex: index);
  });

  /// Entrega el ejercicio (a mano o porque se acabó el tiempo) y recarga.
  /// Ignora llamadas repetidas.
  Future<void> submit() async {
    final current = state.value;
    if (current == null || current.session.isFinished || _submitting) return;
    _submitting = true;
    try {
      _update((s) => s.config); // suma el tiempo de la pregunta abierta
      await _writes;
      await ref.read(submitExamPartProvider)(sessionId);
      ref.invalidateSelf();
      await future;
    } finally {
      _submitting = false;
    }
  }

  /// Empieza (o retoma) el ejercicio siguiente; devuelve su sesión.
  Future<StudySession?> startNext() async {
    final current = state.value;
    if (current == null || !current.hasNextPart) return null;
    return ref.read(startExamProvider).next(current.session);
  }

  /// Aplica [change] al borrador sumando antes el tiempo de la pregunta
  /// abierta, lo muestra al momento y lo guarda en segundo plano.
  void _update(ExamSessionConfig Function(ExamSessionState) change) {
    final current = state.value;
    if (current == null || current.isEmpty || current.session.isFinished) {
      return;
    }
    final now = ref.read(clockProvider)();
    final elapsed = now.difference(_shownAt ?? now).inMilliseconds;
    _shownAt = now;
    final timed = current.withConfig(
      current.config.withTimeSpent(current.current.id, elapsed),
    );
    final updated = timed.withConfig(change(timed));
    state = AsyncData(updated);
    final json = updated.config.toJson();
    final progress = ref.read(progressRepositoryProvider);
    _writes = _writes.then(
      (_) => progress.updateSessionConfig(sessionId, json),
    );
  }
}
