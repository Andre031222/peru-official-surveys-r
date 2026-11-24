#' Download modules
#'
#' Fetches the requested modules into the cache. Before downloading anything
#' it looks in the cache: a file that is already there and whose SHA-256
#' matches the catalog is reused as is.
#'
#' The files that are missing are downloaded together, a few at a time
#' (`options(faperu.connections = 4)`). A transfer that breaks is retried and
#' resumed from where it stopped, up to `options(faperu.retries = 3)` times;
#' an unfinished file is kept as `.part` so the next call picks it up. Every
#' file is checked before it enters the cache: it must be a readable zip, not
#' an error page. The INEI portal only serves whole modules, so there is no
#' way to download single variables; download the module once and read the
#' columns you need with `fa_read(cols = )`.
#'
#' @inheritParams fa_years
#' @param year One year.
#' @param module Module codes as shown by [fa_catalog()], or their names
#'   (e.g. `"00_Padron"` in the School Census). `NULL` means all modules of
#'   that year.
#' @param format `"auto"` uses the format of the verified copy, or else the
#'   first of STATA, SPSS, CSV and DBF that the module has. Stata comes
#'   first because it is read exactly, with labels, and quickly; INEI's CSV
#'   files can have line breaks inside text answers. You can also ask for
#'   one of those formats.
#' @param series For sources with several series, e.g. `"panel"` in ENAHO.
#' @param period For sources with several files per year, the `period`
#'   shown by [fa_catalog()], e.g. `"Anual - (Ene-Dic)"` in EPEN. A
#'   regular expression.
#' @param cache Cache folder, see [fa_cache()].
#' @param overwrite Download again even if the file is cached.
#' @return Invisibly, a data frame with one row per module, a `status`
#'   column (`"cached"`, `"downloaded"` or `"changed"`, when the source now
#'   serves a file that differs from the catalog), the size in `bytes` and
#'   the download time in `seconds` (0 for cached files).
#' @examples
#' \dontrun{
#' fa_download("ena", 2024, "1893")
#' }
#' @export
fa_download <- function(survey, year, module = NULL, format = "auto", series = NULL,
                        cache = fa_cache(), overwrite = FALSE, period = NULL) {
  x <- .load(survey)
  if (!x$fuente %in% c("inei_portal", "escale_dir")) {
    .abort("unsupported", "%s has no direct download yet: %s", x$siglas, x$estado)
  }
  if (length(year) != 1L) .abort("input", "`year` must be a single year.")
  todo <- fa_catalog(survey, year)
  # fa_catalog() may have added the files of an ESCALE year read from its folder.
  x <- .load(survey)
  todo <- .pick(todo, module, series, period)
  if (nrow(todo) == 0L) {
    if (year %in% fa_years(survey) && !year %in% fa_catalog(survey)$year) {
      .abort("not_found", "%s %s is published but its modules are not in the catalog yet.",
             x$siglas, year)
    }
    .abort("not_found", "No %s modules for %s with those filters. See fa_catalog(\"%s\", %s).",
           x$siglas, year, x$id, year)
  }
  plan <- lapply(todo$.i, function(i) .plan(x, x$modulos[[i]], format, cache, overwrite))
  plan <- do.call(rbind, plan)
  get <- plan$status == "pending"
  if (any(get)) plan[get, ] <- .transfer(plan[get, , drop = FALSE])
  # The portal lists formats it does not always serve (EPE Lima 2015 has no
  # CSV). With format = "auto", a 404 moves on to the next format.
  if (identical(format, "auto")) {
    for (j in which(plan$status == "failed" & grepl("HTTP 404", plan$why))) {
      m <- x$modulos[[todo$.i[j]]]
      for (f in setdiff(intersect(.order, names(m$archivos)), plan$format[j])) {
        alt <- .plan(x, m, f, cache, overwrite)
        if (alt$status == "pending") alt <- .transfer(alt)
        if (alt$status != "failed") {
          message(sprintf("  %s is not served as %s; used %s.", basename(plan$path[j]), plan$format[j], f))
          plan[j, ] <- alt
          break
        }
      }
    }
  }
  bad <- plan$status == "failed"
  if (any(bad)) {
    .abort("download", "Could not download %s",
           paste(sprintf("%s (%s)", plan$url[bad], plan$why[bad]), collapse = "; "))
  }
  plan$why <- NULL
  plan$expected <- NULL
  plan$url <- NULL
  rownames(plan) <- NULL
  invisible(plan)
}

