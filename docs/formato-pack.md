# Formato de pack (v1)

Un **pack** es un único fichero JSON (`*.pack.json`) con todo lo necesario para estudiar un examen:
temario, preguntas y, opcionalmente, reglas de simulacro y apuntes. La app no conoce ningún examen
concreto: solo sabe leer packs. Esquema formal: [`schema/pack.schema.json`](../schema/pack.schema.json).

## Estructura

| Clave | Obligatoria | Qué contiene |
|---|---|---|
| `formato`, `version_formato` | sí | Siempre `"estudio-pack"` y `1`. |
| `pack` | sí | `id` estable, `nombre`, `version` (semver), `tipo` (`oposicion`, `curso`, `certificacion`, `otro`), `idioma`. |
| `temario` | sí | `bloques` (id, nombre) y `temas` (id, bloque, titulo). |
| `fuentes` | sí | De dónde salen las preguntas. `oficial: true` solo con plantilla oficial. |
| `preguntas` | sí | Lista plana. Cada pregunta indica `fuente`, `tema` y, si aplica, `ejercicio` y `contexto`. |
| `contextos` | no | Enunciados compartidos (supuestos prácticos), con `codigo` y `lenguaje` opcionales. |
| `simulacro` | no | Ejercicios del examen real: nº de preguntas, reserva, opciones, duración y puntuación. |
| `apuntes` | no | Resúmenes y tips por tema, en Markdown. |

## Reglas importantes

- **Los `id` de pack y de pregunta no cambian nunca.** El progreso del usuario se guarda por id de pregunta;
  si una pregunta cambia de texto en una versión nueva del pack, conserva su id y el progreso sigue valiendo.
- Las opciones son letras consecutivas `a`, `b`, `c`… (de 2 a 6).
- `correcta` es `null` **solo** si `anulada: true`. En ese caso se puede guardar `correcta_provisional`.
- Las preguntas `reserva: true` solo entran en el simulacro cuando sustituyen a una anulada.
- `obsoleta: true` marca preguntas cuya respuesta depende de normativa derogada: la app las excluye por defecto.

## Cómo crear un pack

1. Copia `packs/ejemplo-minimo.pack.json` y rellénalo.
2. O convierte tus PDF con cualquier chat de IA pegando el esquema y pidiendo que respete el formato.
3. Valida antes de importar:

```bash
pip install jsonschema
python3 tools/validate_pack.py packs/mi-pack.pack.json
```
