import 'package:freezed_annotation/freezed_annotation.dart';

part 'pack_document.freezed.dart';
part 'pack_document.g.dart';

/// Contenido completo de un fichero `*.pack.json` (formato v1).
///
/// Las claves del JSON están en español (`docs/formato-pack.md`) y los campos
/// en inglés según el glosario de `CLAUDE.md`: `@JsonKey` hace de traductor,
/// así el formato del fichero y los nombres del código evolucionan por separado.
///
/// Solo se construye con [PackDocument.fromJson] **después** de pasar el
/// `PackValidator`: el parseo asume que la estructura ya es correcta.
@freezed
abstract class PackDocument with _$PackDocument {
  const factory PackDocument({
    @JsonKey(name: 'formato') required String format,
    @JsonKey(name: 'version_formato') required int formatVersion,
    @JsonKey(name: 'pack') required PackInfo info,
    @JsonKey(name: 'temario') required Syllabus syllabus,
    @JsonKey(name: 'fuentes') required List<Source> sources,
    @JsonKey(name: 'preguntas') required List<Question> questions,
    @JsonKey(name: 'contextos')
    @Default(<QuestionContext>[])
    List<QuestionContext> contexts,
    @JsonKey(name: 'simulacro') ExamRules? examRules,
    @JsonKey(name: 'apuntes') @Default(<Note>[]) List<Note> notes,
  }) = _PackDocument;

  factory PackDocument.fromJson(Map<String, dynamic> json) =>
      _$PackDocumentFromJson(json);
}

enum PackType {
  @JsonValue('oposicion')
  competitiveExam,
  @JsonValue('curso')
  course,
  @JsonValue('certificacion')
  certification,
  @JsonValue('otro')
  other,
}

@freezed
abstract class PackInfo with _$PackInfo {
  const factory PackInfo({
    required String id,
    @JsonKey(name: 'nombre') required String name,
    @JsonKey(name: 'descripcion') String? description,
    required String version,
    @JsonKey(name: 'tipo') required PackType type,
    @JsonKey(name: 'idioma') required String language,
    @JsonKey(name: 'autor') String? author,

    /// Fecha `AAAA-MM-DD` tal cual viene en el pack (solo informativa).
    @JsonKey(name: 'actualizado') String? updatedOn,
  }) = _PackInfo;

  factory PackInfo.fromJson(Map<String, dynamic> json) =>
      _$PackInfoFromJson(json);
}

@freezed
abstract class Syllabus with _$Syllabus {
  const factory Syllabus({
    @JsonKey(name: 'bloques') required List<Block> blocks,
    @JsonKey(name: 'temas') required List<Topic> topics,
  }) = _Syllabus;

  factory Syllabus.fromJson(Map<String, dynamic> json) =>
      _$SyllabusFromJson(json);
}

@freezed
abstract class Block with _$Block {
  const factory Block({
    required int id,
    @JsonKey(name: 'nombre') required String name,
  }) = _Block;

  factory Block.fromJson(Map<String, dynamic> json) => _$BlockFromJson(json);
}

