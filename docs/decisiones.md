# Registro de decisiones

## Fase 0 — Formato de pack y arquitectura

- **Motor + packs.** La app no contiene ningún examen en el código; todo llega en un fichero de pack.
  Así una misma app sirve para varias oposiciones o cursos a la vez.
- **Sin IA dentro de la app.** Coste cero y ninguna respuesta inventada. Los PDF se convierten fuera
  (con un chat de IA o a mano) y se importan como pack validado.
- **Sin servidor al principio, pero preparada para tenerlo.** Repositorios como interfaces, UUID,
  marcas de tiempo y respuestas como eventos inmutables: añadir Supabase más adelante no obliga a reescribir.
- **Lista plana de preguntas en el pack.** Simplifica importar a SQL: cada pregunta referencia su fuente,
  su ejercicio, su tema y su contexto por id.
- **Ids estables.** El progreso se asocia al id de pregunta, así sobrevive a actualizaciones del pack.
- **Oficial vs estudio.** Cada fuente declara si sus respuestas vienen de plantilla oficial. Las estadísticas y el
  simulacro pueden separarlas.

## Fase 0 — Puntuación según las bases

- Las bases generales C1 (apdo. 7.4.C) fijan: acierto = nota máxima / preguntas a valorar; cada fallo descuenta
  1/4 de un acierto; en blanco no penaliza; aprobado con 5; redondeo aritmético simétrico a 3 decimales.
- Se modela como `modo: proporcional` y no con valores fijos porque, si se anula una pregunta sin reserva
  (el 2.º ejercicio no tiene), cambia el número de preguntas a valorar y con él el valor de cada acierto.
- El redondeo se hace con decimales exactos (`Decimal`), porque `double` puede redondear mal casos como x,xxx5.

## Fase 0 — Proyecto Flutter y arranque

- **`flutter create` sobre el repo existente, sin mover nada.** `--overwrite` está desactivado por
  defecto: el comando solo crea lo que falta (`pubspec.yaml`, `lib/`, `android/`, `web/`, `test/`,
  `analysis_options.yaml`, `.metadata`) y no toca `README.md`, `CLAUDE.md`, `docs/`, `packs/`,
  `schema/`, `tools/` ni el `.gitignore` ya existente. Verificado con `git status` tras crear el
  proyecto: ningún archivo previo aparece como modificado.
- **Riverpod con generador desde el primer commit.** El router (`appRouterProvider`) y el modo de
  tema (`ThemeModeController`) ya usan `@riverpod`, porque los dos hacen falta de verdad para el
  requisito de tema + router de Fase 0: así se valida ya que `build_runner` + `riverpod_generator`
  funcionan en este entorno (Windows), antes de depender de ellos para los repositorios reales de
  Fase 1. No se ha creado ningún provider "de prueba" solo para probar el toolchain.
- **Código generado (`*.g.dart`, `*.freezed.dart`) fuera de git.** Se regenera con
  `dart run build_runner build` tanto en local como en CI; evita divergencias entre el código fuente
  y lo generado y mantiene el repo más pequeño, relevante sobre todo cuando Drift empiece a generar
  tablas en Fase 1.
- **`drift_flutter` en vez de configurar `drift` + `sqlite3_flutter_libs` a mano.** `drift_flutter`
  fija `sqlite3_flutter_libs` (0.6.0+eol) y `sqlcipher_flutter_libs` (0.7.0+eol) como dependencias
  transitivas; el sufijo `+eol` no es un problema, es el paquete legado que desde su versión 0.6.0 no
  hace nada por sí mismo (`sqlite3` ya va en su versión 3.x). En Fase 0 no se instancia ninguna
  `DriftDatabase` — solo se declara la dependencia; el `sqlite3.wasm`/`drift_worker.js` en `web/` y
  la base de datos real (tablas, migraciones) llegan en Fase 1.
- **`packs/zgz-tai.pack.json` declarado directamente como asset, sin copia en `assets/`.** Como
  `pubspec.yaml` vive en la raíz del repo, `packs/` es una ruta relativa válida dentro del proyecto
  Flutter. Evita tener dos copias del mismo fichero (una para `tools/` en Python y otra empaquetada
  con la app) que podrían desincronizarse si se regenera el pack y se olvida actualizar la copia.
- **Pantalla de inicio provisional fuera de `features/`.** Fase 0 no tiene ninguna feature real
  todavía, así que `EstudioApp` y `HomePlaceholderPage` viven en `lib/app.dart` /
  `lib/home_placeholder_page.dart`, a nivel raíz. Se sustituirá por la lista de packs
  (`features/packs/presentation`) en Fase 1 en vez de mantener una pantalla de relleno.
- **CI con `subosito/flutter-action`, fijando la misma versión que en local (3.47.5).** Así un fallo
  en CI es reproducible en la máquina de desarrollo. Ejecuta `build_runner`, `dart format
  --set-exit-if-changed`, `flutter analyze` y `flutter test` en cada push y pull request a `main`.

## Fase 1 — Notas tomadas durante la fase

- **«Reiniciar progreso» (Fase 6) se hará con una marca de reinicio, no borrando filas.** La tabla
  `answers` es inmutable (solo INSERT; dos triggers de SQLite rechazan UPDATE y DELETE), así que
  reiniciar un pack guardará en `settings` una marca con la fecha del reinicio por pack, y las
  estadísticas y el repaso solo tendrán en cuenta las respuestas posteriores. Ventajas: el historial
  no se pierde (se puede deshacer el reinicio), y en la futura sincronización no hay que propagar
  borrados, solo un evento más.
- **`format: date` comprobado en los dos validadores.** `jsonschema` trata `format` como anotación
  salvo que se le pase `FORMAT_CHECKER`; ahora se activa en `tools/validate_pack.py` y el
  `PackValidator` de Dart aplica la misma regla (forma `AAAA-MM-DD` y fecha real del calendario,
  año ≥ 1). Los mismos casos límite (29/02 en año bisiesto y no bisiesto, año 0…) están probados en
  Dart y comprobados a mano en Python.
