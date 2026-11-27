## Submission

This is a new submission: faperu 0.4.2.

faperu downloads, reads, weights and analyses ten official data sources of
Peru (INEI and MINEDU surveys and censuses) with their verified sampling
designs. It never redistributes microdata: every file is downloaded from the
official portal into a cache under `tools::R_user_dir("faperu", "cache")`,
which the user can change with `fa_cache()`.

## R CMD check results

0 errors | 0 warnings | 1 note

* New submission.

## Test environments

* Arch Linux, R 4.6.2: `R CMD check --as-cran`, also with
  `_R_CHECK_DEPENDS_ONLY_=true` (no suggested packages installed).
* r-universe: Linux (R-release, R-devel), Windows and macOS (R-release and
  R-oldrel).

## Notes for the reviewers

* Examples that download survey files (tens to hundreds of MB from the INEI
  portal) are wrapped in `\dontrun{}`; every other example runs.
* Tests that need the network run only with `FAPERU_ONLINE=1`, and tests on
  real microdata only with `FAPERU_LOCAL=<folder>`; on CRAN they are skipped.
  The rest of the test suite runs offline in a few seconds.
* `sf` and `ggplot2` are suggested and used only by `fa_map()` and
  `fa_geometry()`, which stop with a clear message when they are missing.
* `inst/geo/south_america.geojson` holds simplified country outlines from
  Natural Earth (public domain) for the map context; its source is in
  `inst/geo/README.md`.
* Survey acronyms in the Description (ENAHO, ENDES, ENA, EPEN, ENAPRES,
  ENUT, ENARES, ESCALE, INEI, MINEDU) are names of Peruvian official surveys
  and agencies, not misspellings.
