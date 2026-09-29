#!/usr/bin/env python3
"""Une temario + exámenes + preguntas de estudio en un único pack (formato v1)."""
import json, sys
from pathlib import Path
SRC = Path(sys.argv[1]); OUT = Path(sys.argv[2])
load = lambda n: json.loads((SRC / n).read_text(encoding="utf-8"))
tm = load("temario.json")
examenes = [("zgz-2026-tl", "examen_2026_tl.json", "Examen 28/04/2026 · Turno libre", True),
            ("zgz-2024-tl", "examen_2024_tl.json", "Examen 26/11/2024 · Turno libre", True),
            ("zgz-2023-le", "examen_2023_le.json", "Examen 29/09/2023 · Lista de espera", True),
            ("estudio-cuadernillo", "estudio_cuadernillo.json", "Preguntas de estudio (cuadernillo revisado)", False)]
SIM = {3: "ej1", 4: "ej2"}
fuentes, contextos, preguntas = [], [], []
for fid, fname, nombre, oficial in examenes:
    ex = load(fname)
    f = {"id": fid, "tipo": "examen" if oficial else "estudio", "nombre": nombre, "oficial": oficial,
         "fecha": ex.get("fecha_examen"), "convocatoria": ex["convocatoria"],
         "respuestas": ex["fuente_respuestas"], "ejercicios": []}
    if ex.get("turno") and ex["turno"] != "estudio": f["turno"] = ex["turno"]
    for ej in ex["ejercicios"]:
        e = {"id": ej["id"], "nombre": ej["nombre"], "num_opciones": ej["num_opciones"]}
        if oficial: e["simulacro"] = SIM[ej["num_opciones"]]
        f["ejercicios"].append(e)
        cmap = {}
        for c in ej["contextos"]:
            nid = f"{fid}-{ej['id']}-{c['id']}"; cmap[c["id"]] = nid
            nc = {"id": nid, "titulo": c["titulo"], "enunciado": c["enunciado"]}
            if c.get("codigo"): nc["codigo"] = c["codigo"]; nc["lenguaje"] = c.get("lenguaje", "text")
            contextos.append(nc)
        for p in ej["preguntas"]:
            q = {"id": p["id"], "fuente": fid, "ejercicio": ej["id"], "numero": p["numero"], "tema": p["tema"],
                 "contexto": cmap.get(p["contexto"]) if p["contexto"] else None,
                 "enunciado": p["enunciado"], "opciones": p["opciones"], "correcta": p["correcta"]}
            for k in ("reserva", "anulada"):
                if p.get(k): q[k] = True
            for k in ("correcta_provisional", "explicacion", "notas"):
                if p.get(k): q[k] = p[k]
            preguntas.append(q)
    fuentes.append(f)
PROP = {"modo": "proporcional", "nota_maxima": 10, "factor_fallo": 0.25, "blanco": 0, "nota_minima": 5, "decimales": 3}
pack = {
 "formato": "estudio-pack", "version_formato": 1,
 "pack": {"id": "zgz-tecnico-aux-informatica", "nombre": "Técnico/a Auxiliar Informática · Ayto. Zaragoza",
          "descripcion": "Oposición C1 del Ayuntamiento de Zaragoza (OEP 2026). Exámenes oficiales de turno libre y lista de espera con plantilla definitiva, más preguntas de estudio revisadas.",
          "version": "1.1.0", "tipo": "oposicion", "idioma": "es-ES", "autor": "Leslie González", "actualizado": "2026-09-28"},
 "temario": {"bloques": tm["bloques"] and [{"id": b["id"], "nombre": b["nombre"]} for b in tm["bloques"]],
             "temas": tm["temas"]},
 "simulacro": {
   "nota": "Bases generales C1, apdo. 7.4.C: ejercicios el mismo día, eliminatorios, mínimo 5 sobre 10 en cada uno. Acierto = 10 / preguntas valorables; cada fallo resta 1/4 de un acierto; en blanco no penaliza. Redondeo a 3 decimales. El 2.º ejercicio solo se corrige si se supera el 1.º (y la nota de corte del tribunal).",
   "ejercicios": [
     {"id": "ej1", "nombre": "Primer ejercicio (teórico)", "num_preguntas": 50, "num_reserva": 5, "num_opciones": 3,
      "duracion_min": 55, "con_supuestos": False, "puntuacion": PROP},
     {"id": "ej2", "nombre": "Segundo ejercicio (supuestos prácticos)", "num_preguntas": 25, "num_reserva": 0, "num_opciones": 4,
      "duracion_min": 35, "con_supuestos": True, "puntuacion": PROP}]},
 "fuentes": fuentes, "contextos": contextos, "preguntas": preguntas, "apuntes": []}
OUT.write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"{OUT}: {len(preguntas)} preguntas, {len(contextos)} contextos")