@freezed
abstract class Topic with _$Topic {
  const factory Topic({
    required int id,
    @JsonKey(name: 'bloque') required int blockId,
    @JsonKey(name: 'titulo') required String title,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}

enum SourceType {
  @JsonValue('examen')
  exam,
  @JsonValue('estudio')
  study,
}

/// Procedencia de las respuestas correctas de una fuente.
enum AnswersOrigin {
  @JsonValue('plantilla_definitiva')
  officialFinalKey,
  @JsonValue('plantilla_provisional')
  officialProvisionalKey,
  @JsonValue('marcadas_en_examen')
  markedDuringExam,
  @JsonValue('elaboracion_propia')
  selfMade,
}

@freezed
abstract class Source with _$Source {
  const factory Source({
    required String id,
    @JsonKey(name: 'tipo') required SourceType type,
    @JsonKey(name: 'nombre') required String name,

    /// `true` solo si las respuestas vienen de una plantilla oficial.
    @JsonKey(name: 'oficial') required bool isOfficial,
    @JsonKey(name: 'fecha') String? date,
    @JsonKey(name: 'convocatoria') String? call,
    @JsonKey(name: 'turno') String? shift,
    @JsonKey(name: 'respuestas') AnswersOrigin? answersOrigin,
    @JsonKey(name: 'ejercicios')
    @Default(<SourceExercise>[])
    List<SourceExercise> exercises,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}

/// Ejercicio dentro de una fuente (p. ej. «Primer ejercicio» de un examen).
/// Su `id` solo es único dentro de su fuente.
@freezed
abstract class SourceExercise with _$SourceExercise {
  const factory SourceExercise({
    required String id,
    @JsonKey(name: 'nombre') required String name,
    @JsonKey(name: 'num_opciones') required int optionCount,

    /// Ejercicio de simulacro al que equivale, si lo hay.
    @JsonKey(name: 'simulacro') String? examExerciseId,
  }) = _SourceExercise;

  factory SourceExercise.fromJson(Map<String, dynamic> json) =>
      _$SourceExerciseFromJson(json);
}

/// Enunciado compartido por varias preguntas (supuesto práctico).
@freezed
abstract class QuestionContext with _$QuestionContext {
  const factory QuestionContext({
    required String id,
    @JsonKey(name: 'titulo') required String title,
    @JsonKey(name: 'enunciado') required String statement,
    @JsonKey(name: 'codigo') String? code,
    @JsonKey(name: 'lenguaje') String? language,
  }) = _QuestionContext;

  factory QuestionContext.fromJson(Map<String, dynamic> json) =>
      _$QuestionContextFromJson(json);
}

@freezed
abstract class Question with _$Question {
  const factory Question({
    required String id,
    @JsonKey(name: 'fuente') required String sourceId,
    @JsonKey(name: 'ejercicio') String? exerciseId,

    /// Número original en el examen («15», «R1»…), solo informativo.
    @JsonKey(name: 'numero') String? number,
    @JsonKey(name: 'tema') required int topicId,
    @JsonKey(name: 'contexto') String? contextId,
    @JsonKey(name: 'enunciado') required String statement,

    /// Letra → texto. Letras consecutivas desde `a`.
    @JsonKey(name: 'opciones') required Map<String, String> options,

    /// `null` solo si la pregunta está anulada.
    @JsonKey(name: 'correcta') required String? correctKey,
    @JsonKey(name: 'reserva') @Default(false) bool isReserve,
    @JsonKey(name: 'anulada') @Default(false) bool voided,
    @JsonKey(name: 'correcta_provisional') String? provisionalKey,
    @JsonKey(name: 'obsoleta') @Default(false) bool obsolete,
    @JsonKey(name: 'explicacion') String? explanation,
    @JsonKey(name: 'notas') String? notes,
    @JsonKey(name: 'etiquetas') @Default(<String>[]) List<String> tags,
  }) = _Question;

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

/// Reglas del examen real (`simulacro`).
@freezed
abstract class ExamRules with _$ExamRules {
  const factory ExamRules({
    @JsonKey(name: 'nota') String? note,
    @JsonKey(name: 'ejercicios')
    @Default(<ExamExercise>[])
    List<ExamExercise> exercises,
  }) = _ExamRules;

  factory ExamRules.fromJson(Map<String, dynamic> json) =>
      _$ExamRulesFromJson(json);
}

@freezed
abstract class ExamExercise with _$ExamExercise {
  const factory ExamExercise({
    required String id,
    @JsonKey(name: 'nombre') required String name,
    @JsonKey(name: 'num_preguntas') required int questionCount,
    @JsonKey(name: 'num_reserva') @Default(0) int reserveCount,
    @JsonKey(name: 'num_opciones') required int optionCount,

    /// `null` = sin límite de tiempo.
    @JsonKey(name: 'duracion_min') int? durationMin,
    @JsonKey(name: 'con_supuestos') @Default(false) bool hasCaseStudies,
    @JsonKey(name: 'puntuacion') Scoring? scoring,
  }) = _ExamExercise;

  factory ExamExercise.fromJson(Map<String, dynamic> json) =>
      _$ExamExerciseFromJson(json);
}

enum ScoringMode {
  @JsonValue('fijo')
  fixed,
  @JsonValue('proporcional')
  proportional,
}

/// Puntuación de un ejercicio de simulacro.
///
/// Los valores se guardan como `double` porque así llegan del JSON; el cálculo
/// de la nota (Fase 4) los convertirá a `Decimal` antes de operar y redondear.
@freezed
abstract class Scoring with _$Scoring {
  const factory Scoring({
    @JsonKey(name: 'modo') required ScoringMode mode,
    @JsonKey(name: 'acierto') double? correct,
    @JsonKey(name: 'fallo') double? wrong,
    @JsonKey(name: 'blanco') double? blank,
    @JsonKey(name: 'nota_maxima') double? maxScore,
    @JsonKey(name: 'factor_fallo') double? wrongFactor,
    @JsonKey(name: 'nota_minima') double? passMark,
    @JsonKey(name: 'decimales') int? decimals,
  }) = _Scoring;

  factory Scoring.fromJson(Map<String, dynamic> json) =>
      _$ScoringFromJson(json);
}

/// Apunte (resumen o tip) de un tema, en Markdown.
@freezed
abstract class Note with _$Note {
  const factory Note({
    required String id,
    @JsonKey(name: 'tema') required int topicId,
    @JsonKey(name: 'titulo') required String title,
    @JsonKey(name: 'contenido') required String content,
    @JsonKey(name: 'oficial') @Default(false) bool isOfficial,
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
