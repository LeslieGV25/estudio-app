import '../../packs/domain/entities/pack_document.dart';

/// `true` si [chosen] es la respuesta correcta. En blanco (`null`) nunca lo
/// es, y una anulada tampoco: no tiene respuesta correcta y no puntúa.
bool isCorrectAnswer(Question question, String? chosen) =>
    !question.voided && chosen != null && chosen == question.correctKey;
