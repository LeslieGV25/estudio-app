import 'dart:math';

import '../../packs/domain/entities/study_question.dart';

/// Ordena al azar [candidates] para una sesión y recorta a [limit].
///
/// Las preguntas que comparten contexto (un supuesto) forman un grupo que
/// se mantiene junto y en su orden original; lo que se baraja son los grupos.
/// Las preguntas sin contexto son grupos de una.
///
/// Recorte: se recorren los grupos barajados y se toma cada uno que quepa
/// entero; el que no cabe se salta y se prueba con el siguiente, así que la
/// sesión puede quedar con menos de [limit] preguntas. Solo si no cabe ningún
/// grupo entero (p. ej. límite 3 y solo supuestos de 5) se corta el primero.
List<StudyQuestion> practiceOrder(
  List<StudyQuestion> candidates, {
  int? limit,
  required Random random,
}) {
  final groups = _groupByContext(candidates)..shuffle(random);
  if (limit == null) return [for (final g in groups) ...g];
  if (limit <= 0 || groups.isEmpty) return const [];

  final selected = <StudyQuestion>[];
  for (final group in groups) {
    if (selected.length + group.length <= limit) selected.addAll(group);
    if (selected.length == limit) break;
  }
  return selected.isEmpty ? groups.first.take(limit).toList() : selected;
}

List<List<StudyQuestion>> _groupByContext(List<StudyQuestion> questions) {
  final sorted = [...questions]
    ..sort((a, b) => a.position.compareTo(b.position));
  final groups = <List<StudyQuestion>>[];
  final byContext = <String, List<StudyQuestion>>{};
  for (final q in sorted) {
    final contextId = q.question.contextId;
    if (contextId == null) {
      groups.add([q]);
      continue;
    }
    // El grupo entra en `groups` al ver su primera pregunta (eso fija su
    // sitio antes de barajar) y se sigue llenando por referencia.
    final group = byContext.putIfAbsent(contextId, () {
      final created = <StudyQuestion>[];
      groups.add(created);
      return created;
    });
    group.add(q);
  }
  return groups;
}
