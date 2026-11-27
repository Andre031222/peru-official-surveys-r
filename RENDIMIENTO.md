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

## Verificación de filas, columnas y valores / Row, column and value check

`inst/scripts/verify_formats.R` baja cada formato de una muestra de módulos de las 8 encuestas del
INEI (año reciente y uno antiguo), lee cada archivo de datos y compara filas, columnas y, columna
por columna, los valores ordenados. Corrida del 26 de noviembre de 2026:

| Encuesta | Archivos | Filas iguales y columnas iguales | Difieren | En un solo formato |
|---|---|---|---|---|
| ENAHO | 18 | 18 | 0 | 0 |
| ENDES | 9 | 9 | 0 | 0 |
| ENA | 34 | 32 | 1 | 1 |
| EPEN | 31 | 30 | 1 | 0 |
| ENAPRES | 13 | 13 | 0 | 0 |
| ENUT | 13 | 7 | 0 | 6 |
| ENARES | 44 | 44 | 0 | 0 |
| EEA | 595 | 594 | 1 | 0 |
| Total | 757 | 747 | 3 | 7 |

Sobre unos 12,7 millones de filas leídas, ningún formato perdió ni partió filas: todas las filas
coinciden entre Stata, SPSS y CSV en los 747 archivos que se pueden comparar. Los 7 archivos de un
solo formato son tablas que el INEI publica en uno solo.

Las 3 diferencias son de los propios archivos del INEI, no de faperu:

| Archivo | Qué pasa |
|---|---|
| ENA 2016, módulo 1122, `01_cap100_1` | El SPSS trae dos columnas más (`CCCP` y `NOMBRECP`) que el Stata. Mismas filas. |
| EPEN 2025, módulo 1780 (Piura, trimestre 1) | Al SPSS le falta `CODCIUDAD`, que sí traen Stata y CSV. Mismas filas. |
| EEA 2024, módulo 2048, `a2023_s08_fF2_c03_1` | El CSV del INEI es un archivo de 25 bytes con una línea de encabezado y otra de texto; el SPSS trae 8352 filas. faperu lo lee tal cual. |

Valores: de los 750 archivos con al menos dos formatos, 683 son idénticos y 67 muestran alguna
diferencia en alguna columna. Todas tienen una causa conocida (un archivo puede tener varias):

| Causa | Archivos | Qué es |
|---|---|---|
| Precisión de coma flotante | 39 | Stata guarda coordenadas y factores como flotante de 4 bytes y el CSV trae más decimales. |
| Código de "no sabe" en el CSV | 25 | El CSV conserva 9, 99, 999999, 99999,9 y similares; Stata y SPSS los marcan como perdidos. |
| Texto cortado por ancho | 2 | Stata mide el ancho en bytes y corta textos con tilde antes que el SPSS. |
| Saltos de línea dentro del texto | 1 | ENUT 2024 (observaciones): en el CSV sin comillas la línea partida se une con un espacio. |
| Diferencias propias del INEI | 3 | ENAHO 2024 tabla CIUO-88 (el texto de 4 de 5195 filas difiere entre Stata y SPSS), y los nombres `DATO1` a `DATO4` del SPSS que el CSV de la EEA 2024 (módulo 2053, `c15B_1`) llama `DATO2` a `DATO5`, con los mismos valores por posición. |

Verificación del Censo Educativo (ESCALE): 31 archivos DBF de 2015 y 2025 (sin los padrones de
escuelas, que traen datos personales y nunca se descargan en estas pruebas); en todos el número de
filas leído es igual al que dice la cabecera del DBF. El Censo 2017 por REDATAM da 29 381 884
personas, la cifra oficial.

## Errores que encontró esta verificación (corregidos en 0.3.0)

- ENUT 2024 en CSV: fread se detenía en silencio en la fila 9768 de 18 468 y read.csv partía filas
  con saltos de línea; ahora se reparan las filas partidas y lo que no se pueda reparar se avisa.
- CSV en UTF-8 convertido dos veces (FERREÑAFE salía FERREÃ‘AFE) y ceros a la izquierda perdidos
  (CONGLOME 07060 salía 7060).
- Stata del INEI con texto UTF-8 mezclado con bytes Latin-1 (ENARES 2019, 9 archivos) detenía haven;
  los valores y las etiquetas salían como `CAÃ‘ETE`.
- Comillas escapadas dentro de un campo CSV (`2"" TRANSP`) quedaban dobles.
- Un zip con el mismo nombre en CSV, Stata y SPSS devolvía el formato equivocado desde la caché.
- Un código de módulo ambiguo (EPEN 2025 "1780" son cinco) descargaba todos antes de fallar.


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
