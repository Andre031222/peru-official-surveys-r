# faperu

**Las encuestas y censos oficiales del Perú en R, con una sola forma de pedirlos.**
*Peru's official surveys and censuses in R, asked for one way.*

Doce funciones, siete dependencias externas (`curl`, `digest`, `foreign`, `haven`, `survey`,
`tidyselect`, `yaml`) y un catálogo en texto. Cada archivo se guarda en caché y se comprueba con sha256. Los años nuevos se detectan solos.

> [!NOTE]
> **English** — faperu downloads, caches (SHA-256 checked), reads and weights ten official Peruvian
> data sources: ENAHO, ENDES, ENA, EPEN, ENAPRES, ENUT, ENARES, the Annual Economic Survey, the
> School Census (ESCALE) and the 2017 National Censuses. It is independent and not affiliated with
> INEI or MINEDU, and it never redistributes microdata. Function docs are in English; this README
> is mostly in Spanish.

## Empezar / Get started

```r
remotes::install_github("Andre031222/faperu")   # cuando el repositorio esté publicado

library(faperu)
s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
survey::svymean(~I(pobreza < 3), fa_design(s, "enaho"))
```

Baja la Sumaria de la ENAHO 2024, la lee y da la proporción de hogares pobres con su error estándar
(21,9 %). Con el peso por persona sale la cifra oficial del INEI, 27,6 %; está en la guía.
*Downloads ENAHO 2024 summaries and gives the share of poor households with its standard error.
Weighting by persons gives INEI's official 27.6 %; see the vignette.*

## Funciones / Functions

| Función | Qué hace | What it does |
|---|---|---|
| `fa_surveys()` | Las 10 bases | The 10 sources |
| `fa_years("ena")` | Años publicados | Published years |
| `fa_catalog("enaho", 2024)` | Módulos, formatos y sha256 | Modules, formats and SHA-256 |
| `fa_download("ena", 2024, "1893")` | Baja a la caché o reutiliza | Downloads or reuses the cache |
| `fa_read("ena", 2024, "1893", cols = c("CCDD", "P104"))` | Lee Stata, SPSS, CSV o DBF con etiquetas; `cols` lee solo esas variables | Reads Stata, SPSS, CSV or DBF with labels; `cols` reads only those variables |
| `fa_variables("ena", 2024, "1893")` | Nombres, etiquetas y tipo, leyendo solo la cabecera | Names, labels and type from the header only |
| `fa_design(datos, "enaho")` | Diseño muestral para `survey` | Survey design for `survey` |
| `fa_ubigeo(datos, year = 2024, base = 2017)` | Ubigeo, provincia, departamento y código en el año base | Ubigeo, province, department and the base-year code |
| `fa_districts(2017)` | Distritos vigentes ese año | Districts valid that year |
| `fa_redatam("freq PERSONA.C5P2")` | Consulta el Censo 2017 en REDATAM | Queries the 2017 Census in REDATAM |
| `fa_check_updates()` | Años nuevos en la fuente | New years at the source |
| `fa_cache()` | Carpeta de caché | Cache folder |

## Las 10 bases / The 10 sources

| Base | Organismo | Años en el catálogo | Diseño |
|---|---|---|---|
| ENAHO, Condiciones de Vida y Pobreza (y Panel) | INEI | 2004-2025, panel desde 2002 | sí |
| ENDES | INEI | 2010-2025 | sí |
| ENA, Encuesta Nacional Agropecuaria | INEI | 2014-2019, 2021-2025 | sí |
| EPEN (y EPE Lima 2001-2022) | INEI | 2001-2026 | sí |
| ENAPRES | INEI | 2010-2025 | sí |
| ENUT | INEI | 2010, 2022, 2024 | sí, sin estratos |
| ENARES | INEI | 2013, 2015, 2019, 2024 | sí, sin estratos |
| Encuesta Económica Anual | INEI | 2001-2025 | aproximado |
| Censo Educativo (ESCALE) | MINEDU | 2004-2025 | censo |
| Censos Nacionales 2017 | INEI (base REDATAM de CELADE) | 2017 | censo |

Los diseños se verificaron en las fichas técnicas y en las cabeceras de los archivos de 2024 y 2025.
ENUT y ENARES no publican estratos; la EEA tampoco, y sus errores estándar son aproximados. Con
faperu se reproducen las cifras oficiales de 2024: pobreza 27,6 % (ENAHO), desempleo 5,6 % e
informalidad 70,9 % (EPEN) y mujeres productoras 31,5 % (ENA).
*Designs checked against INEI's technical sheets and real file headers; four official 2024 figures
are reproduced.*

ENAHO, ENDES y ENA ya se bajaron una vez y cada archivo tiene su sha256 en el catálogo: si el INEI lo
cambia, faperu avisa.

