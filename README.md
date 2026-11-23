# faperu

**Las encuestas y censos oficiales del Perú en R, con una sola forma de pedirlos.**
*Peru's official surveys and censuses in R, asked for one way.*

Nueve funciones, cinco dependencias externas (`curl`, `digest`, `haven`, `survey`, `yaml`) y un catálogo en
texto. Cada archivo se guarda en caché y se comprueba con sha256. Los años nuevos se detectan solos.

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
| `fa_read("ena", 2024, "1893")` | Lee SPSS, Stata o CSV con etiquetas | Reads SPSS, Stata or CSV with labels |
| `fa_design(datos, "enaho")` | Diseño muestral para `survey` | Survey design for `survey` |
| `fa_ubigeo(datos)` | Ubigeo, provincia y departamento | Ubigeo, province and department |
| `fa_check_updates()` | Años nuevos en la fuente | New years at the source |
| `fa_cache()` | Carpeta de caché | Cache folder |

## Las 10 bases / The 10 sources

| Base | Organismo | Años en el catálogo | Diseño |
|---|---|---|---|
| ENAHO, Condiciones de Vida y Pobreza (y Panel) | INEI | 2004-2025, panel desde 2002 | sí |
| ENDES | INEI | 2010-2025 | sí |
| ENA, Encuesta Nacional Agropecuaria | INEI | 2014-2019, 2021-2025 | sí |
| EPEN (y EPE Lima 2001-2022) | INEI | 2001-2026 | por verificar |
| ENAPRES | INEI | 2010-2025 | por verificar |
| ENUT | INEI | 2010, 2022, 2024 | por verificar |
| ENARES | INEI | 2013, 2015, 2019, 2024 | por verificar |
| Encuesta Económica Anual | INEI | 2001-2025 | por verificar |
| Censo Educativo (ESCALE) | MINEDU | 2004-2025 | censo |
| Censos Nacionales 2017 | INEI | 2017 | censo |

ENAHO, ENDES y ENA ya se bajaron una vez y cada archivo tiene su sha256 en el catálogo: si el INEI lo
cambia, faperu avisa.

## Si ya tienes los datos / If you already have the data

```r
fa_cache("/mnt/discoD/Research-Dev/AUP_Papers/datos/inei_microdatos")
fa_download("ena", 2014, "947")   # status "cached": no baja nada
```

## Errores / Errors

Cada error tiene clase `faperu_error` y una subclase (`faperu_error_download`,
`faperu_error_design`, ...), así que se atrapan con `tryCatch()` sin leer el mensaje.
*Every error has class `faperu_error` plus a subclass, so it can be caught without parsing text.*

## Principios / Principles

- **Pocas dependencias.** Solo HTTP, sha256, lectura de SPSS/Stata, diseño muestral y YAML.
- **El catálogo es texto.** Un YAML por base en [`inst/catalog/`](inst/catalog/).
- **Comprobado, no supuesto.** Lo verificado lleva sha256; lo pendiente dice "por verificar".
- **Sin microdatos en el repositorio.** Siempre se bajan de la fuente.

## Estado / Status

0.1.0, en desarrollo. Falta: armonizar ubigeo entre versiones, diseño muestral de EPEN, ENAPRES,
ENUT, ENARES y EEA, módulos 2025 de ENAPRES y EEA, ENDES 1996-2009 y el adaptador REDATAM del
censo. Cambios en [NEWS.md](NEWS.md); guía completa en [vignettes/faperu.Rmd](vignettes/faperu.Rmd).

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
