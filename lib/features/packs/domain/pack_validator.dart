/// Valida un pack ya decodificado de JSON: primero la estructura (lo que
/// exige `schema/pack.schema.json`) y después la coherencia entre ids.
///
/// Implementa las mismas reglas que `tools/validate_pack.py`, con los mismos
/// mensajes en las reglas de coherencia. Si se cambia una regla aquí, hay que
/// cambiarla también allí (y en el esquema).
class PackValidator {
  const PackValidator();

  /// Devuelve la lista de errores; vacía si el pack es válido.
  List<String> validate(Object? json) {
    final structure = _StructureChecker()..checkRoot(json);
    if (structure.errors.isNotEmpty) {
      // Sin estructura válida no tiene sentido comprobar referencias.
      return structure.errors;
    }
    return _coherenceErrors(json! as Map<String, Object?>);
  }
}

typedef _Json = Map<String, Object?>;

final _slug = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$');
final _letter = RegExp(r'^[a-f]$');
final _semver = RegExp(r'^\d+\.\d+\.\d+$');
final _language = RegExp(r'^[a-z]{2}(-[A-Z]{2})?$');
final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `format: date` igual que `jsonschema`: forma `AAAA-MM-DD` y además una
/// fecha que exista en el calendario (año ≥ 1, sin 31 de abril ni similares).
bool _isDate(String value) {
  final match = _datePattern.firstMatch(value);
  if (match == null) return false;
  final [year, month, day] = [
    for (var i = 1; i <= 3; i++) int.parse(match.group(i)!),
  ];
  // DateTime normaliza los desbordes (31/04 → 01/05): si al volver a leerla
  // no coincide, la fecha no existía.
  final date = DateTime.utc(year, month, day);
  return year >= 1 && date.month == month && date.day == day;
}

/// Recorre el JSON siguiendo `pack.schema.json`. Cada método comprueba un
/// campo solo si está presente: la obligatoriedad la comprueba [_object].
class _StructureChecker {
  final errors = <String>[];

  void checkRoot(Object? json) {
    final root = _object(
      json,
      '',
      required: const {
        'formato',
        'version_formato',
        'pack',
        'temario',
        'fuentes',
        'preguntas',
      },
      optional: const {'contextos', 'simulacro', 'apuntes'},
    );
    if (root == null) return;
    _constant(root, 'formato', '', 'estudio-pack');
    _constant(root, 'version_formato', '', 1);
    _field(root, 'pack', '', _pack);
    _field(root, 'temario', '', _syllabus);
    _field(root, 'simulacro', '', _examRules);
    _array(root, 'fuentes', '', _source, minItems: 1);
    _array(root, 'contextos', '', _context);
    _array(root, 'preguntas', '', _question, minItems: 1);
    _array(root, 'apuntes', '', _note);
  }

  void _pack(Object? value, String path) {
    final o = _object(
      value,
      path,
      required: const {'id', 'nombre', 'version', 'tipo', 'idioma'},
      optional: const {'descripcion', 'autor', 'actualizado'},
    );
    if (o == null) return;
    _string(o, 'id', path, pattern: _slug);
    _string(o, 'nombre', path, minLength: 1);
    _string(o, 'descripcion', path);
    _string(o, 'version', path, pattern: _semver);
    _enum(o, 'tipo', path, const {
      'oposicion',
      'curso',
      'certificacion',
      'otro',
    });
    _string(o, 'idioma', path, pattern: _language);
    _string(o, 'autor', path);
    _string(o, 'actualizado', path, date: true);
  }

  void _syllabus(Object? value, String path) {
    final o = _object(value, path, required: const {'bloques', 'temas'});
    if (o == null) return;
    _array(o, 'bloques', path, minItems: 1, (item, itemPath) {
      final b = _object(item, itemPath, required: const {'id', 'nombre'});
      if (b == null) return;
      _integer(b, 'id', itemPath, min: 0);
      _string(b, 'nombre', itemPath);
    });
    _array(o, 'temas', path, minItems: 1, (item, itemPath) {
      final t = _object(
        item,
        itemPath,
        required: const {'id', 'bloque', 'titulo'},
      );
      if (t == null) return;
      _integer(t, 'id', itemPath, min: 1);
      _integer(t, 'bloque', itemPath, min: 0);
      _string(t, 'titulo', itemPath);
    });
  }

