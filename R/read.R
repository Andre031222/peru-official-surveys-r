#' Read a module
#'
#' Downloads the module if needed (see [fa_download()]), unzips it next to
#' the zip file and reads one data file. SPSS and Stata files keep their
#' variable and value labels (through haven). CSV files from INEI come in
#' Latin-1 and are converted to UTF-8.
#'
#' @inheritParams fa_download
#' @param module One module code.
#' @param file Part of the file name to read, when the module has several
#'   data files (e.g. `"Sumaria-2024"`). A regular expression.
#' @param lower Turn variable names to lower case, so SPSS and Stata files
#'   look the same.
#' @return A data frame (a tibble for SPSS and Stata files).
#' @examples
#' \dontrun{
#' s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
#' }
#' @export
fa_read <- function(survey, year, module, file = NULL, format = "auto", series = NULL,
                    cache = fa_cache(), lower = TRUE) {
  if (length(module) != 1L) .abort("input", "`module` must be a single code.")
  d <- fa_download(survey, year, module, format = format, series = series, cache = cache)
  if (nrow(d) != 1L) {
    .abort("ambiguous", "Module %s matches %d entries; set `series`.", module, nrow(d))
  }
  .read_zip(d$path, file = file, lower = lower)
}

.data_ext <- "\\.(sav|dta|csv)$"

.read_zip <- function(zip, file = NULL, lower = TRUE) {
  if (!file.exists(zip)) .abort("not_found", "File not found: %s", zip)
  dir <- sub("\\.zip$", "", zip)
  # Reuse a folder that was already unpacked next to the zip.
  if (!dir.exists(dir) || length(.data_files(dir)) == 0L) {
    utils::unzip(zip, exdir = dir)
  }
  files <- .data_files(dir)
  if (!is.null(file)) files <- files[grepl(file, basename(files), ignore.case = TRUE)]
  if (length(files) == 0L) {
    .abort("not_found", "No data file%s in %s.",
           if (is.null(file)) "" else sprintf(" matching \"%s\"", file), basename(zip))
  }
  if (length(files) > 1L) {
    .abort("ambiguous", "Several data files in %s; choose one with `file`: %s",
           basename(zip), paste(basename(files), collapse = ", "))
  }
  .read_file(files, lower = lower)
}

.data_files <- function(dir) {
  sort(list.files(dir, pattern = .data_ext, recursive = TRUE, full.names = TRUE,
                  ignore.case = TRUE))
}

.read_file <- function(path, lower = TRUE) {
  ext <- tolower(tools::file_ext(path))
  x <- switch(ext,
    sav = haven::read_sav(path),
    dta = haven::read_dta(path),
    csv = utils::read.csv(path, fileEncoding = "latin1", encoding = "UTF-8",
                          stringsAsFactors = FALSE, check.names = FALSE)
  )
  if (lower) names(x) <- tolower(names(x))
  x
}
