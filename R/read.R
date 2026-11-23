#' Read a module
#'
#' Downloads the module if needed (see [fa_download()]), unzips it next to
#' the zip file and reads one data file. SPSS and Stata files keep their
#' variable and value labels (through haven). CSV files from INEI come in
#' Latin-1 and are converted to UTF-8; the separator (`,`, or `;` with decimal
#' commas as in the ENAHO 2025) is detected, and code columns (`UBIGEO`, `CCDD`, `CCPP`,
#' `CCDI`, `IRUC`, `NSEGM`) are kept as text so no leading zero is lost.
#' DBF files (ESCALE before 2017 and the INEI DBF format) are read with the
#' foreign package.
#'
#' With `cols` only those variables are read. The module is still downloaded
#' whole, because INEI serves nothing smaller, but reading a few columns of
#' a wide file is several times faster and uses a fraction of the memory.
#' [fa_variables()] lists the names. CSV files are read with data.table when
#' it is installed and with base R otherwise; `options(faperu.csv_engine =
#' "base")` forces base R.
#'
#' For the 2017 Census use [fa_redatam()].
#'
#' @inheritParams fa_download
#' @param module One module code.
#' @param file Part of the file name to read, when the module has several
#'   data files (e.g. `"Sumaria-2024"`). A regular expression.
#' @param lower Turn variable names to lower case, so SPSS and Stata files
#'   look the same.
#' @param cols Variables to read, in any case. `NULL` reads them all.
#' @return A data frame (a tibble for SPSS and Stata files).
#' @examples
#' \dontrun{
#' s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.")
#' s <- fa_read("enaho", 2024, "34", file = "Sumaria-2024\\.",
#'              cols = c("conglome", "vivienda", "hogar", "pobreza", "factor07"))
#' }
#' @export
fa_read <- function(survey, year, module, file = NULL, format = "auto", series = NULL,
                    cache = fa_cache(), lower = TRUE, period = NULL, cols = NULL) {
  d <- .one_module(survey, year, module, format, series, cache, period)
  .read_zip(d$path, file = file, lower = lower, cols = cols, format = d$format)
}