## Si ya tienes los datos / If you already have the data

```r
fa_cache("~/datos/inei_microdatos")   # donde ya tienes los zips
fa_download("ena", 2014, "947")   # status "cached": no baja nada
```

## Ubigeo entre años / Ubigeo across years

```r
e <- fa_ubigeo(enaho_2024, year = 2024, base = 2017)   # al marco del Censo 2017 (1874 distritos)
table(e$ubigeo_status)
```

El ubigeo siempre es texto de 6 dígitos (los CSV del INEI pierden el cero: `10101` es `010101`) y
siempre es el del INEI, que no coincide con el de RENIEC desde el departamento 07. La base natural
es 2017: todas las encuestas del INEI desde 2018 usan ese marco. Las equivalencias salen de RENAMU
2004-2025, del Directorio Nacional 2025, del marco del CPV 2017 y, para los 18 distritos creados
después de 2017, del Padrón MINEDU 2025 (por verificar contra cada ley). Lambras y Santa Lucía
tienen dos padres y quedan `NA`; los distritos creados entre 2005 y 2017 no tienen padre conocido y
también quedan `NA`. Fuentes y método en [`inst/ubigeo/README.md`](inst/ubigeo/README.md).
*INEI codes only, always six-digit text. Base 2017 is the census frame used by every INEI survey
since 2018. No parent district is guessed.*

## Censo 2017 / 2017 Census

El INEI no publica los microdatos del Censo 2017 para descargar. CELADE (CEPAL) distribuye la base
completa en formato REDATAM en redatam.org; `fa_redatam()` la baja una vez a la caché (678 MB, con
sha256) y la consulta con [redatamx](https://cran.r-project.org/package=redatamx), que está en
Suggests porque descarga el motor de REDATAM al instalarse.

```r
install.packages("redatamx")
fa_redatam("freq DEPARTAM.CCDD by PERSONA.C5P2")   # personas por departamento y sexo
```

`freq PERSONA.C5P2` suma 29 381 884 personas, la población censada oficial.
*INEI does not publish the 2017 Census microdata; faperu queries CELADE's REDATAM copy with the
suggested redatamx package.*

## Errores / Errors

Cada error tiene clase `faperu_error` y una subclase (`faperu_error_download`,
`faperu_error_design`, ...), así que se atrapan con `tryCatch()` sin leer el mensaje.
*Every error has class `faperu_error` plus a subclass, so it can be caught without parsing text.*

## Principios / Principles

- **Pocas dependencias.** Solo HTTP, sha256, lectura de Stata/SPSS/DBF, diseño muestral y YAML.
  data.table es opcional y solo acelera los CSV.
- **El catálogo es texto.** Un YAML por base en [`inst/catalog/`](inst/catalog/).
- **Comprobado, no supuesto.** Lo verificado lleva sha256; lo pendiente dice "por verificar".
- **Sin microdatos en el repositorio.** Siempre se bajan de la fuente.

## Rendimiento y pruebas / Performance and tests

`fa_download()` baja hasta cuatro archivos a la vez, reintenta y reanuda los cortes y no guarda
nada que no sea un zip legible. El formato por defecto es Stata: es exacto, trae etiquetas y con
`cols` lee 8 de 1425 columnas de la ENAHO en menos de un segundo. Los números, la comparación de
formatos y cómo repetir las pruebas están en [RENDIMIENTO.md](RENDIMIENTO.md).
*Downloads run four at a time with retries and resume; Stata is the default format. Benchmarks,
the cross-format check and how to rerun them are in RENDIMIENTO.md.*

```r
# Prueba rápida de las 10 bases, con tabla de tiempos
source(system.file("scripts", "prueba_faperu.R", package = "faperu"))
```

## Estado / Status

0.3.0. Probado de punta a punta con las 10 bases, en su año más reciente y en uno antiguo. Hecho:
ubigeo armonizado entre 2004 y 2025, diseño muestral de las ocho encuestas, Censo 2017 vía REDATAM y
años fuera del catálogo buscados en la fuente. Falta: estratos de la EEA y factor de la EEA
2001-2011 (no viene en los archivos). Cambios en [NEWS.md](NEWS.md); guía completa en [vignettes/faperu.Rmd](vignettes/faperu.Rmd).

## Estructura / Layout

```text
R/              Un archivo por idea: catalog, download, read, design, ubigeo, update, utils
inst/catalog/   Un YAML por base
tests/          Una prueba por archivo de R
vignettes/      La guía
```

## Licencia y autoría / License and authors

MIT. Ver [LICENSE.md](LICENSE.md).

Richar Andre Vilca Solorzano (ORCID 0009-0003-2385-5263) y Dina Maribel Yana-Yucra
(ORCID 0009-0003-6218-2735).
