# faperu 0.2.0

In development.

- `fa_ubigeo()` gains `year` and `base` to translate district codes between years, adding
  `ubigeo_base` and `ubigeo_status`. The equivalence tables in `inst/ubigeo/` come from INEI's
  RENAMU 2004-2025 and the 2025 National Directory; `data-raw/ubigeo.py` rebuilds them.
- New `fa_districts()` lists the districts valid in a year.

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
