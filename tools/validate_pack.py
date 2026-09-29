#!/usr/bin/env python3
"""Valida un pack de estudio: esquema JSON + reglas de coherencia.

Uso:  python3 tools/validate_pack.py packs/zgz-tai.pack.json
Requiere: pip install jsonschema

Estas mismas reglas deben implementarse en Dart (PackValidator) para que
la app rechace packs inválidos al importarlos.
"""
import json
import sys
from collections import Counter
from pathlib import Path

from jsonschema import Draft202012Validator

SCHEMA = Path(__file__).resolve().parent.parent / "schema" / "pack.schema.json"


def validar(pack: dict) -> list[str]:
    errores: list[str] = []

    # 1. Esquema
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    for e in sorted(Draft202012Validator(schema).iter_errors(pack), key=lambda e: list(e.path)):
        ruta = "/".join(str(p) for p in e.path) or "(raíz)"
        errores.append(f"[esquema] {ruta}: {e.message}")
    if errores:
        return errores  # sin esquema válido no tiene sentido seguir

    # 2. Coherencia
    bloques = {b["id"] for b in pack["temario"]["bloques"]}
    temas = {t["id"] for t in pack["temario"]["temas"]}
    for t in pack["temario"]["temas"]:
        if t["bloque"] not in bloques:
            errores.append(f"tema {t['id']}: bloque {t['bloque']} no existe")

    def duplicados(nombre, ids):
        for i, n in Counter(ids).items():
            if n > 1:
                errores.append(f"{nombre} duplicado: {i}")

    duplicados("bloque", [b["id"] for b in pack["temario"]["bloques"]])
    duplicados("tema", [t["id"] for t in pack["temario"]["temas"]])
    duplicados("fuente", [f["id"] for f in pack["fuentes"]])
    duplicados("contexto", [c["id"] for c in pack.get("contextos", [])])
    duplicados("pregunta", [p["id"] for p in pack["preguntas"]])
    duplicados("apunte", [a["id"] for a in pack.get("apuntes", [])])

    fuentes = {f["id"]: f for f in pack["fuentes"]}
    contextos = {c["id"] for c in pack.get("contextos", [])}
    sim_ej = {e["id"] for e in pack.get("simulacro", {}).get("ejercicios", [])}
    for f in pack["fuentes"]:
        for ej in f.get("ejercicios", []):
            if "simulacro" in ej and ej["simulacro"] not in sim_ej:
                errores.append(f"fuente {f['id']}/{ej['id']}: simulacro '{ej['simulacro']}' no existe")

    for p in pack["preguntas"]:
        pid = p["id"]
        f = fuentes.get(p["fuente"])
        if f is None:
            errores.append(f"{pid}: fuente '{p['fuente']}' no existe")
            continue
        if p["tema"] not in temas:
            errores.append(f"{pid}: tema {p['tema']} no existe")
        if p.get("contexto") and p["contexto"] not in contextos:
            errores.append(f"{pid}: contexto '{p['contexto']}' no existe")
        letras = sorted(p["opciones"])
        if letras != [chr(ord('a') + i) for i in range(len(letras))]:
            errores.append(f"{pid}: las opciones deben ser a, b, c… consecutivas (hay {letras})")
        ejs = {e["id"]: e for e in f.get("ejercicios", [])}
        if "ejercicio" in p:
            ej = ejs.get(p["ejercicio"])
            if ej is None:
                errores.append(f"{pid}: ejercicio '{p['ejercicio']}' no existe en la fuente {f['id']}")
            elif len(p["opciones"]) != ej["num_opciones"]:
                errores.append(f"{pid}: tiene {len(p['opciones'])} opciones y el ejercicio exige {ej['num_opciones']}")
        anulada = p.get("anulada", False)
        if anulada and p["correcta"] is not None:
            errores.append(f"{pid}: anulada pero con respuesta correcta")
        if not anulada:
            if p["correcta"] is None:
                errores.append(f"{pid}: sin respuesta correcta y no está anulada")
            elif p["correcta"] not in p["opciones"]:
                errores.append(f"{pid}: la correcta '{p['correcta']}' no es una opción")
        if "correcta_provisional" in p and p["correcta_provisional"] not in p["opciones"]:
            errores.append(f"{pid}: correcta_provisional no es una opción")
        if len(set(p["opciones"].values())) != len(p["opciones"]):
            errores.append(f"{pid}: opciones repetidas")

    for a in pack.get("apuntes", []):
        if a["tema"] not in temas:
            errores.append(f"apunte {a['id']}: tema {a['tema']} no existe")
    return errores


def resumen(pack: dict) -> str:
    ps = pack["preguntas"]
    fuentes = {f["id"]: f for f in pack["fuentes"]}
    validas = [p for p in ps if not p.get("anulada")]
    oficiales = [p for p in validas if fuentes[p["fuente"]]["oficial"]]
    por_fuente = Counter(p["fuente"] for p in validas)
    lineas = [
        f"Pack: {pack['pack']['nombre']} v{pack['pack']['version']}",
        f"Temas: {len(pack['temario']['temas'])} | Preguntas: {len(ps)} "
        f"({len(validas)} válidas, {len(ps) - len(validas)} anuladas) | Oficiales válidas: {len(oficiales)}",
    ]
    lineas += [f"  - {fuentes[f]['nombre']}: {n}" for f, n in por_fuente.items()]
    return "\n".join(lineas)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    errs = validar(data)
    if errs:
        print(f"❌ {len(errs)} error(es):")
        print("\n".join(f"  {e}" for e in errs[:50]))
        sys.exit(1)
    print("✅ Pack válido")
    print(resumen(data))
