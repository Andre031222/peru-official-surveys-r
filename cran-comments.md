## Submission summary

This is the first submission of faperu (version 0.4.2).

faperu gives R users one consistent way to obtain and analyse ten official
statistical sources of Peru: eight household, labour, health, agricultural
and business surveys from the National Institute of Statistics (INEI), the
School Census of the Ministry of Education (MINEDU) and the 2017 National
Censuses. A text catalog, shipped in `inst/catalog/`, describes 3,092
downloadable modules; the package downloads and verifies them, reads only the
columns requested, builds the survey design documented in INEI's technical
sheets, harmonises district codes across years, and produces design-based
estimates with standard errors, confidence intervals and INEI's
coefficient-of-variation quality bands, together with tables and maps.

Correctness is checked against published figures: the seven ready-made
indicators reproduce INEI's official national values for 2024 and 2025 to
the published decimal (for example, monetary poverty of 25.7% in 2025), as
well as the urban and rural values where INEI publishes them. These
comparisons are part of the test suite and run when a local copy of the
microdata is available (see "Tests" below).

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Richar Andre Vilca Solorzano <andrevilcasolorzano@gmail.com>'
New submission
```

This is a new submission. The Description spells out every survey and agency
the first time it appears; the acronyms that follow (ENAHO, ENDES, ENA, EPEN,
ENAPRES, ENUT, ENARES, INEI, MINEDU) are their official names, not
misspellings. The text is written in British English (`Language: en-GB`).

## Test environments

| Platform | R version | Result |
|---|---|---|
| Arch Linux, x86_64 (local) | 4.6.2 | `--as-cran`: 1 NOTE (new submission) |
| Arch Linux, x86_64 (local), `_R_CHECK_DEPENDS_ONLY_=true` | 4.6.2 | OK |
| Linux, x86_64 (r-universe) | 4.6.2 and R-devel (2026-11-26 r90998) | OK |
| Windows, x86_64 (r-universe) | 4.6.2, 4.5.3 and R-devel (2026-11-17 r90926 ucrt) | OK |
| macOS (r-universe) | 4.6.2 and 4.5.3 | OK |

The check with `_R_CHECK_DEPENDS_ONLY_=true` confirms that the package, its
examples and its tests work when none of the suggested packages are
installed.

## Downloads, internet use and files written

* faperu never redistributes microdata. Every file is downloaded on request
  from the official INEI microdata portal
  (<https://proyectos.inei.gob.pe/microdatos/>), MINEDU's ESCALE or CELADE's
  REDATAM site, and nothing is downloaded at load time.
* Downloaded files are stored only in the cache directory returned by
  `tools::R_user_dir("faperu", "cache")`. Users can choose another folder
  with `fa_cache()` or the `FAPERU_CACHE` environment variable. The package
  writes nowhere else; examples, tests and vignettes do not write to the
  user's home directory.
* Network calls use explicit connect timeouts, a bounded number of retries
  (`options(faperu.retries = 3)`) and resume interrupted transfers. Every
  downloaded zip is verified (SHA-256 where the catalog records it) before it
  enters the cache, so an error page from the server is never stored as
  data. When a source is unavailable, functions stop with an informative
  error of class `faperu_error_download` instead of failing silently.

## Examples

Examples run for every function that works offline (catalog queries, district
codes, quality bands, estimation and tables on data from the survey package,
printing methods). Nine examples are wrapped in `\dontrun{}` because they
download files from the INEI portal, from about 1 MB to more than 20 MB per
module (for instance, the 2024 annual employment survey is 23 MB in Stata
format), and could not run within CRAN's time limits or without network
access.

## Tests

The offline test suite takes about 20 seconds on r-universe (17 to 22 s
across platforms). It covers the catalog, the download logic (with mocked
transfers and small fixture files written to `tempfile()` folders, including
broken transfers, resumes and error pages), reading in every supported
format, survey designs, district harmonisation, estimation, linkage, tables
and maps. Two groups of tests are skipped on CRAN
by design:

* tests that contact the INEI portal and geoserver run only with
  `FAPERU_ONLINE=1`;
* tests on real microdata, including the comparison with INEI's official
  figures, run only with `FAPERU_LOCAL=<folder>`.

## Vignettes

The two vignettes (getting the data, and analysing it) are built with
`eval = FALSE`, because running them would download several hundred MB of
survey files. The results they quote are real output of faperu on the 2024
files; the test suite repeats those computations on the 2024 and 2025 files.

## Dependencies and bundled data

* Imports are kept small: curl, digest, foreign, haven, survey, tidyselect and
  yaml, besides base packages.
* data.table only speeds up reading CSV files; when it is not installed a
  base R reader gives the same result, and the test suite checks both.
* sf and ggplot2 are used only by `fa_geometry()` and `fa_map()`, which stop
  with a clear message explaining how to install them when they are missing.
* `inst/geo/south_america.geojson` (80 KB) holds simplified country outlines
  from Natural Earth, which is in the public domain; its origin is documented
  in `inst/geo/README.md`. Department and district boundaries are downloaded
  from INEI's geoserver into the cache and are not bundled.

## Reverse dependencies

There are no reverse dependencies, as this is a new package.