# Decide, for one module, where it lives in the cache and whether it is
# already there.
.plan <- function(x, m, format, cache, overwrite) {
  fmt <- .pick_format(m, format)
  stem <- m$archivos[[fmt]]
  same <- !is.null(m$local) && identical(toupper(m$local$formato), fmt)
  rel <- if (same) m$local$ruta else .cache_rel(cache, x, m, fmt, stem)
  dest <- file.path(cache, rel)
  expected <- if (same) m$local$sha256 else NA_character_
  status <- "pending"
  sha <- NA_character_
  if (file.exists(dest) && !overwrite) {
    sha <- .sha256(dest)
    # A file faperu downloaded itself carries its SHA-256 next to it; that
    # also covers a module INEI changed after the catalog was made.
    mine <- .sidecar(dest)[1]
    if (is.na(expected) || identical(sha, expected) || identical(sha, mine)) {
      status <- "cached"
    } else {
      .warn("checksum", "%s is cached but its SHA-256 does not match; downloading again.", rel)
      sha <- NA_character_
    }
  }
  data.frame(survey = x$id, year = as.integer(m$anio), module = as.character(m$codigo),
             format = fmt, path = dest, status = status, sha256 = sha,
             bytes = if (status == "cached") file.size(dest) else NA_real_, seconds = 0,
             url = .url(x, m, fmt, stem), expected = expected, why = NA_character_,
             stringsAsFactors = FALSE)
}

# INEI gives the same file name to the CSV, Stata and SPSS zips of a module.
# The first one downloaded keeps the plain layout <SURVEY>/<year>/<file>.zip
# (the one of an existing local copy); another format of the same module goes
# into a <FORMAT>/ folder beside it, so asking for Stata never returns the CSV.
.cache_rel <- function(cache, x, m, fmt, stem) {
  base <- file.path(toupper(x$siglas), m$anio)
  plain <- file.path(base, paste0(stem, ".zip"))
  other <- file.path(base, fmt, paste0(stem, ".zip"))
  if (file.exists(file.path(cache, other))) return(other)
  p <- file.path(cache, plain)
  if (!file.exists(p)) return(plain)
  # What faperu asked for is in the note beside the file; for a copy made
  # elsewhere, look inside the zip.
  got <- .sidecar(p)[2]
  if (fmt %in% if (is.na(got)) .zip_formats(p) else c("ZIP", got)) plain else other
}

# Formats found inside a zip; "ZIP" (ESCALE) matches whatever is there.
.zip_formats <- function(zip) {
  ext <- tryCatch(.ext(utils::unzip(zip, list = TRUE)$Name), error = function(e) character())
  c("ZIP", names(.fmt_ext)[.fmt_ext %in% ext])
}

