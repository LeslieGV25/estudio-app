import '../../packs/domain/entities/study_question.dart';
import 'leitner.dart';
import 'review_state.dart';

/// Una pregunta del repaso con su estado de Leitner.
class ReviewItem {
  const ReviewItem(this.question, this.state);

  final StudyQuestion question;
  final ReviewState state;
}

/// Situación del repaso de un pack en un instante: qué toca hoy y cómo
/// están repartidas las cajas.
///
/// Solo cuenta preguntas que se pueden estudiar: las anuladas, las obsoletas
/// y las que ya no están en el pack conservan su estado en la caché, pero
/// aquí no aparecen.
class ReviewOverview {
  ReviewOverview._(this.items, this.due);

  factory ReviewOverview.from(
    Map<String, ReviewState> states,
    List<StudyQuestion> questions,
    DateTime now,
  ) {
    final items = [
      for (final q in questions)
        if (states[q.id] case final state?
            when !q.question.voided && !q.question.obsolete)
          ReviewItem(q, state),
    ];
    // Primero las más atrasadas; a igualdad, la caja más baja y, al final,
    // el orden del pack (para que el resultado sea estable).
    final due = [
      for (final item in items)
        if (item.state.isDue(now)) item,
    ]..sort(_byPriority);
    return ReviewOverview._(List.unmodifiable(items), List.unmodifiable(due));
  }

  static int _byPriority(ReviewItem a, ReviewItem b) {
    final byDue = a.state.nextDue.compareTo(b.state.nextDue);
    if (byDue != 0) return byDue;
    final byBox = a.state.box.compareTo(b.state.box);
    if (byBox != 0) return byBox;
    return a.question.position.compareTo(b.question.position);
  }

  /// Todas las preguntas en el repaso, en el orden del pack.
  final List<ReviewItem> items;

  /// Pendientes hoy, en el orden en que se repasan.
  final List<ReviewItem> due;

  /// Nº de preguntas en cada caja (índice = caja).
  List<int> get boxCounts {
    final counts = List.filled(Leitner.intervalDays.length, 0);
    for (final item in items) {
      counts[item.state.box]++;
    }
    return counts;
  }

  int get mastered => items.where((i) => i.state.isMastered).length;

  /// Cuándo toca el siguiente repaso si hoy no queda nada; `null` si hay
  /// pendientes o el repaso está vacío.
  DateTime? get nextDue {
    if (due.isNotEmpty || items.isEmpty) return null;
    return items
        .map((i) => i.state.nextDue)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Ids de las [limit] primeras pendientes (todas si [limit] es `null`).
  List<String> dueIds({int? limit}) => [
    for (final item in limit == null ? due : due.take(limit)) item.question.id,
  ];
}
