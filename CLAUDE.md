# CLAUDE.md — App de estudio por packs

Guía para Claude Code. Léela entera antes de cada tarea.

## Qué es este proyecto

App **Flutter (Android + web)** para estudiar exámenes con tests. Es un **motor genérico**: todo el
contenido llega en **packs** (`*.pack.json`, formato en `docs/formato-pack.md`, esquema en
`schema/pack.schema.json`). La usuaria puede tener **varios packs** a la vez (oposición, curso de
especialidad…), cada uno con su progreso y estadísticas independientes.

Primer pack: `packs/zgz-tai.pack.json` (oposición Técnico/a Auxiliar Informática, Ayto. Zaragoza).

Objetivos: (1) herramienta real de estudio, gratuita y sin coste de servidor; (2) proyecto de
portfolio de una desarrolladora junior DAM → el código debe ser limpio, probado y explicable.

## Cómo trabajar conmigo (Leslie)

- Trabaja **fase a fase** (ver Roadmap). No empieces una fase sin que la anterior cumpla sus criterios.
- Antes de escribir código de una fase, **resume el plan en 5–10 líneas** y espera mi OK.
- **Explícame las decisiones**: tengo que poder defender este código en una entrevista. Tras cada
  fase, añade una sección a `docs/decisiones.md` (qué, por qué, alternativas descartadas).
- No añadas dependencias sin justificarlas. No uses paquetes abandonados.
- Al terminar cada tarea: `dart format .`, `flutter analyze` (0 avisos) y `flutter test` en verde.
- Commits pequeños con Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`).

## Stack

| Pieza | Elección | Motivo |
|---|---|---|
| UI | Flutter 3 / Dart 3, Material 3, modo claro/oscuro | Móvil + web con un solo código |
| Estado | Riverpod (con generador) | Testeable, sin contexto global |
| Navegación | go_router | URLs reales en web |
| Base de datos local | Drift (SQLite; en web vía WASM) | SQL tipado, migraciones, funciona en móvil y web |
| Modelos | freezed + json_serializable | Inmutables, parseo del pack |
| Tests | flutter_test + mocktail | Lógica de dominio al 100 % de lo crítico |

## Arquitectura (preparada para desplegar y sincronizar)

Feature-first con tres capas por feature:

```
lib/
  core/            # db (Drift), router, theme, utils, errores
  features/
    packs/         # importar, listar, activar, actualizar y borrar packs
    practice/      # práctica por tema/bloque/fuente
    exam/          # simulacro con reglas del pack
    review/        # repaso de fallos
    stats/         # resúmenes y estadísticas
    editor/        # (fase 6) crear/editar preguntas, CSV
  features/<x>/domain/        # entidades + interfaces de repositorio + casos de uso (Dart puro)
  features/<x>/data/          # implementaciones (Drift hoy; remoto mañana)
  features/<x>/presentation/  # widgets + providers
