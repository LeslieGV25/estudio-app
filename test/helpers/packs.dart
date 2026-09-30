import 'dart:io';

import 'package:drift/drift.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/packs/domain/pack_parser.dart';

const completoPath = 'test/fixtures/packs/valid/completo.pack.json';
const ejemploMinimoPath = 'packs/ejemplo-minimo.pack.json';
const zaragozaPath = 'packs/zgz-tai.pack.json';

PackDocument loadPack(String path) =>
    const PackParser().parse(File(path).readAsBytesSync());

const _contentTables = [
  'blocks',
  'topics',
  'sources',
  'source_exercises',
  'contexts',
  'questions',
  'notes',
  'exam_exercises',
];

/// Nº de filas de cada tabla de contenido que pertenecen a [packId].
Future<Map<String, int>> contentCounts(AppDatabase db, String packId) async => {
  for (final table in _contentTables)
    table: await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM $table WHERE pack_id = ?',
          variables: [Variable(packId)],
        )
        .map((row) => row.read<int>('c'))
        .getSingle(),
};
