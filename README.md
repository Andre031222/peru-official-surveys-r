# faperu: Peruvian Official Surveys and Censuses in R <img src="man/figures/logo.png" align="right" height="139" alt="faperu logo" />

**One catalog and one way of asking for ten official data sources of Peru: download, verify, read, weight and estimate**

[![Version](https://img.shields.io/badge/Version-0.4.2-17A4AE?style=flat-square)](NEWS.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-337AB7?style=flat-square)](LICENSE.md)
[![R >= 4.1](https://img.shields.io/badge/R-%E2%89%A5_4.1-276DC3?style=flat-square&logo=r&logoColor=white)](https://www.r-project.org/)
[![R CMD check](https://img.shields.io/badge/R_CMD_check-OK-2E7D32?style=flat-square)](#tests-and-performance)
[![Tests](https://img.shields.io/badge/Tests-379_passing-2E7D32?style=flat-square)](tests/testthat/)
[![Sources](https://img.shields.io/badge/Sources-10-C0392B?style=flat-square)](#the-ten-sources)
[![Official figures](https://img.shields.io/badge/INEI_2024_and_2025_figures-7_reproduced-7B1FA2?style=flat-square)](#analyse-the-data)

faperu downloads, caches, checks (SHA-256), reads and weights ten official Peruvian data sources:
ENAHO, ENDES, ENA, EPEN, ENAPRES, ENUT, ENARES and the Annual Economic Survey from INEI, the School
Census from MINEDU (ESCALE) and the 2017 National Censuses. Then it turns them into design-based
estimates with INEI quality bands, indicators checked against official figures, tables and maps.

faperu is independent and is not affiliated with INEI or MINEDU. It never redistributes microdata:
every file is downloaded from the official source.

---

## Overview

Peruvian survey microdata are public, but using them well takes a lot of hidden work. Each survey
has its own portal path, module codes, file formats and encoding; codes such as `ubigeo` lose their
leading zero in CSV files; district codes change between years; and the sampling design (weight,
strata, clusters) has to be dug out of each technical sheet. Most users stop at an unweighted mean.

faperu does that work once, in a text catalog, and gives every source the same verbs:

| Step | Function | What it does |
|---|---|---|
| Find | `fa_surveys()`, `fa_years()`, `fa_catalog()` | The ten sources, their years and modules |
| Download | `fa_download()` | Parallel, resumable, SHA-256 checked, cached |
| Read | `fa_read()`, `fa_variables()` | Stata, SPSS, CSV or DBF; only the columns you ask for |
| Locate | `fa_ubigeo()`, `fa_districts()` | District codes harmonised to the 2017 Census frame |
| Weight | `fa_design()` | A `survey` design with the verified weight, strata and clusters; `territory =` keeps one department, province or district with correct standard errors |
| Estimate | `fa_estimate()`, `fa_indicator()` | Figures by domain with SE, CI, CV and the INEI quality band |
| Show | `fa_link()`, `fa_table()`, `fa_map()` | Joins across surveys, tables for a paper, maps |

It is written for people who are not statisticians by training (economists, health and education
researchers, public officials) and want correct numbers in three lines of R.

## Get started

faperu has its own R repository, so it installs like any CRAN package, with no GitHub or
developer tools. In RStudio it can also be added once under *Tools → Global Options → Packages →
Secondary repositories* (`https://faperu.ftorres.org/r`) and then found in the *Install* dialog.

```r
install.packages("faperu", repos = c("https://faperu.ftorres.org/r",
                                    "https://cloud.r-project.org"))

library(faperu)
library(survey)
s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
svymean(~I(pobreza < 3), fa_design(s, "enaho"))
```

This downloads the ENAHO 2024 household summary, reads it and gives the share of poor households
with its standard error (21.9 %). Weighting by persons gives INEI's official 27.6 %; see the
vignette.

Read only what you need. The module is downloaded whole (INEI serves nothing smaller), but reading
8 of the 1425 columns of the ENAHO 2024 employment module takes 0.7 s instead of 11.6 s:

```r
fa_variables("enaho", 2024, "5", file = "500")          # names and labels, header only
e <- fa_read("enaho", 2024, "5", file = "500",
             cols = c("conglome", "vivienda", "hogar", "codperso",
                      "ubigeo", "estrato", "ocu500", "fac500a"))
```

## Key results

<table>
<tr><td valign="top" width="50%">

**What is verified**

| Check | Result |
|---|---|
| Surveys with a verified design | 8 of 8 (plus 2 censuses) |
| Official INEI figures reproduced | 7 of 7, in 2024 and in 2025 |
| Cross-format check (CSV = Stata = SPSS) | Same values |
| `R CMD check` (vignette, local and online tests) | Status OK |
| Tests | 379 passing, 0 failing |
| 2017 Census population via REDATAM | 29 381 884 (official) |

</td><td valign="top" width="50%">

**Reading the ENAHO 2024 employment module**

| Format and engine | All 1425 columns | 8 columns |
|---|:---:|:---:|
| CSV, data.table | 1.0 s | 0.3 s |
| Stata, haven | 11.6 s | **0.7 s** |
| SPSS, haven | 16.5 s | 1.6 s |
| CSV, base R | 22.1 s | 5.8 s |

Peak memory for 8 columns in Stata: 93 MB, against 1.9 GB for the whole file.

</td></tr>
</table>

Details, download times and how to rerun every benchmark are in [RENDIMIENTO.md](RENDIMIENTO.md).

## Analyse the data

```r
p <- fa_indicator("pobreza_monetaria", 2025, by = "department")
p                       # estimate, interval, CV and INEI quality band per department
summary(p)              # how many figures fall in each quality band
plot(p)
fa_map(p)               # needs sf and ggplot2
fa_table(p, format = "markdown")
```

`fa_estimate()` does the same for any variable of any design:

```r
s$pobre  <- as.numeric(s$pobreza < 3)
s$facpob <- s$factor07 * s$mieperho        # weight by persons
fa_estimate(fa_design(s, "enaho", weight = "facpob"), "pobre", type = "prop", by = "area")
```

Seven indicators reproduce INEI's published figures for 2024 and 2025 (monetary and extreme poverty,
unemployment, informality, child anaemia under two definitions and women among agricultural
producers); `fa_indicators()`
lists them with their sources. `fa_link()` joins estimates from different surveys by department
or district and year.

## Functions

| Function | What it does |
|---|---|
| `fa_surveys()` | The 10 sources |
| `fa_years("ena")` | Published years |
| `fa_catalog("enaho", 2024)` | Modules, formats and SHA-256 |
| `fa_download("ena", 2024, "1893")` | Downloads to the cache or reuses it |
| `fa_read("ena", 2024, "1893", cols = c("CCDD", "P104"))` | Reads Stata, SPSS, CSV or DBF with labels; `cols` reads only those variables |
| `fa_variables("ena", 2024, "1893")` | Names, labels and types from the file header |
| `fa_ubigeo(data, year = 2024, base = 2017)` | Six-digit ubigeo, province, department and the base-year code |
| `fa_districts(2017)` | Districts valid in a year |
| `fa_design(data, "enaho", territory = "Puno")` | Survey design for the `survey` package, optionally for one territory |
| `fa_redatam("freq PERSONA.C5P2")` | Queries the 2017 Census in REDATAM |
| `fa_check_updates()` | New years published at the source |
| `fa_cache()` | Cache folder |
| `fa_estimate(design, ~x, by = "department")` | Mean, proportion or total by domain with SE, CI, CV and quality band |
| `fa_quality(cv)` | INEI quality band of a coefficient of variation |
| `fa_indicators()`, `fa_indicator(id, year)` | Ready indicators checked against INEI figures |
| `fa_link(a, b)` | Joins estimates from two surveys by territory and year |
| `fa_geometry("department")`, `fa_map(est)` | INEI boundaries and choropleth maps |
| `fa_table(est, format = "markdown")` | A table ready for a paper |

## The ten sources

| Source | Agency | Years in the catalog | Design |
|---|---|---|---|
| ENAHO, Living Conditions and Poverty (and Panel) | INEI | 2004-2025, panel from 2002 | yes |
| ENDES, Demographic and Family Health | INEI | 2010-2025 | yes |
| ENA, National Agricultural Survey | INEI | 2014-2019, 2021-2025 | yes |
| EPEN, Permanent National Employment (and EPE Lima 2001-2022) | INEI | 2001-2026 | yes |
| ENAPRES, Budget Programmes | INEI | 2010-2025 | yes |
| ENUT, Time Use | INEI | 2010, 2022, 2024 | yes, no strata published |
| ENARES, Social Relations | INEI | 2013, 2015, 2019, 2024 | yes, no strata published |
| EEA, Annual Economic Survey | INEI | 2001-2025 | approximate |
| School Census (ESCALE) | MINEDU | 2004-2025 | census |
| 2017 National Censuses | INEI (REDATAM base from CELADE) | 2017 | census |

Years that are not in the catalog yet (a survey published after this version, or an old one such
as ENDES 2009) are looked up at the source the first time they are asked for.

Designs were checked against INEI's technical sheets and the headers of the 2024 and 2025 files.
ENUT and ENARES publish no strata; neither does the EEA, so its standard errors are approximate.

## Ubigeo across years

```r
e <- fa_ubigeo(enaho_2024, year = 2024, base = 2017)   # to the 2017 Census frame (1874 districts)
table(e$ubigeo_status)
```

The ubigeo is always six-digit text (INEI CSV files drop the zero: `10101` is `010101`) and always
the INEI code, which differs from RENIEC's from department 07 on. Base 2017 is the frame used by
every INEI survey since 2018. The equivalences come from RENAMU 2004-2025, the 2025 National
Directory, the 2017 Census frame and, for the 18 districts created after 2017, the 2025 MINEDU
register. No parent district is guessed: districts with two parents stay `NA`. Sources and method
in [`inst/ubigeo/README.md`](inst/ubigeo/README.md).

## 2017 Census

INEI does not publish the 2017 Census microdata as a download. CELADE (ECLAC) distributes the full
database in REDATAM format; `fa_redatam()` downloads it once (678 MB, SHA-256 checked) and queries
it with [redatamx](https://cran.r-project.org/package=redatamx), which is only suggested.

```r
install.packages("redatamx")
fa_redatam("freq DEPARTAM.CCDD by PERSONA.C5P2")   # people by department and sex
```

## If you already have the data

```r
fa_cache("~/data/inei_microdata")    # a folder laid out as <SURVEY>/<year>/<file>.zip
fa_download("ena", 2014, "947")      # status "cached": nothing is downloaded
```

## Tests and performance

`fa_download()` fetches up to four files at a time, retries and resumes broken transfers, and
never caches anything that is not a readable zip. Stata is the default format: it is exact and
keeps labels. Some INEI CSV files split rows on line breaks typed inside answers (ENUT 2024);
faperu repairs them and warns when it cannot.

```r
# Quick end-to-end test of the ten sources, with a table of times
source(system.file("scripts", "prueba_faperu.R", package = "faperu"))
```

Tests against the real sources run with `FAPERU_ONLINE=1`; tests on a local copy of the microdata
run with `FAPERU_LOCAL=<folder>`.

## Errors

Every error has class `faperu_error` plus a subclass (`faperu_error_download`,
`faperu_error_design`, ...), so it can be caught with `tryCatch()` without parsing the message.

## Principles

- **Few dependencies.** HTTP, SHA-256, Stata/SPSS/DBF readers, survey design and YAML. data.table
  is optional and only speeds up CSV files.
- **The catalog is text.** One YAML per source in [`inst/catalog/`](inst/catalog/).
- **Checked, not assumed.** What is verified carries a SHA-256; what is not says so.
- **No microdata in the repository.** Always downloaded from the source.

## Layout

```text
R/              One file per idea: catalog, download, read, design, ubigeo, estimate, indicator, map, ...
inst/catalog/   One YAML per source
inst/ubigeo/    District tables and crosswalk to the 2017 Census frame
inst/scripts/   End-to-end test, cross-format check and benchmarks
tests/          One test file per R file
vignettes/      Two guides: getting the data, and analysing it
```

---

## En español

faperu baja, guarda en caché, verifica con SHA-256, lee y pondera diez fuentes oficiales del Perú:
ENAHO, ENDES, ENA, EPEN, ENAPRES, ENUT, ENARES y la Encuesta Económica Anual del INEI, el Censo
Educativo del MINEDU y los Censos Nacionales 2017. Está pensado para quienes no son estadísticos de
formación (economistas, investigadores de salud y educación, funcionarios) y quieren cifras
correctas en tres líneas de R.

```r
install.packages("faperu", repos = c("https://faperu.ftorres.org/r",
                                    "https://cloud.r-project.org"))
library(faperu)
library(survey)
s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
svymean(~I(pobreza < 3), fa_design(s, "enaho"))
```

- **Bajar:** `fa_download()` baja hasta cuatro archivos a la vez, reanuda los cortes y comprueba
  cada zip.
- **Leer:** `fa_read(cols = )` lee solo las variables que necesitas; `fa_variables()` muestra los
  nombres y etiquetas sin leer los datos. Los códigos con cero a la izquierda y las tildes quedan
  bien.
- **Ubicar:** `fa_ubigeo(year =, base = 2017)` lleva el ubigeo al marco del Censo 2017.
- **Ponderar:** `fa_design()` arma el diseño muestral verificado en las fichas técnicas del INEI.
  Para un territorio usa `fa_design(datos, "enaho", territory = "Puno")`: el territorio se fija en
  el diseño, no filtrando las filas antes, y así el error estándar sale correcto.
- **Estimar:** `fa_estimate()` y `fa_indicator()` dan la cifra con error estándar, intervalo, CV
  y la banda de calidad del INEI; `fa_map()` y `fa_table()` la llevan a un mapa o a una tabla.

Los cambios están en [NEWS.md](NEWS.md), el rendimiento en [RENDIMIENTO.md](RENDIMIENTO.md) y la
guías en [vignettes/faperu.Rmd](vignettes/faperu.Rmd) y [vignettes/analysis.Rmd](vignettes/analysis.Rmd).

## License and authors

Code under the MIT license, see [LICENSE.md](LICENSE.md).

Fred Torres Cruz ([ORCID 0000-0003-0834-6834](https://orcid.org/0000-0003-0834-6834))
and Richar Andre Vilca Solorzano ([ORCID 0009-0003-2385-5263](https://orcid.org/0009-0003-2385-5263)).
