import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_state.freezed.dart';

/// Estado de Leitner de una pregunta que ha entrado en el repaso.
///
/// Se deriva siempre de las respuestas (`Leitner.replay`); la tabla
/// `review_state` solo es una caché de este valor.
@freezed
abstract class ReviewState with _$ReviewState {
  const ReviewState._();

  const factory ReviewState({
    /// Caja de Leitner, de 0 a 4.
    required int box,

    /// Aciertos seguidos que han subido de caja.
    required int correctStreak,

    /// Desde cuándo toca repasarla (medianoche del día, en UTC).
    required DateTime nextDue,
  }) = _ReviewState;

  /// Dominada: 3 aciertos seguidos. Es solo una etiqueta; sigue en el repaso
  /// con intervalos largos.
  bool get isMastered => correctStreak >= masteredStreak;

  bool isDue(DateTime now) => !nextDue.isAfter(now);

  static const masteredStreak = 3;
}