  void _examRules(Object? value, String path) {
    final o = _object(value, path, optional: const {'nota', 'ejercicios'});
    if (o == null) return;
    _string(o, 'nota', path);
    _array(o, 'ejercicios', path, minItems: 1, (item, itemPath) {
      final e = _object(
        item,
        itemPath,
        required: const {'id', 'nombre', 'num_preguntas', 'num_opciones'},
        optional: const {
          'num_reserva',
          'duracion_min',
          'con_supuestos',
          'puntuacion',
        },
      );
      if (e == null) return;
      _string(e, 'id', itemPath, pattern: _slug);
      _string(e, 'nombre', itemPath);
      _integer(e, 'num_preguntas', itemPath, min: 1);
      _integer(e, 'num_reserva', itemPath, min: 0);
      _integer(e, 'num_opciones', itemPath, min: 2, max: 6);
      _integer(e, 'duracion_min', itemPath, min: 1, nullable: true);
      _boolean(e, 'con_supuestos', itemPath);
      _field(e, 'puntuacion', itemPath, _scoring);
    });
  }

  void _scoring(Object? value, String path) {
    final o = _object(
      value,
      path,
      required: const {'modo'},
      optional: const {
        'acierto',
        'fallo',
        'blanco',
        'nota_maxima',
        'factor_fallo',
        'nota_minima',
        'decimales',
      },
    );
    if (o == null) return;
    _enum(o, 'modo', path, const {'fijo', 'proporcional'});
    _number(o, 'acierto', path);
    _number(o, 'fallo', path, max: 0);
    _number(o, 'blanco', path);
    _number(o, 'nota_maxima', path, exclusiveMin: 0);
    _number(o, 'factor_fallo', path, min: 0, max: 1);
    _number(o, 'nota_minima', path, min: 0);
    _integer(o, 'decimales', path, min: 0, max: 6);
    // Campos que exige cada modo (el allOf/if/then del esquema).
    final needed = switch (o['modo']) {
      'fijo' => const ['acierto', 'fallo'],
      'proporcional' => const ['nota_maxima', 'factor_fallo'],
      _ => const <String>[],
    };
    for (final key in needed) {
      if (!o.containsKey(key)) {
        _error(path, "falta '$key' (obligatorio en modo ${o['modo']})");
      }
    }
  }

  void _source(Object? value, String path) {
    final o = _object(
      value,
      path,
      required: const {'id', 'tipo', 'nombre', 'oficial'},
      optional: const {
        'fecha',
        'convocatoria',
        'turno',
        'respuestas',
        'ejercicios',
      },
    );
    if (o == null) return;
    _string(o, 'id', path, pattern: _slug);
    _enum(o, 'tipo', path, const {'examen', 'estudio'});
    _string(o, 'nombre', path);
    _boolean(o, 'oficial', path);
    _string(o, 'fecha', path, nullable: true, date: true);
    _string(o, 'convocatoria', path);
    _string(o, 'turno', path);
    _enum(o, 'respuestas', path, const {
      'plantilla_definitiva',
      'plantilla_provisional',
      'marcadas_en_examen',
      'elaboracion_propia',
    });
    _array(o, 'ejercicios', path, (item, itemPath) {
      final e = _object(
        item,
        itemPath,
        required: const {'id', 'nombre', 'num_opciones'},
        optional: const {'simulacro'},
      );
      if (e == null) return;
      _string(e, 'id', itemPath, pattern: _slug);
      _string(e, 'nombre', itemPath);
      _integer(e, 'num_opciones', itemPath, min: 2, max: 6);
      _string(e, 'simulacro', itemPath, pattern: _slug);
    });
  }

