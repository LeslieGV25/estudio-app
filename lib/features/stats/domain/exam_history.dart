import 'package:decimal/decimal.dart';

import '../../exam/domain/exam_setup.dart';
import '../../exam/domain/usecases/load_exam_result.dart';

/// Un simulacro hecho (completo o de un ejercicio), con su resultado.
class ExamHistoryEntry {
  const ExamHistoryEntry({
    required this.result,
    required this.setup,
    this.sourceName,
  });

  final ExamResult result;
  final ExamSetup setup;

  /// Examen elegido (solo en [ExamKind.realExam]); `null` si ya no está en
  /// el pack.
  final String? sourceName;

  DateTime get startedAt => result.firstSession.startedAt;

  String get firstSessionId => result.firstSession.id;

  /// Todos los ejercicios en vez de uno suelto.
  bool get isFull => setup.exerciseId == null;

  /// Hay algún ejercicio empezado y sin entregar.
  bool get inProgress =>
      result.parts.any((p) => p.status == ExamPartStatus.inProgress);
}

/// Nota de un ejercicio entregado y corregido.
class ExamScorePoint {
  const ExamScorePoint({
    required this.firstSessionId,
    required this.submittedAt,
    required this.score,
    required this.passed,
  });

  /// Primera sesión del simulacro, para abrir su resultado.
  final String firstSessionId;
  final DateTime submittedAt;
  final Decimal score;

  /// `null` si el ejercicio no tiene nota mínima.
  final bool? passed;
}

/// Evolución de la nota de un ejercicio de simulacro.
class ExamScoreSeries {
  const ExamScoreSeries({
    required this.exerciseId,
    required this.name,
    required this.passMark,
    required this.points,
  });

  final String exerciseId;
  final String name;

  /// Nota mínima de la entrega más reciente (las reglas se copian en cada
  /// simulacro y podrían cambiar); `null` si no tiene.
  final Decimal? passMark;

  /// En orden de entrega.
  final List<ExamScorePoint> points;
}

/// Historial de simulacros de un pack.
class ExamHistory {
  ExamHistory._(this.entries, this.series);

  /// [entries] en cualquier orden; [exerciseOrder] son los ejercicios del
  /// simulacro del pack en su orden (los que ya no estén van al final).
  ///
  /// Solo entran en las series los ejercicios corregidos y con nota: los
  /// «no corregidos», sin entregar o sin puntuación no tienen nota.
  factory ExamHistory.from(
    List<ExamHistoryEntry> entries, {
    required List<String> exerciseOrder,
  }) {
    final chronological = [...entries]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final names = <String, String>{};
    final passMarks = <String, Decimal?>{};
    final points = <String, List<ExamScorePoint>>{};
    for (final entry in chronological) {
      for (final part in entry.result.parts) {
        final score = part.score;
        final submittedAt = part.session?.finishedAt;
        if (part.status != ExamPartStatus.graded ||
            score == null ||
            submittedAt == null) {
          continue;
        }
        final id = part.paper.exerciseId;
        names[id] = part.paper.name;
        passMarks[id] = score.passMark;
        points
            .putIfAbsent(id, () => [])
            .add(
              ExamScorePoint(
                firstSessionId: entry.firstSessionId,
                submittedAt: submittedAt,
                score: score.rounded,
                passed: score.passed,
              ),
            );
      }
    }

    int rank(String id) {
      final i = exerciseOrder.indexOf(id);
      return i == -1 ? exerciseOrder.length : i;
    }

    final ids = points.keys.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    final series = [
      for (final id in ids)
        ExamScoreSeries(
          exerciseId: id,
          name: names[id]!,
          passMark: passMarks[id],
          points: List.unmodifiable(points[id]!),
        ),
    ];
    return ExamHistory._(
      List.unmodifiable(chronological.reversed),
      List.unmodifiable(series),
    );
  }

  /// Del más reciente al más antiguo.
  final List<ExamHistoryEntry> entries;

  /// Una serie por ejercicio, en el orden del simulacro del pack.
  final List<ExamScoreSeries> series;
}