#' Variables of a module
#'
#' Lists the variables of the data files in a module, with their labels when
#' the file has them (SPSS and Stata). Only the file headers are read, so it
#' is quick even for large modules. Use it to choose `cols` in [fa_read()].
#'
#' @inheritParams fa_read
#' @return A data frame with `file`, `name`, `label` and `type`, one row per
#'   variable and file.
#' @examples
#' \dontrun{
#' fa_variables("enaho", 2024, "34")
#' }
#' @export
fa_variables <- function(survey, year, module, file = NULL, format = "auto", series = NULL,
                         cache = fa_cache(), period = NULL) {
  d <- .one_module(survey, year, module, format, series, cache, period)
  files <- .zip_files(d$path, file = file, format = d$format)
  out <- lapply(files, function(f) cbind(file = basename(f), .header(f), stringsAsFactors = FALSE))
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

.one_module <- function(survey, year, module, format, series, cache, period) {
  if (length(module) != 1L) .abort("input", "`module` must be a single code.")
  if (identical(.load(survey)$fuente, "inei_censo")) {
    .abort("unsupported", "The 2017 Census has no module files; query it with fa_redatam().")
  }
  d <- fa_download(survey, year, module, format = format, series = series, cache = cache,
                   period = period)
  if (nrow(d) != 1L) {
    .abort("ambiguous", "Module %s matches %d entries; set `series` or `period`.", module, nrow(d))
  }
  d
}

.data_ext <- "\\.(sav|dta|csv|dbf)$"

# File extension for each download format.
.fmt_ext <- c(CSV = "csv", STATA = "dta", SPSS = "sav", DBF = "dbf")

.read_zip <- function(zip, file = NULL, lower = TRUE, cols = NULL, format = NULL) {
  files <- .zip_files(zip, file = file, format = format)
  if (length(files) > 1L) {
    .abort("ambiguous", "Several data files in %s; choose one with `file`: %s",
           basename(zip), paste(basename(files), collapse = ", "))
  }
  .read_file(files, lower = lower, cols = cols)
}

.zip_files <- function(zip, file = NULL, format = NULL) {
  if (!file.exists(zip)) .abort("not_found", "File not found: %s", zip)
  dir <- sub("\\.zip$", "", zip)
  # Reuse a folder that was already unpacked next to the zip.
  if (!dir.exists(dir) || length(.data_files(dir)) == 0L) .unzip_data(zip, dir)
  files <- .data_files(dir)
  if (!is.null(file)) files <- files[grepl(file, basename(files), ignore.case = TRUE)]
  # Some zips bring the same table in several formats (EPEN Lima 2026 has a
  # csv, a dta and a sav); keep the one that was asked for.
  ext <- tolower(tools::file_ext(files))
  want <- unname(.fmt_ext[toupper(.or(format, ""))])
  if (length(want) == 1L && !is.na(want) && any(ext == want) && length(unique(ext)) > 1L) {
    files <- files[ext == want]
  }
  if (length(files) == 0L) {
    .abort("not_found", "No data file%s in %s.",
           if (is.null(file)) "" else sprintf(" matching \"%s\"", file), basename(zip))
  }
  files
}

# Only the data files are unpacked: the PDFs and dictionaries are not needed,
# and some come with Latin-1 names that an NTFS or exFAT disk refuses
# ("Diccionario_Variables_EEA2010_Peque\xf1as.pdf"). A data file with such a
# name is copied out under its UTF-8 name.
.unzip_data <- function(zip, dir) {
  lst <- utils::unzip(zip, list = TRUE)
  name <- lst$Name
  keep <- grepl(.data_ext, name, ignore.case = TRUE, useBytes = TRUE)
  ok <- validUTF8(name)
  if (any(keep & ok)) utils::unzip(zip, files = name[keep & ok], exdir = dir)
  for (i in which(keep & !ok)) {
    to <- file.path(dir, iconv(name[i], "latin1", "UTF-8"))
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    con <- unz(zip, name[i], open = "rb")
    writeBin(readBin(con, "raw", lst$Length[i]), to)
    close(con)
  }
  invisible(dir)
}

# Codes that must stay text: INEI CSV files would otherwise lose the leading zero.
.code_cols <- c("ubigeo", "ccdd", "ccpp", "ccdi", "iruc", "nsegm")

.csv_head <- function(path) {
  # A UTF-8 byte order mark would end up glued to the first name.
  head <- readLines(path, n = 1L, warn = FALSE)
  head <- sub("^\xef\xbb\xbf", "", head, useBytes = TRUE)
  head <- iconv(head, "latin1", "UTF-8")
  sep <- if (lengths(gregexpr(";", head, fixed = TRUE)) >
             lengths(gregexpr(",", head, fixed = TRUE))) ";" else ","
  cols <- strsplit(head, sep, fixed = TRUE)[[1]]
  list(sep = sep, cols = trimws(gsub('^"|"$', "", trimws(cols))))
}

.csv_engine <- function() {
  e <- getOption("faperu.csv_engine", "auto")
  if (identical(e, "auto")) e <- if (requireNamespace("data.table", quietly = TRUE)) "data.table" else "base"
  match.arg(e, c("data.table", "base"))
}

.read_csv <- function(path, cols = NULL) {
  h <- .csv_head(path)
  keep <- if (is.null(cols)) h$cols else h$cols[.match_cols(cols, h$cols, path)]
  text <- keep[tolower(keep) %in% .code_cols]
  # With ";" as separator INEI writes decimals with a comma (ENAHO 2025).
  dec <- if (h$sep == ";") "," else "."
  if (.csv_engine() == "data.table") {
    x <- data.table::fread(path, sep = h$sep, dec = dec, select = if (!is.null(cols)) keep,
                           colClasses = if (length(text)) list(character = text),
                           encoding = "Latin-1", integer64 = "double",
                           check.names = FALSE, showProgress = FALSE, data.table = FALSE)
    chr <- vapply(x, is.character, logical(1))
    x[chr] <- lapply(x[chr], function(v) iconv(v, "latin1", "UTF-8"))
  } else {
    classes <- rep(NA_character_, length(h$cols))
    if (!is.null(cols)) classes[!h$cols %in% keep] <- "NULL"
    classes[h$cols %in% text] <- "character"
    x <- utils::read.csv(path, sep = h$sep, dec = dec, fileEncoding = "latin1", encoding = "UTF-8",
                         stringsAsFactors = FALSE, check.names = FALSE, colClasses = classes)
    names(x) <- h$cols[h$cols %in% keep]
  }
  # Same order as asked, like the other formats.
  x[keep]
}

# Match requested names without caring about case; stop on the ones missing.
.match_cols <- function(cols, have, path) {
  i <- match(tolower(cols), tolower(have))
  if (anyNA(i)) {
    .abort("not_found", "Not in %s: %s. See fa_variables().", basename(path),
           paste(cols[is.na(i)], collapse = ", "))
  }
  unique(i)
}

.read_dbf <- function(path, cols = NULL) {
  x <- foreign::read.dbf(path, as.is = TRUE)
  if (!is.null(cols)) x <- x[.match_cols(cols, names(x), path)]
  chr <- vapply(x, is.character, logical(1))
  # DBF text from INEI and MINEDU is Latin-1 (or its DOS cousin); keep it valid UTF-8.
  x[chr] <- lapply(x[chr], function(v) {
    bad <- !validUTF8(v)
    v[bad] <- iconv(v[bad], "latin1", "UTF-8")
    v
  })
  x
}

.data_files <- function(dir) {
  sort(list.files(dir, pattern = .data_ext, recursive = TRUE, full.names = TRUE,
                  ignore.case = TRUE))
}

.haven <- function(fun, path, cols) {
  if (is.null(cols)) return(fun(path))
  have <- names(fun(path, n_max = 0L))
  keep <- have[.match_cols(cols, have, path)]
  fun(path, col_select = tidyselect::all_of(keep))[keep]
}

.read_file <- function(path, lower = TRUE, cols = NULL) {
  ext <- tolower(tools::file_ext(path))
  x <- switch(ext,
    sav = .haven(haven::read_sav, path, cols),
    dta = .haven(haven::read_dta, path, cols),
    csv = .read_csv(path, cols),
    dbf = .read_dbf(path, cols)
  )
  if (lower) names(x) <- tolower(names(x))
  x
}

.header <- function(path) {
  ext <- tolower(tools::file_ext(path))
  x <- switch(ext,
    sav = haven::read_sav(path, n_max = 0L),
    dta = haven::read_dta(path, n_max = 0L),
    csv = NULL,
    dbf = foreign::read.dbf(path, as.is = TRUE)[0, , drop = FALSE]
  )
  if (is.null(x)) {
    return(data.frame(name = .csv_head(path)$cols, label = NA_character_, type = NA_character_,
                      stringsAsFactors = FALSE))
  }
  lab <- vapply(x, function(v) .or(attr(v, "label", exact = TRUE), NA_character_), character(1))
  type <- vapply(x, function(v) class(v)[length(class(v))], character(1))
  data.frame(name = names(x), label = unname(lab), type = unname(type), stringsAsFactors = FALSE)
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
