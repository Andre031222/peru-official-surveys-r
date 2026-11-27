# faperu 0.4.0

faperu and faperu.analysis are now one package. Everything that was in faperu.analysis lives here
with the same `fa_` prefix, so one `library(faperu)` gets the data and analyses it.

- New: `fa_estimate()` (means, proportions and totals by domain with standard error, confidence
  interval, coefficient of variation and the INEI quality band), `fa_quality()`,
  `fa_indicator()` and `fa_indicators()` (seven indicators checked against INEI's 2024
  figures), `fa_link()` (joins estimates from different surveys by department or district and
  year), `fa_geometry()`, `fa_map()` and `fa_table()`.
- `fa_estimate` results have `print()`, `summary()` and `plot()` methods; `fa_link` results
  print a short report.
- Renamed from faperu.analysis: `fpa_*` functions are now `fa_*`; error classes `fpa_error*`
  are now `faperu_error*`; the environment variable `FPA_ONLINE` is now `FAPERU_ONLINE`.
- New vignette "Analysis: estimates, indicators and maps" and the article "Galería".
- ggplot2 and sf are suggested, only needed for `fa_map()` and `fa_geometry()`.

- `fa_surveys()`, `fa_catalog()`, `fa_download()` and `fa_check_updates()` return data frames
  with a class (`fa_surveys`, `fa_catalog`, `fa_download`, `fa_updates`) that prints a short
  report; `summary()` of a catalog counts its modules by year. Nothing changes when they are
  used as data frames.

# faperu 0.3.0

Probado de punta a punta con las 10 bases: descarga, caché, lectura por columnas, diseño y
REDATAM, en el año más reciente y en uno antiguo de cada una. Detalle y cifras en
[RENDIMIENTO.md](RENDIMIENTO.md).

## Descarga

- `fa_download()` baja los archivos que faltan en paralelo (`options(faperu.connections = 4)`,
  entre 1,3 y 2,6 veces más rápido con 7 módulos, según el servidor), reintenta y reanuda las transferencias cortadas
  (`options(faperu.retries = 3)`, con espera creciente) y revisa que cada archivo sea un zip
  legible antes de guardarlo: una página de error del servidor nunca entra a la caché.
- Devuelve también el tamaño (`bytes`) y el tiempo (`seconds`) de cada descarga.
- Con `format = "auto"`, si el portal no sirve un formato (404) prueba el siguiente: EPE Lima
  2015 aparece con CSV en el portal pero solo existe en SPSS.
- `format = "auto"` prefiere ahora Stata, luego SPSS, CSV y DBF. Stata se lee exacto, con
  etiquetas, y rápido cuando se piden columnas.
- Cada formato de un módulo tiene su lugar en la caché. El INEI da el mismo nombre al zip CSV,
  Stata y SPSS, y antes pedir Stata después de CSV devolvía el CSV.
- Un módulo que el INEI cambió después del catálogo se baja una vez: faperu guarda su SHA-256
  y su formato al lado del zip y ya no lo vuelve a bajar en cada llamada.
- Un módulo se puede pedir por su nombre (el Censo Educativo 2025 tiene dos módulos "00").
- 41 entradas del catálogo de ENA y ENDES decían CSV o SPSS y la copia local era Stata.

## Años fuera del catálogo

- `fa_catalog()`, `fa_download()` y `fa_read()` buscan en la fuente un año que el catálogo no
  tiene: en el portal del INEI para sus encuestas (ENDES 2009, EEA 2025 o un año publicado
  después de esta versión) y en la carpeta de ESCALE para el Censo Educativo (2004-2024). Se
  consulta una vez por sesión; sin conexión avisa y deja el catálogo como está.

## Lectura

- `fa_read()` gana `cols` para leer solo algunas variables, en cualquier mayúscula y en el
  orden pedido. En la ENAHO 2024 de empleo (1425 columnas) leer 8 columnas en Stata toma
  0,6 s frente a 10 s del archivo entero, con 66 MB de memoria en vez de 994 MB.
- Nueva `fa_variables()`: nombres, etiquetas y tipo de cada variable leyendo solo la cabecera.
- Lee DBF (Censo Educativo hasta 2018 y el formato DBF del INEI) con foreign.
- CSV: con data.table cuando está instalado (`options(faperu.csv_engine = "base")` para base R).
  Los CSV del INEI vienen en Latin-1 o en UTF-8 según el año; solo se convierte el texto que no
  es UTF-8 válido (antes FERREÑAFE salía FERREÃ‘AFE en ENARES 2024). Los códigos con cero a la
  izquierda (CONGLOME 07060, NSELV 0002) quedan como texto, igual que en Stata y SPSS. Una fila
  partida por un salto de línea sin comillas se repara; lo que no se puede reparar se avisa con
  la clase `faperu_warning_csv` y el resto se lee completo (fread se detenía en silencio en la
  fila 9768 de 18468 de la ENUT 2024). Se quita el BOM del encabezado.
- Solo se descomprimen los archivos de datos. Los nombres en Latin-1 dentro del zip (un PDF de
  la EEA 2010, otro de ENARES 2024) ya no rompen la descompresión en discos NTFS ni la
  detección del formato.