  void _context(Object? value, String path) {
    final o = _object(
      value,
      path,
      required: const {'id', 'titulo', 'enunciado'},
      optional: const {'codigo', 'lenguaje'},
    );
    if (o == null) return;
    _string(o, 'id', path, pattern: _slug);
    _string(o, 'titulo', path);
    _string(o, 'enunciado', path);
    _string(o, 'codigo', path);
    _string(o, 'lenguaje', path);
  }

  void _question(Object? value, String path) {
    final o = _object(
      value,
      path,
      required: const {
        'id',
        'fuente',
        'tema',
        'enunciado',
        'opciones',
        'correcta',
      },
      optional: const {
        'ejercicio',
        'numero',
        'contexto',
        'reserva',
        'anulada',
        'correcta_provisional',
        'obsoleta',
        'explicacion',
        'notas',
        'etiquetas',
      },
    );
    if (o == null) return;
    _string(o, 'id', path, pattern: _slug);
    _string(o, 'fuente', path, pattern: _slug);
    _string(o, 'ejercicio', path, pattern: _slug);
    _string(o, 'numero', path);
    _integer(o, 'tema', path, min: 1);
    _string(o, 'contexto', path, pattern: _slug, nullable: true);
    _string(o, 'enunciado', path, minLength: 1);
    _field(o, 'opciones', path, _options);
    _string(o, 'correcta', path, pattern: _letter, nullable: true);
    _boolean(o, 'reserva', path);
    _boolean(o, 'anulada', path);
    _string(o, 'correcta_provisional', path, pattern: _letter);
    _boolean(o, 'obsoleta', path);
    _string(o, 'explicacion', path);
    _string(o, 'notas', path);
    _array(o, 'etiquetas', path, (item, itemPath) {
      if (item is! String) _error(itemPath, 'debe ser texto');
    });
  }

  void _options(Object? value, String path) {
    if (value is! Map<String, Object?>) {
      _error(path, 'debe ser un objeto');
      return;
    }
    if (value.length < 2 || value.length > 6) {
      _error(path, 'debe tener entre 2 y 6 opciones (tiene ${value.length})');
    }
    for (final MapEntry(:key, value: text) in value.entries) {
      if (!_letter.hasMatch(key)) {
        _error(path, "la opción '$key' no es una letra de la a a la f");
      }
      if (text is! String || text.isEmpty) {
        _error('$path/$key', 'debe ser un texto no vacío');
      }
    }
  }

  void _note(Object? value, String path) {
    final o = _object(
      value,
      path,
      required: const {'id', 'tema', 'titulo', 'contenido'},
      optional: const {'oficial'},
    );
    if (o == null) return;
    _string(o, 'id', path, pattern: _slug);
    _integer(o, 'tema', path, min: 1);
    _string(o, 'titulo', path);
    _string(o, 'contenido', path);
    _boolean(o, 'oficial', path);
  }

  // --- Comprobaciones genéricas ---------------------------------------------

  void _error(String path, String message) =>
      errors.add('[esquema] ${path.isEmpty ? '(raíz)' : path}: $message');

  String _join(String path, Object key) => path.isEmpty ? '$key' : '$path/$key';

  /// Comprueba que [value] es un objeto con las claves [required] y sin claves
  /// fuera de [required] ∪ [optional]. Devuelve el mapa o `null` si no lo es.
  _Json? _object(
    Object? value,
    String path, {
    Set<String> required = const {},
    Set<String> optional = const {},
  }) {
    if (value is! Map<String, Object?>) {
      _error(path, 'debe ser un objeto');
      return null;
    }
    for (final key in required) {
      if (!value.containsKey(key)) _error(path, "falta la clave '$key'");
    }
    for (final key in value.keys) {
      if (!required.contains(key) && !optional.contains(key)) {
        _error(path, "clave no permitida '$key'");
      }
    }
    return value;
  }

