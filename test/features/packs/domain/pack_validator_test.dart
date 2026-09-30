import 'dart:convert';
import 'dart:io';

import 'package:estudio_app/features/packs/domain/pack_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Object? _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Object?;

const _invalidDir = 'test/fixtures/packs/invalid';

/// Fichero inválido → texto que debe aparecer en su único error.
///
/// Cada fixture es `valid/completo.pack.json` con un solo cambio, y
/// `tools/validate_pack.py` también devuelve exactamente un error para cada
/// uno: así se comprueba que Dart y Python aplican las mismas reglas.
/// En las de estructura se comprueba la ruta (los mensajes de `jsonschema`
/// están en inglés); en las de coherencia, el mensaje exacto de Python.
const _expectedErrors = {
  // Estructura
  'no-es-objeto': '[esquema] (raíz): debe ser un objeto',
  'falta-preguntas': "[esquema] (raíz): falta la clave 'preguntas'",
  'clave-desconocida': "[esquema] (raíz): clave no permitida 'extra'",
  'formato-incorrecto': '[esquema] formato:',
  'version-formato-2': '[esquema] version_formato:',
  'version-no-semver': '[esquema] pack/version:',
  'tipo-pack-invalido': '[esquema] pack/tipo:',
  'idioma-invalido': '[esquema] pack/idioma:',
  'id-pack-no-slug': '[esquema] pack/id:',
  'temario-sin-bloques': '[esquema] temario/bloques:',
  'tema-id-cero': '[esquema] temario/temas/0/id:',
  'opciones-letra-invalida': "[esquema] preguntas/0/opciones: la opción 'z'",
  'opciones-insuficientes': '[esquema] preguntas/5/opciones: debe tener entre',
  'opcion-vacia': '[esquema] preguntas/0/opciones/a:',
  'correcta-mayuscula': '[esquema] preguntas/0/correcta:',
  'enunciado-vacio': '[esquema] preguntas/0/enunciado:',
  'reserva-no-booleana': '[esquema] preguntas/2/reserva:',
  'fuente-oficial-no-booleana': '[esquema] fuentes/0/oficial:',
  'proporcional-sin-nota-maxima':
      "[esquema] simulacro/ejercicios/0/puntuacion: falta 'nota_maxima'",
  'fijo-fallo-positivo': '[esquema] simulacro/ejercicios/1/puntuacion/fallo:',
  'factor-fallo-mayor-que-1':
      '[esquema] simulacro/ejercicios/0/puntuacion/factor_fallo:',
  'duracion-cero': '[esquema] simulacro/ejercicios/0/duracion_min:',
  // Coherencia
  'tema-bloque-inexistente': 'tema 1: bloque 9 no existe',
  'bloque-duplicado': 'bloque duplicado: 0',
  'tema-duplicado': 'tema duplicado: 1',
  'fuente-duplicada': 'fuente duplicado: examen-2026',
  'contexto-duplicado': 'contexto duplicado: supuesto-1',
  'pregunta-duplicada': 'pregunta duplicado: e1-01',
  'apunte-duplicado': 'apunte duplicado: ap-redes',
  'simulacro-inexistente': "fuente examen-2026/e1: simulacro 'ej9' no existe",
  'fuente-inexistente': "e1-01: fuente 'no-existe' no existe",
  'tema-inexistente': 'e1-01: tema 99 no existe',
  'contexto-inexistente': "e2-01: contexto 'no-existe' no existe",
  'opciones-no-consecutivas':
      'est-01: las opciones deben ser a, b, c… consecutivas',
  'ejercicio-inexistente':
      "e1-01: ejercicio 'e9' no existe en la fuente examen-2026",
  'opciones-distintas-al-ejercicio':
      'e1-01: tiene 4 opciones y el ejercicio exige 3',
  'anulada-con-correcta': 'e1-02: anulada pero con respuesta correcta',
  'sin-correcta-no-anulada': 'e1-01: sin respuesta correcta y no está anulada',
  'correcta-no-es-opcion': "est-01: la correcta 'c' no es una opción",
  'provisional-no-es-opcion': 'e1-02: correcta_provisional no es una opción',
  'opciones-repetidas': 'e1-01: opciones repetidas',
  'apunte-tema-inexistente': 'apunte ap-redes: tema 99 no existe',
};

void main() {
  const validator = PackValidator();

  group('packs válidos', () {
    for (final path in [
      'packs/zgz-tai.pack.json',
      'packs/ejemplo-minimo.pack.json',
      'test/fixtures/packs/valid/completo.pack.json',
    ]) {
      test(path, () {
        expect(validator.validate(_readJson(path)), isEmpty);
      });
    }
  });

  group('packs inválidos (un error cada uno)', () {
    for (final MapEntry(key: name, value: expected)
        in _expectedErrors.entries) {
      test(name, () {
        final errors = validator.validate(
          _readJson('$_invalidDir/$name.pack.json'),
        );
        expect(errors, [contains(expected)]);
      });
    }

    test('no hay fixtures sin caso de test', () {
      final files = Directory(_invalidDir)
          .listSync()
          .map((f) => f.uri.pathSegments.last.replaceAll('.pack.json', ''))
          .toSet();
      expect(files, _expectedErrors.keys.toSet());
    });
  });

  group('estructura', () {
    test('con errores de estructura no se comprueba la coherencia', () {
      final pack =
          _readJson('test/fixtures/packs/valid/completo.pack.json')!
              as Map<String, Object?>;
      pack['formato'] = 'otro';
      (pack['temario']! as Map)['temas'] = [
        {'id': 1, 'bloque': 99, 'titulo': 'Bloque inexistente'},
      ];
      final errors = validator.validate(pack);
      expect(errors, hasLength(1));
      expect(errors.single, startsWith('[esquema]'));
    });

    test('acumula varios errores de estructura a la vez', () {
      final errors = validator.validate(<String, Object?>{'formato': 'x'});
      // formato incorrecto + 5 claves obligatorias ausentes.
      expect(errors, hasLength(6));
    });
  });
}
