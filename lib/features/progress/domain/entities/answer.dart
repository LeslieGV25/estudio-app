import 'package:freezed_annotation/freezed_annotation.dart';

part 'answer.freezed.dart';

/// Respuesta a una pregunta: evento inmutable, nunca se modifica ni se borra.
@freezed
abstract class Answer with _$Answer {
  const Answer._();

  const factory Answer({
    required String id,
    required String sessionId,
    required String packId,
    required String questionId,

    /// Letra elegida; `null` = en blanco.
    String? chosen,
    required bool isCorrect,
    required int timeMs,
    required DateTime answeredAt,
  }) = _Answer;

  bool get isBlank => chosen == null;
}
