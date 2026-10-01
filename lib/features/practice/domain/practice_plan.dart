import 'dart:math';

import '../../packs/domain/entities/study_question.dart';
import 'practice_filter.dart';
import 'question_order.dart';

/// Preguntas elegidas para una sesión de práctica que aún no ha empezado.
///
/// Se calcula en la pantalla de configuración con cada cambio de filtro (es
/// Dart puro y rápido) y después se usa tal cual para crear la sesión: así el
/// número que ve la usuaria es el de la sesión que empieza.
class PracticePlan {
  const PracticePlan._({
    required this.filter,
    required this.questionIds,
    required this.available,
  });

  /// Filtra [questions] (todas las del pack) con [filter] y las ordena con
  /// [practiceOrder].
  factory PracticePlan.build(
    List<StudyQuestion> questions,
    PracticeFilter filter, {
    required Random random,
  }) {
    final candidates = questions.where(filter.matches).toList();
    final ordered = practiceOrder(
      candidates,
      limit: filter.questionCount,
      random: random,
    );
    return PracticePlan._(
      filter: filter,
      questionIds: List.unmodifiable([for (final q in ordered) q.id]),
      available: candidates.length,
    );
  }

  final PracticeFilter filter;

  /// Preguntas de la sesión, en orden.
  final List<String> questionIds;

  /// Preguntas que cumplen el filtro, antes de recortar.
  final int available;

  int get count => questionIds.length;
  bool get isEmpty => questionIds.isEmpty;

  /// Había preguntas de sobra para el nº pedido, pero la sesión sale más
  /// corta porque algún supuesto no cabía entero.
  bool get isShortenedByCaseStudy {
    final requested = filter.questionCount;
    return requested != null && available >= requested && count < requested;
  }
}
