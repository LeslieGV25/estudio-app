import '../../packs/domain/entities/pack_document.dart';

/// Letra con la que se corrige [question] en práctica: la correcta o, si
/// está anulada, la provisional (que se muestra con aviso). `null` si no hay
/// ninguna contra la que corregir.
String? practiceKey(Question question) =>
    question.voided ? question.provisionalKey : question.correctKey;

/// `true` si [chosen] es la respuesta buena. En blanco (`null`) nunca lo es.
bool isCorrectAnswer(Question question, String? chosen) =>
    chosen != null && chosen == practiceKey(question);