  void _field(
    _Json o,
    String key,
    String path,
    void Function(Object? value, String path) check,
  ) {
    if (o.containsKey(key)) check(o[key], _join(path, key));
  }

  void _array(
    _Json o,
    String key,
    String path,
    void Function(Object? item, String itemPath) checkItem, {
    int minItems = 0,
  }) {
    if (!o.containsKey(key)) return;
    final p = _join(path, key);
    final value = o[key];
    if (value is! List<Object?>) {
      _error(p, 'debe ser una lista');
      return;
    }
    if (value.length < minItems) {
      _error(p, 'debe tener al menos $minItems elemento(s)');
    }
    for (var i = 0; i < value.length; i++) {
      checkItem(value[i], _join(p, i));
    }
  }

  void _string(
    _Json o,
    String key,
    String path, {
    int minLength = 0,
    RegExp? pattern,
    bool nullable = false,
    bool date = false,
  }) {
    if (!o.containsKey(key)) return;
    final p = _join(path, key);
    final value = o[key];
    if (value == null && nullable) return;
    if (value is! String) {
      _error(p, nullable ? 'debe ser texto o null' : 'debe ser texto');
    } else if (value.length < minLength) {
      _error(p, 'no puede estar vacío');
    } else if (pattern != null && !pattern.hasMatch(value)) {
      _error(p, "'$value' no cumple el patrón ${pattern.pattern}");
    } else if (date && !_isDate(value)) {
      _error(p, "'$value' no es una fecha válida (AAAA-MM-DD)");
    }
  }

  void _integer(
    _Json o,
    String key,
    String path, {
    int? min,
    int? max,
    bool nullable = false,
  }) {
    if (!o.containsKey(key)) return;
    final p = _join(path, key);
    final value = o[key];
    if (value == null && nullable) return;
    if (value is! int) {
      _error(p, nullable ? 'debe ser un entero o null' : 'debe ser un entero');
    } else {
      _range(p, value, min: min, max: max);
    }
  }

  void _number(
    _Json o,
    String key,
    String path, {
    num? min,
    num? max,
    num? exclusiveMin,
  }) {
    if (!o.containsKey(key)) return;
    final p = _join(path, key);
    final value = o[key];
    if (value is! num) {
      _error(p, 'debe ser un número');
    } else if (exclusiveMin != null && value <= exclusiveMin) {
      _error(p, 'debe ser mayor que $exclusiveMin (es $value)');
    } else {
      _range(p, value, min: min, max: max);
    }
  }

  void _range(String path, num value, {num? min, num? max}) {
    if (min != null && value < min) {
      _error(path, 'debe ser como mínimo $min (es $value)');
    }
    if (max != null && value > max) {
      _error(path, 'debe ser como máximo $max (es $value)');
    }
  }

  void _boolean(_Json o, String key, String path) {
    if (o.containsKey(key) && o[key] is! bool) {
      _error(_join(path, key), 'debe ser true o false');
    }
  }

  void _enum(_Json o, String key, String path, Set<String> allowed) {
    if (o.containsKey(key) && !allowed.contains(o[key])) {
      _error(
        _join(path, key),
        "'${o[key]}' no es válido; debe ser uno de: ${allowed.join(', ')}",
      );
    }
  }

  void _constant(_Json o, String key, String path, Object expected) {
    if (o.containsKey(key) && o[key] != expected) {
      _error(_join(path, key), "debe ser '$expected' (es '${o[key]}')");
    }
  }
}

