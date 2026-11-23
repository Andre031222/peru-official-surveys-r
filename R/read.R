#' Read a module
#'
#' Downloads the module if needed (see [fa_download()]), unzips it next to
#' the zip file and reads one data file. SPSS and Stata files keep their
#' variable and value labels (through haven). CSV files from INEI come in
#' Latin-1 and are converted to UTF-8; the separator (`,`, or `;` with decimal
#' commas as in the ENAHO 2025) is detected, and code columns (`UBIGEO`, `CCDD`, `CCPP`,
#' `CCDI`, `IRUC`, `NSEGM`) are kept as text so no leading zero is lost.
#'
#' For the 2017 Census use [fa_redatam()].
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
                    cache = fa_cache(), lower = TRUE, period = NULL) {
  if (length(module) != 1L) .abort("input", "`module` must be a single code.")
  if (identical(.load(survey)$fuente, "inei_censo")) {
    .abort("unsupported", "The 2017 Census has no module files; query it with fa_redatam().")
  }
  d <- fa_download(survey, year, module, format = format, series = series, cache = cache,
                   period = period)
  if (nrow(d) != 1L) {
    .abort("ambiguous", "Module %s matches %d entries; set `series` or `period`.", module, nrow(d))
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

# Codes that must stay text: INEI CSV files would otherwise lose the leading zero.
.code_cols <- c("ubigeo", "ccdd", "ccpp", "ccdi", "iruc", "nsegm")

.read_csv <- function(path) {
  head <- iconv(readLines(path, n = 1L, warn = FALSE), "latin1", "UTF-8")
  sep <- if (lengths(gregexpr(";", head, fixed = TRUE)) >
             lengths(gregexpr(",", head, fixed = TRUE))) ";" else ","
  cols <- strsplit(head, sep, fixed = TRUE)[[1]]
  cols <- gsub('^"|"$', "", cols)
  text <- cols[tolower(cols) %in% .code_cols]
  # With ";" as separator INEI writes decimals with a comma (ENAHO 2025).
  utils::read.csv(path, sep = sep, dec = if (sep == ";") "," else ".", fileEncoding = "latin1", encoding = "UTF-8",
                  stringsAsFactors = FALSE, check.names = FALSE,
                  colClasses = stats::setNames(rep("character", length(text)), text))
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
    csv = .read_csv(path)
  )
  if (lower) names(x) <- tolower(names(x))
  x
}

#' Query the 2017 Census in REDATAM format
#'
#' INEI does not publish the 2017 Census microdata as a download, only a
#' web REDATAM query and tables. CELADE (ECLAC) distributes the full census
#' database in REDATAM format at redatam.org. `fa_redatam()` downloads it
#' once into the cache (678 MB, SHA-256 checked), unzips it and runs a
#' REDATAM query on it with the redatamx package.
#'
#' redatamx is only suggested: it downloads the REDATAM engine when it is
#' installed. Install it with `install.packages("redatamx")`.
#'
#' Queries use REDATAM syntax, for example `"freq PERSONA.C5P2"` (sex) or
#' `"freq DEPARTAM.CCDD by PERSONA.C5P2"`. The entities are `DEPARTAM`,
#' `PROVINCI`, `DISTRITO`, `VIVIENDA`, `HOGAR` and `PERSONA`.
#'
#' @param query A REDATAM query. `NULL` lists the variables of every
#'   entity instead.
#' @param cache Cache folder, see [fa_cache()].
#' @return A data frame: the table returned by `redatamx::redatam_query()`,
#'   or with `query = NULL` one row per variable with its `entity`.
#' @examples
#' \dontrun{
#' fa_redatam("freq PERSONA.C5P2")   # 14 450 757 men and 14 931 127 women
#' v <- fa_redatam()                  # what is there
#' }
#' @export
fa_redatam <- function(query = NULL, cache = fa_cache()) {
  if (!.has_redatamx()) {
    .abort("dependency", paste(
      "fa_redatam() needs the redatamx package, which is only suggested.",
      "Install it with install.packages(\"redatamx\")."))
  }
  dic <- .redatam_dic(cache)
  # The engine looks for the data files relative to the working directory.
  old <- setwd(dirname(dic))
  on.exit(setwd(old), add = TRUE)
  db <- .rx("redatam_open")(dic)
  on.exit(.rx("redatam_close")(db), add = TRUE)
  if (is.null(query)) {
    ents <- .rx("redatam_entities")(db)$name
    out <- lapply(ents, function(e) {
      v <- .rx("redatam_variables")(db, e)
      if (NROW(v) == 0L) return(NULL)
      cbind(entity = e, as.data.frame(v), stringsAsFactors = FALSE)
    })
    return(do.call(rbind, out))
  }
  out <- .rx("redatam_query")(db, query)
  if (is.null(out)) .abort("redatam", "REDATAM returned nothing for: %s", query)
  out
}

.has_redatamx <- function() requireNamespace("redatamx", quietly = TRUE)

.rx <- function(fun) getExportedValue("redatamx", fun)

.redatam_dic <- function(cache) {
  b <- .load("cpv2017")$redatam$base
  zip <- file.path(cache, "CPV2017", "2017", b$archivo)
  if (!file.exists(zip)) {
    dir.create(dirname(zip), recursive = TRUE, showWarnings = FALSE)
    tmp <- paste0(zip, ".part")
    on.exit(unlink(tmp), add = TRUE)
    message(sprintf("Downloading %s (%.0f MB), only once.", b$url, b$bytes / 1e6))
    ok <- tryCatch({
      curl::curl_download(b$url, tmp, quiet = TRUE)
      TRUE
    }, error = function(e) conditionMessage(e))
    if (!isTRUE(ok)) .abort("download", "Could not download %s: %s", b$url, ok)
    if (!identical(.sha256(tmp), b$sha256)) {
      .warn("changed", "redatam.org now serves a different %s than the catalog.", b$archivo)
    }
    file.rename(tmp, zip)
  }
  dir <- sub("\\.zip$", "", zip)
  dic <- .find_dic(dir)
  if (length(dic) == 0L) {
    utils::unzip(zip, exdir = dir)
    dic <- .find_dic(dir)
  }
  if (length(dic) == 0L) .abort("not_found", "No REDATAM dictionary (.dicx) in %s.", zip)
  .lowercase_links(dirname(dic[1]))
  dic[1]
}

.find_dic <- function(dir) {
  list.files(dir, pattern = "\\.dicx$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
}

# The database was built on Windows: the dictionary names its files in lower
# case and the zip has them in upper case. On a case-sensitive disk the
# engine does not find them, so each file gets a lower-case link.
.lowercase_links <- function(dir) {
  files <- list.files(dir)
  low <- tolower(files)
  todo <- files != low & !file.exists(file.path(dir, low))
  for (i in which(todo)) {
    to <- file.path(dir, low[i])
    if (!suppressWarnings(file.symlink(files[i], to))) file.copy(file.path(dir, files[i]), to)
  }
  invisible(sum(todo))
}
