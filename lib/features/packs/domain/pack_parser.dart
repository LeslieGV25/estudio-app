import 'dart:convert';

import 'entities/pack_document.dart';
import 'pack_validator.dart';

/// Marca de orden de bytes (BOM) que algunos editores añaden al guardar en UTF-8.
const _utf8Bom = 0xFEFF;

/// El fichero no es un pack válido. [errors] trae un mensaje por problema,
/// listo para mostrárselo a la usuaria.
class InvalidPackException implements Exception {
  const InvalidPackException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'InvalidPackException: ${errors.join('; ')}';
}

/// Convierte los bytes de un `*.pack.json` en un [PackDocument] validado.
///
/// Trabaja con bytes y no con rutas porque en web `file_picker` no da acceso
/// a una ruta de fichero, y así el mismo código sirve para el asset incluido,
/// Android y web.
class PackParser {
  const PackParser({this.validator = const PackValidator()});

  final PackValidator validator;

  /// Lanza [InvalidPackException] si los bytes no son UTF-8, no son JSON o
  /// no pasan el [PackValidator].
  PackDocument parse(List<int> bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const InvalidPackException([
        'El fichero no está codificado en UTF-8.',
      ]);
    }

    final Object? json;
    try {
      json = jsonDecode(
        text.isNotEmpty && text.codeUnitAt(0) == _utf8Bom
            ? text.substring(1)
            : text,
      );
    } on FormatException catch (e) {
      throw InvalidPackException([
        'El fichero no es JSON válido: ${e.message}',
      ]);
    }

    final errors = validator.validate(json);
    if (errors.isNotEmpty) throw InvalidPackException(errors);
    return PackDocument.fromJson(json! as Map<String, dynamic>);
  }
}
