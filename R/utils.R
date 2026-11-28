.fa <- new.env(parent = emptyenv())

.ids <- c("enaho", "endes", "ena", "epen", "enapres", "enut", "enares", "eea", "escale", "cpv2017")

# Every error carries a class, so callers can catch one kind with tryCatch()
# instead of parsing the message.
.abort <- function(kind, msg, ...) {
  stop(structure(
    class = c(paste0("faperu_error_", kind), "faperu_error", "error", "condition"),
    list(message = if (...length()) sprintf(msg, ...) else msg, call = NULL)
  ))
}

.warn <- function(kind, msg, ...) {
  warning(structure(
    class = c(paste0("faperu_warning_", kind), "faperu_warning", "warning", "condition"),
    list(message = if (...length()) sprintf(msg, ...) else msg, call = NULL)
  ))
}

.or <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

# Hashing a large zip takes a second; within a session the result is reused
# while the file keeps its size and modification time.
.sha256 <- function(path) {
  info <- file.info(path)[, c("size", "mtime")]
  key <- normalizePath(path, mustWork = FALSE)
  memo <- .fa$.sha[[key]]
  if (!is.null(memo) && identical(memo$info, info)) return(memo$sha)
  sha <- digest::digest(file = path, algo = "sha256")
  if (is.null(.fa$.sha)) .fa$.sha <- list()
  .fa$.sha[[key]] <- list(info = info, sha = sha)
  sha
}

.check_survey <- function(survey) {
  if (!is.character(survey) || length(survey) != 1L || is.na(survey)) {
    .abort("input", "`survey` must be one name, for example \"enaho\".")
  }
  s <- tolower(survey)
  if (!s %in% .ids) {
    .abort("survey", "Unknown survey \"%s\". Available: %s.", survey, paste(.ids, collapse = ", "))
  }
  s
}

.load <- function(survey) {
  survey <- .check_survey(survey)
  if (is.null(.fa[[survey]])) {
    path <- system.file("catalog", paste0(survey, ".yaml"), package = "faperu", mustWork = TRUE)
    # Read as UTF-8 whatever the locale: under LC_ALL=C (Rscript on a Mac
    # without LANG) read_yaml() stops at the first accent and the catalog
    # comes back incomplete without an error.
    .fa[[survey]] <- yaml::yaml.load(readLines(path, encoding = "UTF-8", warn = FALSE))
  }
  .fa[[survey]]
}

#' Cache folder
#'
#' Without arguments, returns the current cache folder. With `path`, changes
#' it for the session. The default comes from the `FAPERU_CACHE` environment
#' variable or, if unset, from [tools::R_user_dir()].
#'
#' If you already have the microdata on disk with the same layout
#' (`<SURVEY>/<year>/<file>.zip`), point the cache there and [fa_download()]
#' will reuse it.
#'
#' @param path New folder, or `NULL` to only query.
#' @return The cache path (invisibly when it is changed).
#' @examples
#' fa_cache()
#' @export
fa_cache <- function(path = NULL) {
  if (!is.null(path)) {
    options(faperu.cache = normalizePath(path, mustWork = FALSE))
    return(invisible(getOption("faperu.cache")))
  }
  p <- getOption("faperu.cache")
  if (is.null(p)) p <- Sys.getenv("FAPERU_CACHE", "")
  if (!nzchar(p)) p <- tools::R_user_dir("faperu", "cache")
  p
}

# Forget what was added to a catalog during the session (used by the tests).
.fa_reset <- function(survey = NULL) {
  rm(list = intersect(.or(survey, ls(.fa)), ls(.fa)), envir = .fa)
  invisible(NULL)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Stata and SPSS columns come as labelled vectors; the code is what we need.
.num <- function(x) as.numeric(unclass(x))

.need <- function(pkg, why) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    .abort("missing_package", "Package '%s' is needed %s. Install it with install.packages(\"%s\").",
           pkg, why, pkg)
  }
}

# tolower() follows the locale: under LC_ALL=C it leaves accented capitals
# alone, so "A\u00d1O" became "a\u00d1o" and no longer matched "a\u00f1o".
# Accented capitals in INEI names are lowered here byte by byte.
.up_chars <- c("\u00c1", "\u00c9", "\u00cd", "\u00d3", "\u00da", "\u00d1", "\u00dc",
               "\u00c0", "\u00c8", "\u00cc", "\u00d2", "\u00d9")
.lo_chars <- c("\u00e1", "\u00e9", "\u00ed", "\u00f3", "\u00fa", "\u00f1", "\u00fc",
               "\u00e0", "\u00e8", "\u00ec", "\u00f2", "\u00f9")
.lower <- function(x) {
  x <- tolower(x)
  if (isTRUE(l10n_info()[["UTF-8"]])) return(x)
  na <- is.na(x)
  x <- enc2utf8(x)
  for (i in seq_along(.up_chars)) {
    x <- gsub(enc2utf8(.up_chars[i]), enc2utf8(.lo_chars[i]), x, fixed = TRUE, useBytes = TRUE)
  }
  Encoding(x) <- "UTF-8"
  x[na] <- NA_character_
  x
}

# Column lookup that ignores case, since INEI files mix both.
.col <- function(data, names) {
  hit <- match(.lower(names), .lower(colnames(data)))
  hit <- hit[!is.na(hit)]
  if (length(hit)) colnames(data)[hit[1]] else NULL
}
