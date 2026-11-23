#' Download modules
#'
#' Fetches the requested modules into the cache. Before downloading anything
#' it looks in the cache: a file that is already there and whose SHA-256
#' matches the catalog is reused as is.
#'
#' @inheritParams fa_years
#' @param year One year.
#' @param module Module codes as shown by [fa_catalog()]. `NULL` means all
#'   modules of that year.
#' @param format `"auto"` uses the format of the verified copy, or else the
#'   first of CSV, STATA, SPSS and DBF. You can also ask for one of those.
#' @param series For sources with several series, e.g. `"panel"` in ENAHO.
#' @param cache Cache folder, see [fa_cache()].
#' @param overwrite Download again even if the file is cached.
#' @return Invisibly, a data frame with one row per module and a `status`
#'   column: `"cached"`, `"downloaded"` or `"changed"` (the source now
#'   serves a file that differs from the catalog).
#' @examples
#' \dontrun{
#' fa_download("ena", 2024, "1893")
#' }
#' @export
fa_download <- function(survey, year, module = NULL, format = "auto", series = NULL,
                        cache = fa_cache(), overwrite = FALSE) {
  x <- .load(survey)
  if (!x$fuente %in% c("inei_portal", "escale_dir")) {
    .abort("unsupported", "%s has no direct download yet: %s", x$siglas, x$estado)
  }
  if (length(year) != 1L) .abort("input", "`year` must be a single year.")
  todo <- fa_catalog(survey, year)
  if (!is.null(series)) todo <- todo[todo$series %in% series, , drop = FALSE]
  if (!is.null(module)) todo <- todo[todo$module %in% as.character(module), , drop = FALSE]
  if (nrow(todo) == 0L) {
    .abort("not_found", "No %s modules for %s with those filters. See fa_catalog(\"%s\", %s).",
           x$siglas, year, x$id, year)
  }
  res <- lapply(todo$.i, function(i) .fetch(x, x$modulos[[i]], format, cache, overwrite))
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  invisible(out)
}

.fetch <- function(x, m, format, cache, overwrite) {
  fmt <- .pick_format(m, format)
  stem <- m$archivos[[fmt]]
  same <- !is.null(m$local) && identical(toupper(m$local$formato), fmt)
  rel <- if (same) m$local$ruta else file.path(toupper(x$siglas), m$anio, paste0(stem, ".zip"))
  dest <- file.path(cache, rel)
  expected <- if (same) m$local$sha256 else NULL
  row <- function(status, sha) {
    data.frame(survey = x$id, year = as.integer(m$anio), module = as.character(m$codigo),
               format = fmt, path = dest, status = status, sha256 = sha,
               stringsAsFactors = FALSE)
  }

  if (file.exists(dest) && !overwrite) {
    sha <- .sha256(dest)
    if (is.null(expected) || identical(sha, expected)) return(row("cached", sha))
    .warn("checksum", "%s is cached but its SHA-256 does not match; downloading again.", rel)
  }

  url <- .url(x, m, fmt, stem)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part")
  on.exit(unlink(tmp), add = TRUE)
  message("Downloading ", url)
  ok <- tryCatch({
    curl::curl_download(url, tmp, quiet = TRUE)
    TRUE
  }, error = function(e) conditionMessage(e))
  if (!isTRUE(ok)) .abort("download", "Could not download %s: %s", url, ok)

  sha <- .sha256(tmp)
  file.rename(tmp, dest)
  # INEI sometimes replaces files without notice. Keep the new one, but say so.
  if (!is.null(expected) && !identical(sha, expected)) {
    .warn("changed", "INEI now serves a different file than the catalog for %s.", rel)
    return(row("changed", sha))
  }
  row("downloaded", sha)
}

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
  pref <- intersect(c("CSV", "STATA", "SPSS", "DBF", "ZIP"), have)
  if (length(pref) == 0L) have[1] else pref[1]
}

.url <- function(x, m, fmt, stem) {
  u <- sub("{formato}", fmt, x$url, fixed = TRUE)
  u <- sub("{anio}", m$anio, u, fixed = TRUE)
  sub("{archivo}", paste0(stem, ".zip"), u, fixed = TRUE)
}