/// Reglas de coherencia entre ids. Asume estructura válida.
/// Mismo orden y mismos mensajes que `validar()` en `tools/validate_pack.py`.
List<String> _coherenceErrors(_Json pack) {
  final errors = <String>[];
  List<_Json> list(Object? value) =>
      value == null ? const [] : (value as List).cast<_Json>();

  final syllabus = pack['temario']! as _Json;
  final blocks = list(syllabus['bloques']);
  final topics = list(syllabus['temas']);
  final sources = list(pack['fuentes']);
  final contexts = list(pack['contextos']);
  final questions = list(pack['preguntas']);
  final notes = list(pack['apuntes']);
  final examExercises = list((pack['simulacro'] as _Json?)?['ejercicios']);

  final blockIds = {for (final b in blocks) b['id']};
  final topicIds = {for (final t in topics) t['id']};
  for (final t in topics) {
    if (!blockIds.contains(t['bloque'])) {
      errors.add('tema ${t['id']}: bloque ${t['bloque']} no existe');
    }
  }

  void duplicates(String name, Iterable<_Json> items, {bool feminine = false}) {
    final seen = <Object?>{};
    final reported = <Object?>{};
    for (final item in items) {
      final id = item['id'];
      if (!seen.add(id) && reported.add(id)) {
        errors.add('$name ${feminine ? 'duplicada' : 'duplicado'}: $id');
      }
    }
  }

  duplicates('bloque', blocks);
  duplicates('tema', topics);
  duplicates('fuente', sources, feminine: true);
  duplicates('contexto', contexts);
  duplicates('pregunta', questions, feminine: true);
  duplicates('apunte', notes);

  final sourcesById = {for (final s in sources) s['id']: s};
  final contextIds = {for (final c in contexts) c['id']};
  final examExerciseIds = {for (final e in examExercises) e['id']};
  for (final s in sources) {
    for (final e in list(s['ejercicios'])) {
      if (e.containsKey('simulacro') &&
          !examExerciseIds.contains(e['simulacro'])) {
        errors.add(
          "fuente ${s['id']}/${e['id']}: "
          "simulacro '${e['simulacro']}' no existe",
        );
      }
    }
  }

  for (final q in questions) {
    final id = q['id'];
    final source = sourcesById[q['fuente']];
    if (source == null) {
      errors.add("$id: fuente '${q['fuente']}' no existe");
      continue;
    }
    if (!topicIds.contains(q['tema'])) {
      errors.add('$id: tema ${q['tema']} no existe');
    }
    final context = q['contexto'];
    if (context != null && !contextIds.contains(context)) {
      errors.add("$id: contexto '$context' no existe");
    }
    final options = (q['opciones']! as Map).cast<String, String>();
    final letters = options.keys.toList()..sort();
    final expected = [
      for (var i = 0; i < letters.length; i++) String.fromCharCode(0x61 + i),
    ];
    if (letters.join() != expected.join()) {
      errors.add(
        '$id: las opciones deben ser a, b, c… consecutivas (hay $letters)',
      );
    }
    if (q.containsKey('ejercicio')) {
      final exercise = list(source['ejercicios'])
          .where((e) => e['id'] == q['ejercicio'])
          .firstOrNull;
      if (exercise == null) {
        errors.add(
          "$id: ejercicio '${q['ejercicio']}' no existe "
          'en la fuente ${source['id']}',
        );
      } else if (options.length != exercise['num_opciones']) {
        errors.add(
          '$id: tiene ${options.length} opciones y el ejercicio exige '
          '${exercise['num_opciones']}',
        );
      }
    }
    final voided = q['anulada'] == true;
    final correct = q['correcta'];
    if (voided && correct != null) {
      errors.add('$id: anulada pero con respuesta correcta');
    }
    if (!voided) {
      if (correct == null) {
        errors.add('$id: sin respuesta correcta y no está anulada');
      } else if (!options.containsKey(correct)) {
        errors.add("$id: la correcta '$correct' no es una opción");
      }
    }
    if (q.containsKey('correcta_provisional') &&
        !options.containsKey(q['correcta_provisional'])) {
      errors.add('$id: correcta_provisional no es una opción');
    }
    if (options.values.toSet().length != options.length) {
      errors.add('$id: opciones repetidas');
    }
  }

  for (final n in notes) {
    if (!topicIds.contains(n['tema'])) {
      errors.add("apunte ${n['id']}: tema ${n['tema']} no existe");
    }
  }
  return errors;
}
