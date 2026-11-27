# Rendimiento y fidelidad de faperu

Medido el 26 de noviembre de 2026 con faperu 0.3.0, R 4.6.2, data.table 1.18.4 y haven 2.5.5,
en Arch Linux con un Intel Core i5-12500H (16 hilos) y 30 GB de RAM. Las descargas son reales,
desde el portal del INEI y en una caché vacía; los tiempos de lectura son la mediana de 3
corridas. *Measured on 26 November 2026; downloads are real, read times are the median of 3 runs.*

## Resumen / Summary

- **Leer solo las columnas que necesitas es lo que más ahorra.** En la ENAHO 2024 de empleo
  (1425 columnas), 8 columnas en Stata toman 0,69 s y 93 MB de memoria; el archivo entero, 11,6 s
  y 1,9 GB.
- **Los tres formatos dan los mismos valores** en los cuatro módulos medidos (abajo, la tabla de
  fidelidad).
- **Stata es el formato por defecto por exactitud, no por velocidad.** Trae etiquetas de
  variables y de valores, y no tiene el problema de las filas partidas de algunos CSV del INEI
  (ENUT 2024). El CSV leído con data.table es el más rápido de todos; si no necesitas etiquetas,
  `format = "CSV"` es una buena opción.
- **Sin data.table, evita el CSV**: base R es de 10 a 20 veces más lento en archivos grandes.
- **Descargar en paralelo ayuda, pero depende del servidor del INEI.** Con 7 módulos de la ENUT
  2024 fue 1,3 veces más rápido hoy; en una medición anterior (23 de noviembre) fue 2,6 veces.
  El servidor limita cuánto se gana.

## Descarga / Download

Un módulo por vez, caché vacía.

| Módulo | Formato | MB | Segundos | MB/s |
|---|---|---:|---:|---:|
| ENARES 2024, hogares | CSV | 1,2 | 1,8 | 0,6 |
| | Stata | 1,3 | 2,0 | 0,7 |
| | SPSS | 1,4 | 2,0 | 0,7 |
| ENUT 2024, residentes | CSV | 0,3 | 0,7 | 0,5 |
| | Stata | 0,5 | 0,8 | 0,5 |
| | SPSS | 0,7 | 0,9 | 0,7 |
| EPEN 2024, anual | CSV | 15,7 | 4,1 | 3,9 |
| | Stata | 23,0 | 13,8 | 1,7 |
| | SPSS | 20,1 | 13,5 | 1,5 |
| ENAHO 2024, empleo (módulo 5) | CSV | 17,8 | 6,9 | 2,6 |
| | Stata | 16,7 | 9,7 | 1,7 |
| | SPSS | 18,4 | 9,9 | 1,9 |

Siete módulos de la ENUT 2024 (SPSS): 19,7 s de uno en uno y 15,2 s de cuatro en cuatro
(`options(faperu.connections = 4)`, el valor por defecto).

## Lectura / Read

`todo` es el archivo entero y `cols` son las pocas variables de un análisis típico
(identificadores, ubicación, factor y una variable de interés). "Memoria" es el pico de memoria
de R durante la lectura.

| Módulo | Filas | Formato | Motor | Lee | Columnas | Segundos | Memoria (MB) | Etiquetas |
|---|---:|---|---|---|---:|---:|---:|---:|
| ENAHO 2024 empleo | 85 992 | CSV | data.table | todo | 1425 | 1,03 | 895 | 0 |
| | | CSV | data.table | cols | 8 | 0,27 | 58 | 0 |
| | | CSV | base | todo | 1425 | 22,11 | 1885 | 0 |
| | | CSV | base | cols | 8 | 5,76 | 83 | 0 |
| | | Stata | haven | todo | 1425 | 11,55 | 1936 | 1425 |
| | | Stata | haven | cols | 8 | 0,69 | 93 | 8 |
| | | SPSS | haven | todo | 1425 | 16,45 | 1936 | 1425 |
| | | SPSS | haven | cols | 8 | 1,56 | 93 | 8 |
| EPEN 2024 anual | 465 598 | CSV | data.table | todo | 132 | 0,77 | 543 | 0 |
| | | CSV | data.table | cols | 5 | 0,20 | 135 | 0 |
| | | CSV | base | todo | 132 | 10,14 | 793 | 0 |
| | | CSV | base | cols | 5 | 3,04 | 269 | 0 |
| | | Stata | haven | todo | 132 | 5,99 | 990 | 132 |
| | | Stata | haven | cols | 5 | 0,74 | 143 | 5 |
| | | SPSS | haven | todo | 132 | 5,88 | 990 | 132 |
| | | SPSS | haven | cols | 5 | 1,01 | 143 | 5 |
| ENUT 2024 residentes | 18 468 | CSV | data.table | todo | 73 | 0,18 | 59 | 0 |
| | | Stata | haven | todo | 73 | 0,22 | 71 | 73 |
| | | Stata | haven | cols | 3 | 0,03 | 11 | 3 |
| ENARES 2024 hogares | 13 826 | CSV | data.table | todo | 49 | 0,03 | 47 | 0 |
| | | Stata | haven | todo | 49 | 0,09 | 47 | 48 |
| | | Stata | haven | cols | 4 | 0,02 | 14 | 3 |

En módulos pequeños (ENUT, ENARES) todo se lee en menos de medio segundo y el formato da igual.
La tabla completa, con todas las combinaciones, la escribe el script en
`faperu-bench-read-<fecha>.csv`.

## Fidelidad entre formatos / Same values across formats

Las columnas de `cols` de cada módulo, leídas en CSV, Stata y SPSS y comparadas valor por valor
(números con `all.equal`, texto sin espacios sobrantes):

| Módulo | CSV = Stata | CSV = SPSS | Stata = SPSS |
|---|---|---|---|
| ENARES 2024 hogares | Sí | Sí | Sí |
| ENUT 2024 residentes | Sí | Sí | Sí |
| EPEN 2024 anual | Sí | Sí | Sí |
| ENAHO 2024 empleo | Sí | Sí | Sí |

<!-- VERIFY_FORMATS -->

## Cómo repetirlo / How to rerun

```r
# Tiempos de descarga y lectura (5 a 10 minutos, unos 400 MB en una carpeta temporal)
source(system.file("scripts", "benchmark.R", package = "faperu"))

# Todos los archivos de datos en Stata, SPSS y CSV, comparados (unos 1,5 GB la primera vez)
source(system.file("scripts", "verify_formats.R", package = "faperu"))

# Las 10 bases de punta a punta, año reciente y antiguo
source(system.file("scripts", "integration.R", package = "faperu"))
```

Las tablas se guardan como CSV en la carpeta de `FAPERU_OUT` (por defecto, la de trabajo). Los
tiempos de descarga dependen sobre todo del servidor del INEI y cambian de un día a otro.
