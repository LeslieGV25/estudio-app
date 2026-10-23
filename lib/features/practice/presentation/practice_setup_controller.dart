import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/practice_filter.dart';
import '../domain/practice_plan.dart';
import 'practice_providers.dart';

part 'practice_setup_controller.g.dart';

/// Nº de preguntas por defecto al abrir la configuración.
const defaultQuestionCount = 20;

/// Filtro que la usuaria va eligiendo en la pantalla de configuración.
///
/// Con [topicId] (de la URL `/practice?tema=N`, p. ej. desde «Practicar este
/// tema» en las estadísticas) empieza con ese tema marcado. Cada valor es un
/// filtro distinto: el valor inicial sale de la URL y no hace falta
/// modificar el filtro desde otra pantalla antes de navegar.
@riverpod
class PracticeFilterController extends _$PracticeFilterController {
  @override
  PracticeFilter build({int? topicId}) =>
      PracticeFilter(questionCount: defaultQuestionCount, topicIds: {?topicId});

  void toggleTopic(int topicId) =>
      state = state.copyWith(topicIds: _toggle(state.topicIds, topicId));

  void toggleBlock(int blockId) =>
      state = state.copyWith(blockIds: _toggle(state.blockIds, blockId));

  void toggleSource(String sourceId) =>
      state = state.copyWith(sourceIds: _toggle(state.sourceIds, sourceId));

  void setOnlyOfficial(bool value) =>
      state = state.copyWith(onlyOfficial: value);

  void setIncludeObsolete(bool value) =>
      state = state.copyWith(includeObsolete: value);

  /// `null` = todas.
  void setQuestionCount(int? value) =>
      state = state.copyWith(questionCount: value);

  static Set<T> _toggle<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};
}

/// Preguntas que tendría la sesión con el filtro actual. Se recalcula (y se
/// vuelve a barajar) con cada cambio; «Empezar» usa exactamente este plan.
@riverpod
Future<PracticePlan> practicePlan(
  Ref ref,
  String packId, {
  int? topicId,
}) async {
  final filter = ref.watch(practiceFilterControllerProvider(topicId: topicId));
  final questions = await ref.watch(packQuestionsProvider(packId).future);
  return PracticePlan.build(
    questions,
    filter,
    random: ref.read(practiceRandomProvider),
  );
}

/// Aviso breve cuando la sesión sale más corta de lo pedido porque un
/// supuesto no cabía entero; `null` si no hace falta.
String? practicePlanNotice(PracticePlan plan) => plan.isShortenedByCaseStudy
    ? 'Se usarán ${plan.count}: un supuesto no cabía entero'
    : null;
