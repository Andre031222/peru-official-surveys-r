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
