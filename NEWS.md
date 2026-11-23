# faperu 0.2.0

In development.

- `fa_ubigeo()` gains `year` and `base` to translate INEI district codes between years, adding
  `ubigeo_base` and `ubigeo_status`. Base 2017 is the 2017 Census frame (1874 districts). The
  tables in `inst/ubigeo/` come from INEI's RENAMU 2004-2025, the 2025 National Directory, the
  2017 census frame and, for the 18 districts created after 2017, MINEDU's 2025 school register
  (not yet checked against each law). `data-raw/` rebuilds them.
- New `fa_districts()` lists the districts valid in a year.
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
