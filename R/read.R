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
#' Labels are the ones INEI wrote in the file. Stata limits them to 80
#' characters, and some are cut (for example the ENA 2022-2025 genetic
#' improvement items `P501A_16C` to `P501A_16E`); the full wording is in the
#' data dictionary PDF that comes in the same zip. CSV files have no labels;
#' a message then suggests `format = "spss"` or `"stata"`.
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
  if (identical(d$format, "CSV") && all(is.na(out$label))) {
    message("CSV files carry no variable labels; use format = \"spss\" or \"stata\" to see them.")
  }
  out
}

.one_module <- function(survey, year, module, format, series, cache, period) {
  if (length(module) != 1L) .abort("input", "`module` must be a single code.")
  if (identical(.load(survey)$fuente, "inei_censo")) {
    .abort("unsupported", "The 2017 Census has no module files; query it with fa_redatam().")
  }
  # Check before downloading, so an ambiguous code does not fetch every match.
  n <- nrow(.pick(fa_catalog(survey, year), module, series, period))
  if (n > 1L) {
    .abort("ambiguous", "Module %s matches %d entries; set `series` or `period`.", module, n)
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
  ext <- .ext(files)
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
  # A session that is not UTF-8 (LC_ALL=C) cannot write "\u00f1" in a file
  # name at all; there the name is spelt in plain ASCII.
  native <- if (isTRUE(l10n_info()[["UTF-8"]])) identity else
    function(n) iconv(n, "UTF-8", "ASCII", sub = "_")
  for (i in which(keep & !ok)) {
    to <- file.path(dir, native(iconv(name[i], "latin1", "UTF-8")))
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
  head <- .fix_text(head)
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
  x <- NULL
  if (.csv_engine() == "data.table") {
    # fread stops at the first malformed line and only warns, which would
    # silently drop the rest of the file. On any warning the file is repaired
    # first and read again.
    # Let fread finish (interrupting it leaves its state dirty) and only note
    # that it complained.
    warned <- FALSE
    x <- withCallingHandlers(.fread(path, h, keep, cols), warning = function(w) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    })
    if (warned) {
      fixed <- .csv_repair(path, h)
      on.exit(if (!identical(c(fixed), path)) unlink(fixed), add = TRUE)
      x <- if (identical(c(fixed), path)) {
        # Nothing to repair line by line, yet fread complained: base R is
        # slower but reads quoted fields with line breaks the standard way.
        .base_csv(path, h, keep, cols)
      } else if (isTRUE(attr(fixed, "left") > 0)) {
        # What could not be repaired was already reported; read the rest whole.
        suppressWarnings(.fread(fixed, h, keep, cols, fill = TRUE))
      } else {
        .fread(fixed, h, keep, cols)
      }
    }
  } else {
    fixed <- .csv_repair(path, h)
    on.exit(if (!identical(c(fixed), path)) unlink(fixed), add = TRUE)
    x <- .base_csv(fixed, h, keep, cols)
  }
  # Same order as asked, like the other formats.
  x[keep]
}

.csv_dec <- function(h) if (h$sep == ";") "," else "."

.fread <- function(path, h, keep, cols, fill = FALSE) {
  # Columns go by position: the names in the file may still be Latin-1 bytes,
  # while `h$cols` is already UTF-8.
  idx <- sort(match(keep, h$cols))
  text <- which(.lower(h$cols) %in% .code_cols)
  # With ";" as separator INEI writes decimals with a comma (ENAHO 2025).
  x <- data.table::fread(path, sep = h$sep, dec = .csv_dec(h), select = if (!is.null(cols)) idx,
                         colClasses = if (length(text)) list(character = text),
                         integer64 = "double", keepLeadingZeros = TRUE,
                         check.names = FALSE, showProgress = FALSE, data.table = FALSE,
                         fill = fill)
  x <- x[seq_len(min(ncol(x), length(h$cols)))]
  names(x) <- h$cols[if (is.null(cols)) seq_len(ncol(x)) else idx]
  # fread leaves an escaped quote doubled ("2"" TRANSP" comes back as 2"").
  for (j in which(vapply(x, is.character, logical(1)))) {
    v <- x[[j]]
    # Byte-wise: the text may still be Latin-1 here, before .fix_cols().
    k <- grepl('""', v, fixed = TRUE, useBytes = TRUE)
    if (any(k)) x[[j]][k] <- gsub('""', '"', v[k], fixed = TRUE, useBytes = TRUE)
  }
  .fix_cols(x)
}

# INEI's CSV files come in Latin-1 or, lately, in UTF-8 (ENARES 2024), even
# within one survey. Each text value that is not valid UTF-8 is taken as
# Latin-1; converting a UTF-8 file again would turn "FERRE\u00d1AFE" into
# mojibake.
.fix_text <- function(v) {
  bad <- !is.na(v) & !validUTF8(v)
  v[bad] <- iconv(v[bad], "latin1", "UTF-8")
  Encoding(v[!bad & !is.na(v)]) <- "UTF-8"
  v
}

.fix_cols <- function(x) {
  chr <- vapply(x, is.character, logical(1))
  x[chr] <- lapply(x[chr], .fix_text)
  x
}

.base_csv <- function(path, h, keep, cols) {
  text <- keep[.lower(keep) %in% .code_cols]
  # Everything as text first, so codes such as CONGLOME "07060" keep their
  # leading zero, as they do in the Stata and SPSS files.
  classes <- rep("character", length(h$cols))
  if (!is.null(cols)) classes[!h$cols %in% keep] <- "NULL"
  x <- utils::read.csv(path, sep = h$sep, stringsAsFactors = FALSE, check.names = FALSE,
                       colClasses = classes, na.strings = "NA")
  names(x) <- h$cols[h$cols %in% keep]
  for (n in setdiff(names(x), text)) {
    v <- x[[n]]
    if (!any(grepl("^-?0[0-9]", v, useBytes = TRUE))) {
      x[[n]] <- utils::type.convert(v, as.is = TRUE, dec = .csv_dec(h), numerals = "no.loss")
    }
  }
  .fix_cols(x)
}

# INEI writes text answers without quotes, and a line break typed inside an
# answer splits the row in two (ENUT 2024 has 26 of them). A short line is
# glued to the next ones while that adds up to exactly the number of columns;
# the break becomes a space. Returns the path of a repaired copy, or the
# original path when there is nothing to repair. Lines that cannot be
# repaired are reported.
.csv_repair <- function(path, h) {
  N <- length(h$cols)
  n <- utils::count.fields(path, sep = h$sep, quote = "\"", blank.lines.skip = FALSE,
                           comment.char = "")
  # A blank line inside an answer counts as one empty field.
  n[!is.na(n) & n == 0L] <- 1L
  # NA marks lines inside a quoted field, which fread reads fine.
  bad <- which(!is.na(n) & n != N)
  if (length(bad) == 0L) return(path)
  lines <- readLines(path, warn = FALSE)
  if (length(lines) != length(n)) {
    .warn("csv", "%s could not be checked line by line; read the STATA or SPSS version.", basename(path))
    return(path)
  }
  keep <- rep(TRUE, length(lines))
  left <- 0L
  j <- 1L
  while (j <= length(bad)) {
    i <- bad[j]
    acc <- n[i]
    k <- i
    while (!is.na(acc) && acc < N && k < length(lines)) {
      k <- k + 1L
      acc <- acc + n[k] - 1L
    }
    if (!is.na(acc) && acc == N && k > i) {
      lines[i] <- paste(lines[i:k], collapse = " ")
      keep[(i + 1L):k] <- FALSE
    } else {
      left <- left + 1L
      k <- i
      # Keep the first N fields of a line that is too long, as fread does;
      # otherwise read.csv shifts every column of the file.
      if (n[i] > N) lines[i] <- .cut_fields(lines[i], h$sep, N)
    }
    j <- j + sum(bad[j:length(bad)] <= k)
  }
  if (left > 0L) {
    .warn("csv", paste("%s has %d malformed lines that could not be repaired.",
                       "Read the STATA or SPSS version for an exact copy."), basename(path), left)
  }
  out <- tempfile(fileext = ".csv")
  writeLines(lines[keep], out, useBytes = TRUE)
  structure(out, left = left)
}

# The first n fields of one CSV line, quoted again where needed.
.cut_fields <- function(line, sep, n) {
  f <- scan(text = line, what = "character", sep = sep, quote = "\"", quiet = TRUE,
            na.strings = character(), strip.white = FALSE, blank.lines.skip = FALSE)[seq_len(n)]
  f[is.na(f)] <- ""
  q <- grepl(sep, f, fixed = TRUE) | grepl("\"", f, fixed = TRUE)
  f[q] <- paste0("\"", gsub("\"", "\"\"", f[q], fixed = TRUE), "\"")
  paste(f, collapse = sep)
}

# Match requested names without caring about case; stop on the ones missing.
.match_cols <- function(cols, have, path) {
  i <- match(.lower(cols), .lower(have))
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
  if (is.null(cols)) return(.latin1_retry(fun, path))
  have <- names(.latin1_retry(fun, path, n_max = 0L))
  keep <- have[.match_cols(cols, have, path)]
  .latin1_retry(fun, path, col_select = tidyselect::all_of(keep))[keep]
}

# Some INEI Stata files mix UTF-8 text with a few Latin-1 bytes (ENARES
# 2019), and haven stops with "Unable to convert string". Then the file is
# read byte for byte as Latin-1 and every value is put back together: the
# ones that were UTF-8 are recovered, the Latin-1 ones are already right.
.latin1_retry <- function(fun, path, ...) {
  tryCatch(fun(path, ...), error = function(e) {
    if (!grepl("encoding|convert string", conditionMessage(e), ignore.case = TRUE)) stop(e)
    fun(path, ..., encoding = "latin1")
  })
}

# Text that is UTF-8 read as Latin-1 ("Â¿" for "¿", "SELECCIÃ\u0093N") is put
# back; text that is right stays as it is, because its Latin-1 bytes are not
# valid UTF-8. Old Stata files need it even when haven does not fail, and
# some SPSS files carry a few such values (EEA 2015, "CASTAÃ±A").
.unmix <- function(x) {
  fix <- function(v) {
    if (!is.character(v) || length(v) == 0L) return(v)
    b <- iconv(v, "UTF-8", "latin1")
    Encoding(b) <- "UTF-8"
    ok <- !is.na(b) & !is.na(v) & validUTF8(b) & b != v
    v[ok] <- b[ok]
    v
  }
  for (n in names(x)) {
    v <- x[[n]]
    a <- attributes(v)
    if (is.character(v)) v <- fix(v)
    attributes(v) <- a
    if (!is.null(a$label)) attr(v, "label") <- fix(a$label)
    if (!is.null(a$labels)) {
      l <- a$labels
      names(l) <- fix(names(l))
      if (is.character(l)) l[] <- fix(unclass(l))
      attr(v, "labels") <- l
    }
    x[[n]] <- v
  }
  names(x) <- fix(names(x))
  x
}

.read_file <- function(path, lower = TRUE, cols = NULL) {
  ext <- .ext(path)
  x <- switch(ext,
    sav = .unmix(.haven(haven::read_sav, path, cols)),
    dta = .unmix(.haven(haven::read_dta, path, cols)),
    csv = .read_csv(path, cols),
    dbf = .read_dbf(path, cols)
  )
  if (lower) names(x) <- .lower(names(x))
  .trim_keys(x)
}

# Identifiers must match whatever format each module was read in: INEI's SPSS
# and Stata files pad HHID and CASEID with leading blanks, the CSV files do
# not, so a join between them found no household (ENDES 2025).
.key_cols <- c("hhid", "caseid", "hvidx", "conglome", "vivienda", "hogar", "codperso",
               "nsegm", "conglomerado", "id_prod", "nselua", "ua", "ubigeo")
.trim_keys <- function(x) {
  for (k in names(x)[.lower(names(x)) %in% .key_cols]) {
    if (is.character(x[[k]])) x[[k]] <- trimws(x[[k]])
  }
  x
}

.header <- function(path) {
  ext <- .ext(path)
  x <- switch(ext,
    sav = .unmix(.latin1_retry(haven::read_sav, path, n_max = 0L)),
    dta = .unmix(.latin1_retry(haven::read_dta, path, n_max = 0L)),
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
