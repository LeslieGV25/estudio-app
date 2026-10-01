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

## Fase 1 — Datos

### Formato y validación

- **Modelos freezed con claves en español y campos en inglés.** El JSON del pack usa el vocabulario
  de la oposición (`preguntas`, `correcta`, `anulada`) y el código el del glosario (`Question`,
  `correctKey`, `voided`); `@JsonKey(name: …)` traduce. Así se puede renombrar en el código sin romper
  los packs existentes, y al revés.
- **Primero validar, después parsear.** `PackValidator` trabaja sobre el JSON crudo y `fromJson` solo
  se llama si no hay errores. Si se parseara directamente, un pack mal formado lanzaría un
  `TypeError` sin decir qué campo falla; así la usuaria recibe la lista completa de problemas.
- **Validador escrito a mano, sin paquete de JSON Schema.** Descartado `json_schema` (pub.dev): poco
  mantenido y con mensajes genéricos en inglés. El validador sigue el esquema campo a campo con
  mensajes en español y las mismas reglas de coherencia que `tools/validate_pack.py`.
- **Paridad Dart ↔ Python comprobada con fixtures.** Cada fichero de
  `test/fixtures/packs/invalid/` es el pack `completo` con un solo cambio, y los dos validadores
  devuelven exactamente un error para cada uno. El CI, además, valida `packs/*.pack.json` con el
  script de Python: si alguien regenera el pack de Zaragoza y lo rompe, el CI falla.
- **Importar siempre desde bytes.** `PackParser.parse(List<int>)` sirve igual para el asset
  incluido, `file_picker` en Android y en web (donde no hay rutas de fichero). Se acepta el BOM de
  UTF-8 que añaden algunos editores de Windows.

### Base de datos

- **Dos mundos separados: contenido y usuaria.** Las tablas de contenido cuelgan de `packs` con
  `ON DELETE CASCADE` y clave `(pack_id, id)`; las de usuaria no tienen clave foránea hacia `packs`.
  Por eso borrar o actualizar un pack nunca puede arrastrar el progreso, y al reimportarlo las
  respuestas se reenlazan solas por `pack_id + question_id`. Hay un test que lo comprueba.
- **Actualizar = borrar y reinsertar en una transacción.** Más simple que calcular diferencias,
  no deja restos si la versión nueva quita preguntas y, si algo falla a mitad, el rollback deja la
  versión anterior intacta (probado). Se conserva `installed_at`.
- **`PRAGMA foreign_keys = ON` al abrir.** SQLite trae las claves foráneas desactivadas; sin esta
  línea la cascada no haría nada y los tests de borrado fallarían.
- **Integridad garantizada por la base de datos, no solo por el código:** triggers que hacen
  `answers` de solo inserción y un `CHECK` que limita la caja de Leitner a 0–4.
- **JSON en columnas solo para lo que siempre se lee entero** (opciones, etiquetas, puntuación,
  configuración de sesión). Lo que se filtra (tema, fuente, anulada…) va en columnas propias con
  índices.
- **Fechas como texto ISO-8601 en UTC** (`store_date_time_values_as_text`), legibles y compatibles
  con `timestamptz` de Postgres para la Fase 8. La nota de la sesión se guarda como texto decimal
  para no pasar por `double`.
- **Filas `XxxRow`.** Las clases que genera Drift se llaman `QuestionRow`, `PackRow`… para no chocar
  con las entidades del dominio; el repositorio traduce de una a otra.
- **Esquema versionado con `drift_dev make-migrations`.** La foto de la v1 está en `drift_schemas/`;
  al subir a v2 la herramienta genera los tests que comprueban la migración con datos reales.
- **Web: `sqlite3.wasm` y `drift_worker.js` en `web/`**, descargados de las releases que
  corresponden a las versiones del `pubspec.lock` (sqlite3 3.5.2, drift 2.35.0). Si se actualiza
  drift o sqlite3, hay que actualizar también estos dos ficheros.

### Casos de uso y pantalla

- **Solo hay caso de uso donde hay reglas.** `ImportPack` (versión mayor → actualiza; igual o
  menor → pide confirmación), `DeletePack` (si era el activo, activa otro) y `SeedBundledPack`
  (pack incluido). Listar packs o activar uno no tienen reglas: la pantalla usa el repositorio
  (su interfaz) directamente, sin clases que solo reenvían la llamada.
- **`SemVer` propio en vez de un paquete.** Son 40 líneas y el formato del pack solo admite
  `MAYOR.MENOR.PARCHE`. Comparar como texto fallaría (`"1.10.0" < "1.9.0"`).
- **Pack incluido: una marca en ajustes.** Se instala una sola vez; si la usuaria lo borra, no
  vuelve. Si una versión nueva de la app trae el pack con versión mayor, se actualiza solo si sigue
  instalado. Nunca se instala una versión anterior a la que hay.
