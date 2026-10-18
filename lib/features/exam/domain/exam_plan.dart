import 'dart:math';

import '../../packs/domain/entities/pack_document.dart';
import '../../packs/domain/entities/pack_outline.dart';
import '../../packs/domain/entities/study_question.dart';
import '../../practice/domain/question_order.dart';
import 'exam_paper.dart';
import 'exam_setup.dart';

/// Ejercicios de un simulacro que aún no ha empezado.
///
/// Como en la práctica, se calcula en la pantalla de configuración (Dart
/// puro) y se usa tal cual al empezar: lo que se anuncia es lo que sale.
class ExamPlan {
  const ExamPlan._(this.setup, this.papers);

  /// Prepara los ejercicios pedidos en [setup] con las preguntas del pack
  /// ([questions], todas, en el orden del fichero).
  ///
  /// Los ejercicios sin ninguna pregunta se omiten (p. ej. un examen del
  /// pack del que solo se tiene el primer ejercicio).
  factory ExamPlan.build({
    required List<StudyQuestion> questions,
    required PackOutline outline,
    required ExamRules rules,
    required ExamSetup setup,
    required Random random,
  }) {
    final exercises = [
      for (final e in rules.exercises)
        if (setup.exerciseId == null || setup.exerciseId == e.id) e,
    ];
    final examExerciseOf = _examExerciseOf(outline);
    final papers = <ExamPaper>[];
    for (final exercise in exercises) {
      final ofExercise = [
        for (final q in questions)
          if (examExerciseOf[(q.question.sourceId, q.question.exerciseId)] ==
              exercise.id)
            q,
      ];
      final paper = switch (setup.kind) {
        ExamKind.realExam => _realPaper(exercise, ofExercise, setup),
        ExamKind.random => _randomPaper(exercise, ofExercise, setup, random),
      };
      if (paper.questionIds.isNotEmpty) papers.add(paper);
    }
    return ExamPlan._(setup, List.unmodifiable(papers));
  }

  final ExamSetup setup;

  /// Ejercicios en el orden del pack.
  final List<ExamPaper> papers;

  bool get isEmpty => papers.isEmpty;

  /// Fuentes que se pueden hacer como examen real: las que tienen algún
  /// ejercicio que equivale a uno del simulacro.
  static List<Source> realExamSources(PackOutline outline, ExamRules rules) {
    final ids = {for (final e in rules.exercises) e.id};
    return [
      for (final s in outline.sources)
        if (s.exercises.any((e) => ids.contains(e.examExerciseId))) s,
    ];
  }

  /// (fuente, ejercicio de la fuente) → ejercicio de simulacro.
  static Map<(String, String?), String> _examExerciseOf(PackOutline outline) =>
      {
        for (final s in outline.sources)
          for (final e in s.exercises)
            if (e.examExerciseId != null) (s.id, e.id): e.examExerciseId!,
      };

  /// Examen real: las preguntas de la fuente en su orden; las anuladas se
  /// quitan y cada una se sustituye por la siguiente reserva disponible, que
  /// va al final (como en el cuadernillo del examen). Las reservas que
  /// sobran no se muestran: no puntuarían.
  static ExamPaper _realPaper(
    ExamExercise exercise,
    List<StudyQuestion> ofExercise,
    ExamSetup setup,
  ) {
    bool usable(StudyQuestion q) =>
        !q.question.voided && (setup.includeObsolete || !q.question.obsolete);

    final fromSource = [
      for (final q in ofExercise)
        if (q.question.sourceId == setup.sourceId) q,
    ];
    final main = [
      for (final q in fromSource)
        if (!q.question.isReserve) q,
    ];
    final voided = [
      for (final q in main)
        if (q.question.voided) q.id,
    ];
    final reserves = [
      for (final q in fromSource)
        if (q.question.isReserve && usable(q)) q.id,
    ];
    final replacements = {
      for (final (i, id) in voided.take(reserves.length).indexed)
        id: reserves[i],
    };
    return ExamPaper(
      exerciseId: exercise.id,
      name: exercise.name,
      questionCount: exercise.questionCount,
      questionIds: [
        for (final q in main)
          if (usable(q)) q.id,
        ...replacements.values,
      ],
      voidedIds: voided,
      replacements: replacements,
      durationMin: exercise.durationMin,
      scoring: exercise.scoring,
    );
  }

  /// Aleatorio: [ExamExercise.questionCount] preguntas de todas las fuentes
  /// que equivalen al ejercicio. Las reservas entran como normales; los
  /// supuestos van enteros (ver [practiceOrder]).
  static ExamPaper _randomPaper(
    ExamExercise exercise,
    List<StudyQuestion> ofExercise,
    ExamSetup setup,
    Random random,
  ) {
    final pool = [
      for (final q in ofExercise)
        if (!q.question.voided &&
            (setup.includeObsolete || !q.question.obsolete) &&
            (!setup.onlyOfficial || q.isOfficial))
          q,
    ];
    final ordered = practiceOrder(
      pool,
      limit: exercise.questionCount,
      random: random,
    );
    return ExamPaper(
      exerciseId: exercise.id,
      name: exercise.name,
      questionCount: exercise.questionCount,
      questionIds: [for (final q in ordered) q.id],
      durationMin: exercise.durationMin,
      scoring: exercise.scoring,
    );
  }
}
