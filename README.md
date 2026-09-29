# Estudio por packs

[![CI](https://github.com/LeslieGV25/estudio-app/actions/workflows/ci.yml/badge.svg)](https://github.com/LeslieGV25/estudio-app/actions/workflows/ci.yml)

App multiplataforma (Android y web) hecha con Flutter para preparar exámenes con tests: práctica por temas,
simulacros con las reglas del examen real, repaso inteligente de fallos y estadísticas.

El contenido se carga mediante **packs** intercambiables, así que sirve para cualquier oposición, curso o
certificación. Incluye de serie el pack de la oposición de Técnico/a Auxiliar Informática del Ayuntamiento de
Zaragoza: 192 preguntas de exámenes oficiales con plantilla definitiva y 168 de estudio.

> 🚧 En desarrollo. Plan y arquitectura en [`CLAUDE.md`](CLAUDE.md).

## Estructura actual

```
packs/            packs de contenido (*.pack.json)
schema/           esquema JSON del formato de pack
tools/            validador y scripts de construcción de packs
docs/             documentación (formato de pack, decisiones)
```

## Validar un pack

```bash
pip install jsonschema
python3 tools/validate_pack.py packs/zgz-tai.pack.json
```