```

Reglas para que después se pueda añadir servidor (Supabase: Postgres + Auth, plan gratuito)
**sin reescribir la app**:

1. La UI y los casos de uso **solo conocen interfaces** (`PackRepository`, `ProgressRepository`…).
   Hoy se implementan con Drift; mañana se añade una implementación remota + sincronización.
2. Datos del usuario con **UUID v4**, `created_at`/`updated_at` en UTC y borrado lógico (`deleted_at`).
3. Las respuestas se guardan como **eventos inmutables** (tabla `answers`, solo INSERT). Estadísticas y
   estado de repaso se **derivan** de ellos → sincronizar es subir eventos nuevos.
4. Columna `user_id` presente (valor `'local'` hasta que exista login).
5. **Contenido del pack y datos del usuario en tablas separadas.** Actualizar o reimportar un pack
   reemplaza el contenido pero **nunca** borra respuestas: se enlazan por `pack_id` + `question_id`.
6. Toda consulta va filtrada por `pack_id` (multi-pack desde el día 1).

### Modelo de datos (Drift)

Contenido (se reemplaza al actualizar el pack): `packs`, `blocks`, `topics`, `sources`,
`source_exercises`, `contexts`, `questions` (opciones como JSON), `notes` (apuntes),
`exam_exercises` (reglas de simulacro).

Usuario (nunca se borra al actualizar un pack):
- `sessions` — id, user_id, pack_id, mode (`practice` | `exam` | `review`), config JSON, started_at, finished_at, score.
- `answers` — id, user_id, session_id, pack_id, question_id, chosen (null = en blanco), is_correct, time_ms, answered_at.
- `review_state` — pack_id, question_id, box (Leitner 0–4), correct_streak, next_due, updated_at (caché derivable de `answers`).
- `settings` — pack activo, preferencias, reglas de simulacro editadas por la usuaria.

Glosario pack → código: pregunta=`Question`, opciones=`options`, correcta=`correctKey`,
tema=`Topic`, bloque=`Block`, fuente=`Source`, contexto=`QuestionContext`, anulada=`voided`,
reserva=`isReserve`, apuntes=`Note`, simulacro=`ExamRules`.

## Reglas de negocio

- **Anuladas**: nunca puntúan ni aparecen en simulacro. En práctica, solo si se activa «ver anuladas» y
  mostrando `correcta_provisional` con aviso.
- **Reserva**: en simulacro solo entran para sustituir anuladas del mismo ejercicio. En práctica, normales.
- **Obsoletas**: excluidas por defecto (filtro para incluirlas).
- **Oficial vs estudio**: filtro en práctica y en estadísticas; el simulacro usa por defecto solo oficiales.
- **Puntuación del simulacro** (`puntuacion` de cada ejercicio, editable por la usuaria):
  - `fijo`: nota = aciertos·acierto + fallos·fallo + blancos·blanco.
  - `proporcional` (pack de Zaragoza): valorables = preguntas del ejercicio − anuladas no sustituidas por reserva;
    acierto = nota_maxima / valorables; fallo = −acierto · factor_fallo; blanco = 0.
    Ej. 1: 50 valorables → +0,200 / −0,050. Ej. 2: 25 → +0,400 / −0,100.
  - Redondeo aritmético simétrico (half-up) a `decimales`, usando `Decimal`, nunca `double` para el redondeo.
  - Mostrar «APTO / NO APTO» frente a `nota_minima`, y el nº de aciertos netos que faltaban para aprobar.
  - Tests obligatorios de `ScoreCalculator` con estos casos: ej. 1 con 30 aciertos y 20 fallos → 5,000 (apto);
    29 aciertos y 21 fallos → 4,750 (no apto); ej. 2 con 15 aciertos y 10 fallos → 5,000.
- **Simulacro completo**: ej. 1 (55 min) y a continuación ej. 2 (35 min); si el ej. 1 no llega a la nota mínima,
  el ej. 2 se muestra como «no corregido», igual que en el examen real.
- **Práctica**: feedback inmediato (correcta/incorrecta + explicación). **Simulacro**: sin feedback hasta
  entregar, con temporizador si hay `duracion_min`.
- **Repaso de fallos (Leitner)**: fallo → caja 0; acierto → sube una caja; se considera «dominada» con 3
  aciertos seguidos. Intervalos de caja: 0 d, 1 d, 3 d, 7 d, 14 d.
- **Supuestos**: el `contexto` se muestra encima de la pregunta; el `codigo` en fuente monoespaciada,
  con scroll horizontal y seleccionable.
- **Resumen final** de cada sesión: % aciertos / fallos / en blanco, desglose por tema, lista de falladas
  con botón «repasar estas».
- **Importación**: validar con `PackValidator` (mismas reglas que `tools/validate_pack.py`). Si el `pack.id`
  ya existe: versión mayor → actualizar; igual o menor → preguntar.

## Roadmap y criterios de aceptación

- **Fase 0 — Base** ✅ formato, esquema, validador Python, pack de Zaragoza. Pendiente en Flutter:
  `flutter create`, estructura de carpetas, dependencias, tema, router, CI (GitHub Actions: analyze + test).
- **Fase 1 — Datos**: esquema Drift + migraciones; parseo del pack; `PackValidator` en Dart con tests
  (casos válidos e inválidos); el pack de Zaragoza se importa al primer arranque desde el asset
  `packs/zgz-tai.pack.json` (declarado tal cual en `pubspec.yaml`, sin copiarlo a `assets/`: es la
  misma fuente que usan `tools/validate_pack.py` y `tools/build_zgz_pack.py`); pantalla de packs
  (lista, activar, importar desde fichero, borrar).
- **Fase 2 — Práctica**: elegir tema/bloque/fuente y nº de preguntas; pantalla de pregunta con
  contexto y código; feedback y explicación; guardar cada respuesta como evento.
- **Fase 3 — Repaso**: Leitner, contador de «pendientes hoy», sesión de repaso.
- **Fase 4 — Simulacro**: reglas del pack, temporizador, reserva/anuladas, entrega y nota.
- **Fase 5 — Estadísticas**: global y por tema, evolución por días, temas débiles.
- **Fase 6 — Personalización**: editor de preguntas, importar CSV (plantilla), exportar pack,
  exportar/importar progreso, pantalla «Crear pack con IA» que copia el prompt + esquema.
- **Fase 7 — Publicación**: web en GitHub Pages o Cloudflare Pages; APK en GitHub Releases;
  README de portfolio con capturas y GIF.
- **Fase 8 (opcional) — Nube**: Supabase (Auth + Postgres), `RemoteProgressRepository`, sincronización
  de eventos, packs compartidos.

## Comandos útiles

```bash
python3 tools/build_zgz_pack.py tools/fuentes packs/zgz-tai.pack.json  # regenerar el pack de Zaragoza
python3 tools/validate_pack.py packs/zgz-tai.pack.json   # validar un pack
dart run build_runner build                               # generar código (drift/freezed/riverpod)
flutter test
flutter run -d chrome
```

## No hacer

- No meter lógica de negocio en widgets.
- No acceder a Drift desde `presentation/`.
- No editar `packs/*.pack.json` a mano sin pasar el validador.
- No inventar respuestas «oficiales»: una pregunta es oficial solo si viene de una plantilla oficial.