# Download the pending rows in parallel, resuming broken transfers.
.transfer <- function(p) {
  for (d in unique(dirname(p$path))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  part <- paste0(p$path, ".part")
  tries <- max(1L, as.integer(getOption("faperu.retries", 3L)))
  left <- seq_len(nrow(p))
  why <- rep(NA_character_, nrow(p))
  for (k in seq_len(tries)) {
    if (k > 1L) .pause(2^(k - 1L))
    message(sprintf("Downloading %d file%s from %s%s", length(left), if (length(left) > 1L) "s" else "",
                    .host(p$url[left[1]]), if (k > 1L) sprintf(" (attempt %d)", k) else ""))
    t0 <- Sys.time()
    r <- .multi(p$url[left], part[left])
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    ok <- logical(length(left))
    for (j in seq_along(left)) {
      i <- left[j]
      why[i] <- .bad_download(r[j, ], part[i])
      if (is.na(why[i])) {
        ok[j] <- TRUE
        p$seconds[i] <- .or(r$time[j], secs)
      } else if (!.resumable(r[j, ])) {
        # An error page or a broken zip cannot be resumed; start again next time.
        unlink(part[i])
      }
    }
    left <- left[!ok]
    if (length(left) == 0L) break
  }
  p$status[left] <- "failed"
  p$why[left] <- why[left]
  for (i in setdiff(seq_len(nrow(p)), left)) {
    sha <- .sha256(part[i])
    file.rename(part[i], p$path[i])
    writeLines(c(sha, p$format[i]), paste0(p$path[i], ".sha256"))
    p$sha256[i] <- sha
    p$bytes[i] <- file.size(p$path[i])
    # INEI sometimes replaces files without notice. Keep the new one, but say so.
    if (!is.na(p$expected[i]) && !identical(sha, p$expected[i])) {
      .warn("changed", "The source now serves a different file than the catalog for %s.",
            basename(p$path[i]))
      p$status[i] <- "changed"
    } else {
      p$status[i] <- "downloaded"
    }
    message(sprintf("  %s: %.1f MB in %.1f s", basename(p$path[i]), p$bytes[i] / 1e6, p$seconds[i]))
  }
  p
}

# A few files at a time: the INEI server is slow to answer when it gets many
# requests at once.
.multi <- function(urls, dest) {
  n <- max(1L, as.integer(getOption("faperu.connections", 4L)))
  groups <- split(seq_along(urls), ceiling(seq_along(urls) / n))
  out <- lapply(groups, function(g) {
    r <- curl::multi_download(
      urls[g], dest[g], resume = TRUE,
      progress = interactive() && isTRUE(getOption("faperu.progress", TRUE)),
      multiplex = FALSE,
      useragent = "faperu (R package)",
      connecttimeout = getOption("faperu.connect_timeout", 30),
      # Give up on a transfer that crawls below 1 kB/s for a minute; it is resumed later.
      low_speed_limit = 1000, low_speed_time = 60
    )
    as.data.frame(r[, c("success", "status_code", "resumefrom", "error", "time")])
  })
  do.call(rbind, out)
}

# NA when the file is a good zip; otherwise the reason.
.bad_download <- function(r, file) {
  if (!isTRUE(r$success)) return(.or(r$error, "transfer failed"))
  code <- .or(r$status_code, 0)
  if (!code %in% c(200, 206, 416)) return(sprintf("HTTP %s", code))
  # curl appends to the partial file; a server that ignores the range sends
  # the whole file again, so the result would be corrupt.
  if (code == 200 && .or(r$resumefrom, 0) > 0) return("the server does not resume downloads")
  if (!file.exists(file) || file.size(file) < 22) return("empty file")
  if (!.is_zip(file)) return("the server did not send a zip file")
  NA_character_
}

# Only a transfer that broke halfway is worth resuming. One that finished but
# left a bad file starts from zero.
.resumable <- function(r) !isTRUE(r$success)

.is_zip <- function(file) {
  magic <- readBin(file, "raw", 4L)
  if (!identical(magic, as.raw(c(0x50, 0x4b, 0x03, 0x04)))) return(FALSE)
  # The central directory is at the end: a cut file fails here.
  !inherits(tryCatch(utils::unzip(file, list = TRUE), error = function(e) e,
                     warning = function(w) w), "condition")
}

.host <- function(url) sub("^https?://([^/]+).*$", "\\1", url)

# Order tried with format = "auto". Stata first: it keeps labels and types,
# and INEI's CSV files sometimes carry line breaks inside text answers that
# split rows (ENUT 2024).
.order <- c("STATA", "SPSS", "CSV", "DBF")

.pick_format <- function(m, format) {
  have <- names(m$archivos)
  if (!identical(format, "auto")) {
    f <- toupper(format)
    if (!f %in% have) {
      .abort("format", "Module %s (%s) is not available as %s. Available: %s.",
             m$codigo, m$anio, f, paste(have, collapse = ", "))
    }
    return(f)
  }
  if (!is.null(m$local$formato) && toupper(m$local$formato) %in% have) {
    return(toupper(m$local$formato))
  }
  pref <- intersect(c(.order, "ZIP"), have)
  if (length(pref) == 0L) have[1] else pref[1]
}

.url <- function(x, m, fmt, stem) {
  u <- sub("{formato}", fmt, x$url, fixed = TRUE)
  u <- sub("{anio}", m$anio, u, fixed = TRUE)
  # ESCALE names some files with spaces ("01 Tabgence.dbf.zip").
  sub("{archivo}", utils::URLencode(paste0(stem, ".zip")), u, fixed = TRUE)
}

.pause <- function(secs) Sys.sleep(secs)

# File extension without tripping over Latin-1 names, which tools::file_ext()
# cannot handle in a UTF-8 session.
.ext <- function(x) {
  x <- sub("^.*/", "", x, useBytes = TRUE)
  has <- grepl(".", x, fixed = TRUE, useBytes = TRUE)
  ifelse(has, tolower(sub("^.*[.]", "", x, useBytes = TRUE)), "")
}

# SHA-256 and format of a file faperu downloaded, or NA.
.sidecar <- function(path) {
  f <- paste0(path, ".sha256")
  v <- if (file.exists(f)) readLines(f, n = 2L, warn = FALSE) else character()
  c(v, NA_character_, NA_character_)[1:2]
}

# Rows of the catalog that match the filters. A module can be named by its
# code or by its name; ESCALE has two "00".
.pick <- function(todo, module = NULL, series = NULL, period = NULL) {
  if (!is.null(series)) todo <- todo[todo$series %in% series, , drop = FALSE]
  if (!is.null(module)) {
    module <- as.character(module)
    todo <- todo[todo$module %in% module | todo$name %in% module, , drop = FALSE]
  }
  if (!is.null(period)) todo <- todo[grepl(period, todo$period), , drop = FALSE]
  todo
}
