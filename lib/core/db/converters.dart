import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/packs/domain/entities/pack_document.dart';

/// Opciones de una pregunta (`{"a": "...", "b": "..."}`) guardadas como JSON.
///
/// No se normalizan en una tabla `options` porque siempre se leen enteras con
/// su pregunta y nunca se consultan por separado.
class OptionsConverter extends TypeConverter<Map<String, String>, String> {
  const OptionsConverter();

  @override
  Map<String, String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map<String, dynamic>).cast<String, String>();

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Puntuación de un ejercicio de simulacro, con las mismas claves que el pack.
class ScoringConverter extends TypeConverter<Scoring, String> {
  const ScoringConverter();

  @override
  Scoring fromSql(String fromDb) =>
      Scoring.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(Scoring value) => jsonEncode(value.toJson());
}

/// Configuración libre de una sesión (filtros de práctica, reglas usadas en
/// un simulacro…). Cada modo define su forma en su propia fase.
class JsonMapConverter extends TypeConverter<Map<String, Object?>, String> {
  const JsonMapConverter();

  @override
  Map<String, Object?> fromSql(String fromDb) =>
      jsonDecode(fromDb) as Map<String, Object?>;

  @override
  String toSql(Map<String, Object?> value) => jsonEncode(value);
}
