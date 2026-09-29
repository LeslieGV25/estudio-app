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