- **`ImportPack` no guarda cuando necesita confirmación**: devuelve un resultado
  `ImportNeedsConfirmation` con el documento ya validado, y la pantalla llama a `replace()` si la
  usuaria acepta. Así el caso de uso no depende de la UI (sin callbacks de «¿seguro?») y no hay que
  volver a leer ni validar el fichero.
- **Resultados como `sealed class`.** `ImportOutcome` e `ImportFlowResult` obligan a la pantalla a
  tratar todos los casos: si mañana se añade uno, el `switch` deja de compilar hasta cubrirlo.
- **`file_picker` detrás de una interfaz (`PackFilePicker`).** Es la única forma de probar el flujo
  de importación en tests de widgets sin abrir un diálogo nativo. Se usa `file_picker` 13
  (mantenido, federado, soporta Android y web).
- **Providers que exponen interfaces.** `packRepositoryProvider` devuelve `PackRepository`, no
  `DriftPackRepository`: la capa de presentación no importa nada de Drift y los tests sustituyen la
  base de datos por una en memoria con `overrideWithValue`.
- **Tests de widgets con la base de datos real en memoria** en lugar de repositorios falsos:
  comprueban la integración completa (asset real, SQLite, streams) con poco código extra.

### Notas tomadas durante la fase

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

## Fase 2 — Práctica

### Dominio

- **Lectura del contenido separada de la instalación.** `PackContentRepository` (solo lectura:
  temario, fuentes y preguntas con su contexto, fuente y tema) vive en `packs` junto a
  `PackRepository`, que instala y borra. Práctica, simulacro, repaso y estadísticas solo leen, y así
  no ven métodos que no deben usar.
- **`StudyQuestion` reutiliza `Question` y `QuestionContext`.** No se duplica la pregunta en otra
  entidad: se envuelve con lo que hace falta para mostrarla y filtrarla (nombre de la fuente, si es
  oficial, tema, bloque y posición).
- **El filtro se aplica en Dart, no en SQL.** Se cargan las preguntas del pack (371 en el de
  Zaragoza) y `PracticeFilter.matches` decide. Las reglas (anuladas, obsoletas, oficiales,
  temario y fuentes) están en un solo sitio, se prueban sin base de datos y la pantalla usa el mismo
  método para el contador en vivo. Descartado: un `WHERE` en el repositorio, que obligaría a repetir
  las reglas en SQL y en Dart. El coste (tener el pack en memoria) es despreciable a este tamaño.
- **Temas o bloques (O), fuentes (Y).** Elegir un bloque equivale a elegir todos sus temas; las
  fuentes restringen sobre lo anterior.
- **Barajar por grupos.** Las preguntas de un mismo supuesto van juntas y en su orden original; se
  barajan los grupos. Al recortar al nº pedido no se parte un supuesto: el que no cabe se salta, y
  la sesión puede quedar más corta (la pantalla de configuración lo avisa). Solo si no cabe ningún
  grupo entero se corta el primero. `Random` se inyecta para que los tests sean deterministas.
- **Al filtrar por tema, un supuesto puede quedar partido.** Si sus preguntas son de temas
  distintos, solo entran las del tema elegido (con el contexto encima). Se prefirió respetar el
  filtro antes que traer preguntas de otros temas.
- **Las anuladas no se practican nunca**, ni en práctica ni en «repasar estas» (y tampoco entrarán
  en el repaso de fallos). Se descartó una opción «ver anuladas» con la respuesta provisional:
  practicar con una respuesta que el tribunal retiró no ayuda a aprobar. Siguen en la base de datos
  porque el simulacro (Fase 4) las necesita para aplicar las reservas. Hay tres defensas: el filtro,
  `retry` y `AnswerPracticeQuestion`, que rechaza responder una anulada (por si el pack se actualiza
  a mitad de sesión). Una respuesta antigua a una pregunta anulada después se guarda igual (los
  eventos son inmutables), pero el resumen la marca «no cuenta».
- **La sesión guarda sus preguntas ya elegidas y en orden** en `sessions.config`
  (`PracticeSessionConfig`). Con eso y los eventos de `answers` se puede reanudar una sesión (la
  siguiente pregunta es la primera sin respuesta) y reconstruir el resumen días después, sin estado
  en memoria. No hizo falta cambiar el esquema.
- **Una respuesta por pregunta y sesión.** El feedback es inmediato, así que no se puede cambiar.
  Lo comprueba el caso de uso, no la base de datos: un `UNIQUE (session_id, question_id)` exigiría
  una migración y estorbaría al simulacro, donde se puede cambiar de opción antes de entregar.
- **El pack de una respuesta se toma de su sesión** (`recordAnswer` no recibe `packId`): imposible
  guardar una respuesta con un pack distinto al de su sesión.
- **`SessionSummary` en `progress`, no en `practice`.** Repaso y simulacro mostrarán el mismo
  resumen. «Repasar estas» incluye falladas y en blanco; los porcentajes se calculan sobre las
  respuestas que cuentan (sin anuladas ni preguntas sin responder).
