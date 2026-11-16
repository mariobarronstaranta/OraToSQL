# Validacion local del 2026-11-06

Ejecutado `../tests_lotes_08.py` en LocalDB. Resultado: aprobado.

- 17 archivos; cobertura exacta de 65 tablas sin repeticiones.
- Huellas de los SQL comprobadas contra manifest.json.
- Vista previa de cada archivo contiene solo sus tablas y en el orden del 07.
- Aplicacion secuencial: 65 PK creadas al finalizar.
- Se crearon tambien las 16 tablas fuera del alcance con datos NULL para
  detectar inclusion accidental: ninguna fue procesada ni recibio PK.
- Una segunda vista previa por lote reconoce sus PK ya existentes.
- CLIENTE se probo con indice original deshabilitado.

Se usaron tablas ficticias pequenas. Esta prueba verifica aislamiento y
ejecucion, no rendimiento ni duracion sobre los volumenes de T3QA.
El instalador base tiene ademas sus pruebas de rollback y DDL reales,
documentadas en ../GUIA_INSTALADOR_05.md.

Base temporal CodexPKLotes_d1410016 eliminada. No se conecto a T3QA.