- Cuando un zip trae el mismo cuadro en varios formatos (EPEN Lima 2026) se lee el pedido.
- Algunos Stata del INEI mezclan texto UTF-8 con bytes Latin-1 y haven se detenía ("Unable to
  convert string"; ENARES 2019, 9 archivos). Ahora se leen y el texto queda igual al del SPSS
  (CAÑETE, no CAÃ‘ETE). Lo mismo se corrige en las etiquetas y en los pocos valores así de los
  SPSS (EEA 2015).
- En CSV, una comilla escapada dentro de un campo (`"CINTA 2"" TRANSP"`) se lee como una sola
  comilla, igual que en Stata y SPSS; fread la dejaba doble.
- `fa_read()` y `fa_variables()` avisan que un código es ambiguo antes de descargar; antes bajaban
  todos los módulos con ese código (EPEN 2025 "1780" son cinco).

## Diseño

- Nombres de los años antiguos, vistos en las cabeceras: ENA 2014 (`FACTOR`, `CONGLOMERADO`),
  ENAPRES 2015 (`FACTORANUAL`), ENUT 2010 (`Factor_100`, `CONGLOMERADO`), ENARES 2013
  (`FACEXP*`, `C1CONGLOME`) y EEA 2012-2020 (`FACTOR`, `FAC_EXP`). La EEA de 2001 a 2011 no trae
  factor de expansión.
- La ENA quita las entrevistas incompletas, que no tienen factor (986 filas en 2024).

## Scripts

- `inst/scripts/prueba_faperu.R`: prueba rápida de las 10 bases con tabla de tiempos, en
  español, para correr con `Rscript` o paso a paso en RStudio.
- `inst/scripts/integration.R`: las 10 bases, año reciente y antiguo, de punta a punta.
- `inst/scripts/verify_formats.R`: filas, columnas y valores de cada archivo en Stata, SPSS y CSV,
  con la causa de cada diferencia.
- `inst/scripts/benchmark.R`: tiempos de descarga y lectura por formato.
- Pruebas contra las fuentes reales con `FAPERU_ONLINE=1`. Las que usan una copia local de los
  microdatos corren solo con `FAPERU_LOCAL` apuntando a ella; el paquete ya no trae rutas de una
  máquina concreta.

## Paquete

- Versiones mínimas declaradas: curl 5.0.0 (`multi_download()`), haven 2.4.0 y tidyselect 1.1.0.
- Configuración de pkgdown (`_pkgdown.yml`) para el sitio del paquete.

# faperu 0.2.0

- `fa_ubigeo()` gains `year` and `base` to translate INEI district codes between years, adding
  `ubigeo_base` and `ubigeo_status`. Base 2017 is the 2017 Census frame (1874 districts). The
  tables in `inst/ubigeo/` come from INEI's RENAMU 2004-2025, the 2025 National Directory, the
  2017 census frame and, for the 18 districts created after 2017, MINEDU's 2025 school register
  (not yet checked against each law). `data-raw/` rebuilds them.
- New `fa_districts()` lists the districts valid in a year.
- `fa_catalog()` shows each file's `period`, and `fa_download()` and `fa_read()` take a `period`
  filter, so EPEN's annual file can be told apart from the department files of the same year.
- `fa_design()` now covers EPEN, ENAPRES, ENUT, ENARES and the Annual Economic Survey, with names
  checked in INEI's technical sheets and in real 2024-2025 file headers. Strata can cross two
  columns (`"CCDD*AREA"`), weights can be matched by pattern (EPE Lima), EPEN rows without weight
  are dropped, surveys without published strata or clusters warn instead of failing, and certainty
  firms in the EEA get their own stratum. It warns when a stratum has a single cluster and
  `survey.lonely.psu` is not set.
- New `fa_redatam()` queries the 2017 Census. INEI does not publish its microdata; CELADE's full
  REDATAM database (redatam.org) is downloaded once into the cache with a SHA-256 check and
  queried with redatamx, which is only suggested. `fa_read()` points to it for the census.
- `fa_read()` detects `;` separators with decimal commas (ENAHO 2025) and keeps `UBIGEO`, `CCDD`,
  `CCPP`, `CCDI`, `IRUC` and `NSEGM` as text in CSV files.
- Tests reproduce four official 2024 figures from the local microdata: poverty 27.6 % (ENAHO),
  unemployment 5.6 % and informality 70.9 % (EPEN), women producers 31.5 % (ENA).

# faperu 0.1.0

First version, not released yet.

- Catalog of ten sources: ENAHO, ENDES, ENA, EPEN, ENAPRES, ENUT, ENARES, the Annual Economic
  Survey, the School Census (ESCALE) and the 2017 National Censuses. RENIPRESS was dropped because
  only seven months of 2026 are online.
- `fa_surveys()`, `fa_years()` and `fa_catalog()` to explore the catalog.
- `fa_download()` with a SHA-256 checked cache that can point to an existing copy.
- `fa_read()` for SPSS, Stata and CSV inside INEI zip files, with labels.
- `fa_design()` builds the survey design for ENAHO, ENDES and ENA.
- `fa_ubigeo()` adds standard ubigeo, province and department columns.
- `fa_check_updates()` asks INEI and ESCALE which years are published.
- Errors have class `faperu_error` and a specific subclass.
